# Simplest Dream Example

The absolute simplest possible Dream application. Everything in one file.

## What This Demonstrates

- **Single file structure**: Everything in `main.gleam`
- **Inline controller**: No separate controller files
- **Minimal dependencies**: Only Dream core
- **One route**: Just `GET /`
- **Plain text response**: Returns "Hello, World!"

## What's NOT Here

This example intentionally omits:
- Separate controller files
- View files
- Custom services
- Custom context
- Database connections
- External HTTP clients
- Multiple routes
- JSON responses
- Middleware

For more features, see the `simple` example.

## Running

### Quick Start

```bash
./run_example.sh
```

### Using Make

```bash
make run
```

### Manual

```bash
gleam run
```

## Testing

Visit http://localhost:3000 in your browser or use curl:

```bash
curl http://localhost:3000
```

You should see:

```
Hello, World!
```

## Code Structure

The entire application is in `src/main.gleam`:

1. **Import statements** - Only the essential Dream core modules
2. **Inline controller** - A simple function that returns a response
3. **Router setup** - One route definition
4. **Server configuration** - Minimal Dream server setup

## Learning Path

1. Start here to understand the bare minimum
2. Move to `simple` example for basic routing and HTTP clients
3. Explore `database` example for persistence
4. Check `cms` example for a full application

## Philosophy

This example follows Dream's philosophy of **no magic**:
- Everything is explicit and visible
- No hidden configuration
- No framework-specific patterns
- Just functions and data structures




