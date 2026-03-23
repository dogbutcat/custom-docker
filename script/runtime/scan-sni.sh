#!/bin/sh

# Wrapper script for RealiTLScanner
# Usage:
#   docker run --rm --network host <image> scan-sni           # Auto-detect, scan /24
#   docker exec <container> scan-sni -addr 1.2.3.0/24         # Manual subnet
#   docker exec <container> scan-sni -addr 1.2.3.0/24 -n 10   # With concurrency limit

SCANNER="/usr/bin/xray/RealiTLScanner"

if [ ! -x "$SCANNER" ]; then
    echo "error: RealiTLScanner not found. It may not be available on this architecture."
    exit 1
fi

# If no args provided, auto-detect VPS IP and scan /24
if [ $# -eq 0 ]; then
    echo "Auto-detecting VPS public IP..."

    # Method 1: host networking — get default route source IP
    VPS_IP=$(ip route get 8.8.8.8 2>/dev/null | awk '/src/{for(i=1;i<=NF;i++) if($i=="src") print $(i+1)}')

    # Method 2: fallback to external API
    if [ -z "$VPS_IP" ] || echo "$VPS_IP" | grep -qE '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)'; then
        VPS_IP=$(wget -qO- https://api4.ipify.org 2>/dev/null || \
                 wget -qO- https://ipv4.icanhazip.com 2>/dev/null)
    fi

    if [ -z "$VPS_IP" ]; then
        echo "error: Could not detect VPS public IP."
        echo "Tip: run with --network host for auto-detection:"
        echo "  docker run --rm --network host <image> scan-sni"
        echo "Or specify manually:"
        echo "  scan-sni -addr YOUR_VPS_IP/24"
        exit 1
    fi

    SUBNET=$(echo "$VPS_IP" | sed 's/\.[0-9]*$/.0\/24/')
    echo "VPS IP: $VPS_IP"
    echo "Scanning subnet: $SUBNET"
    echo "Looking for TLS 1.3 + H2 targets suitable for Reality..."
    echo "---"
    exec "$SCANNER" -addr "$SUBNET"
else
    exec "$SCANNER" "$@"
fi
