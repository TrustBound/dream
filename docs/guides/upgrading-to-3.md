[README](https://hexdocs.pm/dream/3.0.0/) > [Guides](https://hexdocs.pm/dream/3.0.0/guides/index.html) > Upgrade from Dream 2 to 3

# Upgrade from Dream 2 to 3

Dream 3.0.0 has breaking changes. A request body is one `RequestBody` value, the compiler enforces the order of the server builder, `validate_json` returns every error, and Dream runs on its own HTTP server packages. Most projects need only the request body change. This guide takes you through the upgrade in order: update the dependency, let the compiler list what broke, then fix one area at a time, each with the Dream 2 code next to the Dream 3 code.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which steps you need](#which-steps-you-need)
- [Step 1: Update the dependency](#step-1-update-the-dependency)
- [Step 2: Replace mist and glisten](#step-2-replace-mist-and-glisten)
- [Step 3: Read request bodies as a RequestBody](#step-3-read-request-bodies-as-a-requestbody)
- [Step 4: Put the server builder in order](#step-4-put-the-server-builder-in-order)
- [Step 5: Name the new methods](#step-5-name-the-new-methods)
- [Step 6: Answer every validation error](#step-6-answer-every-validation-error)
- [Step 7: Move the ConnectionClosed work to on_close](#step-7-move-the-connectionclosed-work-to-on_close)
- [Step 8: Move from pog and squirrel](#step-8-move-from-pog-and-squirrel)
- [Step 9: Handle the result of listen](#step-9-handle-the-result-of-listen)
- [Step 10: Update calls of get_server and response.convert](#step-10-update-calls-of-get_server-and-responseconvert)
- [Step 11: Answer the Conflict error](#step-11-answer-the-conflict-error)
- [Step 12: Check the behavior changes](#step-12-check-the-behavior-changes)
- [Step 13: Update your tests to dream_test 3](#step-13-update-your-tests-to-dream_test-3)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

By the end of this guide, your project:

- Depends on Dream 3.0.0 and compiles.
- Reads request bodies as `Text`, `Bytes` or `Stream`, and answers a broken upload.
- Builds the server in the order that the compiler enforces.
- Stops with a non-zero exit code when the server cannot start.
- Expects the new answers: `405` for a wrong method, `413` for a body over the limit.

## Before you start

You need a project that uses Dream 2, with its tests passing on Dream 2, so every failure after the upgrade is about the upgrade. Commit first, so you can compare.

Each Dream 2 example on this page has the label **Code at 2.4.1**: the code is a copy of a file at the 2.4.1 tag, and the link opens that file at the shown lines. The docs check compares each one with that file at the tag. Each Dream 3 example is a tested snippet or a file of Dream 3.0.0 itself, and the docs check compares it with that file.

## Which steps you need

Do the steps in order. Steps 1 and 3 apply to most projects. The other steps apply only when your code uses what the table names.

| Your code uses | What changed | Step |
|:---|:---|:---|
| Any Dream 2 version | The requirement is `>= 3.0.0 and < 4.0.0`, and `gleam_stdlib` must be 1.x. | [Step 1](#step-1-update-the-dependency) |
| `mist` or `glisten` in `gleam.toml` | Dream uses `dream_http_server` and `dream_socket_server`, which define the same modules. | [Step 2](#step-2-replace-mist-and-glisten) |
| `request.body`, `request.stream`, or code that builds a `Request` | `body` is a `RequestBody`. The `stream` field is gone. | [Step 3](#step-3-read-request-bodies-as-a-requestbody) |
| The `Dream` type, or `context()` or `services()` after `router()` | `Dream` has a fourth type parameter, and the builder order is checked. | [Step 4](#step-4-put-the-server-builder-in-order) |
| A `case` over every `Method` | `Method` has `Connect`, `Trace` and `Other(String)`. | [Step 5](#step-5-name-the-new-methods) |
| `validate_json` | It returns a list of errors. | [Step 6](#step-6-answer-every-validation-error) |
| `websocket.ConnectionClosed` | It is removed. `on_close` runs when the connection closes. | [Step 7](#step-7-move-the-connectionclosed-work-to-on_close) |
| `pog`, `squirrel` or `dream_postgres` | The guides use `dream_postgres_client` and `dream_sql_generator`. | [Step 8](#step-8-move-from-pog-and-squirrel) |
| `server.listen` in `main` | It returns a `Result`. | [Step 9](#step-9-handle-the-result-of-listen) |
| `dream.get_server` or `response.convert` | `get_server` takes `RisksUnderstood`. `convert` takes the Mist request. | [Step 10](#step-10-update-calls-of-get_server-and-responseconvert) |
| A `case` over every `Error` | `Error` has `Conflict(String)`, which gives 409. | [Step 11](#step-11-answer-the-conflict-error) |
| Tests or clients that check status codes or error texts | Some answers and messages changed. | [Step 12](#step-12-check-the-behavior-changes) |
| Tests from the Dream 2 testing guide | No change is necessary. The new guide uses `dream_test` 3. | [Step 13](#step-13-update-your-tests-to-dream_test-3) |

## Step 1: Update the dependency

Change the Dream line in the `[dependencies]` of your `gleam.toml`:

```toml
[dependencies]
dream = ">= 3.0.0 and < 4.0.0"
```

Then download it:

```bash
gleam deps update dream
```

Dream 2.4.1 accepted `gleam_stdlib` from 0.44. Dream 3.0.0 requires `>= 1.0.0 and < 2.0.0`. If your `gleam.toml` names an older `gleam_stdlib`, change it to `>= 1.0.0 and < 2.0.0` as well.

Then run `gleam build`. Each error names a file and a line. The steps below say which change each error comes from.

## Step 2: Replace mist and glisten

Dream's server packages define the same modules as `mist` and `glisten`, and Gleam stops the build with a duplicate module error when two packages do. Replace `mist` with `dream_http_server`, as Dream's own `gleam.toml` did:

### Replace `mist` with `dream_http_server` <a href="https://github.com/TrustBound/dream/compare/2.4.1...3.0.0#diff-7cd1e07e743a743d849d706b1dafd77e5839325c3b7327d3f060335605d525be"><img align="right" alt="Tested diff" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-diff-lightgreen.svg?style=flat-square"></a>

```diff
--- a/gleam.toml
+++ b/gleam.toml
 [dependencies]
-gleam_stdlib = ">= 0.44.0 and < 2.0.0"
-mist = ">= 5.0.3 and < 6.0.0"
+gleam_stdlib = ">= 1.0.0 and < 2.0.0"
+# dream's HTTP server: a fork of mist 6.0.3 with HTTP/2 fixes, published under
+# its own name with mist's module names.
+dream_http_server = ">= 2.1.0 and < 3.0.0"
```

Replace `glisten` with `dream_socket_server = ">= 1.0.0 and < 2.0.0"` in the same way. Your `import mist` and `import glisten` lines stay as they are, because the module names are the same.

## Step 3: Read request bodies as a RequestBody

**What changed.** `Request.body` is a `RequestBody`, and the `Request.stream` field is gone. In Dream 2 the request had two fields:

### The body fields of `Request` <a href="https://github.com/TrustBound/dream/blob/2.4.1/src/dream/http/request.gleam#L155-L158"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
    remote_address: option.Option(String),
    body: String,
    stream: option.Option(Yielder(BitArray)),
    headers: List(Header),
```

In Dream 3 it has one:

### The body field of `Request` <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/http/request.gleam#L203-L205"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    remote_address: option.Option(String),
    body: RequestBody,
    headers: List(Header),
```

A `RequestBody` has three shapes:

### The `RequestBody` type <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/http/request.gleam#L262-L276"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type RequestBody {
  Text(String)
  Bytes(BitArray)
  Stream(Yielder(Result(BitArray, BodyReadError)))
}

/// Why a read of a streamed request body failed
///
/// The server reports one cause. `MalformedBody` means that the server could
/// not read the rest of the body: the connection closed before the end of
/// the body, no data came in the read timeout, or the chunked framing was
/// not valid. The server does not tell these cases apart.
pub type BodyReadError {
  MalformedBody
}
```

- On a route made with `route`, a body that is valid UTF-8 arrives as `Text`. An empty body is `Text("")`. Any other body arrives as `Bytes`, with the exact bytes.
- On a route made with `stream_route`, the body arrives as `Stream`. Each item is `Ok(chunk)`, or one `Error(MalformedBody)` when a read from the connection fails, for example when the client closed the connection before the end of the body. The stream ends after the `Error` item.

**Why.** In Dream 2, a body that was not valid UTF-8 (for example a PNG or a PDF upload) reached the controller as `""`, with no error. The `body` and `stream` fields could also disagree. One value with three shapes removes both problems, and it matches `ResponseBody`.

### A controller that parses JSON

Use the new `require_json`. It reads the body as text, parses the JSON, runs your decoder, and returns `BadRequest` with the reason when a step fails. The database example made this change. In Dream 2 it had a helper that validated `request.body`:

### The helper that parsed a `String` body <a href="https://github.com/TrustBound/dream/blob/2.4.1/examples/database/src/controllers/users_controller.gleam#L19-L24"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
fn parse_user_data(body: String) -> Result(#(String, String), Error) {
  case validate_json(body, user.decoder()) {
    Ok(d) -> Ok(d)
    Error(_) -> Error(BadRequest("Invalid user data"))
  }
}
```

The controller called the helper:

### The call of the helper <a href="https://github.com/TrustBound/dream/blob/2.4.1/examples/database/src/controllers/users_controller.gleam#L67-L72"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
  let result = {
    use data <- result.try(parse_user_data(request.body))
    let #(name, email) = data
    let db = services.database.connection
    user_operations.create_user(db, name, email)
  }
```

In Dream 3 the helper is gone, and the controller calls `require_json`:

### Parse a JSON body with `require_json` <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/src/controllers/users_controller.gleam#L58-L62"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  let result = {
    use #(name, email) <- result.try(require_json(request, user.decoder()))
    let db = services.database.connection
    user_operations.create_user(db, name, email)
  }
```

Use `validate_json(text, decoder)` when you already have a `String`. It returns a list of errors: [Step 6](#step-6-answer-every-validation-error) shows the change.

### A controller that needs the body as text

Use `body_as_string(request)`. It returns `Error(Nil)` when the body is not valid UTF-8:

### Read a text body with `body_as_string` <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_request.gleam#L46-L51"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn show_body(request: Request, _context, _services) -> Response {
  case body_as_string(request) {
    Ok(body) -> text_response(status.ok, body)
    Error(_) -> text_response(status.bad_request, "Body is not valid UTF-8")
  }
}
```

### A controller or middleware that reads the stream

Match `Stream` on `request.body` in place of `Some` on `request.stream`. Each item is a `Result`, so fold with `yielder.try_fold` and answer the `Error` item. The streaming example made this change. In Dream 2 it matched `request.stream`:

### Read `request.stream` <a href="https://github.com/TrustBound/dream/blob/2.4.1/examples/streaming_capabilities/src/controllers/stream_controller.gleam#L20-L31"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
  case request.stream {
    Some(stream) -> {
      // Consume the stream "saving" it
      let total_bytes = stream |> yielder.fold(0, accumulate_chunk_size)

      text_response(
        status.ok,
        "Uploaded " <> int.to_string(total_bytes) <> " bytes successfully",
      )
    }
    None -> text_response(status.bad_request, "Expected streaming request body")
  }
```

In Dream 3 it matches `request.body`:

### Read a stream from `request.body` <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/src/controllers/stream_controller.gleam#L21-L29"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  case request.body {
    // Consume the stream "saving" it. try_fold stops at an Error item.
    Stream(stream) ->
      stream
      |> yielder.try_fold(0, accumulate_chunk_size)
      |> respond_to_upload
    Text(_) | Bytes(_) ->
      text_response(status.bad_request, "Expected streaming request body")
  }
```

In Dream 2 the fold function got each chunk:

### Fold over chunks <a href="https://github.com/TrustBound/dream/blob/2.4.1/examples/streaming_capabilities/src/controllers/stream_controller.gleam#L87-L91"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
fn accumulate_chunk_size(acc: Int, chunk: BitArray) -> Int {
  let size = bit_array.byte_size(chunk)
  // Simulate saving to disk
  acc + size
}
```

In Dream 3 it gets the `Result` and stops at an `Error`. The controller answers the `Error` with 400:

### Fold over `Result` items <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/streaming_capabilities/src/controllers/stream_controller.gleam#L90-L110"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn accumulate_chunk_size(
  acc: Int,
  item: Result(BitArray, BodyReadError),
) -> Result(Int, BodyReadError) {
  use chunk <- result.map(item)
  // Simulate saving to disk
  acc + bit_array.byte_size(chunk)
}

fn respond_to_upload(counted: Result(Int, BodyReadError)) -> Response {
  case counted {
    Ok(total_bytes) ->
      text_response(
        status.ok,
        "Uploaded " <> int.to_string(total_bytes) <> " bytes successfully",
      )
    // The connection broke before the client sent the whole body
    Error(_read_error) ->
      text_response(status.bad_request, "The upload stopped before its end")
  }
}
```

A controller that saves the stream to a file deletes the partial file when it gets the `Error` item. [Stream responses and uploads](https://hexdocs.pm/dream/3.0.0/guides/streaming.html) shows the full example.

### Code that builds a `Request`

Tests and middleware that build a `Request` remove `stream:` and give `body:` a `RequestBody`. Dream's test fixtures made this change. In Dream 2 they set both fields:

### Build a `Request` with `body` and `stream` <a href="https://github.com/TrustBound/dream/blob/2.4.1/test/fixtures/request.gleam#L22-L25"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
    remote_address: option.None,
    body: "",
    stream: option.None,
    headers: [],
```

In Dream 3 they set `body` only:

### Build a `Request` with a `RequestBody` <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/fixtures/request.gleam#L24-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
    remote_address: option.None,
    body: Text(""),
    headers: [],
```

A streamed request put the yielder in `stream`:

### Build a streamed request in Dream 2 <a href="https://github.com/TrustBound/dream/blob/2.4.1/test/fixtures/request.gleam#L60-L66"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
pub fn create_streaming_request(
  method: Method,
  path: String,
  stream: yielder.Yielder(BitArray),
) -> Request {
  Request(..create_request(method, path), stream: option.Some(stream))
}
```

In Dream 3 the yielder goes in `body`, with each chunk in `Ok`:

### Build a streamed request in Dream 3 <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/fixtures/request.gleam#L70-L76"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_streaming_request(
  method: Method,
  path: String,
  stream: yielder.Yielder(BitArray),
) -> Request {
  Request(..create_request(method, path), body: Stream(yielder.map(stream, Ok)))
}
```

### A module that uses request and response bodies together

`Text`, `Bytes` and `Stream` are also the `ResponseBody` constructors. Qualify the request side: `request.Text`, `request.Bytes`, `request.Stream`.

### Other body changes

- `require_form` returns `BadRequest("Request body is not text")` for a body that is not text. It also reads a `Stream` body.
- A binary upload on a `route` arrives as `Bytes`. In Dream 2 it arrived as `""`.

## Step 4: Put the server builder in order

**What changed.** The `Dream` type has a fourth type parameter, `router`. In Dream 2 it had three:

### The `Dream` type in Dream 2 <a href="https://github.com/TrustBound/dream/blob/2.4.1/src/dream/dream.gleam#L71-L80"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
pub opaque type Dream(server, context, services) {
  Dream(
    server: server,
    router: option.Option(Router(context, services)),
    context: context,
    services: option.Option(services),
    max_body_size: Int,
    bind_interface: option.Option(String),
  )
}
```

In Dream 3 the router is a type parameter:

### The `Dream` type in Dream 3 <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/dream.gleam#L98-L109"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub opaque type Dream(server, context, services, router) {
  Dream(
    server: server,
    router: router,
    context: context,
    services: services,
    max_body_size: Int,
    bind_interface: option.Option(String),
    tls: option.Option(Tls),
    shutdown_timeout: Int,
  )
}
```

The parameter is `NoRouter` until you call `server.router()`, and then it is the `Router(context, services)` you gave. The compiler enforces the builder order:

- `server.context()` and `server.services()` accept only an app that has no router yet. Call them before `server.router()`.
- `server.listen()` and `server.listen_with_handle()` accept only an app that has a router.
- `server.router()` accepts only an app that has no router yet, so you call it one time.
- `bind()`, `max_body_size()` and `tls()` work before or after `router()`.

The accessors in `dream/dream` follow the new shape. `get_router` returns `NoRouter` or the router, not an `Option`. `get_services` returns the services, not an `Option`. `create` takes the router state and the services without an `Option`.

**Why.** A router's type includes the context and services types: `Router(context, services)`. `context()` and `services()` change those types, so a router given before them cannot stay in the app. In Dream 2, `context()` and `services()` dropped the router with no error, and `listen()` crashed at start.

**How to upgrade.**

- If the build fails with a type mismatch between `NoRouter` and `Router(...)`, move `context()` and `services()` above `router()`, and make sure that `router()` comes before `listen()`.
- If you write the `Dream` type, add the fourth parameter. This app has its own context and services, in the right order:

### Context, services, router, in that order <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_core_dream_type.gleam#L22-L35"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_server() -> Dream(
  mist.Builder(Connection, ResponseData),
  MyContext,
  Services,
  Router(MyContext, Services),
) {
  server.new()
  |> server.context(MyContext(request_id: "", user: None))
  |> server.services(Services(
    database_url: "postgres://localhost/app",
    cache_size: 100,
  ))
  |> server.router(my_router())
}
```

- If you use `dream.get_router` or `dream.get_services`, remove the `Some` and `None` cases.

## Step 5: Name the new methods

**What changed.** `Method` has three more variants: `Connect`, `Trace` and `Other(String)`. A `case` that names every `Method` value does not compile until it has a branch for each one. Dream's own `method_to_string` made this change. In Dream 2 it named seven methods:

### Seven methods <a href="https://github.com/TrustBound/dream/blob/2.4.1/src/dream/http/request.gleam#L210-L220"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
pub fn method_to_string(method: Method) -> String {
  case method {
    Get -> "GET"
    Post -> "POST"
    Put -> "PUT"
    Delete -> "DELETE"
    Patch -> "PATCH"
    Options -> "OPTIONS"
    Head -> "HEAD"
  }
}
```

In Dream 3 it names the new ones too:

### Name the new methods <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/http/request.gleam#L357-L370"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn method_to_string(method: Method) -> String {
  case method {
    Get -> "GET"
    Post -> "POST"
    Put -> "PUT"
    Delete -> "DELETE"
    Patch -> "PATCH"
    Options -> "OPTIONS"
    Head -> "HEAD"
    Connect -> "CONNECT"
    Trace -> "TRACE"
    Other(name) -> name
  }
}
```

`Other` holds the name exactly as the client sent it. `parse_method` gives `Some(Connect)` and `Some(Trace)` for those names in any case, and `Some(Other(name))` for another valid method token, such as `"PURGE"`. It gives `None` only for text that is not a method token, such as `"GET /"`. In Dream 2 it gave `None` for every name except the seven standard ones.

## Step 6: Answer every validation error

**What changed.** `validate_json` returns `Result(a, List(ValidationError))`. A body with two wrong fields gives two errors, in the order of the decoder. A JSON syntax error gives a list with one error. In Dream 2 it gave only the first error:

### `validate_json` returns one error <a href="https://github.com/TrustBound/dream/blob/2.4.1/src/dream/http/validation.gleam#L143-L146"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
pub fn validate_json(
  body: String,
  decoder: decode.Decoder(decoded_type),
) -> Result(decoded_type, ValidationError) {
```

In Dream 3 it gives all of them:

### `validate_json` returns a list of errors <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/http/validation.gleam#L223-L226"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn validate_json(
  body: String,
  decoder: decode.Decoder(decoded_type),
) -> Result(decoded_type, List(ValidationError)) {
```

A controller that answered one error now answers the list, for example with one JSON object for each field:

### Answer with every validation error <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/doc_http_data_validate_json.gleam#L27-L43"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
fn create_post_from_json(body: String) -> Response {
  case validate_json(body, post_decoder()) {
    Ok(post) -> {
      // Valid post data - proceed with business logic
      json_response(created, post_to_json(post))
    }

    Error(validation_errors) -> {
      // One object for each field that failed
      let errors_json =
        json.object([
          #("errors", json.array(validation_errors, validation_error_to_json)),
        ])
      json_response(bad_request, json.to_string(errors_json))
    }
  }
}
```

`require_json` joins the messages with `"; "` in its `BadRequest`.

## Step 7: Move the ConnectionClosed work to on_close

**What changed.** The `websocket.Message` type has no `ConnectionClosed` any more. In Dream 2 it had four variants:

### The WebSocket `Message` in Dream 2 <a href="https://github.com/TrustBound/dream/blob/2.4.1/src/dream/servers/mist/websocket.gleam#L109-L118"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
pub type Message(custom) {
  /// A text frame received from the client
  TextMessage(String)
  /// A binary frame received from the client
  BinaryMessage(BitArray)
  /// A custom message from the application (via selector)
  CustomMessage(custom)
  /// The connection was closed
  ConnectionClosed
}
```

In Dream 3 it has three:

### The WebSocket `Message` in Dream 3 <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/servers/mist/websocket.gleam#L116-L123"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Message(custom) {
  /// A text frame received from the client
  TextMessage(String)
  /// A binary frame received from the client
  BinaryMessage(BitArray)
  /// A custom message from the application (via selector)
  CustomMessage(custom)
}
```

`ConnectionClosed` never arrived: a close frame from the client and a dropped connection call `on_close`, and the server sends no message to `on_message`. `dream_http_server` 2.0.0 removed `Closed` and `Shutdown` from `mist.WebsocketMessage`, which `ConnectionClosed` came from. A `case` that names `websocket.ConnectionClosed` does not compile.

**What to do.** Delete the `ConnectionClosed` branch of your `on_message` handler. Do the work of that branch in `on_close`, which runs once when the connection closes. [Build a chat with WebSockets](https://hexdocs.pm/dream/3.0.0/guides/websockets.html) shows a handler with `on_close`.

## Step 8: Move from pog and squirrel

**What changed.** The guides and the examples use [`dream_postgres_client`](https://hex.pm/packages/dream_postgres_client) in place of `pog`, and [`dream_sql_generator`](https://hex.pm/packages/dream_sql_generator) in place of `squirrel`. Both are forks, maintained for Dream. `dream_postgres` 2.0.0 uses `dream_postgres_client`. Your app can stay on `pog` and `squirrel`: Dream 3.0.0 does not depend on them. Do this step to follow the guides, or to use `dream_postgres` 2.0.0.

**What to do.**

1. In `[dependencies]`, replace `pog` with `dream_postgres_client = ">= 1.0.0 and < 2.0.0"`.
2. In `[dev-dependencies]`, replace `squirrel` with `dream_sql_generator = ">= 1.0.0 and < 2.0.0"`.
3. Add a `[tools.dream_sql_generator]` table with `client_module = "dream_postgres_client"`.
4. In your code, replace `import pog` with `import dream_postgres_client`, and `pog.` with `dream_postgres_client.`.
5. Run `gleam run -m dream_sql_generator` in place of `gleam run -m squirrel`. The generated code then uses `dream_postgres_client`.

[Build a database-backed JSON API](https://hexdocs.pm/dream/3.0.0/guides/database-api.html) shows the full setup.

## Step 9: Handle the result of listen

**What changed.** `server.listen` returns `Result(Nil, actor.StartError)`. When the server starts, it still blocks and does not return. When the server cannot start, it returns the error. In Dream 2 it returned `Nil` and stopped the program with a panic:

### `listen` in Dream 2 <a href="https://github.com/TrustBound/dream/blob/2.4.1/src/dream/servers/mist/server.gleam#L339-L349"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
pub fn listen(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
  ),
  port: Int,
) -> Nil {
  listen_internal(dream_instance, port, True)
  |> panic_on_start_error
}
```

### `listen` in Dream 3 <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/servers/mist/server.gleam#L639-L647"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn listen(
  dream_instance: dream.Dream(
    mist.Builder(Connection, ResponseData),
    context,
    services,
    Router(context, services),
  ),
  port: Int,
) -> Result(Nil, actor.StartError) {
```

A `main` that ends with `listen` does not compile with Dream 3, because its value is a `Result`. This was the `main` of the `simple` example:

### `main` in Dream 2 <a href="https://github.com/TrustBound/dream/blob/2.4.1/examples/simple/src/main.gleam#L6-L11"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
pub fn main() {
  dream.new()
  |> router(create_router())
  |> bind("localhost")
  |> listen(3000)
}
```

**How to fix it.** Put `let assert Ok(Nil) =` in front of the call. A server that cannot start is a fault of the deployment, so the program must stop. `let assert` stops it with the error and a non-zero exit code, and the platform can start it again:

### `main` in Dream 3 <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/src/main.gleam#L6-L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn main() {
  let assert Ok(Nil) =
    dream.new()
    |> router(create_router())
    |> bind("localhost")
    // Refuse a buffered request body over 1 MB
    |> max_body_size(1_000_000)
    |> listen(3000)
}
```

A program that must do something else on a start error can match on the `Error` value in place of `let assert`.

## Step 10: Update calls of get_server and response.convert

Most apps do not call these two functions. Skip this step if your code does not use them.

**What changed in `get_server`.** The `risks_understood` argument is the value `RisksUnderstood`, not a `Bool`. A call with `False` panicked in Dream 2. In Dream 3 it does not compile:

### `get_server` in Dream 2 <a href="https://github.com/TrustBound/dream/blob/2.4.1/src/dream/dream.gleam#L176-L185"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
pub fn get_server(
  dream: Dream(server, context, services),
  risks_understood risks: Bool,
) -> server {
  case risks {
    True -> dream.server
    False ->
      panic as "dream.get_server() requires risks_understood: True. This function breaks Dream's server abstraction and couples your code to Mist. Read the documentation to understand the risks before proceeding."
  }
}
```

### `get_server` in Dream 3 <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/dream.gleam#L242-L247"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn get_server(
  dream: Dream(server, context, services, router),
  risks_understood _risks: RisksUnderstood,
) -> server {
  dream.server
}
```

### The `RisksUnderstood` type <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/dream.gleam#L189-L191"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type RisksUnderstood {
  RisksUnderstood
}
```

**How to fix it.** Replace `risks_understood: True` with `risks_understood: dream.RisksUnderstood`.

**What changed in `response.convert`.** `convert` from `dream/servers/mist/response` takes the Mist request first, and it converts a `Stream` body too. In Dream 2 it panicked on a `Stream` body:

### `convert` in Dream 2 <a href="https://github.com/TrustBound/dream/blob/2.4.1/src/dream/servers/mist/response.gleam#L52"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
pub fn convert(dream_resp: Response) -> http_response.Response(ResponseData) {
```

### `convert` in Dream 3 <a href="https://github.com/TrustBound/dream/blob/3.0.0/src/dream/servers/mist/response.gleam#L69-L72"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn convert(
  mist_request: http_request.Request(Connection),
  dream_response: Response,
) -> http_response.Response(ResponseData) {
```

**How to fix it.** Give the Mist request as the first argument. `convert_stream` is private now: call `convert` for every body.

## Step 11: Answer the Conflict error

**What changed.** `Error` has one more variant: `Conflict(String)`. `to_status_code` gives `409` for it. Use it when a request clashes with the current state of a resource: a unique value that is already taken, an edit against a stale version, or a state change that the current state does not allow. A `case` that names every `Error` value does not compile until it has a `Conflict` branch. The `simple` example had this helper in Dream 2:

### `handle_error` in Dream 2 <a href="https://github.com/TrustBound/dream/blob/2.4.1/examples/simple/src/utilities/response_helpers.gleam#L11-L24"><img align="right" alt="Code at 2.4.1" src="https://img.shields.io/badge/%F0%9F%93%9C_code_at-2.4.1-lightgrey.svg?style=flat-square"></a>

```gleam
pub fn handle_error(err: Error) -> Response {
  case err {
    error.BadRequest(msg) ->
      text_response(status.bad_request, "Bad Request: " <> msg)
    error.Unauthorized(_msg) ->
      text_response(status.unauthorized, "Unauthorized")
    error.Forbidden(_msg) -> text_response(status.forbidden, "Forbidden")
    error.NotFound(msg) -> text_response(status.not_found, "Not Found: " <> msg)
    error.UnprocessableContent(msg) ->
      text_response(status.unprocessable_content, "Unprocessable: " <> msg)
    error.InternalServerError(_msg) ->
      text_response(status.internal_server_error, "Internal Server Error")
  }
}
```

**How to fix it.** Add a `Conflict` branch. In Dream 3 the helper answers `409` with the message:

### `handle_error` in Dream 3 <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/src/utilities/response_helpers.gleam#L11-L25"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn handle_error(err: Error) -> Response {
  case err {
    error.BadRequest(msg) ->
      text_response(status.bad_request, "Bad Request: " <> msg)
    error.Unauthorized(_msg) ->
      text_response(status.unauthorized, "Unauthorized")
    error.Forbidden(_msg) -> text_response(status.forbidden, "Forbidden")
    error.NotFound(msg) -> text_response(status.not_found, "Not Found: " <> msg)
    error.Conflict(msg) -> text_response(status.conflict, "Conflict: " <> msg)
    error.UnprocessableContent(msg) ->
      text_response(status.unprocessable_content, "Unprocessable: " <> msg)
    error.InternalServerError(_msg) ->
      text_response(status.internal_server_error, "Internal Server Error")
  }
}
```

If your code answered a taken unique value with `UnprocessableContent` or `InternalServerError`, return `Conflict` in its place, so the client gets `409`.

## Step 12: Check the behavior changes

These changes compile with no error, but a test or a client can see them:

- **405 for a known path with another method.** A request whose path matches a route, with a method that no route of the path has, gets `405 Method Not Allowed` with an `Allow` header and the body `Method not allowed`. In Dream 2 it got `404 Route not found`. A client or a test that expects `404` for a wrong method must expect `405`. A path that no route matches still gets `404`.
- **Body over the size limit.** A buffered body over `max_body_size` gets `413 Content Too Large` with the body `Request body too large`. In Dream 2 it got `400` with an empty body, and a chunked body over the limit reached the controller. A body that cannot be read still gets `400`, now with the body `Request body could not be read`.
- **Router fallback.** When a route fits the start of a path but fails deeper down, the router tries the next route. With `/users/:id/posts` and `/users/**rest`, `GET /users/1/comments` finds `/users/**rest`. In Dream 2 it returned 404. A wildcard route can receive requests that got a 404 before.
- **Methods.** A request with CONNECT, TRACE or another method without its own constructor gets the route of that method, or the 405 or 404 above. In Dream 2 it ran the GET route of its path.
- **Missing path parameter message.** `get_int_param`, `get_string_param`, `require_int` and `require_string` give `Missing required path parameter: id` for a missing parameter, the message of `get_param`. In Dream 2 they gave `Missing id parameter`.
- **`server.stop`.** `stop` stops the server from any process, and it returns after the server is down. In Dream 2 it did nothing unless the process that started the server called it.
- **Broadcaster.** The broadcaster removes a subscriber when the process that subscribed stops. You do not have to call `unsubscribe` before a WebSocket or SSE connection ends. New function: `broadcaster.count_subscribers`.
- **Form, query string and cookie values.** A value that contains `=` is kept. `token=a=b` gives the value `a=b`. In Dream 2 the form field and the query parameter were dropped, and the cookie value was empty.
- **SSE `on_init` selector.** The selector that `on_init` returns is used, as in Dream 2.4.
- **Cookie `Expires`.** The `Set-Cookie` header writes `expires` as an HTTP date, `Expires=Tue, 14 Nov 2023 22:13:20 GMT`. In Dream 2 it was the number of seconds, which browsers ignore.
- **IPv6 `remote_address`.** An IPv6 client gives its real address, such as `2601:282:a00:b38::421d`. In Dream 2 every IPv6 client was `::1`.
- **Binary static files.** `static.serve` sends a file that is not UTF-8 as `Bytes` with status 200. In Dream 2 it answered 404. A UTF-8 file is still `Text`.
- **Connection after an unread body.** Over HTTP/1.1, the server closes the connection after it answers a request whose body it did not read to its end, and sends `connection: close`. A client that sends a body Dream refuses (`404`, `405`, `413`) opens a new connection for its next request. HTTP clients do that by themselves.

## Step 13: Update your tests to dream_test 3

The testing guide shows tests for `dream_test` 3.0.0. Dream 3.0.0 does not need a change to your tests, and they can stay on `dream_test` 1.x. To use the code of the new guide, set `dream_test = ">= 3.0.0 and < 4.0.0"` in `[dev-dependencies]` and run `gleam deps update dream_test`. Then change your tests as the [dream_test 2.0.0 release notes](https://github.com/TrustBound/dream_test/blob/2.0.0/releases/release-2.0.0.md) and the [dream_test upgrade guide](https://hexdocs.pm/dream_test/3.0.0/guides/upgrading-to-3.html) show.

## Test your code

Run your tests:

```bash illustration
gleam test
```

A failure after the upgrade is one of the changes above. A test that expects `404` for a wrong method, `400` for a large body, or `Missing id parameter` belongs to [Step 12](#step-12-check-the-behavior-changes). A test that builds a `Request` belongs to [Step 3](#step-3-read-request-bodies-as-a-requestbody). [Test your controllers and your app](https://hexdocs.pm/dream/3.0.0/guides/testing.html) shows how to test controllers, routes and a running server with Dream 3.

## Common pitfalls

**A duplicate module error for `mist`.** *Symptom:* the build stops because two packages define the module `mist`. *Fix:* remove `mist` from `gleam.toml`, as [Step 2](#step-2-replace-mist-and-glisten) shows. `dream_http_server` gives the module.

**A type mismatch between `NoRouter` and `Router`.** *Symptom:* the build fails at `server.context()`, `server.services()` or `server.listen()`. *Fix:* call `context()` and `services()` before `router()`, and `router()` before `listen()`.

**An empty body after the upgrade.** *Symptom:* a controller that matched `Text(body)` gets no text for an upload. *Fix:* a body that is not valid UTF-8 arrives as `Bytes`. Match `Bytes` too, or use `body_as_string` and answer its `Error`.

**A name clash between `Text` of a request and of a response.** *Symptom:* the compiler says that `Text` is a `ResponseBody` where you meant a `RequestBody`. *Fix:* write `request.Text`, `request.Bytes` and `request.Stream` on the request side.

## Where to go next

- [Read request data safely](https://hexdocs.pm/dream/3.0.0/guides/request-data.html): query strings, `require_json` and forms with Dream 3.
- [Stream responses and uploads](https://hexdocs.pm/dream/3.0.0/guides/streaming.html): streamed uploads and the `Error` item.
- [Start, stop and troubleshoot the server](https://hexdocs.pm/dream/3.0.0/guides/operating.html): start errors, body limits and stopping.
- [Dream 3.0.0 release notes](https://github.com/TrustBound/dream/blob/3.0.0/releases/release-3.0.0.md): what is new, and why.
