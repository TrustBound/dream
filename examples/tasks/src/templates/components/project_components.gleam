//// Project-specific components

import gleam/int
import gleam/option
import gleam/string
import types/project.{type Project}
import templates/elements/card

pub fn project_card(project: Project) -> String {
  let content = project_card_content(project)
  card.render(
    card_id: "project-" <> int.to_string(project.id),
    card_content: content,
  )
}

fn project_card_content(project: Project) -> String {
  let title = "<h3><a href=\"/projects/" <> int.to_string(project.id) <> "\">" <> project.name <> "</a></h3>"

  let description_html = case project.description {
    option.Some(desc) -> "<p>" <> desc <> "</p>"
    option.None -> ""
  }

  let delete_button =
    "<button hx-delete=\"/projects/"
    <> int.to_string(project.id)
    <> "\" hx-target=\"closest article\" hx-swap=\"outerHTML\" hx-confirm=\"Delete this project?\">Delete</button>"

  title <> description_html <> delete_button
}

pub fn project_list(projects: List(Project)) -> String {
  let items =
    projects
    |> list_map(fn(project) {
      "<li>" <> project_card(project) <> "</li>"
    })
    |> string.join("\n")

  "<ul>" <> items <> "</ul>"
}

pub fn project_form() -> String {
  "<form hx-post=\"/projects\" hx-swap=\"beforebegin\">"
  <> "<label for=\"project-name\">Name<input id=\"project-name\" name=\"name\" type=\"text\" required></label>"
  <> "<label for=\"project-description\">Description<textarea id=\"project-description\" name=\"description\"></textarea></label>"
  <> "<label for=\"project-color\">Color<input id=\"project-color\" name=\"color\" type=\"color\"></label>"
  <> "<button type=\"submit\">Create Project</button>"
  <> "</form>"
}

// Helper
fn list_map(list: List(a), f: fn(a) -> b) -> List(b) {
  case list {
    [] -> []
    [head, ..tail] -> [f(head), ..list_map(tail, f)]
  }
}

