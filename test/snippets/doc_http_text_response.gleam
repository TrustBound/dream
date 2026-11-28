import dream/http/response.{text_response}
import dream/http/status.{ok}

pub fn healthcheck(_request, _context, _services) {
  text_response(ok, "OK")
}
