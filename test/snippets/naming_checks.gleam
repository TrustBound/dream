//// Naming conventions: Boolean Checks
////
//// `is_{adjective}` asks about a property of one value. `has_{noun}` asks
//// whether a collection or a value contains something.

import dream/http.{type Cookie, type Header, type Request, type Response}
import dream/http/request.{Post}
import gleam/option.{Some}

pub fn is_post(request: Request) -> Bool {
  http.is_method(request, Post)
}

pub fn is_secure(cookie: Cookie) -> Bool {
  cookie.secure
}

pub fn is_json(response: Response) -> Bool {
  response.content_type == Some("application/json; charset=utf-8")
}

pub fn has_json_body(request: Request) -> Bool {
  http.has_content_type(request, "application/json")
}

pub fn has_header(headers: List(Header), name: String) -> Bool {
  option.is_some(http.get_header(headers, name))
}

pub fn has_cookie(cookies: List(Cookie), name: String) -> Bool {
  option.is_some(http.get_cookie(cookies, name))
}
