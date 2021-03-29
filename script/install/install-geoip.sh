#!/bin/bash

# This Bash script to install the latest release of geoip.dat and geosite.dat:

# https://github.com/v2fly/geoip
# https://github.com/v2fly/domain-list-community

# Depends on cURL, please solve it yourself

# You may plan to execute this Bash script regularly:

# install -m 755 install-dat-release.sh /usr/local/bin/install-dat-release

# 0 0 * * * /usr/local/bin/install-dat-release > /dev/null 2>&1

# You can modify it to /usr/local/lib/xray/
XRAY="/usr/bin/xray/"
DOWNLOAD_LINK_GEOIP="https://github.com/v2fly/geoip/releases/latest/download/geoip.dat"
DOWNLOAD_LINK_GEOSITE="https://github.com/v2fly/domain-list-community/releases/latest/download/dlc.dat"

download_geoip() {
    echo "Starting Download GEOIP: ${DOWNLOAD_LINK_GEOIP}"
    if ! curl -L -H 'Cache-Control: no-cache' -o "${XRAY}geoip.dat.new" "$DOWNLOAD_LINK_GEOIP"; then
        echo 'error: Download failed! Please check your network or try again.'
        exit 1
    fi
    if ! curl -L -H 'Cache-Control: no-cache' -o "${XRAY}geoip.dat.sha256sum.new" "$DOWNLOAD_LINK_GEOIP.sha256sum"; then
        echo 'error: Download failed! Please check your network or try again.'
        exit 1
    fi
    SUM="$(sha256sum ${XRAY}geoip.dat.new | sed 's/ .*//')"
    CHECKSUM="$(sed 's/ .*//' ${XRAY}geoip.dat.sha256sum.new)"
    if [[ "$SUM" != "$CHECKSUM" ]]; then
        echo 'error: Check failed! Please check your network or try again.'
        exit 1
    fi
}

download_geosite() {
    echo "Starting Download GEOSITE: ${DOWNLOAD_LINK_GEOSITE}"
    if ! curl -L -H 'Cache-Control: no-cache' -o "${XRAY}geosite.dat.new" "$DOWNLOAD_LINK_GEOSITE"; then
        echo 'error: Download failed! Please check your network or try again.'
        exit 1
    fi
    if ! curl -L -H 'Cache-Control: no-cache' -o "${XRAY}geosite.dat.sha256sum.new" "$DOWNLOAD_LINK_GEOSITE.sha256sum"; then
        echo 'error: Download failed! Please check your network or try again.'
        exit 1
    fi
    SUM="$(sha256sum ${XRAY}geosite.dat.new | sed 's/ .*//')"
    CHECKSUM="$(sed 's/ .*//' ${XRAY}geosite.dat.sha256sum.new)"
    if [[ "$SUM" != "$CHECKSUM" ]]; then
        echo 'error: Check failed! Please check your network or try again.'
        exit 1
    fi
}

rename_new() {
    for DAT in 'geoip' 'geosite'; do
        install -m 644 "${XRAY}$DAT.dat.new" "${XRAY}$DAT.dat"
        rm "${XRAY}$DAT.dat.new"
        rm "${XRAY}$DAT.dat.sha256sum.new"
    done
}

main() {
    download_geoip
    download_geosite
    rename_new
}

main