# Controllers & Models

Dream encourages a clean separation of concerns using the
Model-View-Controller (MVC) pattern.

This guide is for you if:

- You know basic Gleam (functions, types, pattern matching).
- You are new to Dream and want to see **where things go** in a real
  app.

We will explain controllers, models, and views in plain language and
show how data flows between them.

## Controllers

Controllers handle HTTP requests. They are pure functions that:
1.  Parse parameters from the request.
2.  Call models to fetch or update data.
3.  Call views to format the response.
4.  Return a `Response`.

#### The controller signature <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/controllers_guide_controller.gleam#L27-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>
```gleam
pub type Controller(context, services) =
  fn(Request, context, services) -> Response
```

In words:

- `Request` – everything about the incoming HTTP request (method, path,
  headers, body).
- `Context` – per-request data you carry around (like current user,
  request id).
- `Services` – long-lived application dependencies (database pool, HTTP
  clients, caches).
- `Response` – what will be sent back to the client.

Dream’s type system makes sure that **every controller** in a router has
this shape (with your specific `Context` and `Services` types).

#### A controller that shows a task <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/controllers_guide_controller.gleam#L1-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/context.{type AppContext}
import dream/http.{type Request, type Response, html_response, ok, require_int}
import gleam/result
import snippets/controllers_guide_response_helpers as response_helpers
import snippets/controllers_guide_services.{type Services}
import snippets/controllers_guide_task_model as task_model
import snippets/controllers_guide_task_view as task_view

pub fn show(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    let db = services.database.connection
    use task <- result.try(task_model.get(db, id))
    Ok(task)
  }

  case result {
    Ok(task) -> html_response(ok, task_view.show(task))
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

This controller uses `require_int` to safely extract and validate the
path parameter. If the parameter is missing or invalid,
`require_int(request, "id")` returns a `Result` with a
`BadRequest` error.

The `use` syntax is Gleam’s way of working with `Result` values without
nesting many `case` expressions. You can read this block:

#### The use chain in the controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/controllers_guide_controller.gleam#L14-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  let result = {
    use id <- result.try(require_int(request, "id"))
    let db = services.database.connection
    use task <- result.try(task_model.get(db, id))
    Ok(task)
  }
```

as:

1. Try to extract and validate `id` from the request.
2. If that works, call `task_model.get`.
3. If both steps succeed, return `Ok(task)`.
4. If any step fails, short-circuit with that error.

All errors end up in the final `case result` and are mapped to HTTP
responses by `response_helpers.handle_error`.

### Best Practices
- **Keep it thin:** Controllers should coordinate, not calculate. Move business logic to Models or Operations.
- **No nested cases:** Use flat `use` chains instead of nested `case` statements.
- **Explicit dependencies:** Access services via the `services` parameter.
- **Unified error handling:** Use `dream.Error` types and `response_helpers.handle_error` for consistent error responses.

### When to Use Operations

For simple CRUD operations, controllers can call models directly. But when business logic gets complex, use the **Operations** pattern instead.

**Keep it in the controller when:**
- Simple CRUD (create, read, update, delete)
- Single model operation
- Direct request → model → view flow

**Move to an Operation when:**
- Coordinating multiple models or services
- Complex business rules or validation
- Reusable logic across multiple endpoints
- Side effects (indexing, notifications, events)

For example, creating a user might be simple enough for a controller, but publishing a post that updates the database, indexes in search, and sends notifications belongs in an Operation.

See the [Operations Guide](operations.md) and [Advanced Patterns](../learn/04-advanced-patterns.md) for detailed examples.

## Models

Models handle data access. They are functions that:
1.  Take a database connection.
2.  Execute SQL queries (using `dream_postgres` and `squirrel`).
3.  Convert database rows to domain types.
4.  Return a `Result`.

These examples come from the project model in the tasks example. Squirrel generates the `models/project/sql` module, and `dream_postgres/query` gives the `first_row()` and `all_rows()` helpers.

#### Getting a Single Record <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/src/models/project/project_model.gleam#L14-L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Get a single project by ID
pub fn get(db: Connection, project_id: Int) -> Result(Project, Error) {
  case sql.get_project(db, project_id) |> query.first_row() {
    Ok(row) -> Ok(row_to_project(row))
    Error(query.NotFound) -> Error(NotFound("Project not found"))
    Error(query.DatabaseError) -> Error(InternalServerError("Database error"))
  }
}
```

`query.first_row()` returns `query.NotFound` when the query gives no rows. The model maps it to a 404 error.

#### Listing Multiple Records <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/src/models/project/project_model.gleam#L23-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// List all projects
pub fn list(db: Connection) -> Result(List(Project), Error) {
  case sql.list_projects(db) |> query.all_rows() {
    Ok(rows) -> Ok(list.map(rows, list_row_to_project))
    Error(_) -> Error(InternalServerError("Database error"))
  }
}
```

#### Creating a Record <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/src/models/project/project_model.gleam#L31-L43"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Create a new project
pub fn create(db: Connection, data: ProjectData) -> Result(Project, Error) {
  let description = option.unwrap(data.description, "")
  let color = option.unwrap(data.color, "")

  case
    sql.create_project(db, data.name, description, color)
    |> query.first_row()
  {
    Ok(row) -> Ok(create_row_to_project(row))
    Error(_) -> Error(InternalServerError("Database error"))
  }
}
```

