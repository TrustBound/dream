# Multiple Formats

Serve the same data in different formats: JSON, HTML, CSV, XML.

## Setup

Add Matcha for HTML templates:

```bash
gleam add marceau
```

Add to your `Makefile`:

```makefile
matcha:
	@gleam run -m marceau
```

Generate templates:

```bash
make matcha
```

This compiles `.matcha` files in your project to Gleam functions.

## Format Detection

### URL Extension

```gleam
import dream/http/response.{json_response, text_response, html_response}
import dream/http/status.{ok, not_found}
import dream/http/transaction.{Request, Response, get_param}
import dream/context.{AppContext}
import gleam/option.{Option, None, Some}
import models/product.{get, Product}
import services.{Services}
import views/product_view.{to_json, to_csv, to_html}

// Route: /products/:id.:format
// URLs: /products/1.json, /products/1.html, /products/1.csv

pub fn show(request: Request, context: AppContext, services: Services) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int
  
  case get(services.db, id) {
    Ok(product) -> respond_with_format(product, param.format)
    Error(_) -> not_found_response()
  }
}

fn respond_with_format(product: Product, format: Option(String)) -> Response {
  case format {
    Some("json") -> json_response(ok, to_json(product))
    Some("csv") -> text_response(ok, to_csv(product))
    Some("html") -> html_response(ok, to_html(product))
    _ -> html_response(ok, to_html(product))
  }
}

fn not_found_response() -> Response {
  text_response(not_found, "Not found")
}
```

### Accept Header

```gleam
import dream/http/response.{json_response, text_response, html_response}
import dream/http/status.{ok, not_found}
import dream/http/transaction.{Request, Response, get_header, get_param}
import dream/context.{AppContext}
import gleam/option.{unwrap, Option}
import gleam/string.{contains}
import models/product.{get, Product}
import services.{Services}
import views/product_view.{to_json, to_csv, to_html}

pub fn show(request: Request, context: AppContext, services: Services) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int
  let accept = get_header(request.headers, "Accept") |> unwrap("text/html")
  
  case get(services.db, id) {
    Ok(product) -> respond_by_accept(product, accept)
    Error(_) -> not_found_response()
  }
}

fn respond_by_accept(product: Product, accept: String) -> Response {
  case contains(accept, "application/json") {
    True -> json_response(ok, to_json(product))
    False -> check_csv_or_html(product, accept)
  }
}

fn check_csv_or_html(product: Product, accept: String) -> Response {
  case contains(accept, "text/csv") {
    True -> text_response(ok, to_csv(product))
    False -> html_response(ok, to_html(product))
  }
}

fn not_found_response() -> Response {
  text_response(not_found, "Not found")
}
```

## View Layer

Create `src/views/product_view.gleam`:

```gleam
import types/product.{Product}
import gleam/float.{to_string}
import gleam/int.{to_string}
import gleam/json
import gleam/list.{List, map}
import gleam/option.{None, Option}
import gleam/string.{join}
import views/products/templates/show

pub fn to_json(product: Product) -> String {
  product_to_json_object(product)
  |> json.to_string()
}

pub fn to_html(product: Product) -> String {
  // Convert Product to SQL row type (Matcha templates expect SQL types)
  let sql_row = product_to_sql_row(product)
  show.render(sql_row)
}

pub fn to_csv(product: Product) -> String {
  int.to_string(product.id)
  <> "," <> product.name
  <> "," <> float.to_string(product.price)
  <> "," <> int.to_string(product.stock)
}

pub fn list_to_json(products: List(Product)) -> String {
  map(products, product_to_json_object)
  |> json.array(from: _, of: identity)
  |> json.to_string()
}

pub fn list_to_csv(products: List(Product)) -> String {
  let header = "id,name,price,stock\n"
  let rows = map(products, product_to_csv_row) |> join("\n")
  header <> rows
}

fn product_to_json_object(p: Product) -> json.Json {
  json.object([
    #("id", json.int(p.id)),
    #("name", json.string(p.name)),
    #("price", json.float(p.price)),
    #("stock", json.int(p.stock)),
  ])
}

fn product_to_csv_row(p: Product) -> String {
  int.to_string(p.id)
  <> "," <> p.name
  <> "," <> float.to_string(p.price)
  <> "," <> int.to_string(p.stock)
}

fn identity(x: a) -> a {
  x
}

// Adapter: Convert domain type to SQL row type for Matcha templates
fn product_to_sql_row(product: Product) -> sql.GetProductRow {
  sql.GetProductRow(
    id: product.id,
    name: product.name,
    price: product.price,
    stock: product.stock,
    created_at: None,
  )
}
```

