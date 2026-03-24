#!/bin/sh

DEFAULT_UUID='f2707fb2-70fa-6b38-c9b2-81d6f1efa323'
KEY_DIR='/opt/xray/keys'
CONFIG_DIR='/opt/xray/config'
CONFIG_FILE="${CONFIG_DIR}/config.json"

# Replace default UUID with a random one
replace_default_client() {
	UUID=$(cat /proc/sys/kernel/random/uuid)
	flag=$(echo "$1" | awk -v a="$DEFAULT_UUID" '{print match($0, a)}')
	if [ "$flag" -gt 0 ]; then
		echo "${1/$DEFAULT_UUID/$UUID}"
	else
		echo "$1"
	fi
}

# Inject flow:xtls-rprx-vision into CLIENTS JSON
inject_flow() {
	echo "$CLIENTS" | sed 's/}]/,"flow":"xtls-rprx-vision"}]/g' | sed 's/},/,"flow":"xtls-rprx-vision"},/g'
}

# VLESS Encryption: 给定完整 decryption 字符串 → 直接用，留空/auto → 自动生成 ML-KEM-768
resolve_decryption() {
	# 兼容旧值
	case "$VLESSENC_KEY" in auto|none|"") VLESSENC_KEY="" ;; esac
	if [ -n "$VLESSENC_KEY" ]; then
		DECRYPTION="$VLESSENC_KEY"
		return
	fi
	# 尝试加载持久化
	if [ -f "${KEY_DIR}/vlessenc.key" ] && [ -s "${KEY_DIR}/vlessenc.key" ]; then
		DECRYPTION=$(cat "${KEY_DIR}/vlessenc.key")
		case "$DECRYPTION" in mlkem768*) return ;; esac
		# 旧格式，清理后重新生成
		rm -f "${KEY_DIR}"/vlessenc.*
	fi
	# 自动生成
	ENC_OUTPUT=$(xray vlessenc 2>/dev/null)
	if [ -z "$ENC_OUTPUT" ]; then
		echo "ERROR: xray vlessenc failed"; DECRYPTION='none'; return
	fi
	DECRYPTION=$(echo "$ENC_OUTPUT" | grep '"decryption"' | tail -1 | sed 's/.*: "//;s/"$//')
	CLIENT_ENC=$(echo "$ENC_OUTPUT" | grep '"encryption"' | tail -1 | sed 's/.*: "//;s/"$//')
	[ -z "$DECRYPTION" ] && { echo "ERROR: parse vlessenc failed"; DECRYPTION='none'; return; }
	mkdir -p "$KEY_DIR"
	echo "$DECRYPTION" > "${KEY_DIR}/vlessenc.key"
	echo "$CLIENT_ENC" > "${KEY_DIR}/vlessenc.enc"
}

# Reality: 给定 REALITY_PRIVATE_KEY → 直接用，留空 → 自动生成 X25519
# v26: xray x25519 输出 PrivateKey/Password(=公钥)/Hash32
resolve_reality() {
	if [ -n "$REALITY_PRIVATE_KEY" ]; then
		REALITY_PUBLIC_KEY=$(xray x25519 -i "$REALITY_PRIVATE_KEY" 2>&1 | awk '/^Password:/{print $NF}')
		return
	fi
	# 尝试加载持久化
	if [ -f "${KEY_DIR}/reality.key" ] && [ -s "${KEY_DIR}/reality.key" ]; then
		REALITY_PRIVATE_KEY=$(cat "${KEY_DIR}/reality.key")
		REALITY_PUBLIC_KEY=$(xray x25519 -i "$REALITY_PRIVATE_KEY" 2>&1 | awk '/^Password:/{print $NF}')
		[ -z "$REALITY_SHORT_ID" ] && {
			[ -f "${KEY_DIR}/reality.shortid" ] && REALITY_SHORT_ID=$(cat "${KEY_DIR}/reality.shortid") \
				|| { REALITY_SHORT_ID=$(head -c 8 /dev/urandom | od -A n -t x1 | tr -d ' \n'); echo "$REALITY_SHORT_ID" > "${KEY_DIR}/reality.shortid"; }
		}
		return
	fi
	# 自动生成
	KEY_OUTPUT=$(xray x25519 2>&1)
	REALITY_PRIVATE_KEY=$(echo "$KEY_OUTPUT" | awk '/^PrivateKey:/{print $NF}')
	REALITY_PUBLIC_KEY=$(echo "$KEY_OUTPUT" | awk '/^Password:/{print $NF}')
	[ -z "$REALITY_PRIVATE_KEY" ] && { echo "ERROR: xray x25519 failed"; return; }
	[ -z "$REALITY_SHORT_ID" ] && REALITY_SHORT_ID=$(head -c 8 /dev/urandom | od -A n -t x1 | tr -d ' \n')
	mkdir -p "$KEY_DIR"
	echo "$REALITY_PRIVATE_KEY" > "${KEY_DIR}/reality.key"
	echo "$REALITY_SHORT_ID" > "${KEY_DIR}/reality.shortid"
}

