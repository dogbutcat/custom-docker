FROM ubuntu:latest as builder

RUN apt-get update
RUN apt-get install curl -y
RUN curl -L -o /tmp/go.sh https://install.direct/go.sh
RUN chmod +x /tmp/go.sh
RUN /tmp/go.sh

FROM alpine:latest

LABEL maintainer "Darian Raymond <admin@v2ray.com>"


COPY --from=builder /usr/bin/v2ray/v2ray /usr/bin/v2ray/
COPY --from=builder /usr/bin/v2ray/v2ctl /usr/bin/v2ray/
COPY --from=builder /usr/bin/v2ray/geoip.dat /usr/bin/v2ray/
COPY --from=builder /usr/bin/v2ray/geosite.dat /usr/bin/v2ray/
# COPY config.json /etc/v2ray/config.json # comment out from original

RUN set -ex && \
    apk --no-cache add ca-certificates vim jq && \
    mkdir /var/log/v2ray/ &&\
    chmod +x /usr/bin/v2ray/v2ctl && \
    chmod +x /usr/bin/v2ray/v2ray

ENV PATH /usr/bin/v2ray:$PATH

# RUN apk add py-pip libsodium
# # for centos 7 upgrade
# RUN pip install --upgrade pip
# RUN pip install https://github.com/shadowsocks/shadowsocks/archive/master.zip -U

EXPOSE 22
EXPOSE 3389
EXPOSE 3389/udp
EXPOSE 12345
EXPOSE 12345/udp

ENV VMESS_PORT='12345'

ENV SS='{"protocol":"shadowsocks","listen":"0.0.0.0","port":3389,"settings":{"email":"ss@v2ray.com","method":"aes-256-gcm","password":"0x0x0x0x","network":"tcp,udp"}}'

# https://www.v2ray.com/chapter_02/protocols/vmess.html#userobject
ENV CLIENTS='[{"id":"f2707fb2-70fa-6b38-c9b2-81d6f1efa323","level":1,"alterId":100, "email":"vmess@default.domain"}]'

# https://www.v2ray.com/chapter_02/02_protocols.html
ENV INBOUNDS='[]'
ENV OUTBOUNDS='[{"protocol":"freedom","settings":{}},{"protocol":"blackhole","settings":{},"tag":"blocked"}]'

# https://www.v2ray.com/chapter_02/03_routing.html
ENV ROUTING='{"strategy":"rules","settings":{"rules":[{"type":"field","ip":["0.0.0.0/8","10.0.0.0/8","100.64.0.0/10","127.0.0.0/8","169.254.0.0/16","172.16.0.0/12","192.0.0.0/24","192.0.2.0/24","192.168.0.0/16","198.18.0.0/15","198.51.100.0/24","203.0.113.0/24","::1/128","fc00::/7","fe80::/10"],"outboundTag":"blocked"}]}}'

# https://www.v2ray.com/chapter_02/05_transport.html
ENV TRANSPORT='{}'

# TODO: deal with custom dns config
# ENV DNS='{}' 

# all configuration
ENV CONFIG='{}'

# copy pre-setting to workspace
WORKDIR /root/v2ray
COPY script script

# CMD ["/usr/sbin/sshd", "-D" ]
ENTRYPOINT ["script/start-v2ray.sh"]
