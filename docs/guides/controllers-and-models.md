# Controllers & Models

Dream encourages a clean separation of concerns using the Model-View-Controller (MVC) pattern.

## Controllers

Controllers handle HTTP requests. They are pure functions that:
1.  Parse parameters from the request.
2.  Call models to fetch or update data.
3.  Call views to format the response.
4.  Return a `Response`.

**Signature:**
```gleam
fn(Request, Context, Services) -> Response
```

**Example:**

```gleam
import dream/http.{require_int, type Request, type Response, html_response, ok}
import gleam/result
import models/task/task_model
import utilities/response_helpers
import views/task_view

pub fn show(
  request: Request,
  _context: Context,
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

This controller uses `require_int` to safely extract and validate the path parameter. The `use` syntax keeps the code flat and readable, avoiding nested `case` statements. If the parameter is missing or invalid, `require_int` returns a `BadRequest` error. All errors are handled uniformly through `response_helpers.handle_error`, which maps `dream.Error` types to appropriate HTTP responses.

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

**Example: Getting a Single Record**

```gleam
import dream/http/error.{type Error, NotFound, InternalServerError}
import dream_postgres/client.{type Connection}
import dream_postgres/query
import models/task/sql
import types/task.{type Task}

pub fn get(db: Connection, id: Int) -> Result(Task, Error) {
  case sql.get_task(db, id) |> query.first_row() {
    Ok(row) -> Ok(row_to_task(row))
    Error(query.NotFound) -> Error(NotFound("Task not found"))
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

fn row_to_task(row: sql.GetTaskRow) -> Task {
  Task(
    id: row.id,
    title: row.title,
    completed: row.completed,
  )
}
```

**Example: Listing Multiple Records**

```gleam
import dream/http/error.{type Error, InternalServerError}
import dream_postgres/client.{type Connection}
import dream_postgres/query
import gleam/list
import models/user/sql
import types/user.{type User}

pub fn list(db: Connection) -> Result(List(User), Error) {
  case sql.list_users(db) |> query.all_rows() {
    Ok(rows) -> Ok(list.map(rows, row_to_user))
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

fn row_to_user(row: sql.ListUsersRow) -> User {
  User(
    id: row.id,
    name: row.name,
    email: row.email,
  )
}
```

**Example: Creating a Record**

```gleam
import dream/http/error.{type Error, InternalServerError}
import dream_postgres/client.{type Connection}
import dream_postgres/query
import models/user/sql
import types/user.{type User}

pub fn create(
  db: Connection,
  name: String,
  email: String,
) -> Result(User, Error) {
  case sql.create_user(db, name, email) |> query.first_row() {
    Ok(row) -> Ok(row_to_user(row))
    Error(_) -> Error(InternalServerError("Database error"))
  }
}

fn row_to_user(row: sql.CreateUserRow) -> User {
  User(
    id: row.id,
    name: row.name,
    email: row.email,
  )
}
```

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

**Example:**

```gleam
import types/task.{type Task}
import gleam/json

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

```gleam
import dream/http.{type Response, json_response, bad_request, unauthorized, forbidden, not_found, unprocessable_content, internal_server_error}
import dream/http/error

pub fn handle_error(err: Error) -> Response {
  case err {
    error.BadRequest(msg) -> 
      json_response(bad_request, error_json(msg))
    error.Unauthorized(_msg) -> 
      json_response(unauthorized, error_json("Unauthorized"))
    error.Forbidden(_msg) -> 
      json_response(forbidden, error_json("Forbidden"))
    error.NotFound(msg) -> 
      json_response(not_found, error_json(msg))
    error.UnprocessableContent(msg) -> 
      json_response(unprocessable_content, error_json(msg))
    error.InternalServerError(_msg) -> 
      json_response(internal_server_error, error_json("Internal server error"))
  }
}

fn error_json(message: String) -> String {
  "{\"error\": \"" <> message <> "\"}"
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

**Example:**

```gleam
pub fn show(
  request: Request,
  _context: Context,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    let db = services.database.connection
    use task <- result.try(task_model.get(db, id))
    Ok(task)
  }

  case result {
    Ok(task) -> {
      // Content negotiation based on format or Accept header
      case request.format {
        Some("json") -> json_response(ok, task_view.to_json(task))
        Some("html") -> html_response(ok, task_view.card(task, []))
        _ -> json_response(ok, task_view.to_json(task)) // Default
      }
    }
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

See the [Multiple Formats Guide](multiple-formats.md) for detailed content negotiation patterns.

## Further Reading

- [Architecture Reference](../reference/architecture.md) - MVC architecture overview
- [Operations Guide](operations.md) - Complex business logic patterns
- [Multiple Formats Guide](multiple-formats.md) - Content negotiation
- [Advanced Patterns](../learn/04-advanced-patterns.md) - When to use Operations
