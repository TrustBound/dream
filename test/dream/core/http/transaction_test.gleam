// Note: Response builder tests have been moved to dream_helpers module
// This file now only tests core HTTP types (headers, cookies, methods, path params)

import dream/core/http/transaction
import gleam/list
import gleam/option
import gleeunit/should

// Cookie tests
pub fn simple_cookie_with_name_and_value_creates_cookie_with_defaults_test() {
  let cookie = transaction.simple_cookie("theme", "dark")
  transaction.cookie_name(cookie) |> should.equal("theme")
  transaction.cookie_value(cookie) |> should.equal("dark")
}

pub fn secure_cookie_with_name_and_value_creates_secure_cookie_test() {
  let secure_cookie = transaction.secure_cookie("session", "token123")
  
  case transaction.get_cookie_value([secure_cookie], "session") {
    option.Some(value) -> value |> should.equal("token123")
    option.None -> should.fail()
  }
}

// Header tests  
pub fn get_header_with_existing_header_returns_value_test() {
  let headers = [
    transaction.Header("Content-Type", "application/json"),
    transaction.Header("Authorization", "Bearer token"),
  ]
  
  let result = transaction.get_header(headers, "Content-Type")
  
  case result {
    option.Some(value) -> value |> should.equal("application/json")
    option.None -> should.fail()
  }
}

pub fn set_header_with_new_header_adds_header_test() {
  let headers = []
  let result = transaction.set_header(headers, "X-Custom", "value")
  
  list.length(result) |> should.equal(1)
}

//  Path param tests
pub fn get_param_with_format_extension_extracts_format_test() {
  let request =
    transaction.Request(
      method: transaction.Get,
      protocol: transaction.Http,
      version: transaction.Http1,
      path: "/users/123.json",
      query: "",
      params: [#("id", "123.json")],
      host: option.None,
      port: option.None,
      remote_address: option.None,
      body: "",
      headers: [],
      cookies: [],
      content_type: option.None,
      content_length: option.None,
    )
  
  case transaction.get_param(request, "id") {
    Ok(param) -> {
      param.value |> should.equal("123")
      param.raw |> should.equal("123.json")
      case param.format {
        option.Some(fmt) -> fmt |> should.equal("json")
        option.None -> should.fail()
      }
    }
    Error(_) -> should.fail()
  }
}
