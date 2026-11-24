# Proves the queries of src/sql/ and the code that dream_sql_generator makes from them:
# src/sql.gleam must be what dream_sql_generator generates, and "make squirrel" must
# run. The test-integration target of the Makefile runs this script from
# the example folder, after the migrations.
set -eu
export DATABASE_URL=postgres://postgres:postgres@localhost:5435/dream_example_database_db
gleam run -m dream_sql_generator check
make squirrel
