#!/bin/bash
# Runs one example's Cucumber scenarios against a running copy of it.
#
#   run-scenarios.sh NAME PORT MODULE PROTOCOL
#
# NAME     the example's name, for the log file
# PORT     the port the example listens on
# MODULE   the Gleam module to run: main for HTTP, tls_main for HTTPS
# PROTOCOL http1 (plain HTTP, HTTP/1.1) or http2 (HTTPS, HTTP/2 only)
#
# Run it from the example's folder. For http2 it writes a test certificate
# authority and server certificate to build/test_tls first.
set -u
NAME=$1
PORT=$2
MODULE=$3
PROTOCOL=$4
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LOG=/tmp/${NAME}_${PROTOCOL}_test.log

(cd "$ROOT/integration/bridge" && gleam build > /dev/null 2>&1) || {
  echo "Failed to build integration/bridge"
  exit 1
}

SCHEME=http
CA_FILE=""
if [ "$PROTOCOL" = "http2" ]; then
  SCHEME=https
  CA_FILE="$PWD/build/test_tls/ca.pem"
  erl -noshell -pa "$ROOT"/integration/bridge/build/dev/erlang/*/ebin \
    -eval 'integration_certificates:write(<<"build/test_tls">>), halt().' || exit 1
fi

echo "=== $NAME: $PROTOCOL over $SCHEME ==="
gleam run -m "$MODULE" > "$LOG" 2>&1 &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null; sleep 1; kill -9 $SERVER_PID 2>/dev/null; lsof -ti:'"$PORT"' 2>/dev/null | xargs kill -9 2>/dev/null' EXIT

for i in $(seq 1 30); do
  if curl -sk "$SCHEME://localhost:$PORT/" > /dev/null 2>&1; then
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "Server failed to start"
    tail -20 "$LOG"
    exit 1
  fi
  sleep 1
done

mix deps.get > /dev/null 2>&1
DREAM_TEST_PROTOCOL=$PROTOCOL DREAM_TEST_CA_FILE=$CA_FILE MIX_ENV=test mix test
