# Aiursoft Box

[![MIT licensed](https://img.shields.io/badge/license-MIT-blue.svg)](https://gitlab.aiursoft.cn/aiursoft/box/-/blob/master/LICENSE)
[![ManHours](https://manhours.aiursoft.cn/r/gitlab.aiursoft.cn/aiursoft/box.svg)](https://gitlab.aiursoft.cn/aiursoft/box/-/commits/master?ref_type=heads)
[![Website](https://img.shields.io/website?url=https%3A%2F%2Fwww.aiursoft.cn%2F)](https://www.aiursoft.cn)

This defines the data-center of Aiursoft.

This is a distributed system, which is designed to be deployed on a Docker Swarm cluster, with Glusterfs as the storage backend.

It is suggested to have at least 3 nodes to deploy this system.

## Migrating

Currently this project is still working in progress and migrating existing services.

* When I connect to tracer.aiursoft.cn: Through the router's DNS, it tricks me into connecting to Docker's 443, then Docker's Caddy acts as a reverse proxy.
* When I connect to Minecraft: Through the router's DNS, it tricks me into connecting to Docker's 25565, then it goes straight to the Minecraft container.
* When I connect to GitLab: Through the router's DNS, it tricks me into connecting to Docker's 2202, then it goes straight to the port forwarding container, which forwards the port to the real GitLab.
* When connecting to tracer.aiursoft.cn from outside: Through FRPS to FRP, it goes through frp_net, the traffic is sent to Caddy, and then Caddy acts as a reverse proxy.
* When connecting to Minecraft from outside: Through FRPS to FRP, it goes through frp_net, the traffic goes straight to the Minecraft container.
* When connecting to GitLab from outside: Through FRPS to FRP, it goes through the home network, forwarding to the real GitLab.

## Architecture

```text
+------------------------+
|                        |
|        Request         | 
|                        |
+------------------------+
    ↓       ↓       ↓
+------------------------+
|                        |
|    Compute platform    | 
|     Ingress Network    |
|                        |
+------------------------+
    ↓       ↓       ↓
+------+ +------+ +------+
|      | |      | |      |
| Node | | Node | | Node |
|      | |      | |      |
+------+ +------+ +------+
    ↓       ↓       ↓
+------------------------+
|                        |
|    Storage platform    | 
|     Gluster  FS        |
|                        |
+------------------------+
    ↓       ↓       ↓
+------+ +------+ +------+
|      | |      | |      |
| Node | | Node | | Node |
|      | |      | |      |
+------+ +------+ +------+
```

## How to start

### Hardware requirements

You **need** to have at least 3 Linux machines. Each machine must connect to two subnets.

* Public subnet: This subnet is for accessing Internet.
* Private subnet: This subnet is for accessing other nodes.
  * Docker Swarm will use this subnet to communicate between nodes.
  * Glusterfs will use this subnet to replicate data.
  * Subnet should be 10.64.50.0/12

The private subnet should have at least 10Gbps bandwidth.

Each node must be attached with a big disk (sdb). This disk will be used to store the glusterfs data.

### Install Docker

First, install Docker on every node.

```bash
curl -fsSL get.docker.com -o get-docker.sh
CHANNEL=stable sh get-docker.sh
rm get-docker.sh
sudo apt install docker-compose -y
```

Then , configure Docker Swarm on the first node.

```bash
sudo docker swarm init --advertise-addr=<manager-ip> --listen-addr=0.0.0.0 --data-path-port=7779 --force-new-cluster=true
```

### Join the swarm

You can join other nodes to the swarm.

Run this on the first node to get the join token:

```bash
sudo docker swarm join-token manager
```

Then, run this on other nodes to join the swarm:

```bash
sudo docker swarm join --token <token> <manager-ip>:<port>
```

### Prepare Glusterfs

It's required to have a Glusterfs cluster to store the data.

First, every node should be attached with a big disk (sdb). Then, install Glusterfs on every node.

Run this on every node.

```bash
sudo apt-get install glusterfs-server -y
sudo systemctl start glusterd
sudo systemctl enable glusterd
```

Then, format the disk and mount it. Run this on every node.

```bash
sudo mkfs.xfs /dev/sdb
sudo mkdir -p /var/no-direct-write-here/gluster-bricks
echo '/dev/sdb /var/no-direct-write-here/gluster-bricks xfs defaults 0 0' | sudo tee -a /etc/fstab
sudo mount /var/no-direct-write-here/gluster-bricks
```

Finally, add the peers and create the volume. Run this on the first node.

```bash
sudo gluster peer probe <node2>
sudo gluster peer probe <node3>
```

Now start the volume.

```bash
sudo gluster volume create swarm-vol replica 3 \
  <node1>:/var/no-direct-write-here/gluster-bricks/swarm-vol \
  <node2>:/var/no-direct-write-here/gluster-bricks/swarm-vol \
  <node3>:/var/no-direct-write-here/gluster-bricks/swarm-vol
sudo gluster volume set swarm-vol auth.allow 10.*.*.*
sudo gluster volume start swarm-vol
```

Then, mount the volume on every node.

```bash
echo 'localhost:/swarm-vol /swarm-vol glusterfs defaults,_netdev,noauto,x-systemd.automount 0 0' | sudo tee -a /etc/fstab
sudo mkdir -p /swarm-vol
sudo mount /swarm-vol
sudo chown -R root:docker /swarm-vol
```

You can read more about how to configure Glusterfs [here](https://docs.gluster.org/en/v3/Administrator%20Guide/Managing%20Volumes/).

### Deploy the stack

Finally, deploy the stack.

```bash
./deploy.sh
```

That's it! You can now access the system on port 888, from any node!
