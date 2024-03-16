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
