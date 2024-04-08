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

sudo docker exec --user www-data WEB_CONTAINER_ID php occ

## Deploy

cd ~
function deploy() {
    sudo docker stack deploy -c "$1" "$2" --detach
}
deploy ./box/stacks/nextcloud/docker-compose.yml nextcloud

## MM

```bash
sudo -u www-data php -f /var/www/html/nextcloud/occ maintenance:update:htaccess
sudo -u www-data php -f /var/www/html/nextcloud/occ db:add-missing-indices
sudo -u www-data php -f /var/www/html/nextcloud/occ files:scan --all
sudo -u www-data php -f /var/www/html/nextcloud/occ files:scan-app-data
sudo -u www-data php -f /var/www/html/nextcloud/occ files:repair-tree
sudo -u www-data php -f /var/www/html/nextcloud/occ app:update --all
sudo -u www-data php -f /var/www/html/nextcloud/occ update:check
sudo -u www-data php -f /var/www/html/nextcloud/occ upgrade
sudo -u www-data php -f /var/www/html/nextcloud/occ db:convert-filecache-bigint -n
sudo -u www-data php -f /var/www/html/nextcloud/occ maintenance:mode --off
sudo -u www-data php -f /var/www/html/nextcloud/occ versions:expire
sudo -u www-data php -f /var/www/html/nextcloud/occ trashbin:expire
```