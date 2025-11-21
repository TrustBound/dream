//// Task composition - calls task templates

import gleam/int
import gleam/option.{type Option}
import gleam/string
import templates/components/form_components
import templates/components/tag_components
import templates/components/task_card
import templates/components/task_edit_form
import templates/components/task_editor
import templates/components/task_form
import templates/components/task_list
import templates/elements/button
import templates/elements/checkbox
import templates/elements/date_display
import templates/elements/icon
import templates/elements/input
import templates/elements/list_item
import templates/elements/priority_badge
import templates/elements/textarea
import types/tag.{type Tag}
import types/task.{type Task}
import utilities/html_helpers.{htmx_attribute, htmx_vals, join_attributes}

pub fn task_card(task: Task, tags: List(Tag)) -> String {
  let task_id = int.to_string(task.id)

  // Double-click is now handled via onclick in template
  let card_attrs = ""

  let checked_attr = case task.completed {
    True -> "checked"
    False -> ""
  }

  let checkbox_attrs =
    join_attributes([
      htmx_attribute("post", "/tasks/" <> task_id <> "/toggle"),
      htmx_attribute("target", "closest article"),
      htmx_attribute("swap", "outerHTML"),
    ])

  let checkbox_html =
    checkbox.render(
      checkbox_id: "checkbox-" <> task_id,
      checkbox_name: "completed",
      label_text: "",
      checked_attr: checked_attr,
      attributes: checkbox_attrs,
    )

  let priority_text = case task.priority {
    1 -> "Urgent"
    2 -> "High"
    3 -> "Normal"
    4 -> "Low"
    _ -> "Normal"
  }
  let priority_badge_html = priority_badge.render(badge_text: priority_text)

  let due_date_html = case task.due_date {
    option.Some(date) -> {
      let icon_html = icon.render(icon_name: "calendar")
      date_display.render(icon_html: icon_html, date_text: date)
    }
    option.None -> ""
  }

  let tags_html = tag_components.tag_list(tags)

  let edit_btn_attrs =
    join_attributes([
      htmx_attribute("get", "/tasks/" <> task_id <> "/edit"),
      htmx_attribute("target", "closest article"),
      htmx_attribute("swap", "outerHTML"),
    ])

  let edit_btn =
    button.render(
      button_id: "edit-" <> task_id,
      button_type: "button",
      button_text: "Edit",
      attributes: edit_btn_attrs,
    )

  let delete_btn_attrs =
    join_attributes([
      htmx_attribute("delete", "/tasks/" <> task_id),
      htmx_attribute("target", "closest article"),
      htmx_attribute("swap", "outerHTML"),
      htmx_attribute("confirm", "Delete this task?"),
    ])

  let delete_btn =
    button.render(
      button_id: "delete-" <> task_id,
      button_type: "button",
      button_text: "Delete",
      attributes: delete_btn_attrs,
    )

  task_card.render(
    task_id: task_id,
    attributes: card_attrs,
    checkbox_html: checkbox_html,
    title: task.title,
    priority_badge: priority_badge_html,
    due_date_html: due_date_html,
    tags_html: tags_html,
    edit_button: edit_btn,
    delete_button: delete_btn,
  )
}

