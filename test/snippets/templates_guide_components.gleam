//// Templates guide: components compose elements
////
//// Shown in excerpts in docs/guides/templates.md.

import gleam/int
import gleam/list
import gleam/string
import snippets/templates_guide_badge as badge
import snippets/templates_guide_button as button
import snippets/templates_guide_checkbox as checkbox
import snippets/templates_guide_input as input
import snippets/templates_guide_task.{type Tag, type Task}
import snippets/templates_guide_task_card as task_card

pub fn save_button() -> String {
  button.render(
    button_id: "submit-btn",
    button_type: "submit",
    button_text: "Save Task",
    attributes: "hx-post=\"/tasks\"",
  )
}

pub fn task_card(task: Task) -> String {
  let task_id = int.to_string(task.id)

  // Compose elements
  let checkbox_html =
    checkbox.render(
      checkbox_id: "checkbox-" <> task_id,
      checkbox_name: "completed",
      label_text: "",
      checked_attr: checked_attribute(task.completed),
      attributes: htmx_attributes(task_id),
    )

  let title_input =
    input.render(
      input_id: "title-" <> task_id,
      input_name: "title",
      input_value: task.title,
      attributes: "readonly",
    )

  // Use compiled Matcha template for structure
  task_card.render(
    task_id: task_id,
    checkbox_html: checkbox_html,
    title_input: title_input,
    tags_html: render_tags(task.tags),
  )
}

pub fn task_list(tasks: List(Task)) -> String {
  list.map(tasks, task_card)
  |> string.concat
}

fn checked_attribute(completed: Bool) -> String {
  case completed {
    True -> "checked"
    False -> ""
  }
}

fn htmx_attributes(task_id: String) -> String {
  "hx-post=\"/tasks/" <> task_id <> "/toggle\""
}

fn render_tags(tags: List(Tag)) -> String {
  list.map(tags, fn(tag) { badge.render(label: tag.name) })
  |> string.concat
}
