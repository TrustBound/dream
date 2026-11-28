import dream/http/header.{Header}

pub fn content_type_value() -> String {
  let content_type = Header("Content-Type", "application/json")
  header.header_value(content_type)
  // "application/json"
}
