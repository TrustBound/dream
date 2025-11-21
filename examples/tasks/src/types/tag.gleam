//// Tag domain type

import gleam/option.{type Option}

pub type Tag {
  Tag(id: Int, name: String, color: Option(String))
}

pub type TagData {
  TagData(name: String, color: Option(String))
}
