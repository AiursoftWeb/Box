# Nextcloud Migration Tips

## Before

sudo docker ps | grep nextcloud

## Sync data

cd /swarm-vol/nextcloud/data
rsync -Aavx --update --delete root@nextcloud:/mnt/datastorage/data/* .

## Sync apps

cd /swarm-vol/nextcloud/apps
rsync -Aavx --update --delete root@nextcloud:/var/www/html/nextcloud/apps/ .

## Restore DB

cd ~
sudo docker exec -i DB_CONTAINER_ID sh -c 'exec mysql   -u root -p"root_dbpassword" nextcloud' < ./temp.bak

## Test OCC

sudo docker exec --user www-data WEB_CONTAINER_ID php occ

## Deploy

cd ~
function deploy() {
    sudo docker stack deploy -c "$1" "$2" --detach
}
deploy ./box/stacks/nextcloud/docker-compose.yml nextcloud
