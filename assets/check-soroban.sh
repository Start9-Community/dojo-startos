#!/bin/bash
# vim: sw=2 ts=2 sts=2 et ai

source /assets/config.env

if ! pgrep -f soroban-server > /dev/null; then
  echo "Soroban has not started yet" >&2
  exit 60
fi

if ! nc -z "$NET_DOJO_SOROBAN_IPV4" "$SOROBAN_PORT" 2>/dev/null; then
  echo "Soroban is not listening on port $SOROBAN_PORT yet" >&2
  exit 61
fi

exit 0
