FROM localhost:8080/public_mirror/ubuntu:25.04

COPY aiursoft-source.list /aiursoft-source.list
COPY huawei-source.list /huawei-sources.list

RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

RUN if curl -f http://mirrors.aiursoft.com/; then \
        echo "Using aiursoft sources"; \
        cp /aiursoft-source.list /etc/apt/sources.list && \
        apt update; \
    elif curl -f http://mirrors.huaweicloud.com/; then \
        echo "Using huaweicloud sources"; \
        cp /huawei-sources.list /etc/apt/sources.list && \
        apt update; \
    else \
        echo "Using default ubuntu sources"; \
    fi

#RUN rm /etc/apt/sources.list.d/ubuntu.sources && apt modernize-sources -y && rm /etc/apt/sources.list.bak
RUN apt modernize-sources -y && rm /etc/apt/sources.list.bak

RUN apt upgrade -y
