FROM ubuntu:latest as builder

WORKDIR /usr/bin/xray/
ADD ./script/install .

RUN apt-get update
RUN apt-get install -y curl unzip

ENV XRAY_BINARY 1.4.2
ENV VERSION 5.1.0

RUN bash ./install-xray.sh
RUN bash ./install-geoip.sh

FROM alpine:latest

COPY --from=builder /usr/bin/xray/xray /usr/bin/xray/
COPY --from=builder /usr/bin/xray/geoip.dat /usr/bin/xray/
COPY --from=builder /usr/bin/xray/geosite.dat /usr/bin/xray/
# COPY config.json /etc/xray/config.json # comment out from original

RUN set -ex && \
    apk --no-cache add ca-certificates vim jq && \
    mkdir /var/log/xray/ &&\
    chmod +x /usr/bin/xray/xray

ENV PATH /usr/bin/xray:$PATH

# RUN apk add py-pip libsodium
# # for centos 7 upgrade
# RUN pip install --upgrade pip
# RUN pip install https://github.com/shadowsocks/shadowsocks/archive/master.zip -U

EXPOSE 22
EXPOSE 3389
EXPOSE 3389/udp
EXPOSE 12345
EXPOSE 12345/udp

ENV VLESS_PORT='12345'

ENV SS='{"protocol":"shadowsocks","listen":"0.0.0.0","port":3389,"settings":{"email":"ss@xray.com","method":"aes-256-gcm","password":"0x0x0x0x","network":"tcp,udp"}}'

# https://www.v2fly.org/config/protocols/vless.html#inboundconfigurationobject
ENV CLIENTS='[{"id":"f2707fb2-70fa-6b38-c9b2-81d6f1efa323","level":0, "email":"vless@default.domain"}]'

# https://www.v2fly.org/config/inbounds.html
ENV INBOUNDS='[]'
# https://www.v2fly.org/config/outbounds.html
ENV OUTBOUNDS='[{"protocol":"freedom","settings":{}},{"protocol":"blackhole","settings":{},"tag":"blocked"}]'

# https://www.v2fly.org/config/routing.html#routingobject
ENV ROUTING='{"settings":{"rules":[{"inboundTag":["api"],"outboundTag":"api","type":"field"},{"type":"field","ip":["0.0.0.0/8","10.0.0.0/8","100.64.0.0/10","127.0.0.0/8","169.254.0.0/16","172.16.0.0/12","192.0.0.0/24","192.0.2.0/24","192.168.0.0/16","198.18.0.0/15","198.51.100.0/24","203.0.113.0/24","::1/128","fc00::/7","fe80::/10"],"outboundTag":"blocked"}]},"strategy":"rules"}'

# https://www.v2fly.org/config/transport.html#transportobject
ENV TRANSPORT='{}'

# https://www.v2fly.org/config/dns.html
ENV DNS='{}' 

# all configuration
ENV CONFIG='{}'

ENV LOGLEVEL='"warning"'

# copy pre-setting to workspace
WORKDIR /root/xray
COPY script/runtime script

# CMD ["/usr/sbin/sshd", "-D" ]
ENTRYPOINT ["script/start-xray.sh"]
