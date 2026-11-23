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
#
# The runs also prove the commands of the README of the example:
#
# - test/integration/start.sh, when the example has one, starts the server
#   in place of "gleam run -m MODULE". It runs from the repository root.
# - test/integration/readme.sh, when the example has one, runs once the
#   server answers, with bash, in an empty folder. Its standard output must
#   be the same as test/integration/readme_output.txt. In the http2 run,
#   test/integration/readme_http2.sh and readme_http2_output.txt do the same
#   against the HTTPS server. The comparison makes three changes that
#   make it the same on every run: the carriage returns of "curl -i" headers
#   are removed, the value of each "date:" header line is replaced with
#   "(the time of the request)", and each UTC timestamp such as
#   2026-01-02T03:04:05.123456Z (a created_at value) is replaced with
#   "(a time)".
#
# The Cucumber scenarios run when the example has a mix.exs.
set -u
NAME=$1
PORT=$2
MODULE=$3
PROTOCOL=$4
ROOT=$(cd "$(dirname "$0")/.." && pwd)
LOG=/tmp/${NAME}_${PROTOCOL}_test.log

if ! output=$(cd "$ROOT/integration/bridge" && gleam build 2>&1); then
  echo "$output"
  echo "Failed to build integration/bridge"
  exit 1
fi

SCHEME=http
CA_FILE=""
if [ "$PROTOCOL" = "http2" ]; then
  SCHEME=https
  CA_FILE="$PWD/build/test_tls/ca.pem"
  erl -noshell -pa "$ROOT"/integration/bridge/build/dev/erlang/*/ebin \
    -eval 'integration_certificates:write(<<"build/test_tls">>), halt().' || exit 1
fi

EXAMPLE=$PWD
START="$EXAMPLE/test/integration/start.sh"
COMMANDS="$EXAMPLE/test/integration/readme.sh"
EXPECTED="$EXAMPLE/test/integration/readme_output.txt"
if [ "$PROTOCOL" = "http2" ]; then
  COMMANDS="$EXAMPLE/test/integration/readme_http2.sh"
  EXPECTED="$EXAMPLE/test/integration/readme_http2_output.txt"
fi

echo "=== $NAME: $PROTOCOL over $SCHEME ==="
if [ "$PROTOCOL" = "http1" ] && [ -f "$START" ]; then
  (cd "$ROOT" && exec sh "$START") > "$LOG" 2>&1 &
else
  gleam run -m "$MODULE" > "$LOG" 2>&1 &
fi
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

if [ -f "$COMMANDS" ]; then
  echo "=== $NAME: the README commands ==="
  WORK=$(mktemp -d)
  if ! (cd "$WORK" && bash "$COMMANDS") > "$WORK.raw" 2>> "$LOG"; then
    echo "The README commands failed. See $LOG."
    exit 1
  fi
  tr -d '\r' < "$WORK.raw" \
    | sed -e 's/^date: .*$/date: (the time of the request)/' \
      -e 's/[0-9]\{4\}-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]\(\.[0-9]*\)\{0,1\}Z/(a time)/g' \
    > "$WORK.out"
  if ! diff -u "$EXPECTED" "$WORK.out"; then
    echo "The README commands gave other output than $EXPECTED."
    exit 1
  fi
  rm -rf "$WORK" "$WORK.raw" "$WORK.out"
  echo "The README commands gave the expected output."
fi

if [ -f mix.exs ]; then
  mix deps.get > /dev/null 2>&1
  DREAM_TEST_PROTOCOL=$PROTOCOL DREAM_TEST_CA_FILE=$CA_FILE MIX_ENV=test mix test
fi
