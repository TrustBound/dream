//// Example for the doc of `error.from_shared`.

import dream/http/error.{from_shared}
import dream_errors

pub type StoreError {
  StoreDown
}

pub fn load_profile(
  store_result: Result(String, dream_errors.Error(StoreError)),
) -> Result(String, error.Error) {
  case store_result {
    Ok(profile) -> Ok(profile)
    Error(dream_errors.NotFound(..)) ->
      Error(error.NotFound("Profile not found"))
    Error(shared) -> Error(from_shared(shared))
  }
}
