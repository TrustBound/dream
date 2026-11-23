# Proves the queries of the sql/ folders of src/ and the code that Squirrel
# makes from them: each sql.gleam must be what Squirrel generates, and
# "make squirrel" must run. The test-integration target of the Makefile runs
# this script from the example folder, after the migrations.
set -eu
export DATABASE_URL=postgres://postgres:postgres@localhost:5437/tasks_db
gleam run -m squirrel check
make squirrel
