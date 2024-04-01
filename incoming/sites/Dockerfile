# ============================
# Prepare caddy Environment
FROM caddy:builder as caddy-build-env

RUN xcaddy build \
    --with github.com/ueffel/caddy-brotli \
    --with github.com/caddyserver/transform-encoder

# ============================
# Prepare Caddyfile build Environment
FROM localhost:8080/box_starting/local_ubuntu as config-build-env
WORKDIR /app
COPY . .
RUN apt update
RUN apt install curl bash -y

# Outputs to /app/Dist/Caddyfile
RUN chmod +x /app/build.sh
RUN cd /app
RUN /bin/bash /app/build.sh

# ============================
# Prepare Runtime Environment
FROM caddy

WORKDIR /app

EXPOSE 80 443

COPY --from=caddy-build-env /usr/bin/caddy /usr/bin/caddy
COPY --from=config-build-env /app/Dist/Caddyfile /etc/caddy/Caddyfile
