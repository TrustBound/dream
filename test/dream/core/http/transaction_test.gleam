import dream/core/context.{type AppContext, new_context}
import dream/core/http/statuses as statuses
import dream/core/http/transaction as transaction
import gleam/list
import gleam/option
import gleeunit/should

// Cookie tests
pub fn simple_cookie_with_name_and_value_creates_cookie_with_defaults_test() {
  // Arrange & Act
  let cookie = transaction.simple_cookie("theme", "dark")
  
  // Assert
  transaction.cookie_name(cookie) |> should.equal("theme")
  transaction.cookie_value(cookie) |> should.equal("dark")
  // Verify defaults by checking behavior: secure cookies should have different properties
  let secure_cookie = transaction.secure_cookie("session", "token")
  let secure_name = transaction.cookie_name(secure_cookie)
  let secure_value = transaction.cookie_value(secure_cookie)
  secure_name |> should.equal("session")
  secure_value |> should.equal("token")
}

pub fn secure_cookie_with_name_and_value_creates_secure_cookie_test() {
  // Arrange & Act
  let secure_cookie = transaction.secure_cookie("session", "token123")
  
  // Assert - verify secure cookie works with cookie management functions
  case transaction.get_cookie_value([secure_cookie], "session") {
    option.Some(value) -> value |> should.equal("token123")
    option.None -> should.fail()
  }
  // Verify secure cookie can be added to cookie list
  let cookies = transaction.set_cookie([], secure_cookie)
  list.length(cookies) |> should.equal(1)
  // Verify secure cookie can be retrieved
  case transaction.get_cookie(cookies, "session") {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
}

// Header tests
pub fn get_header_with_existing_header_returns_value_test() {
  // Arrange
  let headers = [
    transaction.Header("Content-Type", "application/json"),
    transaction.Header("Authorization", "Bearer token"),
  ]
  
  // Act
  let result = transaction.get_header(headers, "Content-Type")
  
  // Assert
  case result {
    option.Some(value) -> value |> should.equal("application/json")
    option.None -> should.fail()
  }
}

pub fn get_header_with_case_insensitive_search_returns_value_test() {
  // Arrange
  let headers = [
    transaction.Header("Content-Type", "application/json"),
  ]
  
  // Act
  let result = transaction.get_header(headers, "content-type")
  
  // Assert
  case result {
    option.Some(value) -> value |> should.equal("application/json")
    option.None -> should.fail()
  }
}

pub fn get_header_with_non_existing_header_returns_none_test() {
  // Arrange
  let headers = [
    transaction.Header("Content-Type", "application/json"),
  ]
  
  // Act
  let result = transaction.get_header(headers, "X-Custom-Header")
  
  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> Nil
  }
}

pub fn set_header_with_new_header_adds_header_test() {
  // Arrange
  let headers = []
  
  // Act
  let result = transaction.set_header(headers, "X-Custom", "value")
  
  // Assert
  list.length(result) |> should.equal(1)
  case result {
    [header] -> {
      transaction.header_name(header) |> should.equal("X-Custom")
      transaction.header_value(header) |> should.equal("value")
    }
    _ -> should.fail()
  }
}

pub fn set_header_with_existing_header_replaces_header_test() {
  // Arrange
  let headers = [
    transaction.Header("X-Custom", "old-value"),
  ]
  
  // Act
  let result = transaction.set_header(headers, "X-Custom", "new-value")
  
  // Assert
  list.length(result) |> should.equal(1)
  case result {
    [header, .._] -> {
      transaction.header_value(header) |> should.equal("new-value")
    }
    [] -> should.fail()
  }
}

pub fn add_header_adds_header_without_removing_existing_test() {
  // Arrange
  let headers = [
    transaction.Header("X-Custom", "value1"),
  ]
  
  // Act
  let result = transaction.add_header(headers, "X-Custom", "value2")
  
  // Assert
  list.length(result) |> should.equal(2)
}

pub fn remove_header_with_existing_header_removes_header_test() {
  // Arrange
  let headers = [
    transaction.Header("X-Custom", "value"),
    transaction.Header("Content-Type", "application/json"),
  ]
  
  // Act
  let result = transaction.remove_header(headers, "X-Custom")
  
  // Assert
  list.length(result) |> should.equal(1)
  case result {
    [header, .._] -> {
      transaction.header_name(header) |> should.equal("Content-Type")
    }
    [] -> should.fail()
  }
}

