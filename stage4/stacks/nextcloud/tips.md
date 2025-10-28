# Nextcloud Migration Tips

## AIO

注意：Nextcloud 具有两部分：Nextcloud 本体和 AIO 服务。

其中，AIO 服务中自带了 Turn Server。我们无需在外部的公有云上额外部署 Turn Server。Nextcloud 应当配置成直接用 AIO 内置的 Turn Server。

但是，Turn Server 稍微有一点怪：考虑到在内网，所有业务我们都靠 DNS Override 来配置直接访问内网 IP 地址。但是，Turn Server 不能这么干。它必须要用公网 IP 地址。

所以内网的 DNS 里解析 talk.aiursoft.com 一定是公网 IP 地址。

公网的人解析 talk.aiursoft.com 也是公网 IP 地址，无论是哪个 FRPS 节点，都能正常访问通话。

## Before

sudo docker ps | grep nextcloud
WEB_CONTAINER_ID=$(sudo docker ps | grep nextcloud_web | awk '{print $1}')

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
sudo docker exec --user www-data $WEB_CONTAINER_ID php occ versions:cleanup
sudo docker exec --user www-data $WEB_CONTAINER_ID php occ trashbin:expire
sudo docker exec --user www-data $WEB_CONTAINER_ID php occ trashbin:clean --all-users
```
