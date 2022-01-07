#!/bin/sh

DEFAULT_UUID='f2707fb2-70fa-6b38-c9b2-81d6f1efa323'

function replace_default_client {
	UUID=$(cat /proc/sys/kernel/random/uuid)
	flag=`echo $1|awk -v a="$DEFAULT_UUID" '{print match($0, a)}'`
	if [ $flag -gt 0 ];then
		# echo 'success';
		echo "${1/$DEFAULT_UUID/$UUID}"
	else
		# echo 'fail';
		echo $1;
	fi
}

function init_variables {
	if [ "$INBOUNDS" = '[]' ];then
		# INBOUNDS='[{"port":"env:VMESS_PORT", "listen":"0.0.0.0", "protocol":"vmess","settings":{"clients":'${CLIENTS}'},"streamSettings":{"network":"tcp"}},'${SS}']'
		INBOUNDS='[{"port":"1234", "listen":"0.0.0.0", "protocol":"vless","settings":{"clients":'${CLIENTS}',"decryption": "none"},"streamSettings":{"network":"tcp"}},'${SS}']'
	fi
}

function output_config {
	if [ "$CONFIG" = '{}' ];then
		if [ "$DNS" = '{}' ];then
			CONFIG='{"stats":{},"log":{"loglevel":'"${LOGLEVEL}"'},"api":{"tag":"api","services":["HandlerService","LoggerService","StatsService"]},"policy":{"levels":{"0":{"statsUserUplink":true,"statsUserDownlink":true},"1":{"statsUserUplink":true,"statsUserDownlink":true}},"system":{"statsInboundUplink":true,"statsInboundDownlink":true}},"inbounds":'"${INBOUNDS}"',"outbounds":'"${OUTBOUNDS}"',"routing":'"${ROUTING}"',"transport":'"${TRANSPORT}"'}'
		else
			CONFIG='{"stats":{},"log":{"loglevel":'"${LOGLEVEL}"'},"api":{"tag":"api","services":["HandlerService","LoggerService","StatsService"]},"policy":{"levels":{"0":{"statsUserUplink":true,"statsUserDownlink":true},"1":{"statsUserUplink":true,"statsUserDownlink":true}},"system":{"statsInboundUplink":true,"statsInboundDownlink":true}},"inbounds":'"${INBOUNDS}"',"outbounds":'"${OUTBOUNDS}"',"routing":'"${ROUTING}"',"transport":'"${TRANSPORT}"',"dns":'"${DNS}"'}'
		fi

		if [ -e /opt/xray/config.json ];then
			CONFIG=$(cat /opt/xray/config.json)
		fi
	fi

	mkdir -p /tmp
	echo $CONFIG>/tmp/config.json
	echo Main Clients:
	echo ${CLIENTS}|jq .
	echo -e '\n'
	echo Current Config:
	echo ${CONFIG}|jq .
}

function start_v2ray {
	xray --config=/tmp/config.json &
}

init_variables
CLIENTS=$(replace_default_client $CLIENTS)
output_config
start_v2ray

function finish {
	kPID=$(ps -ef|grep -v grep|grep -v start|awk '{print $1}')
	echo "killing PID: $kPID"
	kill -9 $kPID
}
trap finish SIGTERM SIGINT SIGQUIT
while sleep 3600 && wait $!;do :;done # uncomment this at end