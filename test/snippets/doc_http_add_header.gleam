import dream/http/header

pub fn add_cookies() {
  let headers = []

  // Add multiple Set-Cookie headers
  headers
  |> header.add_header("Set-Cookie", "session=abc; HttpOnly")
  |> header.add_header("Set-Cookie", "preferences=dark; Path=/")
  // Result: [
  //   Header("Set-Cookie", "preferences=dark; Path=/"),
  //   Header("Set-Cookie", "session=abc; HttpOnly")
  // ]
}
