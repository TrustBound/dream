//// Multiple formats guide: one view module, three presentations

import gleam/json
import snippets/templates_guide_components as task_components
import snippets/templates_guide_layouts as layout_components
import snippets/templates_guide_task.{type Task}

// JSON representation
pub fn to_json(task: Task) -> String {
  json.object([
    #("id", json.int(task.id)),
    #("title", json.string(task.title)),
  ])
  |> json.to_string()
}

// HTML Partial (for HTMX or including in other pages)
pub fn card(task: Task) -> String {
  // Components compose elements into reusable pieces
  task_components.task_card(task)
}

// Full HTML Page
pub fn page(task: Task) -> String {
  // Layouts wrap components with consistent structure
  layout_components.build_page(task.title, card(task))
}
