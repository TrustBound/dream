//// Post-processes the HTML that `gleam docs build` writes, so that
//// "tested snippet" badges link to local snippet pages.
////
//// The documentation links each code example to the file in
//// `test/snippets/` that tests it. On GitHub such a link looks like
//// `https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/name.gleam#L8-L10`.
//// That address only works after the tag is pushed, and it leaves the
//// documentation. This program changes each such link into a relative link
//// to `snippets/name.html` inside the documentation, and writes that page.
//// The page shows the snippet with the same code colors as the HexDocs
//// pages, and it highlights the lines that the link names.
////
//// Run it after `gleam docs build`:
////
//// ```sh
//// gleam run -m docs_snippet_pages
//// ```
////
//// The module lives in `test/` so that it never ships in the Hex package,
//// and so that `gleam run -m` finds it on every Gleam version that the
//// project supports. It changes only files under `build/dev/docs/dream/`.
////
//// The logic is in pure functions (`find_snippet_link`, `rewrite_page`,
//// `find_missing_snippet`, `render_snippet_page`). The `main` function only
//// reads and writes files and reports errors.

import gleam/int
import gleam/io
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import simplifile

/// The directory that `gleam docs build` writes the dream docs into.
const docs_directory = "build/dev/docs/dream"

/// The directory that holds the tested snippet source files.
const snippets_source_directory = "test/snippets"

/// The address prefix of every file in the dream GitHub repository. The
/// segment after it is the tag (or branch), which this program ignores.
const github_blob_prefix = "https://github.com/TrustBound/dream/blob/"

/// The path of the snippet directory inside the repository.
const snippets_repository_path = "test/snippets/"

/// A link to a tested snippet file.
///
/// `name` is the file name without the `.gleam` extension.
/// `anchor` is the line anchor with its `#`, such as `#L8-L10`, or an
/// empty string when the link has no line anchor.
pub type SnippetLink {
  SnippetLink(name: String, anchor: String)
}

/// One snippet link found on one documentation page.
///
/// `page` is the path of the page relative to the docs root, such as
/// `dream/servers/mist/server.html`.
pub type SnippetReference {
  SnippetReference(page: String, name: String)
}

/// The result of rewriting one documentation page.
///
/// `html` is the page with each snippet link made local. `snippet_names`
/// lists the snippet names that the page links to, in page order.
pub type RewrittenPage {
  RewrittenPage(html: String, snippet_names: List(String))
}

/// An error that stops the post-processing.
pub type DocsError {
  /// A page links to a snippet file that does not exist.
  MissingSnippet(page: String, snippet_path: String)
  /// A directory could not be listed.
  ListFailed(path: String, reason: simplifile.FileError)
  /// A file could not be read.
  ReadFailed(path: String, reason: simplifile.FileError)
  /// A file or directory could not be written.
  WriteFailed(path: String, reason: simplifile.FileError)
}

/// Rewrites the snippet links in the built docs and writes the snippet
/// pages. Prints an error and stops with exit code 1 if a step fails, so
/// that `make docs` stops too.
pub fn main() -> Nil {
  case process_docs() {
    Ok(count) ->
      io.println(
        "Wrote " <> int.to_string(count) <> " snippet page(s) for the docs.",
      )
    Error(error) -> report_error(error)
  }
}

fn report_error(error: DocsError) -> Nil {
  io.println_error("error: " <> describe_error(error))
  halt(1)
}

@external(erlang, "erlang", "halt")
fn halt(status: Int) -> Nil

/// Describes an error in one line, naming the files that are involved.
pub fn describe_error(error: DocsError) -> String {
  case error {
    MissingSnippet(page:, snippet_path:) ->
      "The docs page "
      <> page
      <> " links to the snippet file "
      <> snippet_path
      <> ", which does not exist."
    ListFailed(path:, reason:) ->
      "Cannot list " <> path <> ": " <> simplifile.describe_error(reason)
    ReadFailed(path:, reason:) ->
      "Cannot read " <> path <> ": " <> simplifile.describe_error(reason)
    WriteFailed(path:, reason:) ->
      "Cannot write " <> path <> ": " <> simplifile.describe_error(reason)
  }
}

