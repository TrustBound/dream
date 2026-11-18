//// Tests for the snippets shown in the doc comments of the `dream/http`
//// modules. Each snippet is in test/snippets/doc_http_*.gleam.

import dream/dream
import dream/http/error
import dream/http/header.{Header}
import dream/http/request.{
  type Request, Delete, Get, Http2, Https, Post, Request,
}
import dream/http/response.{type Response, Bytes, Stream, Text}
import dream_test/assertions/should.{equal, or_fail_with, should}
import dream_test/unit.{type UnitTest, describe, it}
import fixtures/request as test_request
import gleam/bit_array
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/yielder
import matchers/extract_body_text.{extract_body_text}
import snippets/doc_http_add_header
import snippets/doc_http_binary_response
import snippets/doc_http_empty_response
import snippets/doc_http_get_header
import snippets/doc_http_header_module
import snippets/doc_http_header_name
import snippets/doc_http_header_type
import snippets/doc_http_header_value
import snippets/doc_http_html_response
import snippets/doc_http_json_response
import snippets/doc_http_redirect_response
import snippets/doc_http_remove_header
import snippets/doc_http_request
import snippets/doc_http_request_body
import snippets/doc_http_request_methods
import snippets/doc_http_request_module
import snippets/doc_http_response_body
import snippets/doc_http_response_module
import snippets/doc_http_response_type
import snippets/doc_http_separate_imports
import snippets/doc_http_set_header
import snippets/doc_http_single_import
import snippets/doc_http_status_module
import snippets/doc_http_stream_response
import snippets/doc_http_submodule_imports
import snippets/doc_http_text_response

pub fn tests() -> UnitTest {
  describe("doc comment snippets for dream/http", [
    http_module_tests(),
    request_module_tests(),
    response_module_tests(),
    header_module_tests(),
    status_module_tests(),
  ])
}

