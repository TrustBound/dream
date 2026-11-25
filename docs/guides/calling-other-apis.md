# Call another API from a controller

Sooner or later, a controller needs data that your app does not have. A forecast service knows the weather, a payment provider knows the charges, a carrier knows where a parcel is. So the controller sends an HTTP request of its own, and waits for the answer. That call is the weak part of the request. The other service can be slow, it can fail, it can answer JSON of another shape, or it can be down. Each of these must become a clear answer to your own client, not a crash and not a request that hangs.

This guide builds a small Dream app that calls a forecast service with [`dream_http_client`](https://hexdocs.pm/dream_http_client/6.0.0/). We keep the call in one client module, give it a typed error, and turn each error into the correct status. Then we send JSON, stream a reply through to the client, and make sure that a slow service holds up only its own request.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Step 1: Build the base request one time](#step-1-build-the-base-request-one-time)
- [Step 2: Put the calls in a client module](#step-2-put-the-calls-in-a-client-module)
- [Step 3: Answer each error with the correct status](#step-3-answer-each-error-with-the-correct-status)
- [Step 4: Send JSON and decode the reply](#step-4-send-json-and-decode-the-reply)
- [Step 5: Stream the reply to the client](#step-5-stream-the-reply-to-the-client)
- [Step 6: Keep a slow service in its own request](#step-6-keep-a-slow-service-in-its-own-request)
- [Step 7: Test against a local service](#step-7-test-against-a-local-service)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide, we:

- Build the base request of the forecast service one time, with its timeouts, and keep it in the services of the app.
- Write one client module for the service. Each function returns a `Result` with a typed error.
- Answer `404` when the service does not know the city, `502` when the service fails, and `504` when it does not answer in time.
- Send JSON to the service, and decode its JSON reply.
- Stream the hourly forecast of the service to the client, chunk by chunk.
- Test all of it against a fake service on localhost.

All the code is in [`examples/outbound_http`](https://github.com/TrustBound/dream/tree/3.0.0/examples/outbound_http) of the Dream repository. Its tests compare each answer on this page with the real answer of the app.

## Before you start

You need a Dream app. If you do not have one, start with [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html).

The app needs the HTTP client, and `gleam_json` to read and write JSON. `gleam_yielder` is for the stream in Step 5:

### The dependencies <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/gleam.toml#L8-L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
dream_http_client = ">= 6.0.0 and < 7.0.0"
gleam_http = ">= 4.3.0 and < 5.0.0"
gleam_json = ">= 2.2.0 and < 4.0.0"
gleam_stdlib = ">= 0.44.0 and < 2.0.0"
gleam_yielder = ">= 1.1.0 and < 2.0.0"
```

## Step 1: Build the base request one time

Each call to the forecast service shares most of its request: the scheme, the host, the port, the headers and the timeouts. Only the path and the body change. So we build that shared part one time, and each call adds its own path to it. `dream_http_client` calls this value a `ClientRequest`. It is a plain value, so we can keep it and use it again.

The base request is a dependency of the app, like a database pool. In Dream, dependencies go in the services. The app makes the services one time, when it starts, and gives them to each controller:

### The services of the app <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/src/services.gleam#L7-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Services {
  Services(forecasts: ClientRequest)
}

/// The services of the running app: the forecast service at its real
/// address. The app builds the base request one time, at start.
pub fn initialize_services() -> Services {
  Services(forecasts: forecast_service.base_request(
    http.Https,
    "forecasts.example.com",
    443,
  ))
}
```

A test makes its own services. Thus the test can point the same code at a fake service on localhost, with no change to the app. Step 7 does this.

The client module builds the base request:

### The base request and its timeouts <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/src/forecast_service.gleam#L34-L48"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The base request of the forecast service. Each call waits at most 1
/// second for a connection, and at most 2 seconds for the answer.
pub fn base_request(
  scheme: http.Scheme,
  host: String,
  port: Int,
) -> ClientRequest {
  client.new()
  |> client.scheme(scheme)
  |> client.host(host)
  |> client.port(port)
  |> client.connect_timeout(1000)
  |> client.timeout(2000)
  |> client.add_header("accept", "application/json")
}
```

Set both timeouts yourself. Without them, the client waits 15 seconds for a connection and 30 seconds for the answer. Your own client, or the load balancer in front of your app, usually gives up before that. Then the request fails with no clear error, and your log does not show the slow service. `connect_timeout` limits the time to open the connection. `timeout` limits the time for the request and its answer. Choose a total that is shorter than the time your own client waits.

## Step 2: Put the calls in a client module

A controller can call `client.send` directly. But then each controller must know the paths of the service, the JSON of its answers, and what each status means. Put that knowledge in one module for each service. The controllers then see only what the app cares about: a forecast, or an error that says what went wrong.

The module starts with its types:

### The types of the client module <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/src/forecast_service.gleam#L16-L32"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Forecast {
  Forecast(city: String, high: Int, low: Int)
}

pub type Watch {
  Watch(id: String, city: String)
}

pub type ForecastError {
  /// The service does not know the city: it answered 404.
  UnknownCity(city: String)
  /// The service did not answer in time.
  NoAnswerInTime(timeout_ms: Int)
  /// Any other failure: a status of 500, no connection, a body that is
  /// not the JSON we expect.
  ServiceFailed(reason: String)
}
```

`ForecastError` has one variant for each answer that our app gives in a different way. The variants do not copy the errors of the HTTP client. They name what happened to the app.

Each function takes the base request as its first parameter, and adds only its own part:

### Get the forecast of a city <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/src/forecast_service.gleam#L50-L62"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The forecast of `city`, from `GET /v1/forecasts/<city>`.
pub fn get_forecast(
  service: ClientRequest,
  city: String,
) -> Result(Forecast, ForecastError) {
  use response <- result.try(
    service
    |> client.path("/v1/forecasts/" <> city)
    |> client.send()
    |> result.map_error(send_error_to_forecast_error(_, city)),
  )
  decode_body(response.body, forecast_decoder())
}
```

`client.send` gives `Ok` only for a status of 200 to 299. Any other status is `ResponseError`, with the full response. A request that gets no answer is `RequestError`, with a `TransportError` that says why. These small functions turn both into a `ForecastError`:

### Turn a failed call into a ForecastError <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/src/forecast_service.gleam#L121-L157"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn send_error_to_forecast_error(
  error: client.SendError,
  city: String,
) -> ForecastError {
  case error {
    client.ResponseError(response:) ->
      status_to_forecast_error(response.status, city)
    client.RequestError(error:) -> transport_error_to_forecast_error(error)
  }
}

fn stream_failure_to_forecast_error(
  failure: StreamFailure,
  city: String,
) -> ForecastError {
  case failure {
    client.HttpFailure(response:) ->
      status_to_forecast_error(response.status, city)
    client.TransportFailure(error:) -> transport_error_to_forecast_error(error)
  }
}

fn status_to_forecast_error(status: Int, city: String) -> ForecastError {
  case status {
    404 -> UnknownCity(city)
    _ -> ServiceFailed("HTTP " <> int.to_string(status))
  }
}

fn transport_error_to_forecast_error(
  error: client.TransportError,
) -> ForecastError {
  case error {
    client.TimedOut(timeout_ms:) -> NoAnswerInTime(timeout_ms)
    _ -> ServiceFailed(client.transport_error_to_string(error))
  }
}
```

The stream of Step 5 fails with a `StreamFailure`, not a `SendError`, so it has its own small function. Both share the rules for a status and for a transport error.

## Step 3: Answer each error with the correct status

Now the controller. It gets the city from the path, calls the client module, and answers:

### The forecast controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/src/controllers/forecasts_controller.gleam#L20-L31"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// GET /forecasts/:city: the forecast as JSON.
pub fn show(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  use city <- with_city(request)
  case forecast_service.get_forecast(services.forecasts, city) {
    Ok(forecast) -> json_response(status.ok, forecast_json(forecast))
    Error(error) -> error_response(error)
  }
}
```

The choice of status tells your client whose problem it is, and if a retry can help:

- The service does not know the city. That is a fact about the city, not a failure, so we pass the `404` through.
- The service failed, or answered something that we cannot read. HTTP has a status for this: `502 Bad Gateway`. It tells the client that our app works, but the service behind it does not.
- The service did not answer in time. That is `504 Gateway Timeout`. A retry later can work.

Do not answer `500` for these. A `500` says that your own code has a bug. The status module of Dream has no constants for `502` and `504`, so the controller names them:

### The answer to each error <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/src/controllers/forecasts_controller.gleam#L60-L80"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The answer to each error of the forecast service.
fn error_response(error: ForecastError) -> Response {
  case error {
    UnknownCity(city:) ->
      json_response(status.not_found, error_json("No forecast for " <> city))
    NoAnswerInTime(timeout_ms:) ->
      json_response(
        gateway_timeout,
        error_json(
          "The forecast service did not answer in "
          <> int.to_string(timeout_ms)
          <> " ms",
        ),
      )
    ServiceFailed(reason:) ->
      json_response(
        bad_gateway,
        error_json("The forecast service failed: " <> reason),
      )
  }
}
```

Here are the answers of the app in the tests. The fake service knows `oslo`, does not know `atlantis`, fails for `broken`, answers JSON of another shape for `lima`, and is slow for `slow`. The tests set the timeout to 300 ms:

### The answers for each city <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/test/outputs/answers.txt#L1-L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
GET /forecasts/oslo
200 {"city":"oslo","high":4,"low":-2}

GET /forecasts/atlantis
404 {"error":"No forecast for atlantis"}

GET /forecasts/broken
502 {"error":"The forecast service failed: HTTP 500"}

GET /forecasts/lima
502 {"error":"The forecast service failed: Expected Int at high, found String"}

GET /forecasts/slow
504 {"error":"The forecast service did not answer in 300 ms"}
```

The `502` body holds the reason, so that the tests can show it. If the reason must not reach your clients, log it in the controller and send a shorter body.

## Step 4: Send JSON and decode the reply

To send data to the service, set the method, the content type and the body on the base request. `json.object` builds the body, so the JSON is always valid:

### Send JSON to the service <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/src/forecast_service.gleam#L64-L81"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Asks the service to watch `city`, with `POST /v1/watches` and the
/// JSON `{"city": city}`.
pub fn watch_city(
  service: ClientRequest,
  city: String,
) -> Result(Watch, ForecastError) {
  let body = json.object([#("city", json.string(city))]) |> json.to_string
  use response <- result.try(
    service
    |> client.method(http.Post)
    |> client.path("/v1/watches")
    |> client.add_header("content-type", "application/json")
    |> client.body(body)
    |> client.send()
    |> result.map_error(send_error_to_forecast_error(_, city)),
  )
  decode_body(response.body, watch_decoder())
}
```

The reply is JSON too. A decoder reads it into a `Watch`, as in [Grow a JSON API](https://hexdocs.pm/dream/3.0.0/guides/api-patterns.html). Do not trust the shape of the reply. A service can change its JSON, and a decode failure then becomes `ServiceFailed`, so the client gets a `502` with the field that did not match, as `lima` shows above.

The controller of `POST /forecasts/:city/watches` answers `201` with the ID of the watch:

### The answer to a watch <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/test/outputs/answers.txt#L16-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
POST /forecasts/oslo/watches
201 {"watch":"watch-oslo"}
```

## Step 5: Stream the reply to the client

The hourly forecast can be long. We do not want to hold all of it in memory before we answer. `client.stream_yielder` gives the reply as a yielder of chunks, and Dream's `stream_response` sends a yielder to the client. So we can connect the two.

There is one problem. The status of our response goes out before the first chunk. After that, a `404` or a timeout of the service cannot change it any more. So we take the first chunk in the controller, before we choose the status:

### Stream the hourly forecast <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/src/forecast_service.gleam#L83-L119"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The hourly forecast of `city`, from `GET /v1/forecasts/<city>/hourly`,
/// chunk by chunk as the service sends it. The first chunk tells if the
/// service answered, so a 404 or a timeout is an `Error` here, before the
/// status of our own response goes out.
pub fn stream_hourly(
  service: ClientRequest,
  city: String,
) -> Result(Yielder(BitArray), ForecastError) {
  let chunks =
    service
    |> client.path("/v1/forecasts/" <> city <> "/hourly")
    |> client.stream_yielder()
  case yielder.step(chunks) {
    yielder.Next(Ok(first), rest) ->
      Ok(
        yielder.single(Ok(first))
        |> yielder.append(rest)
        |> yielder.map(chunk_or_failure_line),
      )
    yielder.Next(Error(failure), _rest) ->
      Error(stream_failure_to_forecast_error(failure, city))
    yielder.Done -> Ok(yielder.empty())
  }
}

// After the first chunk, our status is already sent. A failure can only
// end the stream with a line that says what went wrong.
fn chunk_or_failure_line(chunk: Result(BytesTree, StreamFailure)) -> BitArray {
  case chunk {
    Ok(bytes) -> bytes_tree.to_bit_array(bytes)
    Error(failure) -> <<
      "The forecast service failed: ":utf8,
      client.stream_failure_to_string(failure):utf8,
      "\n":utf8,
    >>
  }
}
```

`yielder.step` sends the request and waits for the first chunk. A status that is not 2xx comes back as `HttpFailure` in that first step, and a timeout as `TransportFailure`. Then the function puts the first chunk back in front of the rest. The HTTP client reads the rest from the service only as fast as Dream sends it on. Thus a slow client does not fill the memory of the app.

The controller gives the yielder to `stream_response`, or answers the error as in Step 3:

### The hourly controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/src/controllers/forecasts_controller.gleam#L46-L58"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// GET /forecasts/:city/hourly: the hourly forecast, streamed from the
/// service to the client chunk by chunk.
pub fn hourly(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  use city <- with_city(request)
  case forecast_service.stream_hourly(services.forecasts, city) {
    Ok(lines) -> stream_response(status.ok, lines, "text/plain")
    Error(error) -> error_response(error)
  }
}
```

A city that the service knows streams with `200`. A city that it does not know gets a normal `404`:

### The answers of the stream <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/test/outputs/answers.txt#L19-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
GET /forecasts/oslo/hourly
200 06:00 3C
07:00 4C
08:00 5C

GET /forecasts/atlantis/hourly
404 {"error":"No forecast for atlantis"}
```

[Stream responses and uploads](https://hexdocs.pm/dream/3.0.0/guides/streaming.html) has more about streamed responses.

## Step 6: Keep a slow service in its own request

On the BEAM, each connection to your app runs in its own process. A controller that waits for the forecast service stops only that process. The other connections go on, each in its own process. So you can call the service directly in the controller, with no thread pool and no async code. [Slow work in a request](https://hexdocs.pm/dream/3.0.0/guides/beam.html#slow-work-in-a-request) in the BEAM guide explains this.

The client that waits is the problem, not the app. The timeout of Step 1 sets the longest wait. A call with no limit keeps the process and the connection until the client gives up, and nothing shows in the log. [A call with no timeout](https://hexdocs.pm/dream/3.0.0/guides/beam.html#a-call-with-no-timeout) shows the same failure with a process call.

The example proves the first part with a test. The fake service holds the request for the city `slow` until the test lets it go. While it holds it, the test asks for `oslo` on another connection:

### Ask for a fast city while a slow one waits <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/test/forecasts_tests.gleam#L159-L181"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// Sends a request for the slow city, and waits until it reaches the
// service. While the service holds it, a request for another city must
// get its answer. Then the test lets the slow request go.
fn ask_while_slow(
  port: Int,
  slow_requests: Subject(Subject(Nil)),
) -> Result(#(String, String), String) {
  let finished = process.new_subject()
  process.spawn(fn() {
    process.send(finished, status_text(ask(port, http.Get, "/forecasts/slow")))
  })
  use release <- result.try(
    process.receive(slow_requests, 2000)
    |> result.replace_error("The slow request did not reach the service"),
  )
  let fast = status_text(ask(port, http.Get, "/forecasts/oslo"))
  process.send(release, Nil)
  use slow <- result.try(
    process.receive(finished, 2000)
    |> result.replace_error("The slow request did not finish"),
  )
  Ok(#("fast: " <> fast, "slow: " <> slow))
}
```

The test expects `#("fast: 200", "slow: 200")`. The fast request gets its answer while the slow request is still in the service. The test does not sleep: it waits for messages, each with a limit.

If each request must call the service, and the service is slow for all of them, a timeout is not enough. Then each request waits for the full timeout. Keep the timeout short, and think about a cache in the services for answers that do not change often.

## Step 7: Test against a local service

The tests start a fake forecast service and the app on localhost, each on its own port. Then they send real HTTP requests to the app. The only difference from production is the services. They point the base request at the fake service, and set a short timeout:

### The services of the tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/test/forecasts_tests.gleam#L34-L41"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The services of the app in the tests: the fake service on `port`, and
/// a timeout of 300 ms, so that the test of a slow service is fast.
pub fn test_services(port: Int) -> Services {
  Services(
    forecasts: forecast_service.base_request(http.Http, "localhost", port)
    |> client.timeout(300),
  )
}
```

`client.timeout(300)` replaces the 2 seconds of the base request. Each builder step sets one value, so a test can change one setting and keep the others.

The fake service is a small Dream app with one city for each answer:

### The fake forecast service <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/test/fake_forecast_service.gleam#L61-L76"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn forecast(
  request: Request,
  _context: EmptyContext,
  services: FakeServices,
) -> Response {
  case require_string(request, "city") {
    Ok("oslo") ->
      json_response(200, "{\"city\":\"oslo\",\"high\":4,\"low\":-2}")
    Ok("lima") ->
      json_response(200, "{\"city\":\"lima\",\"high\":\"warm\",\"low\":18}")
    Ok("broken") -> text_response(500, "The database is down")
    Ok("slow") -> answer_when_released(services.slow_requests)
    Ok(city) -> unknown_city(city)
    Error(problem) -> text_response(400, error.message(problem))
  }
}
```

The setup of the suite starts both servers, and the teardown stops them, also when a test fails:

### Start the fake service and the app <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/outbound_http/test/forecasts_tests.gleam#L187-L205"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn start_servers() -> Result(Servers, String) {
  use service <- result.try(fake_forecast_service.start(
    service_port,
    process.new_subject(),
  ))
  case start_app(app_port, test_services(service_port)) {
    Ok(app) -> Ok(Servers(service:, app:))
    Error(reason) -> {
      server.stop(service)
      Error(reason)
    }
  }
}

fn stop_servers(servers: Servers) -> Result(Nil, String) {
  server.stop(servers.app)
  server.stop(servers.service)
  Ok(Nil)
}
```

A fake service that you write yourself is good when you control both sides, or when you must test cases that the real service rarely gives, such as a timeout. To test against the real answers of a real API, with no network in CI, record them one time. [Test a Dream app that calls other APIs](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-http.html) shows how. The same services work for both: the recorder goes on the base request.

## Common pitfalls

**No timeout on the base request.** *Symptom:* when the service is slow, your clients wait 30 seconds, or the load balancer gives up first with its own error. *Fix:* set `connect_timeout` and `timeout` on the base request, shorter than the wait of your clients.

**`500` for a failure of the service.** *Symptom:* your alerts show a bug in your app, but the bug is in the service. *Fix:* answer `502` for a failed call and `504` for a timeout, as in Step 3.

**A base request built in each request.** *Symptom:* the host and the token are in many controllers, and a test cannot change them. *Fix:* build it one time in the services, as in Step 1.

**A status chosen after the stream starts.** *Symptom:* the client gets `200`, then an empty or a short body, for a city that the service does not know. *Fix:* take the first chunk before you choose the status, as `stream_hourly` does.

**A test that sleeps to make the service slow.** *Symptom:* the test is slow, and it fails on a busy CI machine. *Fix:* let the fake service wait for a message from the test, as `answer_when_released` does, and let the client timeout of the test be short.

## Where to go next

- [Test a Dream app that calls other APIs](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-http.html): test against recordings of the real API.
- [The BEAM for Dream developers](https://hexdocs.pm/dream/3.0.0/guides/beam.html): processes, timeouts and failure.
- [Stream responses and uploads](https://hexdocs.pm/dream/3.0.0/guides/streaming.html): more about streamed responses.
- [Grow a JSON API](https://hexdocs.pm/dream/3.0.0/guides/api-patterns.html): services, errors and JSON.
- [`dream_http_client`](https://hexdocs.pm/dream_http_client/6.0.0/): the full API of the client, with connection pools and HTTP/2.
