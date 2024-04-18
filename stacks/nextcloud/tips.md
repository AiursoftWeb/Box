# Nextcloud Migration Tips

## Before

sudo docker ps | grep nextcloud

## Sync data

cd /swarm-vol/nextcloud/data
rsync -Aavx --update --delete root@nextcloud:/mnt/datastorage/data/* .

## Sync apps

cd /swarm-vol/nextcloud/apps
rsync -Aavx --update --delete root@nextcloud:/var/www/html/nextcloud/apps/ .

## Backup DB

sudo mysqldump --single-transaction -h localhost -u root --password=gu********_nextcloud nextcloud > /home/anduin/temp.bak

## Restore DB

cd ~
sudo docker exec -i DB_CONTAINER_ID sh -c 'exec mysql   -u root -p"root_dbpassword" nextcloud' < ./temp.bak

## Test OCC

sudo docker exec --user www-data $WEB_CONTAINER_ID php occ

## Upgrade

sudo docker exec --user www-data $WEB_CONTAINER_ID php occ upgrade

## Deploy

cd ~
function deploy() {
    sudo docker stack deploy -c "$1" "$2" --detach
}
deploy ./box/stacks/nextcloud/docker-compose.yml nextcloud

## MM

```bash
sudo docker exec --user www-data $WEB_CONTAINER_ID php occ maintenance:update:htaccess
sudo docker exec --user www-data $WEB_CONTAINER_ID php occ db:add-missing-indices
sudo docker exec --user www-data $WEB_CONTAINER_ID php occ files:scan --all
sudo docker exec --user www-data $WEB_CONTAINER_ID php occ files:scan-app-data
sudo docker exec --user www-data $WEB_CONTAINER_ID php occ files:repair-tree
sudo docker exec --user www-data $WEB_CONTAINER_ID php occ app:update --all
sudo docker exec --user www-data $WEB_CONTAINER_ID php occ update:check
sudo docker exec --user www-data $WEB_CONTAINER_ID php occ upgrade
sudo docker exec --user www-data $WEB_CONTAINER_ID php occ db:convert-filecache-bigint -n
sudo docker exec --user www-data $WEB_CONTAINER_ID php occ maintenance:mode --off
sudo docker exec --user www-data $WEB_CONTAINER_ID php occ versions:expire
sudo docker exec --user www-data $WEB_CONTAINER_ID php occ trashbin:expire
```
