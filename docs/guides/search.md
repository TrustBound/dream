[README](https://hexdocs.pm/dream/3.0.0/) > [Guides](https://hexdocs.pm/dream/3.0.0/guides/index.html) > Add search to a Dream app

# Add search to a Dream app

Your app keeps records, and now its users want to find them by the words inside them. A `LIKE '%garden%'` query works for a hundred rows. But it does not rank the results by how well they match, and it reads every row each time. A search engine such as [OpenSearch](https://opensearch.org/) does these things well. But it brings a second store into the app, and a second store can be down, slow, or out of date.

This guide adds OpenSearch to a small Dream app with [`dream_opensearch`](https://hexdocs.pm/dream_opensearch/4.0.0/). The important part is not the search request. The important part is the place of the index in the app: the index is a copy of the records, and the app must work when the copy fails.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Step 1: Keep the client in services](#step-1-keep-the-client-in-services)
- [Step 2: Create the index at start](#step-2-create-the-index-at-start)
- [Step 3: Index a note when it changes](#step-3-index-a-note-when-it-changes)
- [Step 4: Add the search route](#step-4-add-the-search-route)
- [Step 5: Answer when search is down](#step-5-answer-when-search-is-down)
- [Step 6: Record the OpenSearch calls one time](#step-6-record-the-opensearch-calls-one-time)
- [Step 7: Test search that is down](#step-7-test-search-that-is-down)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

A notes app with these routes:

| Route | What it does |
|:---|:---|
| `POST /notes` | Keeps a note, then puts it in the index |
| `PUT /notes/:id` | Changes a note, then puts it in the index again |
| `DELETE /notes/:id` | Removes a note, then removes it from the index |
| `GET /search?q=garden&page=1&size=10` | Searches the titles and the bodies of the notes |

The notes live in a store, which is the system of record. To keep the example small, the store is a `gleam_otp` actor that holds the notes in memory. A real app uses its database, as in [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html). The rest of this guide does not change when the store is a database.

The tests run against recordings of a real OpenSearch, so `make test` needs no Docker and no network. All the code is in [`examples/search`](https://github.com/TrustBound/dream/tree/3.0.0/examples/search) of the Dream repository.

## Before you start

You need a Dream app with services. If you do not have one, start with [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html). The tests use recordings. [Test a Dream app that calls other APIs](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-http.html) explains them in full, and this guide uses the same pattern.

The app needs `dream_opensearch`, and `dream_http_client` for the base request of the client:

### The dependencies <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/gleam.toml#L8-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
dream_opensearch = ">= 4.0.0 and < 5.0.0"
dream_http_client = ">= 6.0.0 and < 7.0.0"
```

## Step 1: Keep the client in services

`dream_opensearch` gives two ways to make a client. `client.new("http://localhost:9200")` takes a URL. `client.from_request(base)` takes a `dream_http_client` request, and every request of the client starts from it. We use `from_request`, for two reasons:

1. The base request can set a timeout. The default timeout of the HTTP client is 30 seconds. A user who waits 30 seconds for a search box does not come back, so the app gives OpenSearch 2 seconds.
2. A test can give the app another base request: one with a recorder, or one that points at a port where nothing listens. The app code does not change.

The client goes in the services, next to the store and the name of the index:

### The services of the notes app <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/src/notes/services.gleam#L11-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Services {
  Services(notes: Store, opensearch: Client, index: String)
}

/// The OpenSearch client of the running app. A search waits 2 seconds at
/// most: after that, the app answers 503 and does not keep the client
/// waiting for the 30 seconds of the default timeout.
pub fn opensearch_client() -> Client {
  http_client.new()
  |> http_client.scheme(http.Http)
  |> http_client.host("localhost")
  |> http_client.port(9200)
  |> http_client.timeout(2000)
  |> client.from_request
}
```

The index name is in the services too. Each test suite then uses its own index, and two suites never see the documents of the other.

## Step 2: Create the index at start

OpenSearch can create an index by itself when the first document arrives. Do not let it. It then guesses the type of each field from the first document, and a wrong guess is hard to change later. So the app creates the index with a mapping when it starts.

`ensure_index` asks for the index with `HEAD /<index>`. The answer is the typed error `Rejected(status: 404, ..)` when the index does not exist. Then the function creates it. Each other error goes back to the caller:

### Create the index when it does not exist <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/src/notes/search_index.gleam#L32-L74"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Creates the index with its mapping when it does not exist. The app
/// calls it one time, at start.
pub fn ensure_index(
  opensearch: Client,
  index: String,
) -> Result(Nil, OpenSearchError) {
  case client.send_request(opensearch, http.Head, "/" <> index, "") {
    Ok(_body) -> Ok(Nil)
    Error(Rejected(status: 404, ..)) ->
      document.create_index(opensearch, index, mapping())
      |> result.replace(Nil)
    Error(error) -> Error(error)
  }
}

/// One shard keeps the scores the same from run to run in a small index.
/// No replicas, because the development cluster has one node: a cluster
/// with more nodes sets replicas.
fn mapping() -> String {
  json.object([
    #(
      "settings",
      json.object([
        #("number_of_shards", json.int(1)),
        #("number_of_replicas", json.int(0)),
      ]),
    ),
    #(
      "mappings",
      json.object([
        #(
          "properties",
          json.object([
            #("id", json.object([#("type", json.string("integer"))])),
            #("title", json.object([#("type", json.string("text"))])),
            #("body", json.object([#("type", json.string("text"))])),
          ]),
        ),
      ]),
    ),
  ])
  |> json.to_string
}
```

A match on the status in `Rejected` is all we need here. We do not read the text of the error body.

`main` starts the store, makes sure that the index exists, and only then starts the server. `client.describe_error` turns the error into one line for the log:

### Start the services and the index <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/src/main.gleam#L25-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Starts the store, and creates the index when it does not exist. The app
/// does not start without its index.
fn start_services() -> Result(Services, String) {
  let opensearch = services.opensearch_client()
  use started <- result.try(services.start_services(opensearch, "notes"))
  search_index.ensure_index(started.opensearch, started.index)
  |> result.replace(started)
  |> result.map_error(client.describe_error)
}
```

This app does not start without its index. That is a choice. An app that must start when OpenSearch is down can log the error and start, and a reindex task creates the index later.

## Step 3: Index a note when it changes

Now the most important decision of the guide. A user creates a note while OpenSearch is down. What does the app answer?

The store is the system of record. The note is safe in the store, so the write is a success. The index is a copy, and the copy missed one change. So the app answers `201` with the note, and adds `"indexed": false`. A client can show "saved, search updates soon". An answer of `503` would tell the user that the note is lost, and that is not true.

Each write goes to the store first, then to the index:

### Keep the note, then index it <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/src/notes/notes_controller.gleam#L64-L113"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn create_note(services: Services, draft: Draft) -> Response {
  case store.create(services.notes, draft) {
    Ok(note) ->
      json_response(
        status.created,
        views.written_note_json(note, index_note(services, note)),
      )
    Error(error) -> store_failure(error)
  }
}

fn update_note(services: Services, id: Int, draft: Draft) -> Response {
  case store.update(services.notes, id, draft) {
    Ok(note) ->
      json_response(
        status.ok,
        views.written_note_json(note, index_note(services, note)),
      )
    Error(error) -> store_failure(error)
  }
}

fn delete_note(services: Services, id: Int) -> Response {
  case store.delete(services.notes, id) {
    Ok(note) ->
      search_index.remove_note(services.opensearch, services.index, note.id)
      |> is_indexed
      |> views.deleted_note_json(note, _)
      |> json_response(status.ok, _)
    Error(error) -> store_failure(error)
  }
}

/// `True` when the index has the note. The store has it either way.
fn index_note(services: Services, note: Note) -> Bool {
  search_index.index_note(services.opensearch, services.index, note)
  |> is_indexed
}

fn is_indexed(written: Result(Nil, OpenSearchError)) -> Bool {
  case written {
    Ok(Nil) -> True
    Error(error) -> {
      io.println_error(
        "The index missed a change, reindex: " <> client.describe_error(error),
      )
      False
    }
  }
}
```

`is_indexed` turns the result of the index write into the `indexed` flag, and logs the error for the operator. The answer of the controller does not change with the kind of error. For a write, the only question is: does the index have the change or not?

A delete removes the note from the index too. A note that was created while search was down is not in the index, and OpenSearch answers `404` for its delete. That is not a failure: the note is gone from the index, which is what we want:

### Remove a note from the index <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/src/notes/search_index.gleam#L86-L98"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Removes the note with `id` from the index. A note that is not in the
/// index is not an error: it was written while search was down.
pub fn remove_note(
  opensearch: Client,
  index: String,
  id: Int,
) -> Result(Nil, OpenSearchError) {
  case document.delete(opensearch, index, int.to_string(id)) {
    Ok(_body) -> Ok(Nil)
    Error(Rejected(status: 404, ..)) -> Ok(Nil)
    Error(error) -> Error(error)
  }
}
```

A missed change stays missed until something writes it again. The fix is a reindex task: read every note from the store, and send them to OpenSearch with `document.bulk`. Run it after an outage, and after a change to the mapping. [Loading documents in bulk](https://hexdocs.pm/dream_opensearch/4.0.0/guides/bulk-loading.html) shows the bulk format, and [Run background work](https://hexdocs.pm/dream/3.0.0/guides/background-work.html) shows how to run a long task in a Dream app.

## Step 4: Add the search route

The search route reads three query parameters: `q`, `page` and `size`. The app checks them before it calls OpenSearch:

### Read the search parameters <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/src/notes/search_controller.gleam#L15-L57"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// OpenSearch gives no hit past the first 10000 (the index setting
/// `max_result_window`), and answers 400 to a page past it
const last_hit = 10_000

/// Searches the titles and the bodies of the notes. `q` is required.
/// `page` starts at 1, and `size` is from 1 to 50, 10 when not given.
pub fn search(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case read_search(request.query) {
    Ok(#(text, paging)) -> search_notes(services, text, paging)
    Error(message) ->
      json_response(status.bad_request, views.error_json(message))
  }
}

fn search_notes(services: Services, text: String, paging: Paging) -> Response {
  case
    search_index.search_notes(services.opensearch, services.index, text, paging)
  {
    Ok(page) -> json_response(status.ok, views.search_page_json(page))
    Error(SearchFailed(error:)) -> search_failure.to_response(error)
    Error(UnexpectedAnswer(reason:)) ->
      search_failure.unexpected_answer_response(reason)
  }
}

fn read_search(query: String) -> Result(#(String, Paging), String) {
  use text <- result.try(read_text(query))
  use page <- result.try(read_number(
    query,
    "page",
    default: 1,
    highest: last_hit,
  ))
  use size <- result.try(read_number(query, "size", default: 10, highest: 50))
  case page * size <= last_hit {
    True -> Ok(#(text, Paging(page:, size:)))
    False -> Error("page times size must be 10000 or less")
  }
}
```

The limit on `page * size` matters. OpenSearch gives no hit after the first 10000 (the index setting `max_result_window`). A request past it gets a `400` from OpenSearch, which the app would show as a `502`. The client sent the bad value, so the app answers `400` itself, with a message that the client can read.

The query matches `q` in the title and in the body, and a title match counts two times. The sort is the score first, then the ID. Two notes with the same score then come in the same order each time, and page 2 never shows a note of page 1 again:

### The search query <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/src/notes/search_index.gleam#L100-L143"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The notes whose title or body match `text`, best match first
pub fn search_notes(
  opensearch: Client,
  index: String,
  text: String,
  paging: Paging,
) -> Result(SearchPage, SearchError) {
  use answer <- result.try(
    document.search(opensearch, index, search_query(text, paging))
    |> result.map_error(SearchFailed),
  )
  json.parse(answer, hits_decoder())
  |> result.map(fn(hits) { SearchPage(total: hits.0, paging:, notes: hits.1) })
  |> result.map_error(fn(error) { UnexpectedAnswer(string.inspect(error)) })
}

/// A title match counts twice as much as a body match. The ID breaks a
/// tie, so a page has the same notes each time.
fn search_query(text: String, paging: Paging) -> String {
  json.object([
    #("from", json.int({ paging.page - 1 } * paging.size)),
    #("size", json.int(paging.size)),
    #(
      "query",
      json.object([
        #(
          "multi_match",
          json.object([
            #("query", json.string(text)),
            #("fields", json.array(["title^2", "body"], json.string)),
          ]),
        ),
      ]),
    ),
    #(
      "sort",
      json.preprocessed_array([
        json.string("_score"),
        json.object([#("id", json.string("asc"))]),
      ]),
    ),
  ])
  |> json.to_string
}
```

`document.search` gives the body of the answer as text. The app decodes the total and the `_source` of each hit into a `SearchPage`, a type of the app. A body that does not decode is an `UnexpectedAnswer`, not a crash. The view turns the page into JSON, with no field of OpenSearch in it:

### The JSON of a search page <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/src/notes/views.gleam#L25-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// One page of search hits
pub fn search_page_json(page: SearchPage) -> String {
  json.object([
    #("total", json.int(page.total)),
    #("page", json.int(page.paging.page)),
    #("size", json.int(page.paging.size)),
    #("notes", json.array(page.notes, note_json)),
  ])
  |> json.to_string
}
```

The client sees the JSON of the app, not of OpenSearch. Thus the app can change its search engine or its mapping, and its clients do not see a change.

## Step 5: Answer when search is down

A search with no OpenSearch has no answer, so this time the request fails. The question is which status to send. `dream_opensearch` gives each failure as a variant of `OpenSearchError`, and the app matches them:

### The status for each OpenSearch error <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/src/notes/search_failure.gleam#L12-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
const bad_gateway = 502

/// The status for a failed request to OpenSearch:
///
/// - 503 when OpenSearch did not answer. The client can try again later.
/// - 502 when OpenSearch answered with an error or with a body we cannot
///   read, or a test has no recording for the request.
/// - 500 when the app has a wrong OpenSearch URL.
pub fn status(error: OpenSearchError) -> Int {
  case error {
    Unavailable(..) | TimedOut(..) -> status.service_unavailable
    Rejected(..) | InvalidResponseBody(..) | NoRecording(..) -> bad_gateway
    InvalidUrl(..) -> status.internal_server_error
  }
}

/// Logs the error for the operator, and answers the client with `status`.
/// The body does not show the error: it can hold the answer of OpenSearch.
pub fn to_response(error: OpenSearchError) -> Response {
  io.println_error(client.describe_error(error))
  let code = status(error)
  json_response(code, views.error_json(message(code)))
}
```

- `Unavailable` (no connection) and `TimedOut` (no answer in time) mean that OpenSearch did not answer. `503 Service Unavailable` tells the client to try again later.
- `Rejected` means that OpenSearch answered with an error status. The app sent a request that OpenSearch did not accept, so `502 Bad Gateway` is correct. Try again later does not help.
- `InvalidUrl` comes only from `client.new`, so it means a wrong configuration.

The match names each variant, with no catch-all. If a new version of `dream_opensearch` adds a variant, the compiler shows this function, and we decide its status. The app never reads the text of an error to decide. The text is for the log only, and `to_response` keeps it out of the body, because a `Rejected` body holds the answer of OpenSearch.

## Step 6: Record the OpenSearch calls one time

A test against a real OpenSearch needs Docker and about a minute to start. A test against a hand-written fake tests our idea of OpenSearch, not OpenSearch. Recordings give both: real answers, and no OpenSearch in CI.

The test setup puts a recorder on the base request, and gives the app services with it, as Step 1 planned:

### Start the recorder and the services <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/test/search_setup.gleam#L46-L76"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Starts a recorder in `mode` that keeps its files in
/// `test/recordings/<index>`, and the services of the app with it. Then it
/// creates the index, as `main` does.
pub fn start_app(mode: recorder.Mode, index: String) -> Result(App, String) {
  use recorder <- result.try(
    recorder.new()
    |> recorder.directory("test/recordings/" <> index)
    |> recorder.mode(mode)
    |> recorder.key(matching.request_key(
      method: True,
      url: True,
      headers: False,
      body: True,
    ))
    |> recorder.response_transformer(drop_timings)
    |> recorder.start(),
  )
  let opensearch =
    http_client.new()
    |> http_client.scheme(http.Http)
    |> http_client.host("localhost")
    |> http_client.port(opensearch_port)
    |> http_client.recorder(recorder)
    |> client.from_request
  use services <- result.try(services.start_services(opensearch, index))
  use Nil <- result.try(
    search_index.ensure_index(services.opensearch, services.index)
    |> result.map_error(client.describe_error),
  )
  Ok(App(services:, recorder: Some(recorder)))
}
```

Two settings are different from the recorder of [Test a Dream app that calls other APIs](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-http.html):

- The key has the body. Each search is `POST /<index>/_search`, and only the body has the search text and the page. Without the body in the key, all the searches have one key, and one recording.
- The response transformer removes the times. OpenSearch puts the time of the request in `took`. The transformer sets it to 0, and removes the `date` and `content-length` headers:

### Remove the times from the recordings <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/test/search_setup.gleam#L123-L149"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Runs in record mode only, before the recorder writes the response.
/// `took` is the time of the request in OpenSearch, and the `date` header
/// is the time of the answer. Both change on each run, so this sets `took`
/// to 0 and removes `date`. The body length changes with `took`, so it
/// removes `content-length` too. A new record run then gives the same
/// files.
fn drop_timings(
  _request: RecordedRequest,
  response: RecordedResponse,
) -> RecordedResponse {
  let keep = fn(header: #(String, String)) {
    header.0 != "date" && header.0 != "content-length"
  }
  case response {
    BlockingResponse(..) ->
      BlockingResponse(
        ..response,
        headers: list.filter(response.headers, keep),
        body: zero_took(response.body),
      )
    StreamingResponse(..) ->
      StreamingResponse(
        ..response,
        headers: list.filter(response.headers, keep),
      )
  }
}
```

Then a new record run of the same tests gives the same files, and `git diff` shows only real changes.

OpenSearch makes a new document searchable about one time each second. The setup of the search suite adds three notes through the routes, then calls `refresh`, which asks OpenSearch to make them searchable now:

### Make new notes searchable now <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/test/search_setup.gleam#L110-L121"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// OpenSearch makes a new document searchable about one time each second.
/// A test that searches right after a write asks for a refresh first.
pub fn refresh(app: App) -> Result(Nil, String) {
  client.send_request(
    app.services.opensearch,
    http.Post,
    "/" <> app.services.index <> "/_refresh",
    "",
  )
  |> result.replace(Nil)
  |> result.map_error(client.describe_error)
}
```

Only a test needs `refresh`. In the app, a note that shows in search one second after its write is correct.

`make record` starts a single OpenSearch node in Docker, with no security plugin, and removes it with its data at the end:

### The OpenSearch of a record run <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/docker-compose.yml#L5-L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```yaml
name: dream_search

services:
  opensearch:
    image: opensearchproject/opensearch:2.19.1
    environment:
      discovery.type: single-node
      # No TLS and no login, for a node that only the tests use
      DISABLE_SECURITY_PLUGIN: "true"
      DISABLE_INSTALL_DEMO_CONFIG: "true"
      OPENSEARCH_JAVA_OPTS: "-Xms512m -Xmx512m"
    ports:
      # Port 19200 on this machine, so the record run does not use an
      # OpenSearch that already listens on 9200.
      - "19200:9200"
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:9200/_cluster/health"]
      interval: 2s
      timeout: 5s
      retries: 60
```

### Record the tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/scripts/record.sh#L6-L15"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sh
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
```

The `curl` line turns off the disk check of OpenSearch. OpenSearch does not put a shard on a disk that is more than 90% full, and then the index of the tests never gets ready. The node holds only test data, so the check does not help. Do not turn it off on a real cluster.

Here is the recording of the second page of `garden`. The request body holds the page, and `took` is 0:

### The recording of page 2 <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/test/recordings/notes_search/POST_localhost__notes_search__search_b824ce81f9c83685.json#L1"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```json
{"version":"1.0","entries":[{"request":{"method":"POST","scheme":"http","host":"localhost","port":19200,"path":"/notes_search/_search","query":null,"headers":[["content-type","application/json"]],"body":"{\"from\":1,\"size\":1,\"query\":{\"multi_match\":{\"query\":\"garden\",\"fields\":[\"title^2\",\"body\"]}},\"sort\":[\"_score\",{\"id\":\"asc\"}]}"},"response":{"mode":"blocking","status":200,"headers":[["content-type","application/json; charset=UTF-8"]],"body":"{\"took\":0,\"timed_out\":false,\"_shards\":{\"total\":1,\"successful\":1,\"skipped\":0,\"failed\":0},\"hits\":{\"total\":{\"value\":2,\"relation\":\"eq\"},\"max_score\":null,\"hits\":[{\"_index\":\"notes_search\",\"_id\":\"2\",\"_score\":0.9400072,\"_source\":{\"id\":2,\"title\":\"Plan the garden\",\"body\":\"Beans go in the north bed this year\"},\"sort\":[0.9400072,2]}]}}"}}]}
```

The scores of the two notes are equal, and the `sort` value shows the ID that breaks the tie. Now `make test` plays the recordings back, with no Docker:

### The report of the search suite <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/test/outputs/search_playback.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Search notes
  ✓ finds the notes that match the search text
  ✓ gives the second page of the hits
  ✓ answers an empty page when no note matches
  ✓ answers 400 without a search text
  ✓ answers 400 for a page past hit 10000

Summary: 5 run, 0 failed, 5 passed in 0ms
```

## Step 7: Test search that is down

A recording cannot show a connection that fails, because a failed connection has no answer to record. But a closed port gives exactly that failure, with no network. The setup of this suite points the base request at port 19299, where nothing listens:

### Services with search down <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/test/search_setup.gleam#L78-L89"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The services of the app with OpenSearch down: the base request points
/// at a port where nothing listens.
pub fn start_app_without_search() -> Result(App, String) {
  let opensearch =
    http_client.new()
    |> http_client.scheme(http.Http)
    |> http_client.host("localhost")
    |> http_client.port(closed_port)
    |> client.from_request
  use services <- result.try(services.start_services(opensearch, "notes"))
  Ok(App(services:, recorder: None))
}
```

The tests check the two answers of Step 3 and Step 5. A search answers `503`, and the writes succeed with `"indexed": false`:

### The suite with search down <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/test/down_tests.gleam#L15-L60"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() -> TestSuite {
  describe(
    "Notes with search down",
    context.setup(start_app_without_search, teardown: stop_app),
    [
      it("answers 503 to a search", fn(app: App) {
        let response = send(app.services, Get, "/search", "q=garden", "")

        answer(response)
        |> should
        |> be_equal(#(
          503,
          "{\"error\":\"Search is unavailable. Try again later.\"}",
        ))
        |> or_fail_with("a search should answer 503 while OpenSearch is down")
      }),
      it("keeps a new note and answers that the index missed it", fn(app: App) {
        let response =
          send(
            app.services,
            Post,
            "/notes",
            "",
            "{\"title\":\"Buy seeds\",\"body\":\"Carrots and beans\"}",
          )

        answer(response)
        |> should
        |> be_equal(#(
          201,
          "{\"id\":1,\"title\":\"Buy seeds\",\"body\":\"Carrots and beans\",\"indexed\":false}",
        ))
        |> or_fail_with("POST /notes should keep the note while search is down")
      }),
      it("deletes a note and answers that the index missed it", fn(app: App) {
        use Nil <- result.try(add_note(app, "Sell the bike", "Ask 80 euros"))

        let response = send(app.services, Delete, "/notes/2", "", "")

        answer(response)
        |> should
        |> be_equal(#(200, "{\"id\":2,\"indexed\":false}"))
        |> or_fail_with("DELETE /notes/2 should remove the note from the store")
      }),
    ],
  )
```

### The report of the suite with search down <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/search/test/outputs/search_down.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Notes with search down
  ✓ answers 503 to a search
  ✓ keeps a new note and answers that the index missed it
  ✓ deletes a note and answers that the index missed it

Summary: 3 run, 0 failed, 3 passed in 0ms
```

The `TimedOut` and `Rejected` statuses are tested on `search_failure.status` directly, with one test for each variant. That is faster and more exact than a slow server in a test.

## Common pitfalls

**A search that does not find a new note.** *Symptom:* a test creates a note, searches, and gets no hit. *Fix:* OpenSearch makes a document searchable about one time each second. Call `POST /<index>/_refresh` in the test before the search. Do not add a sleep.

**All the searches play back one answer.** *Symptom:* each search in playback gives the hits of another search. *Fix:* each search has the same method and URL. Put the body in the key with `matching.request_key(method: True, url: True, headers: False, body: True)`, and record again.

**A recording that changes on each record run.** *Symptom:* `git diff` shows a new `took` after each record run. *Fix:* set `took` to 0 with a response transformer, as `drop_timings` does.

**A page that changes from request to request.** *Symptom:* two notes change places on a page, or a note shows on two pages. *Fix:* sort by `_score`, then by a unique field such as the ID.

**A field with the wrong type.** *Symptom:* a search on a field finds nothing, or OpenSearch rejects a document. *Fix:* create the index with a mapping before the first document, as `ensure_index` does. A mapping cannot change a field type later: create a new index and reindex.

**A write that fails when search is down.** *Symptom:* users lose work during a search outage. *Fix:* write the store first, and treat a failed index write as a missed change, not as a failed request.

## Where to go next

- [`dream_opensearch` 4.0.0](https://hexdocs.pm/dream_opensearch/4.0.0/): [Searching an index](https://hexdocs.pm/dream_opensearch/4.0.0/guides/searching.html), [Managing indexes](https://hexdocs.pm/dream_opensearch/4.0.0/guides/managing-indexes.html) and [Handling errors](https://hexdocs.pm/dream_opensearch/4.0.0/guides/handling-errors.html).
- [Test a Dream app that calls other APIs](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-http.html): the recorder in full.
- [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html): a real system of record in place of the actor.
- [Run background work](https://hexdocs.pm/dream/3.0.0/guides/background-work.html): a home for the reindex task.
