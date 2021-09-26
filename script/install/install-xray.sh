# pre-define to replace `identify_the_operating_system_and_architecture`
MACHINE='64'
DAT_PATH='/usr/bin/xray/'
# Two very important variables
# TMP_DIRECTORY="$(mktemp -du)/"
TMP_DIRECTORY=${DAT_PATH}
ZIP_FILE="${TMP_DIRECTORY}xray-linux-$MACHINE.zip"

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
     # Get xray release XRAY_BINARY number
    TMP_FILE="$(mktemp)"
    install_software curl
    # DO NOT QUOTE THESE `${PROXY}` VARIABLES!
    if ! curl -o "$TMP_FILE" 'https://api.github.com/repos/XTLS/Xray-core/releases/latest'; then
        rm "$TMP_FILE"
        echo 'error: Failed to get release list, please check your network.'
        exit 1
    fi
    RELEASE_LATEST="$(sed 'y/,/\n/' "$TMP_FILE" | grep 'tag_name' | awk -F '"' '{print $4}')"
    rm "$TMP_FILE"
    XRAY_BINARY="$(version_number "$RELEASE_LATEST")"
}

decompression() {
    echo "Starting unzip file"
    if ! unzip -q "$1" -d "$TMP_DIRECTORY"; then
        echo 'error: xray decompression failed.'
        rm -r "$TMP_DIRECTORY"
        echo "removed: $TMP_DIRECTORY"
        exit 1
    fi
    echo "info: Extract the xray package to $TMP_DIRECTORY and prepare it for installation."
}

download_xray() {
    mkdir "$TMP_DIRECTORY"
    DOWNLOAD_LINK="https://github.com/XTLS/Xray-core/releases/download/$XRAY_BINARY/Xray-linux-$MACHINE.zip"
    echo "Downloading xray archive: $DOWNLOAD_LINK"
    if ! curl -L -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK"; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    echo "Downloading verification file for xray archive: $DOWNLOAD_LINK.dgst"
    if ! curl -L -H 'Cache-Control: no-cache' -o "$ZIP_FILE.dgst" "$DOWNLOAD_LINK.dgst"; then
        echo 'error: Download failed! Please check your network or try again.'
        return 1
    fi
    if [[ "$(cat "$ZIP_FILE".dgst)" == 'Not Found' ]]; then
        echo "error: This XRAY_BINARY ${XRAY_BINARY} does not support verification. Please replace with another XRAY_BINARY."
        return 1
    fi

    # Verification of xray archive
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
    if [[ "$NAME" == 'xray' ]] ; then
        install -m 755 "${TMP_DIRECTORY}$NAME" "${DAT_PATH}$NAME"
    elif [[ "$NAME" == 'geoip.dat' ]] || [[ "$NAME" == 'geosite.dat' ]]; then
        install -m 644 "${TMP_DIRECTORY}$NAME" "${DAT_PATH}$NAME"
    fi
}

install_xray() {
    # get XRAY_BINARY without XRAY_BINARY
    [ -z "${XRAY_BINARY}" ] && get_version
    # Download xray binary
    download_xray
    decompression "$ZIP_FILE"
    # Install xray binary to /usr/local/bin/ and $DAT_PATH
    # install_file xray
    # install -d "$DAT_PATH"
    # If the file exists, geoip.dat and geosite.dat will not be installed or updated
    # if [[ ! -f "${DAT_PATH}.undat" ]]; then
    #     install_file geoip.dat
    #     install_file geosite.dat
    # fi
}

main(){
    install_xray
}

main