fn process_docs() -> Result(Int, DocsError) {
  use page_paths <- result.try(list_pages())
  use pages <- result.try(list.try_map(page_paths, load_and_rewrite_page))
  use available_names <- result.try(list_snippet_names())
  let references = list.flat_map(pages, page_references)
  use _ <- result.try(find_missing_snippet(references, available_names))
  use _ <- result.try(list.try_each(pages, save_rewritten_page))
  let names =
    references
    |> list.map(fn(reference) { reference.name })
    |> list.unique
  use _ <- result.try(list.try_each(names, write_snippet_page))
  Ok(list.length(names))
}

/// A page path relative to the docs root, with its rewritten content.
type LoadedPage {
  LoadedPage(page: String, original: String, rewritten: RewrittenPage)
}

fn list_pages() -> Result(List(String), DocsError) {
  simplifile.get_files(docs_directory)
  |> result.map_error(fn(reason) { ListFailed(docs_directory, reason) })
  |> result.map(fn(paths) {
    paths
    |> list.filter(fn(path) { string.ends_with(path, ".html") })
    |> list.map(relative_to_docs_root)
    |> list.filter(fn(page) { !string.starts_with(page, "snippets/") })
    |> list.sort(string.compare)
  })
}

fn relative_to_docs_root(path: String) -> String {
  string.drop_start(path, string.length(docs_directory <> "/"))
}

fn load_and_rewrite_page(page: String) -> Result(LoadedPage, DocsError) {
  let path = docs_directory <> "/" <> page
  simplifile.read(path)
  |> result.map_error(fn(reason) { ReadFailed(path, reason) })
  |> result.map(fn(html) {
    LoadedPage(page:, original: html, rewritten: rewrite_page(html, page))
  })
}

fn page_references(loaded: LoadedPage) -> List(SnippetReference) {
  list.map(loaded.rewritten.snippet_names, fn(name) {
    SnippetReference(page: loaded.page, name:)
  })
}

fn list_snippet_names() -> Result(List(String), DocsError) {
  simplifile.read_directory(snippets_source_directory)
  |> result.map_error(fn(reason) {
    ListFailed(snippets_source_directory, reason)
  })
  |> result.map(fn(files) {
    files
    |> list.filter(fn(file) { string.ends_with(file, ".gleam") })
    |> list.map(fn(file) { string.drop_end(file, string.length(".gleam")) })
  })
}

fn save_rewritten_page(loaded: LoadedPage) -> Result(Nil, DocsError) {
  case loaded.rewritten.html == loaded.original {
    True -> Ok(Nil)
    False ->
      write_file(docs_directory <> "/" <> loaded.page, loaded.rewritten.html)
  }
}

fn write_snippet_page(name: String) -> Result(Nil, DocsError) {
  let source_path = snippet_source_path(name)
  use source <- result.try(
    simplifile.read(source_path)
    |> result.map_error(fn(reason) { ReadFailed(source_path, reason) }),
  )
  let pages_directory = docs_directory <> "/snippets"
  use _ <- result.try(
    simplifile.create_directory_all(pages_directory)
    |> result.map_error(fn(reason) { WriteFailed(pages_directory, reason) }),
  )
  write_file(
    pages_directory <> "/" <> name <> ".html",
    render_snippet_page(name, source),
  )
}

fn write_file(path: String, contents: String) -> Result(Nil, DocsError) {
  simplifile.write(to: path, contents:)
  |> result.map_error(fn(reason) { WriteFailed(path, reason) })
}

fn snippet_source_path(name: String) -> String {
  snippets_source_directory <> "/" <> name <> ".gleam"
}

// ---------------------------------------------------------------------------
// Link discovery and rewriting
// ---------------------------------------------------------------------------

