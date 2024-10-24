#/bin/bash

# TODO: Decouple this script with /dev/sdc
# This is because /dev/sdc is not always the backup drive

if [ -e /dev/sdc ]; then
    sudo mkdir -p /mnt/backup
    sudo mount /dev/sdc /mnt/backup
    sudo mkdir -p /mnt/backup/backup-data/swarm-vol
    sudo mkdir -p /mnt/backup/backup-config/swarm-vol
    
    sudo rsync -Aavx --delete --update /swarm-vol/ /mnt/backup/backup-data/swarm-vol/
    sudo rsync -Aavx --delete --update . /mnt/backup/backup-config/swarm-vol/
    sudo umount /mnt/backup
else
    echo "No /dev/sdc found, skipping backup..."
    exit 1
fi