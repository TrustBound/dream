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
cd examples/static
make run
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
- **Root**: `./assets/`
- **Examples**:
  - `http://localhost:3000/assets/data.json` → serves JSON file

### `/images/**/*.{jpg,png,gif,svg}` - Extension-filtered images
- **Config**: Same as `/public` but route only matches image extensions
- **Root**: `./public/images/`
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
examples/static/
  src/
    controllers/
      static_controller.gleam     # Controller functions for each route
  public/                          # Main static directory
    index.html                     # Root page
    styles.css                     # Stylesheet
    script.js                      # JavaScript
    about/
      index.html                   # Nested page
    images/
      cat.svg                      # SVG cat image
      logo.png                     # PNG placeholder
      photo.jpg                    # JPG placeholder
  assets/                          # Alternative static directory
    data.json                      # JSON data file
  src/
    main.gleam                     # Application entry point
    router.gleam                   # Route definitions
    services.gleam                 # Empty services
```

## Using in Your Own App

Write a controller that calls `static.serve`. `get_param` gives the captured path, and `param.raw` is the path as the client sent it:

### Simple Setup: controller <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/static/src/controllers/static_controller.gleam#L11-L33"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

Then send a wildcard route to the controller:

### Simple Setup: route <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/static/src/router.gleam#L6-L14"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### With Configuration

Chain options onto `static.default_config()`. `with_directory_listing()` makes directory indexes (`serve_public` above uses it). `without_index()` stops the automatic `index.html` (`serve_assets` uses it). `with_custom_404(handler)` sets the page for a missing file:

#### Custom 404 page <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/static/src/controllers/static_controller.gleam#L158-L186"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

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

### Extension Filtering

Use router patterns instead of controller logic. These routes match only image files:

#### Image routes <a href="https://github.com/TrustBound/dream/blob/2.5.0/examples/static/src/router.gleam#L43-L56"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
  // Brace expansion extension: *.{ext1,ext2}
  |> route(
    method: Get,
    path: "/images/*.{jpg,png,gif,svg}",
    controller: static_controller.serve_image_file,
    middleware: [],
  )
  // Multi-wildcard + extension in middle
  |> route(
    method: Get,
    path: "/photos/**/*.{jpg,png}",
    controller: static_controller.serve_photo,
    middleware: [],
  )
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

