//// Form composition helpers

import gleam/int
import gleam/option.{type Option}
import gleam/string
import templates/elements/button
import templates/elements/checkbox
import templates/elements/input
import templates/elements/select
import templates/elements/textarea

pub fn text_field(
  id: String,
  name: String,
  label: String,
  value: String,
) -> String {
  input.render(
    input_id: id,
    input_name: name,
    label_text: label,
    input_value: value,
    input_type: "text",
  )
}

pub fn date_field(
  id: String,
  name: String,
  label: String,
  value: String,
) -> String {
  input.render(
    input_id: id,
    input_name: name,
    label_text: label,
    input_value: value,
    input_type: "date",
  )
}

pub fn text_area(id: String, name: String, label: String, value: String) -> String {
  textarea.render(
    textarea_id: id,
    textarea_name: name,
    label_text: label,
    textarea_value: value,
  )
}

pub fn checkbox_field(
  id: String,
  name: String,
  label: String,
  is_checked: Bool,
) -> String {
  let checked_attr = case is_checked {
    True -> "checked"
    False -> ""
  }
  checkbox.render(
    checkbox_id: id,
    checkbox_name: name,
    label_text: label,
    checked_attr: checked_attr,
  )
}

pub fn priority_select(id: String, name: String, current: Int) -> String {
  let options = [
    #(1, "Urgent"),
    #(2, "High"),
    #(3, "Normal"),
    #(4, "Low"),
  ]

  let options_html =
    options
    |> list_map(fn(opt) {
      let #(value, label) = opt
      let selected = case value == current {
        True -> " selected"
        False -> ""
      }
      "<option value=\""
      <> int.to_string(value)
      <> "\""
      <> selected
      <> ">"
      <> label
      <> "</option>"
    })
    |> string.join("")

  select.render(
    select_id: id,
    select_name: name,
    label_text: "Priority",
    options_html: options_html,
  )
}

pub fn submit_button(id: String, text: String) -> String {
  button.render(button_id: id, button_text: text, button_type: "submit")
}

pub fn regular_button(id: String, text: String) -> String {
  button.render(button_id: id, button_text: text, button_type: "button")
}

// Helper to map over lists
fn list_map(list: List(a), f: fn(a) -> b) -> List(b) {
  case list {
    [] -> []
    [head, ..tail] -> [f(head), ..list_map(tail, f)]
  }
}

