[README](https://hexdocs.pm/dream/3.0.0/) > [Guides](https://hexdocs.pm/dream/3.0.0/guides/index.html) > Test a Dream app against a fake API

# Test a Dream app against a fake API

Your app calls an outside service, and you want tests for the bad days too: the service answers `503`, sends HTML where you expect JSON, takes too long, or closes the connection in the middle of a stream. The real service does not fail when you ask it to. A fake does. In this guide, we start [`dream_mock_server`](https://hexdocs.pm/dream_mock_server/2.0.0/) on localhost as a stand-in for a news service. Then we point a Dream app at it, and test each answer that the app must handle, the bad ones included.

The app calls the service with [`dream_http_client`](https://hexdocs.pm/dream_http_client/6.0.0/). The production side of that code, with the base request in services, the typed errors and the `502` and `504` answers, is in [Call another API from a controller](https://hexdocs.pm/dream/3.0.0/guides/calling-other-apis.html). This guide is about the tests.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [A fake or a recording?](#a-fake-or-a-recording)
- [What the mock server can do](#what-the-mock-server-can-do)
- [Step 1: Keep each feed in services](#step-1-keep-each-feed-in-services)
- [Step 2: Write the answers of the fake](#step-2-write-the-answers-of-the-fake)
- [Step 3: Start the fake in the suite setup](#step-3-start-the-fake-in-the-suite-setup)
- [Step 4: Point the app at one case](#step-4-point-the-app-at-one-case)
- [Step 5: Test the answers and an error status](#step-5-test-the-answers-and-an-error-status)
- [Step 6: Test a slow answer and a closed port](#step-6-test-a-slow-answer-and-a-closed-port)
- [Step 7: Test a streamed answer](#step-7-test-a-streamed-answer)
- [Step 8: Keep the fake honest](#step-8-keep-the-fake-honest)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

The news app has two routes. `GET /headlines` asks the news service for the headlines, and answers them as JSON. `GET /live` streams the live feed of the service to the client, line by line. In this guide, we:

- Start two mock servers in the setup of a test suite, each on its own port, and stop them in the teardown.
- Give the app services that point at one case of the fake for each test.
- Test the headlines, a `503`, a body that is not JSON, a slow answer, a closed port, a stream, a stream that starts with `500`, and a stream that drops.
- Run one contract test against the fake and, when you ask for it, against the real service.

All the code is in [`examples/fake_api`](https://github.com/TrustBound/dream/tree/3.0.0/examples/fake_api) of the Dream repository. Its tests compare each report on this page with the real report.

## Before you start

You need a Dream app with tests in Dream Test. If you do not have them, start with [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html) and [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html).

The app needs the HTTP client:

### The dependency of the app <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/fake_api/gleam.toml#L8"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
dream_http_client = ">= 6.0.0 and < 7.0.0"
```

The tests need the mock server, Dream Test, `envoy` to read one environment variable, and `simplifile` to read the expected reports:

### The dev dependencies <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/fake_api/gleam.toml#L15-L18"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
dream_mock_server = ">= 2.0.0 and < 3.0.0"
dream_test = ">= 3.0.0 and < 4.0.0"
envoy = ">= 1.0.2 and < 2.0.0"
simplifile = ">= 2.3.0 and < 3.0.0"
```

No Docker, no network and no token. Everything runs on localhost.

## A fake or a recording?

Dream has two ways to test an app that calls another service. [Test a Dream app that calls other APIs](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-http.html) records the real answers one time and plays them back. This guide builds a fake. They answer different questions:

| | A fake service | Recorded traffic |
|:---|:---|:---|
| Access to the real service | Never needed | Needed for each record run |
| Failures | On demand: any status, a slow answer, a closed port, a dropped stream | Only the failures that the service gave during the record run |
| What a pass proves | The app handles *your idea* of the service | The app handles what the service sent on the day of the record run |
| When it goes stale | When the service changes and the fake does not | When the service changes and nobody records again |

Use a fake when you have no access to the service, or when you must test failures. Use a recording when the exact shape of the real answers is the risk. An app can use both: recordings for the happy paths, a fake for the failures. A fake has one real weakness: it agrees with you. If you misread the docs of the service, the fake and the app are wrong together, and the tests pass. [Step 8](#step-8-keep-the-fake-honest) shows a small guard against that.

## What the mock server can do

Before we design the tests, we must know what `dream_mock_server` 2.0.0 gives. It runs in one of two modes, and a server cannot mix them:

- **Config mode**, with `server.start_with_config(port, routes)`. Each `MockRoute` has a path, `Exact` or `Prefix` match, a method or `None` for every method, a status and a body. The first route that matches wins. A request that matches no route gets `404` with the body `Not found`. The body always goes out at once, with the content type `text/plain; charset=utf-8`. Config mode has no delay, no custom headers and no streaming.
- **Built-in endpoints**, with `server.start(port)`. The paths and the answers are fixed. The ones we use: `GET /slow` answers after 5 seconds, `GET /stream/json` streams 5 JSON lines one each 200 ms, `GET /stream/error` streams with status `500`, and `GET /stream/drop` sends 2 chunks and then closes the connection. `GET /` on a running server lists them all.

So the answers of our own API come from config mode, and the slow and streamed answers come from the built-in endpoints, at their fixed paths. That last fact shapes Step 1.

The mock server does not keep the requests that it gets, so a test cannot ask it what the app sent.

## Step 1: Keep each feed in services

A Dream controller gets its dependencies from the services, and a test makes its own services. That is how a test points the app at the fake with no change to the app code.

The news service gives each feed as a URL. So the app keeps one complete request, path included, for each feed:

### The services of the news app <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/fake_api/src/services.gleam#L7-L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The news service gives each feed as its own URL, so the app keeps one
/// request for each feed.
pub type Services {
  Services(headlines: ClientRequest, live: ClientRequest)
}

/// The services of the running app: the feeds of the news service at
/// their real addresses. The app builds the requests one time, at start.
pub fn initialize_services() -> Services {
  Services(
    headlines: news_service.feed_request(
      http.Https,
      "news.example.com",
      443,
      "/v2/headlines",
    ),
    live: news_service.feed_request(
      http.Https,
      "news.example.com",
      443,
      "/v2/live",
    ),
  )
}
```

`news_service.feed_request` sets the scheme, the host, the port, the path, a connect timeout of 1 second, a timeout of 2 seconds and the `accept` header. The client functions send the request as it is. [Call another API from a controller](https://hexdocs.pm/dream/3.0.0/guides/calling-other-apis.html) explains client code of this kind.

Because the path is in services, a test can point the headlines feed at any path of the fake, also at the fixed `/slow` of the built-in endpoints. If your client module adds the path itself, as a typical client does, the built-in endpoints are out of reach for that call, because their paths do not match yours. Then the mock server can give your app fixed answers and error statuses, but not a slow answer or a stream. For those, write a small fake of your own, as in [Step 7 of the calling-other-apis guide](https://hexdocs.pm/dream/3.0.0/guides/calling-other-apis.html#step-7-test-against-a-local-service).

## Step 2: Write the answers of the fake

The fake gives one path for each case that a test needs. A real service answers one path in different ways on different days. The fake cannot, because a route has one answer. So the cases get their own paths:

### The answers of the fake <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/fake_api/test/fake_news_service.gleam#L29-L57"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Our own answers: one path for each case that a test needs.
pub fn news_routes() -> List(MockRoute) {
  [
    MockRoute(
      path: "/v2/headlines",
      path_match: Exact,
      method: Some(http.Get),
      status: 200,
      body: "{\"headlines\":["
        <> "{\"title\":\"Gleam on the BEAM\",\"url\":\"https://news.example.com/1\"},"
        <> "{\"title\":\"Dream 3.0.0\",\"url\":\"https://news.example.com/2\"}"
        <> "]}",
    ),
    MockRoute(
      path: "/v2/headlines-unavailable",
      path_match: Exact,
      method: Some(http.Get),
      status: 503,
      body: "Service Unavailable",
    ),
    MockRoute(
      path: "/v2/headlines-not-json",
      path_match: Exact,
      method: Some(http.Get),
      status: 200,
      body: "<html>Down for maintenance</html>",
    ),
  ]
}
```

The first route is the happy path: our idea of the answer of the real service. The second route gives a `503`. The third gives `200` with an HTML page, as a service behind a proxy sometimes does during maintenance.

## Step 3: Start the fake in the suite setup

A mock server is a process that listens on a port. Starting it for each test costs time, and two tests on one port at the same time fail. So the suite starts the fake one time, in the setup of `context.setup`, and stops it in the teardown:

### Start and stop the fake <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/fake_api/test/fake_news_service.gleam#L13-L79"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The two servers of the fake: one with our own answers, and one with
/// the built-in endpoints of `dream_mock_server` for slow and streamed
/// answers.
pub type FakeNews {
  FakeNews(answers: ServerHandle, failures: ServerHandle)
}

/// The port of the server with our own answers.
pub const answers_port = 19_910

/// The port of the server with the built-in endpoints.
pub const failures_port = 19_911

/// A port where nothing listens.
pub const closed_port = 19_912

/// Our own answers: one path for each case that a test needs.
pub fn news_routes() -> List(MockRoute) {
  [
    MockRoute(
      path: "/v2/headlines",
      path_match: Exact,
      method: Some(http.Get),
      status: 200,
      body: "{\"headlines\":["
        <> "{\"title\":\"Gleam on the BEAM\",\"url\":\"https://news.example.com/1\"},"
        <> "{\"title\":\"Dream 3.0.0\",\"url\":\"https://news.example.com/2\"}"
        <> "]}",
    ),
    MockRoute(
      path: "/v2/headlines-unavailable",
      path_match: Exact,
      method: Some(http.Get),
      status: 503,
      body: "Service Unavailable",
    ),
    MockRoute(
      path: "/v2/headlines-not-json",
      path_match: Exact,
      method: Some(http.Get),
      status: 200,
      body: "<html>Down for maintenance</html>",
    ),
  ]
}

/// Starts both servers. When the second one cannot start, it stops the
/// first one, so that no server stays on after a failed setup.
pub fn start() -> Result(FakeNews, String) {
  use answers <- result.try(
    server.start_with_config(answers_port, news_routes())
    |> result.map_error(string.inspect),
  )
  case server.start(failures_port) {
    Ok(failures) -> Ok(FakeNews(answers:, failures:))
    Error(start_error) -> {
      server.stop(answers)
      Error(string.inspect(start_error))
    }
  }
}

pub fn stop(fake: FakeNews) -> Result(Nil, String) {
  server.stop(fake.answers)
  server.stop(fake.failures)
  Ok(Nil)
}
```

How it works:

- The fake is two servers: `answers` in config mode with our routes, and `failures` with the built-in endpoints. Each has its own port constant. Choose ports that no other test of your project uses.
- `closed_port` is a port where nothing listens. It needs no server.
- `start` returns an `Error` with the message of the mock server when a port is in use. Then no test of the suite runs, and the report shows the message.
- When the second server fails to start, `start` stops the first one. No server stays on after a failed setup.

## Step 4: Point the app at one case

Each test makes services with the feed that its case needs. `feed` builds the request with the same `feed_request` as the app, at `localhost`, and only changes the timeout:

### A feed on the fake <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/fake_api/test/fake_news_service.gleam#L81-L86"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The request of a feed at `path` on the fake, with a timeout of 500 ms,
/// so that the test of a slow answer is fast.
pub fn feed(port: Int, path: String) -> ClientRequest {
  news_service.feed_request(http.Http, "localhost", port, path)
  |> client.timeout(500)
}
```

The timeout of the app is 2 seconds. In the tests it is 500 ms, so the test of a slow answer is fast. The other settings stay as in the app.

The suite has two small helpers, one for each feed:

### The services of one case <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/fake_api/test/news_tests.gleam#L144-L159"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The services of the app with the headlines feed at `path` on `port`.
fn news_services(port: Int, path: String) -> services.Services {
  Services(
    headlines: feed(port, path),
    live: feed(failures_port, "/stream/json"),
  )
}

/// The services of the app with the live feed at `path` on the server
/// with the built-in endpoints.
fn live_services(path: String) -> services.Services {
  Services(
    headlines: feed(answers_port, "/v2/headlines"),
    live: feed(failures_port, path),
  )
}
```

The tests send each request through the router of the app with `dream.route_request`, as the server does. The helper `get` in [`test/app_request.gleam`](https://github.com/TrustBound/dream/blob/3.0.0/examples/fake_api/test/app_request.gleam) gives the status and the body as text, and it reads a streamed body to its end. The calls from the app to the fake are real HTTP calls on localhost.

## Step 5: Test the answers and an error status

Here is the start of the suite, with the setup, the happy path and the `503`:

### The headlines and a 503 <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/fake_api/test/news_tests.gleam#L15-L50"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() -> TestSuite {
  describe(
    "News",
    context.setup(fake_news_service.start, teardown: fake_news_service.stop),
    [
      group("GET /headlines", [
        it("answers the headlines as JSON", fn(_fake: FakeNews) {
          let services = news_services(answers_port, "/v2/headlines")

          let answer = get(services, "/headlines")

          answer
          |> should
          |> be_equal(#(
            200,
            "{\"headlines\":["
              <> "{\"title\":\"Gleam on the BEAM\",\"url\":\"https://news.example.com/1\"},"
              <> "{\"title\":\"Dream 3.0.0\",\"url\":\"https://news.example.com/2\"}"
              <> "]}",
          ))
          |> or_fail_with("GET /headlines should answer the headlines")
        }),
        it("answers 502 when the service answers 503", fn(_fake: FakeNews) {
          let services =
            news_services(answers_port, "/v2/headlines-unavailable")

          let answer = get(services, "/headlines")

          answer
          |> should
          |> be_equal(#(
            502,
            "{\"error\":\"The news service failed: HTTP 503\"}",
          ))
          |> or_fail_with("GET /headlines should answer 502")
        }),
```

Each test has three parts: the services of its case, one request, and one exact assertion on the status and the body. The `503` of the service becomes a `502` of our app, with the reason in the body. The test of the HTML page works the same way, and expects the `502` with the decode error.

## Step 6: Test a slow answer and a closed port

A slow answer needs the built-in `/slow`, because config mode has no delay. A closed port needs no server at all:

### A slow answer and a closed port <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/fake_api/test/news_tests.gleam#L64-L89"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
        it("answers 504 when the service is slow", fn(_fake: FakeNews) {
          let services = news_services(failures_port, "/slow")

          let answer = get(services, "/headlines")

          answer
          |> should
          |> be_equal(#(
            504,
            "{\"error\":\"The news service did not answer in 500 ms\"}",
          ))
          |> or_fail_with("GET /headlines should answer 504")
        }),
        it("answers 502 when nothing listens", fn(_fake: FakeNews) {
          let services = news_services(closed_port, "/v2/headlines")

          let answer = get(services, "/headlines")

          answer
          |> should
          |> be_equal(#(
            502,
            "{\"error\":\"The news service failed: Connection failed: Connection refused\"}",
          ))
          |> or_fail_with("GET /headlines should answer 502")
        }),
```

The first test points the headlines feed at `/slow` on the `failures` server. The client gives up after 500 ms, and the app answers `504`. The second test points the feed at `closed_port`. The connection fails at once, and the app answers `502`.

The test of the slow answer has a cost that you do not see in its own time. `/slow` always waits 5 seconds, and `server.stop` waits for that request to end. So the teardown of the suite takes about 5 seconds more. We measured it: with the `/slow` test, the suite with its teardown takes 5.0 s, and without it, 1.0 s. Keep the slow test in one suite, so that you pay this cost one time.

## Step 7: Test a streamed answer

Config mode cannot stream, so the stream tests use the built-in stream endpoints. The app relays the lines of the live feed to its client:

### The stream tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/fake_api/test/news_tests.gleam#L91-L138"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
      group("GET /live", [
        it("streams the feed line by line", fn(_fake: FakeNews) {
          let services = live_services("/stream/json")

          let answer = get(services, "/live")

          answer
          |> should
          |> be_equal(#(
            200,
            "{\"event\":\"chunk\",\"number\":1,\"message\":\"JSON event 1\"}\n"
              <> "{\"event\":\"chunk\",\"number\":2,\"message\":\"JSON event 2\"}\n"
              <> "{\"event\":\"chunk\",\"number\":3,\"message\":\"JSON event 3\"}\n"
              <> "{\"event\":\"chunk\",\"number\":4,\"message\":\"JSON event 4\"}\n"
              <> "{\"event\":\"chunk\",\"number\":5,\"message\":\"JSON event 5\"}\n",
          ))
          |> or_fail_with("GET /live should stream the five lines")
        }),
        it("answers 502 when the stream starts with 500", fn(_fake: FakeNews) {
          let services = live_services("/stream/error")

          let answer = get(services, "/live")

          answer
          |> should
          |> be_equal(#(
            502,
            "{\"error\":\"The news service failed: HTTP 500\"}",
          ))
          |> or_fail_with("GET /live should answer 502")
        }),
        it(
          "ends the stream with the failure when the connection drops",
          fn(_fake: FakeNews) {
            let services = live_services("/stream/drop")

            let answer = get(services, "/live")

            answer
            |> should
            |> be_equal(#(
              200,
              "Drop chunk 1\nDrop chunk 2\n"
                <> "The news service failed: Remote closed connection\n",
            ))
            |> or_fail_with("GET /live should end with the failure")
          },
        ),
```

The first test checks that all 5 lines of `/stream/json` reach the client, in order. The lines are the fixed lines of the mock server, not news. That is enough to test the relay.

The second test checks a stream that starts with status `500`. The app reads the first chunk before it sends its own status, so it can still answer `502`.

The third test is the hard case. `/stream/drop` sends 2 chunks and then closes the connection. By then, the app sent `200` and the first lines. It cannot change the status, so it ends the stream with a line that names the failure. The test proves that the client gets that line, and not a stream that stops with no reason.

Now run `make test`. The report of the suite:

### The report of the news suite <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/fake_api/test/outputs/news.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
News
  GET /headlines
    ✓ answers the headlines as JSON
    ✓ answers 502 when the service answers 503
    ✓ answers 502 when the body is not JSON
    ✓ answers 504 when the service is slow
    ✓ answers 502 when nothing listens
  GET /live
    ✓ streams the feed line by line
    ✓ answers 502 when the stream starts with 500
    ✓ ends the stream with the failure when the connection drops

Summary: 8 run, 0 failed, 8 passed in 0ms
```

The example sets each time to `0ms` in its outputs, so that the outputs do not change from run to run.

## Step 8: Keep the fake honest

The fake proves the app against our idea of the service. If the idea is wrong, every test can pass while production fails. A contract test is a small guard. It is one assertion about the shape that the app needs, and it runs against both sides: always against the fake, and against the real service when you give its URL.

### The contract suite <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/fake_api/test/contract_tests.gleam#L24-L63"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() -> TestSuite {
  describe(
    "The headlines contract",
    context.setup(start_fake, teardown: stop_fake),
    [
      it("holds for the fake", fn(_fake: ServerHandle) {
        let headlines = feed(contract_port, "/v2/headlines")

        has_headlines(headlines)
      }),
      real_service_test(envoy.get("NEWS_HEADLINES_URL")),
    ],
  )
}

/// Passes when the feed answers at least one headline with a title and a
/// URL: the shape that the app needs.
fn has_headlines(feed: ClientRequest) -> Result(AssertionResult, String) {
  let count = news_service.get_headlines(feed) |> result.map(list.length)

  count
  |> result.map(fn(count) { count > 0 })
  |> should
  |> be_equal(Ok(True))
  |> or_fail_with("the feed should answer at least one headline")
}

fn real_service_test(url: Result(String, Nil)) -> ContextNode(ServerHandle) {
  case url {
    Ok(text) ->
      it("holds for the real service", fn(_fake: ServerHandle) {
        use headlines <- result.try(real_feed(text))
        has_headlines(headlines)
      })
    Error(Nil) ->
      skip("holds for the real service", fn(_fake: ServerHandle) {
        Error("Set NEWS_HEADLINES_URL to run it")
      })
  }
}
```

`has_headlines` uses `news_service.get_headlines`, the same decoder as the app. So the contract is not a copy of the shape that can drift. It is the code of the app. With no `NEWS_HEADLINES_URL`, the test of the real service is a skip, and the report says so:

### The report of the contract suite <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/fake_api/test/outputs/contract.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
The headlines contract
  ✓ holds for the fake
  - holds for the real service

Summary: 2 run, 0 failed, 1 passed, 1 skipped in 0ms
```

To run it against the real service, set the URL, for example `NEWS_HEADLINES_URL=https://news.example.com/v2/headlines gleam test`. When the real test fails and the fake test passes, the fake is wrong: change the fake, and then the app. Run it from a scheduled CI job that has access to the service, not in each pull request: the fake is there so that the tests need no network.

## Common pitfalls

**A port in use.** *Symptom:* the setup fails with `Port 19910 already in use on localhost`, and no test of the suite runs. *Fix:* give each server its own port constant, and do not use one port in two suites that can run at the same time.

**A suite that is 5 seconds slower than its tests.** *Symptom:* the report shows short tests, but the run takes 5 seconds more. *Fix:* nothing is wrong. `server.stop` waits for the `/slow` request. Keep that test in one suite.

**A crash report in the output.** *Symptom:* the output shows `=CRASH REPORT====` with `intentional crash to drop connection`. *Fix:* nothing is wrong. That is how `/stream/drop` closes the connection. The mock server also prints a `Listening on` line for each server.

**A fake that agrees with your bug.** *Symptom:* all tests pass, and production fails to decode the answer. *Fix:* run the contract test against the real service, and change the fake to match.

**A route that answers the wrong case.** *Symptom:* a test gets the answer of another route. *Fix:* the first route that matches wins, and `Prefix` matches more than you expect: `/v2/headlines` as a prefix also matches `/v2/headlines-unavailable`. Use `Exact`, or put the specific routes first.

## Where to go next

- [Call another API from a controller](https://hexdocs.pm/dream/3.0.0/guides/calling-other-apis.html): the client code, the typed errors, and the `502` and `504` answers that these tests check.
- [Test a Dream app that calls other APIs](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-http.html): record the real answers one time, and play them back in CI.
- [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html): matchers, fixtures and tests through the routes.
- [`dream_mock_server`](https://hexdocs.pm/dream_mock_server/2.0.0/): every built-in endpoint, and config mode.
- [Mock at the system boundary](https://hexdocs.pm/dream_test/3.0.0/guides/mock-at-the-boundary.html): why a fake at the edge of your app beats a mock of your own functions.
