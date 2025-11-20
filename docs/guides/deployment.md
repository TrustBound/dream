# Guide: Deployment

**Running Dream in production. Because localhost:3000 won't cut it forever.**

Dream apps compile to native Erlang BEAM bytecode. They run on the same battle-tested runtime that powers WhatsApp, Discord, and other services handling millions of concurrent connections.

This guide covers common deployment patterns.

## Building for Production

Build your release:

```bash
gleam build --target erlang
```

This generates BEAM bytecode in `build/dev/erlang/`. For production, you want an optimized build—but Gleam doesn't have a `--prod` flag yet. The dev build works fine for production. The BEAM is already optimized.

## Environment Variables

Dream apps should read configuration from environment variables (12-factor app style):

```gleam
// config.gleam
import envoy
import gleam/int.{parse}
import gleam/result.{try, replace_error, unwrap}

pub type Config {
  Config(
    database_url: String,
    port: Int,
    secret_key: String,
  )
}

pub fn load() -> Result(Config, String) {
  use database_url <- try(
    envoy.get("DATABASE_URL")
    |> replace_error("DATABASE_URL not set"),
  )
  
  let port =
    envoy.get("PORT")
    |> try(parse)
    |> unwrap(3000)
  
  use secret_key <- try(
    envoy.get("SECRET_KEY")
    |> replace_error("SECRET_KEY not set"),
  )
  
  Ok(Config(database_url:, port:, secret_key:))
}
```

Use in main:

```gleam
import dream/servers/mist/server.{bind, listen, new, router, services} as server
import router.{create_router}
import services.{initialize_services}

pub fn main() {
  let assert Ok(config) = config.load()
  
  server.new()
  |> services(initialize_services(config))
  |> router(create_router())
  |> bind("0.0.0.0")  // Listen on all interfaces
  |> listen(config.port)
}
```

## Docker

Create `Dockerfile`:

```dockerfile
FROM ghcr.io/gleam-lang/gleam:v1.6.2-erlang-alpine

# Copy source
WORKDIR /app
COPY . .

# Install dependencies and build
RUN gleam deps download
RUN gleam build

# Expose port
EXPOSE 3000

# Run
CMD ["gleam", "run"]
```

Build and run:

```bash
docker build -t your-app .
docker run -p 3000:3000 \
  -e DATABASE_URL=postgres://user:pass@host/db \
  -e SECRET_KEY=your-secret \
  your-app
```

## Docker Compose

For local development with database:

```yaml
version: '3.8'

services:
  app:
    build: .
    ports:
      - "3000:3000"
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/yourapp
      SECRET_KEY: dev-secret-key
    depends_on:
      - db

  db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD: postgres
      POSTGRES_DB: yourapp
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

volumes:
  postgres_data:
```

Run:

```bash
docker-compose up
```

## Database Migrations

Run migrations before starting your app:

```bash
# In Docker entrypoint or startup script
gleam run -m squirrel migrate
gleam run
```

Or create a separate migration service in Docker Compose:

```yaml
services:
  migrate:
    build: .
    command: gleam run -m squirrel migrate
    environment:
      DATABASE_URL: postgres://postgres:postgres@db:5432/yourapp
    depends_on:
      - db

  app:
    build: .
    command: gleam run
    # ... rest of app config
    depends_on:
      - migrate
```

## Logging

Log to stdout/stderr. Let your infrastructure handle log aggregation:

```gleam
import gleam/io.{println}
import gleam/json.{Json, object, string, to_string}
import gleam/time/timestamp.{now}

pub fn log_info(message: String, metadata: Json) {
  object([
    #("level", string("info")),
    #("message", string(message)),
    #("metadata", metadata),
    #("timestamp", string(timestamp_to_string(now()))),
  ])
  |> to_string
  |> println
}

fn timestamp_to_string(ts: timestamp.Timestamp) -> String {
  // Convert timestamp to ISO 8601 string
  timestamp.to_string(ts)
}
```

Docker/Kubernetes will capture stdout and route it to your log aggregator.

## Health Checks

Add a health endpoint:

