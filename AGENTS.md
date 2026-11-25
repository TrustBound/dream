# Instructions for coding agents that work on Dream

This file is for an agent that changes the Dream repository itself. To build an app with Dream, use the template in [`docs/agents/AGENTS.md`](https://github.com/TrustBound/dream/blob/3.0.0/docs/agents/AGENTS.md) instead.

The docs of this repository are the source of truth. This file only points at them. When this file and a doc do not agree, the doc is correct: tell the maintainers, and change this file in the same pull request.

## What Dream is

Dream is a web toolkit for Gleam on the BEAM. It is a library, not a framework: it gives explicit pieces (router, middleware, controllers, context, services, server) and the app connects them in its `main`. Read [Design principles](docs/reference/design-principles.md) before you change an API.

| Path | What it holds |
|:---|:---|
| `src/dream/` | The package. `http/` (request, response, headers, cookies, params, validation, errors), `router/` (route trie, path parser), `controllers/` (static files), `servers/mist/` (server adapter, SSE, WebSockets), `services/` (broadcaster), `internal/` (shared code, not for apps) |
| `test/dream/` | Unit tests. The tree mirrors `src/dream/` |
| `test/snippets/` | The tested code of every doc code block |
| `test/fixtures/`, `test/matchers/` | Request and handler fixtures, custom matchers (one matcher in each file) |
| `test/dream_test.gleam` | The test entry point. It lists every test module and turns on line coverage |
| `docs/guides/` | Task guides. Each one is a HexDocs page at `https://hexdocs.pm/dream/3.0.0/guides/<name>.html` |
| `docs/reference/`, `docs/concepts/` | Technical reference and concepts |
| `docs/contributing/` | Contributor rules: [contributing](docs/contributing/contributing.md), [testing](docs/contributing/testing.md), [publishing](docs/contributing/publishing.md), [tone](docs/contributing/tone-guide.md) |
| `examples/` | Example apps. Each one is its own Gleam project with its own tests |
| `integration/` | The runner and HTTP client of the integration tests of the examples |
| `scripts/`, `Makefile`, `.github/workflows/ci.yml` | What CI runs |
| `CHANGELOG.md`, `releases/` | The changelog and the release notes |

Dream modules (for example `dream_http_client`, `dream_postgres`, `dream_ets`) live in their own repositories. Do not add module code to this repository.

## Do not guess

1. Before you change an area, read the guide, the reference page and the source for that area. The table in [Where to look first](#where-to-look-first) names them.
2. Do not invent an API. Before you call a function, find it in `src/`. For a dependency, read its HexDocs at the version that `manifest.toml` locks, for example `https://hexdocs.pm/dream_test/3.0.0/`.
3. Do not invent a rule, a command or a test result. Run the command and read its full output.
4. If the fact that you need is not in your context, in the docs or in the source, stop and ask. Do not fill the gap with a likely answer.
5. If a doc and the code do not agree, report it. Do not pick one in silence.

## Coding standards

Sources: [contributing.md](docs/contributing/contributing.md), [naming-conventions.md](docs/reference/naming-conventions.md), [design-principles.md](docs/reference/design-principles.md), [architecture.md](docs/reference/architecture.md), [contributing/testing.md](docs/contributing/testing.md).

- **Names.** A function name is `{verb}_{noun}`. Do not put the module name in the function name: the module is the namespace. Use full words (`request`, not `req`). Only domain abbreviations such as `id`, `http`, `json`, `url`, `html` and `xml` are permitted. The builder functions of a configuration are the exception (see naming-conventions.md, "Configuration").
- **Explicit over implicit.** No global state, no magic configuration, no hidden behavior.
- **No closures for dependencies.** A function gets each dependency as a parameter, from `Services`, or from a `Dependencies` type for SSE and WebSocket handlers.
- **No nested `case`.** Put the inner `case` in a named helper function, or use a flat `use` chain.
- **Errors are values.** Return `Result(success, error)`. Never discard an error with `Error(_)`: bind it and handle it.
- **No `panic` and no `let assert` in `src`.** Return a `Result`, or make the wrong state impossible with types. For example, `dream.get_server` takes the one value `RisksUnderstood`, not a `Bool`.
- **Builders.** Configure with the builder pattern, one step for each setting.
- **Middleware is per route.** There is no global middleware list.
- **Context and services.** Context is per request. Services are for the whole app.
- **Doc comments.** Each public function has a `///` doc comment with a short description and an example. The example is a tested snippet with a heading and a badge, as in [Code Blocks in READMEs and Guides](docs/contributing/contributing.md#code-blocks-in-readmes-and-guides).
- **Simple over clever.** Abstract when you have three examples, not one.
- **Format.** Run `gleam format`. CI fails on code that is not formatted.

## Testing standards

Sources: [contributing/testing.md](docs/contributing/testing.md), [guides/testing.md](docs/guides/testing.md), [contributing.md](docs/contributing/contributing.md) ("Testing"), and the [dream_test documentation](https://hexdocs.pm/dream_test/3.0.0/).

- Use [dream_test](https://hexdocs.pm/dream_test/3.0.0/), with `describe` or `group` and `it`. Do not write `_test` functions.
- Name the `group` for the function. Name each `it` for the result and the condition, for example `it("returns 404 for NotFound", ...)`.
- Write each test as Arrange, Act, Assert, with a blank line between the three parts.
- Put one assertion in each `it`. Do not throw away the result of a matcher with `let _ =`.
- Assert with the pipe form: `value |> should() |> be_equal(expected) |> or_fail_with("message")`.
- Test the public functions only (black box). A private function that no public function reaches is dead code: delete it.
- A unit test has no database, no network and no files. It is fast and deterministic. A test that needs a real service is an integration test.
- Line coverage of `src/` must be 100%. `gleam test` measures it and fails below 100%, also when every test passes.
- Add a new test module to `test/dream_test.gleam`, or it does not run.
- Put a custom matcher in `test/matchers/`, one in each file. Its first parameter is a `MatchResult(a)`.
- Stop every server that a test starts with `listen_with_handle`, also when an assertion fails. Give each server test its own port.
- Never sleep to wait for a result. Wait for a message, a monitor, or a call with a timeout. See [Sleep in a test](https://hexdocs.pm/dream/3.0.0/guides/beam.html#sleep-in-a-test) in the BEAM guide.

## The docs are proven

Every code block in `README.md`, `SECURITY.md`, the `.md` files of `docs/` and `examples/`, the doc comments of `src/`, and the changelog and release notes from 3.0.0 on, is checked. The rules are in [Code Blocks in READMEs and Guides](docs/contributing/contributing.md#code-blocks-in-readmes-and-guides). In short:

- A Gleam block is a byte-for-byte copy of a file in `test/snippets/`, or of a line range of it. A test in `test/` runs that file.
- The block has a heading with the "tested snippet" badge. The badge links to the file at the release tag, for example `https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/<name>.gleam#L8-L10`.
- A command, output or file block is a copy of a file that a test or CI uses (the `tested_files` list in `gleam.toml`), with the same badge.
- An upgrade guide shows a change as a `diff` block from the real git diff, with the "tested diff" badge.
- A block that nothing can run is an illustration: ```` ```text illustration ````. Keep these few. Never put Gleam code in one.
- Every code fence has a language.
- Do not write a function in a doc that does not exist. When you find a block that breaks these rules, fix it in the same pull request.

## BEAM practices

Read [The BEAM for Dream developers](https://hexdocs.pm/dream/3.0.0/guides/beam.html) and [Why the BEAM?](docs/reference/why-beam.md). These rules come from Dream's own docs:

- Each connection runs in its own process, and the requests on one keep-alive connection share it. Do not keep request state in a shared place. Put shared state (caches, rate limits, pools) in a supervised process or in ETS, and reference it from `Services` ([architecture.md](docs/reference/architecture.md), "Singleton / Global Services").
- Each SSE or WebSocket connection is one actor. Do not do slow work in `on_message`: give it to another process and send the result back as a custom message ([websockets guide](https://hexdocs.pm/dream/3.0.0/guides/websockets.html), "Common pitfalls"). Start timers and subscriptions in `on_init`, not in the controller ([SSE guide](https://hexdocs.pm/dream/3.0.0/guides/sse.html)).
- Do not start a production app with `gleam run`. It does not pass `SIGTERM` to the VM. Use the `entrypoint.sh` of `gleam export erlang-shipment` ([operating guide](https://hexdocs.pm/dream/3.0.0/guides/operating.html), [deployment guide](https://hexdocs.pm/dream/3.0.0/guides/deployment.html)).
- Do not call `listen` in a test. It never returns. Use `listen_with_handle`, and stop the handle.

## Commands

Run these from the repository root before each commit. They are what CI runs.

| Step | Command | Needs |
|:---|:---|:---|
| Format | `gleam format`, then `gleam format --check` | Gleam |
| All unit checks of CI | `make check` (format check, build, unit tests with the 100% coverage gate, docs check) | Gleam, Erlang/OTP 27 or later with the JIT |
| Unit tests only | `make test-unit` | as above |
| Docs check only | `make check-snippets` | the release tags in your clone (`git fetch --tags`) |
| Integration tests of the examples | `make test-integration`, or `(cd examples/<name> && make test-integration)` | PostgreSQL on port 5435 (`make setup-integration-dbs`), Elixir |
| Template modules | `make check-templates` | the `matcha` binary |
| Docker image | `make test-docker` | Docker, port 3000 free |
| Tasks example | `make test-tasks` | Docker, `matcha`, Node.js |

- Run `make check` for every change. Run the integration, template, Docker and tasks checks when your change touches the examples, the templates, the deployment example or the server.
- Use a `Makefile` target when one exists.
- `make install-hooks` installs the pre-commit hook. It checks the format, builds Dream and each example, and runs the docs check.
- Do not publish to Hex. Only maintainers publish ([publishing.md](docs/contributing/publishing.md)).

## Commits and pull requests

From [CONTRIBUTING.md](CONTRIBUTING.md) and [contributing.md](docs/contributing/contributing.md):

- Name the branch `feature/<name>` or `fix/<name>`.
- Use conventional commits: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`.
- Keep each pull request on one subject. Make sure that CI passes.
- Change the docs with the code: guides and HexDocs for a new feature, every reference for an API change, the upgrade guide for a breaking change.

## Where to look first

| Task | Read first |
|:---|:---|
| Any change | [Design principles](docs/reference/design-principles.md), [contributing.md](docs/contributing/contributing.md) |
| Name a function or a variable | [Naming conventions](docs/reference/naming-conventions.md) |
| Router, routes, middleware | [Routing guide](docs/guides/routing.md), [architecture.md](docs/reference/architecture.md), `src/dream/router.gleam`, `src/dream/router/` |
| Request data, params, validation | [Request data guide](docs/guides/request-data.md), `src/dream/http/` |
| Responses, cookies, static files | [Responses guide](docs/guides/responses.md), `src/dream/http/response.gleam`, `src/dream/controllers/static.gleam` |
| Server start, stop, limits | [Operating guide](docs/guides/operating.md), `src/dream/servers/mist/server.gleam` |
| Streaming | [Streaming guide](docs/guides/streaming.md), [streaming API](docs/reference/streaming-api.md) |
| SSE, WebSockets, broadcaster | [SSE guide](docs/guides/sse.md), [WebSockets guide](docs/guides/websockets.md), `src/dream/servers/mist/`, `src/dream/services/broadcaster.gleam` |
| HTTPS, HTTP/2 | [HTTP/2 guide](docs/guides/http2.md), [Dream vs Mist](docs/reference/dream-vs-mist.md) |
| Tests | [contributing/testing.md](docs/contributing/testing.md), [guides/testing.md](docs/guides/testing.md), `test/dream_test.gleam` |
| A doc, a guide, a code block | [contributing.md](docs/contributing/contributing.md) (code blocks), [tone guide](docs/contributing/tone-guide.md), `gleam.toml` (`[tools.dream_snippets]`) |
| Database, models, operations | [Database guide](docs/guides/database-api.md), [architecture.md](docs/reference/architecture.md) |
| Templates, many formats | [Templates guide](docs/guides/templates.md) |
| Deployment | [Deployment guide](docs/guides/deployment.md), `examples/deployment/` |
| A breaking change | [Upgrade guide](docs/guides/upgrading-to-3.md), `CHANGELOG.md` |
| Release or version | [publishing.md](docs/contributing/publishing.md). Ask a maintainer first |
| An example app | `examples/<name>/README.md` and its tests |
