# Proves the queries of src/models/ and the code that dream_model makes from
# them: each generated model module must be what dream_model generates, and
# "make models" must run. The test-integration target of the Makefile runs
# this script from the example folder, after the migrations.
set -eu
export DATABASE_URL=postgres://postgres:postgres@localhost:5437/tasks_db
gleam run -m dream_model -- --check
make models