pub fn task_list(
  tasks: List(Task),
  tags_by_task: List(#(Int, List(Tag))),
) -> String {
  let items =
    tasks
    |> list_map(fn(task) {
      let task_tags = find_tags_for_task(task.id, tags_by_task)
      let card = task_card(task, task_tags)
      list_item.render(item_content: card)
    })
    |> string.join("\n")

  task_list.render(list_items: items)
}

fn find_tags_for_task(
  task_id: Int,
  tags_by_task: List(#(Int, List(Tag))),
) -> List(Tag) {
  case tags_by_task {
    [] -> []
    [#(id, tags), ..rest] ->
      case id == task_id {
        True -> tags
        False -> find_tags_for_task(task_id, rest)
      }
  }
}

pub fn task_form(task: Option(Task)) -> String {
  case task {
    option.Some(t) -> edit_form(t)
    option.None -> create_form()
  }
}

pub fn task_editor(task: Task, _tags: List(Tag)) -> String {
  let task_id = int.to_string(task.id)

  let editor_attrs = ""

  // Checkbox (disabled during editing)
  let checkbox_html =
    checkbox.render(
      checkbox_id: "checkbox-" <> task_id,
      checkbox_name: "completed",
      label_text: "",
      checked_attr: case task.completed {
        True -> "checked"
        False -> ""
      },
      attributes: "disabled",
    )

  // Title input with auto-save
  let title_attrs =
    join_attributes([
      htmx_attribute("post", "/tasks/" <> task_id <> "/update-field"),
      htmx_attribute("trigger", "input changed delay:500ms"),
      htmx_vals("{\"field\": \"title\"}"),
      htmx_attribute("swap", "none"),
    ])

  let title_input_html =
    input.render(
      input_id: "title-" <> task_id,
      input_name: "title",
      input_type: "text",
      input_value: task.title,
      label_text: "",
      placeholder: "Task Title Here",
      attributes: title_attrs,
    )

  // Description textarea with auto-save
  let description_value = option.unwrap(task.description, "")
  let description_attrs =
    join_attributes([
      htmx_attribute("post", "/tasks/" <> task_id <> "/update-field"),
      htmx_attribute("trigger", "input changed delay:500ms"),
      htmx_vals("{\"field\": \"description\"}"),
      htmx_attribute("swap", "none"),
    ])

  let description_textarea_html =
    textarea.render(
      textarea_id: "description-" <> task_id,
      textarea_name: "description",
      textarea_value: description_value,
      label_text: "",
      placeholder: "Description Can be typed here",
      attributes: description_attrs,
    )

  // Due date input with auto-save
  let due_date_value = option.unwrap(task.due_date, "")
  let due_date_attrs =
    join_attributes([
      htmx_attribute("post", "/tasks/" <> task_id <> "/update-field"),
      htmx_attribute("trigger", "change delay:500ms"),
      htmx_vals("{\"field\": \"due_date\"}"),
      htmx_attribute("swap", "none"),
    ])

  let due_date_input_html =
    input.render(
      input_id: "due-date-" <> task_id,
      input_name: "due_date",
      input_type: "date",
      input_value: due_date_value,
      label_text: "",
      placeholder: "",
      attributes: due_date_attrs,
    )

  // Tag button
  let tag_button_attrs =
    join_attributes([
      htmx_attribute("get", "/tasks/" <> task_id <> "/tags"),
      htmx_attribute("target", "#tag-selector-" <> task_id),
      htmx_attribute("swap", "innerHTML"),
    ])

  let tag_button_html =
    button.render(
      button_id: "tag-button-" <> task_id,
      button_type: "button",
      button_text: "Tags",
      attributes: tag_button_attrs,
    )

  let tag_selector_html = ""

  task_editor.render(
    task_id: task_id,
    attributes: editor_attrs,
    checkbox_html: checkbox_html,
    title_input_html: title_input_html,
    description_textarea_html: description_textarea_html,
    due_date_input_html: due_date_input_html,
    tag_button_html: tag_button_html,
    tag_selector_html: tag_selector_html,
  )
}

fn create_form() -> String {
  let title_field = form_components.text_field("title", "title", "Title", "")
  let description_field =
    form_components.text_area("description", "description", "Description", "")
  let priority_field =
    form_components.priority_select("priority", "priority", 3)
  let due_date_field =
    form_components.date_field("due_date", "due_date", "Due Date", "")

  let fields =
    title_field
    <> "\n"
    <> description_field
    <> "\n"
    <> priority_field
    <> "\n"
    <> due_date_field

  task_form.render(
    form_action: "/tasks",
    form_method: "post",
    form_target: "#task-list",
    form_swap: "beforeend",
    form_attrs: "hx-on::after-request=\"if(event.detail.successful) this.reset()\"",
    form_fields: fields,
    submit_text: "Add Task",
  )
}

fn edit_form(task: Task) -> String {
  let task_id = int.to_string(task.id)
  let title_value = task.title
  let description_value = option.unwrap(task.description, "")
  let due_date_value = option.unwrap(task.due_date, "")

  let title_field =
    form_components.text_field("title", "title", "Title", title_value)
  let description_field =
    form_components.text_area(
      "description",
      "description",
      "Description",
      description_value,
    )
  let priority_field =
    form_components.priority_select("priority", "priority", task.priority)
  let due_date_field =
    form_components.date_field(
      "due_date",
      "due_date",
      "Due Date",
      due_date_value,
    )

  let fields =
    title_field
    <> "\n"
    <> description_field
    <> "\n"
    <> priority_field
    <> "\n"
    <> due_date_field

  task_edit_form.render(
    task_id: task_id,
    form_action: "/tasks/" <> task_id <> ".htmx",
    form_fields: fields,
    submit_text: "Save",
  )
}

// Helper
fn list_map(list: List(a), f: fn(a) -> b) -> List(b) {
  case list {
    [] -> []
    [head, ..tail] -> [f(head), ..list_map(tail, f)]
  }
}
