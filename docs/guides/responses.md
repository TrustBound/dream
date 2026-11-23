# Send responses, cookies and files

A controller's job ends with a `Response`. Most of the time that's text or JSON, but a real app also redirects, answers with nothing, sends a file to download, sets a cookie and serves a folder of CSS and images. This guide builds each of those with Dream's response builders and its static file controller, and shows the real headers and bodies that come back. The code is from `examples/simple` and `examples/static`.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which builder to use](#which-builder-to-use)
- [Step 1: Redirect, answer with nothing, send a download](#step-1-redirect-answer-with-nothing-send-a-download)
- [Step 2: Read and set a cookie](#step-2-read-and-set-a-cookie)
- [Step 3: Serve a folder of static files](#step-3-serve-a-folder-of-static-files)
- [Step 4: Answer a missing file your way](#step-4-answer-a-missing-file-your-way)
- [Requests that can't escape the folder](#requests-that-cant-escape-the-folder)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

- A `301` redirect, a `204 No Content`, and a CSV download with a `Content-Disposition` header.
- A visit counter in a cookie.
- `/public/...` served from a folder, with the right content type for each file.
- A custom page for files that don't exist, and the `404` for paths that try to leave the folder.

## Before you start

Read [Build your first Dream server](https://github.com/TrustBound/dream/blob/main/docs/guides/getting-started.md) first. You need Dream:

```sh
gleam add dream
```

Both examples run from the Dream repository with `make run` in their folder, on port 3000.

## Which builder to use

Each builder takes the status first. `dream/http/status` has a name for each common code: `ok`, `created`, `accepted`, `no_content`, `moved_permanently`, `found`, `see_other`, `temporary_redirect`, `bad_request`, `unauthorized`, `forbidden`, `not_found`, `method_not_allowed`, `conflict`, `teapot`, `unprocessable_content`, `too_many_requests`, `internal_server_error`, `not_implemented` and `service_unavailable`. `dream/http` has the same names, so `import dream/http.{ok}` works too.

| You want to send | Use | What it sets |
|:---|:---|:---|
| Plain text | `text_response(status, body)` | `text/plain; charset=utf-8` |
| JSON you built with `gleam/json` | `json_response(status, body)` | `application/json; charset=utf-8` |
| HTML | `html_response(status, body)` | `text/html; charset=utf-8` |
| A redirect | `redirect_response(status, location)` | A `Location` header and an empty body |
| No body | `empty_response(status)` | Nothing but the status |
| Bytes, such as a file or an image | `binary_response(status, bytes, content_type)` | The content type you give |
| A body made while it's sent | `stream_response(status, yielder, content_type)` | See [Stream responses and uploads](https://github.com/TrustBound/dream/blob/main/docs/guides/streaming.md) |
| Server-sent events | `sse_response` | See [Push live updates with server-sent events](https://github.com/TrustBound/dream/blob/main/docs/guides/sse.md) |
| Files from a folder | `static.serve(...)` from `dream/controllers/static` | The content type from the file's extension |

A `Response` is a record with `status`, `body`, `headers`, `cookies` and `content_type`, so you change any part of it with the record update syntax `Response(..response, headers: ...)`.

## Step 1: Redirect, answer with nothing, send a download

### Three builders <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/src/controllers/responses_controller.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Responses controller
////
//// The response builders that are not text or JSON: a redirect, an empty
//// answer, and a file download with headers of its own.

import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response}
import dream/http/header.{add_header}
import dream/http/response.{
  Response, binary_response, empty_response, redirect_response,
}
import dream/http/status
import dream/router.{type EmptyServices}

/// GET /old-home: the page moved to /
pub fn moved(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  redirect_response(status.moved_permanently, "/")
}

/// DELETE /sessions: nothing to send back
pub fn sign_out(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  empty_response(status.no_content)
}

/// GET /report.csv: bytes that the browser saves as a file
pub fn download_report(
  _request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let csv = <<"id,name\n1,Ada\n2,Grace\n":utf8>>
  let response = binary_response(status.ok, csv, "text/csv")
  Response(
    ..response,
    headers: add_header(
      response.headers,
      "Content-Disposition",
      "attachment; filename=\"report.csv\"",
    ),
  )
}
```

`download_report` adds a header to the response that `binary_response` made. `add_header` keeps the headers that are there, and `set_header` would replace one with the same name.

### Ask for each one <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L47-L49"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i http://localhost:3000/old-home
curl -i -X DELETE http://localhost:3000/sessions
curl -i http://localhost:3000/report.csv
```

### The three answers <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L687-L706"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 301 Moved Permanently
location: /
content-length: 0
date: (the time of the request)
connection: keep-alive

HTTP/1.1 204 No Content
date: (the time of the request)
connection: keep-alive

HTTP/1.1 200 OK
content-disposition: attachment; filename="report.csv"
content-type: text/csv
content-length: 22
date: (the time of the request)
connection: keep-alive

id,name
1,Ada
2,Grace
```

The redirect carries `content-length: 0`, and the `204` has no content headers at all, as the HTTP standard asks for a `204`.

## Step 2: Read and set a cookie

The request's cookies arrive parsed in `request.cookies`. A response sends cookies in its `cookies` field, and Dream writes a `Set-Cookie` header for each one:

### Count visits in a cookie <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/src/controllers/visits_controller.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Visits controller
////
//// Counts the visits of one browser in a cookie: reads the cookie of the
//// request and sends the new count back in a Set-Cookie header.

import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response}
import dream/http/cookie.{get_cookie_value, simple_cookie}
import dream/http/response.{Response, text_response}
import dream/http/status
import dream/router.{type EmptyServices}
import gleam/int
import gleam/option
import gleam/result

/// GET /visits
pub fn show(
  request: Request,
  _context: EmptyContext,
  _services: EmptyServices,
) -> Response {
  let visits =
    get_cookie_value(request.cookies, "visits")
    |> option.to_result(Nil)
    |> result.try(int.parse)
    |> result.unwrap(0)
    |> int.add(1)
  let count = int.to_string(visits)

  Response(..text_response(status.ok, "Visit number " <> count), cookies: [
    simple_cookie("visits", count),
  ])
}
```

The first visit has no cookie. The second sends the cookie back as a browser would:

### Two visits <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme.sh#L43-L45"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i http://localhost:3000/visits
echo
curl -i --cookie "visits=4" http://localhost:3000/visits
```

### The two answers <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/simple/test/integration/readme_output.txt#L671-L686"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 200 OK
set-cookie: visits=1
content-type: text/plain; charset=utf-8
content-length: 14
date: (the time of the request)
connection: keep-alive

Visit number 1
HTTP/1.1 200 OK
set-cookie: visits=5
content-type: text/plain; charset=utf-8
content-length: 14
date: (the time of the request)
connection: keep-alive

Visit number 5
```

A cookie value that isn't a number counts as no cookie, so the controller can't crash on a value a client made up. `simple_cookie` sets only the name and the value. For a session id use `secure_cookie`, which adds `Secure`, `HttpOnly` and `SameSite=Strict`. To delete a cookie in the browser, send it again with `max_age: option.Some(0)`.

## Step 3: Serve a folder of static files

`static.serve` answers a request with a file from a folder. The route gives it the rest of the path with a `**name` segment, which matches any number of path segments:

### The /public route <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/static/src/router.gleam#L6-L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_router() -> Router(EmptyContext, EmptyServices) {
  router()
  // Multi-segment named wildcard: **filepath
  |> route(
    method: Get,
    path: "/public/**filepath",
    controller: static_controller.serve_public,
    middleware: [],
  )
```

### Serve /public with a directory listing <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/static/src/controllers/static_controller.gleam#L11-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Serve files from /public with directory listing
pub fn serve_public(
  request: Request,
  context: EmptyContext,
  services: EmptyServices,
) -> Response {
  case get_param(request, "filepath") {
    Ok(param) ->
      static.serve(
        request: request,
        context: context,
        services: services,
        root: "./public",
        filepath: param.raw,
        config: static.default_config() |> static.with_directory_listing(),
      )
    Error(error_msg) ->
      html_response(
        status.bad_request,
        "<h1>Error</h1><p>" <> error_msg <> "</p>",
      )
  }
}
```

The example serves these files:

### List the files <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/static/test/integration/readme.sh#L21"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
find public -type f | sort
```

### The files of public/ <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/static/test/integration/readme_output.txt#L48-L54"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
public/about/index.html
public/images/cat.svg
public/images/logo.png
public/images/photo.jpg
public/index.html
public/script.js
public/styles.css
```

Ask for the stylesheet and look only at the headers:

### Ask for styles.css <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/static/test/integration/readme.sh#L13"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -s -D - -o /dev/null http://localhost:3000/public/styles.css
```

### The headers of styles.css <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/static/test/integration/readme_output.txt#L28-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 200 OK
content-type: text/css
content-length: 760
date: (the time of the request)
connection: keep-alive

```

The content type comes from the extension. The config decides the rest:

| Config | What it does |
|:---|:---|
| `static.default_config()` | Serves files, and `index.html` for a folder path. Answers `404` for a missing file. |
| `\|> static.with_directory_listing()` | Lists the files of a folder that has no `index.html`. |
| `\|> static.without_index()` | Never serves `index.html` for a folder path. |
| `\|> static.with_custom_404(controller)` | Runs your controller for a missing file. |

The root folder is relative to the folder you start the server from. The example starts from `examples/static`, so `./public` is `examples/static/public`.

## Step 4: Answer a missing file your way

The default answer for a missing file is a small HTML page:

### Ask for a missing file <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/static/test/integration/readme.sh#L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i http://localhost:3000/public/missing.css
```

### The default 404 <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/static/test/integration/readme_output.txt#L34-L40"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 404 Not Found
content-type: text/html; charset=utf-8
content-length: 22
date: (the time of the request)
connection: keep-alive

<h1>404 Not Found</h1>
```

`with_custom_404` takes a controller, so the page can be anything you can build:

### Serve with a custom 404 <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/static/src/controllers/static_controller.gleam#L158-L186"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Serve with custom 404
pub fn serve_with_custom_404(
  request: Request,
  context: EmptyContext,
  services: EmptyServices,
) -> Response {
  case get_param(request, "filepath") {
    Ok(param) ->
      static.serve(
        request: request,
        context: context,
        services: services,
        root: "./public",
        filepath: param.raw,
        config: static.default_config()
          |> static.with_custom_404(fn(_req, _ctx, _svc) {
            html_response(
              status.not_found,
              "<h1>Custom 404</h1><p>The requested file does not exist.</p>",
            )
          }),
      )
    Error(error_msg) ->
      html_response(
        status.bad_request,
        "<h1>Error</h1><p>" <> error_msg <> "</p>",
      )
  }
}
```

### Ask for a missing file under /custom <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/static/test/integration/readme.sh#L16"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i http://localhost:3000/custom/missing.css
```

### The custom 404 <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/static/test/integration/readme_output.txt#L41-L47"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 404 Not Found
content-type: text/html; charset=utf-8
content-length: 60
date: (the time of the request)
connection: keep-alive

<h1>Custom 404</h1><p>The requested file does not exist.</p>
```

## Requests that can't escape the folder

A path with `..` in it tries to read files outside the root. `static.serve` refuses it, and so does a dot file such as `.env`. Each of these answers `404`:

### Try to leave the folder <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/static/test/integration/readme.sh#L4-L6"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl --path-as-is -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/public/../../../etc/passwd
curl --path-as-is -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/public/../../secrets
curl --path-as-is -s -o /dev/null -w "%{http_code}\n" http://localhost:3000/public/.env
```

### Three 404s <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/static/test/integration/readme_output.txt#L1-L3"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
404
404
404
```

`--path-as-is` stops curl from removing the `..` itself, so the server really gets it.

## Test your code

A controller that builds a response can be tested without a server: call it and look at the fields of the `Response`. This test checks the cookies that the visit counter of Step 2 sends back. The module it imports is the same code as `visits_controller.gleam` of the example, and a test of Dream checks that the two stay the same:

### Test the cookie of a response <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/guide_responses_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Responses guide: a test of the cookie that a controller sends back

import dream/context.{EmptyContext}
import dream/http/cookie.{type Cookie, simple_cookie}
import dream/http/request.{type Request, Get, Http, Http1, Request}
import dream/router.{EmptyServices}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import snippets/guide_responses_visits as visits_controller

fn visit(cookies: List(Cookie)) -> Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path: "/visits",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: request.Text(""),
    headers: [],
    cookies: cookies,
    content_type: option.None,
    content_length: option.None,
  )
}

pub fn tests() -> TestSuite {
  describe("visits_controller.show", [
    it("sets visits to 1 on the first visit", fn() {
      // Arrange
      let request = visit([])

      // Act
      let response =
        visits_controller.show(request, EmptyContext, EmptyServices)

      // Assert
      response.cookies
      |> should
      |> be_equal([simple_cookie("visits", "1")])
      |> or_fail_with("the first visit should set visits=1")
    }),
    it("adds one to the cookie of the request", fn() {
      // Arrange
      let request = visit([simple_cookie("visits", "4")])

      // Act
      let response =
        visits_controller.show(request, EmptyContext, EmptyServices)

      // Assert
      response.cookies
      |> should
      |> be_equal([simple_cookie("visits", "5")])
      |> or_fail_with("visits=4 should become visits=5")
    }),
    it("starts again at 1 when the cookie is not a number", fn() {
      // Arrange
      let request = visit([simple_cookie("visits", "many")])

      // Act
      let response =
        visits_controller.show(request, EmptyContext, EmptyServices)

      // Assert
      response.cookies
      |> should
      |> be_equal([simple_cookie("visits", "1")])
      |> or_fail_with("a cookie that is not a number should count as none")
    }),
  ])
}
```

### The report of the test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/guide_responses_report.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
visits_controller.show
  ✓ adds one to the cookie of the request
  ✓ sets visits to 1 on the first visit
  ✓ starts again at 1 when the cookie is not a number

Summary: 3 run, 0 failed, 3 passed in 0ms
```

## Common pitfalls

- **The static root is wrong in production.** `./public` is relative to the folder the server starts in. In a container, start the app from the folder that holds `public/`, or give an absolute path.
- **A `204` with a body.** `empty_response` is the builder for "no content". A `text_response(status.no_content, "...")` sends a body that clients must ignore.
- **A cookie set but never sent.** Cookies go in the `cookies` field of the `Response`, not in `headers`. A `Set-Cookie` header you add by hand works too, but then Dream can't check it.
- **A session cookie without `Secure` and `HttpOnly`.** Use `secure_cookie` for anything that identifies a user.
- **Listing a folder by accident.** `with_directory_listing` shows every file name in the folder. Use it only for folders meant to be browsed.

## Where to go next

- [Render HTML and other formats](https://github.com/TrustBound/dream/blob/main/docs/guides/templates.md): HTML from templates, and one route that answers JSON, HTML or CSV.
- [Stream responses and uploads](https://github.com/TrustBound/dream/blob/main/docs/guides/streaming.md): bodies too big to build at once.
- [Read request data safely](https://github.com/TrustBound/dream/blob/main/docs/guides/request-data.md).
- The API reference of `dream/http/response`, `dream/http/cookie` and `dream/controllers/static` on [HexDocs](https://hexdocs.pm/dream/).
