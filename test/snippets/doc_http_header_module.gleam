import dream/http/header.{Header}

pub fn use_headers() {
  // Create headers
  let headers = [
    Header("Content-Type", "application/json"),
    Header("Cache-Control", "max-age=3600"),
  ]

  // Get a header value
  let content_type = header.get_header(headers, "content-type")
  // Some("application/json")

  // Set or replace a header
  let with_custom = header.set_header(headers, "X-Custom", "value")

  // Add a header without replacing
  let with_cookie = header.add_header(with_custom, "Set-Cookie", "session=abc")

  #(content_type, with_cookie)
}
