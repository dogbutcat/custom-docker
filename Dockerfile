FROM ubuntu:latest AS builder

WORKDIR /usr/bin/xray/
ADD ./script/install .

RUN apt-get update && \
    apt-get install -y curl unzip && \
    rm -rf /var/lib/apt/lists/*

ENV XRAY_BINARY=v26.3.27
ENV VERSION=7.1.0

RUN bash ./install-xray.sh
RUN bash ./install-geoip.sh
RUN bash ./install-scanner.sh
RUN touch /usr/bin/xray/RealiTLScanner

FROM alpine:latest

COPY --from=builder /usr/bin/xray/xray /usr/bin/xray/
COPY --from=builder /usr/bin/xray/geoip.dat /usr/bin/xray/
COPY --from=builder /usr/bin/xray/geosite.dat /usr/bin/xray/
COPY --from=builder /usr/bin/xray/RealiTLScanner /usr/bin/xray/

RUN set -ex && \
    apk --no-cache add ca-certificates vim jq libc6-compat && \
    mkdir /var/log/xray/ &&\
    chmod +x /usr/bin/xray/xray && \
    chmod +x /usr/bin/xray/RealiTLScanner 2>/dev/null || true

ENV PATH="/usr/bin/xray:$PATH"

EXPOSE 443
EXPOSE 443/udp
EXPOSE 8443
EXPOSE 8443/udp

# ======== Quick ENV Configuration ========
# These ENVs build a 2-inbound config automatically when INBOUNDS is not set.
# Set INBOUNDS directly to override everything below.

# --- Shared ---
ENV CLIENTS='[{"id":"f2707fb2-70fa-6b38-c9b2-81d6f1efa323","level":0,"email":"vless@default.domain"}]'

# --- Inbound 1: VLESS + Reality (direct connect, GFW bypass) ---
ENV VLESS_PORT='443'
ENV REALITY_DEST='www.microsoft.com:443'
ENV REALITY_SNI='www.microsoft.com'
ENV REALITY_PRIVATE_KEY=''
ENV REALITY_SHORT_ID=''

# --- Inbound 2: VLESS Encryption (CDN / relay / non-TLS) ---
# 留空=自动生成 ML-KEM-768 Post-Quantum 密钥对；给定完整 decryption 字符串=直接用
ENV VLESSENC_PORT='8443'
ENV VLESSENC_KEY=''
# tcp (默认) | ws | ws:/path | grpc | grpc:serviceName | xhttp | xhttp:/path
ENV VLESSENC_NETWORK='tcp'

# --- Legacy: Shadowsocks inbound (set to empty to disable) ---
ENV SS=''

# ======== Advanced Override ========
# Set these to override the auto-built config entirely
ENV INBOUNDS='[]'
ENV OUTBOUNDS='[{"protocol":"freedom","settings":{},"tag":"direct"},{"protocol":"blackhole","settings":{},"tag":"blocked"}]'
ENV ROUTING='{"settings":{"rules":[{"inboundTag":["api"],"outboundTag":"api","type":"field"},{"type":"field","ip":["0.0.0.0/8","10.0.0.0/8","100.64.0.0/10","127.0.0.0/8","169.254.0.0/16","172.16.0.0/12","192.0.0.0/24","192.0.2.0/24","192.168.0.0/16","198.18.0.0/15","198.51.100.0/24","203.0.113.0/24","::1/128","fc00::/7","fe80::/10"],"outboundTag":"blocked"}]},"strategy":"rules"}'
ENV TRANSPORT='{}'
ENV DNS='{}'
ENV CONFIG='{}'
ENV LOGLEVEL='"warning"'

# copy pre-setting to workspace
WORKDIR /root/xray
COPY script/runtime script
RUN chmod +x script/scan-sni.sh script/start-xray.sh script/entrypoint.sh && \
    ln -s /root/xray/script/scan-sni.sh /usr/local/bin/scan-sni

ENTRYPOINT ["script/entrypoint.sh"]
