# ===========================
# Build/Runtime in one stage
# ===========================
FROM python:3.12-slim

ENV PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1

# 必要包：clickhouse-connect 做写入；tzdata 提供时区；watchdog/uvloop 可选
RUN apt-get update && apt-get install -y --no-install-recommends \
        curl ca-certificates tzdata \
    && rm -rf /var/lib/apt/lists/*

RUN pip install clickhouse-connect==0.7.19 uvloop==0.20.0 watchdog==4.0.1

WORKDIR /app
COPY main.py /app/main.py

# state 目录保存 offset
VOLUME ["/state"]

# 默认环境变量（可在 compose/Swarm 覆盖）
ENV LOG_FILE=/data/caddy/logs/web.log \
    CLICKHOUSE_URL=http://clickhouse:8123 \
    CLICKHOUSE_USER=default \
    CLICKHOUSE_PASSWORD=123456 \
    CLICKHOUSE_DATABASE=logs \
    CLICKHOUSE_TABLE=caddy_requests \
    BATCH_SIZE=1000 \
    FLUSH_INTERVAL_SEC=2 \
    TZ="UTC"

CMD ["python", "/app/main.py"]
