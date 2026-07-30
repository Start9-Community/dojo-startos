#!/bin/bash
# vim: sw=2 ts=2 sts=2 et ai

source /assets/config.env

info=$(curl -sS --user "$BITCOIND_RPC_USER:$BITCOIND_RPC_PASSWORD" --data-binary '{"jsonrpc": "1.0", "id": "gni", "method": "getnetworkinfo", "params": []}' -H 'content-type: text/plain;' "http://$BITCOIND_IP:$BITCOIND_RPC_PORT/" 2>&1)

subversion=$(echo "$info" | jq -r '.result.subversion // empty' 2>/dev/null)

if [ -z "$subversion" ]; then
  echo "Waiting for Bitcoin's RPC..." >&2
  exit 60
fi

# Dojo exits on any node whose subversion contains "Knots"
# (lib/bitcoind-rpc/rpc-client.js). Caught here so the reason is on the service
# page instead of buried in a crash-looping API's logs.
case "$subversion" in
*Knots*)
  echo "Dojo does not support Bitcoin Knots ($subversion). Switch to Bitcoin Core." >&2
  exit 62
  ;;
esac

exit 0