The controller decodes the request body into a `ProjectData` record. The model gives defaults to the optional fields and runs the insert.

#### Converting a Row <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/src/models/project/project_model.gleam#L53-L62"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// Convert Squirrel row to domain type
fn row_to_project(row: sql.GetProjectRow) -> Project {
  Project(
    id: row.id,
    name: row.name,
    description: row.description,
    color: row.color,
    created_at: timestamp_to_string(row.created_at),
  )
}
```

Each query has its own row type, so the model has one small function for each row type. The controller gets a `Project` and never sees a row.

### Best Practices
- **Return Domain Types:** Don't leak SQL row types to the controller. Convert them in the model.
- **Explicit Connection:** Pass `db: Connection` explicitly.
- **Type-Safe SQL:** Use `squirrel` to generate type-safe SQL functions.
- **Unified Errors:** Return `Result(_, dream.Error)` to keep error handling consistent across the application.
- **Use Query Helpers:** `dream_postgres/query` provides `first_row()` and `all_rows()` helpers that handle common query result patterns.

## Views

Views handle presentation. They are pure functions that:
1.  Take domain data.
2.  Return a formatted string (HTML, JSON, CSV).

#### A view that writes a task as JSON <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/controllers_guide_task_view.gleam#L1-L11"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import gleam/json
import snippets/controllers_guide_task.{type Task}

pub fn to_json(task: Task) -> String {
  json.object([
    #("id", json.int(task.id)),
    #("title", json.string(task.title)),
    #("completed", json.bool(task.completed)),
  ])
  |> json.to_string()
}
```

### Best Practices
- **Pure Functions:** Views should not have side effects.
- **Dumb Templates:** Logic belongs in the controller or model, not the view.
- **Multiple Formats:** Views can provide multiple format functions (to_json, to_html, to_csv) for the same data. See [Multiple Formats Guide](multiple-formats.md) for content negotiation patterns.

## Putting It Together

1.  **Router** matches URL → calls **Controller**.
2.  **Controller** parses ID → calls **Model**.
3.  **Model** queries DB → returns **Domain Object**.
4.  **Controller** passes Object → calls **View**.
5.  **View** formats Object → returns **String**.
6.  **Controller** wraps String → returns **Response**.

This flow keeps each layer focused and testable.

## Error Handling

Dream uses a unified error type (`dream.Error`) across the framework and application. This eliminates the need for error mapping and keeps controllers thin.

**Response Helpers Pattern:**

Create a `utilities/response_helpers.gleam` module to centralize error handling:

#### A response helpers module <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/controllers_guide_response_helpers.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http.{
  type Response, bad_request, forbidden, internal_server_error, json_response,
  not_found, unauthorized, unprocessable_content,
}
import dream/http/error.{type Error}
import gleam/json

pub fn handle_error(err: Error) -> Response {
  case err {
    error.BadRequest(msg) -> json_response(bad_request, error_json(msg))
    error.Unauthorized(_msg) ->
      json_response(unauthorized, error_json("Unauthorized"))
    error.Forbidden(_msg) -> json_response(forbidden, error_json("Forbidden"))
    error.NotFound(msg) -> json_response(not_found, error_json(msg))
    error.UnprocessableContent(msg) ->
      json_response(unprocessable_content, error_json(msg))
    error.InternalServerError(_msg) ->
      json_response(internal_server_error, error_json("Internal server error"))
  }
}

fn error_json(message: String) -> String {
  json.object([#("error", json.string(message))])
  |> json.to_string()
}
```

This pattern:
- **Centralizes error handling:** One place to update error response formats
- **Consistent responses:** All errors follow the same structure
- **Easy to customize:** Modify error messages or formats in one place
- **Type-safe:** Compile-time checking ensures all error cases are handled

Controllers simply call `response_helpers.handle_error(err)` instead of handling each error type individually.

## Multi-Format Responses

Controllers can serve the same data in different formats (JSON, HTML, CSV) based on the request. Views provide format-specific functions, and controllers use content negotiation to select the appropriate format.

#### A controller that picks the format from the path <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/controllers_guide_multi_format.gleam#L16-L49"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn show(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    let db = services.database.connection
    use task <- result.try(task_model.get(db, id))
    Ok(task)
  }

  case result {
    Ok(task) -> respond_with_format(task, requested_format(request))
    Error(err) -> response_helpers.handle_error(err)
  }
}

// The format comes from the path extension, such as /tasks/1.json
fn requested_format(request: Request) -> Option(String) {
  case get_param(request, "id") {
    Ok(param) -> param.format
    Error(_) -> None
  }
}

fn respond_with_format(task: Task, format: Option(String)) -> Response {
  case format {
    Some("json") -> json_response(ok, task_view.to_json(task))
    Some("html") -> html_response(ok, task_view.card(task))
    // Default
    _ -> json_response(ok, task_view.to_json(task))
  }
}
```

See the [Multiple Formats Guide](multiple-formats.md) for detailed content negotiation patterns.

## Further Reading

- [Architecture Reference](../reference/architecture.md) - MVC architecture overview
- [Operations Guide](operations.md) - Complex business logic patterns
- [Multiple Formats Guide](multiple-formats.md) - Content negotiation
- [Advanced Patterns](../learn/04-advanced-patterns.md) - When to use Operations
