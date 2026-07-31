#!/bin/bash
set -ea

source /assets/config.env

# Dojo reads its own onion, and the explorer's, out of the Tor data directory
# that upstream's compose stack shares with a tor container. StartOS resolves
# both instead, so seed the files Dojo expects to find.
echo "[i] Dojo Tor address: $TOR_ADDRESS"
mkdir -p /var/lib/tor/hsv3dojo
echo -n "$TOR_ADDRESS" > /var/lib/tor/hsv3dojo/hostname

if [ "$COMMON_BTC_NETWORK" = "testnet" ]; then
	API_BASE_URI=/test/v2
	EXPLORER_ENDPOINT="$EXPLORER_ONION/testnet4"
	cp /home/node/app/static/admin/conf/index-testnet.js /home/node/app/static/admin/conf/index.js
else
	API_BASE_URI=/v2
	EXPLORER_ENDPOINT="$EXPLORER_ONION"
	cp /home/node/app/static/admin/conf/index-mainnet.js /home/node/app/static/admin/conf/index.js
fi

mkdir -p /var/lib/tor/hsv3explorer
echo -n "$EXPLORER_ENDPOINT" > /var/lib/tor/hsv3explorer/hostname

echo "[i] Pairing URL: http://$TOR_ADDRESS$API_BASE_URI"

# The same payload the maintenance tool assembles on its Pairing screen: Dojo's
# /support/pairing response, plus the API url a browser would have filled in
# from its own location. Read back by the View Pairing Code action.
cat > "$S9_DATA_DIR/backend.json" << EOF
{
  "pairingCode": "{\"pairing\":{\"type\":\"dojo.api\",\"version\":\"$DOJO_VERSION_TAG\",\"apikey\":\"$NODE_API_KEY\",\"url\":\"http://$TOR_ADDRESS$API_BASE_URI\"},\"explorer\":{\"type\":\"explorer.$EXPLORER_TYPE\",\"url\":\"http://$EXPLORER_ENDPOINT\"}}"
}
EOF

exec pm2-runtime -u node --raw /home/node/app/pm2.config.cjs
