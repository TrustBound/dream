//// Tests for the snippets of the database API guide and the concepts page
//// (docs/guides/database-api.md, docs/concepts.md).
////
//// Each snippet in test/snippets/ is shown, line for line, in one of those
//// docs. If a snippet breaks, these tests fail.

import dream/context.{AppContext, EmptyContext}
import dream/dream
import dream/http/header.{Header, get_header}
import dream/http/request.{type Request, Get, PathParam, Post, Request}
import dream/http/response.{type Response}
import dream/router.{EmptyServices, route, router}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import fixtures/request as test_request
import gleam/erlang/process
import gleam/option.{None, Some}
import gleam/time/timestamp
import matchers/extract_body_text.{extract_body_text}
import matchers/extract_response_status.{extract_response_status}
import snippets/concepts_context.{AuthContext}
import snippets/concepts_hello_controller
import snippets/concepts_middleware
import snippets/concepts_signatures
import snippets/concepts_user_view
import snippets/concepts_validation
import snippets/learn_building_api_show_user
import snippets/learn_building_api_user.{User}
import snippets/learn_building_api_user_view

pub fn tests() -> TestSuite {
  describe("learning snippets", [
    building_api_tests(),
    concepts_tests(),
  ])
}

fn building_api_tests() -> UnitNode {
  group("learn building api", [
    it("to_json formats one user", fn() {
      // Arrange
      let user = create_lesson_user(1, "Ada", "ada@example.com")

      // Act
      let json = learn_building_api_user_view.to_json(user)

      // Assert
      json
      |> should()
      |> be_equal("{\"id\":1,\"name\":\"Ada\",\"email\":\"ada@example.com\"}")
      |> or_fail_with("to_json should format the user")
    }),
    it("list_to_json formats each user in order", fn() {
      // Arrange
      let users = [
        create_lesson_user(1, "Ada", "ada@example.com"),
        create_lesson_user(2, "Bo", "bo@example.com"),
      ]

      // Act
      let json = learn_building_api_user_view.list_to_json(users)

      // Assert
      json
      |> should()
      |> be_equal(
        "[{\"id\":1,\"name\":\"Ada\",\"email\":\"ada@example.com\"},"
        <> "{\"id\":2,\"name\":\"Bo\",\"email\":\"bo@example.com\"}]",
      )
      |> or_fail_with("list_to_json should format both users")
    }),
    it("list_to_json formats no users as an empty array", fn() {
      // Arrange
      let users = []

      // Act
      let json = learn_building_api_user_view.list_to_json(users)

      // Assert
      json
      |> should()
      |> be_equal("[]")
      |> or_fail_with("list_to_json should return []")
    }),
    it("show returns the id from the path", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/users/42")

      // Act
      let response = route_show_user(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("User 42")
      |> or_fail_with("show should return 'User 42'")
    }),
    it("show returns status 400 for an id that is not a number", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/users/abc")

      // Act
      let response = route_show_user(request)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(400)
      |> or_fail_with("show should return 400")
    }),
  ])
}

