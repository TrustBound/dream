// Just status codes
import dream/http/status

// Just error type
import dream/http/error.{type Error}

pub fn error_status(http_error: Error) -> Int {
  case http_error {
    error.NotFound(_) -> status.not_found
    _ -> status.bad_request
  }
}
