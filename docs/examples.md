# Examples

Complete, working applications. Read the code—it's commented to explain the patterns.

If you are not sure where to start, follow the examples in the **Learning Order** section from top to bottom, then jump into the specialized examples that match what you are building.

---

## Learning Order

### 1. [simplest/](../examples/simplest/)
**One file. One route.** (Best first "hello Dream" example.)

The absolute minimum Dream app. Everything inline, no organization. Start here.

**Demonstrates:**
- Basic controller
- Router setup
- Server configuration

**Run:** `cd examples/simplest && make run`

---

### 2. [simple/](../examples/simple/)
**Basic routing and path parameters.** (Best first routing + path parameters example.)

Multiple routes, path parameters, HTTP client usage.

**Demonstrates:**
- Path parameters (`:id`)
- Multiple controllers
- HTTP client (non-streaming)

**Run:** `cd examples/simple && make run`
**Test:** Integration tests

---

### 3. [database/](../examples/database/)
**Full CRUD API with PostgreSQL.** (Best first database-backed REST API example.)

Complete REST API with type-safe SQL, migrations, and validation.

**Demonstrates:**
- Services pattern (database connection)
- Models (data access)
- Views (JSON formatting)
- `dream_model` (typed models from SQL files)
- Cigogne (migrations)
- Makefile automation

**Run:** `cd examples/database && make db-up && make migrate && make run`
**Test:** Integration tests with database isolation

---

### 4. [custom_context/](../examples/custom_context/)
**Authentication with middleware.** (Best first auth + custom context example.)

Custom context types and middleware for auth.

**Demonstrates:**
- Custom context (beyond AppContext)
- Middleware pattern
- Context enrichment
- Protecting routes

**Run:** `cd examples/custom_context && make run`
**Test:** Integration tests covering authentication

---

### 5. [tasks/](../examples/tasks/)
**Full-featured task app with HTMX.** (Best first templates + HTMX example.)

Complete task management application with HTMX, semantic classless HTML, and composable templates.

**Demonstrates:**
- HTMX patterns (create, update, delete, toggle)
- Semantic HTML only (no divs/spans)
- Classless CSS (Pico CSS)
- Composable matcha templates (elements → components → views)
- No raw HTML in Gleam code

**Run:** `cd examples/tasks && make db-up && make migrate && make models && make matcha && make run`
**Test:** Comprehensive Cucumber integration tests

---

## Specialized Examples

### [multi_format/](../examples/multi_format/)
**JSON, HTML, CSV, HTMX responses.** (Best first multi-format responses example.)

Same data in multiple formats with content negotiation.

**Demonstrates:**
- Matcha templates (HTML)
- Format detection (URL extension, Accept header)
- CSV streaming
- HTMX partials

**Run:** `cd examples/multi_format && make db-up && make migrate && make run`
**Test:** Integration tests covering all formats

---

### [streaming/](../examples/streaming/)
**HTTP client with streaming.** (Best first streaming HTTP client example.)

Both streaming and non-streaming HTTP requests to external APIs.

**Demonstrates:**
- HTTP client streaming
- Chunk processing
- Memory-efficient requests
- External API calls

**Run:** `cd examples/streaming && make run`
**Test:** Integration tests

---

### [streaming_capabilities/](../examples/streaming_capabilities/)
**🔥 Advanced streaming patterns.** (Read `streaming/` first; this is the advanced streaming showcase.)

Complete streaming showcase: ingress, egress, bi-directional, middleware, proxying.

**Demonstrates:**
- **Ingress streaming**: Upload large files without buffering
- **Egress streaming**: Download data generated on-the-fly
- **Bi-directional streaming**: Transform data both ways
- **Streaming middleware**: Uppercase input, transform output
- **Proxy streaming**: Stream from external sources

**Run:** `cd examples/streaming_capabilities && make run`
**Test:** Integration tests covering all streaming patterns

---

### [websocket_chat/](../examples/websocket_chat/)
**Real-time chat with WebSockets.** (Best first WebSocket example.)

A multi-user chat application that uses WebSockets and a broadcaster service.

