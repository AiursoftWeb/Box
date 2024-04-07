#!/bin/bash

set -e

function install_docker() {
    curl -fsSL get.docker.com -o get-docker.sh
    CHANNEL=stable sh get-docker.sh
    rm get-docker.sh
}

function disable_snap() {
    sudo systemctl disable --now snapd
    sudo apt purge -y snapd
    sudo rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd /usr/lib/snapd ~/snap
    cat << EOF | sudo tee -a /etc/apt/preferences.d/no-snap.pref
Package: snapd
Pin: release a=*
Pin-Priority: -10
EOF
    sudo chown root:root /etc/apt/preferences.d/no-snap.pref
}

function better_performance() {
    # Add user to sudoers
    if ! sudo grep -q "$USER ALL=(ALL) NOPASSWD:ALL" /etc/sudoers.d/$USER; then
        echo "Adding $USER to sudoers..."
        sudo mkdir -p /etc/sudoers.d
        sudo touch /etc/sudoers.d/$USER
        echo "$USER ALL=(ALL) NOPASSWD:ALL" | sudo tee -a /etc/sudoers.d/$USER
    fi

    # Tuning for better performance
    sudo sysctl -w net.core.rmem_max=2500000
    sudo sysctl -w net.core.wmem_max=2500000
    sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
    sudo sysctl -w net.core.default_qdisc=fq
    sudo sysctl -w fs.inotify.max_user_instances=524288
    sudo sysctl -w fs.inotify.max_user_watches=524288
    sudo sysctl -w fs.inotify.max_queued_events=524288
    sudo sysctl -p

    # Disable swap
    sudo sudo swapoff -a

    # Disable snapd
    disable_snap

    # Set timezone to UTC
    sudo timedatectl set-timezone UTC

    # Install latest kernel and intel-media-va-driver
    DEBIAN_FRONTEND=noninteractive sudo apt update
    apt list --installed | grep -q linux-generic-hwe-22.04 || sudo apt install linux-generic-hwe-22.04

    # Install docker
    apt list --installed | grep -q docker-ce || install_docker

    # Install some basic tools
    sudo DEBIAN_FRONTEND=noninteractive apt install -y \
        apt-transport-https ca-certificates curl lsb-release \
        software-properties-common wget git tree zip unzip vim net-tools traceroute dnsutils htop iotop pcp
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
        networkdId=$(sudo docker network create --driver overlay --subnet $subnet --scope swarm $network_name)
        echo "Network $network_name created with id $networkdId"
    fi
}

echo "Deploying the cluster"
better_performance

echo "Creating secrets..."
create_secret frp-token
create_secret xray-uuid
create_secret openai-key
create_secret openai-instance
create_secret bing-search-key
create_secret nuget-publish-key
create_secret gitlab-runner-token

echo "Creating networks..."
create_network proxy_app 10.234.0.0/16
create_network frp_net 10.233.0.0/16

