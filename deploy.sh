#!/bin/bash

set -e

# Determine which env file to use
if [ -f ".env.prod" ]; then
    ENV_FILE=".env.prod"
    echo "Using .env.prod for configuration."
elif [ -f ".env" ]; then
    ENV_FILE=".env"
    echo "Using .env for configuration."
else
    ENV_FILE=""
    echo "No .env or .env.prod file found. Proceeding without variable substitution."
fi

function install_yq() {
    local download_link="https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_amd64"
    sudo wget -O /usr/bin/yq "$download_link"
    sudo chmod +x /usr/bin/yq
}

function install_docker() {
    curl -fsSL get.docker.com -o get-docker.sh
    CHANNEL=stable sh get-docker.sh
    rm get-docker.sh
}

function init_docker_swarm() {
    sudo docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')
}

function ensure_docker_ready() {
    # Install docker if not installed
    apt list --installed | grep -q docker-ce || install_docker

    # Init docker swarm if not initialized
    sudo docker info | grep -q "Swarm: active" || init_docker_swarm

    # Add user to docker group
    sudo usermod -aG docker $USER
}

function ensure_packages_needed_ready() {
    sudo DEBIAN_FRONTEND=noninteractive apt install -y wsdd valgrind curl wget apt-transport-https ca-certificates software-properties-common

    # Install yq. (Run install_yq only if the /usr/bin/yq does not exist.)
    [ -f /usr/bin/yq ] || install_yq

    # Install docker
    ensure_docker_ready
}

function ensure_nvidia_gpu() {
    # ensure /usr/bin/nvidia-smi exists
    if [ ! -f /usr/bin/nvidia-smi ]; then
        local doc_link=https://docs.anduinos.com/Applications/Development/Docker/Docker.html
        echo "Please install Nvidia driver. See $doc_link for more information."
        exit 1
    fi

    ulimit -n 65535
    valgrind /usr/bin/nvidia-smi -L 2> /dev/null | grep -q "GPU 0" || {
        local doc_link=https://docs.anduinos.com/Applications/Development/Docker/Docker.html
        echo "Please ensure you have Nvidia GPU. See $doc_link for more information."
        exit 1
    }

    # ensure package: nvidia-container-toolkit and nvidia-docker2
    apt list --installed | grep -q nvidia-container-toolkit || {
        local doc_link=https://docs.anduinos.com/Applications/Development/Docker/Docker.html
        echo "Please install nvidia-container-toolkit and nvidia-docker2. See $doc_link for more information."
        exit 1
    }
}

better_performance() {
    # Avoid system sleep (If gsettings command exists)
    if command -v gsettings &>/dev/null; then
        echo "Disabling sleep via gsettings..."
        gsettings set org.gnome.desktop.session idle-delay 0 || true
        gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' || true
        gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' || true
    fi

    sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

    echo "Applying runtime sysctl tweaks for performance..."
    sudo sysctl -w net.core.rmem_max=2500000
    sudo sysctl -w net.core.wmem_max=2500000
    sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
    sudo sysctl -w net.core.default_qdisc=fq
    sudo sysctl -w fs.inotify.max_user_instances=524288
    sudo sysctl -w fs.inotify.max_user_watches=524288
    sudo sysctl -w fs.inotify.max_queued_events=524288
    sudo sysctl -w fs.aio-max-nr=2097152

    sudo timedatectl set-timezone UTC
}

function clean_up_docker() {
    # if there is no stack deployed, run the system prune command
    # else, log and skip cleaning.
    if [ $(sudo docker stack ls --format '{{.Name}}' | wc -l) -eq 0 ]; then
        echo "Seems running on a new cluster. Cleaning up docker..."
        sudo docker system prune -a --volumes -f
        sudo docker network prune -f
        #sudo docker builder prune -f
    else
        echo "There are stacks already deployed and running. Skip cleaning."
    fi
}

function create_secret() {
    local secret_name=$1
    if ! sudo docker secret ls --format '{{.Name}}' | grep -Fxq "$secret_name"; then
        local secret_value
        if [ -t 0 ]; then
          read -rs -p "Enter value for secret '$secret_name': " secret_value
          echo
        else
          read -rs -p "Enter value for secret '$secret_name': " secret_value < /dev/tty
          echo
        fi

        printf '%s' "$secret_value" | sudo docker secret create "$secret_name" -
    fi
}

function create_network() {
    network_name=$1
    subnet=$2
    known_networks=$(sudo docker network ls --format '{{.Name}}')
    if [[ $known_networks != *"$network_name"* ]]; then
        echo "Creating network $network_name with subnet $subnet..."
        networkId=$(sudo docker network create --driver overlay --attachable --subnet $subnet --scope swarm $network_name)
        echo "Network $network_name created with id $networkId"
    fi
}

