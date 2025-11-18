import dream/http/request.{Request, Get, Http, Http1, get_param, get_int_param, get_string_param}
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