fn concepts_tests() -> UnitNode {
  group("concepts", [
    it("an Action can be called with a request, context and services", fn() {
      // Arrange
      let action: concepts_signatures.Action = concepts_signatures.say_hello
      let request = test_request.create_request(Get, "/")

      // Act
      let response = action(request, AppContext("request-1"), EmptyServices)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Hello!")
      |> or_fail_with("the action should say Hello!")
    }),
    it("a Middleware calls next and changes the response", fn() {
      // Arrange
      let middleware: concepts_signatures.Middleware =
        concepts_signatures.add_server_header
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        middleware(
          request,
          AppContext("request-1"),
          EmptyServices,
          concepts_signatures.say_hello,
        )

      // Assert
      get_header(response.headers, "Server")
      |> should()
      |> be_equal(Some("Dream"))
      |> or_fail_with("the middleware should add the Server header")
    }),
    it("greet_world returns Hello, World!", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        concepts_hello_controller.greet_world(
          request,
          EmptyContext,
          EmptyServices,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Hello, World!")
      |> or_fail_with("greet_world should return 'Hello, World!'")
    }),
    it("greet_person greets the name from the path", fn() {
      // Arrange
      let hello_router =
        router()
        |> route(
          method: Get,
          path: "/hello/:name",
          controller: concepts_hello_controller.greet_person,
          middleware: [],
        )
      let request = test_request.create_request(Get, "/hello/Ada")

      // Act
      let response =
        dream.route_request(hello_router, request, EmptyContext, EmptyServices)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Hello, Ada!")
      |> or_fail_with("greet_person should return 'Hello, Ada!'")
    }),
    it("GET / is public", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response = route_concepts_request(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Welcome")
      |> or_fail_with("GET / should return 'Welcome'")
    }),
    it("POST /admin without a header returns status 401", fn() {
      // Arrange
      let request = test_request.create_request(Post, "/admin")

      // Act
      let response = route_concepts_request(request)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(401)
      |> or_fail_with("POST /admin with no header should return 401")
    }),
    it("POST /admin as a member returns status 403", fn() {
      // Arrange
      let request = add_authorization(Post, "/admin", "Bearer bo-token")

      // Act
      let response = route_concepts_request(request)

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(403)
      |> or_fail_with("POST /admin as a member should return 403")
    }),
    it("POST /admin as an admin reaches the controller", fn() {
      // Arrange
      let request = add_authorization(Post, "/admin", "Bearer ada-token")

      // Act
      let response = route_concepts_request(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Admin area")
      |> or_fail_with("POST /admin as an admin should return 'Admin area'")
    }),
    it("logging_middleware returns the response from next", fn() {
      // Arrange
      let request = test_request.create_request(Get, "/")

      // Act
      let response =
        concepts_middleware.logging_middleware(
          request,
          EmptyContext,
          EmptyServices,
          concepts_hello_controller.greet_world,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("Hello, World!")
      |> or_fail_with("logging_middleware should not change the body")
    }),
    it("respond with the json format returns JSON", fn() {
      // Arrange
      let param = create_format_param(Some("json"))

      // Act
      let response = concepts_user_view.respond(create_concepts_user(), param)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal(
        "{\"id\":1,\"email\":\"ada@example.com\",\"name\":\"Ada <3\"}",
      )
      |> or_fail_with("respond should return JSON")
    }),
    it("respond with the csv format returns CSV", fn() {
      // Arrange
      let param = create_format_param(Some("csv"))

      // Act
      let response = concepts_user_view.respond(create_concepts_user(), param)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("id,email,name\n1,\"ada@example.com\",\"Ada <3\"\n")
      |> or_fail_with("respond should return CSV")
    }),
    it("respond with no format returns escaped HTML", fn() {
      // Arrange
      let param = create_format_param(None)

      // Act
      let response = concepts_user_view.respond(create_concepts_user(), param)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("<p>Ada &lt;3 (ada@example.com)</p>")
      |> or_fail_with("respond should return escaped HTML")
    }),
    it("create_note with a valid body returns status 201", fn() {
      // Arrange
      let notes = process.new_subject()
      let request = create_note_request("{\"title\":\"Buy milk\"}")

      // Act
      let response =
        concepts_validation.create_note(
          request,
          EmptyContext,
          concepts_validation.Services(notes: notes),
        )

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(201)
      |> or_fail_with("a valid note should return 201")
    }),
    it("create_note with a valid body sends the note on", fn() {
      // Arrange
      let notes = process.new_subject()
      let request = create_note_request("{\"title\":\"Buy milk\"}")
      let _response =
        concepts_validation.create_note(
          request,
          EmptyContext,
          concepts_validation.Services(notes: notes),
        )

      // Act
      let received = process.receive(notes, 0)

      // Assert
      received
      |> should()
      |> be_equal(Ok(concepts_validation.Note(title: "Buy milk")))
      |> or_fail_with("the note should reach the notes subject")
    }),
    it("create_note with no title returns status 400", fn() {
      // Arrange
      let notes = process.new_subject()
      let request = create_note_request("{}")

      // Act
      let response =
        concepts_validation.create_note(
          request,
          EmptyContext,
          concepts_validation.Services(notes: notes),
        )

      // Assert
      response
      |> should()
      |> extract_response_status()
      |> be_equal(400)
      |> or_fail_with("a note with no title should return 400")
    }),
    it("create_note with no title says why in JSON", fn() {
      // Arrange
      let notes = process.new_subject()
      let request = create_note_request("{}")

      // Act
      let response =
        concepts_validation.create_note(
          request,
          EmptyContext,
          concepts_validation.Services(notes: notes),
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal(
        "{\"errors\":[\"Expected Field but found Nothing at title\"]}",
      )
      |> or_fail_with("the body should give the validation error")
    }),
  ])
}

// Helpers -------------------------------------------------------------------

fn create_lesson_user(id: Int, name: String, email: String) {
  User(
    id: id,
    name: name,
    email: email,
    created_at: timestamp.from_unix_seconds(0),
  )
}

fn route_show_user(request: Request) -> Response {
  let users_router =
    router()
    |> route(
      method: Get,
      path: "/users/:id",
      controller: learn_building_api_show_user.show,
      middleware: [],
    )
  dream.route_request(users_router, request, EmptyContext, EmptyServices)
}

fn add_authorization(
  method: request.Method,
  path: String,
  value: String,
) -> Request {
  Request(..test_request.create_request(method, path), headers: [
    Header("Authorization", value),
  ])
}

fn route_concepts_request(request: Request) -> Response {
  dream.route_request(
    concepts_middleware.create_router(),
    request,
    AuthContext(request_id: "request-1", user: None),
    EmptyServices,
  )
}

fn create_concepts_user() -> concepts_user_view.User {
  concepts_user_view.User(id: 1, email: "ada@example.com", name: "Ada <3")
}

fn create_format_param(format: option.Option(String)) -> request.PathParam {
  PathParam(
    raw: "1",
    value: "1",
    format: format,
    as_int: Ok(1),
    as_float: Error(Nil),
  )
}

fn create_note_request(body: String) -> Request {
  test_request.create_request_with_body(Post, "/notes", body)
}
