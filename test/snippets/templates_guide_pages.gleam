//// Templates guide: a page composes components

import snippets/templates_guide_components as task_components
import snippets/templates_guide_forms as form_components
import snippets/templates_guide_index as index
import snippets/templates_guide_task.{type Task}

pub fn index_page(tasks: List(Task)) -> String {
  // Components compose elements
  let task_list = task_components.task_list(tasks)
  let task_form = form_components.task_form()

  // Page composes components
  index.render(task_form:, task_list:)
}
