import dream/http/header.{Header}

pub fn content_type_name() -> String {
  let content_type = Header("Content-Type", "application/json")
  header.header_name(content_type)
  // "Content-Type"
}
