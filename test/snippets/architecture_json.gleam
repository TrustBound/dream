//// Architecture reference: dream_json
////
//// Encodes optional fields as their value or as null.

import dream_json/json_encoders
import gleam/json
import gleam/option.{type Option}

pub type Profile {
  Profile(email: Option(String), age: Option(Int))
}

pub fn profile_to_json(profile: Profile) -> String {
  json.object([
    #("email", json_encoders.optional_string(profile.email)),
    #("age", json_encoders.optional_int(profile.age)),
  ])
  |> json.to_string()
}
