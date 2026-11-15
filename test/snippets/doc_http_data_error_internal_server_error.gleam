//// Example for the doc of `error.InternalServerError`.

import dream/http/error.{type Error, InternalServerError}
import gleam/result

pub fn load_users(
  query_result: Result(List(String), Nil),
) -> Result(List(String), Error) {
  query_result
  |> result.replace_error(InternalServerError("Database connection failed"))
}

pub fn charge(payment_result: Result(Int, Nil)) -> Result(Int, Error) {
  payment_result
  |> result.replace_error(InternalServerError(
    "External payment API unavailable",
  ))
}
