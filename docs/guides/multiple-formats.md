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
import dream/http/response.{json_response, html_response}
import dream/http/status.{ok}
import dream/http/transaction.{type Request, type Response, get_param}
import gleam/option.{type Option, Some, None}
import views/task_view
import models/task/task_model

pub fn show(
  request: Request,
  _context: Context,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int
  
  case task_model.get(services.db, id) {
    Ok(task) -> respond_with_format(task, param.format)
    Error(_) -> errors.not_found()
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

Your view module handles the different presentations.

```gleam
// views/task_view.gleam

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
  // Uses Matcha template
  templates.task_card(task)
}

// Full HTML Page
pub fn page(task: Task) -> String {
  // Wraps the card in a layout
  layout.main(
    title: task.title,
    content: card(task)
  )
}
```

## Content Negotiation

You can detect the desired format via:

1.  **URL Extension:** `/tasks/1.json`, `/tasks/1.html` (Dream parses this into `param.format`)
2.  **Accept Header:** `Accept: application/json`
3.  **Custom Header:** `HX-Request: true` (common with HTMX)

### Example with Headers

```gleam
import dream/http/transaction.{get_header}

fn detect_format(request: Request, param: PathParam) -> String {
  case param.format {
    Some(f) -> f
    None -> check_headers(request)
  }
}

fn check_headers(request: Request) -> String {
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


