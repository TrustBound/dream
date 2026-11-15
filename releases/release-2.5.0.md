# Dream 2.5.0 Release Notes

**Release Date:** not released yet (draft)

This release makes HTTP/2 work end to end in Dream's Mist server adapter, for browsers over HTTPS and for clients over plain HTTP. To ship the fixes, the adapter now uses two packages that we publish, `dream_http_server` and `dream_socket_server`. Dream's own API is unchanged.

## Key Highlights

- **HTTP/2 works for real workloads**: Requests with bodies, large uploads, large responses, file responses, server-sent events and streamed responses all work over HTTP/2
- **HTTPS with `server.tls()`**: Browsers and other clients agree on HTTP/2 during the TLS handshake. Over plain HTTP, clients get HTTP/2 with prior knowledge
- **Faster and lighter under load**: HTTP/2 throughput is level with Bandit or ahead of it on the same machine, and memory under load is much lower, most of all on macOS
- **New server packages**: Dream depends on `dream_http_server` and, through it, `dream_socket_server`. Read "Upgrading" first if your project lists `mist` or `glisten` itself
- **`gleam_stdlib` 1.x**: Dream now requires `gleam_stdlib` 1.0.0 or later

## What's New

### HTTP/2 That Works End to End

Before this release, HTTP/2 in the Mist server adapter was not finished. Requests with a body got no response, every request left a process behind, large responses stalled, and several kinds of client input closed or crashed the whole connection. All of that is fixed, with no change to your application code:

- Requests with a body get a response
- Request bodies are read to the end of the stream, with or without a `content-length`, and are checked against it when it is given
- Large responses and large headers are split into frames, and flow control is respected in both directions
- Server-sent events, streamed (chunked) responses and file responses work
- A slow client slows its own response and no longer builds up memory on the server
- Bad input gets the error the HTTP/2 specification asks for and no longer closes or crashes the whole connection
- A handler that fails answers 500 on its own stream only
- The process that serves a request is cleaned up when the request ends
- At most 100 streams run at once on a connection

