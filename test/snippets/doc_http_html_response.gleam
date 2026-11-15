import dream/http/response
import dream/http/status

pub fn index(_request, _context, _services) {
  let html =
    "
    <!DOCTYPE html>
    <html>
      <body><h1>Welcome</h1></body>
    </html>
  "

  response.html_response(status.ok, html)
}
