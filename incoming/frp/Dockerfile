# =============================
#          BUILD
# =============================
FROM hub.aiursoft.cn/aiursoft/internalimages/ubuntu as builder

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
FROM hub.aiursoft.cn/aiursoft/internalimages/ubuntu as runtime

COPY --from=builder /builder/frpc /usr/bin/

VOLUME /etc/frp

ENTRYPOINT [ "sh", "-c", "touch /etc/frp/frpc.toml && /usr/bin/frpc -c /etc/frp/frpc.toml" ]