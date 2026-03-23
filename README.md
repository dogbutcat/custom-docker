# docker-sshd-shadowsocks

![Docker Pulls](https://img.shields.io/docker/pulls/dogbutcat/docker-sshd-shadowsocks)

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

## Introducing

this image is based on centos image & you need basic docker knowledge. You can get it from Google or [Git-book](https://yeasy.gitbooks.io/docker_practice/) for Chinese Learning. Then DON'T ASK ME! :D

## Word first

this docker image is for **MY-SELF** usage for quick deploy, no special support. ~~for some reason, I use config file instead of cli named ss.json through, so I referred this [Dockerize an SSH service](https://docs.docker.com/engine/examples/running_ssh_service/#build-an-eg_sshd-image), using python version shadowsocks from pip install which also support udp transfer. You can also login in the container change sysctl.conf with root:root, if your host support BBR algorithm contribute by Google.~~

## ~~How To Use It~~

- ~~standard start~~

    ~~docker run -p 22:22 -p 3389:3389 -p 3389:3389/udp
        -d dogbutcat/docker-sshd-shadowsocks~~

- ~~set up with environments~~

  > as v2ray's shadowsocks setting not directly compatible with original one, some description is deprecated.

  ~~current support ```ROOT_PW, SS_JSON, WORKER_NUM```~~

  1. ~~custom root password (default root password is ```root```)~~

        ~~docker run -p 22:22 -p 3389:3389 -p 3389:3389/udp
            --env ROOT_PW=1233
            -d dogbutcat/docker-sshd-shadowsocks~~

  1. ~~custom $$ config json (**REMENBER to open port transfer with custom port**)~~

        ~~docker run -p 22:22 -p 5666:5666 -p 5666:5666/udp
            --env SS_JSON='{"server":"0.0.0.0","server_port":5666,"local_port":1080,
                            "password":"0x0x0x0x","timeout":600,"method":"aes-256-cfb"}'
            -d dogbutcat/docker-sshd-shadowsocks~~

  1. ~~custom $$ worker~~

        ~~docker run -p 22:22 -p 3389:3389 -p 3389:3389/udp
            --env WORKER_NUM=0
            -d dogbutcat/docker-sshd-shadowsocks~~

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
  docker run --rm --network host dogbutcat/docker-sshd-shadowsocks:7.0.0-xray scan-sni

  # Scan specific subnet
  docker run --rm --network host <image> scan-sni -addr 1.2.3.0/24

  # Or exec into running container (manual subnet required)
  docker exec <container> scan-sni -addr 1.2.3.0/24
  ```

#### **SS**

this is special for running shadowsocks in v2ray, work in [INBOUNDS](#inbounds) segment.

#### **CLIENTS**

this is quick setting for clients part in [INBOUND](#inbound), it will be override by [INBOUND](#inbound) setting.

> the uuid `f2707fb2-70fa-6b38-c9b2-81d6f1efa323` is for default packing option, will be force override by a random uuid generated from kernel, please don't use it for open source safty. Sorry for inconvience.

#### **INBOUNDS**

refer to v2ray's inbound segment, offical reference [here](https://www.v2ray.com/chapter_02/02_protocols.html), maybe already blocked by GFW.

#### ~~**INBOUND_DETOUR**~~

#### **OUTBOUNDS**

#### ~~**OUTBOUND_DETOUR**~~

#### **ROUTING**

#### **TRANSPORT**

all these refer above

#### **CONFIG**

this is for the hole v2ray json config, you can place your setting here, or bind the container path `/opt/v2ray/` to your local one with `config.json` in it which support format is v2ray 3.x or 4.x

> ⚠️Better expirence with Compose or Stack.

```yaml
version: '2'

services:

  v2ray:
    image: dogbutcat/docker-sshd-shadowsocks
    environment:
      - INBOUNDS=[{"port":"1800", "listen":"0.0.0.0", "protocol":"vmess","settings":{"clients":[{"id":"f2707fb2-70fa-6b38-c9b2-81d6f1efa323","level":1, "email":"vmess@default.domain"}]},"streamSettings":{"network":"tcp"}},{"protocol":"shadowsocks","listen":"0.0.0.0","port":3389,"settings":{"email":"ss@v2ray.com","method":"aes-256-gcm","password":"0x0x0x0x","network":"tcp,udp"}}]
      #- CONFIG={"log":{"access":"/var/log/v2ray/access.log","error":"/var/log/v2ray/error.log","loglevel":"warning"},"inbounds":[{"port":"env:VMESS_PORT", "listen":"0.0.0.0", "protocol":"vmess","settings":{"clients":[{"id":"f2707fb2-70fa-6b38-c9b2-81d6f1efa323","level":1, "email":"vmess@default.domain"}]},"streamSettings":{"network":"tcp"}},{"protocol":"shadowsocks","listen":"0.0.0.0","port":3389,"settings":{"email":"ss@v2ray.com","method":"aes-256-gcm","password":"0x0x0x0x","network":"tcp,udp"}}],"outbounds":[{"protocol":"freedom","settings":{}},{"protocol":"blackhole","settings":{},"tag":"blocked"}],"routing":{"strategy":"rules","settings":{"rules":[{"type":"field","ip":["0.0.0.0/8","10.0.0.0/8","100.64.0.0/10","127.0.0.0/8","169.254.0.0/16","172.16.0.0/12","192.0.0.0/24","192.0.2.0/24","192.168.0.0/16","198.18.0.0/15","198.51.100.0/24","203.0.113.0/24","::1/128","fc00::/7","fe80::/10"],"outboundTag":"blocked"}]}},"transport":{},"dns":{"network":"tcp","address":"1.1.1.1","port":53}}
    ports:
      - "1800:1800"
      - "3389:3389"
```

## Problems may happen

- can't connect
  - basicly check your time is sync with server
  - check firewall on server
  - check uuid is same on server and client
  - check docker log for v2ray start normally

[qv2ray]: https://github.com/Qv2ray/Qv2ray
[tls-discussion]: https://github.com/v2ray/discussion/issues/704
[vless]: https://www.v2fly.org/config/protocols/vless.html#vless
