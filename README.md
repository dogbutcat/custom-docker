# docker-sshd-shadowsocks

![Docker Pulls](https://img.shields.io/docker/pulls/ghcr.io/dogbutcat/docker-sshd-shadowsocks:7.0.0-xray)

## V2ray/Xray version in release tag

- 7.0.0-xray Xray 26.2.6 (Xray, Penetrates Everything.) 12ee51e (go1.25.7 linux/amd64)
- 6.0.0-xray Xray 25.1.30 (Xray, Penetrates Everything.) 0a8470c (go1.23.5 linux/amd64)
- 5.9.0-xray Xray 1.8.6 (Xray, Penetrates Everything.) Custom (go1.21.4 linux/amd64)
- 5.7.0-xray Xray 1.7.5 (Xray, Penetrates Everything.) Custom (go1.20 linux/amd64)
- 5.6.0-xray Xray 1.6.1 (Xray, Penetrates Everything.) Custom (go1.19.2 linux/amd64)
- 5.5.0-xray Xray 1.5.5 (Xray, Penetrates Everything.) Custom (go1.18.1 linux/amd64)
- 5.4.0-xray Xray 1.5.3 (Xray, Penetrates Everything.) Custom (go1.17.6 linux/amd64)
- 5.3.0-xray Xray 1.5.2 (Xray, Penetrates Everything.) Custom (go1.17.5 linux/amd64)
- 5.2.1-xray Xray 1.4.5 (Xray, Penetrates Everything.) Custom (go1.17.1 linux/amd64)
- 5.2.0-xray Xray 1.4.3 (Xray, Penetrates Everything.) 7246001 (go1.17.1 linux/amd64)
- 5.1.0-xray Xray 1.4.2 (Xray, Penetrates Everything.) Custom (go1.16.2 linux/amd64)
- 5.0.0-xray - 5.0.2-xray Xray 1.4.0 (Xray, Penetrates Everything.) Custom (go1.16.2 linux/amd64)

<details>
<summary>Former</summary>

- 4.4.0-v2ray V2Ray 4.32.1 (V2Fly, a community-driven edition of V2Ray.)
- 4.3.0-v2ray V2Ray 4.27.4 (V2Fly, a community-driven edition of V2Ray.)
- 4.2.1-v2ray V2Ray 4.23.4 (V2Fly, a community-driven edition of V2Ray.)
- 4.2.0-v2ray V2Ray 4.23.2 (V2Fly, a community-driven edition of V2Ray.)
- 4.1.0-v2ray V2Ray 4.22.1 (V2Fly, a community-driven edition of V2Ray.)
- 4.0.1-v2ray V2Ray 4.18.0 (Po) 20190228

</details>

## Change Log

> 2026-03-24

- **密钥自动管理**: Reality 和 VLESS Encryption 密钥均支持给定直接用、留空自动生成并持久化
- **VLESS Encryption**: 使用 `xray vlessenc` 生成 ML-KEM-768 Post-Quantum 密钥对，客户端 encryption 字符串自动保存到 `vlessenc.enc`
- **Reality 密钥**: 使用 `xray x25519` 自动生成，公钥和 shortId 在启动日志中输出
- xray v26+ flow 自动注入: Reality 和 VLESS Encryption 入站的 clients 自动添加 `flow:xtls-rprx-vision`
- 移除 `VLESSENC_MODE/TICKET/PADDING` ENV（现在由 `xray vlessenc` 整体生成）
- nginx 示例改为 `network_mode: host`，与 xray 直接通过 `127.0.0.1` 互通
- GeoIP2 模块默认注释（需手动编译匹配版本的 .so + 下载 mmdb 文件后启用）

> 2026-03-23

- xray bump to 26.2.6
- New `REALITY_DEST/SNI/PRIVATE_KEY/SHORT_ID` ENVs for one-line Reality setup
- Global `DECRYPTION` injection into custom `INBOUNDS` (replaces all `"decryption":"none"`)
- Integrated [RealiTLScanner](https://github.com/XTLS/RealiTLScanner) v0.2.1 for Reality SNI scanning
- Dockerfile: merged RUN layers, removed `EXPOSE 22`, added `libc6-compat`, multi-arch support in install scripts
- start-xray.sh: POSIX-compatible, PID-based graceful shutdown, debug-only config printing
- Separate volume paths: `/opt/xray/keys` for keys, `/opt/xray/config` for config.json override
- Default SS disabled (set `SS` ENV to re-enable)

> 2025-02

- xray bump to 25.1.30

> 2022-12

- xray bump to 1.6.1

> 2022-05

- xray bump to 1.5.5

> 2022-02

- xray bump to 1.5.3

> 2022-01

- xray bump to 1.5.2
- default template disable port env passthrough as start up failure

> 2021-04

- xray bump to 1.4.2

> 2021-03

- migrate from v2ray to xray super type of v2ray/v2fly
- better support vless+xtls, from test stage, speedtest upgrade up to 3x of my vmess+ws
- mac client recommand [Qv2ray][qv2ray]

<details>
<summary>Former</summary>

> 2020-08

- upgrade v2ray install script and bump binary to 4.27.4 for [VLESS][vless] support

> 2020-06

- v2ray default tls handshake, relative discussion [HERE][tls-discussion]

> 2020-01

- integrate v2ray offical build script to upgrade v2ray

> 2019-03-08

- upgrade config structure to v2ray 4.x

> 2019-03

- migrate to v2ray for integrate shadowsock and v2ray inherit from [v2ray offical image](https://hub.docker.com/r/v2ray/official)

> 2019-02

- deprecate openssh service in alpine branch for significant deployment size and usage memory reduction

> 2019-01

- fix no ssh key to start open-ssh server

> 2018-11

- upgrade to centos 7
- support aes-*-gcm encryption

</details>

## Quick Start

  ```yaml
  services:
    v2ray:
      image: ghcr.io/dogbutcat/docker-sshd-shadowsocks:7.0.0-xray
      network_mode: host
      environment:
        - VLESS_PORT=443
        - REALITY_DEST=n.sni-347-default.ssl.fastly.net:443
        - REALITY_SNI=n.sni-347-default.ssl.fastly.net
        - CLIENTS=[{"id":"your-uuid-here"}]
      volumes:
        - ./keys:/opt/xray/keys
      restart: unless-stopped
  ```

  > 启动后 `docker logs` 查看 Client Config Summary 获取客户端配置所需的公钥、shortId、encryption 字符串。

### environment description

  support environment variables in JSON format to dynamically configure Xray.

  **Quick Setup ENVs** (auto-build inbound config when `INBOUNDS` is not set):

  | ENV | Default | Description |
  |-----|---------|-------------|
  | `CLIENTS` | (default UUID) | Shared client list for all inbounds |
  | `VLESS_PORT` | `443` | VLESS + Reality inbound port |
  | `REALITY_DEST` | `www.microsoft.com:443` | Reality target destination |
  | `REALITY_SNI` | `www.microsoft.com` | Reality server name |
  | `REALITY_PRIVATE_KEY` | (auto-generate) | Reality X25519 私钥。留空=自动生成并持久化，给定=直接用 |
  | `REALITY_SHORT_ID` | (auto-generate) | Reality short ID。留空=自动生成 |
  | `VLESSENC_PORT` | `8443` | VLESS Encryption inbound port |
  | `VLESSENC_KEY` | (auto-generate) | VLESS Encryption 完整 decryption 字符串。留空=自动生成 ML-KEM-768 Post-Quantum 并持久化，给定=直接用 |
  | `VLESSENC_NETWORK` | `tcp` | 传输层协议：`tcp` / `ws` / `ws:/custom-path` / `grpc` / `grpc:serviceName` |
  | `SS` | (empty) | Shadowsocks inbound JSON (empty=disabled) |

  **Advanced Override ENVs** (override auto-built config):

  | ENV | Description |
  |-----|-------------|
  | `INBOUNDS` | Full inbounds JSON array (overrides all Quick Setup ENVs above) |
  | `OUTBOUNDS` | Full outbounds JSON array |
  | `ROUTING` | Full routing JSON |
  | `TRANSPORT` | Global transport settings |
  | `DNS` | DNS settings |
  | `CONFIG` | Full Xray config JSON (overrides everything) |
  | `LOGLEVEL` | `"warning"` (default), set `"debug"` to print full config on startup |

  Override priority: `Quick Setup ENVs` < `INBOUNDS/OUTBOUNDS/ROUTING` < `CONFIG` < `/opt/xray/config/config.json` file

  **Volume Mounts:**

  | Container Path | Purpose |
  |---|---|
  | `/opt/xray/keys` | 自动生成的密钥持久化目录 |
  | `/opt/xray/config` | Optional `config.json` to override entire config |

  **持久化文件 (`/opt/xray/keys/`)：**

  | File | Content |
  |---|---|
  | `vlessenc.key` | VLESS Encryption 完整 decryption 字符串（服务端用） |
  | `vlessenc.enc` | VLESS Encryption 完整 encryption 字符串（**客户端用，填入 mihomo/v2rayN**） |
  | `reality.key` | Reality X25519 私钥 |
  | `reality.shortid` | Reality shortId |

  > 启动日志会输出 Reality 公钥、shortId、以及 Client encryption 字符串，直接复制到客户端配置即可。

### Reality SNI Scanner

  Integrated [RealiTLScanner](https://github.com/XTLS/RealiTLScanner) to find suitable Reality destinations on your VPS subnet:

  ```bash
  # Auto-detect VPS IP, scan /24 subnet (requires --network host)
  docker run --rm --network host ghcr.io/dogbutcat/docker-sshd-shadowsocks:7.0.0-xray scan-sni

  # Scan specific subnet
  docker run --rm --network host ghcr.io/dogbutcat/docker-sshd-shadowsocks:7.0.0-xray scan-sni -addr 1.2.3.0/24

  # Or exec into running container (manual subnet required)
  docker exec <container> scan-sni -addr 1.2.3.0/24
  ```

### Xray 工具命令

  通过 entrypoint 直接调用 xray 子命令：

  ```bash
  # 生成 VLESS Encryption 密钥对 (ML-KEM-768 Post-Quantum)
  docker run --rm ghcr.io/dogbutcat/docker-sshd-shadowsocks:7.0.0-xray xray vlessenc

  # 生成 Reality X25519 密钥对
  docker run --rm ghcr.io/dogbutcat/docker-sshd-shadowsocks:7.0.0-xray xray x25519

  # 从私钥推导公钥 (v26: Password 字段即公钥)
  docker run --rm ghcr.io/dogbutcat/docker-sshd-shadowsocks:7.0.0-xray xray x25519 -i "<private_key>"
  ```

### Mihomo 客户端配置示例

  以下字段从 `docker logs` 日志的 **Client Config Summary** 段中获取。

  **Reality 直连：**

  ```yaml
  proxies:
    - name: reality
      type: vless
      server: <VPS_IP>
      port: 443                # VLESS_PORT
      uuid: <your-uuid>
      flow: xtls-rprx-vision
      network: tcp
      tls: true
      udp: true
      servername: <REALITY_SNI>
      reality-opts:
        public-key: <日志 Public Key>
        short-id: <日志 Short ID>
  ```

  **VLESS Encryption 直连 (TCP)：**

  ```yaml
  proxies:
    - name: vlessenc-tcp
      type: vless
      server: <VPS_IP>
      port: 8443               # VLESSENC_PORT
      uuid: <your-uuid>
      flow: xtls-rprx-vision
      encryption: <日志 Client Encryption>
      network: tcp
      udp: true
  ```

  **VLESS Encryption + CDN (WebSocket)：**

  ```yaml
  proxies:
    - name: vlessenc-ws
      type: vless
      server: <cf-domain>      # CloudFlare 域名
      port: 443
      uuid: <your-uuid>
      encryption: <日志 Client Encryption>
      network: ws
      tls: true
      udp: true
      servername: <cf-domain>
      ws-opts:
        path: /vless-ws        # 与 VLESSENC_NETWORK=ws:/vless-ws 对应
        headers:
          Host: <cf-domain>
  ```

  **VLESS Encryption + CDN (gRPC)：**

  ```yaml
  proxies:
    - name: vlessenc-grpc
      type: vless
      server: <cf-domain>
      port: 443
      uuid: <your-uuid>
      encryption: <日志 Client Encryption>
      network: grpc
      tls: true
      udp: true
      servername: <cf-domain>
      grpc-opts:
        grpc-service-name: my-svc  # 与 VLESSENC_NETWORK=grpc:my-svc 对应
  ```

## Troubleshooting

- 连不上？
  - 检查服务器和客户端时间是否同步
  - 检查服务器防火墙端口
  - 检查 UUID 客户端和服务端一致
  - `docker logs` 查看 xray 是否正常启动

[qv2ray]: https://github.com/Qv2ray/Qv2ray
[tls-discussion]: https://github.com/v2ray/discussion/issues/704
[vless]: https://www.v2fly.org/config/protocols/vless.html#vless