**Demonstrates:**
- HTTP → WebSocket upgrade from a Dream controller
- Typed WebSocket message loop (`on_init`, `on_message`, `on_close`)
- Pub/sub broadcaster service for fan-out messaging
- Frontend integration with JavaScript WebSocket client
- End-to-end integration tests using Gherkin/Cucumber

**Run:** `cd examples/websocket_chat && make run`
**Test:** `cd examples/websocket_chat && make test-integration`

---

### [sse/](../examples/sse/)
**Live updates with server-sent events.** (Best first server-sent events example.)

Two event streams, one with plain events and one with named events and IDs, from typed SSE actors.

**Demonstrates:**
- HTTP → SSE upgrade from a Dream controller with `upgrade_to_sse`
- Typed SSE actor loop (`on_init`, `on_message`)
- Named events with IDs
- Middleware headers, such as CORS, on the SSE response
- End-to-end integration tests using Gherkin/Cucumber

**Run:** `cd examples/sse && make run`
**Test:** `cd examples/sse && make test-integration`
**Guide:** [Push live updates with server-sent events](guides/sse.md)

---

### [rate_limiter/](../examples/rate_limiter/)
**Global rate limiting with shared state.** (Best first ETS + rate limiting example.)

Rate limiting across all requests using shared ETS-backed state.

**Demonstrates:**
- ETS tables
- Rate limiting middleware

**Run:** `cd examples/rate_limiter && make run`
**Test:** Unit tests with a fixed clock (`make test`), and integration tests with unique IP isolation
**Guide:** [Add a cache and a rate limit](guides/caching-and-rate-limiting.md)

---

### [static/](../examples/static/)
**Serving static files.** (Best first static file serving example.)

File serving with security, directory listing, MIME types.

**Demonstrates:**
- Static file controller
- Security (path traversal prevention)
- Custom MIME types
- Directory listings

**Run:** `cd examples/static && make run`
**Test:** Integration tests with security validation

---

### [deployment/](../examples/deployment/)
**A Dream app in a container.** (Best first Docker deployment example.)

An app that reads its settings from the environment, answers `/health` with the state of its database, and listens on all interfaces. Its `Dockerfile` and `docker-compose.yml` run it with PostgreSQL and its migrations.

**Demonstrates:**
- Two-stage Docker image: the Gleam image compiles, an Erlang image runs
- Settings from the environment (`DATABASE_URL`, `PORT`)
- A health check that the platform uses to restart the app
- Migrations that run before the app starts
- A clean stop on `SIGTERM`

**Run and test:** `make test-docker` from the repository root (Docker with Compose v2). It builds the image, starts it with Compose, checks `/health`, and checks that the app stops on `SIGTERM`. The example depends on the Dream of the repository, so the script copies both into one folder first. In your own app, `docker compose up -d --wait app` starts it.
**Guide:** [Deploy with Docker](guides/deployment.md)

---

### [configuration/](../examples/configuration/)
**Typed settings, read one time at startup.**

A links app that reads `PORT`, `SITE_URL` and `SIGNING_KEY` into one `Configuration` value, stops with exit status 1 on a missing or bad setting, keeps the key out of logs, and gives the values to the controller through services.

**Test:** `make test` (needs no settings)
**Guide:** [Load configuration and fail early](guides/configuration.md)

---

### [outbound_http/](../examples/outbound_http/)
**Calls to another API from a controller.**

A Dream app that calls a forecast service with `dream_http_client`: the base request in services, timeouts, typed errors, 502 and 504 answers, JSON, and a streamed reply.

**Test:** `make test`, against a fake service on localhost
**Guide:** [Call another API from a controller](guides/calling-other-apis.md)

---

### [cache/](../examples/cache/)
**A read-through cache with expiry.**

A products app that keeps slow lookups in an ETS table with `dream_ets`, removes an entry after a write, and reads the time from a clock in services.

**Test:** `make test`, with a fixed clock and no sleep
**Guide:** [Add a cache and a rate limit](guides/caching-and-rate-limiting.md)

---

