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

1. **Start database:**
```bash
make db-up
```

2. **Create migrations (already created):**
```bash
make migrate-new name=create_projects
make migrate-new name=create_todos
make migrate-new name=create_tags
make migrate-new name=create_todo_tags
```

3. **Run migrations:**
```bash
make migrate
```

4. **Generate SQL code:**
```bash
make squirrel
```

5. **Compile Matcha templates:**
```bash
make matcha
```

6. **Run the application:**
```bash
make run
```

Server will start on `http://localhost:3000`.

## Quick Start

```bash
# All-in-one setup
make db-up
sleep 5
make migrate
make squirrel
make matcha
make run
```

Or use the automated test script:

```bash
./run_example.sh
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

```
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

