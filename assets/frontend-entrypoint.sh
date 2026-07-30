#!/bin/bash
set -ea

source /assets/config.env

# The two site configs differ in the path prefix they proxy (/v2 vs /test/v2),
# so the enabled one follows the selected network.
if [ "$COMMON_BTC_NETWORK" = "testnet" ]; then
	ln -sf /etc/nginx/sites-available/testnet.conf /etc/nginx/sites-enabled/dojo.conf
else
	ln -sf /etc/nginx/sites-available/mainnet.conf /etc/nginx/sites-enabled/dojo.conf
fi

# nginx.conf carries `daemon off`, so this stays in the foreground.
exec nginx
