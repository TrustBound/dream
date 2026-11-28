//// The tests of the guide "Call another API from a controller". Each
//// suite starts the fake forecast service and the app on localhost, and
//// sends real HTTP requests to the app.

import dream/context.{EmptyContext}
import dream/servers/mist/server.{type ServerHandle}
import dream_http_client/client
import dream_test/context as test_context
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit
import dream_test/unit_context.{describe, it}
import fake_forecast_service
import forecast_service.{ServiceFailed}
import gleam/erlang/process.{type Subject}
import gleam/http
import gleam/int
import gleam/list
import gleam/result
import gleam/string
import router
import services.{type Services, Services}
import simplifile

/// The fake service and the app of a suite.
pub type Servers {
  Servers(service: ServerHandle, app: ServerHandle)
}

const service_port = 19_880

const app_port = 19_881

/// The services of the app in the tests: the fake service on `port`, and
/// a timeout of 300 ms, so that the test of a slow service is fast.
pub fn test_services(port: Int) -> Services {
  Services(
    forecasts: forecast_service.base_request(http.Http, "localhost", port)
    |> client.timeout(300),
  )
}

pub fn tests() -> TestSuite {
  describe(
    "Forecasts",
    test_context.setup(start_servers, teardown: stop_servers),
    [
      it("answers the forecast of a city as JSON", fn(_servers) {
        ask(app_port, http.Get, "/forecasts/oslo")
        |> should
        |> be_equal(#(200, "{\"city\":\"oslo\",\"high\":4,\"low\":-2}"))
        |> or_fail_with("GET /forecasts/oslo should answer the forecast")
      }),
      it("answers 404 for a city that the service does not know", fn(_servers) {
        ask(app_port, http.Get, "/forecasts/atlantis")
        |> should
        |> be_equal(#(404, "{\"error\":\"No forecast for atlantis\"}"))
        |> or_fail_with("GET /forecasts/atlantis should answer 404")
      }),
      it("answers 502 when the service fails", fn(_servers) {
        ask(app_port, http.Get, "/forecasts/broken")
        |> should
        |> be_equal(#(
          502,
          "{\"error\":\"The forecast service failed: HTTP 500\"}",
        ))
        |> or_fail_with("GET /forecasts/broken should answer 502")
      }),
      it(
        "answers 502 when the service answers JSON of another shape",
        fn(_servers) {
          ask(app_port, http.Get, "/forecasts/lima")
          |> should
          |> be_equal(#(
            502,
            "{\"error\":\"The forecast service failed: Expected Int at high, found String\"}",
          ))
          |> or_fail_with("GET /forecasts/lima should answer 502")
        },
      ),
      it("answers 504 when the service does not answer in time", fn(_servers) {
        ask(app_port, http.Get, "/forecasts/slow")
        |> should
        |> be_equal(#(
          504,
          "{\"error\":\"The forecast service did not answer in 300 ms\"}",
        ))
        |> or_fail_with("GET /forecasts/slow should answer 504")
      }),
      it("sends JSON to the service and answers 201", fn(_servers) {
        ask(app_port, http.Post, "/forecasts/oslo/watches")
        |> should
        |> be_equal(#(201, "{\"watch\":\"watch-oslo\"}"))
        |> or_fail_with("POST /forecasts/oslo/watches should answer 201")
      }),
      it("streams the hourly forecast of the service", fn(_servers) {
        ask(app_port, http.Get, "/forecasts/oslo/hourly")
        |> should
        |> be_equal(#(200, "06:00 3C\n07:00 4C\n08:00 5C\n"))
        |> or_fail_with("GET /forecasts/oslo/hourly should stream 3 lines")
      }),
      it("answers 404 before the stream for an unknown city", fn(_servers) {
        ask(app_port, http.Get, "/forecasts/atlantis/hourly")
        |> should
        |> be_equal(#(404, "{\"error\":\"No forecast for atlantis\"}"))
        |> or_fail_with("GET /forecasts/atlantis/hourly should answer 404")
      }),
      it("shows the answers of the guide", fn(_servers) {
        use expected <- result.try(
          simplifile.read("test/outputs/answers.txt")
          |> result.map_error(simplifile.describe_error),
        )
        guide_answers()
        |> should
        |> be_equal(expected)
        |> or_fail_with("the answers should match test/outputs/answers.txt")
      }),
    ],
  )
}

/// The tests of the client module alone, with no app in front of it.
pub fn client_tests() -> TestSuite {
  unit.describe("get_forecast", [
    unit.it("fails with ServiceFailed when nothing listens", fn() {
      forecast_service.base_request(http.Http, "localhost", 19_889)
      |> forecast_service.get_forecast("oslo")
      |> should
      |> be_equal(Error(ServiceFailed("Connection failed: Connection refused")))
      |> or_fail_with("a call to a closed port should fail")
    }),
  ])
}

/// A slow call to the service holds up only its own request.
pub fn slow_service_tests() -> TestSuite {
  unit.describe("A slow forecast service", [
    unit.it("does not hold up the requests of other clients", fn() {
      use answers <- result.try(answer_while_slow())
      answers
      |> should
      |> be_equal(#("fast: 200", "slow: 200"))
      |> or_fail_with("the fast request should answer first")
    }),
  ])
}

fn answer_while_slow() -> Result(#(String, String), String) {
  let slow_requests = process.new_subject()
  use service <- result.try(fake_forecast_service.start(19_882, slow_requests))
  let answers =
    run_with_app(19_883, test_services(19_882), fn() {
      ask_while_slow(19_883, slow_requests)
    })
  server.stop(service)
  answers
}

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

fn status_text(answer: #(Int, String)) -> String {
  int.to_string(answer.0)
}

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

fn run_with_app(
  port: Int,
  app_services: Services,
  run: fn() -> Result(a, String),
) -> Result(a, String) {
  use app <- result.try(start_app(port, app_services))
  let answer = run()
  server.stop(app)
  answer
}

/// Starts the app on `port`, with `app_services`.
pub fn start_app(
  port: Int,
  app_services: Services,
) -> Result(ServerHandle, String) {
  server.new()
  |> server.context(EmptyContext)
  |> server.services(app_services)
  |> server.router(router.create_router())
  |> server.listen_with_handle(port)
  |> result.map_error(string.inspect)
}

/// Sends `method path` to the app on `port`, and gives the status and
/// the body.
pub fn ask(port: Int, method: http.Method, path: String) -> #(Int, String) {
  let answer =
    client.new()
    |> client.method(method)
    |> client.scheme(http.Http)
    |> client.host("localhost")
    |> client.port(port)
    |> client.path(path)
    |> client.send()
  case answer {
    Ok(response) -> #(response.status, body_text(response))
    Error(client.ResponseError(response:)) -> #(
      response.status,
      body_text(response),
    )
    Error(client.RequestError(error:)) -> #(
      0,
      client.transport_error_to_string(error),
    )
  }
}

fn body_text(response: client.HttpResponse) -> String {
  case client.body_text(response) {
    Ok(text) -> text
    Error(Nil) -> "(the body is not UTF-8 text)"
  }
}

// The requests of the guide, each with the answer of the app: the
// request line, the status line, then the body.
fn guide_answers() -> String {
  [
    #(http.Get, "/forecasts/oslo"),
    #(http.Get, "/forecasts/atlantis"),
    #(http.Get, "/forecasts/broken"),
    #(http.Get, "/forecasts/lima"),
    #(http.Get, "/forecasts/slow"),
    #(http.Post, "/forecasts/oslo/watches"),
    #(http.Get, "/forecasts/oslo/hourly"),
    #(http.Get, "/forecasts/atlantis/hourly"),
  ]
  |> list.map(fn(request) {
    let #(status, body) = ask(app_port, request.0, request.1)
    http.method_to_string(request.0)
    <> " "
    <> request.1
    <> "\n"
    <> int.to_string(status)
    <> " "
    <> string.trim_end(body)
    <> "\n"
  })
  |> string.join("\n")
}
