//// Testing guide: a test that fails, to show the report of a failure
////
//// The app is test/snippets/guide_getting_started_app.gleam. The test
//// expects 200 from a path that has no route.

import dream/context.{EmptyContext}
import dream/dream
import dream/http/request.{type Request, Get, Http, Http1, Request}
import dream/router.{EmptyServices}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import snippets/guide_getting_started_app as app

fn get(path: String) -> Request {
  Request(
    method: Get,
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

pub fn tests() -> TestSuite {
  describe("hello app", [
    it("answers GET /about with 200", fn() {
      // Arrange
      let request = get("/about")

      // Act
      let response =
        dream.route_request(
          app.app_router(),
          request,
          EmptyContext,
          EmptyServices,
        )

      // Assert
      response.status
      |> should
      |> be_equal(200)
      |> or_fail_with("GET /about should answer 200")
    }),
  ])
}
