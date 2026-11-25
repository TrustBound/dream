# Instructions for coding agents in this Dream app

This is a template. Copy it to the root of your Dream project as `AGENTS.md`, then edit it. Fill each `<!-- Your project: ... -->` section, and remove the rules that do not fit your project. Coding agents read this file before they change your code.

The rules here come from the Dream 3.0.0 guides. Each rule links to its guide. When you upgrade Dream, change `3.0.0` in each link to the new version.

<!-- Your project: one or two sentences. What the app does, who uses it, and what it must never do. -->

## Do not guess

1. Before you change an area, read the Dream guide for that area (see [Where to look first](#where-to-look-first)) and the docs of this project.
2. Do not invent an API. Before you call a function, find it in the HexDocs of the package, at the version that `manifest.toml` locks. For Dream: `https://hexdocs.pm/dream/3.0.0/`. For Dream Test: `https://hexdocs.pm/dream_test/3.0.0/`.
3. Do not invent a command or a test result. Run the command and read its full output.
4. If the fact that you need is not in your context, in the Dream docs, in the project docs or in the source, stop and ask. Do not fill the gap with a likely answer.
5. If the docs and the code do not agree, report it. Do not pick one in silence.

<!-- Your project: list your own docs here (architecture notes, decision records, API specs), with their paths. -->

## How a Dream app fits together

Dream is a library, not a framework. The app connects the pieces in its `main`, so each dependency is visible. Read [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html) for the full picture.

- **Router.** Each route names its method, path, controller and middleware. Read [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html).
- **Middleware.** Middleware is per route. There is no global middleware list. List it on each route, or make a helper function for a set that many routes use. Read [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html).
- **Scopes.** Group routes with `router.scope(path: "/members", with: require_member, routes: member_routes())`. `with` has the middleware shape, but its `next` can take another context type (for example `Context` to `MemberContext`). It runs before the route's own middleware. Use `path: ""` for a group with no prefix. Give each path parameter a name that is not used again in the prefix plus the route path. Read [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html).
- **Controllers.** A controller is a function that gets the request, the context and the services, and returns a response. Keep it thin: read the request, call a model or an operation, call a view, map errors to a response. Read [Read request data safely](https://hexdocs.pm/dream/3.0.0/guides/request-data.html) and [Send responses, cookies and files](https://hexdocs.pm/dream/3.0.0/guides/responses.html).
- **Context.** Context is the data of one request, such as the request ID and the user. Middleware adds to it. Read [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html).
- **Services.** Services are the dependencies of the whole app, such as the database pool and the config. The app makes them one time at start. Read [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html).
- **Models, views, operations.** A model reads and writes data and returns domain types in a `Result`. A view turns domain types into JSON, HTML or another format, with no side effects. An operation holds a workflow that uses more than one model or service. Read [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html) and [Render HTML and other formats](https://hexdocs.pm/dream/3.0.0/guides/templates.html).
- **JSON APIs.** Read [Grow a JSON API](https://hexdocs.pm/dream/3.0.0/guides/api-patterns.html).
- **Streams, SSE, WebSockets.** Read [Stream responses and uploads](https://hexdocs.pm/dream/3.0.0/guides/streaming.html), [Push live updates with server-sent events](https://hexdocs.pm/dream/3.0.0/guides/sse.html) and [Build a chat with WebSockets](https://hexdocs.pm/dream/3.0.0/guides/websockets.html).

<!-- Your project: your folder layout. For example: where the router, the controllers, the middleware, the models, the views and the operations live, and which module makes the services. -->

## Coding standards

These rules come from the Dream guides and from Dream's [design principles](https://github.com/TrustBound/dream/blob/3.0.0/docs/reference/design-principles.md) and [naming conventions](https://github.com/TrustBound/dream/blob/3.0.0/docs/reference/naming-conventions.md).

- **Explicit over implicit.** No global state and no magic configuration. Pass each dependency as a parameter or in `Services`.
- **No closures for dependencies.** A controller gets the database from `Services`, not from a function that holds it. For SSE and WebSocket handlers, put the dependencies in a `Dependencies` type.
- **Read parameters with the `require_*` functions.** They return an error that you can send back, so you do not need `let assert`.
- **No nested `case`.** Use a flat `use` chain, or put the inner `case` in a named helper function.
- **Errors are values.** Return `Result`. Never discard an error with `Error(_)`: bind it and handle it.
- **Map errors to responses in one place,** for example with `error.to_status_code` and `error.message` from `dream/http/error`.
- **Models know nothing about HTTP.** A model returns a `Result`, not a `Response`.
- **Names.** A function name is `{verb}_{noun}`. Do not repeat the module name in the function name. Use full words (`request`, not `req`). Domain abbreviations such as `id`, `http`, `json` and `url` are permitted.
- **Simple over clever.** Abstract when you have three examples, not one.
- **Format.** Run `gleam format`.

<!-- Your project: your own naming and style rules, for example the names of your modules, your error type, and your rules for SQL. -->

## Testing

Read [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html). For tests that use recorded traffic, read [Test a Dream app that calls other APIs](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-http.html) and [Test a Dream app's database code with recorded queries](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-queries.html).

- Use [Dream Test](https://hexdocs.pm/dream_test/3.0.0/).
- Test a controller or a middleware as a plain function, with a request that you build. It needs no server.
- Test a route, its middleware and its controller together with `dream.route_request(router, request, context, services)`.
- Write each test as Arrange, Act, Assert, with a blank line between the three parts.
- Put one assertion in each test. Do not throw away the result of a matcher with `let _ =`.
- Test the public functions. A private function that no public function reaches is dead code: delete it.
- A unit test has no database, no network and no files. It is fast and deterministic. Put a test that needs a real service in `test/integration/`, and make it clean up.
- Each test makes its own request and its own services. Do not share state between tests through a database row or a file.
- Stop every server that a test starts with `listen_with_handle`, also when an assertion fails. Do not call `listen` in a test: it never returns.
- Never sleep to wait for a result. Wait for a message, a monitor, or a call with a timeout. See [Sleep in a test](https://hexdocs.pm/dream/3.0.0/guides/beam.html#sleep-in-a-test) in the BEAM guide.

<!-- Your project: your coverage target, your fixtures, how to start the test database, and which tests need a real service. -->

## BEAM practices

Read [The BEAM for Dream developers](https://hexdocs.pm/dream/3.0.0/guides/beam.html). From the Dream guides:

- Each connection runs in its own process, and the requests on one keep-alive connection share it. A crash in one request does not stop the server. Do not keep request state in a shared place.
- Put shared state, such as a cache or a rate limit, in a supervised process or in ETS, and reference it from `Services`.
- Each SSE or WebSocket connection is one actor. Do not do slow work in `on_message`: give it to another process and send the result back as a custom message.
- Do not start the app with `gleam run` in production. It does not pass `SIGTERM` to the Erlang VM. Use the `entrypoint.sh` of `gleam export erlang-shipment`. Read [Deploy with Docker](https://hexdocs.pm/dream/3.0.0/guides/deployment.html) and [Start, stop and troubleshoot the server](https://hexdocs.pm/dream/3.0.0/guides/operating.html).
- Set `shutdown_timeout` shorter than the grace period of your platform.

## Commands

Run these before each commit:

- `gleam format --check`
- `gleam test`

<!-- Your project: your other commands, for example the build, the integration tests, the database migrations, and how to start the app on your machine. -->

## Commits and pull requests

<!-- Your project: your branch names, your commit format, and what a pull request must contain. -->

## Where to look first

| Task | Read first |
|:---|:---|
| Start a new app | [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html) |
| Add a route or a middleware | [Route requests and add middleware](https://hexdocs.pm/dream/3.0.0/guides/routing.html) |
| Read params, query, JSON or forms | [Read request data safely](https://hexdocs.pm/dream/3.0.0/guides/request-data.html) |
| Send a response, a cookie or a file | [Send responses, cookies and files](https://hexdocs.pm/dream/3.0.0/guides/responses.html) |
| Add a model, a view or an operation | [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html) |
| Shape a JSON API | [Grow a JSON API](https://hexdocs.pm/dream/3.0.0/guides/api-patterns.html) |
| Render HTML or many formats | [Render HTML and other formats](https://hexdocs.pm/dream/3.0.0/guides/templates.html) |
| Stream a response or an upload | [Stream responses and uploads](https://hexdocs.pm/dream/3.0.0/guides/streaming.html) |
| Push live updates | [Push live updates with server-sent events](https://hexdocs.pm/dream/3.0.0/guides/sse.html) |
| Add WebSockets | [Build a chat with WebSockets](https://hexdocs.pm/dream/3.0.0/guides/websockets.html) |
| Serve HTTPS or HTTP/2 | [Serve HTTPS and HTTP/2](https://hexdocs.pm/dream/3.0.0/guides/http2.html) |
| Write a test | [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html) |
| Test code that calls an HTTP service | [Test a Dream app that calls other APIs](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-http.html) |
| Test code that queries a database | [Test a Dream app's database code with recorded queries](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-queries.html) |
| Read settings and secrets | [Load configuration and fail early](https://hexdocs.pm/dream/3.0.0/guides/configuration.html) |
| Call another HTTP service | [Call another API from a controller](https://hexdocs.pm/dream/3.0.0/guides/calling-other-apis.html) |
| Cache data or limit requests | [Add a cache and a rate limit](https://hexdocs.pm/dream/3.0.0/guides/caching-and-rate-limiting.html) |
| Run work outside a request | [Run background work](https://hexdocs.pm/dream/3.0.0/guides/background-work.html) |
| Add search to records | [Add search to a Dream app](https://hexdocs.pm/dream/3.0.0/guides/search.html) |
| Test against a fake HTTP service | [Test a Dream app against a fake API](https://hexdocs.pm/dream/3.0.0/guides/testing-with-a-fake-api.html) |
| Start, stop or limit the server | [Start, stop and troubleshoot the server](https://hexdocs.pm/dream/3.0.0/guides/operating.html) |
| Deploy | [Deploy with Docker](https://hexdocs.pm/dream/3.0.0/guides/deployment.html) |
| Upgrade from Dream 2 | [Upgrade from Dream 2 to 3](https://hexdocs.pm/dream/3.0.0/guides/upgrading-to-3.html) |
| Run on the BEAM | [The BEAM for Dream developers](https://hexdocs.pm/dream/3.0.0/guides/beam.html) |
| See all guides | [Guides](https://hexdocs.pm/dream/3.0.0/guides/index.html) |

<!-- Your project: add rows for the parts of your app, for example "Change billing" and the module or doc to read first. -->
