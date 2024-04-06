if [ -e /dev/sda2 ]; then
    sudo mkdir -p /mnt/backup
    sudo mount /dev/sda2 /mnt/backup
    sudo rsync -Aavx --delete --update /swarm-vol/ /mnt/backup/swarm-vol/
    sudo umount /mnt/backup
else
    echo "No /dev/sda found, skipping backup..."
    exit 1
fi