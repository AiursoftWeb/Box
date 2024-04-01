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





echo "Pulling images..."




echo "Creating secrets..."




echo "Deploying necessary stacks..."

