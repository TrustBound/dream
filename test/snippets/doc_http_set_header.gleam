import dream/http/header.{Header}

pub fn replace_and_add() {
  let headers = [Header("Content-Type", "text/plain")]

  // Replace existing header
  let updated = header.set_header(headers, "content-type", "application/json")
  // Result: [Header("content-type", "application/json")]

  // Add new header
  header.set_header(updated, "Cache-Control", "max-age=3600")
  // Result: [
  //   Header("Cache-Control", "max-age=3600"),
  //   Header("content-type", "application/json")
  // ]
}
