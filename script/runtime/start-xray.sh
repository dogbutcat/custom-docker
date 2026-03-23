#!/bin/sh

DEFAULT_UUID='f2707fb2-70fa-6b38-c9b2-81d6f1efa323'
KEY_DIR='/opt/xray/keys'
KEY_FILE="${KEY_DIR}/vlessenc.key"
CONFIG_DIR='/opt/xray/config'
CONFIG_FILE="${CONFIG_DIR}/config.json"

# Replace default UUID with a random one for security
replace_default_client() {
	UUID=$(cat /proc/sys/kernel/random/uuid)
	flag=$(echo "$1" | awk -v a="$DEFAULT_UUID" '{print match($0, a)}')
	if [ "$flag" -gt 0 ]; then
		echo "${1/$DEFAULT_UUID/$UUID}"
	else
		echo "$1"
	fi
}

# Resolve VLESSENC_KEY=auto → generate or load persisted key
# Then assemble full DECRYPTION string from VLESSENC_* ENVs
resolve_decryption() {
	# Skip if no encryption requested
	if [ -z "$VLESSENC_KEY" ] || [ "$VLESSENC_KEY" = 'none' ]; then
		DECRYPTION='none'
		return
	fi

	# Auto-generate key if requested
	if [ "$VLESSENC_KEY" = 'auto' ]; then
		if [ -f "$KEY_FILE" ]; then
			VLESSENC_KEY=$(cat "$KEY_FILE")
			echo "Loaded VLESS Encryption key from $KEY_FILE"
		else
			echo "Auto-generating X25519 key pair..."
			KEY_OUTPUT=$(xray x25519 2>/dev/null)
			VLESSENC_KEY=$(echo "$KEY_OUTPUT" | grep 'Private' | awk '{print $NF}')
			VLESSENC_PUB=$(echo "$KEY_OUTPUT" | grep 'Public' | awk '{print $NF}')
			if [ -z "$VLESSENC_KEY" ]; then
				echo "warning: xray x25519 failed, VLESS Encryption disabled"
				DECRYPTION='none'
				return
			fi
			mkdir -p "$KEY_DIR"
			echo "$VLESSENC_KEY" > "$KEY_FILE"
			echo "$VLESSENC_PUB" > "${KEY_DIR}/vlessenc.pub"
			echo "Key saved to $KEY_FILE"
			echo "Public key (for client config): $VLESSENC_PUB"
		fi
	fi

	# Assemble: mlkem768x25519plus.MODE.TICKET.PADDING.KEY
	DECRYPTION="mlkem768x25519plus.${VLESSENC_MODE}.${VLESSENC_TICKET}.${VLESSENC_PADDING}.${VLESSENC_KEY}"
	echo "VLESS Encryption assembled: mlkem768x25519plus.${VLESSENC_MODE}.${VLESSENC_TICKET}.[padding].***"
}

