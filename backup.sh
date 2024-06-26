#/bin/bash

# TODO: Decouple this script with /dev/sda
# This is because /dev/sda is not always the backup drive

if [ -e /dev/sda ]; then
    sudo mkdir -p /mnt/backup
    sudo mount /dev/sda /mnt/backup
    
    sudo rsync -Aavx --delete --update /swarm-vol/ /mnt/backup/swarm-vol/
    sudo umount /mnt/backup
else
    echo "No /dev/sda found, skipping backup..."
    exit 1
fi