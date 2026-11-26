//// Task view - presentation layer

import gleam/json.{string}
import gleam/option.{map}
import models/tag.{type Tag}
import models/task.{type Task}
import templates/components/layout_components
import templates/components/task_components
import templates/pages/index
import utilities/dates.{date_to_string, timestamp_to_string}

/// Render task card for HTMX swap
pub fn card(task: Task, tags: List(Tag)) -> String {
  task_components.task_card(task, tags)
}

/// Render task edit form
pub fn edit_form(task: Task) -> String {
  task_components.task_form(option.Some(task))
}

/// Render task editor (inline editing)
pub fn editor(task: Task, tags: List(Tag)) -> String {
  task_components.task_editor(task, tags)
}

/// Render full index page with tasks
pub fn index_page(
  tasks: List(Task),
  tags_by_task: List(#(Int, List(Tag))),
) -> String {
  let list = task_components.task_list(tasks, tags_by_task)
  let content = index.render(task_list: list)

  layout_components.build_page("Tasks", content)
}

/// Convert task to JSON
pub fn to_json(task: Task) -> String {
  json.object([
    #("id", json.int(task.id)),
    #("title", json.string(task.title)),
    #("description", json_option_string(task.description)),
    #("completed", json.bool(task.completed)),
    #("priority", json.int(task.priority)),
    #("due_date", json_option_string(map(task.due_date, date_to_string))),
    #("position", json.int(task.position)),
    #("project_id", json_option_int(task.project_id)),
    #("created_at", string(timestamp_to_string(task.created_at))),
    #("updated_at", string(timestamp_to_string(task.updated_at))),
  ])
  |> json.to_string
}

/// Convert list of tasks to JSON
pub fn list_to_json(tasks: List(Task)) -> String {
  json.array(tasks, task_to_json_object)
  |> json.to_string
}

fn task_to_json_object(task: Task) -> json.Json {
  json.object([
    #("id", json.int(task.id)),
    #("title", json.string(task.title)),
    #("description", json_option_string(task.description)),
    #("completed", json.bool(task.completed)),
    #("priority", json.int(task.priority)),
    #("due_date", json_option_string(map(task.due_date, date_to_string))),
    #("position", json.int(task.position)),
    #("project_id", json_option_int(task.project_id)),
    #("created_at", string(timestamp_to_string(task.created_at))),
    #("updated_at", string(timestamp_to_string(task.updated_at))),
  ])
}

fn json_option_string(opt: option.Option(String)) -> json.Json {
  case opt {
    option.Some(val) -> json.string(val)
    option.None -> json.null()
  }
}

fn json_option_int(opt: option.Option(Int)) -> json.Json {
  case opt {
    option.Some(val) -> json.int(val)
    option.None -> json.null()
  }
}