fn user_request(id: String) -> Request {
  test_request.create_request_with_params(Get, "/users/" <> id, [#("id", id)])
}

fn http_module_tests() -> UnitTest {
  describe("dream/http", [
    it("separate imports show returns the user as JSON", fn() {
      // Arrange
      let request = user_request("7")

      // Act
      let response = doc_http_separate_imports.show(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("{\"id\":7}")
      |> or_fail_with("show should return {\"id\":7}")
    }),
    it("single import show returns the user as JSON", fn() {
      // Arrange
      let request = user_request("7")

      // Act
      let response = doc_http_single_import.show(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("{\"id\":7}")
      |> or_fail_with("show should return {\"id\":7}")
    }),
    it("single import show returns 400 for a bad id", fn() {
      // Arrange
      let request = user_request("seven")

      // Act
      let response = doc_http_single_import.show(request, Nil, Nil)

      // Assert
      response.status
      |> should()
      |> equal(400)
      |> or_fail_with("show should return 400 for a bad id")
    }),
    it("submodule imports map NotFound to 404", fn() {
      // Arrange
      let http_error = error.NotFound("User not found")

      // Act
      let status = doc_http_submodule_imports.error_status(http_error)

      // Assert
      status
      |> should()
      |> equal(404)
      |> or_fail_with("NotFound should map to 404")
    }),
  ])
}

fn request_module_tests() -> UnitTest {
  describe("dream/http/request", [
    it("module example returns the user as JSON", fn() {
      // Arrange
      let request = user_request("1")
      let services =
        doc_http_request_module.Services(find_user: fn(_id) { Ok("Alice") })

      // Act
      let response = doc_http_request_module.show_user(request, Nil, services)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("{\"name\":\"Alice\"}")
      |> or_fail_with("show_user should return Alice as JSON")
    }),
    it("method example routes DELETE /users/:id", fn() {
      // Arrange
      let request = test_request.create_request(Delete, "/users/3")

      // Act
      let response =
        dream.route_request(
          doc_http_request_methods.user_router(),
          request,
          Nil,
          Nil,
        )

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Delete user")
      |> or_fail_with("DELETE /users/3 should reach delete_user")
    }),
    it("protocol example describes HTTPS", fn() {
      // Arrange
      let request =
        Request(..test_request.create_request(Get, "/"), protocol: Https)

      // Act
      let description = doc_http_request.describe_protocol(request)

      // Assert
      description
      |> should()
      |> equal("Secure connection")
      |> or_fail_with("Https should be a secure connection")
    }),
    it("version example describes HTTP/2", fn() {
      // Arrange
      let request =
        Request(..test_request.create_request(Get, "/"), version: Http2)

      // Act
      let description = doc_http_request.describe_version(request)

      // Assert
      description
      |> should()
      |> equal("HTTP/2")
      |> or_fail_with("Http2 should be HTTP/2")
    }),
    it("request example reads method, path, id and body", fn() {
      // Arrange
      let request =
        Request(
          ..test_request.create_request(Post, "/users/123"),
          params: [#("id", "123")],
          body: request.Text("hello"),
        )

      // Act
      let response = doc_http_request.show_user(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("POST /users/123 123 hello")
      |> or_fail_with("show_user should describe the request")
    }),
    it("request example answers 400 for a body that is not text", fn() {
      // Arrange
      let request =
        Request(
          ..test_request.create_request(Post, "/users/123"),
          params: [#("id", "123")],
          body: request.Bytes(<<0xFF, 0xD8>>),
        )

      // Act
      let response = doc_http_request.show_user(request, Nil, Nil)

      // Assert
      #(response.status, response.body)
      |> should()
      |> equal(#(400, Text("Request body is not text")))
      |> or_fail_with("show_user should reject a binary body")
    }),
    it("body_as_string example returns the streamed body", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(Post, "/", [
          "hello ",
          "world",
        ])

      // Act
      let response = doc_http_request.show_body(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("hello world")
      |> or_fail_with("show_body should return the whole body")
    }),
    it("RequestBody example measures a Text body in bytes", fn() {
      // Arrange
      let request = test_request.create_request_with_body(Post, "/", "héllo")

      // Act
      let size = doc_http_request_body.body_size(request)

      // Assert
      size
      |> should()
      |> equal(6)
      |> or_fail_with("body_size should count the UTF-8 bytes of the text")
    }),
    it("RequestBody example measures a Bytes body", fn() {
      // Arrange
      let request =
        test_request.create_request_with_bytes(Post, "/", <<0xFF, 0xD8, 0xFF>>)

      // Act
      let size = doc_http_request_body.body_size(request)

      // Assert
      size
      |> should()
      |> equal(3)
      |> or_fail_with("body_size should count the bytes")
    }),
    it("RequestBody example adds up the chunks of a Stream body", fn() {
      // Arrange
      let request =
        test_request.create_streaming_request_from_strings(Post, "/", [
          "hello ",
          "world",
        ])

      // Act
      let size = doc_http_request_body.body_size(request)

      // Assert
      size
      |> should()
      |> equal(11)
      |> or_fail_with("body_size should add up the chunk sizes")
    }),
    it("get_param example reads value and as_int", fn() {
      // Arrange
      let request = user_request("123")

      // Act
      let parts = doc_http_request.read_user_id(request)

      // Assert
      parts
      |> should()
      |> equal(Ok(#("123", Ok(123))))
      |> or_fail_with("read_user_id should return #(\"123\", Ok(123))")
    }),
    it("get_param example reads the format", fn() {
      // Arrange
      let request = user_request("123.json")

      // Act
      let parts = doc_http_request.read_user_id_with_format(request)

      // Assert
      parts
      |> should()
      |> equal(Ok(#("123", Some("json"), Ok(123))))
      |> or_fail_with("read_user_id_with_format should find the json format")
    }),
    it("get_int_param example shows the user", fn() {
      // Arrange
      let request = user_request("123")

      // Act
      let response = doc_http_request.show_user_by_id(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("User 123")
      |> or_fail_with("show_user_by_id should return User 123")
    }),
    it("get_int_param example returns a JSON error for a bad id", fn() {
      // Arrange
      let request = user_request("abc")

      // Act
      let response = doc_http_request.show_user_by_id(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("{\"error\":\"id must be an integer\"}")
      |> or_fail_with("show_user_by_id should return the error as JSON")
    }),
    it("get_string_param example shows the user", fn() {
      // Arrange
      let request =
        test_request.create_request_with_params(Get, "/users/john", [
          #("name", "john"),
        ])

      // Act
      let response = doc_http_request.show_user_by_name(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("User john")
      |> or_fail_with("show_user_by_name should return User john")
    }),
  ])
}

fn stream_bytes(response: Response) -> BitArray {
  case response.body {
    Stream(stream) -> yielder.fold(stream, <<>>, bit_array.append)
    Text(text) -> bit_array.from_string(text)
    Bytes(bytes) -> bytes
  }
}

fn response_module_tests() -> UnitTest {
  describe("dream/http/response", [
    it("module example builds a text response", fn() {
      // Act
      let response = doc_http_response_module.greeting()

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Hello, World!")
      |> or_fail_with("greeting should return Hello, World!")
    }),
    it("module example builds a JSON response", fn() {
      // Arrange
      let user_json = json.object([#("id", json.int(1))])

      // Act
      let response = doc_http_response_module.user(user_json)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("{\"id\":1}")
      |> or_fail_with("user should return the JSON")
    }),
    it("module example builds an HTML response", fn() {
      // Act
      let response = doc_http_response_module.welcome_page()

      // Assert
      response.content_type
      |> should()
      |> equal(Some("text/html; charset=utf-8"))
      |> or_fail_with("welcome_page should be HTML")
    }),
    it("module example builds a redirect", fn() {
      // Act
      let response = doc_http_response_module.login_redirect()

      // Assert
      #(response.status, response.headers)
      |> should()
      |> equal(#(303, [Header("Location", "/login")]))
      |> or_fail_with("login_redirect should be a 303 to /login")
    }),
    it("response body example lists text and bytes bodies", fn() {
      // Arrange
      let data = json.object([#("id", json.int(1))])
      let file_chunks = yielder.from_list([<<"chunk":utf8>>])

      // Act
      let bodies =
        doc_http_response_body.response_bodies(data, <<1, 2, 3>>, file_chunks)

      // Assert
      list.take(bodies, 3)
      |> should()
      |> equal([Text("Hello, World!"), Text("{\"id\":1}"), Bytes(<<1, 2, 3>>)])
      |> or_fail_with("response_bodies should list the text and bytes bodies")
    }),
    it("response type example: builder and direct construction match", fn() {
      // Arrange
      let user_json = "{\"id\":1}"

      // Act
      let built = doc_http_response_type.with_builder(user_json)

      // Assert
      built
      |> should()
      |> equal(doc_http_response_type.by_hand(user_json))
      |> or_fail_with("with_builder and by_hand should build the same response")
    }),
    it("text_response example returns OK", fn() {
      // Act
      let response = doc_http_text_response.healthcheck(Nil, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("OK")
      |> or_fail_with("healthcheck should return OK")
    }),
    it("json_response example returns the user", fn() {
      // Act
      let response = doc_http_json_response.show_user(Nil, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("{\"id\":123,\"name\":\"Alice\"}")
      |> or_fail_with("show_user should return Alice as JSON")
    }),
    it("html_response example returns the page", fn() {
      // Act
      let response = doc_http_html_response.index(Nil, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal(
        "\n    <!DOCTYPE html>\n    <html>\n      <body><h1>Welcome</h1></body>\n    </html>\n  ",
      )
      |> or_fail_with("index should return the HTML page")
    }),
    it("redirect_response example redirects to the post", fn() {
      // Act
      let response = doc_http_redirect_response.create_post(Nil, Nil, Nil)

      // Assert
      #(response.status, response.headers)
      |> should()
      |> equal(#(303, [Header("Location", "/posts/123")]))
      |> or_fail_with("create_post should be a 303 to /posts/123")
    }),
    it("empty_response example returns 204", fn() {
      // Arrange
      let request = user_request("5")
      let services =
        doc_http_empty_response.Services(delete_user: fn(_user_id) { Nil })

      // Act
      let response = doc_http_empty_response.delete_user(request, Nil, services)

      // Assert
      #(response.status, response.body)
      |> should()
      |> equal(#(204, Text("")))
      |> or_fail_with("delete_user should return 204 with no body")
    }),
    it("binary_response example returns 404 when logo.png is missing", fn() {
      // Act
      let response = doc_http_binary_response.serve_image(Nil, Nil, Nil)

      // Assert
      response.status
      |> should()
      |> equal(404)
      |> or_fail_with("serve_image should return 404 without logo.png")
    }),
    it("stream_response example streams one CSV row for each user", fn() {
      // Arrange
      let services =
        doc_http_stream_response.Services(user_names: ["Alice", "Bob"])

      // Act
      let response = doc_http_stream_response.export_users(Nil, Nil, services)

      // Assert
      stream_bytes(response)
      |> should()
      |> equal(<<"Alice\nBob\n":utf8>>)
      |> or_fail_with("export_users should stream Alice and Bob")
    }),
  ])
}

fn header_module_tests() -> UnitTest {
  describe("dream/http/header", [
    it("module example gets, sets and adds headers", fn() {
      // Act
      let result = doc_http_header_module.use_headers()

      // Assert
      result
      |> should()
      |> equal(
        #(Some("application/json"), [
          Header("Set-Cookie", "session=abc"),
          Header("X-Custom", "value"),
          Header("Content-Type", "application/json"),
          Header("Cache-Control", "max-age=3600"),
        ]),
      )
      |> or_fail_with("use_headers should return the expected headers")
    }),
    it("Header example builds three headers", fn() {
      // Act
      let headers = doc_http_header_type.response_headers()

      // Assert
      headers
      |> should()
      |> equal([
        Header("Content-Type", "application/json"),
        Header("Cache-Control", "no-cache"),
        Header("X-Request-ID", "abc-123"),
      ])
      |> or_fail_with("response_headers should return three headers")
    }),
    it("header_name example returns Content-Type", fn() {
      // Act
      let name = doc_http_header_name.content_type_name()

      // Assert
      name
      |> should()
      |> equal("Content-Type")
      |> or_fail_with("content_type_name should return Content-Type")
    }),
    it("header_value example returns application/json", fn() {
      // Act
      let value = doc_http_header_value.content_type_value()

      // Assert
      value
      |> should()
      |> equal("application/json")
      |> or_fail_with("content_type_value should return application/json")
    }),
    it("get_header example ignores case and finds no missing header", fn() {
      // Act
      let values = doc_http_get_header.look_up_headers()

      // Assert
      values
      |> should()
      |> equal(#(Some("application/json"), Some("max-age=3600"), None))
      |> or_fail_with("look_up_headers should return the expected values")
    }),
    it("set_header example replaces and adds headers", fn() {
      // Act
      let headers = doc_http_set_header.replace_and_add()

      // Assert
      headers
      |> should()
      |> equal([
        Header("Cache-Control", "max-age=3600"),
        Header("content-type", "application/json"),
      ])
      |> or_fail_with("replace_and_add should return the expected headers")
    }),
    it("add_header example keeps both Set-Cookie headers", fn() {
      // Act
      let headers = doc_http_add_header.add_cookies()

      // Assert
      headers
      |> should()
      |> equal([
        Header("Set-Cookie", "preferences=dark; Path=/"),
        Header("Set-Cookie", "session=abc; HttpOnly"),
      ])
      |> or_fail_with("add_cookies should return both Set-Cookie headers")
    }),
    it("remove_header example removes X-Debug", fn() {
      // Act
      let headers = doc_http_remove_header.remove_debug()

      // Assert
      headers
      |> should()
      |> equal([
        Header("Content-Type", "application/json"),
        Header("Cache-Control", "max-age=3600"),
      ])
      |> or_fail_with("remove_debug should remove X-Debug")
    }),
  ])
}

fn status_module_tests() -> UnitTest {
  describe("dream/http/status", [
    it("module example returns Hello, World!", fn() {
      // Act
      let response = doc_http_status_module.index(Nil, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> equal("Hello, World!")
      |> or_fail_with("index should return Hello, World!")
    }),
  ])
}
