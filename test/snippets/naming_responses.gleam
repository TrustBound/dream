//// Naming conventions: Response Builders
////
//// `{type}_response` makes a response of one content type.

import dream/http.{type Response}

pub fn example_responses() -> List(Response) {
  let text = http.text_response(http.ok, "Hello")
  let json = http.json_response(http.ok, "{\"message\":\"Hello\"}")
  let html = http.html_response(http.ok, "<h1>Hello</h1>")
  let redirect = http.redirect_response(http.see_other, "/login")
  let empty = http.empty_response(http.no_content)
  [text, json, html, redirect, empty]
}
