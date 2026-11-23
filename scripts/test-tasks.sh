#!/bin/sh
# The tests of examples/tasks: the integration tests, then the Cypress E2E
# tests. They need Docker (PostgreSQL on port 5437), the matcha binary,
# Node.js and the port 3000 free. "make test-tasks" runs this script.
set -eu

(cd examples/tasks && make test-integration)
(cd examples/tasks && sh test/e2e.sh)
