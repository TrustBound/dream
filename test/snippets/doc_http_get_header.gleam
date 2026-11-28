import dream/http/header.{Header}

pub fn look_up_headers() {
  let headers = [
    Header("Content-Type", "application/json"),
    Header("Cache-Control", "max-age=3600"),
  ]

  let content_type = header.get_header(headers, "content-type")
  // Some("application/json")
  let cache_control = header.get_header(headers, "CACHE-CONTROL")
  // Some("max-age=3600")
  let missing = header.get_header(headers, "X-Missing")
  // None

  #(content_type, cache_control, missing)
}
