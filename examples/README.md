# Dream Examples

This directory contains standalone example projects demonstrating various Dream features. Each example is its own Gleam project that depends on Dream as a local path dependency.

## Running Examples

Each example has its own `run_example.sh` script that:
- Sets up any required services (databases, etc.)
- Builds and starts the server
- Tests all endpoints
- Cleans up automatically (even on failure)

```bash
cd examples/simple
./run_example.sh
```

## Available Examples

### 1. Simplest (`simplest/`)
**Port:** 3000  
**Features:** Absolute minimum Dream application

The simplest possible Dream app - one file, one route, returning "Hello, World!". Perfect starting point to understand Dream's core concepts with zero complexity.

### 2. Simple (`simple/`)
**Port:** 3000  
**Features:** Basic routing with path parameters

Demonstrates a simple Dream app with two routes and an HTTP client.

### 3. Singleton (`singleton/`)
**Port:** 3000  
**Features:** Global state management, rate limiting

Shows how to use Dream's singleton pattern for managing global state (rate limiter service).

### 4. Streaming (`streaming/`)
**Port:** 3000  
**Features:** HTTP client (streaming and non-streaming)

Demonstrates Dream's HTTP client for making external requests.

### 5. Custom Context (`custom_context/`)
**Port:** 3001  
**Features:** Authentication, authorization, middleware chaining

Shows how to extend Dream's context with custom types for auth and use middleware.

### 6. Static (`static/`)
**Port:** 3000  
**Features:** Static file serving, wildcard routing, directory listing

Comprehensive example of all wildcard pattern types and secure static file serving.

### 7. Database (`database/`)
**Port:** 3002  
**Database:** PostgreSQL on port 5435  
**Features:** Full CRUD, type-safe SQL with Squirrel, database migrations

Complete REST API with PostgreSQL integration.

### 8. Multi-Format (`multi_format/`)
**Port:** 3000  
**Database:** PostgreSQL on port 5436  
**Features:** JSON, HTML, HTMX, CSV responses, streaming, Matcha templates

Demonstrates serving the same data in multiple formats using format extensions.

## Isolation

Each example runs in complete isolation:
- Unique ports prevent conflicts
- Database examples have their own Docker containers
- Each has its own dependencies and build artifacts
- Integration tests (`run_example.sh`) clean up automatically

## Testing All Examples

To run all examples sequentially:

```bash
cd examples
for dir in simplest simple singleton streaming custom_context static database multi_format; do
  cd $dir && ./run_example.sh && cd ..
done
```

All examples reset their state before testing, so they can be run multiple times.

