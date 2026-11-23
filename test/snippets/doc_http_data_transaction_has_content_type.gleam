//// Example for the doc of `transaction.has_content_type`.

import dream/http/transaction.{type Request, has_content_type}

pub fn is_json(request: Request) -> Bool {
  // True for "application/json; charset=utf-8"
  has_content_type(request, "application/json")
}
