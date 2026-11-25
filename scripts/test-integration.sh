#!/bin/sh
# The integration tests of the examples. "make test-integration" runs this
# script, and so does the integration job of CI. The database and
# multi_format examples need PostgreSQL on port 5435.
set -eu

(cd examples/simplest && make test-integration)
(cd examples/simple && make test-integration)
(cd examples/custom_context && make test-integration)
(cd examples/static && make test-integration)
(cd examples/streaming && make test-integration)
(cd examples/rate_limiter && make test-integration)
(cd examples/database && make test-integration)
(cd examples/multi_format && make test-integration)
(cd examples/streaming_capabilities && make test-integration)
(cd examples/websocket_chat && make test-integration)
(cd examples/sse && make test-integration)
# Example apps of the guides: unit tests only, no network, no database
(cd examples/configuration && make test)
(cd examples/outbound_http && make test)
(cd examples/cache && make test)
(cd examples/rate_limiter && make test)
(cd examples/fake_api && make test)
(cd examples/background_work && make test)
# Plays back recorded HTTP calls and queries: no network and no database
(cd examples/recorded_tests && make test)

echo ""
echo "✅ All integration tests passed!"
