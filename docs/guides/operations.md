# Operations

When your application logic gets complex, Controllers can become
bloated. The **Operations** pattern helps organize business logic into
reusable, testable units.

This guide is for you if:

- You have controllers that feel “too smart” or too long.
- You are coordinating several services (database, email, search,
  websockets) in one place.
- You want business logic that can be reused from HTTP, background jobs,
  or other entrypoints.

We will show what an Operation is, when to introduce one, and how it
changes your controllers.

## What is an Operation?

An Operation is a function that encapsulates a specific business action. It sits between the Controller and the Model.

**Use Operations when:**
- You need to coordinate multiple models or services.
- You have complex business rules (validation, state transitions).
- The logic is reused across multiple controllers (e.g., API and Web UI).

## Structure

An Operation is just a **function**. Typically it:

- Takes `Services` and the input it needs (IDs, payloads, etc.).
- Calls models and other services.
- Returns a `Result(success_value, Error)`, with `Error` from
  `dream/http/error`, so controllers can handle errors uniformly.

**Example: Reordering Tasks**

This operation moves a task to a new position and shifts the other tasks. An unknown task gives `NotFound`, and a position outside the list gives `BadRequest`.

### The reorder_task operation <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/operations_guide_tasks.gleam#L23-L40"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn reorder_task(
  services: Services,
  task_id: Int,
  new_position: Int,
) -> Result(List(Task), Error) {
  // In a real app, this might also:
  // 1. Check permissions
  // 2. Save the new order in the database
  // 3. Log the activity
  // 4. Broadcast an event via WebSocket
  use task <- result.try(find_task(services.tasks, task_id))
  use Nil <- result.try(check_position(services.tasks, new_position))
  let other_tasks =
    list.filter(services.tasks, fn(other) { other.id != task_id })
  // Shift the other tasks to make room
  let #(before, after) = list.split(other_tasks, new_position - 1)
  Ok(list.flatten([before, [task], after]))
}
```

## Using in a Controller

The controller becomes a simple coordinator:

### The reorder controller <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/operations_guide_tasks.gleam#L42-L58"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn reorder(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    use form <- result.try(require_form(request))
    use new_position <- result.try(require_field_int(form, "position"))
    reorder_task(services, id, new_position)
  }

  case result {
    Ok(tasks) -> json_response(ok, task_ids_to_json(tasks))
    Error(failure) -> respond_with_error(failure)
  }
}
```

This controller uses `require_int` to safely extract the path parameter
and `require_field_int` to read `position` from the form body, then
calls the operation. The `use` syntax keeps the code flat and
readable.

All errors from the parameters and from the operation (which returns
`Result(_, Error)`) flow into the final `case result`.
`respond_with_error` turns each one into an HTTP response with
`error.to_status_code` and `error.message`.

The important shift is:

- Before: controller both **decides** what to do and **does** it.
- After: controller **decides** what to do, Operation **does** it.

## Benefits

1.  **Testability:** You can unit test the operation without mocking HTTP requests.
2.  **Reusability:** Call the same operation from a REST API, a GraphQL resolver, or a background job.
3.  **Clarity:** The controller reads like a summary of what's happening, not the implementation details.

## Advanced: Service Coordination

Operations are the perfect place to coordinate multiple services.

### The publish_post operation <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/operations_guide_posts.gleam#L21-L31"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn publish_post(services: Services, post_id: Int) -> Result(Post, Error) {
  use post <- result.try(find_post(services.posts, post_id))
  let published_post = Post(..post, published: True)

  // Side effects coordinated here. A failure stops the chain and comes
  // back to the controller as an Error.
  use Nil <- result.try(services.add_to_search_index(published_post))
  use Nil <- result.try(services.notify_subscribers(published_post))

  Ok(published_post)
}
```

Use the `use` syntax (Gleam's equivalent of `do` notation) to chain operations flatly, avoiding nested cases.

Do not discard the result of a side effect with `let _ =`. If the search index or the mailer fails, nobody then sees the error. In the example, each side effect returns a `Result`, and a failure comes back to the controller.

**Important:** Operations should return `Result(_, Error)` to keep error handling consistent across the application. This allows controllers to handle all errors uniformly without needing to map between different error types.
