#!/bin/bash

# Install RealiTLScanner for Reality SNI scanning
# https://github.com/XTLS/RealiTLScanner

set -euo pipefail

SCANNER_VERSION="v0.2.1"
INSTALL_DIR="/usr/bin/xray/optional"
mkdir -p "$INSTALL_DIR"
# Never retain a previous executable after a skipped or failed optional install.
rm -f -- "${INSTALL_DIR}/RealiTLScanner"

MACHINE=$(uname -m)
case "$MACHINE" in
    x86_64|amd64) ARCH="64" ;;
    *)
        echo "warning: RealiTLScanner only provides linux-64 binary, skipping for $MACHINE" >&2
        exit 0
        ;;
esac
DOWNLOAD_URL="https://github.com/XTLS/RealiTLScanner/releases/download/${SCANNER_VERSION}/RealiTLScanner-linux-${ARCH}"
SCANNER_FILE=$(mktemp "${INSTALL_DIR}/.RealiTLScanner.XXXXXX")
trap 'rm -f -- "$SCANNER_FILE"' EXIT

echo "Downloading RealiTLScanner ${SCANNER_VERSION}..."
if ! curl --fail --location --retry 3 --retry-delay 1 --retry-max-time 120 --connect-timeout 10 --max-time 60 \
    -H 'Cache-Control: no-cache' -o "$SCANNER_FILE" "$DOWNLOAD_URL"; then
    echo "error: Download failed! RealiTLScanner will not be available."
    exit 0  # Non-fatal, scanner is optional
fi

# Validate a complete little-endian ELF64 header for the official x86-64 asset.
HEADER=$(od -An -tx1 -N20 "$SCANNER_FILE" | tr -d ' \n')
if [[ $(wc -c < "$SCANNER_FILE") -lt 64 || "$HEADER" != 7f454c460201*3e00 ]]; then
    echo 'warning: Invalid RealiTLScanner ELF response; scanner will not be available.' >&2
    exit 0
fi
if ! chmod 755 "$SCANNER_FILE" || ! mv "$SCANNER_FILE" "${INSTALL_DIR}/RealiTLScanner"; then
    echo 'warning: Could not install RealiTLScanner; scanner will not be available.' >&2
    exit 0
fi
echo "RealiTLScanner installed to ${INSTALL_DIR}/RealiTLScanner"
