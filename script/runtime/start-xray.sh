#!/bin/sh

DEFAULT_UUID='f2707fb2-70fa-6b38-c9b2-81d6f1efa323'
KEY_DIR='/opt/xray/keys'
CONFIG_FILE='/opt/xray/config/config.json'

# 工具函数
replace_default_client() { echo "${1//$DEFAULT_UUID/$(cat /proc/sys/kernel/random/uuid)}"; }
inject_flow() { echo "$CLIENTS" | sed 's/}]/,"flow":"xtls-rprx-vision"}]/g' | sed 's/},/,"flow":"xtls-rprx-vision"},/g'; }
derive_pubkey() { xray x25519 -i "$1" 2>&1 | awk '/^Password:/{print $NF}'; }
gen_shortid() { head -c 8 /dev/urandom | od -A n -t x1 | tr -d ' \n'; }

# VLESSENC_NETWORK → streamSettings JSON
build_enc_stream() {
	NET="${VLESSENC_NETWORK%%:*}"; PARAM="${VLESSENC_NETWORK#*:}"
	[ "$PARAM" = "$VLESSENC_NETWORK" ] && PARAM=""
	case "$NET" in
		ws)   echo '{"network":"ws","wsSettings":{"path":"'"${PARAM:-/}"'"}}'  ;;
		grpc) echo '{"network":"grpc","grpcSettings":{"serviceName":"'"${PARAM:-vless}"'"}}'  ;;
		*)    echo '{"network":"tcp"}'  ;;
	esac
}

# VLESS Encryption 密钥: 传入 → 直接用, 持久化 → 加载, 否则 → 自动生成
resolve_decryption() {
	case "$VLESSENC_KEY" in auto|none|"") VLESSENC_KEY="" ;; esac
	[ -n "$VLESSENC_KEY" ] && { DECRYPTION="$VLESSENC_KEY"; return; }
	# 加载持久化
	if [ -f "${KEY_DIR}/vlessenc.key" ] && [ -s "${KEY_DIR}/vlessenc.key" ]; then
		DECRYPTION=$(cat "${KEY_DIR}/vlessenc.key")
		case "$DECRYPTION" in mlkem768*) return ;; esac
		rm -f "${KEY_DIR}"/vlessenc.*
	fi
	# 自动生成
	ENC_OUTPUT=$(xray vlessenc 2>/dev/null)
	[ -z "$ENC_OUTPUT" ] && { echo "ERROR: xray vlessenc failed"; DECRYPTION='none'; return; }
	DECRYPTION=$(echo "$ENC_OUTPUT" | grep '"decryption"' | tail -1 | sed 's/.*: "//;s/"$//')
	CLIENT_ENC=$(echo "$ENC_OUTPUT" | grep '"encryption"' | tail -1 | sed 's/.*: "//;s/"$//')
	[ -z "$DECRYPTION" ] && { echo "ERROR: parse vlessenc failed"; DECRYPTION='none'; return; }
	mkdir -p "$KEY_DIR"
	echo "$DECRYPTION" > "${KEY_DIR}/vlessenc.key"
	echo "$CLIENT_ENC" > "${KEY_DIR}/vlessenc.enc"
}

# Reality 密钥: 传入 → 直接用, 持久化 → 加载, 否则 → 自动生成
resolve_reality() {
	if [ -n "$REALITY_PRIVATE_KEY" ]; then
		REALITY_PUBLIC_KEY=$(derive_pubkey "$REALITY_PRIVATE_KEY"); return
	fi
	# 加载持久化
	if [ -f "${KEY_DIR}/reality.key" ] && [ -s "${KEY_DIR}/reality.key" ]; then
		REALITY_PRIVATE_KEY=$(cat "${KEY_DIR}/reality.key")
		REALITY_PUBLIC_KEY=$(derive_pubkey "$REALITY_PRIVATE_KEY")
		[ -z "$REALITY_SHORT_ID" ] && {
			[ -f "${KEY_DIR}/reality.shortid" ] && REALITY_SHORT_ID=$(cat "${KEY_DIR}/reality.shortid") \
				|| { REALITY_SHORT_ID=$(gen_shortid); echo "$REALITY_SHORT_ID" > "${KEY_DIR}/reality.shortid"; }
		}
		return
	fi
	# 自动生成
	KEY_OUTPUT=$(xray x25519 2>&1)
	REALITY_PRIVATE_KEY=$(echo "$KEY_OUTPUT" | awk '/^PrivateKey:/{print $NF}')
	REALITY_PUBLIC_KEY=$(echo "$KEY_OUTPUT" | awk '/^Password:/{print $NF}')
	[ -z "$REALITY_PRIVATE_KEY" ] && { echo "ERROR: xray x25519 failed"; return; }
	[ -z "$REALITY_SHORT_ID" ] && REALITY_SHORT_ID=$(gen_shortid)
	mkdir -p "$KEY_DIR"
	echo "$REALITY_PRIVATE_KEY" > "${KEY_DIR}/reality.key"
	echo "$REALITY_SHORT_ID" > "${KEY_DIR}/reality.shortid"
}

