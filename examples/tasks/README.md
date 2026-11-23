# Task App Example

**Full-featured task application demonstrating Dream's architecture with HTMX, semantic HTML, and composable matcha templates.**

This example showcases:
- HTMX for dynamic UI updates
- Semantic, classless HTML with Pico CSS
- Composable matcha templates (elements → components → views)
- Clean MVC architecture
- No raw HTML in Gleam code

## Architecture Demonstration

### Template Layers

**Elements** (`views/templates/elements/*.matcha`): Low-level semantic HTML templates
- button, input, textarea, select, checkbox, badge, icon, card, modal
- Classless - styled purely via Pico CSS
- Reusable across the app

**Components** (`views/templates/components/*.gleam`): Gleam functions that compose elements
- form_components - Form field helpers
- task_components - Task cards, lists, forms
- project_components - Project cards, lists
- tag_components - Tag badges, selectors
- layout_components - Page layouts

**Views** (`views/*.gleam`): Format-specific presentation
- todo_view - card(), edit_form(), index_page(), to_json()
- project_view - card(), show_page(), list_page(), to_json()
- tag_view - badge(), to_json()

### HTMX Patterns

**Create:** Form appends new card to list, auto-resets
**Update:** Form swaps entire article with updated card
**Delete:** Button removes article (204 response)
**Toggle:** Checkbox swaps article with updated card

All using semantic HTML without classes.

## Setup

### Start the database and the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/test/integration/start.sh#L3-L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
cd examples/tasks

# Start database
make db-up

# Run migrations
make migrate

# Run the application
make run
```

Server will start on `http://localhost:3000`.

The migrations are already in `priv/migrations`. They were made with `make migrate-new name=create_projects`, and the same for `create_todos`, `create_tags` and `create_todo_tags`.

When you change a query or a template, generate the code again. `make squirrel` needs the database:

### Generate the SQL code <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/test/integration/sql.sh#L8"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
make squirrel
```

### Compile the templates <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/tasks/test/templates.sh#L4"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
make matcha
```

## Endpoints

**Todos:**
- `GET /` - Main task app page (HTML)
- `GET /tasks/:task_id` - Show task (HTML or `.htmx` for partial)
- `POST /tasks` - Create task (returns task card for HTMX)
- `PUT /tasks/:task_id.htmx` - Update task (returns updated card)
- `DELETE /tasks/:task_id` - Delete task (204)
- `POST /tasks/:task_id/toggle.htmx` - Toggle completion (returns card)
- `POST /tasks/:task_id/reorder` - Update position

**Projects:**
- `GET /projects` - List projects
- `GET /projects/:project_id` - Show project with todos
- `POST /projects` - Create project
- `DELETE /projects/:project_id` - Delete project

**Tags:**
- `GET /tags` - List tags (JSON)
- `POST /tags` - Create tag (JSON)
- `POST /tasks/:task_id/tags` - Add tag to task
- `DELETE /tasks/:task_id/tags/:tag_id` - Remove tag from task

## Testing HTMX Functionality

Open `http://localhost:3000` in your browser to:
- ✅ Create todos using the form (auto-resets after creation)
- ✅ Toggle completion with checkboxes (instant swap)
- ✅ Delete tasks with confirmation
- ✅ Drag and drop to reorder (with Sortable.js)
- ✅ Filter by status, priority, tags

## What This Demonstrates

1. ✅ **HTMX patterns** - Create, update, delete with partials
2. ✅ **Semantic HTML** - No divs, no spans, only semantic tags
3. ✅ **Classless CSS** - Pico CSS styles semantic HTML
4. ✅ **Composable templates** - Elements → Components → Views
5. ✅ **No raw HTML in code** - All HTML from matcha templates
6. ✅ **Format detection** - PathParam.format for `.htmx` partials
7. ✅ **Clean architecture** - Models, Controllers, Views, Operations
8. ✅ **Type-safe SQL** - Squirrel-generated queries

## Code Structure

```text illustration
examples/tasks/
├── src/
│   ├── main.gleam              # Entry point
│   ├── router.gleam            # Route definitions
│   ├── context.gleam           # Request context
│   ├── services.gleam          # Database service
│   ├── types/                  # Domain types
│   ├── models/                 # Data access (repositories)
│   ├── controllers/            # HTTP handlers
│   ├── operations/             # Business logic
│   ├── views/
│   │   ├── templates/
│   │   │   ├── elements/       # Matcha templates
│   │   │   └── components/     # Gleam composition functions
│   │   ├── pages/              # Page templates
│   │   └── *.gleam             # View modules
│   └── middleware/             # Request/response wrappers
├── priv/migrations/            # Database migrations
├── Makefile                    # Build commands
└── docker-compose.yml          # Database setup
```

