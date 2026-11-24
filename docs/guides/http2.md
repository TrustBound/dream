# Serve HTTPS and HTTP/2

Browsers only use HTTP/2 over HTTPS, and they want HTTPS anyway. You want your Dream app to serve both, and to know which protocol a client really got. The good news: Dream serves HTTP/2 with no change to your application code. Routes, controllers, middleware, streaming responses and server-sent events work the same over HTTP/1.1 and HTTP/2. This guide turns HTTPS on, checks the protocol with curl against the `simple` example, and shows what happens when the certificate is missing.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [How a client gets HTTP/2](#how-a-client-gets-http2)
- [Step 1: Serve HTTPS](#step-1-serve-https)
- [Step 2: Check which protocol you get](#step-2-check-which-protocol-you-get)
- [Step 3: Decide where TLS ends](#step-3-decide-where-tls-ends)
- [When the certificate is missing](#when-the-certificate-is-missing)
- [What stays on HTTP/1.1](#what-stays-on-http11)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

- An HTTPS server with `server.tls`, which gives HTTP/2 to the clients that ask for it.
- A check with curl that prints the protocol version of an answer.
- The start error for a certificate that isn't there, and a test of it.

## Before you start

You need Dream, and a certificate and key as PEM files. Read [Build your first Dream server](https://github.com/TrustBound/dream/blob/main/docs/guides/getting-started.md) first. The `simple` example's integration run starts it twice: over plain HTTP with `main`, then over HTTPS with this module, which uses a test certificate that the run writes to `build/test_tls`:

### The HTTPS start of the simple example <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/tls_main.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Starts the example over HTTPS, for the HTTP/2 run of the integration
//// tests. It is the same server as `main`, plus `tls()` with the test
//// certificate that `integration/run-scenarios.sh` writes.

import dream/servers/mist/server.{bind, listen, router, tls} as dream
import router.{create_router}

pub fn main() {
  dream.new()
  |> router(create_router())
  |> bind("localhost")
  |> tls(certfile: "build/test_tls/cert.pem", keyfile: "build/test_tls/key.pem")
  |> listen(3000)
}
```

For local development, [mkcert](https://github.com/FiloSottile/mkcert) makes a certificate that your browser trusts. It changes the trust store of your own machine, so no test runs it:

```bash illustration
mkcert -install
mkcert -cert-file priv/cert.pem -key-file priv/key.pem localhost
```

## How a client gets HTTP/2

How a client gets HTTP/2 depends on whether the server uses HTTPS. The server listens on one port and answers each client with the protocol that client can use.

How a client gets HTTP/2 depends on whether the server uses HTTPS. The server listens on one port and answers each client with the protocol that client can use.

| Connection | How the client gets HTTP/2 | Who does this |
|------------|----------------------------|---------------|
| HTTPS, with `server.tls()` | The client and server agree on HTTP/2 during the TLS handshake (ALPN). | Browsers, curl, most HTTP clients |
| Plain HTTP, prior knowledge | The client sends HTTP/2 from its first byte. | Proxies and load balancers set to speak HTTP/2 to their backends (h2c), gRPC clients, `h2load` |

Every other client gets HTTP/1.1 on the same port.

Browsers use HTTP/2 only over HTTPS. If browsers connect to Dream directly, give Dream a certificate.


## Step 1: Serve HTTPS

Pass the paths to your certificate and key (PEM files) to `server.tls()`.

### Serve HTTPS <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/server_tls.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

You can call `server.tls()` before or after the other settings. If a file does not exist, `listen()` stops with the message `Failed to start server: InitFailed("TLS file not found: <path>")`, and `listen_with_handle()` returns `Error(InitFailed("TLS file not found: <path>"))`.


## Step 2: Check which protocol you get

The integration tests of the `simple` example run these commands against its plain HTTP server and its HTTPS server, both on port 3000.

Over HTTPS (`-k` accepts a self-signed certificate):

### Over HTTPS <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_http2.sh#L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -k --http2 -s -o /dev/null -w "%{http_version}\n" https://localhost:3000/
```

Over plain HTTP, with prior knowledge:

### Over plain HTTP <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl --http2-prior-knowledge -s -o /dev/null -w "%{http_version}\n" http://localhost:3000/
```

Each command prints `2` when the response came over HTTP/2:

### The output <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_http2_output.txt#L1"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
2
```

In a browser, open the developer tools, then the Network tab, and show the Protocol column. It shows `h2` for HTTP/2.

## Step 3: Decide where TLS ends

Most production setups end TLS at a proxy or load balancer in front of Dream. Clients then get HTTP/2 from the proxy, whatever the proxy speaks to Dream.

To use HTTP/2 between the proxy and Dream as well:

- If the proxy can send HTTP/2 over plain HTTP (often called h2c), point it at Dream's plain HTTP port. Dream accepts it with no setup.
- If the proxy sends HTTP/2 only over TLS, give Dream a certificate with `server.tls()`.


## When the certificate is missing

Dream checks that both files exist before it opens the port. `listen` stops the program with the error, and `listen_with_handle` returns it. The `simple` example's plain HTTP run has no test certificate yet, so starting `tls_main` there shows the error:

### Start tls_main with no certificate <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L62"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
gleam run -m tls_main 2>&1 | grep "Failed to start server"
```

### The start error <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L729"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Failed to start server: InitFailed("TLS file not found: build/test_tls/cert.pem")
```

The path in the message is the path you gave, relative to the folder the server started in.

## What stays on HTTP/1.1

- **WebSockets.** Dream's WebSockets run over HTTP/1.1. Browsers open a separate HTTP/1.1 connection for a WebSocket when the server does not offer WebSockets over HTTP/2, so they work over HTTPS as well.
- **Requests with `Upgrade: h2c`.** Dream does not upgrade HTTP/1.1 connections to HTTP/2. RFC 9113 deprecated this upgrade, and it lets a client get past a proxy's rules (h2c smuggling) when the proxy passes `Upgrade` headers on. Such requests get a normal HTTP/1.1 response. Use HTTPS or prior knowledge instead.
- **Server push.** Dream does not push responses. Browsers have dropped support for it.


## Test your code

Start the HTTPS server with `listen_with_handle` in a test, and you get the start error as a value. This test gives the server of Step 1 a certificate path that doesn't exist:

### Test the start error <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/guide_http2_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// HTTP/2 guide: a test of the start of an HTTPS server with a missing
//// certificate
////
//// start is from test/snippets/server_tls.gleam: it serves HTTPS with
//// listen_with_handle, which returns the start error instead of stopping
//// the program.

import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/otp/actor
import gleam/result
import snippets/server_tls

pub fn tests() -> TestSuite {
  describe("server_tls.start", [
    it("names the certificate file that is missing", fn() {
      // Act
      let started =
        server_tls.start("priv/missing-cert.pem", "priv/missing-key.pem", 0)

      // Assert
      started
      |> result.map(fn(_handle) { Nil })
      |> should
      |> be_equal(
        Error(actor.InitFailed("TLS file not found: priv/missing-cert.pem")),
      )
      |> or_fail_with("a missing certificate should give InitFailed")
    }),
  ])
}
```

### The report of the test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/guide_http2_report.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
server_tls.start
  ✓ names the certificate file that is missing

Summary: 1 run, 0 failed, 1 passed in 0ms
```

To test that real clients get HTTP/2, run a client against the running server, as the `simple` example's integration run does with the curl commands of Step 2.

## Common pitfalls

- **Browsers still show `http/1.1`.** Browsers use HTTP/2 only over HTTPS. A plain HTTP server gives them HTTP/1.1.
- **A relative certificate path breaks in production.** `tls(certfile: "priv/cert.pem", ...)` is relative to the folder the server starts in. Start the app from its project folder, or pass absolute paths.
- **The proxy speaks HTTP/1.1 to Dream.** Clients still get HTTP/2 from the proxy. Turn on h2c or TLS to the backend only if you need HTTP/2 all the way.
- **Expecting `Upgrade: h2c` to work.** Dream answers such requests over HTTP/1.1, on purpose. Use HTTPS or prior knowledge.

## Where to go next

- [Start, stop and troubleshoot the server](https://github.com/TrustBound/dream/blob/main/docs/guides/operating.md): other start errors.
- [Deploy with Docker](https://github.com/TrustBound/dream/blob/main/docs/guides/deployment.md).
- The API reference of `dream/servers/mist/server` on [HexDocs](https://hexdocs.pm/dream/dream/servers/mist/server.html).
