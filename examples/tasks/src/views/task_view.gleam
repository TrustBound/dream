//// Task view - presentation layer

import gleam/json.{type Json, array, bool, int, null, object, string, to_string}
import gleam/option.{type Option, None, Some, map}
import models/tag.{type Tag}
import models/task.{type Task}
import templates/components/layout_components.{build_page}
import templates/components/task_components.{task_card, task_editor, task_form}
import templates/pages/index.{render}
import utilities/dates.{date_to_string, timestamp_to_string}

/// Render task card for HTMX swap
pub fn card(task: Task, tags: List(Tag)) -> String {
  task_card(task, tags)
}

/// Render task edit form
pub fn edit_form(task: Task) -> String {
  task_form(Some(task))
}

/// Render task editor (inline editing)
pub fn editor(task: Task, tags: List(Tag)) -> String {
  task_editor(task, tags)
}

/// Render full index page with tasks
pub fn index_page(
  tasks: List(Task),
  tags_by_task: List(#(Int, List(Tag))),
) -> String {
  let list = task_components.task_list(tasks, tags_by_task)
  let content = render(task_list: list)

  build_page("Tasks", content)
}

/// Convert task to JSON
pub fn to_json(task: Task) -> String {
  object([
    #("id", int(task.id)),
    #("title", string(task.title)),
    #("description", json_option_string(task.description)),
    #("completed", bool(task.completed)),
    #("priority", int(task.priority)),
    #("due_date", json_option_string(map(task.due_date, date_to_string))),
    #("position", int(task.position)),
    #("project_id", json_option_int(task.project_id)),
    #("created_at", string(timestamp_to_string(task.created_at))),
    #("updated_at", string(timestamp_to_string(task.updated_at))),
  ])
  |> to_string
}

/// Convert list of tasks to JSON
pub fn list_to_json(tasks: List(Task)) -> String {
  array(tasks, task_to_json_object)
  |> to_string
}

fn task_to_json_object(task: Task) -> Json {
  object([
    #("id", int(task.id)),
    #("title", string(task.title)),
    #("description", json_option_string(task.description)),
    #("completed", bool(task.completed)),
    #("priority", int(task.priority)),
    #("due_date", json_option_string(map(task.due_date, date_to_string))),
    #("position", int(task.position)),
    #("project_id", json_option_int(task.project_id)),
    #("created_at", string(timestamp_to_string(task.created_at))),
    #("updated_at", string(timestamp_to_string(task.updated_at))),
  ])
}

fn json_option_string(opt: Option(String)) -> Json {
  case opt {
    Some(val) -> string(val)
    None -> null()
  }
}

fn json_option_int(opt: Option(Int)) -> Json {
  case opt {
    Some(val) -> int(val)
    None -> null()
  }
}
