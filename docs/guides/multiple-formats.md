# Multiple Formats

Serve the same data in different formats (JSON, HTML, CSV) from the same controller. This allows you to build a rich web UI and a JSON API with a single backend.

## Concept

**One Controller, Multiple Views.**

Instead of separate `api/users_controller.gleam` and `web/users_controller.gleam`, you have one `users_controller.gleam` that responds with the requested format.

## Setup

Add Matcha for HTML templates:

```bash
gleam add marceau
```

## Pattern: JSON + HTML (Side-by-Side)

This pattern is powerful for modern web apps. You can serve:
1.  **JSON** for mobile apps or external API clients.
2.  **HTML** for the browser.
3.  **HTMX Partials** for dynamic page updates without full reloads.

### Controller Implementation

Use a helper function to switch formats based on the request.

```gleam
import dream/http.{require_int, type Request, type Response, json_response, html_response, ok}
import gleam/option.{type Option, Some, None}
import gleam/result
import utilities/response_helpers
import views/task_view
import models/task/task_model

pub fn show(
  request: Request,
  _context: Context,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    let db = services.database.connection
    use task <- result.try(task_model.get(db, id))
    let format = request.format
    Ok(#(task, format))
  }
  
  case result {
    Ok(#(task, format)) -> respond_with_format(task, format)
    Error(err) -> response_helpers.handle_error(err)
  }
}

fn respond_with_format(task: Task, format: Option(String)) -> Response {
  case format {
    // HTMX request asking for just the card partial
    Some("htmx") -> html_response(ok, task_view.card(task))
    
    // Full HTML page
    Some("html") -> html_response(ok, task_view.page(task))
    
    // Default to JSON
    _ -> json_response(ok, task_view.to_json(task))
  }
}
```

### View Layer

Your view module handles the different presentations. For HTML rendering, we use a layered template composition approach that keeps markup consistent and reusable.

```gleam
// views/task_view.gleam
import templates/components/layout_components
import templates/components/task_components
import templates/pages/index

// JSON representation
pub fn to_json(task: Task) -> String {
  json.object([
    #("id", json.int(task.id)),
    #("title", json.string(task.title)),
  ])
  |> json.to_string()
}

// HTML Partial (for HTMX or including in other pages)
pub fn card(task: Task, tags: List(Tag)) -> String {
  // Components compose elements into reusable pieces
  task_components.task_card(task, tags)
}

// Full HTML Page
pub fn index_page(
  tasks: List(Task),
  tags_by_task: List(#(Int, List(Tag))),
) -> String {
  // Components compose elements
  let list = task_components.task_list(tasks, tags_by_task)
  
  // Pages compose components
  let content = index.render(task_form: "", task_list: list)
  
  // Layouts wrap pages with consistent structure
  layout_components.build_page("Tasks", content)
}
```

**Template Composition Architecture:**

This pattern uses four layers to build HTML:

1. **Elements** (`templates/elements/*.matcha`): Low-level HTML components
   - Semantic HTML templates (buttons, inputs, cards, badges)
   - Compiled from Matcha templates
   - Reusable across the entire application

2. **Components** (`templates/components/*.gleam`): Compose elements into reusable pieces
   - Gleam functions that combine multiple elements
   - Handle presentation logic (formatting, conditional rendering)
   - Examples: `task_card()`, `task_form()`, `task_list()`

3. **Pages** (`templates/pages/*.matcha` or `.gleam`): Compose components into full pages
   - Page-level templates that combine multiple components
   - Examples: `index.render()`, `show.render()`

4. **Layouts** (`templates/layouts/*.gleam`): Page structure (nav, footer, main wrapper)
   - Wraps pages with consistent structure
   - Handles navigation, footer, scripts
   - Example: `layout_components.build_page(title, content)`

This layered approach solves real-world problems:
- **Eliminates duplication**: Reuse elements and components instead of copying markup
- **Consistent styling**: Changes to elements propagate automatically
- **Type safety**: Full Gleam type checking throughout the template pipeline
- **Maintainability**: Clear separation of concerns makes changes predictable

See [Template Composition](../guides/templates.md) for a complete guide to this pattern.

## Content Negotiation

You can detect the desired format via:

1.  **URL Extension:** `/tasks/1.json`, `/tasks/1.html` (Dream parses this into `request.format`)
2.  **Accept Header:** `Accept: application/json`
3.  **Custom Header:** `HX-Request: true` (common with HTMX)

### Example with Headers

```gleam
import dream/http.{type Request, get_header}
import gleam/option

fn detect_format(request: Request) -> String {
  case request.format {
    Some(f) -> f
    None -> detect_format_from_headers(request)
  }
}

fn detect_format_from_headers(request: Request) -> String {
  case get_header(request.headers, "HX-Request") {
    Some("true") -> "htmx"
    None -> "json" // Default
  }
}
```

## Working Example

See [examples/tasks](../../examples/tasks/) for a complete application demonstrating:
- Side-by-side JSON and HTML
- HTMX for dynamic updates
- Shared business logic


