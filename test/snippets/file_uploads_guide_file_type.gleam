import gleam/list.{contains}

const allowed_types = [
  "image/jpeg",
  "image/png",
  "image/gif",
  "application/pdf",
]

pub fn validate_file_type(content_type: String) -> Result(Nil, String) {
  case contains(allowed_types, content_type) {
    True -> Ok(Nil)
    False -> Error("Unsupported file type")
  }
}
