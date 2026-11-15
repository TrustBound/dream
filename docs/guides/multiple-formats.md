# Multiple Formats

Serve the same data in different formats (JSON, HTML, CSV) from the same controller. This allows you to build a rich web UI and a JSON API with a single backend.

## Concept

**One Controller, Multiple Views.**

Instead of separate `api/users_controller.gleam` and `web/users_controller.gleam`, you have one `users_controller.gleam` that responds with the requested format.

## Setup

For HTML templates we use Matcha, a small Rust program that reads
`.matcha` files and generates Gleam modules with `render` functions.

At a high level:

- You write templates in `.matcha` files (HTML plus a bit of template
  syntax).
- You run the `matcha` binary at the project root.
- It walks the project, finds `.matcha` files, and generates
  `.gleam` modules next to them.
- You import those generated modules from your views and call
  `render(...)`.

You can either download a prebuilt Matcha binary or build it from source
if you already use Rust tooling.

A typical Makefile integration looks like this:

```makefile
matcha:
	@matcha

build:
	@make matcha
	@gleam build
```

Then you can run `make build` and know both templates and Gleam code are
up to date.

## Pattern: JSON + HTML (Side-by-Side)

This pattern is powerful for modern web apps. You can serve:
1.  **JSON** for mobile apps or external API clients.
2.  **HTML** for the browser.
3.  **HTMX Partials** for dynamic page updates without full reloads.

### Controller Implementation

Use a helper function to switch formats based on the request. `detect_format` is shown in [Example with Headers](#example-with-headers).

#### The show controller <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/multiple_formats_guide_tasks.gleam#L22-L49"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn show(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    find_task(services.tasks, id)
  }

  case result {
    Ok(task) -> respond_with_format(task, detect_format(request))
    Error(error) -> respond_with_error(error)
  }
}

fn respond_with_format(task: Task, format: String) -> Response {
  case format {
    // HTMX request asking for just the card partial
    "htmx" -> html_response(ok, task_view.card(task))

    // Full HTML page
    "html" -> html_response(ok, task_view.page(task))

    // Default to JSON
    _ -> json_response(ok, task_view.to_json(task))
  }
}
```

### View Layer

Your view module handles the different presentations. For HTML rendering, we use a layered template composition approach that keeps markup consistent and reusable.

#### The task view <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/multiple_formats_guide_task_view.gleam#L8-L27"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
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

1.  **URL Extension:** `/tasks/1.json`, `/tasks/1.html` (`get_param` puts the extension in `PathParam.format`, and `require_int` reads `1`)
2.  **Accept Header:** `Accept: application/json`
3.  **Custom Header:** `HX-Request: true` (common with HTMX)

### Example with Headers

#### Format from the extension or the headers <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/multiple_formats_guide_tasks.gleam#L51-L66"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// /tasks/1.json and /tasks/1.html: Dream puts the extension in
// PathParam.format
pub fn detect_format(request: Request) -> String {
  case get_param(request, "id") {
    Ok(PathParam(format: Some(format), ..)) -> format
    _ -> detect_format_from_headers(request)
  }
}

fn detect_format_from_headers(request: Request) -> String {
  case get_header(request.headers, "HX-Request") {
    Some("true") -> "htmx"
    // Default
    _ -> "json"
  }
}
```

## Working Example

See [examples/tasks](../../examples/tasks/) for a complete application demonstrating:
- Side-by-side JSON and HTML
- HTMX for dynamic updates
- Shared business logic


