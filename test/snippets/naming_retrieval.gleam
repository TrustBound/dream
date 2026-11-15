//// Naming conventions: Retrieval
////
//// `get_{noun}` looks up a value in a collection by a key. `{noun}_name`
//// and `{noun}_value` read one field of a single value.

import dream/http.{type Cookie, type Header, type Request}
import gleam/option.{type Option}

pub type RequestDetails {
  RequestDetails(
    content_type: Option(String),
    session: Option(Cookie),
    page: Option(String),
  )
}

pub fn summarize_request(request: Request) -> RequestDetails {
  let content_type = http.get_header(request.headers, "Content-Type")
  let session = http.get_cookie(request.cookies, "session")
  let page = http.get_query_param(request.query, "page")
  RequestDetails(content_type:, session:, page:)
}

pub fn list_names(cookie: Cookie, header: Header) -> List(String) {
  let cookie_name = http.cookie_name(cookie)
  let header_name = http.header_name(header)
  [cookie_name, header_name]
}

pub fn list_values(cookie: Cookie, header: Header) -> List(String) {
  let cookie_value = http.cookie_value(cookie)
  let header_value = http.header_value(header)
  [cookie_value, header_value]
}
