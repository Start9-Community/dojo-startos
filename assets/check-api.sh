#!/bin/bash
# vim: sw=2 ts=2 sts=2 et ai

source /assets/config.env
source /assets/functions.sh

access_token=$(cat /run/secrets/access_token 2>/dev/null)

if [ -z "$access_token" ] || ! check_token "$access_token"; then
  access_token=$(do_authenticate "$NODE_ADMIN_KEY")
fi

if [ -z "$access_token" ]; then
  echo "Waiting for the accounts API to accept the admin key..." >&2
  exit 60
fi

if get_account_status "$access_token"; then
  exit 0
fi

echo "Waiting for the accounts API to answer..." >&2
exit 61
