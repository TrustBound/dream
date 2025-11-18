# Lesson 4: Advanced Patterns

**Time:** 45 minutes  
**Goal:** Learn when and how to use operations for complex business logic

You'll learn the operations pattern for coordinating multiple services.

## What You'll Learn

- When controllers get too complex
- Operations pattern for business logic
- Coordinating multiple services
- When you actually need this (vs when you don't)

## Prerequisites

- [Lesson 3: Adding Auth](03-adding-auth.md) completed

## The Problem

Your controller needs to publish a post, which requires:

1. Get the post from database
2. Verify user is the author (authorization)
3. Update post status to Published
4. Index the post in OpenSearch
5. Broadcast event via Server-Sent Events

That's 5 steps coordinating 3 services (Postgres, OpenSearch, SSE). **This is too much for a controller.**

## When to Use Operations

**Keep it in the controller:**
```gleam
import dream/http/response.{json_response, text_response}
import dream/http/status.{ok, not_found}
import dream/http/transaction.{type Request, type Response, get_param}
import dream/context.{type AppContext}
import models/user.{get}
import services.{type Services}
import views/user_view.{to_json}

// Simple: one model, one action
pub fn show(request: Request, context: AppContext, services: Services) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int
  
  case get(services.db, id) {
    Ok(user) -> json_response(ok, to_json(user))
    Error(_) -> text_response(not_found, "Not found")
  }
}
```

**Extract to operation:**
```gleam
import dream/http/response.{json_response}
import dream/http/status.{ok, forbidden, not_found, internal_server_error}
import dream/http/transaction.{type Request, type Response, get_param}
import context.{type AuthContext}
import gleam/option.{Some}
import operations/publish_post.{execute}
import services.{type Services}
import types/errors.{Unauthorized, NotFound}
import views/post_view.{to_json}

// Complex: multiple services, business rules, side effects
pub fn publish(request: Request, context: AuthContext, services: Services) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int
  let assert Some(user) = context.user
  
  case execute(id, user.id, services) {
    Ok(post) -> json_response(ok, to_json(post))
    Error(Unauthorized) -> json_response(forbidden, "{\"error\": \"Forbidden\"}")
    Error(NotFound) -> json_response(not_found, "{\"error\": \"Not found\"}")
    Error(_) -> json_response(internal_server_error, "{\"error\": \"Server error\"}")
  }
}
```

**The controller stays simple:** Extract params, call operation, map errors, return response.

**The operation handles complexity:** Business logic lives in one place.

## Step 1: Create the Operation

Create `src/operations/publish_post.gleam`:

```gleam
import gleam/result.{try}
import models/post as post_model
import models/event as event_model
import services.{type Services}
import types/errors.{type DataError, Unauthorized}
import types/post.{type Post}
import types/event.{type Event, PostPublished}

pub fn execute(
  post_id: Int,
  user_id: Int,
  services: Services,
) -> Result(Post, DataError) {
  use post <- try(post_model.get(services.db, post_id))
  use _ <- try(check_authorization(user_id, post))
  use published <- try(post_model.publish(services.db, post_id))
  
  let _ = log_publish_event(published, user_id, services)
  
  Ok(published)
}

fn check_authorization(user_id: Int, post: Post) -> Result(Nil, DataError) {
  case user_id == post.author_id {
    True -> Ok(Nil)
    False -> Error(Unauthorized)
  }
}

fn log_publish_event(
  post: Post,
  user_id: Int,
  services: Services,
) -> Result(Nil, DataError) {
  let publish_event = Event(
    event_type: PostPublished,
    user_id: user_id,
    post_id: post.id,
  )
  
  // Index in OpenSearch
  let _ = event_model.log(services.opensearch, publish_event)
  
  // Broadcast to SSE subscribers
  services.events.broadcast(publish_event)
  
  Ok(Nil)
}
```

**What's happening:**

Operations coordinate multiple services:
1. Fetch post (Postgres)
2. Check business rule (user is author)
3. Update post (Postgres)
4. Log event (OpenSearch)
5. Broadcast (SSE)

All business logic in one place, easy to test.

## Step 2: Use Operation in Controller

Create `src/controllers/posts_controller.gleam`:

```gleam
import dream/http/response.{json_response}
import dream/http/status.{ok, forbidden, not_found, internal_server_error}
import dream/http/transaction.{Request, Response, get_param}
import context.{AuthContext}
import operations/publish_post.{execute}
import services.{Services}
import types/errors.{Unauthorized, NotFound}
import views/post_view.{to_json}

pub fn publish(
  request: Request,
  context: AuthContext,
  services: Services,
) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int
  let assert Some(user) = context.user
  
  case execute(id, user.id, services) {
    Ok(post) -> json_response(ok, to_json(post))
    Error(Unauthorized) ->
      json_response(forbidden, error_json("Not the author"))
    Error(NotFound) ->
      json_response(not_found, error_json("Post not found"))
    Error(_) ->
      json_response(internal_server_error, error_json("Server error"))
  }
}

fn error_json(message: String) -> String {
  "{\"error\": \"" <> message <> "\"}"
}
```

The controller is clean:
- Extract parameters
- Call operation
- Map domain errors → HTTP status codes
- Build response

All complexity is in the operation.

## When You Need Operations

**Use operations when:**
- Coordinating 2+ models
- Business rules span multiple entities
- Side effects (events, search indexing, email)
- Complex workflows

**Don't use operations when:**
- Simple CRUD (one model, one action)
- No business rules
- No coordination needed

**Most controllers don't need operations.** Only extract them when controllers get too complex.

## Testing Operations

Operations are easier to test than fat controllers:

```gleam
// Helper functions for testing (implement in test_helpers.gleam)
// - test_services() -> Services
// - create_test_post(Services) -> Post

pub fn publish_post_with_valid_user_returns_published_test() {
  // Arrange
  let services = test_services()
  let post = create_test_post(services)
  let user_id = post.author_id
  
  // Act
  let result = publish_post.execute(post.id, user_id, services)
  
  // Assert
  assert Ok(published) = result
  assert published.status == Published
}

pub fn publish_post_with_wrong_user_returns_unauthorized_test() {
  // Arrange
  let services = test_services()
  let post = create_test_post(services)
  let wrong_user_id = 999
  
  // Act
  let result = publish_post.execute(post.id, wrong_user_id, services)
  
  // Assert
  assert Error(Unauthorized) = result
}
```

Test the business logic without HTTP concerns.

## What You Learned

✅ Operations coordinate multiple services  
✅ Extract from controllers when complexity grows  
✅ Business rules live in operations  
✅ Controllers stay simple: params → operation → response  
✅ Most apps don't need operations (only for complex workflows)

## You've Completed the Learning Path!

You now understand:
- Router and controllers (Lesson 1)
- Services and code organization (Lesson 2)
- Context and middleware (Lesson 3)
- Operations for complex logic (Lesson 4)

## What's Next?

**Build something:**
- [REST API Guide](../guides/rest-api.md) - Production-ready API patterns
- [Multiple Formats Guide](../guides/multiple-formats.md) - JSON, HTML, CSV responses
- [Deployment Guide](../guides/deployment.md) - Running in production

**Deep dives:**
- [Dream vs Mist](../reference/dream-vs-mist.md) - See what Dream provides
- [Architecture](../reference/architecture.md) - How it all fits together

**Examples:**
- [CMS Example](../../examples/cms/) - Full application with operations
- [Multi-Format Example](../../examples/multi_format/) - JSON, HTML, CSV responses
- [All Examples](../../examples/) - Complete working applications

---

**Working example:** See [examples/cms/](../../examples/cms/) for the complete runnable code with operations.

