# docker-sshd-shadowsocks

## Change Log

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

this docker image is for **MY-SELF** usage for quick deploy, no special support, for some reason, I use config file instead of cli named ss.json through, so I referred this [Dockerize an SSH service](https://docs.docker.com/engine/examples/running_ssh_service/#build-an-eg_sshd-image), using python version shadowsocks from pip install which also support udp transfer. You can also login in the container change sysctl.conf with root:root, if your host support BBR algorithm contribute by Google.

## How To Use It

* standard start

        docker run -p 22:22 -p 3389:3389 -p 3389:3389/udp
            -d dogbutcat/docker-sshd-shadowsocks

* set up with environments

  current support ```ROOT_PW, SS_JSON, WORKER_NUM```

  1. custom root password (default root password is ```root```)

            docker run -p 22:22 -p 3389:3389 -p 3389:3389/udp
                --env ROOT_PW=1233
                -d dogbutcat/docker-sshd-shadowsocks

  1. custom $$ config json (**REMENBER to open port transfer with custom port**)

            docker run -p 22:22 -p 5666:5666 -p 5666:5666/udp
                --env SS_JSON='{"server":"0.0.0.0","server_port":5666,"local_port":1080,
                                "password":"0x0x0x0x","timeout":600,"method":"aes-256-cfb"}'
                -d dogbutcat/docker-sshd-shadowsocks

  1. custom $$ worker

            docker run -p 22:22 -p 3389:3389 -p 3389:3389/udp
                --env WORKER_NUM=0
                -d dogbutcat/docker-sshd-shadowsocks
