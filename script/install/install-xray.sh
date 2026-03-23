#!/bin/bash

# Install Xray-core for the docker image
# https://github.com/XTLS/Xray-core

identify_arch() {
    case "$(uname -m)" in
        x86_64|amd64)   echo "64" ;;
        aarch64|arm64)  echo "arm64-v8a" ;;
        armv7l)         echo "arm32-v7a" ;;
        *)
            echo "error: Unsupported architecture $(uname -m)" >&2
            exit 1
            ;;
    esac
}

MACHINE=$(identify_arch)
DAT_PATH='/usr/bin/xray/'
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
    mkdir -p "$TMP_DIRECTORY"
    DOWNLOAD_LINK="https://github.com/XTLS/Xray-core/releases/download/$XRAY_BINARY/Xray-linux-$MACHINE.zip"
    echo "Downloading xray archive: $DOWNLOAD_LINK"
    if ! curl -L -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK"; then
        echo 'error: Download failed! Please check your network or try again.'
        exit 1
    fi

    DGST_FILE="${ZIP_FILE}.dgst"
    echo "Downloading verification file: ${DOWNLOAD_LINK}.dgst"
    if ! curl -L -H 'Cache-Control: no-cache' -o "$DGST_FILE" "${DOWNLOAD_LINK}.dgst"; then
        echo 'warning: Could not download dgst file, skipping verification.'
        return 0
    fi

    if [[ "$(cat "$DGST_FILE")" == 'Not Found' ]]; then
        echo "warning: No dgst file for ${XRAY_BINARY}, skipping verification."
        return 0
    fi

    # Verify SHA256 — dgst format is "SHA2-256= <hash>"
    ACTUAL_SHA256="$(sha256sum "$ZIP_FILE" | awk '{print $1}')"
    EXPECTED_SHA256="$(grep -i 'SHA2-256' "$DGST_FILE" | awk -F'= ' '{print $2}' | tr -d ' \r\n')"

    if [ -z "$EXPECTED_SHA256" ]; then
        echo "warning: Could not parse SHA256 from dgst file, skipping verification."
        return 0
    fi

    if [ "$ACTUAL_SHA256" != "$EXPECTED_SHA256" ]; then
        echo "error: SHA256 check failed!"
        echo "  Expected: $EXPECTED_SHA256"
        echo "  Actual:   $ACTUAL_SHA256"
        exit 1
    fi

    echo "SHA256 verification passed."
}

install_xray() {
    if [ -z "${XRAY_BINARY}" ]; then
        echo "error: XRAY_BINARY env is not set. Cannot determine version to download."
        exit 1
    fi
    XRAY_BINARY="$(version_number "$XRAY_BINARY")"
    download_xray
    decompression "$ZIP_FILE"
}

main() {
    install_xray
}

main