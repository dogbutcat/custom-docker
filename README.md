# docker-udpspeeder

## Change Log

> 2020-06

- update udpspeeder to 20190121.0
- update script

> 2019-03

- update udpspeeder

## Introducing

this image is based on alpine image & you need basic docker knowledge. You can get it from Google or [Git-book](https://yeasy.gitbooks.io/docker_practice/) for Chinese Learning. Then DON'T ASK ME! :D

## Word first

this is for udpspeeder usage. Build-in version is [Here](https://github.com/wangyu-/UDPspeeder/releases/20180806.0)

## How To Use It

> please replace command option with default entry point `speederv2_amd64` like what you need to add to end `docker run` as below

```sh
docker run -p 1234:1234/udp -p 5678:5678/udp dogbutcat/1.0-speederv2 \
          -s -l127.0.0.1:1234 -r127.0.0.1:5678 -f1:2 -k "passwds" --mode 0
```

you can also replace the binary with append `speederv2_x86`, `speederv2_arm`, `speederv2_mips24kc_be`, `speederv2_mips24kc_le` to command

```sh
docker run -p 1234:1234/udp -p 5678:5678/udp dogbutcat/1.0-speederv2 speederv2_x86 \
          -s -l127.0.0.1:1234 -r127.0.0.1:5678 -f1:2 -k "passwds" --mode 0
```

## Caveats

For several days' testing, if you need to change NAT(Network Address Translation) type, MUST work in `host` network mode while docker bridge network is also working in NAT - [Helpful Link](http://blog.daocloud.io/docker-bridge/).

That's explains why NAT type after docker would be `Symmetric` type
