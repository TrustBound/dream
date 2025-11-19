import dream/http/request.{Request, Get, Http, Http1, get_param, get_int_param, get_string_param, get_query_param}
import gleam/option
import gleeunit/should

pub fn get_param_with_format_extension_extracts_format_test() {
  let request =
    Request(
      method: Get,
      protocol: Http,
      version: Http1,
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
  
  case get_param(request, "id") {
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

pub fn get_int_param_with_valid_integer_returns_ok_test() {
  let request =
    Request(
      method: Get,
      protocol: Http,
      version: Http1,
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
    )
  
  case get_int_param(request, "id") {
    Ok(id) -> id |> should.equal(123)
    Error(_) -> should.fail()
  }
}

pub fn get_int_param_with_missing_parameter_returns_error_test() {
  let request =
    Request(
      method: Get,
      protocol: Http,
      version: Http1,
      path: "/users",
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
    )
  
  case get_int_param(request, "id") {
    Ok(_) -> should.fail()
    Error(msg) -> msg |> should.equal("Missing id parameter")
  }
}

pub fn get_int_param_with_non_integer_returns_error_test() {
  let request =
    Request(
      method: Get,
      protocol: Http,
      version: Http1,
      path: "/users/abc",
      query: "",
      params: [#("id", "abc")],
      host: option.None,
      port: option.None,
      remote_address: option.None,
      body: "",
      headers: [],
      cookies: [],
      content_type: option.None,
      content_length: option.None,
    )
  
  case get_int_param(request, "id") {
    Ok(_) -> should.fail()
    Error(msg) -> msg |> should.equal("id must be an integer")
  }
}

pub fn get_string_param_with_valid_parameter_returns_ok_test() {
  let request =
    Request(
      method: Get,
      protocol: Http,
      version: Http1,
      path: "/users/john",
      query: "",
      params: [#("name", "john")],
      host: option.None,
      port: option.None,
      remote_address: option.None,
      body: "",
      headers: [],
      cookies: [],
      content_type: option.None,
      content_length: option.None,
    )
  
  case get_string_param(request, "name") {
    Ok(name) -> name |> should.equal("john")
    Error(_) -> should.fail()
  }
}

pub fn get_string_param_with_missing_parameter_returns_error_test() {
  let request =
    Request(
      method: Get,
      protocol: Http,
      version: Http1,
      path: "/users",
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
    )
  
  case get_string_param(request, "name") {
    Ok(_) -> should.fail()
    Error(msg) -> msg |> should.equal("Missing name parameter")
  }
}

// Query parameter tests with URL decoding

pub fn get_query_param_decodes_percent_encoded_values_test() {
  // Test %20 (space) decoding
  case get_query_param("name=hello%20world", "name") {
    option.Some(value) -> value |> should.equal("hello world")
    option.None -> should.fail()
  }
}

pub fn get_query_param_decodes_percent_encoded_ampersand_test() {
  // Test %26 (&) decoding
  case get_query_param("title=Buy%20milk%20%26%20eggs", "title") {
    option.Some(value) -> value |> should.equal("Buy milk & eggs")
    option.None -> should.fail()
  }
}

pub fn get_query_param_decodes_plus_sign_as_space_test() {
  // Test + (plus sign) decoding to space
  case get_query_param("name=hello+world", "name") {
    option.Some(value) -> value |> should.equal("hello world")
    option.None -> should.fail()
  }
}

pub fn get_query_param_decodes_multiple_encoded_chars_test() {
  // Test multiple encoded characters
  case get_query_param("query=search%20for%20%22test%22", "query") {
    option.Some(value) -> value |> should.equal("search for \"test\"")
    option.None -> should.fail()
  }
}

pub fn get_query_param_decodes_key_and_value_test() {
  // Test that both key and value are decoded
  case get_query_param("user%20name=john%20doe", "user name") {
    option.Some(value) -> value |> should.equal("john doe")
    option.None -> should.fail()
  }
}

pub fn get_query_param_handles_empty_value_test() {
  // Test parameter with no value
  case get_query_param("flag&other=value", "flag") {
    option.Some(value) -> value |> should.equal("")
    option.None -> should.fail()
  }
}

pub fn get_query_param_handles_multiple_parameters_test() {
  // Test multiple parameters, finding the right one
  case get_query_param("name=john&age=30&city=new%20york", "city") {
    option.Some(value) -> value |> should.equal("new york")
    option.None -> should.fail()
  }
}

pub fn get_query_param_returns_none_for_missing_parameter_test() {
  // Test missing parameter
  case get_query_param("name=john&age=30", "missing") {
    option.Some(_) -> should.fail()
    option.None -> option.None |> should.be_none()
  }
}

pub fn get_query_param_handles_empty_query_string_test() {
  // Test empty query string
  case get_query_param("", "name") {
    option.Some(_) -> should.fail()
    option.None -> option.None |> should.be_none()
  }
}

pub fn get_query_param_decodes_special_characters_test() {
  // Test various special characters
  case get_query_param("path=/home/user%2Fdocuments", "path") {
    option.Some(value) -> value |> should.equal("/home/user/documents")
    option.None -> should.fail()
  }
}

pub fn get_query_param_handles_malformed_encoding_gracefully_test() {
  // Test malformed percent encoding (falls back gracefully)
  case get_query_param("name=hello%2", "name") {
    option.Some(value) -> {
      // Should fall back to original string with + replaced
      value |> should.equal("hello%2")
    }
    option.None -> should.fail()
  }
}

pub fn get_query_param_decodes_unicode_characters_test() {
  // Test Unicode character encoding (UTF-8)
  case get_query_param("text=hello%20%E2%9C%93", "text") {
    option.Some(value) -> value |> should.equal("hello ✓")
    option.None -> should.fail()
  }
}

pub fn get_query_param_handles_equals_sign_in_value_test() {
  // Test equals sign in value (should not break parsing)
  case get_query_param("equation=x%3Dy%2Bz", "equation") {
    option.Some(value) -> value |> should.equal("x=y+z")
    option.None -> should.fail()
  }
}

