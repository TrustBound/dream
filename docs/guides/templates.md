# Template Composition

Many developers choose front-end frameworks like React or Vue, which is
perfectly fine. Dream lets you choose whatever you want for a
front-end.

For those who want server-side rendering **in Gleam** with full type
safety, this guide explains a layered approach that keeps markup
consistent, DRY, and reusable as applications grow.

You do not need to be a Matcha expert to follow along. We will point out
where each layer’s files live and how they fit into the view layer of a
Dream app.

The basic Matcha mental model is:

- **Input:** `.matcha` files that contain mostly HTML plus a few
  templating directives.
- **Compiler:** an external `matcha` binary (written in Rust) that you
  run at the project root.
- **Output:** `.gleam` modules with `render` / `render_tree` functions
  that you import like any other module.

In practice you will usually add a small Makefile target:

```makefile
matcha:
	@matcha

build:
	@make matcha
	@gleam build
```

and then treat Matcha as “one extra step before Gleam builds”. If you’re
not familiar with Rust or Cargo, you can stick to downloading the
prebuilt Matcha binary and just use it via this Makefile target.

### Mini walkthrough: from `.matcha` to Gleam

1. Create a simple template, e.g. `templates/elements/hello.matcha`:

   ```jinja
   {> with name as String
   Hello {{ name }}!
   ```

2. Run `matcha` at the project root (or `make matcha`). Matcha
   generates `templates/elements/hello.gleam` with a `render` function.
3. Import the generated module and call `render`, as the example below
   shows. `greet("Dream")` returns the rendered string `Hello Dream!`.

#### Calling the generated module <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/templates_guide_greeting.gleam#L7-L9"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn greet(name: String) -> String {
  hello.render(name: name)
}
```

In this example the generated module is imported as `hello`.

You never call `render_tree` directly unless you are composing
`StringTree` values manually; most apps will just use the
`render(...) -> String` function.

## The Problem We Solved

In real-world applications, we've experienced pain points from:

- **Duplicated markup with slight variations**: Copying HTML with small changes leads to inconsistencies
- **Duplicated CSS styling as a result**: Each variation needs its own styles
- **Embedded inline HTML within Gleam files**: Makes code hard to read and maintain
- **These issues compound as applications grow**: What starts small becomes unmaintainable

## The Solution: Layered Template Composition

A four-layer approach that builds HTML from the bottom up:

1. **Elements** (matcha templates): Low-level HTML components
2. **Components** (gleam functions): Compose elements into reusable pieces
3. **Pages** (gleam functions): Compose components into full pages
4. **Layouts** (gleam functions): Page structure (nav, footer, main wrapper)

## Layer 1: Elements

Elements are the smallest reusable pieces. They're compiled from Matcha templates and represent semantic HTML components.

**Location:** `templates/elements/*.matcha`

**Example: Button Element**

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

### Using the button element <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/templates_guide_components.gleam#L15-L22"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

## Layer 2: Components

Components are Gleam functions that compose multiple elements into reusable pieces. They handle presentation logic like formatting and conditional rendering.

**Location:** `templates/components/*.gleam`

The component below imports the generated element modules as `badge`, `button`, `checkbox`, `input` and `task_card`.

### The task card component <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/templates_guide_components.gleam#L24-L73"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

## Layer 3: Pages

Pages compose multiple components into full page content. They represent the main content area of a page.

**Location:** `templates/pages/*.matcha` or `templates/pages/*.gleam`

**Example: Index Page**

```matcha
{> with task_form as String
{> with task_list as String
<main>
  <section>
    <h1>Tasks</h1>
    {{ task_form }}
  </section>
  <section>
    {{ task_list }}
  </section>
</main>
```

A page can also be a Gleam function:

### The index page as a Gleam function <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/templates_guide_pages.gleam#L8-L15"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

## Layer 4: Layouts

Layouts wrap pages with consistent structure. They handle navigation, footer, scripts, and the overall page shell.

**Location:** `templates/layouts/*.gleam`

### The page layout <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/templates_guide_layouts.gleam#L9-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

## Complete Flow Example

Here's how all layers work together:

### The view layer <a href="https://github.com/TrustBound/dream/blob/2.5.0/test/snippets/templates_guide_views.gleam#L8-L18"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

## Benefits

This layered approach provides:

- **Eliminates duplication**: Reuse elements and components instead of copying markup
- **Consistent styling**: Changes to elements propagate automatically throughout the app
- **Type safety**: Full Gleam type checking throughout the template pipeline
- **Maintainability**: Clear separation of concerns makes changes predictable
- **Scalability**: Pattern works well as applications grow

## Best Practices

### When to Use Each Layer

- **Elements**: Use for atomic HTML pieces (buttons, inputs, badges, icons)
- **Components**: Use for composed UI pieces (cards, forms, lists)
- **Pages**: Use for page-level content composition
- **Layouts**: Use for consistent page structure

### Avoiding Duplication

- **Don't copy markup**: If you find yourself copying HTML, extract it to an element or component
- **Parameterize variations**: Use function parameters instead of creating separate templates
- **Compose, don't duplicate**: Build complex pieces from simpler ones

### Type Safety

- All template functions are type-checked at compile time
- Matcha templates generate typed Gleam functions
- Errors caught before runtime

## Important Note

This is by no means the only way to do server-side rendering, but we have found that it serves our needs well as our applications grow. It provides full type safety through Gleam, eliminates markup duplication, and keeps styling consistent.

## Working Example

See [examples/tasks](../../examples/tasks/) for a complete working example of this pattern, including:
- Element templates (button, input, checkbox, etc.)
- Component functions (task_card, task_list, etc.)
- Page templates (index, show, etc.)
- Layout functions (build_page, etc.)

## See Also

- [Multiple Formats](multiple-formats.md) - Using templates with JSON/HTML responses
- [Controllers & Models](controllers-and-models.md) - How views fit into the MVC pattern