## Content Negotiation

```gleam
import dream/http/response.{json_response, text_response, html_response}
import dream/http/status.{ok, not_found}
import dream/http/transaction.{Request, Response, PathParam, get_header, get_param}
import dream/context.{AppContext}
import gleam/option.{Some, None, Option}
import gleam/string.{contains}
import models/product.{get, Product}
import services.{Services}
import views/product_view.{to_json, to_csv, to_html}

pub fn show(request: Request, context: AppContext, services: Services) -> Response {
  let assert Ok(param) = get_param(request, "id")
  let assert Ok(id) = param.as_int
  
  case get(services.db, id) {
    Ok(product) -> negotiate_format(request, param, product)
    Error(_) -> not_found_response()
  }
}

fn negotiate_format(request: Request, param: PathParam, product: Product) -> Response {
  // Priority: URL extension > Accept header > default
  case param.format {
    Some(format) -> respond_with_format(product, Some(format))
    None -> check_accept_header(request, product)
  }
}

fn check_accept_header(request: Request, product: Product) -> Response {
  let accept = get_header(request.headers, "Accept")
  respond_by_accept(product, accept)
}

fn respond_with_format(product: Product, format: Option(String)) -> Response {
  case format {
    Some("json") -> json_response(ok, to_json(product))
    Some("csv") -> text_response(ok, to_csv(product))
    Some("html") -> html_response(ok, to_html(product))
    _ -> html_response(ok, to_html(product))
  }
}

fn respond_by_accept(product: Product, accept: Option(String)) -> Response {
  case accept {
    Some(header) -> check_format_in_header(product, header)
    None -> html_response(ok, to_html(product))
  }
}

fn check_format_in_header(product: Product, accept: String) -> Response {
  case contains(accept, "application/json") {
    True -> json_response(ok, to_json(product))
    False -> check_csv_or_html(product, accept)
  }
}

fn check_csv_or_html(product: Product, accept: String) -> Response {
  case contains(accept, "text/csv") {
    True -> text_response(ok, to_csv(product))
    False -> html_response(ok, to_html(product))
  }
}

fn not_found_response() -> Response {
  text_response(not_found, "Not found")
}
```

## HTML Templates with Matcha

Create `src/views/products/templates/show.matcha`:

```matcha
{> import sql.{type GetProductRow}
{> import gleam/int
{> import gleam/float
{> with product as GetProductRow

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <title>{{ product.name }}</title>
</head>
<body>
  <div class="product">
    <h1>{{ product.name }}</h1>
    <p>Price: ${{ float.to_string(product.price) }}</p>
    <p>Stock: {{ int.to_string(product.stock) }}</p>
  </div>
</body>
</html>
```

**Generate Gleam code:**

```bash
make matcha
```

This creates `src/views/products/templates/show.gleam` with a `render()` function.

**Use in your view:**

```gleam
import views/products/templates/show

pub fn to_html(product: Product) -> String {
  let sql_row = product_to_sql_row(product)
  show.render(sql_row)
}
```

**Why Matcha?** Type-safe templates that compile to Gleam functions. The compiler catches template errors at build time.

## Working Example

See [examples/multi_format/](../../examples/multi_format/) for complete code with:
- JSON, HTML, CSV responses
- Matcha templates
- Format detection
- HTMX partials

## See Also

- [Streaming](streaming.md) - Stream large CSV files
- [Testing](testing.md) - Test multiple formats

