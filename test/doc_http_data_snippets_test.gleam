//// Tests for the snippets shown in the doc comments of `dream/http/cookie`,
//// `error`, `params`, `transaction` and `validation`. Each snippet is in
//// test/snippets/doc_http_data_*.gleam.

import dream/http/cookie.{Cookie, Lax, Strict}
import dream/http/error.{
  BadRequest, Conflict, Forbidden, GatewayTimeout, InternalServerError,
  ServiceUnavailable, Unauthorized, UnprocessableContent,
}
import dream/http/request.{type Request, Get, Post, Request}
import dream/http/transaction.{Delete, Header, Http, Http1, Response, Text}
import dream/http/validation.{validate_json}
import dream_errors.{Unavailable}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{type UnitNode, describe, group, it}
import fixtures/request.{
  create_request, create_request_with_body, create_request_with_params,
} as _
import gleam/dynamic/decode.{string, subfield, success}
import gleam/json.{to_string}
import gleam/option.{None, Some}
import matchers/extract_body_text.{extract_body_text}
import snippets/doc_http_data_cookie_module.{new_cookies, session_status}
import snippets/doc_http_data_cookie_name.{session_cookie_name}
import snippets/doc_http_data_cookie_same_site
import snippets/doc_http_data_cookie_type.{builder_cookie, manual_cookie}
import snippets/doc_http_data_cookie_value.{session_cookie_value}
import snippets/doc_http_data_error_bad_request.{check_signup}
import snippets/doc_http_data_error_conflict.{check_email, check_version}
import snippets/doc_http_data_error_forbidden.{check_post_owner, require_admin}
import snippets/doc_http_data_error_gateway_timeout.{fetch_quote}
import snippets/doc_http_data_error_internal_server_error.{charge, load_users}
import snippets/doc_http_data_error_message.{bad_request_json}
import snippets/doc_http_data_error_module.{User, create_user, get_user}
import snippets/doc_http_data_error_not_found.{find_post, find_user}
import snippets/doc_http_data_error_response.{user_response}
import snippets/doc_http_data_error_service_unavailable.{load_rates}
import snippets/doc_http_data_error_unauthorized.{authenticate}
import snippets/doc_http_data_error_unprocessable_content.{check_dates}
import snippets/doc_http_data_field_optional.{task_description}
import snippets/doc_http_data_from_shared.{StoreDown, load_profile}
import snippets/doc_http_data_get_cookie.{example_cookies, session_value}
import snippets/doc_http_data_get_cookie_value
import snippets/doc_http_data_remove_cookie.{expired_session}
import snippets/doc_http_data_require_field_int.{task_priority}
import snippets/doc_http_data_require_form.{task_title}
import snippets/doc_http_data_require_int.{user_path}
import snippets/doc_http_data_require_json.{NewTask, read_task}
import snippets/doc_http_data_require_string.{greeting}
import snippets/doc_http_data_secure_cookie.{login_cookies}
import snippets/doc_http_data_set_cookie.{updated_cookies}
import snippets/doc_http_data_simple_cookie.{preference_cookies}
import snippets/doc_http_data_to_status_code.{not_found_response}
import snippets/doc_http_data_transaction_add_header.{set_cookie_headers}
import snippets/doc_http_data_transaction_cookie_name.{theme_cookie_name}
import snippets/doc_http_data_transaction_cookie_value.{theme_cookie_value}
import snippets/doc_http_data_transaction_format.{describe_id}
import snippets/doc_http_data_transaction_get_cookie.{session}
import snippets/doc_http_data_transaction_get_cookie_value.{theme}
import snippets/doc_http_data_transaction_get_header
import snippets/doc_http_data_transaction_get_query_param.{search_term}
import snippets/doc_http_data_transaction_has_content_type.{is_json}
import snippets/doc_http_data_transaction_header_name.{content_type_name}
import snippets/doc_http_data_transaction_header_value.{content_type_value}
import snippets/doc_http_data_transaction_is_method.{is_post}
import snippets/doc_http_data_transaction_method_to_string.{post_name}
import snippets/doc_http_data_transaction_params.{
  read_id, read_id_with_format, show, show_by_id, show_by_name,
}
import snippets/doc_http_data_transaction_parse_method.{delete_method}
import snippets/doc_http_data_transaction_path.{show_user}
import snippets/doc_http_data_transaction_remove_cookie
import snippets/doc_http_data_transaction_remove_header.{public_headers}
import snippets/doc_http_data_transaction_secure_cookie
import snippets/doc_http_data_transaction_set_cookie.{dark_theme}
import snippets/doc_http_data_transaction_set_header.{cache_headers}
import snippets/doc_http_data_transaction_set_params.{with_user_id}
import snippets/doc_http_data_transaction_simple_cookie
import snippets/doc_http_data_validate_json.{create_post}
import snippets/doc_http_data_validation_error.{email_error}
import snippets/doc_http_data_validation_module.{create}

