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
	if [ "$INBOUND" = '{}' ];then
		INBOUND='{"port":12345,"protocol":"vmess","settings":{"clients":'${CLIENTS}'},"streamSettings":{"network":"tcp"}}'
	fi
	if [ "$INBOUND_DETOUR" = '[]' ];then
		INBOUND_DETOUR="[${SS}]"
	fi
}

function output_config {
	if [ "$CONFIG" = '{}' ];then
		CONFIG='{"log":{"access":"/var/log/v2ray/access.log","error":"/var/log/v2ray/error.log","loglevel":"warning"},"inbound":'"${INBOUND}"',"outbound":'"${OUTBOUND}"',"inboundDetour":'"${INBOUND_DETOUR}"',"outboundDetour":'"${OUTBOUND_DETOUR}"',"routing":'"${ROUTING}"',"transport":'"${TRANSPORT}"'}'
	fi
	
	if [ -e /opt/v2ray/config.json ];then
		CONFIG=$(</opt/v2ray/config.json)
	else
		mkdir -p /opt/v2ray
		echo $CONFIG>/opt/v2ray/config.json
	fi
	echo Main Clients:
	echo ${CLIENTS}|jq .
	echo -e '\n'
	echo Current Config:
	echo ${CONFIG}|jq .
}

function start_v2ray {
	v2ray --config=/opt/v2ray/config.json &
}

CLIENTS=$(replace_default_client $CLIENTS)
init_variables
output_config
start_v2ray

function finish {
	kPID=$(ps -ef|grep -v grep|grep -v start|awk '{print $1}')
	echo "killing PID: $kPID"
	kill -9 $kPID
}
trap finish SIGTERM SIGINT SIGQUIT
while sleep 3600 && wait $!;do :;done # uncomment this at end