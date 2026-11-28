import dream/http/header.{type Header, Header}

pub fn response_headers() -> List(Header) {
  [
    Header("Content-Type", "application/json"),
    Header("Cache-Control", "no-cache"),
    Header("X-Request-ID", "abc-123"),
  ]
}
