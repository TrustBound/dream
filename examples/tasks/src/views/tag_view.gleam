//// Tag view - presentation layer

import gleam/json
import gleam/option
import templates/components/tag_components
import types/tag.{type Tag}

/// Render tag badge
pub fn badge(tag: Tag) -> String {
  tag_components.tag_badge(tag)
}

/// Render list of tag badges
pub fn badge_list(tags: List(Tag)) -> String {
  tag_components.tag_list(tags)
}

/// Convert tag to JSON
pub fn to_json(tag: Tag) -> String {
  json.object([
    #("id", json.int(tag.id)),
    #("name", json.string(tag.name)),
    #("color", json_option_string(tag.color)),
  ])
  |> json.to_string
}

/// Convert list of tags to JSON
pub fn list_to_json(tags: List(Tag)) -> String {
  json.array(tags, tag_to_json_object)
  |> json.to_string
}

fn tag_to_json_object(tag: Tag) -> json.Json {
  json.object([
    #("id", json.int(tag.id)),
    #("name", json.string(tag.name)),
    #("color", json_option_string(tag.color)),
  ])
}

fn json_option_string(opt: option.Option(String)) -> json.Json {
  case opt {
    option.Some(val) -> json.string(val)
    option.None -> json.null()
  }
}
