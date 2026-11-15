//// Templates guide: the view layer uses every layer

import snippets/templates_guide_components as task_components
import snippets/templates_guide_index as index
import snippets/templates_guide_layouts as layout_components
import snippets/templates_guide_task.{type Task}

// View layer (views/task_view.gleam)
pub fn index_page(tasks: List(Task)) -> String {
  // Components compose elements
  let task_list = task_components.task_list(tasks)

  // Pages compose components
  let content = index.render(task_form: "", task_list:)

  // Layouts wrap pages
  layout_components.build_page("Tasks", content)
}