function deploy() {
    local original_compose_file=$1
    local stack_name=$2
    local temp_compose_file=$(mktemp)

    # Always copy to a temporary file to avoid modifying the original
    cp "$original_compose_file" "$temp_compose_file"

    # If an environment file is found, perform substitutions
    if [ -n "$ENV_FILE" ]; then
        # Read non-empty, non-comment lines from the env file
        grep -v -e '^#' -e '^$' "$ENV_FILE" | while IFS='=' read -r key value; do
            # Escape slashes and ampersands for sed
            escaped_value=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g')
            # Use a different delimiter for sed to handle special characters in values
            sed -i "s/{{$key}}/$escaped_value/g" "$temp_compose_file"
        done
    fi

    sudo docker stack deploy -c "$temp_compose_file" "$stack_name" --detach --prune

    # Clean up the temporary file
    rm "$temp_compose_file"
}

function block_port() {
  local PORT=$1
  local RULE_MARKER="# Rule to restrict port $PORT to localhost only"
  local BEFORE_RULES="/etc/ufw/before.rules"
  
  # 使用 sudo 检查规则是否已存在
  if sudo grep -qF "$RULE_MARKER" "$BEFORE_RULES"; then
    echo "Rule for blocking $PORT already exists in $BEFORE_RULES"
    return 0
  fi
  
  echo "Adding rule for blocking $PORT to $BEFORE_RULES..."
  
  # 使用 sudo sh -c 来处理重定向操作（确保写入文件时具有 root 权限）
  sudo sh -c "{
    cat <<EOF
$RULE_MARKER
*mangle
:PREROUTING ACCEPT [0:0]
-A PREROUTING ! -i lo -p tcp --dport $PORT -j DROP
COMMIT

EOF
    cat $BEFORE_RULES
  } > ${BEFORE_RULES}.new && mv ${BEFORE_RULES}.new $BEFORE_RULES"
  
  echo "Reloading UFW to apply changes..."
  sudo ufw reload
  
  echo "Rule has been added to $BEFORE_RULES and UFW has been reloaded"
}

# Ensure packages needed are ready
echo "Ensure packages needed are ready..."
ensure_packages_needed_ready

# Ensure has Nvidia GPU and have installed nvidia-container-toolkit and nvidia-docker2
echo "Ensure has Nvidia GPU and have installed..."
ensure_nvidia_gpu

# Tuning for better performance
echo "Tuning for better performance..."
better_performance

echo "Cleaning up docker (if no stack deployed)..."
clean_up_docker

echo "Creating secrets..."
while IFS= read -r file; do
  while IFS= read -r secret_name; do
    if [ -n "$secret_name" ]; then
      echo "Creating secret $secret_name..."
      create_secret "$secret_name"
    fi
  done < <(yq eval '.secrets | to_entries | .[] | select(.value.external == true) | .key' "$file")
done < <(find ./stage* -name 'docker-compose.yml' -type f)

echo "Creating networks..."
subnet_third_octet=233
external_networks=$(find ./stage* -name 'docker-compose.yml' -type f | xargs yq eval '.networks | to_entries | .[] | select(.value.external == true) | .key' 2>/dev/null | sort | uniq)
for network in $external_networks; do
  if [ "$network" == "---" ]; then
    continue
  fi
  echo "Creating network $network ... on subnet 10.${subnet_third_octet}.0.0/16"
  create_network "$network" "10.${subnet_third_octet}.0.0/16"
  subnet_third_octet=$((subnet_third_octet + 1))
done

echo "Creating data folders..."
find . -name 'docker-compose.yml' | while read file; do
  awk '{if(/device:/) print $2}' "$file" | while read -r path; do
    sudo mkdir -p "$path" && echo "Created $path"
  done
done

#=============================
# Nvidia GPU Part
#=============================
echo "Configuring docker daemon for Nvidia GPU..."
GPU_IDS=$(valgrind /usr/bin/nvidia-smi -a 2> /dev/null | grep "GPU UUID" | awk '{print substr($4,5,36)}')
echo "Detected GPU UUIDs:"
echo "$GPU_IDS"
JSON_GPU_RESOURCES=""
for ID in $GPU_IDS; do
    JSON_GPU_RESOURCES+="\"NVIDIA-GPU=$ID\","
done
JSON_GPU_RESOURCES=${JSON_GPU_RESOURCES%,}  # 去掉最后一个逗号

if [ -f /etc/docker/daemon.json ]; then
    old_hash_daemon=$(sha256sum /etc/docker/daemon.json | awk '{print $1}')
else
    old_hash_daemon=""
fi

if [ -f /etc/nvidia-container-runtime/config.toml ]; then
    old_hash_nvidia=$(sha256sum /etc/nvidia-container-runtime/config.toml | awk '{print $1}')
else
    old_hash_nvidia=""
fi

sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "runtimes": {
    "nvidia": {
      "path": "/usr/bin/nvidia-container-runtime",
      "runtimeArgs": []
    }
  },
  "default-runtime": "nvidia",
  "node-generic-resources": [
    $JSON_GPU_RESOURCES
  ],
  "insecure-registries": [
    "localhost:8080"
  ]
}
EOF
sudo sed -i 's/#swarm-resource = "DOCKER_RESOURCE_GPU"/swarm-resource = "DOCKER_RESOURCE_GPU"/' /etc/nvidia-container-runtime/config.toml

new_hash_daemon=$(sha256sum /etc/docker/daemon.json | awk '{print $1}')
new_hash_nvidia=$(sha256sum /etc/nvidia-container-runtime/config.toml | awk '{print $1}')
if [ "$old_hash_daemon" != "$new_hash_daemon" ] || [ "$old_hash_nvidia" != "$new_hash_nvidia" ]; then
    echo "Configuration files changed. Restarting docker service..."
    sudo systemctl restart docker.service
else
    echo "Configuration files not changed."
fi
#=============================
# Nvidia GPU Part end
#=============================

#=============================
# Stage 0: Start a simple registry
#=============================
echo "Starting registry..."
deploy stage0/registry/docker-compose.yml registry # 8080

echo "Blocking external access to the registry..."
#sudo iptables -t mangle -A PREROUTING ! -i lo -p tcp --dport 8080 -j DROP
#block_port 8080

echo "Make sure the registry is ready..."
sleep 15 # Could not trust result in the first few seconds, because the old registry might still be running
while curl -s http://localhost:8080/ > /dev/null; [ $? -ne 0 ]; do
    echo "Waiting for registry(http://localhost:8080/) to start..."
    sleep 1
done

#=============================
# Stage 1: Mirror public some images
#=============================
echo "Mirroring public images..."
bash ./stage1/mirror.sh

#=============================
# Stage 2: Build and start basic web infrastructure
#=============================
echo "Prebuild stage 2 images..."
rm -rf ./stage2/images/sites/discovered
mkdir -p ./stage2/images/sites/discovered && \
    cp ./stage2/stacks/**/*.conf ./stage2/images/sites/discovered && \
    cp ./stage3/stacks/**/*.conf ./stage2/images/sites/discovered && \
    cp ./stage4/stacks/**/*.conf ./stage2/images/sites/discovered

echo "Building images..."
sudo docker build ./stage2/images/ubuntu   -t localhost:8080/box_starting/local_ubuntu:latest
sudo docker push localhost:8080/box_starting/local_ubuntu:latest
sudo docker build ./stage2/images/frp      -t localhost:8080/box_starting/local_frp:latest
sudo docker push localhost:8080/box_starting/local_frp:latest
sudo docker build ./stage2/images/sites    -t localhost:8080/box_starting/local_sites:latest
sudo docker push localhost:8080/box_starting/local_sites:latest
sudo docker build ./stage2/images/pysyncer    -t localhost:8080/box_starting/local_pysyncer:latest
sudo docker push localhost:8080/box_starting/local_pysyncer:latest

echo "Starting incoming proxy..."
deploy stage2/stacks/incoming/docker-compose.yml incoming # 8080
exit;

echo "Make sure the registry is ready..."
sleep 5 # Could not trust result in the first few seconds, because the old registry might still be running
while curl -s https://test.aiursoft.cn > /dev/null; [ $? -ne 0 ]; do
    echo "Waiting for registry (https://hub.aiursoft.cn) to start... ETA: 25s"
    sleep 1
done

#=============================
# Stage 3: Build and start Authentik and Zot
#=============================
echo "Prebuild stage 3 images..."
sudo docker build ./stage3/images/zot -t localhost:8080/box_starting/local_zot:latest
sudo docker push localhost:8080/box_starting/local_zot:latest

echo "Starting Authentik and Zot..."
deploy stage3/stacks/authentik/docker-compose.yml authentik
deploy stage3/stacks/zot/docker-compose.yml zot

echo "Make sure the zot is ready..."
sleep 5 # Could not trust result in the first few seconds, because the old zot might still be running
while curl -s https://registry.aiursoft.cn > /dev/null; [ $? -ne 0 ]; do
    echo "Waiting for registry (https://registry.aiursoft.cn) to start... ETA: 25s"
    sleep 1
done

#=============================
# Stage 4: Deploy business stacks
#=============================
echo "Deploying business stacks..."
serviceCount=$(sudo docker service ls --format '{{.Name}}' | wc -l | awk '{print $1}')
find ./stage4 -name 'docker-compose.yml' -print0 | while IFS= read -r -d '' file; do
    # Skip the registry and incoming stacks
    if [[ $file == *"registry"* ]]; then
        continue
    fi
    if [[ $file == *"incoming"* ]]; then
        continue
    fi
    
    deploy "$file" "$(basename "$(dirname "$file")")"

    # If serviceCount < 10, which means this is a new cluster. Sleep 10 to slow down the deployment.
    if [ $serviceCount -lt 10 ]; then
        sleep 10
    fi
done
