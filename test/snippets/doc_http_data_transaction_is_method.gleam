//// Example for the doc of `transaction.is_method`.

import dream/http/transaction.{type Request, Post, is_method}

pub fn is_post(request: Request) -> Bool {
  // True only for a POST request
  is_method(request, Post)
}
