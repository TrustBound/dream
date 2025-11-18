//// Project composition - calls project templates

import gleam/int
import gleam/option
import gleam/string
import types/project.{type Project}
import templates/components/project_card
import templates/components/project_form
import templates/components/project_list
import templates/elements/delete_button
import templates/elements/list_item
import templates/elements/paragraph

pub fn project_card(project: Project) -> String {
  let project_id = int.to_string(project.id)
  let project_link = "/projects/" <> project_id
  
  let description_html = case project.description {
    option.Some(desc) -> paragraph.render(text_content: desc)
    option.None -> ""
  }
  
  let delete_btn = delete_button.render(
    entity_type: "projects",
    entity_id: project_id,
    confirm_msg: "Delete this project?",
  )
  
  project_card.render(
    project_id: project_id,
    project_name: project.name,
    project_link: project_link,
    description_html: description_html,
    delete_button: delete_btn,
  )
}

pub fn project_list(projects: List(Project)) -> String {
  let items =
    projects
    |> list_map(fn(project) {
      let card = project_card(project)
      list_item.render(item_content: card)
    })
    |> string.join("\n")
  
  project_list.render(list_items: items)
}

pub fn project_form_html() -> String {
  let fields = "" // TODO: build fields using form_components
  project_form.render(form_fields: fields)
}

// Helper
fn list_map(list: List(a), f: fn(a) -> b) -> List(b) {
  case list {
    [] -> []
    [head, ..tail] -> [f(head), ..list_map(tail, f)]
  }
}
