# =============================
#          BUILD
# =============================
FROM local_ubuntu as builder

WORKDIR /builder

RUN apt update
RUN apt install -y wget curl jq tar

RUN latestUrl=$(curl https://api.github.com/repos/fatedier/frp/releases/latest | jq -r '(.assets[] | select(.browser_download_url | contains("linux_amd64"))).browser_download_url') \
    && echo $latestUrl \
    && wget -O /builder/frp.tar.gz $latestUrl
RUN mkdir /builder/temp
RUN tar -zxvf /builder/frp.tar.gz --directory /builder/temp

RUN frpcPath=$(find /builder/temp/ -name "frpc") \
    && cp $frpcPath /builder/frpc

#============================
#        RUNTIME
#============================
FROM local_ubuntu as runtime

COPY --from=builder /builder/frpc /usr/bin/
COPY ./frpc.toml /etc/frp/
COPY ./entrypoint.sh /
RUN chmod +x /entrypoint.sh

ENTRYPOINT [ "sh", "-c", "/entrypoint.sh" ]