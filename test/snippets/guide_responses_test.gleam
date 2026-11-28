//// Responses guide: a test of the cookie that a controller sends back

import dream/context.{EmptyContext}
import dream/http/cookie.{type Cookie, simple_cookie}
import dream/http/request.{type Request, Get, Http, Http1, Request}
import dream/router.{EmptyServices}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import snippets/guide_responses_visits as visits_controller

fn visit(cookies: List(Cookie)) -> Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path: "/visits",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: request.Text(""),
    headers: [],
    cookies: cookies,
    content_type: option.None,
    content_length: option.None,
  )
}

pub fn tests() -> TestSuite {
  describe("visits_controller.show", [
    it("sets visits to 1 on the first visit", fn() {
      // Arrange
      let request = visit([])

      // Act
      let response =
        visits_controller.show(request, EmptyContext, EmptyServices)

      // Assert
      response.cookies
      |> should
      |> be_equal([simple_cookie("visits", "1")])
      |> or_fail_with("the first visit should set visits=1")
    }),
    it("adds one to the cookie of the request", fn() {
      // Arrange
      let request = visit([simple_cookie("visits", "4")])

      // Act
      let response =
        visits_controller.show(request, EmptyContext, EmptyServices)

      // Assert
      response.cookies
      |> should
      |> be_equal([simple_cookie("visits", "5")])
      |> or_fail_with("visits=4 should become visits=5")
    }),
    it("starts again at 1 when the cookie is not a number", fn() {
      // Arrange
      let request = visit([simple_cookie("visits", "many")])

      // Act
      let response =
        visits_controller.show(request, EmptyContext, EmptyServices)

      // Assert
      response.cookies
      |> should
      |> be_equal([simple_cookie("visits", "1")])
      |> or_fail_with("a cookie that is not a number should count as none")
    }),
  ])
}