# 构建 INBOUNDS
init_variables() {
	if [ "$INBOUNDS" != '[]' ]; then
		[ "$DECRYPTION" != 'none' ] && \
			INBOUNDS=$(echo "$INBOUNDS" | sed "s/\"decryption\":\"none\"/\"decryption\":\"${DECRYPTION}\"/g")
		return
	fi

	INBOUNDS='['
	FLOW_CLIENTS=$(inject_flow)

	# Reality
	[ -n "$REALITY_PRIVATE_KEY" ] && \
		INBOUNDS="${INBOUNDS}"'{"listen":"0.0.0.0","port":'${VLESS_PORT}',"protocol":"vless","settings":{"clients":'${FLOW_CLIENTS}',"decryption":"none"},"streamSettings":{"network":"tcp","security":"reality","realitySettings":{"show":false,"dest":"'${REALITY_DEST}'","xver":0,"serverNames":["'${REALITY_SNI}'"],"privateKey":"'${REALITY_PRIVATE_KEY}'","shortIds":["'${REALITY_SHORT_ID}'"]}}}'

	# VLESS Encryption
	if [ "$DECRYPTION" != 'none' ]; then
		[ "$INBOUNDS" != '[' ] && INBOUNDS="${INBOUNDS},"
		INBOUNDS="${INBOUNDS}"'{"listen":"0.0.0.0","port":'${VLESSENC_PORT}',"protocol":"vless","settings":{"clients":'${FLOW_CLIENTS}',"decryption":"'${DECRYPTION}'"},"streamSettings":'$(build_enc_stream)'}'
	fi

	# Shadowsocks
	[ -n "$SS" ] && { [ "$INBOUNDS" != '[' ] && INBOUNDS="${INBOUNDS},"; INBOUNDS="${INBOUNDS}${SS}"; }

	# Fallback / 闭合
	if [ "$INBOUNDS" = '[' ]; then
		INBOUNDS='[{"port":'${VLESS_PORT}',"listen":"0.0.0.0","protocol":"vless","settings":{"clients":'${CLIENTS}',"decryption":"none"},"streamSettings":{"network":"tcp"}}]'
	else
		INBOUNDS="${INBOUNDS}]"
	fi
}

# 组装 config + 输出日志
output_config() {
	if [ "$CONFIG" = '{}' ]; then
		BASE='"stats":{},"log":{"loglevel":'${LOGLEVEL}'},"api":{"tag":"api","services":["HandlerService","LoggerService","StatsService"]},"policy":{"levels":{"0":{"statsUserUplink":true,"statsUserDownlink":true},"1":{"statsUserUplink":true,"statsUserDownlink":true}},"system":{"statsInboundUplink":true,"statsInboundDownlink":true}}'
		CORE='"inbounds":'${INBOUNDS}',"outbounds":'${OUTBOUNDS}',"routing":'${ROUTING}',"transport":'${TRANSPORT}
		[ "$DNS" = '{}' ] && CONFIG='{'${BASE}','${CORE}'}' || CONFIG='{'${BASE}','${CORE}',"dns":'${DNS}'}'
		[ -e "$CONFIG_FILE" ] && { CONFIG=$(cat "$CONFIG_FILE"); echo "Config overridden by $CONFIG_FILE"; }
	fi

	echo "$CONFIG" > /tmp/config.json
	echo "Main Clients:"; echo "${CLIENTS}" | jq .

	echo "========== Client Config Summary =========="
	[ -n "$REALITY_PRIVATE_KEY" ] && {
		echo "[Reality] Port:$VLESS_PORT  SNI:$REALITY_SNI"
		echo "  Public Key: $REALITY_PUBLIC_KEY"
		echo "  Short ID:   $REALITY_SHORT_ID"
	}
	[ "$DECRYPTION" != 'none' ] && {
		echo "[VLESS Encryption] Port:$VLESSENC_PORT  Network:$VLESSENC_NETWORK"
		[ -f "${KEY_DIR}/vlessenc.enc" ] \
			&& echo "  Client Encryption: $(cat "${KEY_DIR}/vlessenc.enc")" \
			|| echo "  Client Encryption: (user-provided key, use your xray vlessenc output)"
	}
	echo "==========================================="

	[ "$LOGLEVEL" = '"debug"' ] \
		&& { echo "Current Config:"; echo "${CONFIG}" | jq .; } \
		|| echo "Config written to /tmp/config.json (set LOGLEVEL='\"debug\"' to print full config)"
}

finish() { echo "Shutting down xray..."; kill "$XRAY_PID" 2>/dev/null; wait "$XRAY_PID" 2>/dev/null; exit 0; }

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