echo "Creating data folders..."
sudo mkdir -p /swarm-vol/registry-data
sudo mkdir -p /swarm-vol/sites-data
sudo mkdir -p /swarm-vol/swarmpit-db-data
sudo mkdir -p /swarm-vol/swarmpit-influx-data
sudo mkdir -p /swarm-vol/manhours-data
sudo mkdir -p /swarm-vol/chess-data
sudo mkdir -p /swarm-vol/stathub-data
sudo mkdir -p /swarm-vol/prometheus-config
sudo mkdir -p /swarm-vol/prometheus-data
sudo mkdir -p /swarm-vol/grafana-config
sudo mkdir -p /swarm-vol/grafana-data
sudo mkdir -p /swarm-vol/sleepagent-data
sudo mkdir -p /swarm-vol/chat-data
sudo mkdir -p /swarm-vol/cpprunner-data
sudo mkdir -p /swarm-vol/nuget-data
sudo mkdir -p /swarm-vol/remotely/data
sudo mkdir -p /swarm-vol/remotely/asp
sudo mkdir -p /swarm-vol/koel/db
sudo mkdir -p /swarm-vol/koel/music
sudo mkdir -p /swarm-vol/koel/covers
sudo mkdir -p /swarm-vol/koel/search_index
sudo mkdir -p /swarm-vol/wiki-data
sudo mkdir -p /swarm-vol/flyclass-data
sudo mkdir -p /swarm-vol/gist-data
sudo mkdir -p /swarm-vol/gitea-data
sudo mkdir -p /swarm-vol/apt-mirror-data
sudo mkdir -p /swarm-vol/apt-mirror-data/mirror/archive.ubuntu.com
sudo mkdir -p /swarm-vol/apt-mirror-data/mirror/ppa.launchpad.net
sudo mkdir -p /swarm-vol/immortal-data
sudo mkdir -p /swarm-vol/mc/world
sudo mkdir -p /swarm-vol/mc/world_nether
sudo mkdir -p /swarm-vol/mc/world_the_end
sudo mkdir -p /swarm-vol/mc/dynmap
sudo mkdir -p /swarm-vol/mc/log
sudo mkdir -p /swarm-vol/vpn-data
sudo mkdir -p /swarm-vol/gitlab/data
sudo mkdir -p /swarm-vol/gitlab/log
sudo mkdir -p /swarm-vol/gitlab/config
sudo mkdir -p /swarm-vol/moongladepure/anduin/db
sudo mkdir -p /swarm-vol/moongladepure/anduin/files
sudo mkdir -p /swarm-vol/moongladepure/anduin/aspnet
sudo mkdir -p /swarm-vol/moongladepure/jimmoen/db
sudo mkdir -p /swarm-vol/moongladepure/jimmoen/files
sudo mkdir -p /swarm-vol/moongladepure/jimmoen/aspnet
sudo mkdir -p /swarm-vol/moongladepure/rest/db
sudo mkdir -p /swarm-vol/moongladepure/rest/files
sudo mkdir -p /swarm-vol/moongladepure/rest/aspnet
sudo mkdir -p /swarm-vol/moongladepure/cody/db
sudo mkdir -p /swarm-vol/moongladepure/cody/files
sudo mkdir -p /swarm-vol/moongladepure/cody/aspnet
sudo mkdir -p /swarm-vol/moongladepure/gxhao/db
sudo mkdir -p /swarm-vol/moongladepure/gxhao/files
sudo mkdir -p /swarm-vol/moongladepure/gxhao/aspnet
sudo mkdir -p /swarm-vol/moongladepure/anois/db
sudo mkdir -p /swarm-vol/moongladepure/anois/files
sudo mkdir -p /swarm-vol/moongladepure/anois/aspnet
sudo mkdir -p /swarm-vol/moongladepure/dvorak/db
sudo mkdir -p /swarm-vol/moongladepure/dvorak/files
sudo mkdir -p /swarm-vol/moongladepure/dvorak/aspnet
sudo mkdir -p /swarm-vol/moongladepure/kitlau/db
sudo mkdir -p /swarm-vol/moongladepure/kitlau/files
sudo mkdir -p /swarm-vol/moongladepure/kitlau/aspnet
sudo mkdir -p /swarm-vol/moongladepure/xinboo/db
sudo mkdir -p /swarm-vol/moongladepure/xinboo/files
sudo mkdir -p /swarm-vol/moongladepure/xinboo/aspnet
sudo mkdir -p /swarm-vol/moongladepure/gbiner/db
sudo mkdir -p /swarm-vol/moongladepure/gbiner/files
sudo mkdir -p /swarm-vol/moongladepure/gbiner/aspnet
sudo mkdir -p /swarm-vol/moongladepure/rdf/db
sudo mkdir -p /swarm-vol/moongladepure/rdf/files
sudo mkdir -p /swarm-vol/moongladepure/rdf/aspnet
sudo mkdir -p /swarm-vol/moongladepure/lyx/db
sudo mkdir -p /swarm-vol/moongladepure/lyx/files
sudo mkdir -p /swarm-vol/moongladepure/lyx/aspnet
sudo mkdir -p /swarm-vol/moongladepure/shubuzuo/db
sudo mkdir -p /swarm-vol/moongladepure/shubuzuo/files
sudo mkdir -p /swarm-vol/moongladepure/shubuzuo/aspnet
sudo mkdir -p /swarm-vol/moongladepure/lily/db
sudo mkdir -p /swarm-vol/moongladepure/lily/files
sudo mkdir -p /swarm-vol/moongladepure/lily/aspnet
sudo mkdir -p /swarm-vol/moongladepure/carson/db
sudo mkdir -p /swarm-vol/moongladepure/carson/files
sudo mkdir -p /swarm-vol/moongladepure/carson/aspnet
sudo mkdir -p /swarm-vol/moongladepure/zoneblog/db
sudo mkdir -p /swarm-vol/moongladepure/zoneblog/files
sudo mkdir -p /swarm-vol/moongladepure/zoneblog/aspnet
sudo mkdir -p /swarm-vol/filebrowser/data
sudo mkdir -p /swarm-vol/filebrowser/database
sudo mkdir -p /swarm-vol/jellyfin/config
sudo mkdir -p /swarm-vol/jellyfin/cache
sudo mkdir -p /swarm-vol/jellyfin/media
sudo mkdir -p /swarm-vol/jellyfin/filebrowser/
sudo touch /swarm-vol/koel/config
sudo touch /swarm-vol/filebrowser/database/database.db
sudo touch /swarm-vol/jellyfin/filebrowser/database.db

