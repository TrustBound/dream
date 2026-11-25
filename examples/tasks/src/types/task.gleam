//// Task input type
////
//// The data of a task that a form sends. dream_model generates the Task
//// record of a row in models/task.

import gleam/option.{type Option}

pub type TaskData {
  TaskData(
    title: String,
    description: Option(String),
    completed: Bool,
    priority: Int,
    due_date: Option(String),
    position: Int,
    project_id: Option(Int),
  )
}
