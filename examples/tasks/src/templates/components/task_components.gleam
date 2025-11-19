//// Task composition - calls task templates

import gleam/int
import gleam/option.{type Option}
import gleam/string
import templates/components/form_components
import templates/components/tag_components
import templates/components/task_card
import templates/components/task_edit_form
import templates/components/task_form
import templates/components/task_list
import templates/elements/checkbox_htmx
import templates/elements/date_display
import templates/elements/delete_button
import templates/elements/edit_button
import templates/elements/icon
import templates/elements/list_item
import templates/elements/priority_badge
import types/tag.{type Tag}
import types/task.{type Task}

pub fn task_card(task: Task, tags: List(Tag)) -> String {
  let task_id = int.to_string(task.id)

  let checked_attr = case task.completed {
    True -> "checked"
    False -> ""
  }
  let checkbox_html =
    checkbox_htmx.render(task_id: task_id, checked_attr: checked_attr)

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

  let edit_btn =
    edit_button.render(
      entity_type: "tasks",
      entity_id: task_id,
    )

  let delete_btn =
    delete_button.render(
      entity_type: "tasks",
      entity_id: task_id,
      confirm_msg: "Delete this task?",
    )

  task_card.render(
    task_id: task_id,
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

fn create_form() -> String {
  let title_field =
    form_components.text_field("title", "title", "Title", "")
  let description_field =
    form_components.text_area("description", "description", "Description", "")
  let priority_field = form_components.priority_select("priority", "priority", 3)
  let due_date_field = form_components.date_field("due_date", "due_date", "Due Date", "")

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
    form_components.text_area("description", "description", "Description", description_value)
  let priority_field =
    form_components.priority_select("priority", "priority", task.priority)
  let due_date_field =
    form_components.date_field("due_date", "due_date", "Due Date", due_date_value)

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
