#!/bin/sh
set -e

# 确保挂载点存在
mkdir -p /config /etc/zot /data

# 处理 config.json：有就用它，没就复制默认的并软链
if [ -s /config/config.json ]; then
  ln -sf /config/config.json /etc/zot/config.json
else
  if [ ! -e /config/config.json ]; then
    cp /etc/zot/default-config.json /config/config.json
  fi
  ln -sf /config/config.json /etc/zot/config.json
fi

# 启动 zot（以 root 直接跑）
exec /usr/local/bin/zot serve /etc/zot/config.json
