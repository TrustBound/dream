import gleam/json
import snippets/controllers_guide_task.{type Task}

pub fn to_json(task: Task) -> String {
  json.object([
    #("id", json.int(task.id)),
    #("title", json.string(task.title)),
    #("completed", json.bool(task.completed)),
  ])
  |> json.to_string()
}

pub fn show(task: Task) -> String {
  "<h1>" <> task.title <> "</h1>"
}

pub fn card(task: Task) -> String {
  "<div class=\"task\">" <> task.title <> "</div>"
}
