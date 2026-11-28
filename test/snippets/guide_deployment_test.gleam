//// Deployment guide: a test of the health check, with a stub database
////
//// health_check is from test/snippets/deployment_guide_app.gleam. Its
//// database check is a function in Services, so a test gives a stub.

import dream/context.{EmptyContext}
import dream/dream
import dream/http/request.{type Request, Get, Http, Http1, Request}
import dream/http/response.{Text}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import snippets/deployment_guide_app.{Services}

fn health_request() -> Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path: "/health",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: request.Text(""),
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

fn ask_health(
  check_database: fn() -> Result(Nil, String),
) -> response.Response {
  dream.route_request(
    deployment_guide_app.create_router(),
    health_request(),
    EmptyContext,
    Services(check_database: check_database),
  )
}

pub fn tests() -> TestSuite {
  describe("GET /health", [
    it("answers 200 when the database answers", fn() {
      // Act
      let response = ask_health(fn() { Ok(Nil) })

      // Assert
      response.status
      |> should
      |> be_equal(200)
      |> or_fail_with("a healthy database should give 200")
    }),
    it("answers 503 when the database is down", fn() {
      // Act
      let response = ask_health(fn() { Error("connection refused") })

      // Assert
      response.status
      |> should
      |> be_equal(503)
      |> or_fail_with("a database that is down should give 503")
    }),
    it("says why it is unhealthy", fn() {
      // Act
      let response = ask_health(fn() { Error("connection refused") })

      // Assert
      response.body
      |> should
      |> be_equal(Text("Database unavailable"))
      |> or_fail_with("the body should say the database is unavailable")
    }),
  ])
}