pub fn tests() -> TestSuite {
  describe("doc comment snippets for dream/http data modules", [
    cookie_tests(),
    error_tests(),
    params_tests(),
    transaction_tests(),
    validation_tests(),
  ])
}

fn params_request(params: List(#(String, String))) -> Request {
  create_request_with_params(Get, "/", params)
}

fn form_request(body: String) -> Request {
  create_request_with_body(Post, "/tasks", body)
}

fn json_request(body: String) -> Request {
  create_request_with_body(Post, "/", body)
}

fn transaction_request(params: List(#(String, String))) -> transaction.Request {
  transaction.Request(
    method: transaction.Get,
    protocol: Http,
    version: Http1,
    path: "/users",
    query: "",
    params: params,
    host: None,
    port: None,
    remote_address: None,
    body: request.Text(""),
    headers: [],
    cookies: [],
    content_type: None,
    content_length: None,
  )
}

fn cookie_tests() -> UnitNode {
  group("dream/http/cookie", [
    it("module example builds a simple and a secure cookie", fn() {
      // Act
      let cookies = new_cookies()

      // Assert
      cookies
      |> should()
      |> be_equal([
        cookie.simple_cookie("theme", "dark"),
        cookie.secure_cookie("session_id", "abc123"),
      ])
      |> or_fail_with("new_cookies should hold theme and session_id")
    }),
    it("module example reads the session cookie from the request", fn() {
      // Arrange
      let request =
        Request(..create_request(Get, "/"), cookies: [
          cookie.secure_cookie("session_id", "abc123"),
        ])

      // Act
      let status = session_status(request)

      // Assert
      status
      |> should()
      |> be_equal("Session abc123")
      |> or_fail_with("session_status should read abc123")
    }),
    it("module example reports a missing session cookie", fn() {
      // Arrange
      let request = create_request(Get, "/")

      // Act
      let status = session_status(request)

      // Assert
      status
      |> should()
      |> be_equal("No session cookie")
      |> or_fail_with("session_status should report no cookie")
    }),
    it("SameSite example sets Lax", fn() {
      // Act
      let session_cookie = doc_http_data_cookie_same_site.session_cookie()

      // Assert
      session_cookie
      |> should()
      |> be_equal(
        Cookie(
          ..cookie.secure_cookie("session", "abc123"),
          same_site: Some(Lax),
        ),
      )
      |> or_fail_with("session_cookie should be secure with Lax")
    }),
    it("Cookie example builder makes a secure cookie", fn() {
      // Act
      let auth_cookie = builder_cookie()

      // Assert
      auth_cookie
      |> should()
      |> be_equal(cookie.secure_cookie("auth_token", "xyz789"))
      |> or_fail_with("builder_cookie should be a secure cookie")
    }),
    it("Cookie example constructor sets a one hour max age", fn() {
      // Act
      let auth_cookie = manual_cookie()

      // Assert
      auth_cookie
      |> should()
      |> be_equal(
        Cookie(
          ..cookie.secure_cookie("auth_token", "xyz789"),
          max_age: Some(3600),
          path: Some("/"),
        ),
      )
      |> or_fail_with(
        "manual_cookie should be secure with max_age 3600 and path /",
      )
    }),
    it("cookie_name example returns the name", fn() {
      // Act
      let name = session_cookie_name()

      // Assert
      name
      |> should()
      |> be_equal("session_id")
      |> or_fail_with("cookie_name should return session_id")
    }),
    it("cookie_value example returns the value", fn() {
      // Act
      let value = session_cookie_value()

      // Assert
      value
      |> should()
      |> be_equal("abc123")
      |> or_fail_with("cookie_value should return abc123")
    }),
    it("simple_cookie example builds preference cookies", fn() {
      // Act
      let cookies = preference_cookies()

      // Assert
      cookies
      |> should()
      |> be_equal([
        Cookie("theme", "dark", None, None, None, None, False, False, None),
        Cookie("lang", "en", None, None, None, None, False, False, None),
      ])
      |> or_fail_with("preference_cookies should be two plain cookies")
    }),
    it("secure_cookie example builds secure cookies", fn() {
      // Act
      let cookies = login_cookies("s-1", "jwt-1", "csrf-1")

      // Assert
      cookies
      |> should()
      |> be_equal([
        Cookie(
          "session_id",
          "s-1",
          None,
          None,
          None,
          None,
          True,
          True,
          Some(Strict),
        ),
        Cookie(
          "auth_token",
          "jwt-1",
          None,
          None,
          None,
          None,
          True,
          True,
          Some(Strict),
        ),
        Cookie(
          "csrf_token",
          "csrf-1",
          None,
          None,
          None,
          None,
          True,
          True,
          Some(Strict),
        ),
      ])
      |> or_fail_with("login_cookies should be three secure cookies")
    }),
    it("get_cookie example finds the session value", fn() {
      // Arrange
      let cookies = example_cookies()

      // Act
      let value = session_value(cookies)

      // Assert
      value
      |> should()
      |> be_equal("abc123")
      |> or_fail_with("session_value should be abc123")
    }),
    it("get_cookie example returns no session for an empty list", fn() {
      // Arrange
      let cookies = []

      // Act
      let value = session_value(cookies)

      // Assert
      value
      |> should()
      |> be_equal("no session")
      |> or_fail_with("session_value should be no session")
    }),
    it("get_cookie example ignores case", fn() {
      // Arrange
      let cookies = example_cookies()

      // Act
      let found = doc_http_data_get_cookie.theme_cookie(cookies)

      // Assert
      found
      |> should()
      |> be_equal(Some(cookie.simple_cookie("theme", "dark")))
      |> or_fail_with("THEME should find the theme cookie")
    }),
    it("get_cookie_value example finds theme and not missing", fn() {
      // Act
      let lookups = doc_http_data_get_cookie_value.lookups()

      // Assert
      lookups
      |> should()
      |> be_equal(#(Some("dark"), None))
      |> or_fail_with("lookups should be Some(dark) and None")
    }),
    it("set_cookie example replaces and adds", fn() {
      // Act
      let cookies = updated_cookies()

      // Assert
      cookies
      |> should()
      |> be_equal([
        cookie.secure_cookie("session_id", "abc123"),
        cookie.simple_cookie("theme", "dark"),
      ])
      |> or_fail_with("updated_cookies should be session_id then theme")
    }),
    it("remove_cookie example removes theme", fn() {
      // Act
      let cookies = doc_http_data_remove_cookie.without_theme()

      // Assert
      cookies
      |> should()
      |> be_equal([cookie.secure_cookie("session_id", "abc123")])
      |> or_fail_with("without_theme should keep session_id only")
    }),
    it("remove_cookie example expires the session cookie", fn() {
      // Act
      let expired = expired_session()

      // Assert
      expired
      |> should()
      |> be_equal(
        Cookie(..cookie.secure_cookie("session_id", ""), max_age: Some(0)),
      )
      |> or_fail_with("expired_session should have max_age 0")
    }),
  ])
}

fn error_tests() -> UnitNode {
  group("dream/http/error", [
    it("module example finds a user", fn() {
      // Arrange
      let users = [User(1, "Alice")]

      // Act
      let result = get_user(users, 1)

      // Assert
      result
      |> should()
      |> be_equal(Ok(User(1, "Alice")))
      |> or_fail_with("get_user should find Alice")
    }),
    it("module example returns NotFound", fn() {
      // Arrange
      let users = []

      // Act
      let result = get_user(users, 1)

      // Assert
      result
      |> should()
      |> be_equal(Error(error.NotFound("User not found")))
      |> or_fail_with("get_user should return NotFound")
    }),
    it("module example rejects an empty name", fn() {
      // Arrange
      let users = []

      // Act
      let result = create_user(users, "")

      // Assert
      result
      |> should()
      |> be_equal(Error(BadRequest("Name must not be empty")))
      |> or_fail_with("create_user should reject an empty name")
    }),
    it("module example creates a user", fn() {
      // Arrange
      let users = [User(1, "Alice")]

      // Act
      let result = create_user(users, "Bob")

      // Assert
      result
      |> should()
      |> be_equal(Ok(User(2, "Bob")))
      |> or_fail_with("create_user should create Bob with id 2")
    }),
    it("response example sends the user", fn() {
      // Arrange
      let result = Ok("Alice")

      // Act
      let response = user_response(result)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("{\"name\":\"Alice\"}")
      |> or_fail_with("user_response should send Alice")
    }),
    it("response example maps the error status", fn() {
      // Arrange
      let result = Error(error.NotFound("User not found"))

      // Act
      let response = user_response(result)

      // Assert
      response.status
      |> should()
      |> be_equal(404)
      |> or_fail_with("user_response should return 404")
    }),
    it("response example sends the error message", fn() {
      // Arrange
      let result = Error(error.NotFound("User not found"))

      // Act
      let response = user_response(result)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("{\"error\":\"User not found\"}")
      |> or_fail_with("user_response should send the message")
    }),
    it("BadRequest example requires an email", fn() {
      // Act
      let result = check_signup("", 1)

      // Assert
      result
      |> should()
      |> be_equal(Error(BadRequest("Field 'email' is required")))
      |> or_fail_with("check_signup should require an email")
    }),
    it("BadRequest example requires a positive id", fn() {
      // Act
      let result = check_signup("a@example.com", 0)

      // Assert
      result
      |> should()
      |> be_equal(Error(BadRequest("ID must be a positive integer")))
      |> or_fail_with("check_signup should require a positive id")
    }),
    it("Unauthorized example requires a token", fn() {
      // Act
      let result = authenticate("", ["t-1"])

      // Assert
      result
      |> should()
      |> be_equal(Error(Unauthorized("Authentication token required")))
      |> or_fail_with("authenticate should require a token")
    }),
    it("Unauthorized example rejects an unknown token", fn() {
      // Act
      let result = authenticate("t-2", ["t-1"])

      // Assert
      result
      |> should()
      |> be_equal(Error(Unauthorized("Invalid or expired token")))
      |> or_fail_with("authenticate should reject t-2")
    }),
    it("Forbidden example requires an admin", fn() {
      // Act
      let result = require_admin(False)

      // Assert
      result
      |> should()
      |> be_equal(Error(Forbidden("Admin access required")))
      |> or_fail_with("require_admin should refuse a non-admin")
    }),
    it("Forbidden example protects another user's post", fn() {
      // Act
      let result = check_post_owner(1, 2)

      // Assert
      result
      |> should()
      |> be_equal(Error(Forbidden("Cannot delete another user's post")))
      |> or_fail_with("check_post_owner should refuse user 1")
    }),
    it("NotFound example reports a missing user", fn() {
      // Act
      let result = find_user([], 7)

      // Assert
      result
      |> should()
      |> be_equal(Error(error.NotFound("User not found")))
      |> or_fail_with("find_user should return NotFound")
    }),
    it("NotFound example names the missing post", fn() {
      // Act
      let result = find_post([], 123)

      // Assert
      result
      |> should()
      |> be_equal(Error(error.NotFound("Post with ID 123 does not exist")))
      |> or_fail_with("find_post should name post 123")
    }),
    it("Conflict example rejects a taken email", fn() {
      // Act
      let result =
        check_email("a@example.com", [
          "a@example.com",
        ])

      // Assert
      result
      |> should()
      |> be_equal(Error(Conflict("Email already registered")))
      |> or_fail_with("check_email should reject a taken email")
    }),
    it("Conflict example rejects a stale version", fn() {
      // Act
      let result = check_version(3, 4)

      // Assert
      result
      |> should()
      |> be_equal(Error(Conflict("The post changed after you loaded it")))
      |> or_fail_with("check_version should reject version 3 against 4")
    }),
    it("UnprocessableContent example rejects reversed dates", fn() {
      // Act
      let result = check_dates(5, 1)

      // Assert
      result
      |> should()
      |> be_equal(
        Error(UnprocessableContent("Start date must be before end date")),
      )
      |> or_fail_with("check_dates should reject 5 to 1")
    }),
    it("InternalServerError example wraps a database failure", fn() {
      // Act
      let result = load_users(Error(Nil))

      // Assert
      result
      |> should()
      |> be_equal(Error(InternalServerError("Database connection failed")))
      |> or_fail_with("load_users should return InternalServerError")
    }),
    it("InternalServerError example wraps a payment failure", fn() {
      // Act
      let result = charge(Error(Nil))

      // Assert
      result
      |> should()
      |> be_equal(
        Error(InternalServerError("External payment API unavailable")),
      )
      |> or_fail_with("charge should return InternalServerError")
    }),
    it("ServiceUnavailable example answers a down rate service", fn() {
      // Act
      let result = load_rates(Error(Nil))

      // Assert
      result
      |> should()
      |> be_equal(Error(ServiceUnavailable("Rate service is down")))
      |> or_fail_with("load_rates should return ServiceUnavailable")
    }),
    it("GatewayTimeout example answers a slow quote service", fn() {
      // Act
      let result = fetch_quote(Error(Nil))

      // Assert
      result
      |> should()
      |> be_equal(Error(GatewayTimeout("Quote service did not answer")))
      |> or_fail_with("fetch_quote should return GatewayTimeout")
    }),
    it("from_shared example gives a missing profile its own text", fn() {
      // Act
      let result =
        load_profile(Error(dream_errors.NotFound("profiles.get found no row")))

      // Assert
      result
      |> should()
      |> be_equal(Error(error.NotFound("Profile not found")))
      |> or_fail_with("load_profile should return its own NotFound text")
    }),
    it("from_shared example hides the message of another error", fn() {
      // Act
      let result =
        load_profile(
          Error(Unavailable(
            "store at 10.0.0.5 refused the connection",
            StoreDown,
          )),
        )

      // Assert
      result
      |> should()
      |> be_equal(Error(ServiceUnavailable("Service unavailable")))
      |> or_fail_with("load_profile should return the generic 503")
    }),
    it("from_shared example keeps the profile", fn() {
      // Act
      let result = load_profile(Ok("Ann"))

      // Assert
      result
      |> should()
      |> be_equal(Ok("Ann"))
      |> or_fail_with("load_profile should return the profile")
    }),
    it("to_status_code example returns 404", fn() {
      // Act
      let response = not_found_response()

      // Assert
      response.status
      |> should()
      |> be_equal(404)
      |> or_fail_with("not_found_response should return 404")
    }),
    it("to_status_code example sends the message", fn() {
      // Act
      let response = not_found_response()

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("{\"error\":\"User not found\"}")
      |> or_fail_with("not_found_response should send the message")
    }),
    it("message example builds the error JSON", fn() {
      // Act
      let error_json = bad_request_json()

      // Assert
      to_string(error_json)
      |> should()
      |> be_equal("{\"error\":\"Invalid email format\",\"status\":400}")
      |> or_fail_with("bad_request_json should hold message and 400")
    }),
  ])
}

fn params_tests() -> UnitNode {
  group("dream/http/params", [
    it("require_int example builds the user path", fn() {
      // Arrange
      let request = params_request([#("id", "42")])

      // Act
      let result = user_path(request)

      // Assert
      result
      |> should()
      |> be_equal(Ok("/users/42"))
      |> or_fail_with("user_path should be /users/42")
    }),
    it("require_int example rejects a bad id", fn() {
      // Arrange
      let request = params_request([#("id", "abc")])

      // Act
      let result = user_path(request)

      // Assert
      result
      |> should()
      |> be_equal(Error(BadRequest("id must be an integer")))
      |> or_fail_with("user_path should reject abc")
    }),
    it("require_string example greets the user", fn() {
      // Arrange
      let request = params_request([#("name", "john")])

      // Act
      let result = greeting(request)

      // Assert
      result
      |> should()
      |> be_equal(Ok("Hello, john"))
      |> or_fail_with("greeting should greet john")
    }),
    it("require_string example reports a missing name", fn() {
      // Arrange
      let request = params_request([])

      // Act
      let result = greeting(request)

      // Assert
      result
      |> should()
      |> be_equal(Error(BadRequest("Missing required path parameter: name")))
      |> or_fail_with("greeting should report a missing name")
    }),
    it("require_form example reads the title", fn() {
      // Arrange
      let request = form_request("title=Buy+milk")

      // Act
      let result = task_title(request)

      // Assert
      result
      |> should()
      |> be_equal(Ok("Buy milk"))
      |> or_fail_with("task_title should be Buy milk")
    }),
    it("require_form example rejects an empty body", fn() {
      // Arrange
      let request = form_request("")

      // Act
      let result = task_title(request)

      // Assert
      result
      |> should()
      |> be_equal(Error(BadRequest("Request body is empty")))
      |> or_fail_with("task_title should reject an empty body")
    }),
    it("require_json example reads the task", fn() {
      // Arrange
      let request = json_request("{\"title\":\"Buy milk\",\"priority\":2}")

      // Act
      let result = read_task(request)

      // Assert
      result
      |> should()
      |> be_equal(Ok(NewTask(title: "Buy milk", priority: 2)))
      |> or_fail_with("read_task should decode the task")
    }),
    it("require_json example reports a field with the wrong type", fn() {
      // Arrange
      let request =
        json_request("{\"title\":\"Buy milk\",\"priority\":\"high\"}")

      // Act
      let result = read_task(request)

      // Assert
      result
      |> should()
      |> be_equal(
        Error(BadRequest("Expected Int but found String at priority")),
      )
      |> or_fail_with("read_task should report the priority field")
    }),
    it("require_field example reports a missing title", fn() {
      // Arrange
      let request = form_request("priority=1")

      // Act
      let result = task_title(request)

      // Assert
      result
      |> should()
      |> be_equal(Error(BadRequest("Missing required field: title")))
      |> or_fail_with("task_title should report a missing title")
    }),
    it("require_field_int example reads the priority", fn() {
      // Arrange
      let request = form_request("priority=3")

      // Act
      let result = task_priority(request)

      // Assert
      result
      |> should()
      |> be_equal(Ok(3))
      |> or_fail_with("task_priority should be 3")
    }),
    it("require_field_int example rejects a bad priority", fn() {
      // Arrange
      let request = form_request("priority=high")

      // Act
      let result = task_priority(request)

      // Assert
      result
      |> should()
      |> be_equal(Error(BadRequest("Field 'priority' must be an integer")))
      |> or_fail_with("task_priority should reject high")
    }),
    it("field_optional example reads the description", fn() {
      // Arrange
      let form = [#("description", "Weekly")]

      // Act
      let result = task_description(form)

      // Assert
      result
      |> should()
      |> be_equal(Some("Weekly"))
      |> or_fail_with("task_description should be Weekly")
    }),
    it("field_optional example treats empty as missing", fn() {
      // Arrange
      let form = [#("description", "")]

      // Act
      let result = task_description(form)

      // Assert
      result
      |> should()
      |> be_equal(None)
      |> or_fail_with("task_description should be None")
    }),
  ])
}

fn transaction_tests() -> UnitNode {
  group("dream/http/transaction", [
    it("path example sends the user", fn() {
      // Arrange
      let request = transaction_request([#("id", "123")])

      // Act
      let response = show_user(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("{\"id\":123}")
      |> or_fail_with("show_user should send id 123")
    }),
    it("path example rejects a bad id", fn() {
      // Arrange
      let request = transaction_request([#("id", "abc")])

      // Act
      let response = show_user(request, Nil, Nil)

      // Assert
      response.status
      |> should()
      |> be_equal(400)
      |> or_fail_with("show_user should return 400")
    }),
    it("format example reads the json extension", fn() {
      // Arrange
      let request = transaction_request([#("id", "123.json")])

      // Act
      let description = describe_id(request)

      // Assert
      description
      |> should()
      |> be_equal("123 as json")
      |> or_fail_with("describe_id should find json")
    }),
    it("format example reports a missing parameter", fn() {
      // Arrange
      let request = transaction_request([])

      // Act
      let description = describe_id(request)

      // Assert
      description
      |> should()
      |> be_equal("Error: Missing required path parameter: id")
      |> or_fail_with("describe_id should report the missing id")
    }),
    it("get_param example reads value and integer", fn() {
      // Arrange
      let request = transaction_request([#("id", "123")])

      // Act
      let result = read_id(request)

      // Assert
      result
      |> should()
      |> be_equal(Ok(#("123", Ok(123))))
      |> or_fail_with("read_id should be 123")
    }),
    it("get_param example reads the format", fn() {
      // Arrange
      let request = transaction_request([#("id", "123.json")])

      // Act
      let result = read_id_with_format(request)

      // Assert
      result
      |> should()
      |> be_equal(Ok(#("123", Some("json"), Ok(123))))
      |> or_fail_with("read_id_with_format should find json")
    }),
    it("get_param example uses get_int_param", fn() {
      // Arrange
      let request = transaction_request([#("id", "123")])

      // Act
      let response = show(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("{\"id\":123}")
      |> or_fail_with("show should send id 123")
    }),
    it("get_int_param example rejects a bad id", fn() {
      // Arrange
      let request = transaction_request([#("id", "abc")])

      // Act
      let response = show_by_id(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("{\"error\":\"id must be an integer\"}")
      |> or_fail_with("show_by_id should reject abc")
    }),
    it("get_string_param example sends the name", fn() {
      // Arrange
      let request = transaction_request([#("name", "john")])

      // Act
      let response = show_by_name(request)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("{\"name\":\"john\"}")
      |> or_fail_with("show_by_name should send john")
    }),
    it("set_header example sets both headers", fn() {
      // Arrange
      let response =
        Response(
          status: 200,
          body: Text(""),
          headers: [Header("Cache-Control", "no-cache")],
          cookies: [],
          content_type: None,
        )

      // Act
      let headers = cache_headers(response)

      // Assert
      headers
      |> should()
      |> be_equal([
        Header("X-Custom-Header", "value"),
        Header("Cache-Control", "max-age=3600"),
      ])
      |> or_fail_with(
        "cache_headers should replace Cache-Control and add X-Custom-Header",
      )
    }),
    it("transaction cookie_name example returns theme", fn() {
      // Act
      let name = theme_cookie_name()

      // Assert
      name
      |> should()
      |> be_equal("theme")
      |> or_fail_with("the cookie name should be theme")
    }),
    it("transaction cookie_value example returns dark", fn() {
      // Act
      let value = theme_cookie_value()

      // Assert
      value
      |> should()
      |> be_equal("dark")
      |> or_fail_with("the cookie value should be dark")
    }),
    it("transaction simple_cookie example has no security flags", fn() {
      // Act
      let cookie = doc_http_data_transaction_simple_cookie.theme_cookie()

      // Assert
      cookie
      |> should()
      |> be_equal(transaction.Cookie(
        name: "theme",
        value: "dark",
        expires: None,
        max_age: None,
        domain: None,
        path: None,
        secure: False,
        http_only: False,
        same_site: None,
      ))
      |> or_fail_with("the cookie should have no flags")
    }),
    it("transaction secure_cookie example is secure, httpOnly and Strict", fn() {
      // Act
      let cookie = doc_http_data_transaction_secure_cookie.session_cookie()

      // Assert
      cookie
      |> should()
      |> be_equal(transaction.Cookie(
        name: "session_id",
        value: "abc123",
        expires: None,
        max_age: None,
        domain: None,
        path: None,
        secure: True,
        http_only: True,
        same_site: Some(transaction.Strict),
      ))
      |> or_fail_with("the cookie should be secure")
    }),
    it("transaction header_name example returns Content-Type", fn() {
      // Act
      let name = content_type_name()

      // Assert
      name
      |> should()
      |> be_equal("Content-Type")
      |> or_fail_with("the header name should be Content-Type")
    }),
    it("transaction header_value example returns text/html", fn() {
      // Act
      let value = content_type_value()

      // Assert
      value
      |> should()
      |> be_equal("text/html")
      |> or_fail_with("the header value should be text/html")
    }),
    it("transaction get_header example ignores the case of the name", fn() {
      // Act
      let value = doc_http_data_transaction_get_header.content_type()

      // Assert
      value
      |> should()
      |> be_equal(Some("application/json"))
      |> or_fail_with("the content type should be found")
    }),
    it("transaction add_header example keeps both headers", fn() {
      // Act
      let headers = set_cookie_headers()

      // Assert
      headers
      |> should()
      |> be_equal([
        Header("Set-Cookie", "b=2"),
        Header("Set-Cookie", "a=1"),
      ])
      |> or_fail_with("both Set-Cookie headers should stay")
    }),
    it("transaction remove_header example removes Server", fn() {
      // Act
      let headers = public_headers()

      // Assert
      headers
      |> should()
      |> be_equal([Header("Content-Type", "text/plain")])
      |> or_fail_with("only Content-Type should stay")
    }),
    it("transaction get_cookie example finds the session cookie", fn() {
      // Act
      let cookie = session()

      // Assert
      cookie
      |> should()
      |> be_equal(
        Some(transaction.Cookie(
          name: "session_id",
          value: "abc123",
          expires: None,
          max_age: None,
          domain: None,
          path: None,
          secure: True,
          http_only: True,
          same_site: Some(transaction.Strict),
        )),
      )
      |> or_fail_with("the session cookie should be found")
    }),
    it("transaction get_cookie_value example returns dark", fn() {
      // Act
      let value = theme()

      // Assert
      value
      |> should()
      |> be_equal(Some("dark"))
      |> or_fail_with("the theme should be dark")
    }),
    it("transaction set_cookie example replaces the theme cookie", fn() {
      // Act
      let cookies = dark_theme()

      // Assert
      cookies
      |> should()
      |> be_equal([
        transaction.Cookie(
          name: "theme",
          value: "dark",
          expires: None,
          max_age: None,
          domain: None,
          path: None,
          secure: False,
          http_only: False,
          same_site: None,
        ),
      ])
      |> or_fail_with("only the dark theme cookie should stay")
    }),
    it("transaction remove_cookie example removes the theme cookie", fn() {
      // Act
      let cookies = doc_http_data_transaction_remove_cookie.without_theme()

      // Assert
      cookies
      |> should()
      |> be_equal([
        transaction.Cookie(
          name: "lang",
          value: "en",
          expires: None,
          max_age: None,
          domain: None,
          path: None,
          secure: False,
          http_only: False,
          same_site: None,
        ),
      ])
      |> or_fail_with("only the lang cookie should stay")
    }),
    it("transaction method_to_string example returns POST", fn() {
      // Act
      let name = post_name()

      // Assert
      name
      |> should()
      |> be_equal("POST")
      |> or_fail_with("the name should be POST")
    }),
    it("transaction parse_method example returns Delete", fn() {
      // Act
      let method = delete_method()

      // Assert
      method
      |> should()
      |> be_equal(Some(Delete))
      |> or_fail_with("delete should parse to Delete")
    }),
    it("transaction get_query_param example decodes the value", fn() {
      // Act
      let value = search_term()

      // Assert
      value
      |> should()
      |> be_equal(Some("hello world"))
      |> or_fail_with("the search term should be hello world")
    }),
    it("transaction has_content_type example matches a JSON request", fn() {
      // Arrange
      let request =
        transaction.Request(
          ..transaction_request([]),
          content_type: Some("application/json; charset=utf-8"),
        )

      // Act
      let matches = is_json(request)

      // Assert
      matches
      |> should()
      |> be_equal(True)
      |> or_fail_with("a JSON request should match")
    }),
    it("transaction is_method example matches a POST request", fn() {
      // Arrange
      let request =
        transaction.Request(..transaction_request([]), method: transaction.Post)

      // Act
      let matches = is_post(request)

      // Assert
      matches
      |> should()
      |> be_equal(True)
      |> or_fail_with("a POST request should match")
    }),
    it("transaction is_method example does not match a GET request", fn() {
      // Arrange
      let request = transaction_request([])

      // Act
      let matches = is_post(request)

      // Assert
      matches
      |> should()
      |> be_equal(False)
      |> or_fail_with("a GET request should not match")
    }),
    it("transaction set_params example sets the id", fn() {
      // Arrange
      let request = transaction_request([])

      // Act
      let params = with_user_id(request).params

      // Assert
      params
      |> should()
      |> be_equal([#("id", "42")])
      |> or_fail_with("the params should be the id 42")
    }),
  ])
}

fn validation_tests() -> UnitNode {
  group("dream/http/validation", [
    it("module example creates the user", fn() {
      // Arrange
      let request =
        json_request(
          "{\"name\":\"Ann\",\"email\":\"ann@example.com\",\"age\":30}",
        )

      // Act
      let response = create(request, Nil, Nil)

      // Assert
      response.status
      |> should()
      |> be_equal(201)
      |> or_fail_with("create should return 201")
    }),
    it("module example reports the bad field", fn() {
      // Arrange
      let request =
        json_request(
          "{\"name\":\"Ann\",\"email\":\"ann@example.com\",\"age\":\"old\"}",
        )

      // Act
      let response = create(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("{\"errors\":[\"Expected Int but found String at age\"]}")
      |> or_fail_with("create should report age")
    }),
    it("ValidationError example matches validate_json output", fn() {
      // Arrange
      let decoder = {
        use email <- subfield(["user", "email"], string)
        success(email)
      }

      // Act
      let result = validate_json("{\"user\":{\"email\":1}}", decoder)

      // Assert
      result
      |> should()
      |> be_equal(Error([email_error()]))
      |> or_fail_with("validate_json should return email_error")
    }),
    it("validate_json example creates the post", fn() {
      // Arrange
      let request =
        json_request("{\"title\":\"Hi\",\"body\":\"Text\",\"published\":true}")

      // Act
      let response = create_post(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal("{\"title\":\"Hi\",\"body\":\"Text\",\"published\":true}")
      |> or_fail_with("create_post should send the post")
    }),
    it("validate_json example reports the bad field", fn() {
      // Arrange
      let request =
        json_request(
          "{\"title\":\"Hi\",\"body\":\"Text\",\"published\":\"yes\"}",
        )

      // Act
      let response = create_post(request, Nil, Nil)

      // Assert
      response
      |> should()
      |> extract_body_text()
      |> be_equal(
        "{\"errors\":[{\"error\":\"Expected Bool but found String at published\",\"field\":\"published\"}]}",
      )
      |> or_fail_with("create_post should report published")
    }),
  ])
}
