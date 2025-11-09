# dream_helpers

Common utilities for Dream applications.

Provides:
- HTTP status codes and helpers
- Response builders (json_response, html_response, etc.)
- JSON validation with auto-error responses

## Usage

```gleam
import dream_helpers/statuses.{ok_status, not_found_status}
import dream_helpers/http.{json_response, html_response}
import dream_helpers/validators

// Build responses
json_response(ok_status(), "{\"message\": \"Hello\"}")
html_response(ok_status(), "<h1>Hello</h1>")

// Validate JSON
case validators.validate_or_respond(request.body, user_decoder()) {
  Ok(user_data) -> // Use data
  Error(error_response) -> error_response
}
```

