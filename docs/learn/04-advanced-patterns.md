# Lesson 4: Advanced Patterns

**Goal:** Learn when and how to use operations for business logic that spans more than one model

This lesson uses real code from the
[tasks example](https://github.com/TrustBound/dream/tree/3.0.0/examples/tasks).

## What You'll Learn

- When a controller does too much
- The operations pattern for business logic
- How an operation coordinates more than one model or step
- How the tasks example tests its operations
- When you need an operation, and when you do not

## Prerequisites

- [Lesson 3: Adding Auth](03-adding-auth.md) completed

## The Problem

The tasks example lets you type a new tag name on a task. To save it, the app must:

1. Find the tag with that name, or create it
2. Attach the tag to the task
3. Get all tags, so the page can show the updated tag selector

Each step is simple. Together they are a small workflow. If the controller does all of it, the controller mixes HTTP work with business rules.

## When to Use Operations

**Keep it in the controller:**

The project list in
[examples/tasks](https://github.com/TrustBound/dream/tree/3.0.0/examples/tasks/src)
calls one model and formats the result. It needs no operation:

### One model, one action <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/src/controllers/projects_controller.gleam#L18-L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn index(
  _request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  case project_model.list(services.db) {
    Ok(projects) ->
      http.html_response(http.ok, project_view.list_page(projects))
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

**Extract to operation:**

The task card shows a task and its tags. The data comes from two models. The controller does not call them one by one. It calls one operation:

### Two models, one operation <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/src/controllers/tasks_controller.gleam#L19-L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Show single task
pub fn show(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use task_id <- result.try(http.require_int(request, "task_id"))
    task_operations.get_task_with_tags(services.db, task_id)
  }

  case result {
    Ok(#(task, tags)) -> http.html_response(http.ok, task_view.card(task, tags))
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

**The controller stays simple:** It reads the parameters, calls the operation and returns a response.

**The operation handles the logic:** The business rules live in one place.

## Step 1: The Operation

The tag workflow lives in `src/operations/tag_operations.gleam`:

### Create and attach a tag <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/src/operations/tag_operations.gleam#L15-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Create a new tag and attach it to a task
///
/// Returns the newly created tag or an error.
pub fn create_and_attach(
  db: Connection,
  task_id: Int,
  tag_name: String,
) -> Result(Tag, Error) {
  let data = TagData(name: tag_name, color: option.None)

  use tag <- result.try(tag_model.get_or_create(db, data))
  use _ <- result.try(tag_model.add_to_task(db, task_id, tag.id))

  Ok(tag)
}
```

**What's happening:**

1. `tag_model.get_or_create` finds the tag with that name, or creates it.
2. `tag_model.add_to_task` attaches the tag to the task.
3. If a step fails, `result.try` stops and returns the error.

The operation knows nothing about HTTP. It takes a database connection and plain values, and it returns `Result(Tag, Error)`.

## Step 2: Use the Operation in the Controller

The controller in `src/controllers/tags_controller.gleam` calls the operation:

### The controller calls the operation <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/src/controllers/tags_controller.gleam#L60-L89"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Create tag and add to task (returns updated tag selector HTML)
pub fn create_and_add_to_task(
  request: http.Request,
  _context: TasksContext,
  services: Services,
) -> http.Response {
  let result = {
    use task_id <- result.try(http.require_int(request, "task_id"))
    use form <- result.try(http.require_form(request))
    use tag_name <- result.try(http.require_field(form, "tag_name"))

    use _ <- result.try(tag_operations.create_and_attach(
      services.db,
      task_id,
      tag_name,
    ))

    use all_tags <- result.try(tag_operations.list_all(services.db))
    Ok(#(all_tags, task_id))
  }

  case result {
    Ok(#(all_tags, task_id)) ->
      http.html_response(
        http.ok,
        tag_components.tag_selector_html(all_tags, task_id),
      )
    Error(err) -> response_helpers.handle_error(err)
  }
}
```

The controller is thin:

- It reads the task ID and the tag name with `require_int`, `require_form` and `require_field`. Each one returns a `Result`.
- It calls the operation, which returns `dream.Error` on failure.
- It sends every error to `response_helpers.handle_error`.
- It builds the response.

The workflow lives in the operation. The controller and the operation use the same error type (`dream.Error`), so the controller does not map errors.

## When You Need Operations

**Use operations when:**
- An action uses 2 or more models
- An action has more than one step that must happen in order
- A business rule spans more than one entity
- More than one controller needs the same workflow

**Don't use operations when:**
- The action is simple CRUD (one model, one action)
- There are no business rules
- Nothing needs coordination

**Most controllers don't need operations.** Extract one only when a controller does too much.

## Testing Operations

The tasks example tests its operations through the HTTP API, with Cucumber scenarios in
[test/integration/features/tasks.feature](https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/test/integration/features/tasks.feature).
This scenario runs `create_and_attach` through the controller and then examines the database:

```gherkin
Scenario: Create and add tag to task in one operation
    Given a task exists with title "New Tag Task"
    When I send a POST request to "/tasks/1/tags/create" with form data "tag_name=Urgent"
    Then the response status should be 200
    And there should be 1 tags in the database
    And the task with id 1 should have tag with id 1
```

To run the scenarios, run `make test-integration` in `examples/tasks`. It starts Postgres with Docker, starts the server and runs the Cucumber tests.

## What You Learned

✅ Operations coordinate more than one model or step  
✅ Extract from controllers when a controller does too much  
✅ Business rules live in operations  
✅ Controllers stay simple: params → operation → response  
✅ Unified error handling with `dream.Error` keeps controllers thin
✅ Most actions don't need operations (only workflows do)

## You've Completed the Learning Path!

You now understand:
- Router and controllers (Lesson 1)
- Services and code organization (Lesson 2)
- Context and middleware (Lesson 3)
- Operations for business logic (Lesson 4)

## What's Next?

**Build something:**
- [REST API Guide](../guides/rest-api.md) - Production-ready API patterns
- [Multiple Formats Guide](../guides/multiple-formats.md) - JSON, HTML, CSV responses
- [Deployment Guide](../guides/deployment.md) - Running in production

**Deep dives:**
- [Dream vs Mist](../reference/dream-vs-mist.md) - See what Dream provides
- [Architecture](../reference/architecture.md) - How it all fits together

**Examples:**
- [Tasks Example](../../examples/tasks/) - Full application with operations
- [Multi-Format Example](../../examples/multi_format/) - JSON, HTML, CSV responses
- [All Examples](../../examples/) - Complete working applications

---

**Working example:** See [examples/tasks/](../../examples/tasks/) for the complete runnable code with operations.