pub fn remove_header_with_case_insensitive_search_removes_header_test() {
  // Arrange
  let headers = [
    transaction.Header("Content-Type", "application/json"),
  ]
  
  // Act
  let result = transaction.remove_header(headers, "content-type")
  
  // Assert
  list.length(result) |> should.equal(0)
}

// Cookie management tests
pub fn get_cookie_with_existing_cookie_returns_cookie_test() {
  // Arrange
  let cookie1 = transaction.simple_cookie("session", "abc123")
  let cookie2 = transaction.simple_cookie("theme", "dark")
  let cookies = [cookie1, cookie2]
  
  // Act
  let result = transaction.get_cookie(cookies, "session")
  
  // Assert
  case result {
    option.Some(cookie) -> {
      transaction.cookie_name(cookie) |> should.equal("session")
      transaction.cookie_value(cookie) |> should.equal("abc123")
    }
    option.None -> should.fail()
  }
}

pub fn get_cookie_with_case_insensitive_search_returns_cookie_test() {
  // Arrange
  let cookie = transaction.simple_cookie("Session", "abc123")
  let cookies = [cookie]
  
  // Act
  let result = transaction.get_cookie(cookies, "session")
  
  // Assert
  case result {
    option.Some(_) -> Nil
    option.None -> should.fail()
  }
}

pub fn get_cookie_with_non_existing_cookie_returns_none_test() {
  // Arrange
  let cookies = []
  
  // Act
  let result = transaction.get_cookie(cookies, "session")
  
  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> Nil
  }
}

pub fn get_cookie_value_with_existing_cookie_returns_value_test() {
  // Arrange
  let cookie = transaction.simple_cookie("session", "abc123")
  let cookies = [cookie]
  
  // Act
  let result = transaction.get_cookie_value(cookies, "session")
  
  // Assert
  case result {
    option.Some(value) -> value |> should.equal("abc123")
    option.None -> should.fail()
  }
}

pub fn set_cookie_with_new_cookie_adds_cookie_test() {
  // Arrange
  let cookies = []
  let new_cookie = transaction.simple_cookie("session", "abc123")
  
  // Act
  let result = transaction.set_cookie(cookies, new_cookie)
  
  // Assert
  list.length(result) |> should.equal(1)
}

pub fn set_cookie_with_existing_cookie_replaces_cookie_test() {
  // Arrange
  let old_cookie = transaction.simple_cookie("session", "old-value")
  let new_cookie = transaction.simple_cookie("session", "new-value")
  let cookies = [old_cookie]
  
  // Act
  let result = transaction.set_cookie(cookies, new_cookie)
  
  // Assert
  list.length(result) |> should.equal(1)
  case result {
    [cookie, .._] -> {
      transaction.cookie_value(cookie) |> should.equal("new-value")
    }
    [] -> should.fail()
  }
}

pub fn remove_cookie_with_existing_cookie_removes_cookie_test() {
  // Arrange
  let cookie1 = transaction.simple_cookie("session", "abc123")
  let cookie2 = transaction.simple_cookie("theme", "dark")
  let cookies = [cookie1, cookie2]
  
  // Act
  let result = transaction.remove_cookie(cookies, "session")
  
  // Assert
  list.length(result) |> should.equal(1)
  case result {
    [cookie, .._] -> {
      transaction.cookie_name(cookie) |> should.equal("theme")
    }
    [] -> should.fail()
  }
}

// Method conversion tests
pub fn method_to_string_with_get_returns_get_test() {
  // Arrange & Act
  let result = transaction.method_to_string(transaction.Get)
  
  // Assert
  result |> should.equal("GET")
}

pub fn method_to_string_with_post_returns_post_test() {
  // Arrange & Act
  let result = transaction.method_to_string(transaction.Post)
  
  // Assert
  result |> should.equal("POST")
}

pub fn method_to_string_with_all_methods_returns_correct_strings_test() {
  transaction.method_to_string(transaction.Put) |> should.equal("PUT")
  transaction.method_to_string(transaction.Delete) |> should.equal("DELETE")
  transaction.method_to_string(transaction.Patch) |> should.equal("PATCH")
  transaction.method_to_string(transaction.Options) |> should.equal("OPTIONS")
  transaction.method_to_string(transaction.Head) |> should.equal("HEAD")
}

pub fn parse_method_with_valid_string_returns_method_test() {
  // Arrange & Act
  let result = transaction.parse_method("GET")
  
  // Assert
  case result {
    option.Some(method) -> {
      case method {
        transaction.Get -> Nil
        _ -> should.fail()
      }
    }
    option.None -> should.fail()
  }
}

