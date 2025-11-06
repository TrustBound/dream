# Static File Serving Example

A complete example demonstrating Dream's static file controller with security, directory listing, and flexible configuration.

## What This Demonstrates

- **Wildcard routing** - Using `**filepath` to match any path depth
- **Extension filtering** - Using `*.{jpg,png,gif,svg}` in routes
- **Multiple static directories** - Different configs for different routes
- **Directory listing** - Auto-generated HTML directory indexes
- **Path traversal prevention** - Security built-in
- **MIME type detection** - Automatic content-type headers using marceau
- **Custom 404 handlers** - Controller-function based error handling

## Running the Example

```bash
gleam run -m examples/static/main
```

Server starts on `http://localhost:3000`

## Routes

### `/public/**filepath` - Main static directory
- **Config**: Directory listing enabled, index.html serving enabled
- **Root**: `./src/examples/static/public/`
- **Examples**:
  - `http://localhost:3000/public/` → serves `index.html`
  - `http://localhost:3000/public/styles.css` → serves CSS file
  - `http://localhost:3000/public/about/` → serves `about/index.html`
  - `http://localhost:3000/public/images/` → shows directory listing

### `/assets/**filepath` - Assets directory
- **Config**: No index.html serving, no directory listing
- **Root**: `./src/examples/static/assets/`
- **Examples**:
  - `http://localhost:3000/assets/data.json` → serves JSON file

### `/images/**/*.{jpg,png,gif,svg}` - Extension-filtered images
- **Config**: Same as `/public` but route only matches image extensions
- **Root**: `./src/examples/static/public/images/`
- **Examples**:
  - `http://localhost:3000/images/cat.svg` → serves SVG image
  - `http://localhost:3000/images/styles.css` → 404 (doesn't match pattern)

### `/custom/**filepath` - Custom 404 example
- **Config**: Custom HTML 404 page instead of default
- **Root**: `./src/examples/static/public/`
- **Examples**:
  - `http://localhost:3000/custom/missing.html` → custom 404 HTML

## Security Features

### Path Traversal Prevention

The static controller automatically blocks dangerous paths:

```bash
# All of these return 404
curl http://localhost:3000/public/../../../etc/passwd
curl http://localhost:3000/public/../../secrets
curl http://localhost:3000/public/.env
```

How it works:
- Rejects any path containing `..`
- Rejects absolute paths (starting with `/`)
- Validates paths stay within the configured root directory

### No Execution

Static files are served as-is. No server-side execution. No code interpretation.

## File Structure

```
src/examples/static/
  controllers/
    static_controller.gleam     # Controller functions for each route
  public/                        # Main static directory
    index.html                   # Root page
    styles.css                   # Stylesheet
    script.js                    # JavaScript
    about/
      index.html                 # Nested page
    images/
      cat.svg                    # SVG cat image
      logo.png                   # PNG placeholder
      photo.jpg                  # JPG placeholder
  assets/                        # Alternative static directory
    data.json                    # JSON data file
  main.gleam                     # Application entry point
  router.gleam                   # Route definitions
  services.gleam                 # Empty services
```

## Using in Your Own App

### Simple Setup

```gleam
// 1. Create controller
import dream/controllers/static
import dream/core/http/transaction.{type Request, type Response, get_param}

pub fn serve_static(request: Request, _ctx, _svc) -> Response {
  let assert Ok(filepath) = get_param(request, "filepath")
  static.serve(
    request: request,
    context: _ctx,
    services: _svc,
    root: "./public",
    filepath: filepath,
    config: static.default_config(),
  )
}

// 2. Add route
import dream/core/router.{route}

router
|> route(Get, "/public/**filepath", serve_static, [])
```

### With Configuration

```gleam
static.serve(
  request: request,
  context: context,
  services: services,
  root: "./public",
  filepath: filepath,
  config: static.default_config()
    |> static.with_directory_listing()  // Enable directory indexes
    |> static.without_index()            // Don't auto-serve index.html
    |> static.with_custom_404(custom_404_handler),
)
```

### Extension Filtering

Use router patterns instead of controller logic:

```gleam
// Serve only images
router
|> route(Get, "/images/**/*.{jpg,png,gif,svg}", serve_images, [])

// Serve only CSS/JS
|> route(Get, "/assets/**/*.{css,js}", serve_assets, [])

// Serve everything else
|> route(Get, "/public/**filepath", serve_all, [])
```

## MIME Types

The controller automatically detects MIME types using the `marceau` library:

- `.html` → `text/html; charset=utf-8`
- `.css` → `text/css; charset=utf-8`
- `.js` → `application/javascript; charset=utf-8`
- `.json` → `application/json; charset=utf-8`
- `.jpg`, `.png`, `.svg`, etc. → appropriate image types
- Unknown → `application/octet-stream`

## Directory Listing

When enabled, generates a clean HTML page listing all files and subdirectories:

```html
Index of /public/images/

../
cat.svg
logo.png
photo.jpg
```

Directories show with trailing slash, files without.

## Notes

- **Binary files**: Currently only text files are fully supported (SVG, HTML, CSS, JS, JSON, etc.)
- **Large files**: No streaming support yet - entire file loaded into memory
- **Caching**: Not implemented - every request reads from disk
- **Compression**: Not implemented - files served as-is

These limitations are intentional - the controller is designed to be simple and secure. For production static file serving, consider a CDN or reverse proxy (Nginx, Caddy, etc.).

