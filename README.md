# Aiursoft Box

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://gitlab.aiursoft.cn/aiursoft/box/-/blob/master/LICENSE)
[![ManHours](https://manhours.aiursoft.cn/r/gitlab.aiursoft.cn/aiursoft/box.svg)](https://gitlab.aiursoft.cn/aiursoft/box/-/commits/master?ref_type=heads)
[![Website](https://img.shields.io/website?url=https%3A%2F%2Fwww.aiursoft.cn%2F)](https://www.aiursoft.cn)

This defines the data-center of Aiursoft.

## How to start

First, install Docker Swarm first.

```bash
sudo docker swarm init
```

If you have other nodes, you can join them to the swarm.

```bash
sudo docker swarm join --token <token> <manager-ip>:<port>
```

Then, deploy the stack.

```bash
./deploy.sh
```

And it's required to configure glusterfs.

```bash
# Assuming using /dev/sdb is your new empty disk on EVERY NODE
# Assuming 10.0.0.* is your private network

# Install and configure GlusterFS. (Run on all nodes)
apt-get install glusterfs-server -y
systemctl start glusterd
systemctl enable glusterd

# Format the disk and mount it (Run on all nodes)
mkfs.xfs /dev/sdb
echo '/dev/sdb /var/no-direct-write-here/gluster-bricks xfs defaults 0 0' >> /etc/fstab
mkdir -p /var/no-direct-write-here/gluster-bricks
mount /var/no-direct-write-here/gluster-bricks

# Add the peers (Run on node1)
gluster peer probe node2
gluster peer probe node3
gluster peer status
gluster pool list

# Create the volume (Run on node1)
gluster volume create swarm-vol replica 3 \
  node1:/var/no-direct-write-here/gluster-bricks/swarm-vol \
  node2:/var/no-direct-write-here/gluster-bricks/swarm-vol \
  node3:/var/no-direct-write-here/gluster-bricks/swarm-vol
gluster volume set swarm-vol auth.allow 10.64.50.*
gluster volume start swarm-vol
gluster volume status
gluster volume info swarm-vol

# Mount the volume (Run on all nodes)
echo 'localhost:/swarm-vol /swarm-vol glusterfs defaults,_netdev,noauto,x-systemd.automount 0 0' >> /etc/fstab
mkdir -p /swarm-vol
mount /swarm-vol
chown -R root:docker /swarm-vol

# Final check (Run on all nodes)
cd /swarm-vol/
df -Th .

# READ: https://docs.gluster.org/en/v3/Administrator%20Guide/Managing%20Volumes/
```
