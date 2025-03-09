#!/bin/bash

set -e

function install_docker() {
    curl -fsSL get.docker.com -o get-docker.sh
    CHANNEL=stable sh get-docker.sh
    rm get-docker.sh
}

function init_docker_swarm() {
    sudo docker swarm init --advertise-addr $(hostname -I | awk '{print $1}')
}

function install_yq() {
    download_link=https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_amd64
    sudo wget -O /usr/bin/yq $download_link
    sudo chmod +x /usr/bin/yq
}

function ensure_nvidia_gpu() {
    # ensure Nvidia GPU exists
    nvidia-smi > /dev/null || {
        doc_link=https://docs.anduinos.com/Applications/Development/Docker/Docker.html
        echo "Please ensure Nvidia GPU exists. See $doc_link for more information."
        exit 1
    }

    # ensure package: nvidia-container-toolkit and nvidia-docker2
    apt list --installed | grep -q nvidia-container-toolkit || {
        doc_link=https://docs.anduinos.com/Applications/Development/Docker/Docker.html
        echo "Please install nvidia-container-toolkit and nvidia-docker2. See $doc_link for more information."
        exit 1
    }
}

function better_performance() {
    # Tuning for better performance
    sudo sysctl -w net.core.rmem_max=2500000
    sudo sysctl -w net.core.wmem_max=2500000
    sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
    sudo sysctl -w net.core.default_qdisc=fq
    sudo sysctl -w fs.inotify.max_user_instances=524288
    sudo sysctl -w fs.inotify.max_user_watches=524288
    sudo sysctl -w fs.inotify.max_queued_events=524288
    sudo sysctl -w fs.aio-max-nr=2097152
    sudo sysctl -p

    # Set timezone to UTC
    sudo timedatectl set-timezone UTC
}

function ensure_docker_ready() {
    # Install docker if not installed
    apt list --installed | grep -q docker-ce || install_docker

    # Init docker swarm if not initialized
    sudo docker info | grep -q "Swarm: active" || init_docker_swarm

    # Add user to docker group
    sudo usermod -aG docker $USER

    # Install yq. (Run install_yq only if the /usr/bin/yq does not exist.)
    [ -f /usr/bin/yq ] || install_yq

    # Install some basic tools
    sudo DEBIAN_FRONTEND=noninteractive apt install -y wsdd valgrind
}

function clean_up_docker() {
    # if there is no stack deployed, run the system prune command
    # else, log and skip cleaning.
    if [ $(sudo docker stack ls --format '{{.Name}}' | wc -l) -eq 0 ]; then
        echo "Seems running on a new cluster. Cleaning up docker..."
        sudo docker system prune -a --volumes -f
        sudo docker builder prune -f
    else
        echo "There are stacks already deployed and running. Skip cleaning."
    fi
}

function deploy() {
    sudo docker stack deploy -c "$1" "$2" --detach --prune
}

function create_secret() {
    secret_name=$1
    known_secrets=$(sudo docker secret ls --format '{{.Name}}')
    if [[ $known_secrets != *"$secret_name"* ]]; then
        echo "Please enter $secret_name secret"
        read secret_value
        echo $secret_value | sudo docker secret create $secret_name -
    fi
}

function create_network() {
    network_name=$1
    subnet=$2
    known_networks=$(sudo docker network ls --format '{{.Name}}')
    if [[ $known_networks != *"$network_name"* ]]; then
        networkId=$(sudo docker network create --driver overlay --attachable --subnet $subnet --scope swarm $network_name)
        echo "Network $network_name created with id $networkId"
    fi
}


# Ensure has Nvidia GPU and have installed nvidia-container-toolkit and nvidia-docker2
echo "Ensure has Nvidia GPU and have installed..."
ensure_nvidia_gpu

echo "Tuning for better performance..."
better_performance

echo "Ensure docker is ready and in Swarm manager mode..."
ensure_docker_ready

echo "Cleaning up docker (if no stack deployed)..."
clean_up_docker

echo "Creating secrets..."
create_secret bing-search-key
create_secret frp-token
create_secret github-token
create_secret gitlab-runner-token
create_secret neko-image-gallery-access-token
create_secret neko-image-gallery-admin-token
create_secret nuget-publish-key
create_secret xray-uuid

echo "Creating networks..."
create_network proxy_app 10.234.0.0/16
create_network frp_net 10.233.0.0/16
create_network ollama_net 20.232.0.0/16

echo "Creating data folders..."
find . -name 'docker-compose.yml' | while read file; do
  awk '{if(/device:/) print $2}' "$file" | while read -r path; do
    sudo mkdir -p "$path" && echo "Created $path"
  done
done

echo "Opening firewall ports..."
find . -name 'docker-compose.yml' | while read -r file; do
  yq eval -r '.services[].ports[]? | select(has("published")) | "\(.published) \(.protocol)"' "$file" | while read -r published protocol; do
    if [ -z "$protocol" ]; then
      continue
    else
      sudo ufw allow "${published}/${protocol}" && echo "Allowed ${published}/${protocol}"
    fi
  done
done

echo "Creating files for volumes..."
sudo touch /swarm-vol/koel/config
sudo cp ./assets/database.db /swarm-vol/jellyfin/filebrowser/database.db

#=============================
# Nvidia GPU Part
#=============================
echo "Configuring docker daemon for Nvidia GPU..."
GPU_IDS=$(valgrind nvidia-smi -a 2> /dev/null | grep "GPU UUID" | awk '{print substr($4,5,36)}')
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

echo "Starting registry..."
deploy stacks/registry/docker-compose.yml registry # 8080

echo "Make sure the registry is ready..."
sleep 15 # Could not trust result in the first few seconds, because the old registry might still be running
while curl -s http://localhost:8080/ > /dev/null; [ $? -ne 0 ]; do
    echo "Waiting for registry(http://localhost:8080) to start..."
    sleep 1
done

echo "Prebuild images..."
mkdir -p ./images/sites/discovered && cp ./stacks/**/*.conf ./images/sites/discovered

echo "Building images..."
sudo docker build ./images/ubuntu   -t localhost:8080/box_starting/local_ubuntu:latest
sudo docker push localhost:8080/box_starting/local_ubuntu:latest
sudo docker build ./images/frp      -t localhost:8080/box_starting/local_frp:latest
sudo docker push localhost:8080/box_starting/local_frp:latest
sudo docker build ./images/sites    -t localhost:8080/box_starting/local_sites:latest
sudo docker push localhost:8080/box_starting/local_sites:latest

echo "Starting incoming proxy..."
deploy stacks/incoming/docker-compose.yml incoming # 8080

echo "Make sure the registry is ready..."
sleep 5 # Could not trust result in the first few seconds, because the old registry might still be running
while curl -s https://hub.aiursoft.cn > /dev/null; [ $? -ne 0 ]; do
    echo "Waiting for registry (https://hub.aiursoft.cn) to start... ETA: 25s"
    sleep 1
done

echo "Deploying business stacks..."
serviceCount=$(sudo docker service ls --format '{{.Name}}' | wc -l | awk '{print $1}')
find ./stacks -name 'docker-compose.yml' -print0 | while IFS= read -r -d '' file; do
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
