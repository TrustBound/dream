//// Example for the doc of `request.is_method`.

import dream/http/request.{type Request, Post, is_method}

pub fn is_post(request: Request) -> Bool {
  // True only for a POST request
  is_method(request, Post)
}
