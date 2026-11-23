# Simple Example

The simplest possible Dream app. Demonstrates basic routing, path parameters, and HTTP client usage.

## What This Demonstrates

- **Basic routing** - Simple GET routes
- **Path parameters** - Extracting `:id` and `:post_id` from URLs
- **HTTP client** - Making HTTPS requests to external APIs
- **Clean controller pattern** - Simple request handlers
- **Request data** - The query string, a JSON body that reports every error, and a form
- **Responses** - Cookies, a redirect, an empty answer and a CSV download
- **A custom method** - A `PURGE` route, and a 1 MB limit on request bodies

## Running the Example

### Start the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/start.sh#L3-L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
cd examples/simple
make run
```

Server starts on `http://localhost:3000`

## Endpoints

- `GET /` - Returns "Hello, World!"
- `GET /users/:id/posts/:post_id` - Demonstrates path parameters and makes an HTTPS request to jsonplaceholder.typicode.com
- `GET /users/:id`, `GET /search?q=...`, `POST /signups` and `POST /contact` - Request data, shown in [Read request data safely](../../docs/guides/request-data.md)
- `GET /visits`, `GET /old-home`, `DELETE /sessions` and `GET /report.csv` - Responses, shown in [Send responses, cookies and files](../../docs/guides/responses.md)
- `PURGE /cache` - A custom method, shown in [Route requests and add middleware](../../docs/guides/routing.md)

## Example Usage

### Send the requests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L3-L7"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
# Simple hello world
curl http://localhost:3000/

# Path parameters with external API call
curl http://localhost:3000/users/1/posts/2
```

## Code Structure

The example has these source files:

### List the source files <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L79"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
find src -type f | sort
```

### The source files <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L743-L752"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
src/controllers/cache_controller.gleam
src/controllers/posts_controller.gleam
src/controllers/request_data_controller.gleam
src/controllers/responses_controller.gleam
src/controllers/visits_controller.gleam
src/main.gleam
src/router.gleam
src/services.gleam
src/utilities/response_helpers.gleam
src/views/post_view.gleam
```

- `src/controllers/posts_controller.gleam`: hello world and the HTTPS call.
- `src/controllers/request_data_controller.gleam`: path, query, JSON and form data.
- `src/controllers/responses_controller.gleam`: redirect, empty answer, download.
- `src/controllers/visits_controller.gleam`: a cookie counter.
- `src/controllers/cache_controller.gleam`: the `PURGE` route.
- `src/utilities/response_helpers.gleam`: errors to responses.
- `src/views/post_view.gleam`: text formatting.

## Key Concepts

- **Routes** - Defined using `route()` function calls
- **Path Parameters** - Extracted using `get_param(request, "id")`
- **HTTP Client** - Uses Dream's HTTP client builder pattern
- **Controllers** - Simple functions that take `Request`, `Context`, and `Services`

This is the perfect starting point for understanding Dream's core concepts.

