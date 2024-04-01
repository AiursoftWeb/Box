#!/bin/bash

function better_performance() {
    sudo sysctl -w net.core.rmem_max=2500000
    sudo sysctl -w net.core.wmem_max=2500000
    sudo sysctl -w net.ipv4.tcp_congestion_control=bbr
    sudo sysctl -w net.core.default_qdisc=fq
    sudo sysctl -p
}

function deploy() {
    sudo docker stack deploy -c "$1" "$2" --detach
}

function ask_and_create_secret() {
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

# Secrets
echo "Creating secrets..."
ask_and_create_secret openai-key
ask_and_create_secret openai-instance
ask_and_create_secret bing-search-key
ask_and_create_secret nuget-publish-key
ask_and_create_secret gitlab-runner-token

# Data folders
echo "Creating data folders..."
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
sudo mkdir -p /swarm-vol/remotely-data
sudo mkdir -p /swarm-vol/remotely-asp
sudo mkdir -p /swarm-vol/koel/db
sudo mkdir -p /swarm-vol/koel/music
sudo mkdir -p /swarm-vol/koel/covers
sudo mkdir -p /swarm-vol/koel/search_index
sudo mkdir -p /swarm-vol/wiki-data
sudo mkdir -p /swarm-vol/flyclass-data
sudo mkdir -p /swarm-vol/gist-data
sudo mkdir -p /swarm-vol/gitea-data
sudo mkdir -p /swarm-vol/apt-mirror-data
sudo mkdir -p /swarm-vol/immortal-data
sudo mkdir -p /swarm-vol/mc/world
sudo mkdir -p /swarm-vol/mc/world_nether
sudo mkdir -p /swarm-vol/mc/world_the_end
sudo mkdir -p /swarm-vol/mc/dynmap
sudo mkdir -p /swarm-vol/mc/log
sudo touch /swarm-vol/koel/config

# Business stacks
echo "Deploying business stacks..."
deploy swarmpit/docker-compose.yml       swarmpit
deploy tracer/docker-compose.yml         tracer
deploy manhours/docker-compose.yml       manhours
deploy chess/docker-compose.yml          chess
deploy stathub/docker-compose.yml        stathub
deploy health/docker-compose.yml         health #48470,48471
deploy chat/docker-compose.yml           chat #48472
deploy homepage/docker-compose.yml       homepage #48473
deploy gameoflife/docker-compose.yml     gameoflife #48474
deploy howtocook/docker-compose.yml      howtocook #48475
deploy edgeneko-blog/docker-compose.yml  edgeneko-blog #48476
deploy cpprunner/docker-compose.yml      cpprunner #48477
deploy lab/docker-compose.yml            lab #48478
deploy nuget/docker-compose.yml          nuget #48479
deploy remotely/docker-compose.yml       remotely #48480
deploy runner/docker-compose.yml         runner
deploy koel/docker-compose.yml           koel #48481
deploy kiwix/docker-compose.yml          kiwix #48482
deploy flyclass/docker-compose.yml       flyclass #48483
deploy gist/docker-compose.yml           gist #48484
deploy gitea/docker-compose.yml          gitea #2201
deploy apt-mirror/docker-compose.yml     apt-mirror #48486 48487 48488
deploy minecraft/docker-compose.yml      minecraft #25565 19132