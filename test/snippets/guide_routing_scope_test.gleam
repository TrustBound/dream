//// Routing guide: a test of the member area and the plain group
////
//// The app is test/snippets/guide_routing_scope_app.gleam.

import dream/dream
import dream/http/header.{type Header, Header, get_header}
import dream/http/request.{
  type Method, type Request, Get, Http, Http1, Post, Request,
}
import dream/http/response.{type ResponseBody, Text}
import dream/router.{EmptyServices}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option.{type Option}
import snippets/guide_routing_scope_app.{Context}

fn request(method: Method, path: String, headers: List(Header)) -> Request {
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
    headers: headers,
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

/// The status and the body of the answer
fn send(request: Request) -> #(Int, ResponseBody) {
  let response = answer(request)
  #(response.status, response.body)
}

fn answer(request: Request) -> response.Response {
  dream.route_request(
    guide_routing_scope_app.create_router(),
    request,
    Context(request_id: "request-1"),
    EmptyServices,
  )
}

fn header_of(request: Request, name: String) -> Option(String) {
  get_header(answer(request).headers, name)
}

pub fn tests() -> TestSuite {
  describe("scopes", [
    it("answers 401 for /members with no X-User header", fn() {
      // Arrange
      let profile = request(Get, "/members", [])

      // Act
      let result = send(profile)

      // Assert
      result
      |> should
      |> be_equal(#(401, Text("Sign in first")))
      |> or_fail_with("GET /members with no user should answer 401")
    }),
    it("gives the member to the profile controller", fn() {
      // Arrange
      let profile = request(Get, "/members", [Header("X-User", "ada")])

      // Act
      let result = send(profile)

      // Assert
      result
      |> should
      |> be_equal(#(200, Text("Profile of ada")))
      |> or_fail_with("GET /members should show the profile of ada")
    }),
    it("gives the team id and the member to the team controller", fn() {
      // Arrange
      let team = request(Get, "/members/teams/7", [Header("X-User", "ada")])

      // Act
      let result = send(team)

      // Assert
      result
      |> should
      |> be_equal(#(200, Text("Team 7 of ada")))
      |> or_fail_with("GET /members/teams/7 should show team 7 of ada")
    }),
    it("answers 405 with Allow: GET for POST /members/teams/7", fn() {
      // Arrange
      let team = request(Post, "/members/teams/7", [Header("X-User", "ada")])

      // Act
      let allow = header_of(team, "Allow")

      // Assert
      allow
      |> should
      |> be_equal(option.Some("GET"))
      |> or_fail_with("POST /members/teams/7 should get Allow: GET")
    }),
    it("adds the Cache-Control header to /about", fn() {
      // Arrange
      let about = request(Get, "/about", [])

      // Act
      let cache_control = header_of(about, "Cache-Control")

      // Assert
      cache_control
      |> should
      |> be_equal(option.Some("public, max-age=60"))
      |> or_fail_with("GET /about should have Cache-Control")
    }),
  ])
}
