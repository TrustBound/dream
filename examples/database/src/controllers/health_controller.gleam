//// Health Controller
////
//// Health check endpoint for load balancers and monitoring.
//// Runs `SELECT 1` against the connection pool to prove the database answers.

import context.{type DatabaseContext}
import dream/http.{type Request, type Response}
import dream/http/error.{type Error, InternalServerError}
import dream/http/response.{json_response}
import dream/http/status
import pog
import services.{type Services}

/// Report whether the app and its database are healthy
pub fn show(
  _request: Request,
  _context: DatabaseContext,
  services: Services,
) -> Response {
  case check_database(services.database.connection) {
    Ok(_) -> json_response(status.ok, "{\"status\": \"healthy\"}")
    Error(_) ->
      json_response(status.service_unavailable, "{\"status\": \"unhealthy\"}")
  }
}

fn check_database(db: pog.Connection) -> Result(Nil, Error) {
  case pog.query("SELECT 1") |> pog.execute(db) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(InternalServerError("Database connection failed"))
  }
}
