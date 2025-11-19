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
import dream/http/request.{get_param}
import dream/http/response.{html_response}
import dream/http/status
import models/task/task_model
import views/task_view
import views/errors

pub fn show(
  request: Request,
  _context: Context,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int

  case task_model.get(services.db, id) {
    Ok(task) -> html_response(status.ok, task_view.show(task))
    Error(_) -> errors.not_found("Task not found")
  }
}
```

### Best Practices
- **Keep it thin:** Controllers should coordinate, not calculate. Move business logic to Models or Operations.
- **No nested cases:** Use helper functions to handle complex flows.
- **Explicit dependencies:** Access services via the `services` parameter.

## Models

Models handle data access. They are functions that:
1.  Take a database connection.
2.  Execute SQL queries (using `dream_postgres` and `squirrel`).
3.  Convert database rows to domain types.
4.  Return a `Result`.

**Example:**

```gleam
import dream_postgres/client.{type Connection}
import dream_postgres/query
import models/task/sql
import types/task.{type Task}

pub fn get(db: Connection, id: Int) -> Result(Task, Error) {
  case sql.get_task(db, id) |> query.first_row() {
    Ok(row) -> Ok(row_to_task(row))
    Error(err) -> Error(err)
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

### Best Practices
- **Return Domain Types:** Don't leak SQL row types to the controller. Convert them in the model.
- **Explicit Connection:** Pass `db: Connection` explicitly.
- **Type-Safe SQL:** Use `squirrel` to generate type-safe SQL functions.

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

## Putting It Together

1.  **Router** matches URL → calls **Controller**.
2.  **Controller** parses ID → calls **Model**.
3.  **Model** queries DB → returns **Domain Object**.
4.  **Controller** passes Object → calls **View**.
5.  **View** formats Object → returns **String**.
6.  **Controller** wraps String → returns **Response**.

This flow keeps each layer focused and testable.
