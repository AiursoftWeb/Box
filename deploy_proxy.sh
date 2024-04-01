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

echo "Cleaning up stacks..."
sudo docker stack rm incoming || echo "incoming stack not found"
sudo docker stack rm registry || echo "registry stack not found"

echo "Cleaning up networks..."
sudo docker network rm proxy_app || echo "proxy_app network not found"
sudo docker network rm frp_net || echo "frp_net network not found"

#sudo docker builder prune -f
echo "Cleaning up images..."
sudo docker image rm local_ubuntu:latest || echo "local_ubuntu image not found"
sudo docker image rm local_frp:latest || echo "local_frp image not found"
sudo docker image rm local_sites:latest || echo "local_sites image not found"

echo "Pulling images..."
sudo docker pull caddy:latest
sudo docker pull caddy:builder
sudo docker pull ubuntu:22.04
sudo docker pull joxit/docker-registry-ui:main
sudo docker pull registry:2.8.2

echo "Building images..."
sudo docker build ./incoming/ubuntu   -t local_ubuntu:latest
sudo docker build ./incoming/frp      -t local_frp:latest
sudo docker build ./incoming/sites    -t local_sites:latest

echo "Creating secrets..."
ask_and_create_secret frp-token

echo "Creating networks..."
create_network proxy_app 10.234.0.0/16
create_network frp_net 10.233.0.0/16

echo "Creating data folders..."
sudo mkdir -p /swarm-vol/sites-data
sudo mkdir -p /swarm-vol/registry-data

echo "Deploying necessary stacks..."
deploy incoming/docker-compose.yml       incoming # 80 443
deploy registry/docker-compose.yml       registry # 48464