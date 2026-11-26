//// Example for the doc of `error.from_shared`.

import dream/http/error.{type Error, NotFound, from_shared}
import dream_errors

pub type StoreError {
  StoreDown
}

pub fn load_profile(
  store_result: Result(String, dream_errors.Error(StoreError)),
) -> Result(String, Error) {
  case store_result {
    Ok(profile) -> Ok(profile)
    Error(dream_errors.NotFound(..)) -> Error(NotFound("Profile not found"))
    Error(shared) -> Error(from_shared(shared))
  }
}