/// Reads a link address and returns the snippet it names, if it is a link
/// to a file in `test/snippets/` of the dream GitHub repository.
///
/// Any tag is accepted, so a page built for 2.4.1 and a page built for
/// 2.5.0 both match. The line anchor must be `#L<n>` or `#L<start>-L<end>`,
/// or absent. Every other address gives `None`, so other links stay as
/// they are.
pub fn find_snippet_link(href: String) -> Option(SnippetLink) {
  use after_prefix <- option.then(remove_prefix(href, github_blob_prefix))
  use #(tag, repository_path) <- option.then(
    string.split_once(after_prefix, "/") |> option.from_result,
  )
  use <- guard_option(tag != "")
  use file_and_anchor <- option.then(remove_prefix(
    repository_path,
    snippets_repository_path,
  ))
  let #(file, anchor) = split_anchor(file_and_anchor)
  use name <- option.then(snippet_name(file))
  use <- guard_option(is_line_anchor(anchor))
  Some(SnippetLink(name:, anchor:))
}

fn remove_prefix(text: String, prefix: String) -> Option(String) {
  case string.starts_with(text, prefix) {
    True -> Some(string.drop_start(text, string.length(prefix)))
    False -> None
  }
}

fn guard_option(condition: Bool, next: fn() -> Option(a)) -> Option(a) {
  case condition {
    True -> next()
    False -> None
  }
}

fn split_anchor(text: String) -> #(String, String) {
  case string.split_once(text, "#") {
    Ok(#(file, fragment)) -> #(file, "#" <> fragment)
    Error(Nil) -> #(text, "")
  }
}

fn snippet_name(file: String) -> Option(String) {
  let name = string.drop_end(file, string.length(".gleam"))
  let is_valid =
    string.ends_with(file, ".gleam")
    && name != ""
    && !string.contains(name, "/")
  case is_valid {
    True -> Some(name)
    False -> None
  }
}

fn is_line_anchor(anchor: String) -> Bool {
  case anchor {
    "" -> True
    "#L" <> lines -> is_line_range(lines)
    _ -> False
  }
}

fn is_line_range(lines: String) -> Bool {
  case string.split_once(lines, "-L") {
    Ok(#(start, end)) -> is_line_number(start) && is_line_number(end)
    Error(Nil) -> is_line_number(lines)
  }
}

fn is_line_number(text: String) -> Bool {
  case int.parse(text) {
    Ok(number) -> number > 0 && int.to_string(number) == text
    Error(Nil) -> False
  }
}

/// Makes the relative address of a snippet page, as seen from a docs page.
///
/// `page` is the path of the docs page relative to the docs root. Each `/`
/// in it adds one `../`, so `index.html` gives `snippets/x.html` and
/// `dream/servers/mist/server.html` gives `../../../snippets/x.html`. The
/// line anchor stays at the end.
pub fn snippet_page_href(link: SnippetLink, page: String) -> String {
  let depth = list.length(string.split(page, "/")) - 1
  string.repeat("../", depth)
  <> "snippets/"
  <> link.name
  <> ".html"
  <> link.anchor
}

/// Changes every snippet link on a docs page into a relative link to the
/// local snippet page, and lists the snippet names it found.
///
/// The scan splits the HTML on `href="`, so it reads each link address
/// exactly as `gleam docs build` writes it. Links that are not snippet
/// links stay unchanged.
pub fn rewrite_page(html: String, page: String) -> RewrittenPage {
  case string.split(html, "href=\"") {
    [] -> RewrittenPage(html:, snippet_names: [])
    [first, ..attributes] -> {
      let #(parts, names) =
        list.fold(attributes, #([first], []), fn(state, attribute) {
          let #(parts, names) = state
          let #(part, found) = rewrite_attribute(attribute, page)
          #([part, ..parts], list.append(list.reverse(found), names))
        })
      RewrittenPage(
        html: parts |> list.reverse |> string.join("href=\""),
        snippet_names: list.reverse(names),
      )
    }
  }
}

