# pre-define to replace `identify_the_operating_system_and_architecture`
MACHINE='64'
DAT_PATH='/usr/bin/v2ray/'
# Two very important variables
TMP_DIRECTORY="$(mktemp -du)/"
ZIP_FILE="${TMP_DIRECTORY}v2ray-linux-$MACHINE.zip"

version_number() {
    case "$1" in
        'v'*)
            echo "$1"
            ;;
        *)
            echo "v$1"
            ;;
    esac
}

get_version() {
     # Get V2Ray release version number
    TMP_FILE="$(mktemp)"
    install_software curl
    # DO NOT QUOTE THESE `${PROXY}` VARIABLES!
    if ! curl ${PROXY} -o "$TMP_FILE" 'https://api.github.com/repos/v2fly/v2ray-core/releases/latest'; then
        rm "$TMP_FILE"
        echo 'error: Failed to get release list, please check your network.'
        exit 1
    fi
    RELEASE_LATEST="$(sed 'y/,/\n/' "$TMP_FILE" | grep 'tag_name' | awk -F '"' '{print $4}')"
    rm "$TMP_FILE"
    RELEASE_VERSION="$(version_number "$RELEASE_LATEST")"
}

decompression() {
    if ! unzip -q "$1" -d "$TMP_DIRECTORY"; then
        echo 'error: V2Ray decompression failed.'
        rm -r "$TMP_DIRECTORY"
        echo "removed: $TMP_DIRECTORY"
        exit 1
    fi
    echo "info: Extract the V2Ray package to $TMP_DIRECTORY and prepare it for installation."
}

download_v2ray() {
    mkdir "$TMP_DIRECTORY"
    DOWNLOAD_LINK="https://github.com/v2fly/v2ray-core/releases/download/$RELEASE_VERSION/v2ray-linux-$MACHINE.zip"
    echo "Downloading V2Ray archive: $DOWNLOAD_LINK"
    if ! curl -L -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK"; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    echo "Downloading verification file for V2Ray archive: $DOWNLOAD_LINK.dgst"
    if ! curl -L -H 'Cache-Control: no-cache' -o "$ZIP_FILE.dgst" "$DOWNLOAD_LINK.dgst"; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    if [[ "$(cat "$ZIP_FILE".dgst)" == 'Not Found' ]]; then
        echo 'error: This version does not support verification. Please replace with another version.'
        return 1
    fi

    # Verification of V2Ray archive
    for LISTSUM in 'md5' 'sha1' 'sha256' 'sha512'; do
        SUM="$(${LISTSUM}sum "$ZIP_FILE" | sed 's/ .*//')"
        CHECKSUM="$(grep ${LISTSUM^^} "$ZIP_FILE".dgst | grep "$SUM" -o -a | uniq)"
        if [[ "$SUM" != "$CHECKSUM" ]]; then
            echo 'error: Check failed! Please check your network or try again.'
            return 1
        fi
    done
}

install_file() {
    NAME="$1"
    if [[ "$NAME" == 'v2ray' ]] || [[ "$NAME" == 'v2ctl' ]]; then
        cp -m 755 "${TMP_DIRECTORY}$NAME" "${DAT_PATH}$NAME"
    elif [[ "$NAME" == 'geoip.dat' ]] || [[ "$NAME" == 'geosite.dat' ]]; then
        cp -m 644 "${TMP_DIRECTORY}$NAME" "${DAT_PATH}$NAME"
    fi
}

install_v2ray() {
    # Install V2Ray binary to /usr/local/bin/ and $DAT_PATH
    install_file v2ray
    install_file v2ctl
    install -d "$DAT_PATH"
    # If the file exists, geoip.dat and geosite.dat will not be installed or updated
    if [[ ! -f "${DAT_PATH}.undat" ]]; then
        install_file geoip.dat
        install_file geosite.dat
    fi
}

main(){
    install_v2ray
}

main