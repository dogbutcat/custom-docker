#!/bin/bash

# Install RealiTLScanner for Reality SNI scanning
# https://github.com/XTLS/RealiTLScanner

SCANNER_VERSION="v0.2.1"
INSTALL_DIR="/usr/bin/xray"

identify_arch() {
    case "$(uname -m)" in
        x86_64|amd64)   echo "64" ;;
        *)
            echo "warning: RealiTLScanner only provides linux-64 binary, skipping for $(uname -m)" >&2
            exit 0
            ;;
    esac
}

ARCH=$(identify_arch)
DOWNLOAD_URL="https://github.com/XTLS/RealiTLScanner/releases/download/${SCANNER_VERSION}/RealiTLScanner-linux-${ARCH}"

echo "Downloading RealiTLScanner ${SCANNER_VERSION}..."
if ! curl -L -H 'Cache-Control: no-cache' -o "${INSTALL_DIR}/RealiTLScanner" "$DOWNLOAD_URL"; then
    echo "error: Download failed! RealiTLScanner will not be available."
    exit 0  # Non-fatal, scanner is optional
fi

chmod +x "${INSTALL_DIR}/RealiTLScanner"
echo "RealiTLScanner installed to ${INSTALL_DIR}/RealiTLScanner"
