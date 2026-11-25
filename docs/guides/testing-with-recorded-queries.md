[README](https://hexdocs.pm/dream/3.0.0/) > [Guides](https://hexdocs.pm/dream/3.0.0/guides/index.html) > Test a Dream app's database code with recorded queries

# Test a Dream app's database code with recorded queries

Your app keeps its data in PostgreSQL, and its tests must check the SQL: the queries, the transactions, the constraints. A test against a real database is the true check, but it needs a server on each machine and in CI, and a schema in the right state. A recording gives you both. You run the tests one time against PostgreSQL in Docker, and the recorder of [`dream_postgres`](https://hexdocs.pm/dream_postgres/2.0.0/) writes each query and its result to a file. You commit the file. After that, the tests play the file back, with no database. This guide builds a small Dream app for shopping lists, and tests it through its routes with recorded queries.

Why test at this boundary, and not with a mock of your own models: see [Mock at the system boundary](https://hexdocs.pm/dream_test/3.0.0/guides/mock-at-the-boundary.html).

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which mode to use](#which-mode-to-use)
- [Step 1: Keep the connection in services](#step-1-keep-the-connection-in-services)
- [Step 2: Start PostgreSQL for a record run](#step-2-start-postgresql-for-a-record-run)
- [Step 3: Connect through a recorder in the suite setup](#step-3-connect-through-a-recorder-in-the-suite-setup)
- [Step 4: Test the app through its routes](#step-4-test-the-app-through-its-routes)
- [Step 5: Record one time](#step-5-record-one-time)
- [Step 6: Play back with no database](#step-6-play-back-with-no-database)
- [Step 7: Keep a secret column out of the file](#step-7-keep-a-secret-column-out-of-the-file)
- [Step 8: Read a query with no recording](#step-8-read-a-query-with-no-recording)
- [Refresh the recording](#refresh-the-recording)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide, you will:

- Keep the database connection in the services of a Dream app, as in [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html).
- Connect through a recorder in the setup of a test suite, and give the app services with that connection.
- Record the queries one time against PostgreSQL in Docker, a transaction that rolls back included.
- Play the recording back with no database.
- Keep a secret column out of the file.
- Read the test failure of a query that has no recording.

All the code is in [`examples/recorded_tests`](https://github.com/TrustBound/dream/tree/3.0.0/examples/recorded_tests) of the Dream repository. Its tests compare each output on this page with the real report.

## Before you start

You need a Dream app with Dream Test, as in [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html), and Docker for the record run. The app needs the PostgreSQL client and `dream_postgres`. The tests read the mode from the environment with `envoy`:

### The dependencies <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/gleam.toml#L9-L11"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
envoy = ">= 1.0.2 and < 2.0.0"
dream_postgres = ">= 2.0.0 and < 3.0.0"
dream_postgres_client = ">= 1.0.0 and < 2.0.0"
```

### The dev dependency <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/gleam.toml#L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
dream_test = ">= 3.0.0 and < 4.0.0"
```

## Which mode to use

A recorder runs in one of three modes. Each mode is a value of the type `recorder.Mode`:

| Your situation | Mode | What the recorder does |
|:---|:---|:---|
| You want a new recording from the database | `recorder.Record` | Runs each query on the database, and writes it and its result to the file before the query returns. |
| The tests must run with no database, as in CI | `recorder.Playback` | Connects to nothing. Each query gets the result of its recording. A query with no recording fails with `NoRecording`. |
| The recorder is in place, but you want live queries for now | `recorder.Passthrough` | Runs each query on the database, and writes nothing. |

The full API of the recorder is in [Test database code with recorded queries](https://hexdocs.pm/dream_postgres/2.0.0/guides/recorded-queries.html). This guide shows how to fit it into a Dream app and its tests.

## Step 1: Keep the connection in services

A Dream controller gets three values: the request, the context and the services. The app makes its services one time at start, and gives them to each controller. The lists app keeps its database connection there:

### The services of the lists app <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/src/lists/services.gleam#L9-L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Services {
  Services(database: Connection)
}

/// The services of the running app: a pool of connections to the
/// database at `DATABASE_URL`.
pub fn initialize_services() -> Result(Services, String) {
  use url <- result.try(
    envoy.get("DATABASE_URL")
    |> result.replace_error("Set DATABASE_URL to the URL of the database"),
  )
  use database <- result.try(
    postgres.from_url(url) |> result.map_error(string.inspect),
  )
  Ok(Services(database:))
}
```

A test makes its own `Services`, with a connection from a recorder. Each function of the model takes the connection as its first parameter, so the model does not know which connection it gets. `create` adds a list and its items in one transaction:

### Create a list in one transaction <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/src/lists/list_model.gleam#L22-L44"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Creates a list and its items in one transaction: when one item cannot
/// be saved, the database keeps nothing.
pub fn create(
  db: Connection,
  name: String,
  items: List(String),
) -> Result(ShoppingList, ListError) {
  let created = {
    use transaction <- dream_postgres_client.transaction(db)
    use id <- result.try(insert_list(transaction, name))
    use Nil <- result.try(list.try_each(items, insert_item(transaction, id, _)))
    Ok(ShoppingList(id:, name:, items:))
  }
  case created {
    Ok(shopping_list) -> Ok(shopping_list)
    Error(TransactionRolledBack(ConstraintViolated(
      constraint: "item_title_length",
      ..,
    ))) -> Error(ItemTooLong)
    Error(TransactionRolledBack(error)) -> Error(QueryFailed(error))
    Error(TransactionQueryError(error)) -> Error(QueryFailed(error))
  }
}
```

The constraint `item_title_length` of the schema allows 1 to 40 characters for an item. When an insert breaks it, the callback returns the error, the transaction rolls back, and `create` gives `ItemTooLong`. Each controller takes `services.database`, calls the model, and turns a `ListError` into a response:

### Turn a model error into a response <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/src/lists/lists_controller.gleam#L109-L126"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// The cause of a failed query stays in the server: the client gets a 500
// with no SQL in it
fn error_response(list_error: ListError) -> Response {
  case list_error {
    NoSuchList(id:) ->
      json_response(
        status.not_found,
        error_json("No list " <> int.to_string(id)),
      )
    ItemTooLong ->
      json_response(
        status.unprocessable_content,
        error_json("Each item needs 1 to 40 characters"),
      )
    QueryFailed(_) ->
      json_response(status.internal_server_error, error_json("Database error"))
  }
}
```

The app has four routes: `GET /lists`, `POST /lists`, `GET /lists/:id` and `GET /lists/:id/share`. The full code is in [`src/lists`](https://github.com/TrustBound/dream/tree/3.0.0/examples/recorded_tests/src/lists).

## Step 2: Start PostgreSQL for a record run

Only a record run needs a database. The example starts PostgreSQL 16 in Docker with its own Compose project name and a free port, so that it does not touch another PostgreSQL server on your machine:

### docker-compose.yml <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/docker-compose.yml"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```yaml
# The PostgreSQL server for a record run of the lists tests. `make record`
# starts it, and removes it with its data at the end. A playback run needs
# no server.

name: dream_recorded_tests

services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_USER: dream
      POSTGRES_PASSWORD: dream
      POSTGRES_DB: lists
    ports:
      # Port 5441 on this machine, so the record run does not use a
      # PostgreSQL server that already listens on 5432.
      - "5441:5432"
    volumes:
      # Runs when the server starts with an empty database
      - ./priv/schema.sql:/docker-entrypoint-initdb.d/schema.sql:ro
    healthcheck:
      # Over TCP: the server listens on TCP only after the schema is made
      test: ["CMD-SHELL", "pg_isready -h 127.0.0.1 -U dream -d lists"]
      interval: 1s
      timeout: 5s
      retries: 30
```

The server runs the schema file when it starts with an empty database:

### priv/schema.sql <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/priv/schema.sql"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sql
-- The schema of the lists app. The PostgreSQL server of docker-compose.yml
-- runs this file when it starts with an empty database.

CREATE TABLE lists (
  id serial PRIMARY KEY,
  name text NOT NULL,
  share_token text NOT NULL DEFAULT md5(random()::text)
);

CREATE TABLE items (
  id serial PRIMARY KEY,
  list_id integer NOT NULL REFERENCES lists (id),
  title text NOT NULL CONSTRAINT item_title_length
    CHECK (length(title) BETWEEN 1 AND 40)
);
```

A record run removes the container and its data at the end. So each record run starts from an empty database, and gives the same ids.

## Step 3: Connect through a recorder in the suite setup

A recorder keeps the queries of a suite in one file, `<directory>/<name>.json`. The setup of the suite starts it, connects through it, and builds the services of the app with that connection. The mode comes from the environment variable `RECORDER_MODE`, and `recorder.parse_mode` reads it. With no variable, the tests play back:

### Start the recorder and the services <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/recorded_queries/database_setup.gleam#L17-L59"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// What each lists test gets: the services of the app, and the recorder
/// that made their connection.
pub type App {
  App(services: Services, recorder: Recorder)
}

/// The database of `make record`. Only a record run connects to it.
const database_url = "postgresql://dream:dream@localhost:5441/lists"

/// `RECORDER_MODE=record gleam test` records. With no `RECORDER_MODE`,
/// the tests play back, so CI needs no database.
pub fn recorder_mode() -> Result(recorder.Mode, String) {
  case envoy.get("RECORDER_MODE") {
    Ok(text) -> recorder.parse_mode(text)
    Error(Nil) -> Ok(recorder.Playback)
  }
}

/// Starts a recorder that keeps the queries in
/// `test/recordings/queries/<name>.json`, and connects through it.
pub fn start_app(mode: recorder.Mode, name: String) -> Result(App, String) {
  use recorder <- result.try(
    recorder.new()
    |> recorder.directory("test/recordings/queries")
    |> recorder.name(name)
    |> recorder.mode(mode)
    |> recorder.result_transformer(hide_share_tokens)
    |> recorder.start(),
  )
  use config <- result.try(
    postgres.parse_config(process.new_name("lists_database"), database_url)
    |> result.map_error(string.inspect),
  )
  // In playback mode, nothing connects to the database
  use database <- result.try(
    recorder.connect(recorder, config) |> result.map_error(string.inspect),
  )
  Ok(App(services: Services(database:), recorder:))
}

pub fn stop_app(app: App) -> Result(Nil, String) {
  recorder.stop(app.recorder)
}
```

How it works:

- `recorder.connect` takes the `Config` of the database. In record and passthrough mode, it starts a pool. In playback mode, it starts no pool and opens no connection: the URL is not used, so the database does not have to exist.
- `Services(database:)` is the same `Services` type that the running app uses. Only the connection is different.
- When the setup returns an `Error`, no test of the suite runs, and the report shows the message. A wrong `RECORDER_MODE` stops the suite there, with the text of `parse_mode`.
- `hide_share_tokens` keeps a secret out of the file. [Step 7](#step-7-keep-a-secret-column-out-of-the-file) shows it.

## Step 4: Test the app through its routes

Each test sends a request through the router of the app with `dream.route_request`, with the services of the test. The tests share one database, so they run one at a time, in the order of the suite. Two tests make their list with the model first, then read it through a route:

### The lists suite <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/recorded_queries/lists_tests.gleam#L21-L84"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() -> TestSuite {
  describe("Lists", context.setup(start_lists_app, teardown: stop_app), [
    it("creates a list with its items", fn(app: App) {
      let response =
        request(
          app,
          Post,
          "/lists",
          "{\"name\":\"Groceries\",\"items\":[\"Milk\",\"Eggs\"]}",
        )
      #(response.status, body_text(response))
      |> should
      |> be_equal(#(
        201,
        "{\"id\":1,\"name\":\"Groceries\",\"items\":[\"Milk\",\"Eggs\"]}",
      ))
      |> or_fail_with("POST /lists should create Groceries")
    }),
    it("shows a list with its items", fn(app: App) {
      use hardware <- result.try(add_list(app, "Hardware", ["Nails", "Glue"]))
      let response = request(app, Get, "/lists/" <> hardware, "")
      body_text(response)
      |> should
      |> be_equal(
        "{\"id\":"
        <> hardware
        <> ",\"name\":\"Hardware\",\"items\":[\"Nails\",\"Glue\"]}",
      )
      |> or_fail_with("GET /lists/:id should show Hardware")
    }),
    it("keeps no list when an item is too long", fn(app: App) {
      let response =
        request(
          app,
          Post,
          "/lists",
          "{\"name\":\"Party\",\"items\":[\"Cake\",\""
            <> string.repeat("Balloons ", 5)
            <> "\"]}",
        )
      let lists = body_text(request(app, Get, "/lists", ""))
      #(response.status, string.contains(lists, "Party"))
      |> should
      |> be_equal(#(422, False))
      |> or_fail_with("the transaction should roll back, and keep no Party")
    }),
    it("shares a list with a link", fn(app: App) {
      use camping <- result.try(add_list(app, "Camping", ["Tent"]))
      // Playback gives "[hidden]": the recorder never wrote the token
      body_text(request(app, Get, "/lists/" <> camping <> "/share", ""))
      |> string.starts_with("{\"url\":\"/shared/")
      |> should
      |> be_equal(True)
      |> or_fail_with("GET /lists/:id/share should give a link")
    }),
    it("answers 404 for a list that does not exist", fn(app: App) {
      let response = request(app, Get, "/lists/999", "")
      #(response.status, body_text(response))
      |> should
      |> be_equal(#(404, "{\"error\":\"No list 999\"}"))
      |> or_fail_with("GET /lists/999 should answer 404")
    }),
  ])
}
```

The third test checks the transaction. The second item is 45 characters long, so the insert breaks the constraint. The app answers `422`, and `GET /lists` shows no list named `Party`: the database kept nothing of it.

The run gives the suite `max_concurrency: 1` in the test `main`, with `runner.add_suites_with_config`. [Test a Dream app that calls other APIs](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-http.html#step-4-test-the-app-through-its-routes) shows that `main`.

## Step 5: Record one time

`make record` in the example runs this script. It starts PostgreSQL, runs the tests with `RECORDER_MODE=record`, and removes the container and its data at the end:

### Record the tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/scripts/record.sh#L7-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sh
docker compose up -d --wait postgres
trap 'docker compose down -v' EXIT
RECORDER_MODE=record gleam test
```

The tests pass as they do in playback, and the recorder writes `test/recordings/queries/lists.json`. Each query in it has its SQL, its parameters and its result. A query of a transaction is recorded like any other. This is the insert that broke the constraint, with the error of PostgreSQL as its result:

### The failed insert in the recording <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/recordings/queries/lists.json#L96-L100"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```json
    {
      "sql": "INSERT INTO items (list_id, title) VALUES ($1, $2)",
      "parameters": [3,"Balloons Balloons Balloons Balloons Balloons "],
      "result": {"error":"constraint_violated","message":"new row for relation \"items\" violates check constraint \"item_title_length\"","constraint":"item_title_length","detail":"Failing row contains (6, 3, Balloons Balloons Balloons Balloons Balloons )."}
    },
```

In playback, this query fails with the same `ConstraintViolated` error. The callback of the transaction returns it, and `transaction` gives `TransactionRolledBack`, as it did on the live database. So the test of the rollback passes with no database too.

Read the file before you commit it. A record run accepts whatever the database answered. Then commit `test/recordings/queries` with the tests.

## Step 6: Play back with no database

Now run `gleam test` with no variable. No PostgreSQL server runs, and the tests pass from the file:

### The report of a playback run <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/outputs/queries_playback.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Lists
  ✓ creates a list with its items
  ✓ shows a list with its items
  ✓ keeps no list when an item is too long
  ✓ shares a list with a link
  ✓ answers 404 for a list that does not exist

Summary: 5 run, 0 failed, 5 passed in 0ms
```

The example sets each time to `0ms` in its outputs, so that the outputs do not change from run to run. `make test` in the example plays back, and the integration job of Dream's CI runs it with no database.

In playback mode, each query gets the first recording that it was not given yet, with the same SQL and the same parameters. So the same query two times gets its two results in recorded order. The order of different queries does not matter. [Test database code with recorded queries](https://hexdocs.pm/dream_postgres/2.0.0/guides/recorded-queries.html#how-a-query-finds-its-recording) gives the other keys, for example SQL with other whitespace.

## Step 7: Keep a secret column out of the file

The `share_token` column of a list is a secret: anyone with the link can read the list. The recording must not hold it. A result transformer changes a result before the recorder writes it, in record mode only. `hide_share_tokens` puts `[hidden]` in place of each token:

### Hide the share tokens <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/recorded_queries/database_setup.gleam#L61-L75"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Runs in record mode only, before the recorder writes a result: the
/// file never holds a share token.
fn hide_share_tokens(
  query: RecordedQuery,
  result: RecordedResult,
) -> RecordedResult {
  case string.starts_with(query.sql, "SELECT share_token"), result {
    True, Returned(count:, rows:) ->
      Returned(
        count:,
        rows: list.map(rows, fn(_row) { Tuple([Text("[hidden]")]) }),
      )
    _, _ -> result
  }
}
```

The recording of the share query holds no token:

### The share query in the recording <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/recordings/queries/lists.json#L130-L139"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```json
    {
      "sql": "SELECT share_token FROM lists WHERE id = $1",
      "parameters": [4],
      "result": {
        "count": 1,
        "rows": [
          {"tuple":["[hidden]"]}
        ]
      }
    },
```

The live app reads a real token. In playback, the app reads `[hidden]`, so `GET /lists/4/share` answers `{"url":"/shared/[hidden]"}`. That is why the test of the share link checks the start of the URL, and not the token. To hide a secret in the parameters of a query, use a query transformer: see [Test database code with recorded queries](https://hexdocs.pm/dream_postgres/2.0.0/guides/recorded-queries.html#step-6-keep-a-secret-out-of-the-file).

## Step 8: Read a query with no recording

In playback mode, a query with no recording never reaches a database. It fails with `dream_postgres_client.InterceptorFailed`. Through a route, the app answers `500` with `{"error":"Database error"}`: the controller keeps the cause in the server, as a production app must. To read the cause, test the model with the same connection. `recorder.error` reads the `RecorderError` back from the query error, and `recorder.describe_error` writes it as text:

### The text of a query error <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/recorded_queries/database_setup.gleam#L77-L84"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The text of a query error: for a query that the recorder failed, the
/// text of its `RecorderError`.
pub fn describe_query_error(error: QueryError) -> String {
  case recorder.error(error) {
    Ok(recorder_error) -> recorder.describe_error(recorder_error)
    Error(Nil) -> string.inspect(error)
  }
}
```

This test asks for list 7, which the record run did not read:

### A test with no recording <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/recorded_queries/miss_tests.gleam#L15-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() -> TestSuite {
  describe(
    "Lists",
    context.setup(
      fn() { start_app(recorder.Playback, "lists") },
      teardown: stop_app,
    ),
    [
      it("finds list 7", fn(app: App) {
        case list_model.get(app.services.database, 7) {
          Ok(_list) -> Ok(succeed())
          // The failure message is the text of the miss
          Error(QueryFailed(error:)) ->
            Ok(fail_with(describe_query_error(error)))
          Error(error) -> Ok(fail_with(string.inspect(error)))
        }
      }),
    ],
  )
}
```

The test fails, and the report shows the query and the nearest recordings:

### The report of a query with no recording <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/outputs/queries_miss.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Lists
  ✗ finds list 7
    fail_with
      Message: No recording matches SELECT name FROM lists WHERE id = $1 with [7]
               Nearest recording in test/recordings/queries/lists.json:
                 parameters:
                 - [2]
                 + [7]
               Next nearest recording in test/recordings/queries/lists.json:
                 parameters:
                 - [999]
                 + [7]
    Run it alone: gleam test -- --only "Lists/finds list 7"

Failures:
Lists
  ✗ finds list 7
    fail_with
      Message: No recording matches SELECT name FROM lists WHERE id = $1 with [7]
               Nearest recording in test/recordings/queries/lists.json:
                 parameters:
                 - [2]
                 + [7]
               Next nearest recording in test/recordings/queries/lists.json:
                 parameters:
                 - [999]
                 + [7]
    Run it alone: gleam test -- --only "Lists/finds list 7"

Summary: 1 run, 1 failed, 0 passed in 0ms
```

A nearest recording has the same SQL. The report shows its parameters on the `-` line, and the parameters of the query on the `+` line. When no recording has the SQL, the report says that no recording matches, with no nearest recording: the SQL changed since the record run.

Each failed test ends with a `Run it alone:` line. It is the command that runs only that test. In the example, this test runs only from the output checks, so the command finds it only in your own suite.

## Refresh the recording

Record again when you change a query, the schema, or a test:

1. Run `make record`.
2. Read `git diff test/recordings/queries`. A changed result is a change of your SQL or your schema. Make sure that it is the change you wanted.
3. Commit the file with the tests.

A record run writes the file of the suite again, from the queries of that run.

## Common pitfalls

**A query that changed since the record run.** *Symptom:* playback fails with `No recording matches`. *Fix:* the SQL or the parameters changed. Record again.

**A test that runs a query more often than in the record run.** *Symptom:* `recorder.describe_error` writes `Each recording of <sql> with <parameters> in <path> was played already`. *Fix:* each recording answers one query. Record again.

**Tests that depend on the order of the suite.** *Symptom:* a test passes alone and fails in the suite, or the other way. *Fix:* the tests share one database. Run the suite with `max_concurrency: 1`, and make each test create the rows that it reads, as the tests above do.

**A secret in the committed file.** *Symptom:* a token or a password shows in `lists.json`. *Fix:* add a result transformer or a query transformer that hides it, record again, and delete the old file from the history of your repository.

**Port 5432 in use.** *Symptom:* the record run cannot start PostgreSQL. *Fix:* the example maps PostgreSQL to port 5441. Use a free port, and the same port in the URL of the suite.

## Where to go next

- [Test a Dream app that calls other APIs](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-http.html): the same pattern for HTTP calls.
- [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html): matchers, fixtures and tests through the routes.
- [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html): models, operations and migrations.
- [Grow a JSON API](https://hexdocs.pm/dream/3.0.0/guides/api-patterns.html): services, errors and the other patterns of a JSON API.
- [Test database code with recorded queries](https://hexdocs.pm/dream_postgres/2.0.0/guides/recorded-queries.html): the full API of the recorder.
- [Mock at the system boundary](https://hexdocs.pm/dream_test/3.0.0/guides/mock-at-the-boundary.html): why a recording at the edge of your app beats a mock of your own models.
