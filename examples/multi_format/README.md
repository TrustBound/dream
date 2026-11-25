# Multi-Format Response Example

Demonstrates Dream's elegant pattern for serving the same data in multiple formats (JSON, HTML, HTMX, CSV, streaming) with clean, maintainable code.

## Features Demonstrated

- **PathParam format detection** - `/products/1.json`, `/products/1.htmx`, `/products/1.csv`
- **Matcha templates** - Semantic HTML with Pico CSS (classless styling)
- **Flat controller pattern** - No nested cases, all named helper functions
- **Streaming responses** - CSV export as a stream of bytes
- **Typed models** - `dream_model` generates the product model from SQL files
- **Multiple formats per endpoint** - Same controller serves JSON, HTML, HTMX, CSV

## Running the Example

### Start the database and the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/multi_format/test/integration/start.sh#L3-L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
cd examples/multi_format

# Start database
make db-up

# Run migrations
make migrate

# Run the server
make run
```

Server will start on `http://localhost:3000`.

When you change a query in `src/models/product/` or a template, generate the code again. `make models` needs the database:

### Generate the model <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/multi_format/test/integration/models.sh#L8"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
make models
```

### Compile the templates <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/multi_format/test/templates.sh#L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
make matcha
```

## Try It Out

### Send the requests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/multi_format/test/integration/readme.sh#L3-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
# HTML - Full page with Pico CSS styling
curl http://localhost:3000/products/1

# JSON - API response
curl http://localhost:3000/products/1.json

# HTMX partial - Card component
curl http://localhost:3000/products/1.htmx

# CSV - Single row
curl http://localhost:3000/products/1.csv

# JSON list
curl http://localhost:3000/products.json

# Streaming CSV export
curl http://localhost:3000/products.csv
```

## Pattern Overview

### Model Layer (`models/product.gleam`)

Models provide `to_*` conversion functions:

- `to_json(product)` - Converts to JSON string
- `to_html(product)` - Calls Matcha template for full page
- `to_htmx(product)` - Calls Matcha template for partial
- `to_csv(product)` - Converts to CSV row
- `list_to_csv_stream(products)` - Streams CSV bytes

### View Layer (Matcha templates)

- `views/products/show.matcha` - Full HTML page with semantic markup
- `views/products/card.matcha` - HTMX partial (article component)
- `views/products/index.matcha` - Products list table

Templates use:
- Semantic HTML (no classes)
- Pico CSS for styling
- Lucide icons
- ARIA attributes for accessibility

### Controller Layer (`controllers/products_controller.gleam`)

Controllers use flat case pattern:

1. Extract PathParam
2. Check `param.as_int` for conversion
3. Query database
4. Match on `param.format` to choose converter
5. Return appropriate response

No nested cases, every function has a single responsibility.

## Code Structure

The example has these source files and migrations:

### List the files <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/multi_format/test/integration/readme.sh#L34"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
find src priv -type f | sort
```

### The files <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/multi_format/test/integration/readme_output.txt#L91-L111"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
priv/migrations/20251106170310-create_products.sql
src/context.gleam
src/controllers/products_controller.gleam
src/database.gleam
src/main.gleam
src/models/product.gleam
src/models/product/get.sql
src/models/product/list.sql
src/operations/product_operations.gleam
src/router.gleam
src/services.gleam
src/types/errors.gleam
src/utilities/response_helpers.gleam
src/views/errors.gleam
src/views/products/templates/card.gleam
src/views/products/templates/card.matcha
src/views/products/templates/index.gleam
src/views/products/templates/index.matcha
src/views/products/templates/show.gleam
src/views/products/templates/show.matcha
src/views/products/view.gleam
```

- `src/models/product/`: the SQL queries. `dream_model` generates `src/models/product.gleam` from them. The templates take its `Product` type.
- `src/database.gleam` starts the pool and calls `client.check_schema` with the fingerprint of the model, through `check_schema_waiting_for_database`. The app waits for a database that is not up yet, and stops with a clear message when the schema changed after the generation.
- `src/views/products/templates/`: the Matcha templates (`.matcha`) and the Gleam modules generated from them.
- `src/views/products/view.gleam`: a product as JSON, HTML, CSV or HTMX partial.
- `src/controllers/products_controller.gleam`: picks the format from the path extension.
- `priv/migrations/`: the database migration. `docker-compose.yml` starts PostgreSQL.

### Start-up needs the database

At start-up, the app runs `client.check_schema` through `check_schema_waiting_for_database` in `src/database.gleam`. The check queries the database.

- When PostgreSQL cannot be reached, the app prints one line for each attempt, such as `Waiting for the database (attempt 3 of 15): ...`. It runs the check again every 2 seconds, at most 15 times. Each failed attempt also takes 2 to 3 seconds, the time that the pool waits for a connection. When the last attempt fails, the app prints one message (from `client.format_schema_check_error`) and stops with exit status 1.
- When the schema changed after `make models`, the app prints that message and stops with exit status 1 at once. Another database error, such as a missing table, also stops the app at once.

Start the database first. After a schema change, run `make migrate` and `make models`. `make test` proves both cases with `integration/startup-check.sh` of the repository: it stops the postgres container and starts the app, and it changes a column of the test database.

## Key Takeaways

1. **Format is explicit** - Extension in URL (`/products/1.json`)
2. **Models own conversion** - All `to_*` functions in one place
3. **Templates are functions** - Matcha compiles to type-safe Gleam
4. **Flat, readable code** - No nesting, named helpers
5. **Separation of concerns** - Models convert, controllers route, templates render

See [Multi-Format Responses Tutorial](../../docs/tutorials/multi-format-responses.md) for complete documentation.

