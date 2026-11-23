//// Example for the doc of `request.has_content_type`.

import dream/http/request.{type Request, has_content_type}

pub fn is_json(request: Request) -> Bool {
  // True for "application/json; charset=utf-8"
  has_content_type(request, "application/json")
}
