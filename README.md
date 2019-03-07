# docker-sshd-shadowsocks

## Change Log

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

  support `SS, CLIENTS, INBOUND, INBOUND_DETOUR, OUTBOUND, OUTBOUND_DETOUR, ROUTING, TRANSPORT, CONFIG`, all these above is in JSON format, and override sequence by `CLIENTS`=`SS`<`INBOUND`=`INBOUND_DETOUR`=`OUTBOUND`=`OUTBOUND_DETOUR`=`ROUTING`=`TRANSPORT`<`CONFIG`

#### **SS**

this is special for running shadowsocks in v2ray, work in [INBOUND_DETOUR](#inbound_detour) segment as main entry([INBOUND](#inbound)) is for vmess.

#### **CLIENTS**

this is quick setting for clients part in [INBOUND](#inbound), it will be override by [INBOUND](#inbound) setting.

> the uuid `f2707fb2-70fa-6b38-c9b2-81d6f1efa323` is for default packing option, will be force override by a random uuid generated from kernel, please don't use it for open source safty. Sorry for inconvience.

#### **INBOUND**

refer to v2ray's inbound segment, offical reference [here](https://www.v2ray.com/chapter_02/02_protocols.html), maybe already blocked by GFW.

#### **INBOUND_DETOUR**

#### **OUTBOUND**

#### **OUTBOUND_DETOUR**

#### **ROUTING**

#### **TRANSPORT**

all these refer above

#### **CONFIG**

this is for the hole v2ray json config, you can place your setting here, or bind the container path `/opt/v2ray/` to your local one with `config.json` in it.

> ⚠️Better expirence with Compose or Stack.

## Problems may happen

- can't connect
  - check firewall on server
  - check uuid or alterId is same on server and client
  - check docker log for v2ray start normally