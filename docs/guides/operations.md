# Operations

When your application logic gets complex, Controllers can become bloated. The **Operations** pattern helps organize business logic into reusable, testable units.

## What is an Operation?

An Operation is a function that encapsulates a specific business action. It sits between the Controller and the Model.

**Use Operations when:**
- You need to coordinate multiple models or services.
- You have complex business rules (validation, state transitions).
- The logic is reused across multiple controllers (e.g., API and Web UI).

## Structure

An operation typically takes `Services` and parameters, and returns a `Result`.

**Example: Reordering Tasks**

This operation updates the position of a task, which might involve shifting other tasks.

```gleam
import dream_postgres/client.{type Connection}
import models/task/task_model
import types/task.{type Task}

pub fn execute(
  db: Connection,
  task_id: Int,
  new_position: Int,
) -> Result(Task, Error) {
  // In a real app, this might also:
  // 1. Check permissions
  // 2. Shift other tasks to make room
  // 3. Log the activity
  // 4. Broadcast an event via WebSocket
  
  task_model.update_position(db, task_id, new_position)
}
```

## Using in a Controller

The controller becomes a simple coordinator:

```gleam
import operations/reorder_tasks

pub fn reorder(
  request: Request,
  _context: Context,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int
  
  // Parse body for new_position...
  let new_position = 5

  case reorder_tasks.execute(services.db, id, new_position) {
    Ok(_) -> empty_response(status.ok)
    Error(_) -> errors.internal_error()
  }
}
```

## Benefits

1.  **Testability:** You can unit test the operation without mocking HTTP requests.
2.  **Reusability:** Call the same operation from a REST API, a GraphQL resolver, or a background job.
3.  **Clarity:** The controller reads like a summary of what's happening, not the implementation details.

## Advanced: Service Coordination

Operations are the perfect place to coordinate multiple services.

```gleam
pub fn publish_post(services: Services, post_id: Int) -> Result(Post, Error) {
  use post <- result.try(post_model.publish(services.db, post_id))
  
  // Side effects coordinated here
  let _ = search_index.add(services.opensearch, post)
  let _ = notifications.send_subscribers(services.mailer, post)
  
  Ok(post)
}
```

Use the `use` syntax (Gleam's equivalent of `do` notation) to chain operations flatly, avoiding nested cases.
