//// Architecture reference: a view
////
//// Pure functions that format a task as JSON or as HTML.

import gleam/json
import gleam/string
import snippets/architecture_task.{type Task}

pub fn to_json(task: Task) -> String {
  json.object([
    #("id", json.int(task.id)),
    #("title", json.string(task.title)),
    #("completed", json.bool(task.completed)),
  ])
  |> json.to_string()
}

pub fn to_html(task: Task) -> String {
  "<li class=\"task\">" <> escape_html(task.title) <> "</li>"
}

fn escape_html(text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
}
