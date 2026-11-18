import dream/http/header.{Header}

pub fn remove_debug() {
  let headers = [
    Header("Content-Type", "application/json"),
    Header("Cache-Control", "max-age=3600"),
    Header("X-Debug", "true"),
  ]

  header.remove_header(headers, "x-debug")
  // Result: [
  //   Header("Content-Type", "application/json"),
  //   Header("Cache-Control", "max-age=3600")
  // ]
}