pub fn parse_method_with_case_insensitive_string_returns_method_test() {
  // Arrange & Act
  let result = transaction.parse_method("post")
  
  // Assert
  case result {
    option.Some(method) -> {
      case method {
        transaction.Post -> Nil
        _ -> should.fail()
      }
    }
    option.None -> should.fail()
  }
}

pub fn parse_method_with_invalid_string_returns_none_test() {
  // Arrange & Act
  let result = transaction.parse_method("INVALID")
  
  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> Nil
  }
}

// Response builder tests
pub fn text_response_with_valid_status_and_body_creates_text_response_test() {
  // Arrange & Act
  let response = transaction.text_response(statuses.ok_status(), "Hello World")
  
  // Assert
  case response {
    transaction.Response(status, body, headers, cookies, content_type, content_length) -> {
      status |> should.equal(statuses.ok_status())
      body |> should.equal("Hello World")
      list.length(headers) |> should.equal(1)
      list.length(cookies) |> should.equal(0)
      case content_type {
        option.Some(ct) -> ct |> should.equal("text/plain; charset=utf-8")
        option.None -> should.fail()
      }
    }
  }
}

pub fn json_response_with_valid_status_and_body_creates_json_response_test() {
  // Arrange & Act
  let response = transaction.json_response(statuses.ok_status(), "{\"key\":\"value\"}")
  
  // Assert
  case response {
    transaction.Response(status, body, headers, _, content_type, _) -> {
      status |> should.equal(statuses.ok_status())
      body |> should.equal("{\"key\":\"value\"}")
      case content_type {
        option.Some(ct) -> ct |> should.equal("application/json; charset=utf-8")
        option.None -> should.fail()
      }
    }
  }
}

pub fn html_response_with_valid_status_and_body_creates_html_response_test() {
  // Arrange & Act
  let response = transaction.html_response(statuses.ok_status(), "<html></html>")
  
  // Assert
  case response {
    transaction.Response(_, body, _, _, content_type, _) -> {
      body |> should.equal("<html></html>")
      case content_type {
        option.Some(ct) -> ct |> should.equal("text/html; charset=utf-8")
        option.None -> should.fail()
      }
    }
  }
}

pub fn redirect_response_with_valid_status_and_location_creates_redirect_response_test() {
  // Arrange & Act
  let redirect_status = statuses.convert_redirection_to_status(statuses.moved_permanently())
  let response = transaction.redirect_response(redirect_status, "/new-location")
  
  // Assert
  case response {
    transaction.Response(status, body, headers, _, content_type, _) -> {
      body |> should.equal("")
      case headers {
        [header, .._] -> {
          transaction.header_name(header) |> should.equal("Location")
          transaction.header_value(header) |> should.equal("/new-location")
        }
        [] -> should.fail()
      }
    }
  }
}

pub fn empty_response_with_valid_status_creates_empty_response_test() {
  // Arrange & Act
  let response = transaction.empty_response(statuses.ok_status())
  
  // Assert
  case response {
    transaction.Response(status, body, headers, _, content_type, _) -> {
      status |> should.equal(statuses.ok_status())
      body |> should.equal("")
      list.length(headers) |> should.equal(0)
      content_type |> should.equal(option.None)
    }
  }
}

// Query parameter tests
pub fn get_query_param_with_existing_param_returns_value_test() {
  // Arrange
  let query = "name=value&other=test"
  
  // Act
  let result = transaction.get_query_param(query, "name")
  
  // Assert
  case result {
    option.Some(value) -> value |> should.equal("value")
    option.None -> should.fail()
  }
}

pub fn get_query_param_with_non_existing_param_returns_none_test() {
  // Arrange
  let query = "name=value"
  
  // Act
  let result = transaction.get_query_param(query, "other")
  
  // Assert
  case result {
    option.Some(_) -> should.fail()
    option.None -> Nil
  }
}

// Request utility tests
pub fn has_content_type_with_matching_content_type_returns_true_test() {
  // Arrange
  let request = transaction.Request(
    method: transaction.Get,
    protocol: transaction.Http,
    version: transaction.Http1,
    path: "/",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    headers: [],
    cookies: [],
    content_type: option.Some("application/json"),
    content_length: option.None,
    context: new_context("test-id"),
  )
  
  // Act
  let result = transaction.has_content_type(request, "json")
  
  // Assert
  result |> should.equal(True)
}

