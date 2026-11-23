#!/bin/sh
# What the integration job of CI runs. PostgreSQL runs as a service of the
# job on port 5435, with the database dream_example_database_db, and the job
# sets CI, PGPASSWORD and DATABASE_URL.
set -eu

psql -h localhost -p 5435 -U postgres -c "CREATE DATABASE dream_example_multi_format_db;" || true
(cd examples/database && gleam run -m cigogne all)
(cd examples/multi_format && DATABASE_URL=postgres://postgres:postgres@localhost:5435/dream_example_multi_format_db gleam run -m cigogne all)

make test-integration
