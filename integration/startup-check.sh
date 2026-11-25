#!/bin/bash
# Proves the start-up of an example that runs
# check_schema_waiting_for_database after the pool starts.
#
#   startup-check.sh PORT DATABASE TABLE COLUMN
#
# PORT      the port the example listens on
# DATABASE  the database of the example, in the postgres service of its
#           docker-compose.yml
# TABLE     a table that a model of the example reads
# COLUMN    a NOT NULL column of TABLE
#
# Run it from the example's folder, with the database up and migrated, and
# with no server of the example running. It runs "gleam run -m main" two
# times:
#
# 1. With the postgres container stopped. The app must print two
#    "Waiting for the database (Ns of 30s)" lines. Then the script starts
#    the container, and the app must start and answer on PORT.
# 2. With COLUMN of TABLE changed to allow NULL. The app must stop with
#    exit status 1 and the message of a changed schema, and it must print
#    no "Waiting for the database" line. Then the script sets the column
#    back to NOT NULL.
#
# It stops and starts the container of Docker Compose, so CI does not run it.
set -u
PORT=$1
DATABASE=$2
TABLE=$3
COLUMN=$4
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SERVER="$ROOT/integration/example-server.sh"
PIDFILE="$PWD/build/startup.pid"
LOG="$PWD/build/startup.log"

sql() {
  docker-compose exec -T postgres \
    psql -U postgres -d "$DATABASE" -q -c "$1" > /dev/null
}

wait_for_database() {
  for _ in $(seq 1 30); do
    if docker-compose exec -T postgres pg_isready -U postgres > /dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# Waits at most $2 seconds for the line $1 in the log of the app
wait_for_log() {
  for _ in $(seq 1 "$2"); do
    if grep -qF "$1" "$LOG" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

# Puts the database back as it was, and stops the app
restore() {
  "$SERVER" stop "$PIDFILE" > /dev/null
  docker-compose start postgres > /dev/null 2>&1
  wait_for_database
  sql "ALTER TABLE $TABLE ALTER COLUMN $COLUMN SET NOT NULL" 2>/dev/null
}
trap restore EXIT

fail() {
  echo "$1"
  tail -20 "$LOG"
  exit 1
}

echo "=== Start-up: the app waits for the database ==="
docker-compose stop postgres > /dev/null 2>&1 || fail "Cannot stop the postgres container"
started=$(date +%s)
"$SERVER" start "$PIDFILE" "$LOG" "$PORT" gleam run -m main || exit 1
waited=0
for _ in $(seq 1 30); do
  if [ "$(grep -c 'Waiting for the database (.*s of 30s)' "$LOG" 2>/dev/null)" -ge 2 ]; then
    waited=1
    break
  fi
  sleep 1
done
[ "$waited" -eq 1 ] || fail "The app did not wait for the database"
docker-compose start postgres > /dev/null 2>&1 || fail "Cannot start the postgres container"
answered=0
for _ in $(seq 1 40); do
  if curl -s "http://localhost:$PORT/" > /dev/null 2>&1; then
    answered=1
    break
  fi
  sleep 1
done
[ "$answered" -eq 1 ] || fail "The app did not start after the database came up"
echo "The app waited ($(grep -c 'Waiting for the database' "$LOG") attempts) and started after $(($(date +%s) - started)) seconds."
"$SERVER" stop "$PIDFILE" > /dev/null

echo "=== Start-up: the app stops at once when the schema changed ==="
wait_for_database || fail "The database did not come up"
sql "ALTER TABLE $TABLE ALTER COLUMN $COLUMN DROP NOT NULL" \
  || fail "Cannot change $TABLE.$COLUMN"
started=$(date +%s)
"$SERVER" start "$PIDFILE" "$LOG" "$PORT" \
  sh -c 'gleam run -m main; echo "Exit status: $?"' || exit 1
wait_for_log "Exit status:" 30 || fail "The app did not stop"
grep -qF "Exit status: 1" "$LOG" || fail "The app did not stop with exit status 1"
grep -qF "The database schema changed after dream_model generated these modules" "$LOG" \
  || fail "The app did not print the message of a changed schema"
if grep -qF "Waiting for the database" "$LOG"; then
  fail "The app waited for the database with a changed schema"
fi
echo "The app stopped with exit status 1 after $(($(date +%s) - started)) seconds."
