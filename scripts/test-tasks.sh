#!/bin/sh
# The tests of examples/tasks: the integration tests, then the Cypress E2E
# tests. They need Docker (PostgreSQL on port 5437; with CI set, a PostgreSQL
# that already runs on that port), psql, the matcha binary, Elixir (for the
# Cucumber scenarios), Node.js 18 or later and the port 3000 free.
# "make test-tasks" runs this script.
set -eu

(cd examples/tasks && make test-integration)
(cd examples/tasks && sh test/e2e.sh)