# Build INBOUNDS from individual ENV vars if not explicitly set
init_variables() {
	if [ "$INBOUNDS" != '[]' ]; then
		# User provided custom INBOUNDS, apply global DECRYPTION injection
		if [ "$DECRYPTION" != 'none' ]; then
			INBOUNDS=$(echo "$INBOUNDS" | sed "s/\"decryption\":\"none\"/\"decryption\":\"${DECRYPTION}\"/g")
			echo "Injected DECRYPTION into custom INBOUNDS"
		fi
		return
	fi

	# --- Auto-build INBOUNDS from ENVs ---
	INBOUNDS='['

	# Inbound 1: VLESS + Reality (if REALITY_PRIVATE_KEY is set)
	# xray v26+: clients must have flow:xtls-rprx-vision
	if [ -n "$REALITY_PRIVATE_KEY" ]; then
		REALITY_CLIENTS=$(echo "$CLIENTS" | sed 's/}]/,"flow":"xtls-rprx-vision"}]/g' | sed 's/},/,"flow":"xtls-rprx-vision"},/g')
		INBOUNDS="${INBOUNDS}"'{"listen":"0.0.0.0","port":'${VLESS_PORT}',"protocol":"vless","settings":{"clients":'${REALITY_CLIENTS}',"decryption":"none"},"streamSettings":{"network":"tcp","security":"reality","realitySettings":{"show":false,"dest":"'${REALITY_DEST}'","xver":0,"serverNames":["'${REALITY_SNI}'"],"privateKey":"'${REALITY_PRIVATE_KEY}'","shortIds":["'${REALITY_SHORT_ID}'"]}}}'
	fi

	# Inbound 2: VLESS Encryption (if DECRYPTION is not none)
	# xray v26+: flow:xtls-rprx-vision 同样适用于 VLESS Encryption 入站
	if [ "$DECRYPTION" != 'none' ]; then
		[ "$INBOUNDS" != '[' ] && INBOUNDS="${INBOUNDS},"
		ENC_CLIENTS=$(echo "$CLIENTS" | sed 's/}]/,"flow":"xtls-rprx-vision"}]/g' | sed 's/},/,"flow":"xtls-rprx-vision"},/g')
		INBOUNDS="${INBOUNDS}"'{"listen":"0.0.0.0","port":'${VLESSENC_PORT}',"protocol":"vless","settings":{"clients":'${ENC_CLIENTS}',"decryption":"'${DECRYPTION}'"},"streamSettings":{"network":"tcp"}}'
	fi

	# Inbound 3: Shadowsocks (if SS is set and not empty)
	if [ -n "$SS" ]; then
		[ "$INBOUNDS" != '[' ] && INBOUNDS="${INBOUNDS},"
		INBOUNDS="${INBOUNDS}${SS}"
	fi

	# Fallback: if nothing was configured, create a basic VLESS inbound
	if [ "$INBOUNDS" = '[' ]; then
		INBOUNDS='[{"port":'${VLESS_PORT}',"listen":"0.0.0.0","protocol":"vless","settings":{"clients":'${CLIENTS}',"decryption":"none"},"streamSettings":{"network":"tcp"}}]'
	else
		INBOUNDS="${INBOUNDS}]"
	fi
}


# Assemble final CONFIG JSON from ENV components
output_config() {
	if [ "$CONFIG" = '{}' ]; then
		BASE='"stats":{},"log":{"loglevel":'${LOGLEVEL}'},"api":{"tag":"api","services":["HandlerService","LoggerService","StatsService"]},"policy":{"levels":{"0":{"statsUserUplink":true,"statsUserDownlink":true},"1":{"statsUserUplink":true,"statsUserDownlink":true}},"system":{"statsInboundUplink":true,"statsInboundDownlink":true}}'
		CORE='"inbounds":'${INBOUNDS}',"outbounds":'${OUTBOUNDS}',"routing":'${ROUTING}',"transport":'${TRANSPORT}

		if [ "$DNS" = '{}' ]; then
			CONFIG='{'${BASE}','${CORE}'}'
		else
			CONFIG='{'${BASE}','${CORE}',"dns":'${DNS}'}'
		fi

		# Allow override by mounted config file
		if [ -e "$CONFIG_FILE" ]; then
			CONFIG=$(cat "$CONFIG_FILE")
			echo "Config overridden by $CONFIG_FILE"
		fi
	fi

	mkdir -p /tmp
	echo "$CONFIG" > /tmp/config.json

	echo "Main Clients:"
	echo "${CLIENTS}" | jq .
	echo ""
	if [ "$LOGLEVEL" = '"debug"' ]; then
		echo "Current Config:"
		echo "${CONFIG}" | jq .
	else
		echo "Config written to /tmp/config.json (set LOGLEVEL='\"debug\"' to print full config)"
	fi
}

start_xray() {
	xray --config=/tmp/config.json &
	XRAY_PID=$!
	echo "xray started with PID: $XRAY_PID"
}

finish() {
	echo "Received signal, shutting down xray (PID: $XRAY_PID)..."
	kill "$XRAY_PID" 2>/dev/null
	wait "$XRAY_PID" 2>/dev/null
	echo "xray stopped."
	exit 0
}

# --- Main ---
resolve_decryption
init_variables
CLIENTS=$(replace_default_client "$CLIENTS")
output_config
start_xray

trap finish SIGTERM SIGINT SIGQUIT
wait "$XRAY_PID"