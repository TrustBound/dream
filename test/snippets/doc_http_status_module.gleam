import dream/http/response.{text_response}
import dream/http/status.{ok}

pub fn index(_request, _context, _services) {
  text_response(ok, "Hello, World!")
}
