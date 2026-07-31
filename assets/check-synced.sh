#!/bin/bash
# vim: sw=2 ts=2 sts=2 et ai

source /assets/config.env
source /assets/functions.sh

bci_result=$(curl -sS --user "$BITCOIND_RPC_USER:$BITCOIND_RPC_PASSWORD" --data-binary '{"jsonrpc": "1.0", "id": "gbci", "method": "getblockchaininfo", "params": []}' -H 'content-type: text/plain;' "http://$BITCOIND_IP:$BITCOIND_RPC_PORT/" 2>&1)
bci_return=$?
bci_error=$(echo "$bci_result" | jq -r '.message // "null"' 2>/dev/null)

if [[ $bci_return -ne 0 ]]; then
  echo "Error contacting Bitcoin RPC: $bci_result" >&2
  exit 61
elif [ "$bci_error" != "null" ]; then
  echo "Bitcoin RPC returned error: $bci_error" >&2
  exit 61
fi

bci_block_count=$(echo "$bci_result" | jq -r '.result.blocks // "null"' 2>/dev/null)
bci_block_ibd=$(echo "$bci_result" | jq -r '.result.initialblockdownload' 2>/dev/null)
if [ "$bci_block_count" = "null" ]; then
  echo "Error ascertaining Bitcoin blockchain status: $bci_error" >&2
  exit 61
elif [ "$bci_block_ibd" != "false" ]; then
  bci_block_headers=$(echo "$bci_result" | jq -r '.result.headers // 0' 2>/dev/null)
  if [ "$bci_block_headers" -gt 0 ]; then
    echo "Bitcoin is not fully synced yet: $bci_block_count of $bci_block_headers blocks ($((bci_block_count * 100 / bci_block_headers))%)" >&2
  else
    echo "Bitcoin is not fully synced yet" >&2
  fi
  exit 61
fi

access_token=$(cat /run/secrets/access_token 2>/dev/null)

if [ -z "$access_token" ] || ! check_token "$access_token"; then
  access_token=$(do_authenticate "$NODE_ADMIN_KEY")
fi

if [ -z "$access_token" ]; then
  # Starting
  exit 60
fi

account_status=$(get_account_status "$access_token")
pushtx_status=$(get_pushtx_status "$access_token")
synced_blocks=$(echo "$account_status" | jq -r '.blocks // "null"' 2>/dev/null)
bitcoind_blocks=$(echo "$pushtx_status" | jq -r '.data.bitcoind.blocks // "null"' 2>/dev/null)

# Both read "null" until Dojo has answered with a height. Comparing them
# numerically at that point makes bash read both as 0 and report "synced".
if [ "$synced_blocks" = "null" ] || [ "$bitcoind_blocks" = "null" ] || [ "$bitcoind_blocks" -le 0 ]; then
  echo "Waiting for Dojo to report its height..." >&2
  exit 60
elif [ "$synced_blocks" -ge "$bitcoind_blocks" ]; then
  exit 0
else
  echo "Syncing - $((synced_blocks * 100 / bitcoind_blocks))% (Block #$synced_blocks)" >&2
  exit 61
fi
