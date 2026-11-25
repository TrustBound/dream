# Database Example

Full CRUD operations with PostgreSQL, type-safe SQL queries, and JSON validation.

## What This Demonstrates

- **PostgreSQL connection** - Using `dream_postgres_client` for connection pooling
- **Typed models** - `dream_model` generates the model modules from SQL files
- **Model-Controller pattern** - Clean separation of concerns
- **JSON request validation** - Validating request bodies
- **Database error handling** - Proper error responses, such as 409 for a taken email
- **Complete REST API** - Full CRUD operations

## Prerequisites

- Docker (for PostgreSQL)
- Gleam installed

## Running the Example

### Start the database and the server <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/test/integration/start.sh#L3-L12"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
cd examples/database

# Start PostgreSQL database
make db-up

# Run database migrations
make migrate

# Start the server
make run
```

Server starts on `http://localhost:3002`

## Database Setup

The example uses its own PostgreSQL instance:
- **Port**: 5435
- **Database**: `dream_example_database_db`
- **User**: `postgres`
- **Password**: `postgres`

Connection URL: `postgres://postgres:postgres@localhost:5435/dream_example_database_db`

## API Endpoints

### Users

- `GET /users` - List all users
- `GET /users/:id` - Get one user
- `POST /users` - Create user (JSON body: `{"name":"Alice","email":"alice@example.com"}`)
- `PUT /users/:id` - Update user
- `DELETE /users/:id` - Delete user

### Posts

- `GET /users/:user_id/posts` - List user's posts
- `GET /posts/:id` - Get one post
- `POST /users/:user_id/posts` - Create post (JSON body: `{"title":"My Post","content":"Post content"}`)

## Example Usage

### Send the requests <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/test/integration/readme.sh#L15-L40"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
# List all users
curl http://localhost:3002/users

# Get a specific user
curl http://localhost:3002/users/1

# Create a user
curl -X POST http://localhost:3002/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Bob","email":"bob@example.com"}'

# Update a user
curl -X PUT http://localhost:3002/users/1 \
  -H "Content-Type: application/json" \
  -d '{"name":"Alice Updated","email":"alice.updated@example.com"}'

# Create a post
curl -X POST http://localhost:3002/users/1/posts \
  -H "Content-Type: application/json" \
  -d '{"title":"My First Post","content":"This is my first post!"}'

# List posts for a user
curl http://localhost:3002/users/1/posts

# Delete a user
curl -X DELETE http://localhost:3002/users/1
```

## A taken email

The email column is unique. A second user with the same email gets a 409 answer. The `-- unique users_email_key: Email already taken` hint of `src/models/user/create.sql` gives the message.

### Create a user with a taken email <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/test/integration/readme.sh#L63-L65"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
curl -i -X POST http://localhost:3002/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Grace Again","email":"grace@example.com"}'
```

### The 409 answer <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/test/integration/readme_output.txt#L44-L50"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
HTTP/1.1 409 Conflict
content-type: application/json; charset=utf-8
content-length: 32
date: (the time of the request)
connection: keep-alive

