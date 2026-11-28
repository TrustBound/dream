#!/bin/sh
# Records the HTTP calls and the queries of the tests again. "make record"
# runs this script. It needs Docker, for the database. The fake carrier
# API runs inside the tests.
set -eu

docker compose up -d --wait postgres
trap 'docker compose down -v' EXIT
RECORDER_MODE=record gleam test
