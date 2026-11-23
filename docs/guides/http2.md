# Guide: HTTP/2

**Dream serves HTTP/2 with no change to your application code.** Your routes, controllers, middleware, streaming responses and server-sent events work the same over HTTP/1.1 and HTTP/2.

How a client gets HTTP/2 depends on whether the server uses HTTPS. The server listens on one port and answers each client with the protocol that client can use.

| Connection | How the client gets HTTP/2 | Who does this |
|------------|----------------------------|---------------|
| HTTPS, with `server.tls()` | The client and server agree on HTTP/2 during the TLS handshake (ALPN). | Browsers, curl, most HTTP clients |
| Plain HTTP, prior knowledge | The client sends HTTP/2 from its first byte. | Proxies and load balancers set to speak HTTP/2 to their backends (h2c), gRPC clients, `h2load` |

Every other client gets HTTP/1.1 on the same port.

Browsers use HTTP/2 only over HTTPS. If browsers connect to Dream directly, give Dream a certificate.

## Serve HTTPS

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

For local development, [mkcert](https://github.com/FiloSottile/mkcert) makes a certificate that your browser trusts:

```bash illustration
mkcert -install
mkcert -cert-file priv/cert.pem -key-file priv/key.pem localhost
```

## Behind a proxy

Most production setups end TLS at a proxy or load balancer in front of Dream. Clients then get HTTP/2 from the proxy, whatever the proxy speaks to Dream.

To use HTTP/2 between the proxy and Dream as well:

- If the proxy can send HTTP/2 over plain HTTP (often called h2c), point it at Dream's plain HTTP port. Dream accepts it with no setup.
- If the proxy sends HTTP/2 only over TLS, give Dream a certificate with `server.tls()`.

## Check which protocol you get

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

## What stays on HTTP/1.1

- **WebSockets.** Dream's WebSockets run over HTTP/1.1. Browsers open a separate HTTP/1.1 connection for a WebSocket when the server does not offer WebSockets over HTTP/2, so they work over HTTPS as well.
- **Requests with `Upgrade: h2c`.** Dream does not upgrade HTTP/1.1 connections to HTTP/2. RFC 9113 deprecated this upgrade, and it lets a client get past a proxy's rules (h2c smuggling) when the proxy passes `Upgrade` headers on. Such requests get a normal HTTP/1.1 response. Use HTTPS or prior knowledge instead.
- **Server push.** Dream does not push responses. Browsers have dropped support for it.
