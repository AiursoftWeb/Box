# ============================
# Prepare caddy Environment
FROM local_ubuntu as caddy-build-env

RUN apt update
RUN apt install software-properties-common -y
RUN add-apt-repository ppa:longsleep/golang-backports -y
RUN apt install golang-go curl -y
RUN apt install -y debian-keyring debian-archive-keyring apt-transport-https
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-xcaddy-archive-keyring.gpg
RUN curl -1sLf 'https://dl.cloudsmith.io/public/caddy/xcaddy/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-xcaddy.list
RUN apt update
RUN apt install xcaddy -y

# --with github.com/caddyserver/transform-encoder
RUN xcaddy build --with github.com/ueffel/caddy-brotli --output /tmp/caddy
RUN cp /tmp/caddy /usr/bin/

# ============================
# Prepare Caddyfile build Environment
FROM local_ubuntu as config-build-env
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
FROM caddy:2.7.6
WORKDIR /app
COPY --from=caddy-build-env /usr/bin/caddy /usr/bin/caddy
COPY --from=config-build-env /app/Dist/Caddyfile /etc/caddy/Caddyfile
