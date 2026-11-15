//// Naming conventions: Validation
////
//// `validate_{noun}` checks data and returns a `Result` that tells what is
//// wrong.

import dream/http.{type Cookie}
import gleam/option.{type Option, None, Some}
import gleam/string

pub type Signup {
  Signup(email: String, password: String)
}

pub type SignupError {
  MissingEmail
  PasswordTooShort
}

pub fn validate_signup(signup: Signup) -> Result(Signup, List(SignupError)) {
  let errors =
    [email_error(signup.email), password_error(signup.password)]
    |> option.values
  case errors {
    [] -> Ok(signup)
    _ -> Error(errors)
  }
}

pub fn validate_cookie(cookie: Cookie) -> Result(Cookie, String) {
  case cookie.secure {
    True -> Ok(cookie)
    False -> Error("The " <> cookie.name <> " cookie must be secure")
  }
}

fn email_error(email: String) -> Option(SignupError) {
  case string.contains(email, "@") {
    True -> None
    False -> Some(MissingEmail)
  }
}

fn password_error(password: String) -> Option(SignupError) {
  case string.length(password) >= 12 {
    True -> None
    False -> Some(PasswordTooShort)
  }
}
