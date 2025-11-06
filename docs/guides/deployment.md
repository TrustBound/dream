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

pub type Config {
  Config(
    database_url: String,
    port: Int,
    secret_key: String,
  )
}

pub fn load() -> Result(Config, String) {
  use database_url <- result.try(
    envoy.get("DATABASE_URL")
    |> result.replace_error("DATABASE_URL not set"),
  )
  
  let port =
    envoy.get("PORT")
    |> result.try(int.parse)
    |> result.unwrap(3000)
  
  use secret_key <- result.try(
    envoy.get("SECRET_KEY")
    |> result.replace_error("SECRET_KEY not set"),
  )
  
  Ok(Config(database_url:, port:, secret_key:))
}
```

Use in main:

```gleam
pub fn main() {
  let assert Ok(config) = config.load()
  
  dream.new()
  |> context(AppContext(request_id: ""))
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
import gleam/io
import gleam/json

pub fn log_info(message: String, metadata: json.Json) {
  json.object([
    #("level", json.string("info")),
    #("message", json.string(message)),
    #("metadata", metadata),
    #("timestamp", json.string(timestamp.now())),
  ])
  |> json.to_string
  |> io.println
}
```

Docker/Kubernetes will capture stdout and route it to your log aggregator.

## Health Checks

Add a health endpoint:

```gleam
pub fn health_check(_request, _context, services) {
  case services.database.connection {
    Ok(_) -> text_response(ok_status(), "OK")
    Error(_) -> text_response(service_unavailable_status(), "Database unavailable")
  }
}
```

Add to router:

```gleam
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
let config =
  pog.Config(
    ..pog.default_config(),
    pool_size: 15,  // Adjust based on load
  )
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
pub fn log_request(request: Request, response: Response, duration_ms: Int) {
  json.object([
    #("type", json.string("request")),
    #("method", json.string(request.method)),
    #("path", json.string(request.path)),
    #("status", json.int(response.status)),
    #("duration_ms", json.int(duration_ms)),
  ])
  |> json.to_string
  |> io.println
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

**[← Back: Testing](testing.md)** | **[Up: Documentation](../../README.md)** | **[Next: Database →](database.md)**

