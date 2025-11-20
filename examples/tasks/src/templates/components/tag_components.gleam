//// Tag composition - calls tag templates

import gleam/int
import gleam/string
import templates/components/tag_list
import templates/components/tag_selector
import templates/elements/badge
import templates/elements/tag_button
import types/tag.{type Tag}
import utilities/html_helpers.{htmx_attribute, join_attributes}

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
      tag_list.render(badges_html: badges)
    }
  }
}

pub fn tag_selector_html(tags: List(Tag), task_id: Int) -> String {
  let task_id_str = int.to_string(task_id)
  let options =
    tags
    |> list_map(fn(tag) {
      tag_button.render(
        task_id: task_id_str,
        tag_id: int.to_string(tag.id),
        tag_name: tag.name,
      )
    })
    |> string.join("")

  // Create tag form - creates tag and adds to task, then refreshes selector
  let create_form_attrs =
    join_attributes([
      htmx_attribute("post", "/tasks/" <> task_id_str <> "/tags/create"),
      htmx_attribute("target", "#tag-selector-" <> task_id_str),
      htmx_attribute("swap", "innerHTML"),
    ])

  let create_tag_form =
    "<form "
    <> create_form_attrs
    <> ">\n    <input type=\"text\" name=\"tag_name\" placeholder=\"New tag name\" required>\n    <button type=\"submit\">Create</button>\n  </form>"

  tag_selector.render(tag_buttons: options, create_tag_form: create_tag_form)
}

// Helper
fn list_map(list: List(a), f: fn(a) -> b) -> List(b) {
  case list {
    [] -> []
    [head, ..tail] -> [f(head), ..list_map(tail, f)]
  }
}
