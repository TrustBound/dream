# The Cypress commands of cypress/README.md. scripts/test-tasks.sh runs them
# from the example folder. "make e2e-test" starts the database and the
# server, and stops them at the end.
set -eu
make e2e-install
make e2e-test
make e2e-clean