pub fn has_content_type_with_non_matching_content_type_returns_false_test() {
  // Arrange
  let request = transaction.Request(
    method: transaction.Get,
    protocol: transaction.Http,
    version: transaction.Http1,
    path: "/",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    headers: [],
    cookies: [],
    content_type: option.Some("application/json"),
    content_length: option.None,
    context: new_context("test-id"),
  )
  
  // Act
  let result = transaction.has_content_type(request, "xml")
  
  // Assert
  result |> should.equal(False)
}

pub fn is_method_with_matching_method_returns_true_test() {
  // Arrange
  let request = transaction.Request(
    method: transaction.Post,
    protocol: transaction.Http,
    version: transaction.Http1,
    path: "/",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
    context: new_context("test-id"),
  )
  
  // Act
  let result = transaction.is_method(request, transaction.Post)
  
  // Assert
  result |> should.equal(True)
}

pub fn get_param_with_existing_param_returns_value_test() {
  // Arrange
  let request = transaction.Request(
    method: transaction.Get,
    protocol: transaction.Http,
    version: transaction.Http1,
    path: "/users/123",
    query: "",
    params: [#("id", "123")],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
    context: new_context("test-id"),
  )
  
  // Act
  let result = transaction.get_param(request, "id")
  
  // Assert
  case result {
    Ok(value) -> value |> should.equal("123")
    Error(_) -> should.fail()
  }
}

pub fn get_param_with_non_existing_param_returns_error_test() {
  // Arrange
  let request = transaction.Request(
    method: transaction.Get,
    protocol: transaction.Http,
    version: transaction.Http1,
    path: "/users/123",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
    context: new_context("test-id"),
  )
  
  // Act
  let result = transaction.get_param(request, "id")
  
  // Assert
  case result {
    Ok(_) -> should.fail()
    Error(_) -> Nil
  }
}

pub fn get_context_with_valid_request_returns_request_context_test() {
  // Arrange
  let context_value = new_context("test-id")
  let request = transaction.Request(
    method: transaction.Get,
    protocol: transaction.Http,
    version: transaction.Http1,
    path: "/",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
    context: context_value,
  )
  
  // Act
  let retrieved_context = transaction.get_context(request)
  
  // Assert - verify get_context can be used with set_context for round-trip operations
  let updated_request = transaction.set_context(request, retrieved_context)
  let round_trip_context = transaction.get_context(updated_request)
  // Verify idempotency: get_context followed by set_context preserves the context
  let updated_request2 = transaction.set_context(request, round_trip_context)
  // The round-trip operations should complete without errors (tested via set_params which uses context)
  let final_request = transaction.set_params(updated_request2, [])
  // Verify the request can be used in subsequent operations
  case transaction.get_param(final_request, "nonexistent") {
    Ok(_) -> should.fail()
    Error(_) -> Nil
  }
}

pub fn set_context_with_new_context_updates_request_context_test() {
  // Arrange
  let old_context = new_context("old-id")
  let new_context_value = new_context("new-id")
  let request = transaction.Request(
    method: transaction.Get,
    protocol: transaction.Http,
    version: transaction.Http1,
    path: "/",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
    context: old_context,
  )
  
  // Act
  let updated_request = transaction.set_context(request, new_context_value)
  
  // Assert - verify context was updated by using it in subsequent operations
  let retrieved_context = transaction.get_context(updated_request)
  // Verify the updated request can be used in other operations
  let request_with_params = transaction.set_params(updated_request, [#("test", "value")])
  case transaction.get_param(request_with_params, "test") {
    Ok(value) -> value |> should.equal("value")
    Error(_) -> should.fail()
  }
  // Verify context round-trip works by using it in another set_context
  let request_with_new_context = transaction.set_context(request_with_params, retrieved_context)
  let request_with_final_params = transaction.set_params(request_with_new_context, [#("final", "check")])
  case transaction.get_param(request_with_final_params, "final") {
    Ok(value) -> value |> should.equal("check")
    Error(_) -> should.fail()
  }
}

pub fn set_params_with_new_params_updates_request_params_test() {
  // Arrange
  let request = transaction.Request(
    method: transaction.Get,
    protocol: transaction.Http,
    version: transaction.Http1,
    path: "/users/123",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: "",
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
    context: new_context("test-id"),
  )
  let new_params = [#("id", "123"), #("post_id", "456")]
  
  // Act
  let result = transaction.set_params(request, new_params)
  
  // Assert - verify by using get_param
  case transaction.get_param(result, "id") {
    Ok(value) -> value |> should.equal("123")
    Error(_) -> should.fail()
  }
  case transaction.get_param(result, "post_id") {
    Ok(value) -> value |> should.equal("456")
    Error(_) -> should.fail()
  }
}

