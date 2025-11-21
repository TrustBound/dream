# Things 3 Feature Analysis

Based on visual analysis of Things 3, here are the key features and interaction patterns:

## Core UI Structure

### Left Sidebar (Navigation)
- **Smart Lists** (system-defined):
  - Inbox (default collection)
  - Today (tasks due today)
  - Upcoming (future scheduled tasks)
  - Anytime (unscheduled tasks)
  - Someday (deferred tasks)
  - Logbook (completed tasks archive)
  - Trash (deleted items)
- **User Lists/Projects**:
  - Custom lists with circular icons
  - Can be organized hierarchically
  - "+ New List" button at bottom
- **Categories/Groups**:
  - Folders that contain multiple lists
  - Can nest lists within categories

### Main Content Area
- **Header**:
  - Large circular icon matching list/project
  - Title of current list/project
  - Ellipsis menu for options
  - Notes section for list-level notes
- **Task Sections**:
  - Blue headings to organize tasks
  - Ellipsis menu per section
  - Tasks listed under each heading
- **Bottom Bar**:
  - Navigation arrows
  - Action icons (trash, etc.)

## Task Creation & Editing

### Inline Task Creation
- **No top form** - tasks are created inline within the list
- **"+" button** in header triggers new inline task editor
- **Keyboard shortcut**: Cmd+N (or Ctrl+N) creates new inline task
- **New task appears** as an inline editor (not a form at top)
- **After selected task**: Cmd+N creates new task after the selected one
- **At top of list**: Cmd+N creates new task at the beginning if nothing selected

### Task Editor (Inline)
- **Appears inline** where the task will be placed
- **Title input** - primary field, auto-focuses
- **Description/Notes** - textarea below title
- **Due date** - date picker
- **Tags** - selector/button
- **Priority** - selector
- **Icons row**: Calendar, Tag, List, Flag (for quick actions)
- **Auto-save on blur** or Enter key
- **Escape key** closes editor without saving (if new) or reverts to card view

### Task Card View
- **Checkbox** on left for completion
- **Title** - main text
- **Priority badge** - visual indicator
- **Due date** - if set
- **Tags** - displayed as chips/badges
- **Edit button** - opens inline editor
- **Delete button** - removes task
- **Double-click** - opens inline editor
- **Click** - selects task (highlighted)

## Interaction Patterns

### Keyboard Shortcuts
- **Cmd+N**: Create new inline task
  - If task selected: creates after selected task
  - If no selection: creates at top of list
- **Enter** (in title field):
  - If new task: saves and creates another new task
  - If editing: saves and closes editor
- **Escape**: 
  - Closes editor (if new task, removes it)
  - Reverts to card view (if editing existing)

### Mouse Interactions
- **Click task card**: Selects task (highlighted)
- **Double-click task card**: Opens inline editor
- **Click checkbox**: Toggles completion (HTMX swap)
- **Click Edit button**: Opens inline editor
- **Click Delete button**: Confirms and deletes
- **Click "+" button**: Creates new inline task at top

### HTMX Patterns
- **Toggle completion**: `hx-post` to `/tasks/:id/toggle`, swaps `outerHTML` of task card
- **Delete task**: `hx-delete` to `/tasks/:id`, swaps `outerHTML` (removes element)
- **Edit task**: `hx-get` to `/tasks/:id/edit`, swaps `outerHTML` with editor
- **Update field**: `hx-post` to `/tasks/:id/update-field`, `swap: none` (auto-save)
- **Create task**: `hx-post` to `/tasks`, swaps `beforeend` into `#task-list`
- **New inline editor**: `hx-get` to `/tasks/new-inline`, swaps `afterbegin` or `afterend`

## Task Organization

### Sections/Headings
- **Blue headings** organize tasks into groups
- **Ellipsis menu** per heading for section actions
- **Tasks belong to sections** - can be moved between sections
- **"New Heading"** placeholder for creating sections

### Task Properties
- **Title** (required)
- **Description/Notes** (optional, multi-line)
- **Due Date** (optional, date picker)
- **Priority** (1=Urgent, 2=High, 3=Normal, 4=Low)
- **Tags** (multiple, can create on-the-fly)
- **Project** (optional, links to project)
- **Position** (for manual ordering)

### Task States
- **Incomplete** - default state
- **Completed** - checked, moves to Logbook
- **Selected** - highlighted, affects Cmd+N behavior

## Visual Design

### Color Scheme
- **Dark theme** (dark gray backgrounds, light text)
- **Blue accents** for headings and active elements
- **Circular icons** for lists/projects
- **Priority badges** with color coding

### Layout
- **Two-pane**: Sidebar + main content
- **Tasks flow vertically** in main area
- **Inline editors** appear in-place
- **No modals** - everything inline

## Data Model

### Task
```gleam
type Task {
  id: Int
  title: String
  description: Option(String)
  completed: Bool
  priority: Int  // 1-4
  due_date: Option(String)
  position: Int
  project_id: Option(Int)
  created_at: String
  updated_at: String
}
```

### Project/List
```gleam
type Project {
  id: Int
  name: String
  description: Option(String)
  color: Option(String)
  created_at: String
}
```

### Tag
```gleam
type Tag {
  id: Int
  name: String
  color: Option(String)
}
```

## Key Differences from Traditional Forms

1. **No top form** - all creation is inline
2. **Editor appears in-place** - not in a modal or separate area
3. **Auto-save** - changes save as you type (for existing tasks)
4. **Immediate feedback** - HTMX swaps update UI instantly
5. **Keyboard-driven** - Cmd+N, Enter, Escape are primary interactions
6. **Context-aware** - Cmd+N behavior depends on selection

## Implementation Checklist

- [x] Inline task creation (no top form)
- [x] "+" button triggers new inline editor
- [x] Cmd+N keyboard shortcut
- [x] Enter saves and creates new task
- [x] Escape closes editor
- [x] Double-click to edit
- [x] Click to select
- [x] HTMX for all interactions
- [x] Auto-save on field changes
- [x] Task sections/headings
- [x] Priority, tags, due dates
- [ ] Projects/lists sidebar
- [ ] Smart lists (Today, Upcoming, etc.)
- [ ] Categories/groups
- [ ] Task reordering (drag & drop)
- [ ] Logbook (completed tasks archive)

