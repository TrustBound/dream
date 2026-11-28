[README](https://hexdocs.pm/dream/3.0.0/) > Guides

# Guides

Each guide walks through one task, from an empty project to working, tested code. The outputs on the pages are the real answers of the example servers in the Dream repository.

Start with the first one, then pick the task you have:

- [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html) - From an empty folder to a tested route.
- [The BEAM for Dream developers](https://hexdocs.pm/dream/3.0.0/guides/beam.html) - How the runtime runs your app, and the common traps, each with its fix.
- [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html) - Path parameters, custom methods, context and middleware.
- [Read request data safely](https://hexdocs.pm/dream/3.0.0/guides/request-data.html) - Query strings, JSON that reports every error, and forms.
- [Send responses, cookies and files](https://hexdocs.pm/dream/3.0.0/guides/responses.html) - Redirects, downloads, cookies and static files.
- [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html) - PostgreSQL with `dream_sql_generator`, migrations and operations.
- [Grow a JSON API](https://hexdocs.pm/dream/3.0.0/guides/api-patterns.html) - Pagination, errors, versioning, filtering and CORS.
- [Load configuration and fail early](https://hexdocs.pm/dream/3.0.0/guides/configuration.html) - Typed settings read one time at startup with `dream_config`, a clear error, and secrets kept out of logs.
- [Call another API from a controller](https://hexdocs.pm/dream/3.0.0/guides/calling-other-apis.html) - `dream_http_client` in an app: timeouts, typed errors, 502 and 504 answers, JSON and a streamed reply.
- [Add a cache and a rate limit](https://hexdocs.pm/dream/3.0.0/guides/caching-and-rate-limiting.html) - Shared state in ETS with `dream_ets`: a cache with expiry, and a per-client limit that answers 429.
- [Run background work](https://hexdocs.pm/dream/3.0.0/guides/background-work.html) - Answer 202 at once, and run the job in a supervised worker with a bounded queue, timeouts and a clean stop.
- [Add search to a Dream app](https://hexdocs.pm/dream/3.0.0/guides/search.html) - An OpenSearch index beside the system of record, and the answers when search is down.
- [Render HTML and other formats](https://hexdocs.pm/dream/3.0.0/guides/templates.html) - Matcha templates, and one route in many formats.
- [Stream responses and uploads](https://hexdocs.pm/dream/3.0.0/guides/streaming.html) - Streamed downloads and uploads, and a broken upload.
- [Push live updates with server-sent events](https://hexdocs.pm/dream/3.0.0/guides/sse.html) - Typed SSE actors and a broadcaster.
- [Build a chat with WebSockets](https://hexdocs.pm/dream/3.0.0/guides/websockets.html) - Typed WebSocket actors and a chat room.
- [Serve HTTPS and HTTP/2](https://hexdocs.pm/dream/3.0.0/guides/http2.html) - TLS, ALPN and prior knowledge.
- [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html) - Dream Test for controllers, middleware, routes and servers.
- [Test a Dream app that calls other APIs](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-http.html) - Recorded HTTP calls, with the base request in services.
- [Test a Dream app's database code with recorded queries](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-queries.html) - Recorded PostgreSQL queries, with the connection in services.
- [Test a Dream app against a fake API](https://hexdocs.pm/dream/3.0.0/guides/testing-with-a-fake-api.html) - A fake service from `dream_mock_server`: error statuses, timeouts, streams and a contract test.
- [Deploy with Docker](https://hexdocs.pm/dream/3.0.0/guides/deployment.html) - The image, Compose, migrations and health checks.
- [Start, stop and troubleshoot the server](https://hexdocs.pm/dream/3.0.0/guides/operating.html) - Start errors, body limits and stopping.
- [Instructions for coding agents](https://github.com/TrustBound/dream/blob/3.0.0/docs/agents/AGENTS.md) - A template `AGENTS.md` that keeps the coding agents of your Dream app on Dream's patterns. Copy it to the root of your project and fill in the marked sections.

Upgrading from Dream 2? [Upgrade from Dream 2 to 3](https://hexdocs.pm/dream/3.0.0/guides/upgrading-to-3.html) gives every change, with the Dream 2 code next to the Dream 3 code.

For the API of each module, see [HexDocs](https://hexdocs.pm/dream/3.0.0/). For every streaming type and function, see the [streaming API reference](https://github.com/TrustBound/dream/blob/3.0.0/docs/reference/streaming-api.md). For how Dream is built, see [Concepts](https://github.com/TrustBound/dream/blob/3.0.0/docs/concepts.md).
