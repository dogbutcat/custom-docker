# docker-sshd-shadowsocks

![Docker Pulls](https://img.shields.io/docker/pulls/dogbutcat/docker-sshd-shadowsocks)

## V2ray/Xray version in release tag

- 5.0.0-xray Xray 1.4.0 (Xray, Penetrates Everything.) Custom (go1.16.2 linux/amd64)
- 4.4.0-v2ray V2Ray 4.32.1 (V2Fly, a community-driven edition of V2Ray.)
- 4.3.0-v2ray V2Ray 4.27.4 (V2Fly, a community-driven edition of V2Ray.)
- 4.2.1-v2ray V2Ray 4.23.4 (V2Fly, a community-driven edition of V2Ray.)
- 4.2.0-v2ray V2Ray 4.23.2 (V2Fly, a community-driven edition of V2Ray.)
- 4.1.0-v2ray V2Ray 4.22.1 (V2Fly, a community-driven edition of V2Ray.)
- 4.0.1-v2ray V2Ray 4.18.0 (Po) 20190228

## Change Log

> 2021-03

- migrate from v2ray to xray super type of v2ray/v2fly
- better support vless+xtls, from test stage, speedtest upgrade up to 3x of my vmess+ws
- mac client recommand [Qv2ray][qv2ray]

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

  support `SS`, `VMESS_PORT`,`CLIENTS`, `INBOUNDS`, ~~`INBOUND_DETOUR`~~, `OUTBOUNDS`, ~~`OUTBOUND_DETOUR`~~, `ROUTING`, `TRANSPORT`, `CONFIG`, all these above is in JSON format, and override sequence by `VMESS_PORT`=`CLIENTS`=`SS`<`INBOUNDS`=`OUTBOUNDS`=`ROUTING`=`TRANSPORT`<`CONFIG`

#### **VMESS_PORT**

this is for default vmess port setting, support offical format exclude `env:variable`

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
      - INBOUNDS=[{"port":"1800", "listen":"0.0.0.0", "protocol":"vmess","settings":{"clients":[{"id":"f2707fb2-70fa-6b38-c9b2-81d6f1efa323","level":1,"alterId":100, "email":"vmess@default.domain"}]},"streamSettings":{"network":"tcp"}},{"protocol":"shadowsocks","listen":"0.0.0.0","port":3389,"settings":{"email":"ss@v2ray.com","method":"aes-256-gcm","password":"0x0x0x0x","network":"tcp,udp"}}]
      #- CONFIG={"log":{"access":"/var/log/v2ray/access.log","error":"/var/log/v2ray/error.log","loglevel":"warning"},"inbounds":[{"port":"env:VMESS_PORT", "listen":"0.0.0.0", "protocol":"vmess","settings":{"clients":[{"id":"f2707fb2-70fa-6b38-c9b2-81d6f1efa323","level":1,"alterId":100, "email":"vmess@default.domain"}]},"streamSettings":{"network":"tcp"}},{"protocol":"shadowsocks","listen":"0.0.0.0","port":3389,"settings":{"email":"ss@v2ray.com","method":"aes-256-gcm","password":"0x0x0x0x","network":"tcp,udp"}}],"outbounds":[{"protocol":"freedom","settings":{}},{"protocol":"blackhole","settings":{},"tag":"blocked"}],"routing":{"strategy":"rules","settings":{"rules":[{"type":"field","ip":["0.0.0.0/8","10.0.0.0/8","100.64.0.0/10","127.0.0.0/8","169.254.0.0/16","172.16.0.0/12","192.0.0.0/24","192.0.2.0/24","192.168.0.0/16","198.18.0.0/15","198.51.100.0/24","203.0.113.0/24","::1/128","fc00::/7","fe80::/10"],"outboundTag":"blocked"}]}},"transport":{},"dns":{"network":"tcp","address":"1.1.1.1","port":53}}
    ports:
      - "1800:1800"
      - "3389:3389"
```

## Problems may happen

- can't connect
  - check firewall on server
  - check uuid or alterId is same on server and client
  - check docker log for v2ray start normally

[qv2ray]: https://github.com/Qv2ray/Qv2ray
[tls-discussion]: https://github.com/v2ray/discussion/issues/704
[vless]: https://www.v2fly.org/config/protocols/vless.html#vless
