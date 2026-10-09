#!/bin/sh
# Generate and validate the selected Xray configuration before starting the server.
set -eu
umask 077

DEFAULT_UUID='f2707fb2-70fa-6b38-c9b2-81d6f1efa323'
KEY_DIR='/opt/xray/keys'
CONFIG_FILE='/opt/xray/config/config.json'
RUNTIME_CONFIG='/tmp/config.json'
CONFIG=${CONFIG-'{}'}
INBOUNDS=${INBOUNDS-'[]'}

# 工具函数
fail() { printf 'ERROR: %s\n' "$1" >&2; exit "${2:-1}"; }
json_check() {
    printf '%s' "$2" | jq -es "length == 1 and (.[0] | $3)" >/dev/null 2>&1 \
        || fail "$1: invalid JSON or unexpected value/type"
}
exists() { [ -e "$1" ] || [ -L "$1" ]; }
read_value() {
    [ -f "$1" ] && [ -r "$1" ] && [ -s "$1" ] || fail "Invalid or unreadable persisted $2"
    cat "$1" || fail "Cannot read persisted $2"
}
write_value() {
    mkdir -p "$KEY_DIR" || fail 'Cannot create key directory'
    VALUE_FILE=$(mktemp "$KEY_DIR/.$1.XXXXXX") || fail "Cannot create temporary $1"
    if ! chmod 600 "$VALUE_FILE" || ! printf '%s\n' "$2" > "$VALUE_FILE" \
        || ! mv -f "$VALUE_FILE" "$KEY_DIR/$1"; then
        rm -f "$VALUE_FILE"
        fail "Cannot persist $1"
    fi
}
valid_x25519() {
    json_check "$1" "$(jq -n --arg key "$2" '$key')" \
        'type == "string" and test("^[A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]$")'
}
valid_vless_key() {
    json_check "$1" "$(jq -n --arg key "$2" '$key')" '
        type == "string" and (split(".") as $f |
        ($f | length) >= 4 and $f[0] == "mlkem768x25519plus" and
        ($f[1] == "native" or $f[1] == "xorpub" or $f[1] == "random") and
        ($f[2] | test("^[0-9]+(-[0-9]+)?s?$")) and
        any($f[3:][]; length >= 20) and
        all($f[3:][]; test("^[A-Za-z0-9_-]+$") and
            (length < 20 or test("^([A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]|[A-Za-z0-9_-]{85}[AQgw])$"))))'
}
valid_encryption() {
    json_check 'VLESS client encryption' "$(jq -n --arg key "$1" '$key')" '
        type == "string" and test("^mlkem768x25519plus\\.(native|xorpub|random)\\.(0rtt|1rtt)\\.([A-Za-z0-9_-]{42}[AEIMQUYcgkosw048]|[A-Za-z0-9_-]{1578}[AEIMQUYcgkosw048])$")'
}
parse_x25519() {
    printf '%s' "$1" | jq -Rsc '
        split("\n") | map(select(test("^(PrivateKey|Password)(:| )"))) |
        map(capture("^(?<name>PrivateKey|Password(?: \\(PublicKey\\))?):[ \\t]*(?<value>[^ \\t\\r]+)[ \\t\\r]*$") // error("invalid key field")) |
        if length == 2 and ([.[] | select(.name == "PrivateKey")] | length) == 1
            and ([.[] | select(.name != "PrivateKey")] | length) == 1
        then {private: (.[] | select(.name == "PrivateKey") | .value),
              public: (.[] | select(.name != "PrivateKey") | .value)}
        else error("invalid x25519 output") end' 2>/dev/null
}
checked_x25519() {
    KEY_OUTPUT=$(xray x25519 "$@" 2>/dev/null) || { STATUS=$?; fail 'xray x25519 failed' "$STATUS"; }
    KEY_PAIR=$(parse_x25519 "$KEY_OUTPUT") || fail 'Cannot parse xray x25519 output'
    PARSED_PRIVATE=$(printf '%s' "$KEY_PAIR" | jq -r '.private')
    REALITY_PUBLIC_KEY=$(printf '%s' "$KEY_PAIR" | jq -r '.public')
    valid_x25519 'X25519 private key' "$PARSED_PRIVATE"
    valid_x25519 'X25519 public key' "$REALITY_PUBLIC_KEY"
}
gen_shortid() {
    SHORT_OUTPUT=$(od -A n -N 8 -t x1 /dev/urandom) || fail 'Cannot generate Reality short ID'
    printf '%s' "$SHORT_OUTPUT" | tr -d ' \n'
}
valid_shortid() {
    json_check 'Reality short ID' "$(jq -n --arg id "$1" '$id')" \
        'type == "string" and test("^([0-9a-fA-F]{2}){0,8}$")'
}

# VLESSENC_NETWORK → streamSettings JSON
build_enc_stream() {
    NET=${VLESSENC_NETWORK%%:*}; PARAM=${VLESSENC_NETWORK#*:}
    [ "$PARAM" != "$VLESSENC_NETWORK" ] || PARAM=''
    case "$NET" in
        tcp) [ "$VLESSENC_NETWORK" = 'tcp' ] || fail 'TCP transport does not accept a parameter'
             jq -n '{network:"tcp"}' ;;
        ws|xhttp)
            PARAM=${PARAM:-/}
            case "$PARAM" in /*) ;; *) fail 'WS/XHTTP path must start with /' ;; esac
            jq -n --arg network "$NET" --arg path "$PARAM" '
                if $network == "ws" then {network:$network,wsSettings:{path:$path}}
                else {network:$network,xhttpSettings:{path:$path,mode:"auto"}} end' ;;
        grpc) jq -n --arg service "${PARAM:-vless}" '{network:"grpc",grpcSettings:{serviceName:$service}}' ;;
        *) fail 'Unsupported VLESSENC_NETWORK (expected tcp, ws, grpc, or xhttp)' ;;
    esac
}

# VLESS Encryption 密钥: 传入 → 直接用, 持久化 → 加载, 否则 → 自动生成
resolve_decryption() {
    CLIENT_ENC=''
    case "${VLESSENC_KEY:-}" in auto|none|'') VLESSENC_KEY='' ;; esac
    if [ -n "$VLESSENC_KEY" ]; then
        DECRYPTION=$VLESSENC_KEY
        valid_vless_key 'VLESSENC_KEY' "$DECRYPTION"
        return
    fi
    # 加载持久化
    if exists "$KEY_DIR/vlessenc.key"; then
        DECRYPTION=$(read_value "$KEY_DIR/vlessenc.key" 'VLESS decryption')
        valid_vless_key 'Persisted VLESS decryption' "$DECRYPTION"
        if exists "$KEY_DIR/vlessenc.enc"; then
            CLIENT_ENC=$(read_value "$KEY_DIR/vlessenc.enc" 'VLESS client encryption')
            valid_encryption "$CLIENT_ENC"
        fi
        return
    fi
    exists "$KEY_DIR/vlessenc.enc" && fail 'Persisted VLESS encryption exists without its decryption key'
    # 自动生成
    ENC_OUTPUT=$(xray vlessenc 2>/dev/null) || { STATUS=$?; fail 'xray vlessenc failed' "$STATUS"; }
    ENC_PAIR=$(printf '%s' "$ENC_OUTPUT" | jq -Rsc '
        split("\n") | map(select(test("^\\s*\"(decryption|encryption)\"\\s*:"))) |
        map("{" + . + "}" | fromjson) |
        if length >= 2 and length % 2 == 0 then . else error("missing pair") end |
        [range(0; length; 2) as $i |
            if (.[$i] | keys) == ["decryption"] and (.[$i+1] | keys) == ["encryption"]
            then .[$i] + .[$i+1] else error("unpaired keys") end] | last' 2>/dev/null) \
        || fail 'Cannot parse xray vlessenc output'
    DECRYPTION=$(printf '%s' "$ENC_PAIR" | jq -r '.decryption')
    CLIENT_ENC=$(printf '%s' "$ENC_PAIR" | jq -r '.encryption')
    valid_vless_key 'Generated VLESS decryption' "$DECRYPTION"
    valid_encryption "$CLIENT_ENC"
    write_value vlessenc.key "$DECRYPTION"
    write_value vlessenc.enc "$CLIENT_ENC"
}

# Reality 密钥: 传入 → 直接用, 持久化 → 加载, 否则 → 自动生成
resolve_reality() {
    if [ -n "${REALITY_PRIVATE_KEY:-}" ]; then
        valid_x25519 'REALITY_PRIVATE_KEY' "$REALITY_PRIVATE_KEY"
        checked_x25519 -i "$REALITY_PRIVATE_KEY"
    elif exists "$KEY_DIR/reality.key"; then
        # 加载持久化
        REALITY_PRIVATE_KEY=$(read_value "$KEY_DIR/reality.key" 'Reality private key')
        valid_x25519 'Persisted Reality private key' "$REALITY_PRIVATE_KEY"
        checked_x25519 -i "$REALITY_PRIVATE_KEY"
    else
        # 自动生成
        checked_x25519
        REALITY_PRIVATE_KEY=$PARSED_PRIVATE
        write_value reality.key "$REALITY_PRIVATE_KEY"
    fi
    if [ -z "${REALITY_SHORT_ID:-}" ]; then
        if exists "$KEY_DIR/reality.shortid"; then
            REALITY_SHORT_ID=$(read_value "$KEY_DIR/reality.shortid" 'Reality short ID')
        else
            REALITY_SHORT_ID=$(gen_shortid)
            valid_shortid "$REALITY_SHORT_ID"
            [ -n "$REALITY_SHORT_ID" ] || fail 'Generated Reality short ID is empty'
            write_value reality.shortid "$REALITY_SHORT_ID"
        fi
    fi
    valid_shortid "$REALITY_SHORT_ID"
}

resolve_clients() {
    json_check CLIENTS "$CLIENTS" 'type == "array" and length > 0 and all(.[];
        type == "object" and (.id | type == "string" and length > 0) and
        (if has("flow") then (.flow | type == "string") else true end))'
    if printf '%s' "$CLIENTS" | jq -e --arg sentinel "$DEFAULT_UUID" 'any(.[]; .id == $sentinel)' >/dev/null; then
        if exists "$KEY_DIR/client.uuid"; then
            CLIENT_UUID=$(read_value "$KEY_DIR/client.uuid" 'client UUID')
        else
            CLIENT_UUID=$(xray uuid 2>/dev/null) || { STATUS=$?; fail 'xray uuid failed' "$STATUS"; }
            json_check 'Generated client UUID' "$(jq -n --arg id "$CLIENT_UUID" '$id')" \
                'type == "string" and test("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$")'
            [ "$CLIENT_UUID" != "$DEFAULT_UUID" ] || fail 'UUID helper returned the default sentinel'
            write_value client.uuid "$CLIENT_UUID"
        fi
        json_check 'Persisted client UUID' "$(jq -n --arg id "$CLIENT_UUID" '$id')" \
            'type == "string" and test("^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$")'
        [ "$CLIENT_UUID" != "$DEFAULT_UUID" ] || fail 'Persisted client UUID is the default sentinel'
        CLIENTS=$(printf '%s' "$CLIENTS" | jq --arg old "$DEFAULT_UUID" --arg id "$CLIENT_UUID" \
            'map(if .id == $old then .id = $id else . end)')
    fi
}

# 构建 INBOUNDS
init_variables() {
    VLESS_PORT=${VLESS_PORT-443}; VLESSENC_PORT=${VLESSENC_PORT-8443}
    VLESSENC_NETWORK=${VLESSENC_NETWORK-tcp}
    REALITY_DEST=${REALITY_DEST:-www.microsoft.com:443}; REALITY_SNI=${REALITY_SNI:-www.microsoft.com}
    for PORT in "$VLESS_PORT" "$VLESSENC_PORT"; do
        json_check 'Quick setup port (1..65535)' "$(jq -n --arg port "$PORT" '$port')" \
            'type == "string" and test("^[0-9]+$") and (tonumber >= 1 and tonumber <= 65535)'
    done
    ENC_STREAM=$(build_enc_stream) || fail 'Invalid VLESS Encryption transport'
    SS=${SS:-}; SS_ARRAY='[]'
    if [ -n "$SS" ]; then
        json_check SS "$SS" 'type == "object"'
        SS_ARRAY=$(printf '%s' "$SS" | jq '[.]')
    fi
    resolve_clients
    resolve_decryption
    resolve_reality
    FLOW_CLIENTS=$(printf '%s' "$CLIENTS" | jq 'map(if has("flow") then . else . + {flow:"xtls-rprx-vision"} end)')
    # Reality, VLESS Encryption, Shadowsocks
    INBOUNDS=$(jq -n --argjson clients "$CLIENTS" --argjson flow_clients "$FLOW_CLIENTS" \
        --arg port "$VLESS_PORT" --arg enc_port "$VLESSENC_PORT" \
        --arg dest "$REALITY_DEST" --arg sni "$REALITY_SNI" --arg key "$REALITY_PRIVATE_KEY" \
        --arg shortid "$REALITY_SHORT_ID" --arg decryption "$DECRYPTION" \
        --argjson stream "$ENC_STREAM" --argjson ss "$SS_ARRAY" '
        [{listen:"0.0.0.0",port:($port|tonumber),protocol:"vless",
          settings:{clients:$flow_clients,decryption:"none"},streamSettings:{network:"tcp",security:"reality",
          realitySettings:{show:false,dest:$dest,xver:0,serverNames:[$sni],privateKey:$key,shortIds:[$shortid]}}},
         {listen:"0.0.0.0",port:($enc_port|tonumber),protocol:"vless",
          settings:{clients:(if $stream.network == "tcp" then $flow_clients else $clients end),
                    decryption:$decryption},streamSettings:$stream}] + $ss') \
        || fail 'Cannot build quick setup inbounds'
}

# 组装 config + 输出日志
assemble_config() {
    OUTBOUNDS=${OUTBOUNDS-'[]'}; ROUTING=${ROUTING-'{}'}
    TRANSPORT=${TRANSPORT-'{}'}; DNS=${DNS-'{}'}; LOGLEVEL=${LOGLEVEL-'"warning"'}
    json_check OUTBOUNDS "$OUTBOUNDS" 'type == "array" and all(.[]; type == "object")'
    json_check ROUTING "$ROUTING" 'type == "object"'
    json_check TRANSPORT "$TRANSPORT" 'type == "object"'
    json_check DNS "$DNS" 'type == "object"'
    json_check LOGLEVEL "$LOGLEVEL" 'type == "string" and IN("debug", "info", "warning", "error", "none")'
    CONFIG=$(jq -n --argjson inbounds "$INBOUNDS" --argjson outbounds "$OUTBOUNDS" \
        --argjson routing "$ROUTING" --argjson transport "$TRANSPORT" --argjson dns "$DNS" --argjson level "$LOGLEVEL" '
        {stats:{},log:{loglevel:$level},api:{tag:"api",services:["HandlerService","LoggerService","StatsService"]},
         policy:{levels:{"0":{statsUserUplink:true,statsUserDownlink:true},"1":{statsUserUplink:true,statsUserDownlink:true}},
                 system:{statsInboundUplink:true,statsInboundDownlink:true}},
         inbounds:$inbounds,outbounds:$outbounds,routing:$routing,transport:$transport} |
        if $dns == {} then . else . + {dns:$dns} end') || fail 'Cannot assemble Xray configuration'
}
output_config() {
    CONFIG_TMP=$(mktemp "$RUNTIME_CONFIG.XXXXXX") || fail 'Cannot create runtime configuration'
    if [ "$MODE" = 'file' ]; then
        cat "$CONFIG_FILE" > "$CONFIG_TMP" || fail 'Cannot copy configuration override'
    else
        printf '%s' "$CONFIG" > "$CONFIG_TMP" || fail 'Cannot write runtime configuration'
    fi
    chmod 600 "$CONFIG_TMP" && mv -f "$CONFIG_TMP" "$RUNTIME_CONFIG" || fail 'Cannot persist runtime configuration'
    TEST_OUTPUT=$(xray run -test -config "$RUNTIME_CONFIG" 2>&1) || {
        STATUS=$?
        if [ "${LOGLEVEL:-}" = '"debug"' ]; then printf '%s\n' "$TEST_OUTPUT" >&2; fi
        fail "Xray configuration test failed (exit $STATUS)" "$STATUS"
    }
    printf 'Xray configuration test passed (%s configuration).\n' "$MODE"
    if [ "$MODE" = 'quick' ]; then
        echo 'Main Clients:'
        printf '%s' "$CLIENTS" | jq 'map({id,level,email,flow} | with_entries(select(.value != null)))'
        echo '========== Client Config Summary =========='
        echo "[Reality] Port:$VLESS_PORT  SNI:$REALITY_SNI"
        echo "  Public Key: $REALITY_PUBLIC_KEY"
        echo "  Short ID:   $REALITY_SHORT_ID"
        echo "[VLESS Encryption] Port:$VLESSENC_PORT  Network:$VLESSENC_NETWORK"
        [ "${VLESSENC_NETWORK%%:*}" = 'tcp' ] || echo "  Note: Do not set 'flow' on client for this transport"
        if [ -n "$CLIENT_ENC" ]; then
            echo "  Client Encryption: $CLIENT_ENC"
        else
            echo '  Client Encryption: (user-provided key, use your xray vlessenc output)'
        fi
        echo '=========================================='
    fi
    if [ "${LOGLEVEL:-}" = '"debug"' ]; then
        echo 'Current Config:'; jq . "$RUNTIME_CONFIG"
    else
        echo "Config written to $RUNTIME_CONFIG (set LOGLEVEL='\"debug\"' to print full config)"
    fi
}

# --- Main ---
# Select the override before validating or generating unused quick setup values.
if exists "$CONFIG_FILE"; then
    [ -f "$CONFIG_FILE" ] && [ -r "$CONFIG_FILE" ] || fail 'Configuration override is not a readable file'
    jq -es 'length == 1 and (.[0] | type == "object")' "$CONFIG_FILE" >/dev/null 2>&1 \
        || fail 'Configuration file: invalid JSON or expected an object'
    MODE='file'
else
    json_check CONFIG "$CONFIG" 'type == "object"'
    if printf '%s' "$CONFIG" | jq -e 'length > 0' >/dev/null; then
        MODE='config'
    else
        json_check INBOUNDS "$INBOUNDS" 'type == "array" and all(.[]; type == "object")'
        if printf '%s' "$INBOUNDS" | jq -e 'length > 0' >/dev/null; then
            MODE='inbounds'
        else
            MODE='quick'
            CLIENTS=${CLIENTS-'[{"id":"f2707fb2-70fa-6b38-c9b2-81d6f1efa323"}]'}
            init_variables
        fi
        assemble_config
    fi
fi
output_config
exec xray run -config "$RUNTIME_CONFIG"
