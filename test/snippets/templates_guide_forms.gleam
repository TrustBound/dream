//// Templates guide: the new-task form component

import snippets/templates_guide_button as button
import snippets/templates_guide_input as input
import snippets/templates_guide_task_form as task_form_template

pub fn task_form() -> String {
  let title_input =
    input.render(
      input_id: "new-title",
      input_name: "title",
      input_value: "",
      attributes: "required",
    )
  let save_button =
    button.render(
      button_id: "submit-btn",
      button_type: "submit",
      button_text: "Save Task",
      attributes: "",
    )
  task_form_template.render(title_input:, save_button:)
}
