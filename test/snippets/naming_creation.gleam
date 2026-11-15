//// Naming conventions: Creation and Construction
////
//// `create_{noun}` makes a value from its parts. `build_{noun}` turns a
//// builder into the final value.

import dream/http/cookie.{type Cookie, Cookie}
import dream/http/header.{type Header, Header}
import dream/http/response.{type Response, Response}

pub type ResponseBuilder {
  ResponseBuilder(status: Int, headers: List(Header), body: String)
}

pub type CookieBuilder {
  CookieBuilder(name: String, value: String, secure: Bool)
}

pub fn create_response(status: Int) -> Response {
  response.empty_response(status)
}

pub fn create_cookie(name: String, value: String) -> Cookie {
  cookie.simple_cookie(name, value)
}

pub fn create_header(name: String, value: String) -> Header {
  Header(name:, value:)
}

pub fn build_response(builder: ResponseBuilder) -> Response {
  let text = response.text_response(builder.status, builder.body)
  Response(..text, headers: builder.headers)
}

pub fn build_cookie(builder: CookieBuilder) -> Cookie {
  let simple = cookie.simple_cookie(builder.name, builder.value)
  Cookie(..simple, secure: builder.secure)
}