# Build INBOUNDS from ENVs
init_variables() {
	if [ "$INBOUNDS" != '[]' ]; then
		[ "$DECRYPTION" != 'none' ] && \
			INBOUNDS=$(echo "$INBOUNDS" | sed "s/\"decryption\":\"none\"/\"decryption\":\"${DECRYPTION}\"/g")
		return
	fi

	INBOUNDS='['
	FLOW_CLIENTS=$(inject_flow)

	# Reality inbound
	if [ -n "$REALITY_PRIVATE_KEY" ]; then
		INBOUNDS="${INBOUNDS}"'{"listen":"0.0.0.0","port":'${VLESS_PORT}',"protocol":"vless","settings":{"clients":'${FLOW_CLIENTS}',"decryption":"none"},"streamSettings":{"network":"tcp","security":"reality","realitySettings":{"show":false,"dest":"'${REALITY_DEST}'","xver":0,"serverNames":["'${REALITY_SNI}'"],"privateKey":"'${REALITY_PRIVATE_KEY}'","shortIds":["'${REALITY_SHORT_ID}'"]}}}'
	fi

	# VLESS Encryption inbound
	if [ "$DECRYPTION" != 'none' ]; then
		[ "$INBOUNDS" != '[' ] && INBOUNDS="${INBOUNDS},"
		INBOUNDS="${INBOUNDS}"'{"listen":"0.0.0.0","port":'${VLESSENC_PORT}',"protocol":"vless","settings":{"clients":'${FLOW_CLIENTS}',"decryption":"'${DECRYPTION}'"},"streamSettings":{"network":"tcp"}}'
	fi

	# Shadowsocks inbound
	if [ -n "$SS" ]; then
		[ "$INBOUNDS" != '[' ] && INBOUNDS="${INBOUNDS},"
		INBOUNDS="${INBOUNDS}${SS}"
	fi

	# Fallback
	if [ "$INBOUNDS" = '[' ]; then
		INBOUNDS='[{"port":'${VLESS_PORT}',"listen":"0.0.0.0","protocol":"vless","settings":{"clients":'${CLIENTS}',"decryption":"none"},"streamSettings":{"network":"tcp"}}]'
	else
		INBOUNDS="${INBOUNDS}]"
	fi
}

# Assemble final config JSON
output_config() {
	if [ "$CONFIG" = '{}' ]; then
		BASE='"stats":{},"log":{"loglevel":'${LOGLEVEL}'},"api":{"tag":"api","services":["HandlerService","LoggerService","StatsService"]},"policy":{"levels":{"0":{"statsUserUplink":true,"statsUserDownlink":true},"1":{"statsUserUplink":true,"statsUserDownlink":true}},"system":{"statsInboundUplink":true,"statsInboundDownlink":true}}'
		CORE='"inbounds":'${INBOUNDS}',"outbounds":'${OUTBOUNDS}',"routing":'${ROUTING}',"transport":'${TRANSPORT}

		if [ "$DNS" = '{}' ]; then CONFIG='{'${BASE}','${CORE}'}'
		else CONFIG='{'${BASE}','${CORE}',"dns":'${DNS}'}'
		fi

		[ -e "$CONFIG_FILE" ] && { CONFIG=$(cat "$CONFIG_FILE"); echo "Config overridden by $CONFIG_FILE"; }
	fi

	mkdir -p /tmp
	echo "$CONFIG" > /tmp/config.json

	echo "Main Clients:"
	echo "${CLIENTS}" | jq .

	# 客户端配置汇总
	echo "========== Client Config Summary =========="
	if [ -n "$REALITY_PRIVATE_KEY" ]; then
		echo "[Reality] Port:$VLESS_PORT  SNI:$REALITY_SNI"
		echo "  Public Key: $REALITY_PUBLIC_KEY"
		echo "  Short ID:   $REALITY_SHORT_ID"
	fi
	if [ "$DECRYPTION" != 'none' ]; then
		echo "[VLESS Encryption] Port:$VLESSENC_PORT"
		if [ -f "${KEY_DIR}/vlessenc.enc" ]; then
			echo "  Client Encryption: $(cat "${KEY_DIR}/vlessenc.enc")"
		else
			echo "  Client Encryption: (user-provided key, check your xray vlessenc output for encryption string)"
		fi
	fi
	echo "==========================================="

	if [ "$LOGLEVEL" = '"debug"' ]; then
		echo "Current Config:"; echo "${CONFIG}" | jq .
	else
		echo "Config written to /tmp/config.json (set LOGLEVEL='\"debug\"' to print full config)"
	fi
}

finish() {
	echo "Shutting down xray (PID: $XRAY_PID)..."
	kill "$XRAY_PID" 2>/dev/null; wait "$XRAY_PID" 2>/dev/null
	exit 0
}

# --- Main ---
resolve_decryption
resolve_reality
init_variables
CLIENTS=$(replace_default_client "$CLIENTS")
output_config
xray --config=/tmp/config.json &
XRAY_PID=$!
echo "xray started with PID: $XRAY_PID"
trap finish SIGTERM SIGINT SIGQUIT
wait "$XRAY_PID"