# Multi-Format Responses

**Learn how to serve the same data in multiple formats (JSON, HTML, HTMX, CSV) using Dream's PathParam and format detection.**

## Overview

Modern web applications often need to serve the same data in different formats:
- **HTML** for browsers
- **JSON** for APIs
- **HTMX partials** for dynamic updates
- **CSV** for exports
- **Streaming** for large datasets

Dream makes this clean and explicit using PathParam's format detection via file extensions.

## How It Works

### Format Detection via Extensions

Dream's `PathParam` automatically extracts format extensions from URLs:

- `/products/123` → `format: None` (default HTML)
- `/products/123.json` → `format: Some("json")`
- `/products/123.htmx` → `format: Some("htmx")`
- `/products/123.csv` → `format: Some("csv")`

### The Pattern

1. **Models** convert data to strings (all formats serialize to strings or streams)
2. **Controllers** detect format and call the right model converter
3. **Response builders** wrap strings with appropriate Content-Type headers

## Complete Example

### 1. Create Matcha Templates

**Full page template** (`views/products/show.matcha`):

```matcha
{> import sql.{type GetProductRow}
{> import gleam/int
{> import gleam/float
{> with product as GetProductRow

<!DOCTYPE html>
<html lang="en">
<head>
  <title>{{ product.name }}</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css">
</head>
<body>
  <main>
    <article>
      <header>
        <i data-lucide="package"></i>
        <h2>{{ product.name }}</h2>
      </header>
      <section>
        <dl>
          <dt>Price</dt>
          <dd>${{ float.to_string(product.price) }}</dd>
          <dt>Stock</dt>
          <dd>{{ int.to_string(product.stock) }} units</dd>
        </dl>
      </section>
    </article>
  </main>
  <script src="https://unpkg.com/lucide@latest"></script>
  <script>lucide.createIcons();</script>
</body>
</html>
```

**HTMX partial** (`views/products/card.matcha`):

```matcha
{> import sql.{type GetProductRow}
{> import gleam/float
{> with product as GetProductRow

<article>
  <header>
    <i data-lucide="package"></i>
    <h3>{{ product.name }}</h3>
  </header>
  <dl>
    <dt>Price</dt>
    <dd>${{ float.to_string(product.price) }}</dd>
  </dl>
</article>
```

Compile with: `matcha`

### 2. Model Calls Templates

```gleam
// examples/multi_format/src/models/product.gleam

import views/products/show as show_view
import views/products/card
import gleam/json

/// Convert product to JSON string
pub fn to_json(product: sql.GetProductRow) -> String {
  json.object([
    #("id", json.int(product.id)),
    #("name", json.string(product.name)),
    #("price", json.float(product.price)),
  ])
  |> json.to_string()
}

/// Convert product to full HTML page (uses Matcha template)
pub fn to_html(product: sql.GetProductRow) -> String {
  show_view.render(product: product)
}

/// Convert product to HTMX partial (uses Matcha template)
pub fn to_htmx(product: sql.GetProductRow) -> String {
  card.render(product: product)
}

/// Convert product to CSV row
pub fn to_csv(product: sql.GetProductRow) -> String {
  int.to_string(product.id) <> "," 
    <> product.name <> "," 
    <> float.to_string(product.price)
}
```

### 3. Controller with Flat Case Pattern

```gleam
// examples/multi_format/src/controllers/products_controller.gleam

import dream/core/http/transaction.{
  type PathParam, type Request, type Response, 
  get_param, html_response, json_response,
}
import dream/utilities/query
import models/product

pub fn show(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  case get_param(request, "id") {
    Error(_) -> bad_request_response()
    Ok(param) -> show_with_param(param, services)
  }
}

fn show_with_param(param: PathParam, services: Services) -> Response {
  case param.as_int {
    Error(_) -> bad_request_response()
    Ok(id) -> show_product(id, param, services)
  }
}

fn show_product(id: Int, param: PathParam, services: Services) -> Response {
  let db = services.database.connection
  case sql.get_product(db, id) |> query.first_row() {
    Ok(product) -> render_product(product, param)
    Error(query.NotFound) -> errors.not_found("Product not found")
    Error(query.DatabaseError) -> errors.internal_error()
  }
}

fn render_product(product: sql.GetProductRow, param: PathParam) -> Response {
  case param.format {
    option.Some("json") -> json_response(ok_status(), to_json(product))
    option.Some("htmx") -> html_response(ok_status(), to_htmx(product))
    option.Some("csv") -> text_response(ok_status(), to_csv(product))
    _ -> html_response(ok_status(), to_html(product))
  }
}
```