The full list, one line per change, is in the [changelog of the server package](https://github.com/TrustBound/mist/blob/dream-http-server/CHANGELOG.md).

### HTTPS, and HTTP/2 for Every Kind of Client

`server.tls()` serves HTTPS from a certificate and key.

#### Serve HTTPS <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/server_tls.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http.{ok, text_response}
import dream/http/request.{Get}
import dream/router.{route, router}
import dream/servers/mist/server

fn index(_request, _context, _services) {
  text_response(ok, "Hello over HTTPS")
}

pub fn start(certfile: String, keyfile: String, port: Int) {
  server.new()
  |> server.router(
    router()
    |> route(method: Get, path: "/", controller: index, middleware: []),
  )
  |> server.tls(certfile:, keyfile:)
  |> server.listen_with_handle(port)
}
```

One port serves every client with the protocol it can use:

| Connection | How the client gets HTTP/2 |
|------------|----------------------------|
| HTTPS | The client and server agree on HTTP/2 during the TLS handshake (ALPN). Browsers do this. |
| Plain HTTP, prior knowledge | The client sends HTTP/2 from its first byte, as proxies set to speak h2c to their backends do. |

Every other client gets HTTP/1.1. Dream does not upgrade HTTP/1.1 connections with `Upgrade: h2c`: RFC 9113 deprecated it, and it can let a client get past a proxy's rules. The [HTTP/2 guide](https://github.com/TrustBound/dream/blob/main/docs/guides/http2.md) covers HTTPS, proxies and how to check the protocol.

### Faster and Lighter Under Load

Measured with `h2load -D 10 -t 32 -c 256` against a small test application, on an Apple M1 Max (10 cores, 64 GB, macOS 26.5.1, OTP 28). The machine was quiet but not empty.

| HTTP/2 | mist 6.0.3 | Dream 2.5.0's server | Bandit |
|--------|-----------|----------------------|--------|
| Requests per second | 42k to 74k | 95k | 95k |
| With 100 streams per connection | 80k to 91k | 130k | 128k |
| 1 MB responses per second | | 7.9k | 1.5k |
| 8 MB uploads per second, 8 connections | | 340 | 347 |

| Memory under 256 connections | glisten 9.0.1 | Dream 2.5.0's server |
|------------------------------|---------------|----------------------|
| macOS | about 3 GB | 155 MB |
| Linux | 139 MB | about 70 MB |

The large memory gain is mostly a macOS effect. Linux gets a smaller one, about half.

### Dream's HTTP Server Packages

Dream's router, controllers and HTTP types do not depend on any web server. The server is an adapter, and the one Dream ships today is built on [mist](https://github.com/rawhat/mist), the HTTP server, and mist is built on [glisten](https://github.com/rawhat/glisten), the socket server. Both are by Alex Manning (rawhat) and their contributors. We chose mist for the adapter because we would rather support the libraries the Gleam community already shares than go our own way.

The adapter needed many HTTP/2 fixes in mist and one fix in glisten. We are giving all of them back upstream, which takes time for this many changes. Until upstream releases contain them, the adapter uses two forks that we publish:

| Package | What it is |
|---------|------------|
| [`dream_http_server`](https://hex.pm/packages/dream_http_server) | mist 6.0.3 plus fixes, most of them for HTTP/2, and HTTP/2 over TLS |
| [`dream_socket_server`](https://hex.pm/packages/dream_socket_server) | glisten 9.0.1 plus a socket buffer fix |

Both keep the upstream module names (`mist`, `glisten`). They are named for what they do, so they do not appear when people search Hex for mist or glisten. They are temporary: when upstream releases contain the fixes, Dream goes back to `mist` and `glisten`. See [Dream's HTTP server packages](https://github.com/TrustBound/dream/blob/main/docs/contributing/http-server-packages.md) for the reasons and for how to go back.

### Streaming Uses Chunked Responses

Dream's streaming adapter now uses the server's actor-based chunked responses. Dream's public streaming API (`stream_response`, `sse_response`, `ResponseBody.Stream`) is unchanged.

## Bug Fixes

### Stray 500 After a Fast Streamed Response

Over HTTP/1.1, a streamed response that finished very quickly could be followed by a stray `500 Internal Server Error`. A keep-alive client could read that 500 as the answer to its next request. The first chunk is now sent only after the server has handed the socket to the stream.

### Response Lost to a Connection Reset

Over HTTP/1.1, a response sent just before the connection closed could be lost to a connection reset. The server now reads the remaining request data before it closes.

## Known Limits

- A single HTTP/2 connection uploads large bodies at about 89% of Bandit's speed. With 8 connections it is level.
- The server does not enforce the connection-level receive window. Unread request data on one connection is limited by 100 streams of 1 MiB each.
- The server packages have three new settings (read timeout, send timeout, stream window size). Dream does not expose them yet.

## Testing

- Dream's own tests: 264 run, 0 failed
- `dream_http_client`: 268 passed. Its `h2c_test` drives a real HTTP/2 client against the mock server, which serves its requests through Dream's server adapter
- `dream_mock_server`: 25 passed
- `dream_http_server`: 89 passed, on Gleam 1.17.0 and on Gleam 1.14.0 with OTP 28. Each of its fixes has a test that fails without the fix
- `dream_socket_server`: 6 passed
- CI on `ubuntu-latest` (OTP 28, Gleam 1.17.0): unit tests in 3m 10s, integration tests for the mock server and ten examples in 7m 42s
- Locally (Apple M1 Max, 10 cores, 64 GB, macOS 26.5.1, Gleam 1.17.0): Dream's own tests in about 2 seconds

## Upgrading

Update your dependencies:

```toml
[dependencies]
dream = ">= 2.5.0 and < 3.0.0"
```

Then run:

```bash
gleam deps update dream
```

### Migration Guide

Most projects need nothing more. Two cases need a change:

1. **Your `gleam.toml` lists `mist` or `glisten`.** Dream's server packages define the same modules, and Gleam stops the build with a duplicate module error when two packages do. Replace them:

   ```toml
   # Before
   mist = ">= 5.0.0 and < 6.0.0"
   glisten = ">= 9.0.0 and < 10.0.0"

   # After
   dream_http_server = ">= 1.1.0 and < 2.0.0"
   dream_socket_server = ">= 1.0.0 and < 2.0.0"
   ```

   Your `import mist` and `import glisten` lines stay as they are, because the module names are the same.

2. **Your project still uses `gleam_stdlib` 0.x.** Dream 2.4.1 accepted `gleam_stdlib` from 0.44. Dream 2.5.0 requires `>= 1.0.0 and < 2.0.0`.

## Acknowledgements

To Alex Manning and the contributors to mist and glisten. Problems with the HTTP server in this release belong to us: report them at [TrustBound/mist](https://github.com/TrustBound/mist/issues) or [TrustBound/dream](https://github.com/TrustBound/dream/issues), not to the mist or glisten maintainers.

## Documentation

- [dream](https://hexdocs.pm/dream) - v2.5.0
- [dream_http_server](https://hexdocs.pm/dream_http_server) - v1.1.0
- [dream_socket_server](https://hexdocs.pm/dream_socket_server) - v1.0.0
- [Dream's HTTP server packages](https://github.com/TrustBound/dream/blob/main/docs/contributing/http-server-packages.md)
- [HTTP/2 guide](https://github.com/TrustBound/dream/blob/main/docs/guides/http2.md)
- [Streaming API Reference](https://github.com/TrustBound/dream/blob/main/docs/reference/streaming-api.md)

## Community

- [Full Documentation](https://github.com/TrustBound/dream/tree/main/docs)
- [Discussions](https://github.com/TrustBound/dream/discussions)
- [Report Issues](https://github.com/TrustBound/dream/issues)
- [Contributing Guide](https://github.com/TrustBound/dream/blob/main/CONTRIBUTING.md)

---

**Full Changelog:** [CHANGELOG.md](https://github.com/TrustBound/dream/blob/main/CHANGELOG.md)
