//// Task-specific components

import gleam/int
import gleam/option.{type Option}
import gleam/string
import types/tag.{type Tag}
import types/task.{type Task}
import templates/components/form_components
import templates/components/tag_components
import templates/elements/card
import templates/elements/icon

pub fn task_card(task: Task, tags: List(Tag)) -> String {
  let content = task_card_content(task, tags)
  card.render(
    card_id: "task-" <> int.to_string(task.id),
    card_content: content,
  )
}

fn task_card_content(task: Task, tags: List(Tag)) -> String {
  let completed_status = case task.completed {
    True -> "checked"
    False -> ""
  }

  let checkbox_html =
    "<input type=\"checkbox\" "
    <> completed_status
    <> " hx-post=\"/tasks/"
    <> int.to_string(task.id)
    <> "/toggle.htmx\" hx-target=\"closest article\" hx-swap=\"outerHTML\">"

  let title_html = "<h3>" <> task.title <> "</h3>"

  let priority_badge = priority_indicator(task.priority)

  let due_date_html = case task.due_date {
    option.Some(date) -> "<small>" <> icon.render("calendar") <> " " <> date <> "</small>"
    option.None -> ""
  }

  let tags_html = tag_components.tag_list(tags)

  let delete_button =
    "<button hx-delete=\"/tasks/"
    <> int.to_string(task.id)
    <> "\" hx-target=\"closest article\" hx-swap=\"outerHTML\" hx-confirm=\"Delete this task?\">Delete</button>"

  checkbox_html
  <> title_html
  <> priority_badge
  <> due_date_html
  <> tags_html
  <> delete_button
}

fn priority_indicator(priority: Int) -> String {
  let text = case priority {
    1 -> "🔴 Urgent"
    2 -> "🟠 High"
    3 -> "🟢 Normal"
    4 -> "🔵 Low"
    _ -> "Normal"
  }
  "<mark>" <> text <> "</mark>"
}

pub fn task_list(tasks: List(Task), tags_by_task: List(#(Int, List(Tag)))) -> String {
  let items =
    tasks
    |> list_map(fn(task) {
      let task_tags = find_tags_for_task(task.id, tags_by_task)
      "<li>" <> task_card(task, task_tags) <> "</li>"
    })
    |> string.join("\n")

  "<ul id=\"task-list\">" <> items <> "</ul>"
}

fn find_tags_for_task(task_id: Int, tags_by_task: List(#(Int, List(Tag)))) -> List(Tag) {
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
  "<form hx-post=\"/tasks\" hx-target=\"#task-list\" hx-swap=\"beforeend\" hx-on::after-request=\"if(event.detail.successful) this.reset()\">"
  <> form_components.text_field("title", "title", "Title", "")
  <> form_components.text_area("description", "description", "Description", "")
  <> form_components.priority_select("priority", "priority", 3)
  <> form_components.date_field("due_date", "due_date", "Due Date", "")
  <> form_components.submit_button("submit", "Add Task")
  <> "</form>"
}

fn edit_form(task: Task) -> String {
  let description = option.unwrap(task.description, "")
  let due_date = option.unwrap(task.due_date, "")

  "<form hx-put=\"/tasks/"
  <> int.to_string(task.id)
  <> ".htmx\" hx-target=\"closest article\" hx-swap=\"outerHTML\">"
  <> form_components.text_field("title", "title", "Title", task.title)
  <> form_components.text_area("description", "description", "Description", description)
  <> form_components.priority_select("priority", "priority", task.priority)
  <> form_components.date_field("due_date", "due_date", "Due Date", due_date)
  <> form_components.submit_button("submit", "Save")
  <> "</form>"
}

// Helper
fn list_map(list: List(a), f: fn(a) -> b) -> List(b) {
  case list {
    [] -> []
    [head, ..tail] -> [f(head), ..list_map(tail, f)]
  }
}

