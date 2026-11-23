//// Routing guide: a test of an auth middleware through the routes
////
//// The app is test/snippets/authentication_guide_app.gleam: a public route,
//// and a /profile route behind auth_middleware, which looks the bearer
//// token up in Services.

import dream/dream
import dream/http/header.{type Header, Header}
import dream/http/request.{type Request, Get, Http, Http1, Request}
import dream/http/response.{Text}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import snippets/authentication_guide_app.{Services}
import snippets/authentication_guide_context.{User, default_context}

// One known token, so the tests control who is signed in
fn test_services() -> authentication_guide_app.Services {
  Services(tokens: [
    #("ada-token", User(id: "1", email: "ada@example.com", role: "admin")),
  ])
}

fn get(path: String, headers: List(Header)) -> Request {
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
    headers: headers,
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

fn send(request: Request) -> response.Response {
  dream.route_request(
    authentication_guide_app.create_router(),
    request,
    default_context,
    test_services(),
  )
}

pub fn tests() -> TestSuite {
  describe("auth middleware", [
    it("lets a request with no token reach the public route", fn() {
      // Arrange
      let request = get("/", [])

      // Act
      let response = send(request)

      // Assert
      response.body
      |> should
      |> be_equal(Text("Welcome"))
      |> or_fail_with("GET / should answer Welcome")
    }),
    it("answers 401 for /profile with no token", fn() {
      // Arrange
      let request = get("/profile", [])

      // Act
      let response = send(request)

      // Assert
      response.status
      |> should
      |> be_equal(401)
      |> or_fail_with("GET /profile with no token should answer 401")
    }),
    it("answers 401 for /profile with an unknown token", fn() {
      // Arrange
      let request =
        get("/profile", [Header("Authorization", "Bearer unknown-token")])

      // Act
      let response = send(request)

      // Assert
      response.body
      |> should
      |> be_equal(Text("Invalid token"))
      |> or_fail_with("an unknown token should answer Invalid token")
    }),
    it("gives the signed-in user to the controller", fn() {
      // Arrange
      let request =
        get("/profile", [Header("Authorization", "Bearer ada-token")])

      // Act
      let response = send(request)

      // Assert
      response.body
      |> should
      |> be_equal(Text(
        "{\"id\":\"1\",\"email\":\"ada@example.com\",\"role\":\"admin\"}",
      ))
      |> or_fail_with("GET /profile should answer the user as JSON")
    }),
  ])
}