### [fake_api/](../examples/fake_api/)
**Tests of a Dream app against a fake news service.**

Two mock servers from `dream_mock_server` in the suite setup, with tests for a 503, a body that is not JSON, a timeout, a closed port, a relayed stream and a dropped stream, plus a contract test that can run against the real service.

**Test:** `make test`, about 10 seconds, no network
**Guide:** [Test a Dream app against a fake API](guides/testing-with-a-fake-api.md)

---

### [background_work/](../examples/background_work/)
**A supervised job worker.**

A controller answers 202 with a job id and a status route. The worker has a bounded queue (503 when full) and job timeouts. Each job is linked to the worker, which traps exits: a crashed job fails alone, and a crash of the worker ends its running job and marks the queued jobs lost. A cleanup runs on a timer, and the worker stops cleanly.

**Test:** `make test`, with no sleep
**Guide:** [Run background work](guides/background-work.md)

---

### [search/](../examples/search/)
**A Dream app with an OpenSearch index of its records.**

A notes app that keeps its notes in a store, the system of record, and a copy of them in OpenSearch with `dream_opensearch` 4.0.0. The client is built from a base request and held in services.

**Demonstrates:**
- An index created with a mapping at start
- A note indexed when it is created or changed, and removed from the index when it is deleted
- A search route with a query string, paging and a typed result that a view turns into JSON
- 503 or 502 from a match on the typed OpenSearch errors, and writes that succeed with `"indexed": false` while search is down
- Recorded OpenSearch calls with the times removed, and a closed port for search that is down

**Test:** `make test` plays back, with no network and no OpenSearch. `make record` records again, with OpenSearch in Docker on port 19200.
**Guide:** [Add search to a Dream app](guides/search.md)

---

### [recorded_tests/](../examples/recorded_tests/)
**Tests that play back recorded HTTP calls and queries.** (Best first example of tests with no network and no database.)

Two small apps and their tests. The parcels app calls a carrier API with the base request in its services. The lists app keeps a PostgreSQL connection in its services. The tests give each app services with a recorder, and play back the committed recordings.

**Demonstrates:**
- A base request and a connection in services, so that a test can change them
- A recorder in the setup of a Dream Test suite, with the mode from `RECORDER_MODE`
- A token header and a secret column kept out of the recordings
- A transaction that rolls back, played back with no database
- The report of a request and of a query with no recording

**Test:** `make test` plays back, with no network and no database. `make record` records again, with a fake carrier API and PostgreSQL in Docker.
**Guides:** [Test a Dream app that calls other APIs](guides/testing-with-recorded-http.md) and [Test a Dream app's database code with recorded queries](guides/testing-with-recorded-queries.md)

---

## How to Use Examples

1. **Read the README** - Explains what it demonstrates
2. **Read the code** - Commented to explain patterns
3. **Run it** - See it working
4. **Run the tests** - See comprehensive test coverage
5. **Modify it** - Break things and learn

Each example is self-contained with its own database (if needed), dependencies, and setup.

## Testing Examples

All examples include comprehensive integration tests using Cucumber (BDD framework):

Run all example integration tests from the repo root, as the integration job of CI does in `scripts/ci-integration.sh`:

### Run all integration tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/scripts/ci-integration.sh#L11"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
make test-integration
```

Run the tests of one example:

### Run the tests of one example <a href="https://github.com/TrustBound/dream/blob/3.0.0/scripts/test-integration.sh#L13"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
(cd examples/database && make test-integration)
```

**Comprehensive integration tests** covering:
- Error handling (400, 404, 500)
- Content validation (JSON, CSV, HTML)
- Security (auth, path traversal, rate limiting)
- Streaming (request/response, chunked transfer)
- Database (CRUD, persistence, isolation)

See [Testing Guide](contributing/testing.md) for details.

---

## Next Steps

- [Concepts](concepts.md) - Understand Dream's core ideas
- [Guides](guides/) - Build something specific  
- [Testing Guide](contributing/testing.md) - Learn about the test suite
- [Reference](reference/) - Deep dives on architecture




