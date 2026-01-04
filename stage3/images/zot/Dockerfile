# The version need to be updated regularly.
ARG ZOT_VERSION=v2.1.13
FROM localhost:8080/box_starting/local_ubuntu

ARG ZOT_VERSION
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
    && apt-get install -y --no-install-recommends wget ca-certificates curl \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /etc/zot /config /data

# Check if git.aiursoft.com is accessible. If so, download from the mirror.
# Otherwise, download from the official GitHub releases.
RUN if curl -fsS --connect-timeout 5 https://git.aiursoft.com > /dev/null; then \
        echo "--> git.aiursoft.com is accessible, downloading from mirror..."; \
        wget -O /usr/local/bin/zot "https://git.aiursoft.com/PublicVault/zot/releases/download/${ZOT_VERSION}/zot-linux-amd64"; \
    else \
        echo "--> git.aiursoft.com is not accessible, downloading from GitHub..."; \
        wget -O /usr/local/bin/zot "https://github.com/project-zot/zot/releases/download/${ZOT_VERSION}/zot-linux-amd64"; \
    fi \
    && chmod +x /usr/local/bin/zot

COPY default-config.json /etc/zot/default-config.json
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

EXPOSE 5000

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]