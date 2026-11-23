//// Example for the doc of `request.method_to_string`.

import dream/http/request.{Post, method_to_string}

pub fn post_name() -> String {
  // "POST"
  method_to_string(Post)
}