echo "Starting registry..."
deploy registry/docker-compose.yml       registry # 8080
sleep 20 # Could not trust result in the first few seconds, because the old registry might still be running
while curl -s http://localhost:8080 > /dev/null; [ $? -ne 0 ]; do
    echo "Waiting for registry(localhost:8080) to start..."
    sleep 1
done

echo "Building images..."
echo "{ \"insecure-registries\":[\"localhost:8080\"] }" | sudo tee /etc/docker/daemon.json
sudo docker build ./incoming/ubuntu   -t localhost:8080/box_starting/local_ubuntu:latest
sudo docker push localhost:8080/box_starting/local_ubuntu:latest
sudo docker build ./incoming/frp      -t localhost:8080/box_starting/local_frp:latest
sudo docker push localhost:8080/box_starting/local_frp:latest
sudo docker build .                   -t localhost:8080/box_starting/local_sites:latest
sudo docker push localhost:8080/box_starting/local_sites:latest

echo "Deploying incoming stacks..."
deploy incoming/docker-compose.yml       incoming # 80 443
sleep 20 # Could not trust result in the first few seconds, because the old registry might still be running
while curl -s https://hub.aiursoft.cn > /dev/null; [ $? -ne 0 ]; do
    echo "Waiting for registry(public endpoint) to start..."
    sleep 1
done

echo "Deploying business stacks..."
deploy swarmpit/docker-compose.yml       swarmpit
deploy gitlab/docker-compose.yml         gitlab
deploy tracer/docker-compose.yml         tracer
deploy manhours/docker-compose.yml       manhours
deploy chess/docker-compose.yml          chess
deploy stathub/docker-compose.yml        stathub
deploy health/docker-compose.yml         health
deploy chat/docker-compose.yml           chat
deploy homepage/docker-compose.yml       homepage
deploy gameoflife/docker-compose.yml     gameoflife
deploy howtocook/docker-compose.yml      howtocook
deploy edgeneko_blog/docker-compose.yml  edgeneko_blog
deploy cpprunner/docker-compose.yml      cpprunner
deploy lab/docker-compose.yml            lab
deploy nuget/docker-compose.yml          nuget
deploy remotely/docker-compose.yml       remotely
deploy koel/docker-compose.yml           koel
deploy kiwix/docker-compose.yml          kiwix
deploy flyclass/docker-compose.yml       flyclass
deploy gist/docker-compose.yml           gist
deploy gitea/docker-compose.yml          gitea
deploy apt_mirror/docker-compose.yml     apt_mirror
deploy minecraft/docker-compose.yml      minecraft
deploy gateway/docker-compose.yml        gateway
deploy fissssssh/docker-compose.yml      fissssssh
deploy aimer/docker-compose.yml          aimer
deploy moongladepure/docker-compose.yml  moongladepure
deploy aiurui/docker-compose.yml         aiurui
deploy image_puller/docker-compose.yml   image_puller
deploy iperf3/docker-compose.yml         iperf3
deploy filebrowser/docker-compose.yml    filebrowser
deploy jellyfin/docker-compose.yml       jellyfin
