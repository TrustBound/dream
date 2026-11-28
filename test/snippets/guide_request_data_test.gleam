//// Request data guide: a test of a controller that validates a JSON body
////
//// The controller is test/snippets/doc_http_data_validation_module.gleam,
//// the example of the module doc of dream/http/validation.

import dream/context.{EmptyContext}
import dream/http/request.{type Request, Http, Http1, Post, Request}
import dream/http/response.{Text}
import dream/router.{EmptyServices}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import snippets/doc_http_data_validation_module as users_controller

fn post_json(body: String) -> Request {
  Request(
    method: Post,
    protocol: Http,
    version: Http1,
    path: "/users",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: request.Text(body),
    headers: [],
    cookies: [],
    content_type: option.Some("application/json"),
    content_length: option.None,
  )
}

pub fn tests() -> TestSuite {
  describe("users_controller.create", [
    it("answers 201 for a valid user", fn() {
      // Arrange
      let request =
        post_json("{\"name\":\"Ada\",\"email\":\"ada@example.com\",\"age\":36}")

      // Act
      let response =
        users_controller.create(request, EmptyContext, EmptyServices)

      // Assert
      response.status
      |> should
      |> be_equal(201)
      |> or_fail_with("a valid user should answer 201")
    }),
    it("lists every field that failed", fn() {
      // Arrange
      let request = post_json("{\"name\":7,\"age\":\"old\"}")

      // Act
      let response =
        users_controller.create(request, EmptyContext, EmptyServices)

      // Assert
      response.body
      |> should
      |> be_equal(Text(
        "{\"errors\":[\"Expected String but found Int at name\",\"Expected Field but found Nothing at email\",\"Expected Int but found String at age\"]}",
      ))
      |> or_fail_with("each failed field should have its message")
    }),
    it("answers 400 for a body that is not JSON", fn() {
      // Arrange
      let request = post_json("{\"name\":")

      // Act
      let response =
        users_controller.create(request, EmptyContext, EmptyServices)

      // Assert
      response.status
      |> should
      |> be_equal(400)
      |> or_fail_with("broken JSON should answer 400")
    }),
  ])
}
