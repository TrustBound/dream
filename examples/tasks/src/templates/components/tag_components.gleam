//// Tag-specific components

import gleam/int
import gleam/string
import types/tag.{type Tag}
import templates/elements/badge

pub fn tag_badge(tag: Tag) -> String {
  badge.render(badge_text: tag.name)
}

pub fn tag_list(tags: List(Tag)) -> String {
  case tags {
    [] -> ""
    _ -> {
      let badges =
        tags
        |> list_map(tag_badge)
        |> string.join(" ")
      "<footer>" <> badges <> "</footer>"
    }
  }
}

pub fn tag_selector(tags: List(Tag), task_id: Int) -> String {
  let options =
    tags
    |> list_map(fn(tag) {
      "<button hx-post=\"/tasks/"
      <> int.to_string(task_id)
      <> "/tags?tag_id="
      <> int.to_string(tag.id)
      <> "\" hx-target=\"closest article\" hx-swap=\"outerHTML\">"
      <> tag.name
      <> "</button>"
    })
    |> string.join("")

  "<details><summary>Add Tag</summary>" <> options <> "</details>"
}

// Helper
fn list_map(list: List(a), f: fn(a) -> b) -> List(b) {
  case list {
    [] -> []
    [head, ..tail] -> [f(head), ..list_map(tail, f)]
  }
}

