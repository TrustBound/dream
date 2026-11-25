# Test a Dream app that calls other APIs

Your app calls an outside API: a carrier that tracks parcels, a payment provider, a weather service. A test that calls the real API is slow, needs the network, and fails on the day that the API has a problem. Some APIs also cost money for each call. A recording fixes this. You run the tests one time against the API, and the HTTP client writes each request and its response to a file. You commit the files. After that, the tests play the files back, with no network, in CI and on every machine. This guide builds a small Dream app that calls a carrier API with [`dream_http_client`](https://hexdocs.pm/dream_http_client/6.0.0/), and tests it through its routes with recordings.

Why test at this boundary, and not with a mock of your own functions: see [Mock at the system boundary](https://hexdocs.pm/dream_test/3.0.0/guides/mock-at-the-boundary.html).

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which mode to use](#which-mode-to-use)
- [Step 1: Keep the base request in services](#step-1-keep-the-base-request-in-services)
- [Step 2: Choose the mode from the environment](#step-2-choose-the-mode-from-the-environment)
- [Step 3: Start the recorder in the suite setup](#step-3-start-the-recorder-in-the-suite-setup)
- [Step 4: Test the app through its routes](#step-4-test-the-app-through-its-routes)
- [Step 5: Record one time, without the token](#step-5-record-one-time-without-the-token)
- [Step 6: Play back in CI](#step-6-play-back-in-ci)
- [Step 7: Read a request with no recording](#step-7-read-a-request-with-no-recording)
- [Refresh the recordings](#refresh-the-recordings)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

In this guide, you will:

- Put the base request of the carrier API in the services of a Dream app, so that a test can give the app another base request.
- Start a recorder in the setup of a test suite, and give the app services with the recorder in them.
- Record the calls one time against a fake carrier API, with the token removed from the files.
- Play the recordings back with no network, and see the report.
- Read the test failure of a request that has no recording.

All the code is in [`examples/recorded_tests`](https://github.com/TrustBound/dream/tree/3.0.0/examples/recorded_tests) of the Dream repository. Its tests compare each output on this page with the real report.

## Before you start

You need a Dream app, and Dream Test for its tests. If you do not have them, start with [Build your first Dream server](https://hexdocs.pm/dream/3.0.0/guides/getting-started.html) and [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html).

The app needs the HTTP client. The tests read the mode from the environment with `envoy`:

### The dependencies <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/gleam.toml#L8-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
dream_http_client = ">= 6.0.0 and < 7.0.0"
envoy = ">= 1.0.2 and < 2.0.0"
```

The record run uses [`dream_mock_server`](https://hexdocs.pm/dream_mock_server/2.0.0/) as a fake carrier API, so this guide needs no internet. With a real API, you do not need it:

### The dev dependencies <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/gleam.toml#L18-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```toml
dream_mock_server = ">= 2.0.0 and < 3.0.0"
dream_test = ">= 3.0.0 and < 4.0.0"
```

## Which mode to use

A recorder runs in one of three modes. Each mode is a value of the type `recorder.Mode`:

| Your situation | Mode | What the client does |
|:---|:---|:---|
| You want new recordings from the API | `recorder.Record` | Sends each request, and writes the request and its response to a file before the call returns. |
| The tests must run with no network, as in CI | `recorder.Playback` | Answers each request from a file, and sends nothing. A request with no file fails with `NoRecording`. |
| The recorder is in place, but you want live calls for now | `recorder.Passthrough` | Sends each request, and writes nothing. |

The full API of the recorder is in [Testing with recorded responses](https://hexdocs.pm/dream_http_client/6.0.0/guides/recording-and-playback.html). This guide shows how to fit it into a Dream app and its tests.

## Step 1: Keep the base request in services

A Dream controller gets three values: the request, the context and the services. Services hold what the app needs from outside: a database pool, a cache, the base request of an API. The app makes them one time at start, and gives them to each controller. A test makes its own services, so services are the place to put a dependency that a test must change.

The parcels app keeps the base request of the carrier API in its services. The base request has the scheme, the host, the port and the headers, with the token:

### The services of the parcels app <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/src/parcels/services.gleam#L8-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Services {
  Services(carrier: ClientRequest)
}

/// The services of the running app: the carrier API at its real address,
/// with the token from the environment variable `CARRIER_TOKEN`.
pub fn initialize_services() -> Result(Services, String) {
  use token <- result.try(
    envoy.get("CARRIER_TOKEN")
    |> result.replace_error("Set CARRIER_TOKEN to the token of the carrier API"),
  )
  let carrier =
    client.new()
    |> client.scheme(http.Https)
    |> client.host("api.carrier.example")
    |> client.add_header("authorization", "Bearer " <> token)
  Ok(Services(carrier:))
}
```

The client of the carrier API takes the base request as its first parameter, and adds only the path:

### Ask the carrier for a parcel <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/src/parcels/carrier.gleam#L21-L35"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The parcel with `code`, from `GET /v1/parcels/<code>`.
pub fn track(
  carrier: ClientRequest,
  code: String,
) -> Result(Parcel, CarrierError) {
  case carrier |> client.path("/v1/parcels/" <> code) |> client.send() {
    Ok(response) -> decode_parcel(response.body)
    Error(client.ResponseError(response:)) if response.status == 404 ->
      Error(UnknownParcel(code))
    Error(client.ResponseError(response:)) ->
      Error(CarrierFailed("HTTP " <> int.to_string(response.status)))
    Error(client.RequestError(error:)) ->
      Error(CarrierFailed(client.transport_error_to_string(error)))
  }
}
```

The controller of `GET /parcels/:code` gives `services.carrier` to `track`, and turns the result into a response:

### The parcels controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/src/parcels/parcels_controller.gleam#L14-L31"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn show(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case require_string(request, "code") {
    Error(_) -> json_response(status.bad_request, error_json("No parcel code"))
    Ok(code) ->
      case carrier.track(services.carrier, code) {
        Ok(parcel) -> json_response(status.ok, parcel_json(parcel))
        Error(UnknownParcel(code:)) ->
          json_response(status.not_found, error_json("No parcel " <> code))
        // The body names the cause, so a failed test shows it
        Error(CarrierFailed(reason:)) ->
          text_response(bad_gateway, "The carrier API failed:\n" <> reason)
      }
  }
}
```

A parcel is a `200` with JSON. A parcel that the carrier does not know is a `404`. A failed call is a `502` with the reason as text. [Step 7](#step-7-read-a-request-with-no-recording) shows why the reason is in the body.

Nothing in this code knows about recordings. A recorder goes on the base request, so the test gives the app a base request with a recorder, and the code stays as it is.

## Step 2: Choose the mode from the environment

You record on your machine, and CI plays back. So the mode comes from the environment variable `RECORDER_MODE`. `recorder.parse_mode` turns the text into a `recorder.Mode`. It accepts `record`, `playback` and `passthrough`, and gives an `Error` that names any other text. With no variable, the tests play back:

### The context of the tests and the mode <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/recorded_http/carrier_setup.gleam#L20-L37"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// What each parcels test gets: the services of the app, the recorder in
/// them, and the fake carrier API when one runs.
pub type App {
  App(services: Services, recorder: Recorder, carrier: Option(ServerHandle))
}

/// The port of the carrier API in the tests. The recordings hold it, so
/// playback must use the port of the record run.
pub const carrier_port = 19_870

/// `RECORDER_MODE=record gleam test` records. With no `RECORDER_MODE`,
/// the tests play back, so CI needs no network.
pub fn recorder_mode() -> Result(recorder.Mode, String) {
  case envoy.get("RECORDER_MODE") {
    Ok(text) -> recorder.parse_mode(text)
    Error(Nil) -> Ok(recorder.Playback)
  }
}
```

Playback is the default on purpose. A run that forgets the variable sends nothing to the network. Only a run that asks for `record` can change the files.

`App` is the context of the tests: the value that each test gets. It holds the services of the app, the recorder, and the fake carrier API when one runs.

## Step 3: Start the recorder in the suite setup

A recorder is a process. Something must start it before the first test and stop it after the last test. In Dream Test, that is the setup and the teardown of `context.setup`, which `unit_context.describe` takes. The setup runs one time for the suite, and each test gets its value. `start_app` builds the services of the app around the recorder:

### Start the recorder and the services <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/recorded_http/carrier_setup.gleam#L39-L71"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Starts a recorder in `mode`, and the services of the app with it. Only
/// a run that sends requests starts the fake carrier API.
pub fn start_app(mode: recorder.Mode, port: Int) -> Result(App, String) {
  use carrier <- result.try(case mode {
    recorder.Playback -> Ok(None)
    recorder.Record | recorder.Passthrough ->
      start_fake_carrier(port)
      |> result.map(Some)
      |> result.map_error(string.inspect)
  })
  use recorder <- result.try(
    recorder.new()
    |> recorder.directory("test/recordings/carrier")
    |> recorder.mode(mode)
    |> recorder.request_transformer(drop_authorization)
    |> recorder.response_transformer(drop_date)
    |> recorder.start(),
  )
  let base =
    client.new()
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(port)
    |> client.add_header("authorization", "Bearer test-carrier-token")
    |> client.recorder(recorder)
  Ok(App(services: Services(carrier: base), recorder:, carrier:))
}

pub fn stop_app(app: App) -> Result(Nil, String) {
  let stopped = recorder.stop(app.recorder)
  option.map(app.carrier, server.stop)
  stopped
}
```

How it works:

- `Services(carrier: base)` is the same `Services` type that the running app uses. Only the base request is different: it points at the test port, and `client.recorder(recorder)` puts the recorder on it.
- In playback mode, nothing starts and nothing listens. The recorder reads each file in `test/recordings/carrier` when it starts.
- In record and passthrough mode, the setup starts the fake carrier API. With a real API, leave the fake out, and point the base request at the API.
- When the setup returns an `Error`, no test of the suite runs, and the report shows the message. A wrong `RECORDER_MODE` stops the suite there, with the text of `parse_mode`.
- The two transformers keep the token and the `date` header out of the files. [Step 5](#step-5-record-one-time-without-the-token) shows them.

The fake carrier API of the record run has two parcels, and a `404` for every other code:

### The fake carrier API <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/recorded_http/carrier_setup.gleam#L102-L128"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// The fake carrier API of a record run: two parcels, and a 404 for the
/// rest. With the real API, leave it out and point the base request at it.
fn start_fake_carrier(port: Int) {
  server.start_with_config(port, [
    MockRoute(
      path: "/v1/parcels/PX-100",
      path_match: Exact,
      method: Some(http.Get),
      status: 200,
      body: "{\"code\":\"PX-100\",\"status\":\"in_transit\",\"eta\":\"2026-12-02\"}",
    ),
    MockRoute(
      path: "/v1/parcels/PX-200",
      path_match: Exact,
      method: Some(http.Get),
      status: 200,
      body: "{\"code\":\"PX-200\",\"status\":\"delivered\",\"eta\":\"2026-11-20\"}",
    ),
    MockRoute(
      path: "/v1/parcels/",
      path_match: Prefix,
      method: None,
      status: 404,
      body: "{\"error\":\"unknown parcel\"}",
    ),
  ])
}
```

## Step 4: Test the app through its routes

Each test sends a request through the router of the app with `dream.route_request`, as the server does, with the services of the test. The tests check what a client of your app sees: the status and the body.

### The parcels suite <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/recorded_http/parcels_tests.gleam#L19-L45"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() -> TestSuite {
  describe("Parcels", context.setup(start_parcels_app, teardown: stop_app), [
    it("shows a parcel on its way", fn(app: App) {
      get(app, "/parcels/PX-100")
      |> have_answer(
        200,
        "{\"code\":\"PX-100\",\"status\":\"in_transit\",\"eta\":\"2026-12-02\"}",
      )
    }),
    it("shows a delivered parcel", fn(app: App) {
      get(app, "/parcels/PX-200")
      |> have_answer(
        200,
        "{\"code\":\"PX-200\",\"status\":\"delivered\",\"eta\":\"2026-11-20\"}",
      )
    }),
    it("answers 404 for a parcel the carrier does not know", fn(app: App) {
      get(app, "/parcels/PX-404")
      |> have_answer(404, "{\"error\":\"No parcel PX-404\"}")
    }),
  ])
}

fn start_parcels_app() -> Result(App, String) {
  use mode <- result.try(recorder_mode())
  start_app(mode, carrier_port)
}
```

The tests do not know the mode. The same three tests check the live API in a record run, and the files in a playback run. The third test checks an error status: a `404` of the carrier is a recording like any other.

`get` sends the request, and `have_answer` checks it. When the carrier call fails, `have_answer` gives the body of the `502` to `fail_with`, so the report shows the reason line by line:

### Send a request and check the answer <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/recorded_http/parcels_tests.gleam#L47-L69"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Sends `GET path` through the routes of the app, with the services of
/// the test.
pub fn get(app: App, path: String) -> Response {
  send(router.create_router(), app.services, Get, path, "")
}

/// Passes when the app answers `status` with `body`. When the call to the
/// carrier fails, the app answers 502, and the failure message is its
/// body: the reason, line by line.
pub fn have_answer(
  response: Response,
  status: Int,
  body: String,
) -> Result(AssertionResult, String) {
  case response.status {
    502 if status != 502 -> Ok(fail_with(body_text(response)))
    _ ->
      #(response.status, body_text(response))
      |> should
      |> be_equal(#(status, body))
      |> or_fail_with("GET should answer " <> int.to_string(status))
  }
}
```

`send` and `body_text` are small helpers of the example, in [`test/app_request.gleam`](https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/app_request.gleam). `send` builds a `Request` and calls `dream.route_request`, as in [Test the whole app through its routes](https://hexdocs.pm/dream/3.0.0/guides/testing.html#step-9-test-the-whole-app-through-its-routes).

The suite runs from the test `main`. The output checks compare the reports with the outputs on this page, so a record run leaves them out:

### The test main <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/dream_example_recorded_tests_test.gleam#L8-L24"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  runner.new([parcels_tests.tests()])
  |> runner.add_suites_with_config(one_at_a_time(), [lists_tests.tests()])
  |> runner.add_suites(output_checks())
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

/// The output checks compare the reports of a playback run with the
/// outputs that the guides show, so a record run leaves them out.
fn output_checks() {
  case envoy.get("RECORDER_MODE") {
    Ok("record") -> []
    _ -> [outputs_tests.tests()]
  }
}
```

`lists_tests` is the suite of [Test a Dream app's database code with recorded queries](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-queries.html).

## Step 5: Record one time, without the token

A recording file goes into your repository, so it must not hold a secret. The base request sends `authorization: Bearer test-carrier-token`. A request transformer removes the header before the recorder computes the key, and before it writes the file. The `date` header of a response changes on each run, so a response transformer removes it too. Then a new record run of the same answer gives the same file, and `git diff` shows only real changes:

### Remove the token and the date <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/recorded_http/carrier_setup.gleam#L73-L100"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Runs before the recorder computes the key and before it writes the
/// file: no recording holds the token.
fn drop_authorization(request: RecordedRequest) -> RecordedRequest {
  let headers =
    list.filter(request.headers, fn(header) {
      string.lowercase(header.0) != "authorization"
    })
  RecordedRequest(..request, headers:)
}

/// Runs in record mode only, before the recorder writes the response: the
/// `date` header changes on each run, so a new record run of the same
/// answer gives the same file.
fn drop_date(
  _request: RecordedRequest,
  response: RecordedResponse,
) -> RecordedResponse {
  let keep = fn(header: #(String, String)) { header.0 != "date" }
  case response {
    BlockingResponse(..) ->
      BlockingResponse(..response, headers: list.filter(response.headers, keep))
    StreamingResponse(..) ->
      StreamingResponse(
        ..response,
        headers: list.filter(response.headers, keep),
      )
  }
}
```

The request transformer runs in every mode, so a playback request without the token still matches its recording. Compare header names in lower case: a header keeps the case that you gave `add_header`.

Now record. `make record` in the example runs this script. It starts PostgreSQL for the other guide, and runs the tests with `RECORDER_MODE=record`:

### Record the tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/scripts/record.sh#L7-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sh
docker compose up -d --wait postgres
trap 'docker compose down -v' EXIT
RECORDER_MODE=record gleam test
```

In your own project, the HTTP part is one line: `RECORDER_MODE=record gleam test`. The tests pass as they do in playback, and the recorder writes one file for each request. The name of a file starts with the method, the host and the path, then a hash of the match key. This is the file of parcel PX-100, `test/recordings/carrier/GET_localhost__v1_parcels_PX-100_f8df0aae3df27998.json`:

### The recording of PX-100 <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/recordings/carrier/GET_localhost__v1_parcels_PX-100_f8df0aae3df27998.json#L1"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```json
{"version":"1.0","entries":[{"request":{"method":"GET","scheme":"http","host":"localhost","port":19870,"path":"/v1/parcels/PX-100","query":null,"headers":[],"body":""},"response":{"mode":"blocking","status":200,"headers":[["content-type","text/plain; charset=utf-8"],["content-length","58"],["connection","keep-alive"]],"body":"{\"code\":\"PX-100\",\"status\":\"in_transit\",\"eta\":\"2026-12-02\"}"}}]}
```

The request has no headers, and the response has no `date`. The tests of the example also read every file, and fail when one holds `authorization` or the token.

Read each new file before you commit it. A record run accepts whatever the API answered, errors included. Then commit `test/recordings/carrier` with the tests. The files are part of the tests: without them, playback fails each request.

## Step 6: Play back in CI

Now run `gleam test` with no variable. Nothing listens on port 19870, and the tests pass from the files:

### The report of a playback run <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/outputs/http_playback.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Parcels
  ✓ shows a parcel on its way
  ✓ shows a delivered parcel
  ✓ answers 404 for a parcel the carrier does not know

Summary: 3 run, 0 failed, 3 passed in 0ms
```

The example sets each time to `0ms` in its outputs, so that the outputs do not change from run to run.

`make test` in the example runs this script, and the integration job of Dream's CI runs `make test` too. CI needs no network, no fake API and no token:

### Play back the tests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/scripts/playback.sh#L6-L7"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sh
gleam format --check src test
gleam test
```

The recorder finds the file of each request by its match key. By default, the key is the method and the URL: the scheme, the host, the port, the path and the query. Headers and the body do not count. So the playback run must use the port of the record run. That is why the port is a constant of the suite. [Matching requests and hiding secrets in recordings](https://hexdocs.pm/dream_http_client/6.0.0/guides/request-matching-and-scrubbing.html) shows how to put the body in the key, or to leave parts of the URL out.

## Step 7: Read a request with no recording

In playback mode, a request with no file is not sent. `client.send` fails with the transport error `NoRecording`. The error names the method and the URL, and the recordings nearest to the request. A nearest recording has the same method and path, and the error shows each part that differs.

`track` turns the error into text with `client.transport_error_to_string`, and the controller answers `502` with that text. Here are two tests with no recording. The first asks for parcel PX-300, which the record run did not ask for. The second asks for PX-100 on port 19871, a port that the record run did not use:

### Tests with no recording <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/recorded_http/miss_tests.gleam#L11-L35"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn tests() -> TestSuite {
  describe(
    "Parcels",
    context.setup(
      fn() { start_app(recorder.Playback, 19_871) },
      teardown: stop_app,
    ),
    [
      it("shows parcel PX-300", fn(app: App) {
        get(app, "/parcels/PX-300")
        |> have_answer(
          200,
          "{\"code\":\"PX-300\",\"status\":\"in_transit\",\"eta\":\"2026-12-04\"}",
        )
      }),
      it("shows a parcel on its way from port 19871", fn(app: App) {
        get(app, "/parcels/PX-100")
        |> have_answer(
          200,
          "{\"code\":\"PX-100\",\"status\":\"in_transit\",\"eta\":\"2026-12-02\"}",
        )
      }),
    ],
  )
}
```

The app answers each request with `502`, and `have_answer` puts the body in the failure message. The two tests fail:

### The report of requests with no recording <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/recorded_tests/test/outputs/http_miss.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
Parcels
  ✗ shows parcel PX-300
    fail_with
      Message: The carrier API failed:
               No recording matches GET http://localhost:19871/v1/parcels/PX-300
               No recording in test/recordings/carrier has this method and path
    Run it alone: gleam test -- --only "Parcels/shows parcel PX-300"
  ✗ shows a parcel on its way from port 19871
    fail_with
      Message: The carrier API failed:
               No recording matches GET http://localhost:19871/v1/parcels/PX-100
               Nearest recording: test/recordings/carrier/GET_localhost__v1_parcels_PX-100_f8df0aae3df27998.json
                 origin:
                 - http://localhost:19870
                 + http://localhost:19871
    Run it alone: gleam test -- --only "Parcels/shows a parcel on its way from port 19871"

Failures:
Parcels
  ✗ shows parcel PX-300
    fail_with
      Message: The carrier API failed:
               No recording matches GET http://localhost:19871/v1/parcels/PX-300
               No recording in test/recordings/carrier has this method and path
    Run it alone: gleam test -- --only "Parcels/shows parcel PX-300"
  ✗ shows a parcel on its way from port 19871
    fail_with
      Message: The carrier API failed:
               No recording matches GET http://localhost:19871/v1/parcels/PX-100
               Nearest recording: test/recordings/carrier/GET_localhost__v1_parcels_PX-100_f8df0aae3df27998.json
                 origin:
                 - http://localhost:19870
                 + http://localhost:19871
    Run it alone: gleam test -- --only "Parcels/shows a parcel on its way from port 19871"

Summary: 2 run, 2 failed, 0 passed in 0ms
```

The report of PX-300 names the directory, because no recording in it has the method and the path. The report of PX-100 names the nearest recording. Then it shows the part that differs, with the recorded value on the `-` line and the value of the request on the `+` line.

Each failed test ends with a `Run it alone:` line. It is the command that runs only that test, so you can record or debug it on its own. In the example, these two tests run only from the output checks, so the command finds them only in your own suite.

You see this failure in two cases:

1. A new test calls an endpoint that the record run did not call. The report names no nearest recording. Record again.
2. The request changed since the record run: a new query parameter, another port, another body with a body key. The report shows what changed. Fix the request, or record again.

The `502` body holds the reason, so the report can show it. If the reason must not reach the clients of your app, log it in the controller and send a short body. Then test `carrier.track` with `services.carrier` directly, and give its error text to `fail_with`.

## Refresh the recordings

Record again when the API changes, or when you add a test:

1. Run `make record`, or `RECORDER_MODE=record gleam test` in your project.
2. Read `git diff test/recordings`. A changed response is a change of the API. Make sure that your app still handles it.
3. Commit the files with the tests.

You do not need to delete the old files first. A record run replaces the file of each request that it records again, and keeps the files of the requests that it does not record. A file of an endpoint that no test calls any more stays too: delete it by hand.

## Common pitfalls

**A test that passes only in record mode.** *Symptom:* the tests pass with `RECORDER_MODE=record`, and fail in CI with `No recording matches`. *Fix:* the record run did not write a file for that request, or the request changed after it. Commit `test/recordings` with the tests, and record again after you change a request.

**Another port in playback.** *Symptom:* `Nearest recording` with an `origin:` part that differs. *Fix:* the default key compares the whole URL. Use one constant for the port of the record run and of the playback run, as `carrier_port` does.

**A token in a committed file.** *Symptom:* `authorization` shows in a recording. *Fix:* add a request transformer that removes it, compare the header name in lower case, record again, and delete the old file from the history of your repository.

**A file that changes on each record run.** *Symptom:* `git diff` shows a new `date` or request ID after each record run. *Fix:* remove the header with a response transformer, as `drop_date` does.

**A response transformer for files that exist.** *Symptom:* you added a transformer, and an old file still holds the header. *Fix:* a response transformer runs only in record mode. Record again.

## Where to go next

- [Test a Dream app's database code with recorded queries](https://hexdocs.pm/dream/3.0.0/guides/testing-with-recorded-queries.html): the same pattern for PostgreSQL.
- [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html): matchers, fixtures and tests through the routes.
- [Grow a JSON API](https://hexdocs.pm/dream/3.0.0/guides/api-patterns.html): services, errors and the other patterns of a JSON API.
- [Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html): services that hold a database pool.
- [Testing with recorded responses](https://hexdocs.pm/dream_http_client/6.0.0/guides/recording-and-playback.html) and [Matching requests and hiding secrets in recordings](https://hexdocs.pm/dream_http_client/6.0.0/guides/request-matching-and-scrubbing.html): the full API of the recorder.
- [Mock at the system boundary](https://hexdocs.pm/dream_test/3.0.0/guides/mock-at-the-boundary.html): why a recording at the edge of your app beats a mock of your own functions.