### 4. Router

```gleam
// examples/multi_format/src/router.gleam

import dream/core/router.{route, router}
import dream/core/http/transaction.{Get}

pub fn create_router() -> Router(AppContext, Services) {
  router
  |> route(Get, "/products/:id", products_controller.show, [])
}
```

That's it! This single route now handles:
- `GET /products/1` → HTML page
- `GET /products/1.json` → JSON response
- `GET /products/1.htmx` → HTMX partial
- `GET /products/1.csv` → CSV data

## Streaming Responses

For large datasets, use streaming:

```gleam
/// Convert list to CSV stream
pub fn list_to_csv_stream(
  products: List(sql.ListProductsRow),
) -> yielder.Yielder(BitArray) {
  let header = "id,name,price\n"
  
  yielder.from_list([header, ..list.map(products, to_csv_row)])
  |> yielder.map(fn(s) { <<s:utf8>> })
}
```

```gleam
fn render_list_with_format(products: List, param: PathParam) -> Response {
  case param.format {
    option.Some("csv") ->
      stream_response(
        ok_status(),
        product.list_to_csv_stream(products),
        "text/csv",
      )
    _ -> html_response(ok_status(), product.list_to_html(products))
  }
}
```

## PathParam Features

PathParam provides automatic conversions:

```gleam
pub type PathParam {
  PathParam(
    raw: String,                      // "123.json"
    value: String,                    // "123"
    format: option.Option(String),    // Some("json")
    as_int: Result(Int, Nil),         // Ok(123)
    as_float: Result(Float, Nil),     // Ok(123.0)
  )
}
```

Use it:

```gleam
case get_param(request, "id") {
  Ok(param) -> {
    // Get the ID as int
    case param.as_int {
      Ok(id) -> // use id
      Error(_) -> bad_request()
    }
    
    // Get the format
    case param.format {
      option.Some("json") -> // JSON response
      _ -> // HTML response
    }
  }
  Error(_) -> not_found()
}
```

## Why This Pattern Is Clean

1. **No magic** - Format is explicit in the URL
2. **Type-safe** - PathParam conversions are checked
3. **Extendable** - Add new formats by adding a case
4. **Testable** - Each converter is a pure function
5. **No nested cases** - Flat helper functions
6. **No anonymous functions** - All functions are named
7. **Separation of concerns**:
   - Models: data transformation
   - Controllers: HTTP and format routing
   - Response builders: Content-Type headers

## Complete Example

See `examples/multi_format/` for a working example with:
- Product model with JSON, HTML, HTMX, CSV converters
- Streaming CSV export for lists
- Flat controller pattern
- Full HTML pages and HTMX partials
- Error handling

Run it:
```bash
DATABASE_URL="postgresql://user:pass@localhost/db" gleam run -m examples/multi_format/main
```

Then try:
```bash
curl http://localhost:3000/products/1           # HTML
curl http://localhost:3000/products/1.json      # JSON
curl http://localhost:3000/products/1.csv       # CSV
curl http://localhost:3000/products.csv         # Streaming CSV
```

## Using Matcha Templates

[Matcha](https://github.com/michaeljones/matcha) is a type-safe template system for Gleam that compiles `.matcha` files into Gleam modules with `render()` functions.

**Key benefits:**
- **Type-safe** - Template parameters are checked by the compiler
- **Semantic HTML** - Use with Pico CSS for classless styling
- **Composable** - Templates can call other templates
- **No runtime** - Compiles to Gleam code, no template engine overhead

**Basic Matcha syntax:**
```matcha
{> import my_app/types.{type User}
{> with user as User

<h1>{{ user.name }}</h1>
{% if user.is_admin %}
  <p>Admin user</p>
{% endif %}
```

Compiles to a Gleam module with:
```gleam
pub fn render(user user: User) -> String
```

See the multi-format example (`examples/multi_format/`) for complete working examples with semantic HTML and Pico CSS.

## Next Steps

- [Basic Routing](basic-routing.md) - Learn about Dream's routing
- [Database CRUD](database-crud.md) - Working with databases
- [Matcha Templates](https://github.com/michaeljones/matcha) - Matcha repository and documentation


