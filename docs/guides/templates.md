# Template Composition

Many developers choose front-end frameworks like React or Vue, which is perfectly fine. Dream lets you choose whatever you want for a front-end.

For those who wish to have server-side rendering with full type safety through Gleam, we have a suggested layered approach that keeps markup consistent, DRY, and reusable as applications grow.

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

**Usage in Components:**

```gleam
import templates/elements/button

let button_html = button.render(
  button_id: "submit-btn",
  button_type: "submit",
  button_text: "Save Task",
  attributes: "hx-post=\"/tasks\""
)
```

## Layer 2: Components

Components are Gleam functions that compose multiple elements into reusable pieces. They handle presentation logic like formatting and conditional rendering.

**Location:** `templates/components/*.gleam`

**Example: Task Card Component**

```gleam
import templates/elements/button
import templates/elements/checkbox
import templates/elements/input
import templates/components/task_card
import types/task.{type Task}
import types/tag.{type Tag}

pub fn task_card(task: Task, tags: List(Tag)) -> String {
  let task_id = int.to_string(task.id)
  
  // Compose elements
  let checkbox_html = checkbox.render(
    checkbox_id: "checkbox-" <> task_id,
    checkbox_name: "completed",
    label_text: "",
    checked_attr: if task.completed { "checked" } else { "" },
    attributes: htmx_attributes(task_id)
  )
  
  let title_input = input.render(
    input_id: "title-" <> task_id,
    input_name: "title",
    input_value: task.title,
    attributes: "readonly"
  )
  
  // Use compiled Matcha template for structure
  task_card.render(
    task_id: task_id,
    checkbox_html: checkbox_html,
    title_input: title_input,
    tags_html: render_tags(tags)
  )
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

**Or as a Gleam function:**

```gleam
import templates/components/task_components
import templates/components/form_components

pub fn index_page(
  tasks: List(Task),
  tags_by_task: List(#(Int, List(Tag))),
) -> String {
  // Components compose elements
  let list = task_components.task_list(tasks, tags_by_task)
  let form = form_components.task_form()
  
  // Page composes components
  index.render(task_form: form, task_list: list)
}
```

**Characteristics:**
- Combine multiple components
- Represent page-level content
- No layout structure (that's handled by layouts)

## Layer 4: Layouts

Layouts wrap pages with consistent structure. They handle navigation, footer, scripts, and the overall page shell.

**Location:** `templates/layouts/*.gleam`

**Example: Page Layout**

```gleam
import templates/layouts/footer
import templates/layouts/main_wrapper
import templates/layouts/nav
import templates/layouts/page
import templates/layouts/scripts

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

```gleam
// View layer (views/task_view.gleam)
pub fn index_page(
  tasks: List(Task),
  tags_by_task: List(#(Int, List(Tag))),
) -> String {
  // Components compose elements
  let list = task_components.task_list(tasks, tags_by_task)
  
  // Pages compose components
  let content = index.render(task_form: "", task_list: list)
  
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

