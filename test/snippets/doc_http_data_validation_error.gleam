//// Example for the doc of `validation.ValidationError`.

import dream/http/validation.{type ValidationError, ValidationError}
import gleam/option

pub fn email_error() -> ValidationError {
  // Example error when expecting string but got number
  ValidationError(
    message: "Expected String but found Int at user.email",
    field: option.Some("user.email"),
    expected: option.Some("String"),
    found: option.Some("Int"),
  )
}
