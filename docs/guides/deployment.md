# Deploy with Docker

Your app works on your machine. Now it has to run somewhere else: in a container, with its settings from the environment, its database next to it, its migrations run before it starts, and a health check that tells the platform when to restart it. This guide does that with the real `Dockerfile` and `docker-compose.yml` of `examples/deployment`, which Dream's CI builds and starts on every change.

## Table of Contents

- [What you'll build](#what-youll-build)
- [Before you start](#before-you-start)
- [Which way to run it](#which-way-to-run-it)
- [Step 1: Read the settings from the environment](#step-1-read-the-settings-from-the-environment)
- [Step 2: Add a health check](#step-2-add-a-health-check)
- [Step 3: Build the image](#step-3-build-the-image)
- [Step 4: Run it with its database in Docker Compose](#step-4-run-it-with-its-database-in-docker-compose)
- [Step 5: Log to standard output](#step-5-log-to-standard-output)
- [When the app is unhealthy or won't start](#when-the-app-is-unhealthy-or-wont-start)
- [Where to run it](#where-to-run-it)
- [Performance](#performance)
- [Security checklist](#security-checklist)
- [Test your code](#test-your-code)
- [Common pitfalls](#common-pitfalls)
- [Where to go next](#where-to-go-next)

## What you'll build

- A config module that reads the port and the database URL from the environment.
- A `/health` route that answers `503` when the database is down.
- A Docker image built from the `deployment` example's `Dockerfile`.
- A Compose file that starts PostgreSQL, runs the migrations, then starts the app and waits for its health check.
- JSON log lines on standard output.

## Before you start

You need Docker with Compose v2. Dream apps compile to BEAM bytecode and run on the Erlang runtime, so the image needs Erlang and Gleam, and the official Gleam image has both. Read [Build a database-backed JSON API](https://github.com/TrustBound/dream/blob/main/docs/guides/database-api.md) for the database side. In the Dream repository, `make test-docker` builds the example's image and starts it with Compose:

### The Docker test of the repository <a href="https://github.com/TrustBound/dream/blob/3.0.0/Makefile#L59-L62"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```makefile

# Build the Docker image of examples/deployment and start it with Docker
# Compose (needs Docker and the port 3000 free)
test-docker:
```

The example depends on the Dream of the repository, so `scripts/test-docker.sh` copies the example and Dream into one folder before it runs the example's `test/docker.sh` there. Your app depends on Dream from Hex, so you run the same commands in your project folder.

## Which way to run it

| Your situation | Run it with | Why |
|:---|:---|:---|
| One server, a container platform (Fly.io, Render, Railway, ECS, Kubernetes) | The image from Step 3 | The platform restarts it and routes traffic to it. |
| Local development with a database, or a small server | Docker Compose, Step 4 | One command starts the database, the migrations and the app. |
| No containers | `gleam run` under your process manager | The app is a normal program that reads its settings from the environment. |

## Step 1: Read the settings from the environment

Dream apps should read configuration from environment variables (12-factor app style):

### Config from environment variables <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/deployment_guide_config.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
// config.gleam
import envoy
import gleam/int
import gleam/result.{replace_error, try}

pub type Config {
  Config(database_url: String, port: Int, secret_key: String)
}

pub fn load() -> Result(Config, String) {
  use database_url <- try(
    envoy.get("DATABASE_URL")
    |> replace_error("DATABASE_URL not set"),
  )

  use port <- try(read_port())

  use secret_key <- try(
    envoy.get("SECRET_KEY")
    |> replace_error("SECRET_KEY not set"),
  )

  Ok(Config(database_url:, port:, secret_key:))
}

// PORT is optional, but a PORT that is not a number is an error
fn read_port() -> Result(Int, String) {
  case envoy.get("PORT") {
    Error(Nil) -> Ok(3000)
    Ok(value) ->
      int.parse(value)
      |> replace_error("PORT must be a number, got: " <> value)
  }
}
```

Start the server with the port from `Config`. `start_server` keeps running until the server stops:

### Start the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/deployment_guide_app.gleam#L38-L49"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_server(services: Services) {
  server.new()
  |> server.services(services)
  |> server.router(create_router())
  // Listen on all interfaces
  |> server.bind("0.0.0.0")
}

pub fn start_server(services: Services, port: Int) {
  create_server(services)
  |> server.listen(port)
}
```

## Step 2: Add a health check

Add a health endpoint. `check_database` is a function in `Services`, so a test can give a stub. In production, make it run `SELECT 1` through dream_postgres:

### The health check controller <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/deployment_guide_app.gleam#L13-L26"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub type Services {
  Services(check_database: fn() -> Result(Nil, String))
}

pub fn health_check(
  _request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case services.check_database() {
    Ok(Nil) -> text_response(ok, "OK")
    Error(_reason) -> text_response(service_unavailable, "Database unavailable")
  }
}
```

Add to router:

### The health route <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/deployment_guide_app.gleam#L28-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
pub fn create_router() -> Router(EmptyContext, Services) {
  router()
  |> route(
    method: Get,
    path: "/health",
    controller: health_check,
    middleware: [],
  )
}
```

Configure Docker healthcheck. The Alpine image has `wget`, not `curl`:

#### The health check of the Dockerfile <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/deployment/Dockerfile#L14-L16"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```dockerfile
# Mark the container unhealthy when /health does not answer 200
HEALTHCHECK --interval=5s --timeout=3s \
  CMD wget -q -O /dev/null http://localhost:3000/health || exit 1
```

## Step 3: Build the image

Create `Dockerfile`. This is the Dockerfile of the `deployment` example, which `make test-docker` builds and starts:

### Dockerfile <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/deployment/Dockerfile#L1-L19"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```dockerfile
FROM ghcr.io/gleam-lang/gleam:v1.19.2-erlang-alpine

# Copy source
WORKDIR /app
COPY . .

# Install dependencies and build
RUN gleam deps download
RUN gleam build

# Expose port
EXPOSE 3000

# Mark the container unhealthy when /health does not answer 200
HEALTHCHECK --interval=5s --timeout=3s \
  CMD wget -q -O /dev/null http://localhost:3000/health || exit 1

# Run
CMD ["gleam", "run"]
```

Add a `.dockerignore` file with the line `build`, so that your local build folder stays out of the image.

Build the image:

### Build the image <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/deployment/test/docker.sh#L5"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
docker build -t your-app .
```

### Build for production

Build your release with `gleam build`. Erlang is the default target, so it is the same as `gleam build --target erlang`.

This generates BEAM bytecode in `build/dev/erlang/`. For production, you want an optimized build, but Gleam doesn't have a `--prod` flag yet. The dev build works fine for production. The BEAM is already optimized.


To run the image on its own, give it the settings of your environment:

```bash illustration
docker run -p 3000:3000 \
  -e DATABASE_URL=postgres://user:pass@host/db \
  -e SECRET_KEY=your-secret \
  your-app
```

## Step 4: Run it with its database in Docker Compose

For local development with database. This is the `docker-compose.yml` of the `deployment` example:

### docker-compose.yml <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/deployment/docker-compose.yml#L1-L36"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```yaml
services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/yourapp
      SECRET_KEY: dev-secret-key
    depends_on:
      migrate:
        condition: service_completed_successfully

  migrate:
    build: .
    command: gleam run -m cigogne all
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/yourapp
    depends_on:
      db:
        condition: service_healthy

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: yourapp
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 2s
      timeout: 5s
      retries: 15
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

Start it in the background, and wait until the health check of the app passes. Then ask the app for `/health`, and stop everything:

### Start, check and stop <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/deployment/test/docker.sh#L6-L8"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
docker compose up -d --wait app
curl -f http://localhost:3000/health
docker compose down -v
```

### The migrations run first

Run migrations before starting your app. Cigogne applies them with `gleam run -m cigogne all`. In Docker Compose, a separate service runs them, and the app starts when that service has finished:

#### The migration service <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/deployment/docker-compose.yml#L13-L20"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```yaml
  migrate:
    build: .
    command: gleam run -m cigogne all
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/yourapp
    depends_on:
      db:
        condition: service_healthy
```

## Step 5: Log to standard output

Log to stdout/stderr. Let your infrastructure handle log aggregation:

### JSON log lines <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/deployment_guide_logging.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import gleam/io
import gleam/json.{type Json}
import gleam/time/calendar
import gleam/time/timestamp.{type Timestamp}

pub fn log_info(message: String, metadata: Json) -> Nil {
  format_info_line(message, metadata, timestamp.system_time())
  |> io.println
}

pub fn format_info_line(
  message: String,
  metadata: Json,
  time: Timestamp,
) -> String {
  json.object([
    #("level", json.string("info")),
    #("message", json.string(message)),
    #("metadata", metadata),
    // ISO 8601 in UTC, for example 2026-01-31T09:30:00Z
    #("timestamp", json.string(timestamp.to_rfc3339(time, calendar.utc_offset))),
  ])
  |> json.to_string
}
```

Docker/Kubernetes will capture stdout and route it to your log aggregator.

### Monitoring

#### Application Metrics

Log key metrics:

##### Request log lines <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/deployment_guide_request_log.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import dream/http.{type Request, type Response, method_to_string}
import gleam/io
import gleam/json

pub fn log_request(request: Request, response: Response, duration_ms: Int) {
  format_request_line(request, response, duration_ms)
  |> io.println
}

pub fn format_request_line(
  request: Request,
  response: Response,
  duration_ms: Int,
) -> String {
  json.object([
    #("type", json.string("request")),
    #("method", json.string(method_to_string(request.method))),
    #("path", json.string(request.path)),
    #("status", json.int(response.status)),
    #("duration_ms", json.int(duration_ms)),
  ])
  |> json.to_string
}
```

Send to your monitoring service (Datadog, New Relic, etc.).


## When the app is unhealthy or won't start

### App Won't Start

Check:
- ✅ All environment variables set
- ✅ Database accessible from app
- ✅ Port not already in use
- ✅ Migrations ran successfully

### High Memory Usage

The BEAM allocates memory generously. 1-2GB is normal for production. If it's growing unbounded:
- Check for memory leaks in your code
- Monitor process count (are processes dying?)
- Review query result sizes (loading too much data?)

### Slow Responses

Profile with Erlang tools:
- Add logging/timing to controllers
- Check database query performance
- Review N+1 query patterns
- Consider caching

## Where to run it

### Fly.io

Create `fly.toml`:

```toml illustration
app = "your-app"

[build]
  builder = "paketobuildpacks/builder:base"
  buildpacks = ["gcr.io/paketo-buildpacks/gleam"]

[[services]]
  internal_port = 3000
  protocol = "tcp"

  [[services.ports]]
    handlers = ["http"]
    port = 80

  [[services.ports]]
    handlers = ["tls", "http"]
    port = 443
```

Deploy:

```bash illustration
fly launch
fly deploy
```

### Render

1. Connect your Git repository
2. Select "Web Service"
3. Build command: `gleam build`
4. Start command: `gleam run`
5. Add environment variables in dashboard

### Railway

1. Connect Git repository
2. Railway auto-detects Gleam
3. Add environment variables
4. Deploy

### AWS ECS / Kubernetes

Standard container deployment:
1. Build Docker image
2. Push to registry (ECR, Docker Hub, etc.)
3. Create ECS task definition / Kubernetes deployment
4. Set environment variables
5. Deploy

## Performance

### Connection Pooling

Pog (PostgreSQL client) includes connection pooling:

#### Pool size <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/deployment_guide_postgres.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
import gleam/erlang/process
import pog

pub fn create_database_config() -> pog.Config {
  pog.default_config(pool_name: process.new_name("app_database"))
  // Adjust based on load
  |> pog.pool_size(15)
}
```

Start with 15, increase if you see connection exhaustion. The BEAM handles pooling efficiently.

### Concurrency

The BEAM handles thousands of concurrent connections per core. You don't need to tune much. Each request runs in its own lightweight process.

### Static Assets

Serve static assets from CDN or object storage (S3, Cloudflare, etc.). Don't serve them from your Dream app. Use Dream for dynamic content only.

In development, or for a small number of files, `dream/controllers/static` can serve files from a directory. `static.serve` sends a file, and stops paths that try to leave the root directory. It takes a `Config`. `static.default_config` serves `index.html` for a directory and does not list directories. `static.with_directory_listing` turns on the directory listing, `static.without_index` turns off `index.html`, and `static.with_custom_404` sets your own controller for a file that is not there. Each function has an example in its doc comment on [HexDocs](https://hexdocs.pm/dream/dream/controllers/static.html).

## Security checklist

Production security basics:
- ✅ Use HTTPS (Let's Encrypt via reverse proxy)
- ✅ Validate all input
- ✅ Use parameterized SQL queries (Squirrel does this)
- ✅ Set secure headers (via middleware)
- ✅ Rate limit APIs (via middleware)
- ✅ Don't log secrets
- ✅ Keep dependencies updated

## Test your code

The health check gets its database check from `Services`, so a test gives it a stub and checks both answers without a database:

### Test the health check <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/snippets/guide_deployment_test.gleam"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```gleam
//// Deployment guide: a test of the health check, with a stub database
////
//// health_check is from test/snippets/deployment_guide_app.gleam. Its
//// database check is a function in Services, so a test gives a stub.

import dream/context.{EmptyContext}
import dream/dream
import dream/http/request.{type Request, Get, Http, Http1, Request}
import dream/http/response.{Text}
import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{describe, it}
import gleam/option
import snippets/deployment_guide_app.{Services}

fn health_request() -> Request {
  Request(
    method: Get,
    protocol: Http,
    version: Http1,
    path: "/health",
    query: "",
    params: [],
    host: option.None,
    port: option.None,
    remote_address: option.None,
    body: request.Text(""),
    headers: [],
    cookies: [],
    content_type: option.None,
    content_length: option.None,
  )
}

fn ask_health(
  check_database: fn() -> Result(Nil, String),
) -> response.Response {
  dream.route_request(
    deployment_guide_app.create_router(),
    health_request(),
    EmptyContext,
    Services(check_database: check_database),
  )
}

pub fn tests() -> TestSuite {
  describe("GET /health", [
    it("answers 200 when the database answers", fn() {
      // Act
      let response = ask_health(fn() { Ok(Nil) })

      // Assert
      response.status
      |> should
      |> be_equal(200)
      |> or_fail_with("a healthy database should give 200")
    }),
    it("answers 503 when the database is down", fn() {
      // Act
      let response = ask_health(fn() { Error("connection refused") })

      // Assert
      response.status
      |> should
      |> be_equal(503)
      |> or_fail_with("a database that is down should give 503")
    }),
    it("says why it is unhealthy", fn() {
      // Act
      let response = ask_health(fn() { Error("connection refused") })

      // Assert
      response.body
      |> should
      |> be_equal(Text("Database unavailable"))
      |> or_fail_with("the body should say the database is unavailable")
    }),
  ])
}
```

### The report of the test <a href="https://github.com/TrustBound/dream/blob/3.0.0/test/outputs/guide_deployment_report.txt"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
GET /health
  ✓ answers 200 when the database answers
  ✓ answers 503 when the database is down
  ✓ says why it is unhealthy

Summary: 3 run, 0 failed, 3 passed in 0ms
```

The image itself is tested by running it: `make test-docker` builds it, starts it with Compose, and fails when `curl -f` gets no `200` from `/health`.

## Common pitfalls

- **The app listens on `localhost` in the container.** Nothing outside the container can reach it. Bind to `0.0.0.0`, as `create_server` does.
- **The local `build` folder is copied into the image.** It holds your machine's build. Add `build` to `.dockerignore`.
- **`curl` in a health check of an Alpine image.** Alpine has `wget`, not `curl`. The example's `HEALTHCHECK` uses `wget`.
- **The app starts before the migrations finish.** Make the app depend on the migration service with `condition: service_completed_successfully`, as the Compose file does.
- **Secrets in the image or in Git.** Pass them as environment variables from your platform's secret store.

## Where to go next

- [Start, stop and troubleshoot the server](https://github.com/TrustBound/dream/blob/main/docs/guides/operating.md): start errors, ports and stopping the server.
- [Serve HTTPS and HTTP/2](https://github.com/TrustBound/dream/blob/main/docs/guides/http2.md): TLS in Dream or at a proxy.
- [Why the BEAM?](https://github.com/TrustBound/dream/blob/main/docs/reference/why-beam.md)
