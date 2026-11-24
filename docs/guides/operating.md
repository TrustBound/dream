# Start, stop and troubleshoot the server

A server that runs on your laptop meets new problems in real use: the port is already taken, a certificate path is wrong, a client posts a body far bigger than you expected, a test needs to start and stop a server of its own, and the platform stops your app to deploy a new version. This guide shows what Dream does in each case, with the real errors and answers of the `simplest` and `simple` examples.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which start function to use](#which-start-function-to-use)
- [Step 1: Choose the address and the port](#step-1-choose-the-address-and-the-port)
- [Step 2: Read a start error](#step-2-read-a-start-error)
- [Step 3: Limit the size of request bodies](#step-3-limit-the-size-of-request-bodies)
- [Step 4: Start and stop a server from code](#step-4-start-and-stop-a-server-from-code)
- [Stopping in production](#stopping-in-production)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

- A server bound to the right interface and port.
- The exact start errors for a port in use and a missing certificate.
- A body limit, and the answer a client gets over it.
- A server that a test starts and stops, and a test of the port error.

## Before you start

Read [Build your first Dream server](https://github.com/TrustBound/dream/blob/main/docs/guides/getting-started.md). The examples run from the Dream repository with `make run` in `examples/simplest` and `examples/simple`, both on port 3000.

## Which start function to use

| Your situation | Use | What happens on a start error |
|:---|:---|:---|
| The `main` of your app | `server.listen(port)` | It stops the program with `Failed to start server: ` and the error. It never returns when the start works. |
| A test, or code that must handle the error or stop the server later | `server.listen_with_handle(port)` | It returns `Error(StartError)`, or `Ok(handle)` for `server.stop(handle)`. |

## Step 1: Choose the address and the port

`server.bind` picks the network interface, and `listen` the port:

| `bind` | Who can connect |
|:---|:---|
| `bind("localhost")` | Only programs on the same machine. The right choice in development. |
| `bind("0.0.0.0")` | Any machine that can reach this one, and other containers. Needed in Docker. |
| No `bind` call | The default of the HTTP server, which start errors name `localhost`. |

Read the port from the environment in production, as [Deploy with Docker](https://github.com/TrustBound/dream/blob/main/docs/guides/deployment.md) does, so the platform can choose it.

## Step 2: Read a start error

Before Dream opens the port it checks two things: that the certificate files of `tls()` exist, and that nothing else listens on the port. Start the `simplest` example a second time while the first one runs:

### Start the app again on the same port <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simplest/test/integration/readme.sh#L18"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
gleam run -m main 2>&1 | grep "Failed to start server"
```

### The start error for a port in use <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simplest/test/integration/readme_output.txt#L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Failed to start server: InitFailed("Port 3000 already in use on localhost. Stop the process using that port or choose a different one.")
```

`listen` stopped the program with `Failed to start server:` and the error, an `actor.InitFailed` with a message that says what to do. The full output also has Gleam's `runtime error: panic` header and a stack trace, which the command above leaves out with `grep`.

A missing certificate fails the same way, before the port check. The `simple` example's HTTPS module points at a test certificate that doesn't exist in the plain HTTP run:

### Start the HTTPS module with no certificate <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L62"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
gleam run -m tls_main 2>&1 | grep "Failed to start server"
```

### The start error for a missing certificate <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L729"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Failed to start server: InitFailed("TLS file not found: build/test_tls/cert.pem")
```

## Step 3: Limit the size of request bodies

A normal route reads the whole body into memory before the controller runs, so Dream refuses bodies over a limit. The default is 10,000,000 bytes. The `simple` example sets 1 MB:

### Set the body limit <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/src/main.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// main.gleam

import dream/servers/mist/server.{bind, listen, max_body_size, router} as dream
import router.{create_router}

pub fn main() {
  dream.new()
  |> router(create_router())
  |> bind("localhost")
  // Refuse a buffered request body over 1 MB
  |> max_body_size(1_000_000)
  |> listen(3000)
}
```

Send one byte more than the limit:

### Post a body over the limit <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L66-L67"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
head -c 1000001 /dev/zero | tr '\0' 'a' |
  curl -i -X POST --data-binary @- http://localhost:3000/signups
```

### The answer to a body over the limit <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L730-L736"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 413 Payload Too Large
content-type: text/plain; charset=utf-8
connection: close
content-length: 22
date: (the time of the request)

Request body too large
```

The server answers `413 Content Too Large` (RFC 9110, section 15.5.14) and your controller doesn't run. The reason phrase on the status line is the older name, `Payload Too Large`, from the HTTP server underneath Dream. This request declares its size in `content-length`, so the server answers before it reads the body. Then it closes the connection, and says so with `connection: close`: the body that it did not read can never be read as the next request on the connection. The server does the same after every answer to a request whose body was not read to its end, for example a `404` or `405` for a request with a body.

A client can also send the body in chunks, with no `content-length`:

### Post a chunked body over the limit <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L72-L74"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
head -c 1000001 /dev/zero | tr '\0' 'a' |
  curl -i -X POST -H "transfer-encoding: chunked" --data-binary @- \
    http://localhost:3000/signups
```

### The answer to a chunked body over the limit <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L737-L743"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 413 Payload Too Large
content-type: text/plain; charset=utf-8
connection: close
content-length: 22
date: (the time of the request)

Request body too large
```

The answer is the same. The server reads the chunks until the body grows over the limit, then stops, answers `413` and closes the connection. It never holds more of the body than the limit. A body that stops early, or has malformed chunks, gets `400 Bad Request` with the plain-text body `Request body could not be read`.

Routes made with `stream_route` aren't limited: the controller reads the body chunk by chunk and decides itself, as [Stream responses and uploads](https://github.com/TrustBound/dream/blob/main/docs/guides/streaming.md) shows.

## Step 4: Start and stop a server from code

`listen_with_handle` starts the server and returns at once with a handle. `stop` stops it. This is how a test runs a real server on a port and sends it requests:

### Start, ask and stop a server <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_server_listen_with_handle.gleam#L3-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http/request.{Get}
import dream/http/response.{text_response}
import dream/http/status
import dream/router.{route, router}
import dream/servers/mist/server
import dream_http_client/client
import gleam/http
import gleam/result

pub fn test_server(port: Int) -> Result(String, String) {
  // Start server and get handle
  let started =
    server.new()
    |> server.router(test_router())
    |> server.listen_with_handle(port)

  case started {
    Ok(handle) -> {
      // Make test requests
      let response =
        client.new()
        |> client.scheme(http.Http)
        |> client.host("localhost")
        |> client.port(port)
        |> client.path("/test")
        |> client.send()

      // Stop the server
      server.stop(handle)
      response_body(response)
    }
    Error(_start_error) -> Error("server did not start")
  }
}
```

## Stopping in production

In production, start the app with the `entrypoint.sh` of `gleam export erlang-shipment`, as the image of [Deploy with Docker](https://github.com/TrustBound/dream/blob/main/docs/guides/deployment.md) does. It runs your `main` in the Erlang VM, and `listen` keeps it running. Each request runs in its own process, so a crash in one request doesn't stop the server. Your platform, or Docker, restarts the whole program when it stops.

When the platform stops a copy of your app, it sends `SIGTERM`, and the Erlang VM shuts down: `entrypoint.sh` replaces itself with the VM, so the VM is the process that gets the signal. In the Docker test of the `deployment` example, `docker compose stop` takes about 0.2 seconds, and the app's exit status is `0`. Don't start the app with `gleam run` in production: `gleam run` doesn't pass `SIGTERM` on to the VM, so the platform waits for its grace period, 10 seconds in Docker, and then kills the app.

Dream has no drain step: it doesn't wait for requests that are still running. To deploy without cutting requests off, let the platform stop sending traffic to the old copy first. Most platforms do that with the health check of [Deploy with Docker](https://github.com/TrustBound/dream/blob/main/docs/guides/deployment.md) and a grace period before `SIGTERM`.

To look inside a running VM (process count, memory, scheduler use), start it as a named node and connect a remote shell, or export the VM's metrics to your monitoring. Neither `gleam run` nor `entrypoint.sh run` starts a named node by itself.

## Test your code

Start errors are values with `listen_with_handle`, so a test can check them. This test holds a port with one server, starts a second one on it, and stops the first:

### Test the port error <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/guide_operating_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Operating guide: a test of the start error for a port that is in use

import dream/http/request.{Get}
import dream/http/response.{text_response}
import dream/http/status
import dream/router.{route, router}
import dream/servers/mist/server
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/otp/actor
import gleam/result

const port = 39_871

fn index(_request, _context, _services) {
  text_response(status.ok, "Hello")
}

fn start() -> Result(server.ServerHandle, actor.StartError) {
  server.new()
  |> server.router(
    router()
    |> route(method: Get, path: "/", controller: index, middleware: []),
  )
  |> server.bind("localhost")
  |> server.listen_with_handle(port)
}

// Starts a server, tries a second one on the same port, and stops the first
fn second_start_error() -> Result(Nil, actor.StartError) {
  use first <- result.try(start())
  let second = start()
  server.stop(first)
  result.map(second, fn(_handle) { Nil })
}

pub fn tests() -> TestSuite {
  describe("listen_with_handle", [
    it("refuses a port that another server holds", fn() {
      // Act
      let second = second_start_error()

      // Assert
      second
      |> should
      |> be_equal(
        Error(actor.InitFailed(
          "Port 39871 already in use on localhost. Stop the process using that port or choose a different one.",
        )),
      )
      |> or_fail_with("the second start should fail with the port")
    }),
  ])
}
```

### The report of the test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/guide_operating_report.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
listen_with_handle
  ✓ refuses a port that another server holds

Summary: 1 run, 0 failed, 1 passed in 0ms
```

`second_start_error` stops the first server before it returns, so the port is free for the next test whatever the result.

## Common pitfalls

- **A test server that's never stopped.** The port stays taken, and the next run of the test fails to start. Stop every handle, also when an assertion fails, for example in an `after_each` hook.
- **Two tests on the same port at the same time.** Give each test its own port, or run those tests one at a time.
- **`listen` in a test.** It never returns. Use `listen_with_handle`.
- **A limit that is too large for your memory.** The server can hold a body of up to the limit in memory for each request at the same time. For uploads that can be very large, use a stream route and count the bytes as they arrive.
- **Relative paths in production.** Certificate files and the static root are relative to the folder the program starts in.

## Where to go next

- [Deploy with Docker](https://github.com/TrustBound/dream/blob/main/docs/guides/deployment.md).
- [Serve HTTPS and HTTP/2](https://github.com/TrustBound/dream/blob/main/docs/guides/http2.md).
- [Test your controllers and your app](https://github.com/TrustBound/dream/blob/main/docs/guides/testing.md).
- The API reference of `dream/servers/mist/server` on [HexDocs](https://hexdocs.pm/dream/dream/servers/mist/server.html).
