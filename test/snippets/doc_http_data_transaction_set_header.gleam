//// Example for the doc of `transaction.set_header`.

import dream/http/transaction.{type Header, type Response, set_header}

pub fn cache_headers(response: Response) -> List(Header) {
  response.headers
  |> set_header("Cache-Control", "max-age=3600")
  |> set_header("X-Custom-Header", "value")
}
