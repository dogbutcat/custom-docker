#!/bin/bash

# Install Xray-core for the docker image
# https://github.com/XTLS/Xray-core

set -euo pipefail

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
mkdir -p "$DAT_PATH"
TMP_DIRECTORY=$(mktemp -d "${DAT_PATH}.xray-install.XXXXXX")
# Only this invocation's private staging directory is removed on exit.
trap 'rm -rf -- "$TMP_DIRECTORY"' EXIT
ZIP_FILE="${TMP_DIRECTORY}/xray-linux-$MACHINE.zip"

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
        exit 1
    fi
    echo "info: Extract the xray package to $TMP_DIRECTORY and prepare it for installation."
}

download_xray() {
    DOWNLOAD_LINK="https://github.com/XTLS/Xray-core/releases/download/$XRAY_BINARY/Xray-linux-$MACHINE.zip"
    echo "Downloading xray archive: $DOWNLOAD_LINK"
    if ! curl --fail --location --retry 3 --retry-delay 1 --retry-max-time 120 --connect-timeout 10 --max-time 60 \
        -H 'Cache-Control: no-cache' -o "$ZIP_FILE" "$DOWNLOAD_LINK"; then
        echo 'error: Download failed! Please check your network or try again.'
        exit 1
    fi

    DGST_FILE="${ZIP_FILE}.dgst"
    echo "Downloading verification file: ${DOWNLOAD_LINK}.dgst"
    if ! curl --fail --location --retry 3 --retry-delay 1 --retry-max-time 120 --connect-timeout 10 --max-time 60 \
        -H 'Cache-Control: no-cache' -o "$DGST_FILE" "${DOWNLOAD_LINK}.dgst"; then
        echo 'error: Could not download dgst file; verification is required.' >&2
        exit 1
    fi

    # Verify SHA256 — dgst format is "SHA2-256= <hash>"
    ACTUAL_SHA256="$(sha256sum "$ZIP_FILE" | awk '{print $1}')"
    EXPECTED_SHA256=''
    DIGEST_PATTERN='^[[:space:]]*(SHA2-256|SHA256)[[:space:]]*(\([^)]*\))?[[:space:]]*=[[:space:]]*([[:xdigit:]]{64})[[:space:]]*$'
    while IFS= read -r LINE || [[ -n "$LINE" ]]; do
        if [[ "$LINE" =~ $DIGEST_PATTERN ]]; then
            if [[ -n "$EXPECTED_SHA256" ]]; then
                echo 'error: Ambiguous SHA256 digest file.' >&2
                exit 1
            fi
            EXPECTED_SHA256="$(printf '%s' "${BASH_REMATCH[3]}" | tr 'A-F' 'a-f')"
        fi
    done < "$DGST_FILE"

    if [ -z "$EXPECTED_SHA256" ]; then
        echo 'error: Could not parse a valid 64-hex SHA256 digest.' >&2
        exit 1
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
    if [ -z "${XRAY_BINARY:-}" ]; then
        echo "error: XRAY_BINARY env is not set. Cannot determine version to download."
        exit 1
    fi
    XRAY_BINARY="$(version_number "$XRAY_BINARY")"
    download_xray
    decompression "$ZIP_FILE"
    if [[ ! -s "${TMP_DIRECTORY}/xray" ]]; then
        echo 'error: The verified archive does not contain the xray binary.' >&2
        exit 1
    fi
    install -m 755 "${TMP_DIRECTORY}/xray" "${DAT_PATH}xray"
}

main() {
    install_xray
}

main
