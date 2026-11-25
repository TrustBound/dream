# Render HTML and other formats

Your app serves pages to browsers and data to scripts, often the same data. You want HTML that's type-checked like the rest of your Gleam, markup you write once and reuse, and one route that answers JSON, HTML, an HTMX fragment or CSV depending on what the client asks for. This guide uses Matcha templates in four layers, as the `tasks` example does, and the `multi_format` example for one controller with many formats. Every output is what the `multi_format` server answers.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which format and which layer to use](#which-format-and-which-layer-to-use)
- [Step 1: Compile a template](#step-1-compile-a-template)
- [Step 2: Build pages from layers](#step-2-build-pages-from-layers)
- [Step 3: Answer one route in many formats](#step-3-answer-one-route-in-many-formats)
- [Step 4: Pick the format from the request](#step-4-pick-the-format-from-the-request)
- [When the format or the record is wrong](#when-the-format-or-the-record-is-wrong)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

- A `.matcha` template compiled to a Gleam module with a `render` function.
- Pages built from elements, components, pages and layouts.
- `/products/1`, `/products/1.json`, `/products/1.htmx` and `/products/1.csv` from one controller.
- A function that picks the format from the extension or from an HTMX header, and its test.

## Before you start

Read [Send responses, cookies and files](https://hexdocs.pm/dream/3.0.0/guides/responses.html) for the response builders. You need Dream, and the `matcha` binary of the [Matcha template compiler](https://github.com/michaeljones/matcha) on your `PATH`. Dream's CI installs version 0.19.0 for Linux with `scripts/install-matcha.sh`, which checks the download against the checksum of the release:

### Download, check and unpack matcha <a href="https://github.com/TrustBound/dream/blob/3.0.0/scripts/install-matcha.sh#L15-L17"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```sh
curl -fsSL -o "$FOLDER/$ARCHIVE" "https://github.com/michaeljones/matcha/releases/download/$VERSION/$ARCHIVE"
echo "$SHA256  $FOLDER/$ARCHIVE" | sha256sum -c -
tar -xzf "$FOLDER/$ARCHIVE" -C "$FOLDER" matcha
```

On another system, take the archive for it from the same release page. The `multi_format` example needs PostgreSQL on port 5435: run `make setup-integration-dbs` in the root of the Dream repository, then `make run` in `examples/multi_format`. It listens on port 3000.

Dream doesn't need Matcha. Any way of making a `String` of HTML works with `html_response`, and you can serve a front end built with React or Vue as static files instead.

## Which format and which layer to use

| The client | Format | Builder |
|:---|:---|:---|
| A browser asking for a page | Full HTML | `html_response` with a page in a layout |
| HTMX swapping part of a page | An HTML fragment | `html_response` with a component |
| A script or a mobile app | JSON | `json_response` |
| A spreadsheet | CSV | `text_response`, or `stream_response` for a big export |

| The markup | Layer | Kind of file |
|:---|:---|:---|
| One HTML tag with its classes, such as a button | Element | `.matcha` |
| A piece made of elements, such as a task card | Component | Gleam function |
| The content of one screen | Page | `.matcha` or Gleam |
| The frame around every page: head, nav, footer | Layout | Gleam function |

## Step 1: Compile a template

The basic Matcha mental model is:

- **Input:** `.matcha` files that contain mostly HTML plus a few
  templating directives.
- **Compiler:** an external `matcha` binary (written in Rust) that you
  run at the project root.
- **Output:** `.gleam` modules with `render` / `render_tree` functions
  that you import like any other module.

In practice you will usually add a small Makefile target. These are the targets of the `websocket_chat` example. `gleam format` makes the generated modules the same as the ones in the repository:

### The Matcha targets <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/websocket_chat/Makefile#L22-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```makefile
matcha:
	@matcha && gleam format src

build: matcha
	@gleam build
```

and then treat Matcha as “one extra step before Gleam builds”. If you’re
not familiar with Rust or Cargo, you can stick to downloading the
prebuilt Matcha binary and just use it via this Makefile target.

### From `.matcha` to Gleam

1. Create a simple template, e.g. `templates/elements/hello.matcha`. This is `test/snippets/templates_guide_hello.matcha`, which `make check-templates` compiles:

   #### The template <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/templates_guide_hello.matcha#L1-L2"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

   ```jinja
   {> with name as String
   Hello {{ name }}!
   ```

2. Run `matcha` at the project root (or `make matcha`). Matcha
   generates `templates/elements/hello.gleam` with a `render` function.
3. Import the generated module and call `render`, as the example below
   shows. `greet("Dream")` returns the rendered string `Hello Dream!`.

#### Calling the generated module <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/templates_guide_greeting.gleam#L7-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn greet(name: String) -> String {
  hello.render(name: name)
}
```

In this example the generated module is imported as `hello`.

You never call `render_tree` directly unless you are composing
`StringTree` values manually; most apps will just use the
`render(...) -> String` function.


## Step 2: Build pages from layers

### The Problem We Solved

In real-world applications, we've experienced pain points from:

- **Duplicated markup with slight variations**: Copying HTML with small changes leads to inconsistencies
- **Duplicated CSS styling as a result**: Each variation needs its own styles
- **Embedded inline HTML within Gleam files**: Makes code hard to read and maintain
- **These issues compound as applications grow**: What starts small becomes unmaintainable

### The Solution: Layered Template Composition

A four-layer approach that builds HTML from the bottom up:

1. **Elements** (matcha templates): Low-level HTML components
2. **Components** (gleam functions): Compose elements into reusable pieces
3. **Pages** (gleam functions): Compose components into full pages
4. **Layouts** (gleam functions): Page structure (nav, footer, main wrapper)

### Layer 1: Elements

Elements are the smallest reusable pieces. They're compiled from Matcha templates and represent semantic HTML components.

**Location:** `templates/elements/*.matcha`

**Example: Button Element**

#### The button element of the tasks example <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/src/templates/elements/button.matcha#L1-L10"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```matcha
{> with button_id as String
{> with button_type as String
{> with button_text as String
{> with attributes as String
<button 
  id="{{ button_id }}" 
  type="{{ button_type }}"
  {{ attributes }}>
  {{ button_text }}
</button>
```

**Characteristics:**
- Single-purpose semantic HTML
- Classless (styled via CSS frameworks like Pico CSS)
- Reusable across the entire application
- Compiled to Gleam functions via Matcha

Components call the generated `render` function of an element:

#### Using the button element <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/templates_guide_components.gleam#L15-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn save_button() -> String {
  button.render(
    button_id: "submit-btn",
    button_type: "submit",
    button_text: "Save Task",
    attributes: "hx-post=\"/tasks\"",
  )
}
```

### Layer 2: Components

Components are Gleam functions that compose multiple elements into reusable pieces. They handle presentation logic like formatting and conditional rendering.

**Location:** `templates/components/*.gleam`

The component below imports the generated element modules as `badge`, `button`, `checkbox`, `input` and `task_card`.

#### The task card component <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/templates_guide_components.gleam#L24-L73"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn task_card(task: Task) -> String {
  let task_id = int.to_string(task.id)

  // Compose elements
  let checkbox_html =
    checkbox.render(
      checkbox_id: "checkbox-" <> task_id,
      checkbox_name: "completed",
      label_text: "",
      checked_attr: checked_attribute(task.completed),
      attributes: htmx_attributes(task_id),
    )

  let title_input =
    input.render(
      input_id: "title-" <> task_id,
      input_name: "title",
      input_value: task.title,
      attributes: "readonly",
    )

  // Use compiled Matcha template for structure
  task_card.render(
    task_id: task_id,
    checkbox_html: checkbox_html,
    title_input: title_input,
    tags_html: render_tags(task.tags),
  )
}

pub fn task_list(tasks: List(Task)) -> String {
  list.map(tasks, task_card)
  |> string.concat
}

fn checked_attribute(completed: Bool) -> String {
  case completed {
    True -> "checked"
    False -> ""
  }
}

fn htmx_attributes(task_id: String) -> String {
  "hx-post=\"/tasks/" <> task_id <> "/toggle\""
}

fn render_tags(tags: List(Tag)) -> String {
  list.map(tags, fn(tag) { badge.render(label: tag.name) })
  |> string.concat
}
```

**Characteristics:**
- Combine multiple elements
- Handle presentation logic (formatting, conditionals)
- Reusable across pages
- Type-safe (full Gleam type checking)

### Layer 3: Pages

Pages compose multiple components into full page content. They represent the main content area of a page.

**Location:** `templates/pages/*.matcha` or `templates/pages/*.gleam`

**Example: Index Page**

#### The index page <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/templates_guide_index.matcha#L1-L3"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```matcha
{> with task_form as String
{> with task_list as String
<main><section><h1>Tasks</h1>{{ task_form }}</section><section>{{ task_list }}</section></main>
```

A page can also be a Gleam function:

#### The index page as a Gleam function <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/templates_guide_pages.gleam#L8-L15"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn index_page(tasks: List(Task)) -> String {
  // Components compose elements
  let task_list = task_components.task_list(tasks)
  let task_form = form_components.task_form()

  // Page composes components
  index.render(task_form:, task_list:)
}
```

**Characteristics:**
- Combine multiple components
- Represent page-level content
- No layout structure (that's handled by layouts)

### Layer 4: Layouts

Layouts wrap pages with consistent structure. They handle navigation, footer, scripts, and the overall page shell.

**Location:** `templates/layouts/*.gleam`

#### The page layout <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/templates_guide_layouts.gleam#L9-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn build_page(title: String, content: String) -> String {
  // Compose layout pieces
  let nav_html = nav.render()
  let main_html = main_wrapper.render(main_content: content)
  let footer_html = footer.render()
  let scripts_html = scripts.render()

  let body_content = nav_html <> main_html <> footer_html <> scripts_html

  // Wrap everything in page structure
  page.render(page_title: title, page_content: body_content)
}
```

**Characteristics:**
- Consistent page structure
- Handles navigation, footer, scripts
- Wraps any page content
- Single source of truth for page shell

### Complete Flow Example

Here's how all layers work together:

#### The view layer <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/templates_guide_views.gleam#L8-L18"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// View layer (views/task_view.gleam)
pub fn index_page(tasks: List(Task)) -> String {
  // Components compose elements
  let task_list = task_components.task_list(tasks)

  // Pages compose components
  let content = index.render(task_form: "", task_list:)

  // Layouts wrap pages
  layout_components.build_page("Tasks", content)
}
```

**Flow:**
1. Elements (button, input, checkbox) → compiled from Matcha templates
2. Components (task_card, task_list) → compose elements via Gleam functions
3. Pages (index) → compose components via Matcha or Gleam
4. Layouts (build_page) → wrap pages with consistent structure

### Benefits

This layered approach provides:

- **Eliminates duplication**: Reuse elements and components instead of copying markup
- **Consistent styling**: Changes to elements propagate automatically throughout the app
- **Type safety**: Full Gleam type checking throughout the template pipeline
- **Maintainability**: Clear separation of concerns makes changes predictable
- **Scalability**: Pattern works well as applications grow

### Best Practices

#### When to Use Each Layer

- **Elements**: Use for atomic HTML pieces (buttons, inputs, badges, icons)
- **Components**: Use for composed UI pieces (cards, forms, lists)
- **Pages**: Use for page-level content composition
- **Layouts**: Use for consistent page structure

#### Avoiding Duplication

- **Don't copy markup**: If you find yourself copying HTML, extract it to an element or component
- **Parameterize variations**: Use function parameters instead of creating separate templates
- **Compose, don't duplicate**: Build complex pieces from simpler ones

#### Type Safety

- All template functions are type-checked at compile time
- Matcha templates generate typed Gleam functions
- Errors caught before runtime

## Step 3: Answer one route in many formats

The `multi_format` example has one `show` controller for `/products/:id`. The router puts the extension of the last segment in `PathParam.format`, so `/products/1.json` gives the id `1` and the format `json`:

### One controller, four formats <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/multi_format/src/controllers/products_controller.gleam#L33-L69"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
/// Show single product - supports .json, .htmx, .csv extensions
pub fn show(
  request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  let result = {
    use param <- result.try(result.map_error(
      get_param(request, "id"),
      map_param_error,
    ))
    use id <- result.try(parse_int_param(param))
    let format = param.format
    let db = services.database.connection
    use product <- result.try(product_operations.get_product(db, id))
    Ok(#(product, format))
  }

  case result {
    Ok(#(product, format)) -> respond_with_format(product, format)
    Error(err) -> response_helpers.handle_error(err)
  }
}

fn respond_with_format(
  product: Product,
  format: option.Option(String),
) -> Response {
  case format {
    option.Some("json") ->
      json_response(status.ok, product_view.to_json(product))
    option.Some("htmx") ->
      html_response(status.ok, product_view.to_htmx(product))
    option.Some("csv") -> text_response(status.ok, product_view.to_csv(product))
    _ -> html_response(status.ok, product_view.to_html(product))
  }
}
```

Ask for the JSON and the CSV:

### Ask for JSON and CSV <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/multi_format/test/integration/readme.sh#L24-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i http://localhost:3000/products/1.json
echo
curl -i http://localhost:3000/products/1.csv
```

### The two answers <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/multi_format/test/integration/readme_output.txt#L69-L82"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 200 OK
content-type: application/json; charset=utf-8
content-length: 50
date: (the time of the request)
connection: keep-alive

{"id":1,"name":"Laptop","price":999.99,"stock":15}
HTTP/1.1 200 OK
content-type: text/plain; charset=utf-8
content-length: 18
date: (the time of the request)
connection: keep-alive

1,Laptop,999.99,15
```

The view module has one function for each format, and the controller only picks one. That's the pattern in a few lines of a smaller app:

### Controller and view

Use a helper function to switch formats based on the request. `detect_format` is in [Step 4](#step-4-pick-the-format-from-the-request).

#### The show controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/multiple_formats_guide_tasks.gleam#L22-L49"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn show(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  let result = {
    use id <- result.try(require_int(request, "id"))
    find_task(services.tasks, id)
  }

  case result {
    Ok(task) -> respond_with_format(task, detect_format(request))
    Error(error) -> respond_with_error(error)
  }
}

fn respond_with_format(task: Task, format: String) -> Response {
  case format {
    // HTMX request asking for just the card partial
    "htmx" -> html_response(ok, task_view.card(task))

    // Full HTML page
    "html" -> html_response(ok, task_view.page(task))

    // Default to JSON
    _ -> json_response(ok, task_view.to_json(task))
  }
}
```

### The view

Your view module handles the different presentations. For HTML rendering, we use a layered template composition approach that keeps markup consistent and reusable.

#### The task view <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/multiple_formats_guide_task_view.gleam#L8-L27"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// JSON representation
pub fn to_json(task: Task) -> String {
  json.object([
    #("id", json.int(task.id)),
    #("title", json.string(task.title)),
  ])
  |> json.to_string()
}

// HTML Partial (for HTMX or including in other pages)
pub fn card(task: Task) -> String {
  // Components compose elements into reusable pieces
  task_components.task_card(task)
}

// Full HTML Page
pub fn page(task: Task) -> String {
  // Layouts wrap components with consistent structure
  layout_components.build_page(task.title, card(task))
}
```

**Template Composition Architecture:**

This pattern uses four layers to build HTML:

1. **Elements** (`templates/elements/*.matcha`): Low-level HTML components
   - Semantic HTML templates (buttons, inputs, cards, badges)
   - Compiled from Matcha templates
   - Reusable across the entire application

2. **Components** (`templates/components/*.gleam`): Compose elements into reusable pieces
   - Gleam functions that combine multiple elements
   - Handle presentation logic (formatting, conditional rendering)
   - Examples: `task_card()`, `task_form()`, `task_list()`

3. **Pages** (`templates/pages/*.matcha` or `.gleam`): Compose components into full pages
   - Page-level templates that combine multiple components
   - Examples: `index.render()`, `show.render()`

4. **Layouts** (`templates/layouts/*.gleam`): Page structure (nav, footer, main wrapper)
   - Wraps pages with consistent structure
   - Handles navigation, footer, scripts
   - Example: `layout_components.build_page(title, content)`

This layered approach solves real-world problems:
- **Eliminates duplication**: Reuse elements and components instead of copying markup
- **Consistent styling**: Changes to elements propagate automatically
- **Type safety**: Full Gleam type checking throughout the template pipeline
- **Maintainability**: Clear separation of concerns makes changes predictable

See [Template Composition](https://hexdocs.pm/dream/3.0.0/guides/templates.html) for a complete guide to this pattern.


## Step 4: Pick the format from the request

You can detect the desired format via:

1.  **URL Extension:** `/tasks/1.json`, `/tasks/1.html` (`get_param` puts the extension in `PathParam.format`, and `require_int` reads `1`)
2.  **Accept Header:** `Accept: application/json`
3.  **Custom Header:** `HX-Request: true` (common with HTMX)

#### Format from the extension or the headers <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/multiple_formats_guide_tasks.gleam#L51-L66"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// /tasks/1.json and /tasks/1.html: Dream puts the extension in
// PathParam.format
pub fn detect_format(request: Request) -> String {
  case get_param(request, "id") {
    Ok(PathParam(format: Some(format), ..)) -> format
    _ -> detect_format_from_headers(request)
  }
}

fn detect_format_from_headers(request: Request) -> String {
  case get_header(request.headers, "HX-Request") {
    Some("true") -> "htmx"
    // Default
    _ -> "json"
  }
}
```


## When the format or the record is wrong

A product that doesn't exist gets a `404`. The error answer comes from `response_helpers.handle_error`, which knows nothing about formats, so even a `.json` request gets HTML:

### Ask for a missing product as JSON <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/multi_format/test/integration/readme.sh#L28"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i http://localhost:3000/products/99.json
```

### An HTML 404 <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/multi_format/test/integration/readme_output.txt#L83-L89"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 404 Not Found
content-type: text/html; charset=utf-8
content-length: 46
date: (the time of the request)
connection: keep-alive

<h1>404 Not Found</h1><p>Product not found</p>
```

An extension the controller doesn't know falls through to the full HTML page, with `200`:

### Ask for XML <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/multi_format/test/integration/readme.sh#L30"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -s -o /dev/null -w "%{http_code} %{content_type}\n" http://localhost:3000/products/1.xml
```

### HTML, not an error <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/multi_format/test/integration/readme_output.txt#L90"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
200 text/html; charset=utf-8
```

If your clients rely on the format, give the error helper the format too, and answer `406 Not Acceptable` for a format you don't serve.

## Test your code

The choice of format is a small function, so test it on its own with requests you build. This test checks `detect_format` from Step 4:

### Test the format choice <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/guide_templates_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Templates guide: a test of the format a request asks for
////
//// detect_format is from test/snippets/multiple_formats_guide_tasks.gleam.

import dream/http/header.{type Header, Header}
import dream/http/request.{type Request, Get, Http, Http1, Request}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import snippets/multiple_formats_guide_tasks.{detect_format}

// A request for /tasks/:id, with the id segment as the router gives it
fn task_request(id_segment: String, headers: List(Header)) -> Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path: "/tasks/" <> id_segment,
    query: "",
    params: [#("id", id_segment)],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: request.Text(""),
    headers: headers,
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

pub fn tests() -> TestSuite {
  describe("detect_format", [
    it("takes the format from the extension of the id", fn() {
      // Arrange
      let request = task_request("1.csv", [])

      // Act
      let format = detect_format(request)

      // Assert
      format
      |> should
      |> be_equal("csv")
      |> or_fail_with("/tasks/1.csv should ask for csv")
    }),
    it("answers htmx for an HTMX request with no extension", fn() {
      // Arrange
      let request = task_request("1", [Header("HX-Request", "true")])

      // Act
      let format = detect_format(request)

      // Assert
      format
      |> should
      |> be_equal("htmx")
      |> or_fail_with("HX-Request: true should ask for htmx")
    }),
    it("falls back to json", fn() {
      // Arrange
      let request = task_request("1", [])

      // Act
      let format = detect_format(request)

      // Assert
      format
      |> should
      |> be_equal("json")
      |> or_fail_with("no extension and no header should give json")
    }),
  ])
}
```

### The report of the test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/guide_templates_report.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
detect_format
  ✓ answers htmx for an HTMX request with no extension
  ✓ falls back to json
  ✓ takes the format from the extension of the id

Summary: 3 run, 0 failed, 3 passed in 0ms
```

To check that the generated template modules match their templates, Dream's CI runs `make check-templates`: it compiles every `.matcha` file in a copy of the folder and fails when a generated module differs.

## Common pitfalls

- **The generated `.gleam` file was edited by hand.** The next `matcha` run overwrites it. Change the `.matcha` file and run `make matcha`.
- **Generated modules that `gleam format --check` rejects.** Matcha's output isn't formatted. Run `gleam format src` after `matcha`, as the `matcha` target does.
- **An error answer in the wrong format.** A JSON client that gets an HTML `404` can't parse it. Pass the format to the error helper.
- **An unknown extension gets a page.** `.xml` gets HTML with `200`. Match the formats you serve and answer `406` for the rest.
- **Logic in templates.** Keep templates to markup and loops. Decide what to show in the controller or the view function.

## Where to go next

- [Send responses, cookies and files](https://hexdocs.pm/dream/3.0.0/guides/responses.html).
- [Stream responses and uploads](https://hexdocs.pm/dream/3.0.0/guides/streaming.html): the streamed CSV export of `/products.csv`.
- [Build a chat with WebSockets](https://hexdocs.pm/dream/3.0.0/guides/websockets.html): Matcha templates in a live app.
- [Matcha on GitHub](https://github.com/michaeljones/matcha).
