//// Example for the doc of `transaction.method_to_string`.

import dream/http/transaction.{Post, method_to_string}

pub fn post_name() -> String {
  // "POST"
  method_to_string(Post)
}
