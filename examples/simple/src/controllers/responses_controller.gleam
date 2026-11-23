//// Responses controller
////
//// The response builders that are not text or JSON: a redirect, an empty
//// answer, and a file download with headers of its own.

import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response}
import dream/http/header.{add_header}
import dream/http/response.{
  Response, binary_response, empty_response, redirect_response,
}
import dream/http/status
import dream/router.{type EmptyServices}

/// GET /old-home: the page moved to /
pub fn moved(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  redirect_response(status.moved_permanently, "/")
}

/// DELETE /sessions: nothing to send back
pub fn sign_out(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  empty_response(status.no_content)
}

/// GET /report.csv: bytes that the browser saves as a file
pub fn download_report(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let csv = <<"id,name\n1,Ada\n2,Grace\n":utf8>>
  let response = binary_response(status.ok, csv, "text/csv")
  Response(
    ..response,
    headers: add_header(
      response.headers,
      "Content-Disposition",
      "attachment; filename=\"report.csv\"",
    ),
  )
}
