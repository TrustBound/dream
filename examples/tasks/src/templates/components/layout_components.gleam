//// Layout components for page structure

import gleam/string

pub fn page_layout(title: String, content: String) -> String {
  "<!DOCTYPE html>"
  <> "<html lang=\"en\">"
  <> page_head(title)
  <> "<body>"
  <> page_nav()
  <> "<main>"
  <> content
  <> "</main>"
  <> page_footer()
  <> scripts()
  <> "</body>"
  <> "</html>"
}

fn page_head(title: String) -> String {
  "<head>"
  <> "<meta charset=\"UTF-8\">"
  <> "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">"
  <> "<title>" <> title <> "</title>"
  <> "<link rel=\"stylesheet\" href=\"https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css\">"
  <> "</head>"
}

fn page_nav() -> String {
  "<nav>"
  <> "<ul>"
  <> "<li><strong>Task App</strong></li>"
  <> "</ul>"
  <> "<ul>"
  <> "<li><a href=\"/\">Tasks</a></li>"
  <> "<li><a href=\"/projects\">Projects</a></li>"
  <> "</ul>"
  <> "</nav>"
}

fn page_footer() -> String {
  "<footer>"
  <> "<small>Built with Dream + HTMX + Pico CSS</small>"
  <> "</footer>"
}

fn scripts() -> String {
  "<script src=\"https://unpkg.com/htmx.org@2.0.3\"></script>"
  <> "<script src=\"https://unpkg.com/lucide@latest\"></script>"
  <> "<script>lucide.createIcons();</script>"
}

pub fn section_with_header(header: String, content: String) -> String {
  "<section>"
  <> "<header><h2>" <> header <> "</h2></header>"
  <> content
  <> "</section>"
}

pub fn two_column_layout(left: String, right: String) -> String {
  "<article>"
  <> "<section>" <> left <> "</section>"
  <> "<aside>" <> right <> "</aside>"
  <> "</article>"
}

// Helper
fn list_map(list: List(a), f: fn(a) -> b) -> List(b) {
  case list {
    [] -> []
    [head, ..tail] -> [f(head), ..list_map(tail, f)]
  }
}

