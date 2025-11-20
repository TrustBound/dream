//// Task domain type

import gleam/option.{type Option}

pub type Task {
  Task(
    id: Int,
    title: String,
    description: Option(String),
    completed: Bool,
    priority: Int,
    due_date: Option(String),
    position: Int,
    project_id: Option(Int),
    created_at: String,
    updated_at: String,
  )
}

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