/// Rewrites the text that follows one `href="`. Returns the new text and
/// the snippet name found in it, if any.
fn rewrite_attribute(
  attribute: String,
  page: String,
) -> #(String, List(String)) {
  case string.split_once(attribute, "\"") {
    Ok(#(href, rest)) -> rewrite_href(href, rest, page)
    Error(Nil) -> #(attribute, [])
  }
}

fn rewrite_href(
  href: String,
  rest: String,
  page: String,
) -> #(String, List(String)) {
  case find_snippet_link(href) {
    Some(link) -> #(snippet_page_href(link, page) <> "\"" <> rest, [link.name])
    None -> #(href <> "\"" <> rest, [])
  }
}

/// Returns an error for the first snippet reference whose file is not in
/// `available_names`. Each name is a file name in `test/snippets/` without
/// `.gleam`.
pub fn find_missing_snippet(
  references: List(SnippetReference),
  available_names: List(String),
) -> Result(Nil, DocsError) {
  case
    list.find(references, fn(reference) {
      !list.contains(available_names, reference.name)
    })
  {
    Ok(reference) ->
      Error(MissingSnippet(
        page: reference.page,
        snippet_path: snippet_source_path(reference.name),
      ))
    Error(Nil) -> Ok(Nil)
  }
}

// ---------------------------------------------------------------------------
// Snippet page rendering
// ---------------------------------------------------------------------------

/// Escapes text for use in HTML content and attribute values.
pub fn escape_html(text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
  |> string.replace("'", "&#39;")
}

/// Renders the HTML page for one snippet.
///
/// `name` is the snippet file name without `.gleam`. `source` is the file
/// content. Each line is one table row with the anchor `L<n>`. The page
/// loads the stylesheets and scripts that `gleam docs build` writes, with
/// paths relative to `snippets/`, so it works from `file://` with no
/// network. Its script colors the code with highlight.js, applies the
/// light or dark theme the same way the docs pages do, and highlights the
/// lines that the address names (`#L8` or `#L8-L10`), also when the
/// address changes.
pub fn render_snippet_page(name: String, source: String) -> String {
  let title = escape_html(snippets_repository_path <> name <> ".gleam")
  let rows =
    source
    |> split_lines
    |> list.index_map(render_line)
    |> string.join("\n")
  page_head(title) <> rows <> page_tail()
}

fn split_lines(source: String) -> List(String) {
  let content = case string.ends_with(source, "\n") {
    True -> string.drop_end(source, 1)
    False -> source
  }
  string.split(content, "\n")
}

fn render_line(line: String, index: Int) -> String {
  let number = int.to_string(index + 1)
  "<tr class=\"snippet-line\" id=\"L"
  <> number
  <> "\"><td class=\"snippet-line-number\"><a href=\"#L"
  <> number
  <> "\">"
  <> number
  <> "</a></td><td class=\"snippet-line-code\"><code>"
  <> escape_html(line)
  <> "</code></td></tr>"
}

