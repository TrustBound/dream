//// Form composition helpers

import gleam/int
import gleam/string
import templates/elements/button
import templates/elements/checkbox
import templates/elements/input
import templates/elements/option_item
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
    input_type: "text",
    input_value: value,
    label_text: label,
    placeholder: "",
    attributes: "",
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
    input_type: "date",
    input_value: value,
    label_text: label,
    placeholder: "",
    attributes: "",
  )
}

pub fn text_area(
  id: String,
  name: String,
  label: String,
  value: String,
) -> String {
  textarea.render(
    textarea_id: id,
    textarea_name: name,
    textarea_value: value,
    label_text: label,
    placeholder: "",
    attributes: "",
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
    attributes: "",
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
      let selected_attr = case value == current {
        True -> "selected"
        False -> ""
      }
      option_item.render(
        option_value: int.to_string(value),
        option_label: label,
        selected_attr: selected_attr,
      )
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
  button.render(
    button_id: id,
    button_type: "submit",
    button_text: text,
    attributes: "",
  )
}

pub fn regular_button(id: String, text: String) -> String {
  button.render(
    button_id: id,
    button_type: "button",
    button_text: text,
    attributes: "",
  )
}

// Helper to map over lists
fn list_map(list: List(a), f: fn(a) -> b) -> List(b) {
  case list {
    [] -> []
    [head, ..tail] -> [f(head), ..list_map(tail, f)]
  }
}
