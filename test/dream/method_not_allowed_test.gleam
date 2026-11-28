//// Tests for the answer to a request that no route matches.
////
//// A path that no route matches gets 404. A path that a route matches, with
//// a method that no route of that path has, gets 405 with an `Allow` header
//// (RFC 9110, sections 15.5.6 and 10.2.1). `dream.route_request` gives the
//// same answers as the server, so these tests call it.

import dream/context.{type AppContext, AppContext}
import dream/dream
import dream/http/header
import dream/http/request.{
  type Method, Delete, Get, Head, Options, Other, Patch, Post, Put,
}
import dream/http/response.{type Response, type ResponseBody, Text}
import dream/router.{
  type EmptyServices, type Router, EmptyServices, route, router, stream_route,
}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import fixtures/handler.{test_handler}
import fixtures/request as test_request
import gleam/option.{type Option, None, Some}

pub fn tests() -> TestSuite {
  describe("the answer when no route matches", [
    it("answers 405 with Allow for a known path with another method", fn() {
      // Arrange
      let app_router =
        router()
        |> get_route("/")
        |> method_route(Post, "/")

      // Act
      let answer = ask(app_router, Delete, "/")

      // Assert
      answer
      |> should
      |> be_equal(method_not_allowed("GET, POST"))
      |> or_fail_with("DELETE / should get 405 with Allow: GET, POST")
    }),
    it("answers 404 for a path that no route matches", fn() {
      // Arrange
      let app_router = router() |> get_route("/")

      // Act
      let answer = ask(app_router, Delete, "/missing")

      // Assert
      answer
      |> should
      |> be_equal(not_found())
      |> or_fail_with("DELETE /missing should get 404 with no Allow")
    }),
    it("lists the methods in alphabetical order", fn() {
      // Arrange
      let app_router =
        router()
        |> method_route(Put, "/items")
        |> method_route(Post, "/items")
        |> get_route("/items")
        |> method_route(Delete, "/items")

      // Act
      let answer = ask(app_router, Patch, "/items")

      // Assert
      answer
      |> should
      |> be_equal(method_not_allowed("DELETE, GET, POST, PUT"))
      |> or_fail_with("Allow should list the methods in alphabetical order")
    }),
    it("matches path parameters", fn() {
      // Arrange
      let app_router = router() |> get_route("/users/:id")

      // Act
      let answer = ask(app_router, Delete, "/users/42")

      // Assert
      answer
      |> should
      |> be_equal(method_not_allowed("GET"))
      |> or_fail_with("DELETE /users/42 should get 405 with Allow: GET")
    }),
    it("joins the methods of every route that matches the path", fn() {
      // Arrange
      let app_router =
        router()
        |> get_route("/users/new")
        |> method_route(Post, "/users/:id")

      // Act
      let answer = ask(app_router, Delete, "/users/new")

      // Assert
      answer
      |> should
      |> be_equal(method_not_allowed("GET, POST"))
      |> or_fail_with("GET matches the literal route, POST the param route")
    }),
    it("treats an Other method like any method", fn() {
      // Arrange
      let app_router = router() |> method_route(Other("PURGE"), "/cache")

      // Act
      let answer = ask(app_router, Get, "/cache")

      // Assert
      answer
      |> should
      |> be_equal(method_not_allowed("PURGE"))
      |> or_fail_with("GET /cache should get 405 with Allow: PURGE")
    }),
    it("answers an Other method that the path does not have with 405", fn() {
      // Arrange
      let app_router = router() |> get_route("/cache")

      // Act
      let answer = ask(app_router, Other("PURGE"), "/cache")

      // Assert
      answer
      |> should
      |> be_equal(method_not_allowed("GET"))
      |> or_fail_with("PURGE /cache should get 405 with Allow: GET")
    }),
    it("names a method once when two methods have the same name", fn() {
      // Arrange
      let app_router =
        router()
        |> get_route("/x")
        |> method_route(Other("GET"), "/x")

      // Act
      let answer = ask(app_router, Delete, "/x")

      // Assert
      answer
      |> should
      |> be_equal(method_not_allowed("GET"))
      |> or_fail_with("Get and Other(\"GET\") should give one GET in Allow")
    }),
    it("lists the method of a stream route", fn() {
      // Arrange
      let app_router =
        router()
        |> stream_route(
          method: Post,
          path: "/upload",
          controller: test_handler,
          middleware: [],
        )

      // Act
      let answer = ask(app_router, Get, "/upload")

      // Assert
      answer
      |> should
      |> be_equal(method_not_allowed("POST"))
      |> or_fail_with("GET /upload should get 405 with Allow: POST")
    }),
    it("answers HEAD to a path with only a GET route with 405", fn() {
      // Arrange
      let app_router = router() |> get_route("/page")

      // Act
      let answer = ask(app_router, Head, "/page")

      // Assert
      answer
      |> should
      |> be_equal(method_not_allowed("GET"))
      |> or_fail_with("HEAD /page has no route, so it should get 405")
    }),
    it("answers OPTIONS to a path with no OPTIONS route with 405", fn() {
      // Arrange
      let app_router = router() |> get_route("/page")

      // Act
      let answer = ask(app_router, Options, "/page")

      // Assert
      answer
      |> should
      |> be_equal(method_not_allowed("GET"))
      |> or_fail_with("OPTIONS /page has no route, so it should get 405")
    }),
  ])
}

// ============================================================================
// Helpers
// ============================================================================

fn get_route(
  app_router: Router(AppContext, EmptyServices),
  path: String,
) -> Router(AppContext, EmptyServices) {
  method_route(app_router, Get, path)
}

fn method_route(
  app_router: Router(AppContext, EmptyServices),
  method: Method,
  path: String,
) -> Router(AppContext, EmptyServices) {
  route(
    app_router,
    method: method,
    path: path,
    controller: test_handler,
    middleware: [],
  )
}

/// The status, the Allow header, the content type and the body of the answer
fn ask(
  app_router: Router(AppContext, EmptyServices),
  method: Method,
  path: String,
) -> #(Int, Option(String), Option(String), ResponseBody) {
  let request = test_request.create_request(method, path)
  let response: Response =
    dream.route_request(
      app_router,
      request,
      AppContext(request_id: "test-id"),
      EmptyServices,
    )
  #(
    response.status,
    header.get_header(response.headers, "allow"),
    response.content_type,
    response.body,
  )
}

fn method_not_allowed(
  allow: String,
) -> #(Int, Option(String), Option(String), ResponseBody) {
  #(
    405,
    Some(allow),
    Some("text/plain; charset=utf-8"),
    Text("Method not allowed"),
  )
}

fn not_found() -> #(Int, Option(String), Option(String), ResponseBody) {
  #(404, None, Some("text/plain; charset=utf-8"), Text("Route not found"))
}