{"error": "Email already taken"}
```

## Code Structure

The example has these Gleam files:

### List the Gleam files <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/test/integration/readme.sh#L70"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```bash
find src -name "*.gleam" | sort
```

### The Gleam files <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/test/integration/readme_output.txt#L51-L68"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```text
src/context.gleam
src/context_helpers.gleam
src/controllers/health_controller.gleam
src/controllers/posts_controller.gleam
src/controllers/users_controller.gleam
src/database.gleam
src/main.gleam
src/models/post.gleam
src/models/user.gleam
src/operations/post_operations.gleam
src/operations/user_operations.gleam
src/router.gleam
src/services.gleam
src/types/errors.gleam
src/utilities/response_helpers.gleam
src/views/errors.gleam
src/views/post_view.gleam
src/views/user_view.gleam
```

- `src/models/user.gleam` and `src/models/post.gleam`: generated by `dream_model` from the queries in `src/models/user/` and `src/models/post/`. Do not edit them. Change a `.sql` file and run `make models`.
- `src/database.gleam` starts the pool and calls `client.check_schema` with the fingerprints of the models, through `check_schema_waiting_for_database`. The app waits for a database that is not up yet, and stops with a clear message when the schema changed after the generation.
- `src/views/`: JSON formatting. `src/operations/`: the steps of each action.
- `priv/migrations/`: the database migrations. `docker-compose.yml` starts PostgreSQL.

### Start-up needs the database

At start-up, the app runs `client.check_schema` through `check_schema_waiting_for_database` in `src/database.gleam`. The check queries the database.

- When PostgreSQL cannot be reached, the app prints one line for each attempt, such as `Waiting for the database (attempt 3 of 15): ...`. It runs the check again every 2 seconds, at most 15 times. Each failed attempt also takes 2 to 3 seconds, the time that the pool waits for a connection. When the last attempt fails, the app prints one message (from `client.format_schema_check_error`) and stops with exit status 1.
- When the schema changed after `make models`, the app prints that message and stops with exit status 1 at once. Another database error, such as a missing table, also stops the app at once.

Start the database first. After a schema change, run `make migrate` and `make models`. `make test` proves both cases with `integration/startup-check.sh` of the repository: it stops the postgres container and starts the app, and it changes a column of the test database.

## Database Commands

Each target of the `Makefile` runs one command: `make db-up` starts PostgreSQL, `make db-down` stops it, `make db-logs` follows its log, `make db-shell` opens `psql`, `make db-reset` removes all data and starts it again, `make migrate` applies every migration, `make migrate-up` and `make migrate-down` apply or revert one, `make migrate-new name=my_migration` creates a new migration file, and `make models` generates the model modules from the `.sql` files.

### The database targets <a href="https://github.com/TrustBound/dream/blob/3.0.0/examples/database/Makefile#L75-L116"><img align="right" alt="Tested snippet" src="https://img.shields.io/badge/%F0%9F%A7%AA_tested-snippet-lightgreen.svg?style=flat-square"></a>

```makefile
# Docker Compose commands for PostgreSQL
# In CI, PostgreSQL is a service of the job, on the same port.
db-up:
	@if [ -n "$$CI" ]; then \
		echo "PostgreSQL runs as a service of the CI job"; \
	else \
		docker-compose up -d postgres; \
		echo "Waiting for PostgreSQL to be ready..."; \
		timeout 30 bash -c 'until docker-compose exec -T postgres pg_isready -U postgres; do sleep 1; done' || true; \
	fi

db-down:
	@docker-compose down

db-logs:
	@docker-compose logs -f postgres

db-shell:
	@docker-compose exec postgres psql -U postgres -d dream_example_database_db

db-reset:
	@docker-compose down -v
	@docker-compose up -d postgres
	@echo "Waiting for PostgreSQL to be ready..."
	@timeout 30 bash -c 'until docker-compose exec -T postgres pg_isready -U postgres; do sleep 1; done' || true

# Migration commands using cigogne
migrate:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne all

migrate-up:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne up

migrate-down:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m cigogne down

migrate-new:
	@gleam run -m cigogne new --name $(name)

# Generate the model modules from the queries in src/models/ with dream_model
models:
	@export DATABASE_URL="$(DATABASE_URL)" && gleam run -m dream_model
```

## Key Concepts

- **Database Service** - Singleton pattern for connection management
- **dream_model** - Generates typed model functions from SQL files. They return Dream errors: 404 for a missing row, 409 for a taken email
- **Migrations** - Using Cigogne for database schema management
- **Models** - Generated data access, one `.sql` file for each function
- **Controllers** - HTTP request handling and routing to models

This example shows how to build a complete REST API with Dream and PostgreSQL.

