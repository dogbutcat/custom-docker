#!/bin/sh
# Entrypoint: dispatch commands or start xray
case "$1" in
	scan-sni)
		shift
		exec scan-sni "$@"
		;;
	xray)
		shift
		exec xray "$@"
		;;
	"")
		exec script/start-xray.sh
		;;
	*)
		exec "$@"
		;;
esac
