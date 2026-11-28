//// Example for the doc of `transaction.add_header`.

import dream/http/transaction.{type Header, add_header}

pub fn set_cookie_headers() -> List(Header) {
  // Both headers stay, the newest first:
  // [Header("Set-Cookie", "b=2"), Header("Set-Cookie", "a=1")]
  []
  |> add_header("Set-Cookie", "a=1")
  |> add_header("Set-Cookie", "b=2")
}
