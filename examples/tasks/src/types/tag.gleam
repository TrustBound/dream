//// Tag input type
////
//// The data of a new tag. dream_model generates the Tag record of a row
//// in models/tag.

import gleam/option.{type Option}

pub type TagData {
  TagData(name: String, color: Option(String))
}
