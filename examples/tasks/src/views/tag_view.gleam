//// Tag view - presentation layer

import gleam/json.{type Json, array, int, null, object, string, to_string}
import gleam/option.{type Option, None, Some}
import models/tag.{type Tag}
import templates/components/tag_components.{tag_badge, tag_list}

/// Render tag badge
pub fn badge(tag: Tag) -> String {
  tag_badge(tag)
}

/// Render list of tag badges
pub fn badge_list(tags: List(Tag)) -> String {
  tag_list(tags)
}

/// Convert tag to JSON
pub fn to_json(tag: Tag) -> String {
  object([
    #("id", int(tag.id)),
    #("name", string(tag.name)),
    #("color", json_option_string(tag.color)),
  ])
  |> to_string
}

/// Convert list of tags to JSON
pub fn list_to_json(tags: List(Tag)) -> String {
  array(tags, tag_to_json_object)
  |> to_string
}

fn tag_to_json_object(tag: Tag) -> Json {
  object([
    #("id", int(tag.id)),
    #("name", string(tag.name)),
    #("color", json_option_string(tag.color)),
  ])
}

fn json_option_string(opt: Option(String)) -> Json {
  case opt {
    Some(val) -> string(val)
    None -> null()
  }
}
