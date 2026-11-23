//// Getting started guide: the test of the app
////
//// In your project this is test/hello_dream_test.gleam, and the import of
//// the app is `import hello_dream as app`.

import dream/context.{EmptyContext}
import dream/dream
import dream/http/request.{type Request, Get, Http, Http1, Post, Request}
import dream/http/response.{Text}
import dream/router.{EmptyServices}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/reporters/bdd
import dream_test/runner
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import snippets/guide_getting_started_app as app

// gleam test runs this: it runs the tests and prints the report
pub fn main() {
  runner.new([tests()])
  |> runner.results_reporters([bdd.new()])
  |> runner.exit_on_failure()
  |> runner.run()
}

// A request with no body, headers or cookies
fn request_to(method: request.Method, path: String) -> Request {
  Request(
    method: method,
    protocol: Http,
    version: Http1,
    path: path,
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

// Sends the request through the routes of the app, as the server does
fn send(request: Request) -> response.Response {
  dream.route_request(app.app_router(), request, EmptyContext, EmptyServices)
}

pub fn tests() -> TestSuite {
  describe("hello app", [
    it("answers GET / with 200", fn() {
      // Arrange
      let request = request_to(Get, "/")

      // Act
      let response = send(request)

      // Assert
      response.status
      |> should
      |> be_equal(200)
      |> or_fail_with("GET / should answer 200")
    }),
    it("answers GET / with Hello, World!", fn() {
      // Arrange
      let request = request_to(Get, "/")

      // Act
      let response = send(request)

      // Assert
      response.body
      |> should
      |> be_equal(Text("Hello, World!"))
      |> or_fail_with("GET / should answer Hello, World!")
    }),
    it("answers an unknown path with 404", fn() {
      // Arrange
      let request = request_to(Get, "/missing")

      // Act
      let response = send(request)

      // Assert
      response.status
      |> should
      |> be_equal(404)
      |> or_fail_with("GET /missing should answer 404")
    }),
    it("answers POST / with 404", fn() {
      // Arrange
      let request = request_to(Post, "/")

      // Act
      let response = send(request)

      // Assert
      response.status
      |> should
      |> be_equal(404)
      |> or_fail_with("POST / should answer 404")
    }),
  ])
}
