# Core Patterns

**Patterns for scaling your application logic beyond simple CRUD.**

## Operations (Business Logic)

Controllers should be thin. When logic gets complex (validation, multiple database calls, external services), use an **Operation**.

### The Problem

Your controller action needs to:
1. Validate input
2. Get data from database
3. Check authorization
4. Update multiple records
5. Call external service
6. Send email
7. Index in search

That's too much for a controller. Extract it to an operation.

### The Solution

```gleam
// operations/create_user.gleam
pub fn execute(services: Services, params: Params) -> Result(User, Error) {
  use _ <- result.try(validate(params))
  use user <- result.try(user_model.create(services.db, params))
  let _ = mailer.send_welcome(services.mailer, user)
  Ok(user)
}
```

### Why Operations?

**Testable without HTTP.** No mocking requests, no building Request objects—just test the business logic:

```gleam
pub fn create_user_test() {
  let services = test_services()
  let params = UserParams(email: "test@example.com", name: "Test")
  
  let result = create_user.execute(services, params)
  
  assert Ok(user) = result
  assert "test@example.com" = user.email
}
```

**Reusable.** Call the same operation from:
- API endpoints
- Background jobs
- CLI tasks
- Admin interfaces

**Clear separation.** Controllers handle HTTP. Operations handle business logic.

### When to Use Operations

✅ Use operations when:
- Coordinating 2+ models
- Complex business rules spanning entities
- Side effects (events, emails, search indexing)
- Logic you want to test without HTTP

❌ Don't use operations for:
- Simple CRUD (controller → model → view is fine)
- Single model operations
- Pure formatting (that's a view)

## Multi-Format Responses (JSON + HTML)

Serve API clients and browsers from the same controller.

### The Pattern

```gleam
pub fn show(request: Request, context: Context, services: Services) -> Response {
  // ... fetch data ...
  case format {
    "json" -> json_response(ok, view.to_json(data))
    "html" -> html_response(ok, view.to_html(data))
    "htmx" -> html_response(ok, view.card(data)) // Partial for dynamic updates
  }
}
```

### Why Multi-Format?

**Don't build two separate backends.** One app, multiple views:
- API clients get JSON
- Browsers get HTML
- HTMX requests get partial HTML

**Same business logic.** Models and operations don't care about format. Views handle formatting.

### Implementation

Views handle the formatting:

```gleam
// views/product_view.gleam
pub fn respond(product: Product, request: Request) -> Response {
  case get_format(request) {
    Some("json") -> json_response(status.ok, to_json(product))
    Some("csv") -> text_response(status.ok, to_csv(product))
    _ -> html_response(status.ok, to_html(product))
  }
}

pub fn to_json(product: Product) -> String
pub fn to_html(product: Product) -> String
pub fn to_csv(product: Product) -> String
```

### Format Detection

Detect format from:
- Query parameter: `?format=json`
- Accept header: `Accept: application/json`
- Path extension: `/products/123.json`

## Next Steps

- [Operations Guide](../guides/operations.md) - Complete guide with examples
- [Multiple Formats Guide](../guides/multiple-formats.md) - JSON, HTML, HTMX patterns
- [Examples](../examples.md) - See patterns in action

