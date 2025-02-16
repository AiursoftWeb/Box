#!/bin/bash

set -e

function install_docker() {
    curl -fsSL get.docker.com -o get-docker.sh
    CHANNEL=stable sh get-docker.sh
    rm get-docker.sh
}

function init_docker_swarm() {
    sudo docker swarm init  --advertise-addr $(hostname -I | awk '{print $1}')
}

function install_yq() {
    download_link=https://github.com/mikefarah/yq/releases/download/v4.45.1/yq_linux_amd64
    sudo wget -O /usr/bin/yq $download_link
    sudo chmod +x /usr/bin/yq
}

function ensure_nvidia_gpu() {
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
    sudo sysctl -w fs.aio-max-nr=524288
    
    # Patch /proc/sys/fs/aio-max-nr
    echo 2097152 | sudo tee /proc/sys/fs/aio-max-nr
    
    sudo sysctl -p

    # Set timezone to UTC
    sudo timedatectl set-timezone UTC

    # Install docker if not installed
    apt list --installed | grep -q docker-ce || install_docker

    # Ensure has Nvidia GPU and have installed nvidia-container-toolkit and nvidia-docker2
    ensure_nvidia_gpu

    # Init docker swarm if not initialized
    sudo docker info | grep -q "Swarm: active" || init_docker_swarm

    # Add user to docker group
    sudo usermod -aG docker $USER

    # Install yq. (Run install_yq only if the /usr/bin/yq does not exist.)
    [ -f /usr/bin/yq ] || install_yq

    # Install some basic tools
    sudo DEBIAN_FRONTEND=noninteractive apt install -y wsdd

    # sudo docker system prune -a --volumes -f
    # sudo docker builder prune -f
}

function deploy() {
    sudo docker stack deploy -c "$1" "$2" --detach
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

echo "Deploying the cluster"
better_performance

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

echo "Creating data folders..."
find . -name 'docker-compose.yml' | while read file; do
  awk '{if(/device:/) print $2}' "$file" | while read -r path; do
    echo "sudo mkdir -p \"$path\""
    sudo mkdir -p "$path"
  done
done

echo "Opening firewall ports..."
find . -name 'docker-compose.yml' | while read -r file; do
  echo "Processing $file..."
  yq eval -r '.services[].ports[]? | select(has("published")) | "\(.published) \(.protocol)"' "$file" | while read -r published protocol; do
    # If the protocol is not defined, skip this rule
    if [ -z "$protocol" ]; then
        echo "Skipping $published/$protocol"
    else
      echo "sudo ufw allow ${published}/${protocol}"
      sudo ufw allow "${published}/${protocol}"
    fi
  done
done

echo "Creating files for volumes..."
sudo touch /swarm-vol/koel/config
sudo cp ./assets/database.db /swarm-vol/jellyfin/filebrowser/database.db

echo "Starting registry..."
deploy stacks/registry/docker-compose.yml registry # 8080

echo "Make sure the registry is ready..."
sleep 15 # Could not trust result in the first few seconds, because the old registry might still be running
while curl -s http://localhost:8080/ > /dev/null; [ $? -ne 0 ]; do
    echo "Waiting for registry(http://localhost:8080) to start..."
    sleep 1
done

echo "Prebuild images..."
echo "{ \"insecure-registries\":[\"localhost:8080\"] }" | sudo tee /etc/docker/daemon.json
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
find ./stacks -name 'docker-compose.yml' -print0 | while IFS= read -r -d '' file; do
    # Skip the registry and incoming stacks
    if [[ $file == *"registry"* ]]; then
        continue
    fi
    if [[ $file == *"incoming"* ]]; then
        continue
    fi
    
    deploy "$file" "$(basename "$(dirname "$file")")"

    sleep 10
done
