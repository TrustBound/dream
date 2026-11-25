#!/bin/sh
# Records the OpenSearch calls of the tests again. "make record" runs this
# script. It needs Docker.
set -eu

docker compose up -d --wait opensearch
trap 'docker compose down -v' EXIT
# OpenSearch stops putting shards on a disk that is more than 90% full, and
# then the index of the tests never gets ready. The node only holds test
# data, so turn the disk check off.
curl -sf -X PUT localhost:19200/_cluster/settings \
  -H 'content-type: application/json' \
  -d '{"transient":{"cluster.routing.allocation.disk.threshold_enabled":false}}'
echo
RECORDER_MODE=record gleam test
