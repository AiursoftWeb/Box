# Dockerfile.vector
#
# 构建一个自带 vector.toml 配置的 Vector 镜像
# 能够从 /var/log/caddy/log.json 中按行读取 JSON 日志，
# 把每行 JSON 解析成字段，然后写入 ClickHouse。

FROM timberio/vector:latest-alpine

# 1. 复制主配置
#    请在同目录下准备好 vector.toml（见下方示例）
COPY vector.toml /etc/vector/vector.toml

# 2. 创建日志目录挂载点（可选）
RUN mkdir -p /data/caddy/logs/web.log

# 启动时，Vector 会自动加载 /etc/vector/vector.toml
ENTRYPOINT ["vector", "-c", "/etc/vector/vector.toml"]
