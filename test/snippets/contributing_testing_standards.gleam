//// Test standards: good and bad examples. Shown in
//// docs/contributing/testing.md.

import dream/context.{type AppContext}
import dream/http/error
import dream/http/params.{require_int}
import dream/http/request.{type Request, Get}
import dream/http/response.{
  type Response, type ResponseBody, Text, text_response,
}
import dream/router.{type EmptyServices, type Router, find_route, route, router}
import dream_test/assertions/should.{be_some, equal, or_fail_with, should}
import dream_test/types.{
  type MatchResult, AssertionFailure, AssertionOk, CustomMatcherFailure,
  MatchFailed, MatchOk,
}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/handler.{id_param_handler, test_handler}
import fixtures/request as test_request
import gleam/int
import gleam/option.{Some}
import matchers/extract_route_params.{extract_route_params}

// ✅ Good - focused tests
pub fn focused_tests() -> UnitTest {
  describe("find_route", [
    it("returns route for exact path", fn() {
      let request = test_request.create_request(Get, "/users")
      find_route(create_user_router(), request)
      |> should()
      |> be_some()
      |> or_fail_with("Expected a route for /users")
    }),
    it("extracts params from path", fn() {
      let request = test_request.create_request(Get, "/users/42")
      find_route(create_user_router(), request)
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "42")])
      |> or_fail_with("Expected the id param")
    }),
  ])
}

// ❌ Bad - multiple assertions
pub fn unfocused_test() -> UnitTest {
  it("finds route and extracts params", fn() {
    // Two things being tested
    let request = test_request.create_request(Get, "/users/42")
    let route_found =
      find_route(create_user_router(), request)
      |> should()
      |> be_some()
      |> or_fail_with("Expected a route for /users/42")
    let params_extracted =
      find_route(create_user_router(), request)
      |> should()
      |> be_some()
      |> extract_route_params()
      |> equal([#("id", "42")])
      |> or_fail_with("Expected the id param")
    case route_found {
      AssertionOk -> params_extracted
      _failure -> route_found
    }
  })
}

// ❌ Bad
pub fn extract_text(result: MatchResult(Response)) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> {
      case response.body {
        // Nested!
        Text(text) -> MatchOk(text)
        _non_text_body -> non_text_body_failure()
      }
    }
  }
}

// ✅ Good
pub fn extract_body_text(result: MatchResult(Response)) -> MatchResult(String) {
  case result {
    MatchFailed(failure) -> MatchFailed(failure)
    MatchOk(response) -> extract_from_body(response.body)
  }
}

fn extract_from_body(body: ResponseBody) -> MatchResult(String) {
  case body {
    Text(text) -> MatchOk(text)
    _non_text_body -> non_text_body_failure()
  }
}

// ❌ Bad
pub fn get_user_id(request: Request) -> Int {
  case require_int(request, "id") {
    Ok(id) -> id
    // Error details lost
    Error(_) -> 0
  }
}

// ✅ Good
pub fn show_user(request: Request) -> Response {
  case require_int(request, "id") {
    Ok(id) -> text_response(200, "User " <> int.to_string(id))
    Error(reason) -> text_response(400, error.message(reason))
  }
}

fn create_user_router() -> Router(AppContext, EmptyServices) {
  router()
  |> route(
    method: Get,
    path: "/users",
    controller: test_handler,
    middleware: [],
  )
  |> route(
    method: Get,
    path: "/users/:id",
    controller: id_param_handler,
    middleware: [],
  )
}

fn non_text_body_failure() -> MatchResult(String) {
  MatchFailed(AssertionFailure(
    operator: "extract_body_text",
    message: "Expected Text body",
    payload: Some(CustomMatcherFailure(
      actual: "Non-text body type",
      description: "Body is not Text",
    )),
  ))
}
