//// Naming conventions: Type Conversion
////
//// `convert_{from}_to_{to}` changes one structured type into another,
//// `parse_{noun}` reads text into a type, `format_{noun}` writes a type as
//// text, and `{from}_to_{to}` is the short form.

import dream/dream
import dream/http/cookie.{type Cookie}
import dream/http/header.{type Header, Header}
import dream/http/request.{type Method}
import gleam/http as gleam_http
import gleam/list
import gleam/option.{type Option}
import gleam/string
import gleam/uri

pub type ParsedRequest {
  ParsedRequest(
    cookies: List(Cookie),
    method: Option(Method),
    header_cookies: List(Cookie),
  )
}

pub fn convert_http_method_to_method(
  http_method: gleam_http.Method,
) -> Option(Method) {
  http_method
  |> gleam_http.method_to_string
  |> request.parse_method
}

pub fn convert_cookie_to_header(cookie: Cookie) -> Header {
  Header(name: "Set-Cookie", value: format_cookie_header(cookie))
}

pub fn parse_request(headers: List(Header)) -> ParsedRequest {
  let cookies = dream.parse_cookie_string("theme=dark; session=abc123")
  let method = request.parse_method("POST")
  let header_cookies = dream.parse_cookies_from_headers(headers)
  ParsedRequest(cookies:, method:, header_cookies:)
}

pub fn format_cookie_header(cookie: Cookie) -> String {
  cookie.name <> "=" <> cookie.value
}

pub fn format_query_string(parameters: List(#(String, String))) -> String {
  parameters
  |> list.map(format_query_parameter)
  |> string.join("&")
}

fn format_query_parameter(parameter: #(String, String)) -> String {
  let #(name, value) = parameter
  uri.percent_encode(name) <> "=" <> uri.percent_encode(value)
}

pub fn header_to_pair(header: Header) -> #(String, String) {
  #(header.name, header.value)
}

pub fn pair_to_header(pair: #(String, String)) -> Header {
  let #(name, value) = pair
  Header(name:, value:)
}