```gleam
import dream/http.{type Request, type Response, text_response, ok, service_unavailable}
import dream/context.{AppContext}
import pog.{query}
import services.{Services}

pub fn health_check(
  _request: Request,
  _context: AppContext,
  services: Services,
) -> Response {
  case check_database(services.db) {
    Ok(_) -> text_response(ok, "OK")
    Error(_) -> text_response(service_unavailable, "Database unavailable")
  }
}

fn check_database(db: pog.Connection) -> Result(Nil, Nil) {
  case query("SELECT 1", db, []) {
    Ok(_) -> Ok(Nil)
    Error(_) -> Error(Nil)
  }
}
```

Add to router:

```gleam
import dream/http/request.{Get}
import dream/router.{route}

router
|> route(method: Get, path: "/health", controller: health_check, middleware: [])
```

Configure Docker healthcheck:

```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
  CMD curl -f http://localhost:3000/health || exit 1
```

## Process Management

The BEAM handles process management. You don't need systemd or supervisord. Just run `gleam run` and the BEAM keeps your app running.

For containerized deployments, your orchestrator (Kubernetes, ECS, etc.) handles restarts.

## Performance Considerations

### Connection Pooling

Pog (PostgreSQL client) includes connection pooling:

```gleam
import pog.{default_config, pool_size}

let config =
  default_config()
  |> pool_size(15)  // Adjust based on load
```

Start with 15, increase if you see connection exhaustion. The BEAM handles pooling efficiently.

### Concurrency

The BEAM handles thousands of concurrent connections per core. You don't need to tune much. Each request runs in its own lightweight process.

### Static Assets

Serve static assets from CDN or object storage (S3, Cloudflare, etc.). Don't serve them from your Dream app. Use Dream for dynamic content only.

## Deployment Platforms

### Fly.io

Create `fly.toml`:

```toml
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

```bash
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

## Environment-Specific Configuration

Use environment variables, not config files:

```bash
# Development
export DATABASE_URL=postgres://localhost:5432/dev_db
export SECRET_KEY=dev-secret-not-for-production

# Production (set in your deployment platform)
DATABASE_URL=postgres://prod-host/db
SECRET_KEY=actual-secret-from-vault
```

Never commit secrets to Git. Use secret management:
- AWS Secrets Manager
- HashiCorp Vault
- Platform-specific secrets (Fly.io, Render, etc.)

## Monitoring

### Application Metrics

Log key metrics:

```gleam
import dream/http.{type Request, type Response}
import gleam/io.{println}
import gleam/json.{object, string, int, to_string}
import gleam/http.{method_to_string}

pub fn log_request(request: Request, response: Response, duration_ms: Int) {
  object([
    #("type", string("request")),
    #("method", string(method_to_string(request.method))),
    #("path", string(request.path)),
    #("status", int(response.status)),
    #("duration_ms", int(duration_ms)),
  ])
  |> to_string
  |> println
}
```

Send to your monitoring service (Datadog, New Relic, etc.).

### BEAM Metrics

The BEAM provides runtime metrics:
- Process count
- Memory usage
- Scheduler utilization

Use Erlang observer in development:

```bash
gleam run
# In another terminal:
erl -remsh yourapp@hostname
```

For production, export metrics to Prometheus/Grafana.

## Graceful Shutdown

The BEAM handles shutdown gracefully. On SIGTERM:
1. Stops accepting new connections
2. Finishes existing requests
3. Closes database connections
4. Exits

No special handling needed. The BEAM runtime does this for you.

## Troubleshooting

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

## Security Checklist

Production security basics:
- ✅ Use HTTPS (Let's Encrypt via reverse proxy)
- ✅ Validate all input
- ✅ Use parameterized SQL queries (Squirrel does this)
- ✅ Set secure headers (via middleware)
- ✅ Rate limit APIs (via middleware)
- ✅ Don't log secrets
- ✅ Keep dependencies updated

## Summary

Deploying Dream:
- ✅ Compiles to BEAM bytecode
- ✅ Configure via environment variables
- ✅ Docker-friendly
- ✅ Health checks for orchestrators
- ✅ BEAM handles concurrency and pooling
- ✅ Log to stdout, let infrastructure aggregate
- ✅ Deploy to Fly.io, Render, Railway, or any container platform

The BEAM is production-ready out of the box. You just need to point it at the right database and set your environment variables.

---

**See Also:**
- [Testing](testing.md) - Testing your deployment
- [REST API](rest-api.md) - Production API patterns