fn page_head(title: String) -> String {
  "<!DOCTYPE html>
<html>
  <head>
    <meta charset=\"utf-8\"/>
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\"/>
    <title>" <> title <> " · dream</title>
    <link rel=\"stylesheet\" href=\"../css/index.css\" type=\"text/css\"/>
    <link id=\"syntax-theme\" rel=\"stylesheet\" href=\"../css/atom-one-light.min.css\"/>
    <style>
      .snippet-page { max-width: 64rem; margin: 0 auto; padding: 2rem 1rem; }
      .snippet-page h1 { font-size: 1.25rem; word-break: break-all; }
      .snippet-back { display: inline-block; margin-bottom: 1rem; }
      .snippet-code { overflow-x: auto; border: 1px solid var(--code-border); border-radius: 4px; background: var(--code-background); }
      .snippet-code table { border-collapse: collapse; width: 100%; margin: 0; }
      .snippet-code td { border: none; padding: 0 0.75rem; vertical-align: top; line-height: 1.5; }
      .snippet-code code { background: none; border: none; padding: 0; white-space: pre; font-size: 0.9rem; }
      .snippet-line-number { text-align: right; user-select: none; width: 1%; opacity: 0.6; }
      .snippet-line-number a { color: inherit; text-decoration: none; }
      .snippet-line.is-highlighted { background: rgba(255, 175, 243, 0.35); }
      .theme-dark .snippet-line.is-highlighted { background: rgba(255, 175, 243, 0.18); }
      .snippet-line.is-highlighted .snippet-line-number { opacity: 1; font-weight: bold; }
    </style>
  </head>
  <body class=\"theme-light\">
    <script>
      \"use strict\";
      /* Apply the theme the docs pages store, or the system theme. */
      void function() {
        let theme = null;
        try { theme = localStorage.getItem(\"Gleam.theme\"); } catch (_error) {}
        if (theme !== \"dark\" && theme !== \"light\") {
          theme = window.matchMedia(\"(prefers-color-scheme: dark)\").matches ? \"dark\" : \"light\";
        }
        document.body.classList.remove(\"theme-light\");
        document.body.classList.add(\"theme-\" + theme);
        document.querySelector(\"#syntax-theme\").href = \"../css/atom-one-\" + theme + \".min.css\";
      }();
    </script>
    <main class=\"snippet-page\">
      <a class=\"snippet-back\" href=\"../index.html\">dream documentation</a>
      <h1>" <> title <> "</h1>
      <div class=\"snippet-code\"><table><tbody>
"
}

fn page_tail() -> String {
  "
      </tbody></table></div>
    </main>
    <script src=\"../js/highlight.min.js\"></script>
    <script src=\"../js/highlightjs-gleam.js\"></script>
    <script>
      \"use strict\";
      /* Color the whole file at once, then split the result into lines,
       * closing and opening spans at each line end. */
      void function() {
        const cells = Array.from(document.querySelectorAll(\".snippet-line-code code\"));
        const text = cells.map((cell) => cell.textContent).join(\"\\n\");
        if (typeof hljs === \"undefined\") { return; }
        const html = hljs.highlight(text, { language: \"gleam\" }).value;
        const lines = [];
        let open = [];
        let current = \"\";
        const tokens = html.match(/<span[^>]*>|<\\/span>|\\n|[^<\\n]+/g) || [];
        for (const token of tokens) {
          if (token === \"\\n\") {
            lines.push(current + \"</span>\".repeat(open.length));
            current = open.join(\"\");
          } else if (token.startsWith(\"<span\")) {
            open.push(token);
            current += token;
          } else if (token === \"</span>\") {
            open.pop();
            current += token;
          } else {
            current += token;
          }
        }
        lines.push(current);
        cells.forEach((cell, index) => {
          cell.classList.add(\"hljs\", \"language-gleam\");
          cell.innerHTML = lines[index] || \"\";
        });
      }();

      /* Highlight the lines that the address names, like GitHub. */
      function highlightLines() {
        document.querySelectorAll(\".snippet-line.is-highlighted\")
          .forEach((row) => row.classList.remove(\"is-highlighted\"));
        const match = window.location.hash.match(/^#L(\\d+)(?:-L(\\d+))?$/);
        if (!match) { return; }
        const first = parseInt(match[1], 10);
        const last = match[2] ? parseInt(match[2], 10) : first;
        const start = Math.min(first, last);
        const end = Math.max(first, last);
        for (let number = start; number <= end; number++) {
          const row = document.getElementById(\"L\" + number);
          if (row) { row.classList.add(\"is-highlighted\"); }
        }
        const firstRow = document.getElementById(\"L\" + start);
        if (firstRow) { firstRow.scrollIntoView({ block: \"center\" }); }
      }
      window.addEventListener(\"hashchange\", highlightLines);
      highlightLines();
    </script>
  </body>
</html>
"
}
