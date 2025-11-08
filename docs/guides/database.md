# Guide: Database

**PostgreSQL with type-safe SQL queries. No ORM abstractions. Just SQL that works.**

Dream uses [Pog](https://hexdocs.pm/pog/) for PostgreSQL connections and [Squirrel](https://github.com/giacomocavalieri/squirrel) to generate type-safe Gleam functions from your SQL files.

You write SQL. Squirrel makes it type-safe. Pog executes it. Simple.

## Setup

Add dependencies to `gleam.toml`:

```toml
[dependencies]
pog = ">= 4.0.0 and < 5.0.0"

[dev-dependencies]
squirrel = ">= 4.0.0 and < 5.0.0"
```

Download:

```bash
gleam deps download
```

## Starting PostgreSQL

Use the included Docker setup:

```bash
make db-up
```

This starts PostgreSQL at `localhost:5434` with:
- User: `postgres`
- Password: `postgres`
- Database: `dream_db`

Or run PostgreSQL however you want. Dream doesn't care.

## Database Connection

Create `src/your_app/database.gleam`:

```gleam
import dream/services/service.{type DatabaseService, DatabaseService}
import envoy
import gleam/option.{None}
import pog

pub fn init_database() -> Result(DatabaseService, String) {
  let database_url =
    envoy.get("DATABASE_URL")
    |> result.unwrap("postgres://postgres:postgres@localhost:5434/dream_db")

  let config =
    pog.Config(
      ..pog.default_config(),
      host: "localhost",
      port: 5434,
      database: "dream_db",
      user: "postgres",
      password: None,
      pool_size: 15,
    )

  let connection = pog.connect(config)
  Ok(DatabaseService(connection:))
}
```

The connection pool is managed by the BEAM. It's fast, reliable, and handles thousands of concurrent queries.

## Writing SQL

Create SQL files in `src/your_app/sql/`:

```sql
-- src/your_app/sql/list_users.sql
SELECT id, name, email, created_at
FROM users
ORDER BY id
```

Parameters use `$1`, `$2`, etc.:

```sql
-- src/your_app/sql/get_user.sql
SELECT id, name, email, created_at
FROM users
WHERE id = $1
```

For INSERT/UPDATE, use `RETURNING`:

```sql
-- src/your_app/sql/create_user.sql
INSERT INTO users (name, email)
VALUES ($1, $2)
RETURNING id, name, email, created_at
```

## Generating Type-Safe Functions

Configure Squirrel in `gleam.toml`:

```toml
[squirrel]
src_folder = "src/your_app/sql"
```

Generate functions:

```bash
gleam run -m squirrel
```

This creates `src/your_app/sql.gleam` with functions like:

```gleam
pub fn list_users(db: pog.Connection) 
  -> Result(pog.Returned(ListUsersRow), pog.QueryError)

pub fn get_user(db: pog.Connection, id: Int) 
  -> Result(pog.Returned(GetUserRow), pog.QueryError)

pub fn create_user(db: pog.Connection, name: String, email: String) 
  -> Result(pog.Returned(CreateUserRow), pog.QueryError)
```

Each SQL file becomes a type-safe function. Parameters are inferred from `$1`, `$2`. Return types are generated from your `SELECT` columns.

## Migrations

Create migrations in `priv/migrations/`:

```sql
-- priv/migrations/001_create_users_table.sql
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

Squirrel runs migrations in order:

```bash
gleam run -m squirrel migrate
```

Or via Makefile:

```bash
make migrate
```

## Using in Models

Wrap Squirrel-generated functions in your model:

```gleam
// src/your_app/models/user.gleam
import your_app/sql
import pog

pub fn list(db: pog.Connection) 
  -> Result(pog.Returned(sql.ListUsersRow), pog.QueryError) {
  sql.list_users(db)
}

pub fn get(db: pog.Connection, id: Int) 
  -> Result(pog.Returned(sql.GetUserRow), pog.QueryError) {
  sql.get_user(db, id)
}

pub fn create(db: pog.Connection, name: String, email: String) 
  -> Result(pog.Returned(sql.CreateUserRow), pog.QueryError) {
  sql.create_user(db, name, email)
}
```

## Error Handling

Pog returns `Result(pog.Returned(Row), pog.QueryError)`. Handle it:

```gleam
case user.get(db, id) {
  Ok(returned) if list.length(returned.rows) > 0 -> {
    let assert [user_row] = returned.rows
    // Use user_row
  }
  Ok(_) -> {
    // No rows found
  }
  Error(query_error) -> {
    // Database error
    io.debug(query_error)
  }
}
```

Or delegate to the view layer:

```gleam
user.get(db, id) |> user_view.respond()
```

The view handles:
- Unwrapping the Result
- Encoding to JSON
- Returning 200 with JSON if row found
- Returning 404 if no rows
- Returning 500 on database error

## Transactions

Pog supports transactions:

```gleam
import pog

pub fn transfer_money(db, from_id, to_id, amount) {
  pog.transaction(db, fn(tx) {
    use _ <- result.try(debit_account(tx, from_id, amount))
    use _ <- result.try(credit_account(tx, to_id, amount))
    Ok(Nil)
  })
}
```

If any operation fails, the transaction rolls back. Atomicity guaranteed.

## Common Patterns

### Optional Filters

```sql
-- src/your_app/sql/search_users.sql
SELECT id, name, email, created_at
FROM users
WHERE 
  ($1::TEXT IS NULL OR name ILIKE '%' || $1 || '%')
  AND ($2::TEXT IS NULL OR email ILIKE '%' || $2 || '%')
ORDER BY id
```

Use:

```gleam
sql.search_users(db, option.Some("alice"), option.None)
sql.search_users(db, option.None, option.Some("example.com"))
```

### Pagination

```sql
-- src/your_app/sql/list_users_paginated.sql
SELECT id, name, email, created_at
FROM users
ORDER BY id
LIMIT $1 OFFSET $2
```

Use:

```gleam
let page = 1
let per_page = 20
let offset = (page - 1) * per_page

sql.list_users_paginated(db, per_page, offset)
```

### Joins

```sql
-- src/your_app/sql/list_posts_with_authors.sql
SELECT 
  posts.id,
  posts.title,
  posts.content,
  users.name as author_name,
  users.email as author_email
FROM posts
JOIN users ON posts.user_id = users.id
ORDER BY posts.created_at DESC
```

Squirrel generates a row type with all columns:

```gleam
pub type ListPostsWithAuthorsRow {
  ListPostsWithAuthorsRow(
    id: Int,
    title: String,
    content: String,
    author_name: String,
    author_email: String,
  )
}
```

### Bulk Inserts

For multiple rows, use unnest:

```sql
-- src/your_app/sql/create_users_bulk.sql
INSERT INTO users (name, email)
SELECT * FROM unnest($1::TEXT[], $2::TEXT[])
RETURNING id, name, email
```

Or just loop:

```gleam
pub fn create_many(db, users: List(#(String, String))) {
  users
  |> list.map(fn(user) {
    let #(name, email) = user
    sql.create_user(db, name, email)
  })
}
```

## Connection Pooling

Pog manages the connection pool. Configure pool size:

```gleam
let config =
  pog.Config(
    ..pog.default_config(),
    pool_size: 15,  // Default is fine for most apps
  )
```

Increase if you see connection exhaustion. Decrease if connections sit idle. Start with 15.

## Query Performance

### Use EXPLAIN

Check query plans:

```sql
EXPLAIN ANALYZE
SELECT * FROM users WHERE email = 'alice@example.com';
```

Add indexes for slow queries:

```sql
CREATE INDEX idx_users_email ON users(email);
```

### Avoid N+1 Queries

Bad:

```gleam
// Get all posts
let posts = sql.list_posts(db)

// For each post, get the author (N queries!)
posts.rows
|> list.map(fn(post) {
  let author = sql.get_user(db, post.user_id)
  #(post, author)
})
```

Good:

```gleam
// One query with join
sql.list_posts_with_authors(db)
```

### Limit Result Sets

Always use LIMIT for potentially large result sets:

```sql
SELECT * FROM users ORDER BY created_at DESC LIMIT 1000
```

## Testing with Database

For integration tests, use a test database:

```gleam
pub fn init_test_database() -> Result(DatabaseService, String) {
  let config =
    pog.Config(
      ..pog.default_config(),
      database: "dream_test_db",  // Separate test database
    )

  let connection = pog.connect(config)
  
  // Run migrations
  run_migrations(connection)
  
  Ok(DatabaseService(connection:))
}

pub fn cleanup_test_database(db: pog.Connection) {
  // Truncate all tables
  pog.execute(db, "TRUNCATE users, posts CASCADE")
}
```

## Production Checklist

Before deploying:
- ✅ Use connection pooling (Pog does this)
- ✅ Use parameterized queries (Squirrel does this)
- ✅ Add indexes for common queries
- ✅ Set up backups
- ✅ Monitor slow queries
- ✅ Use SSL for database connections
- ✅ Keep Postgres version up to date

## Alternative: SQLite

Don't need PostgreSQL? Gleam has SQLite libraries too. The pattern stays the same:
1. Write SQL files
2. Generate type-safe functions
3. Wrap in models

Same principles. Different database.

## Summary

Database with Dream:
- ✅ Write SQL in `.sql` files
- ✅ Squirrel generates type-safe Gleam functions
- ✅ Pog executes queries with connection pooling
- ✅ Wrap SQL functions in models
- ✅ Use Dream's response helpers in controllers
- ✅ Transactions via `pog.transaction()`
- ✅ Migrations via Squirrel

No ORM. No query builders. Just SQL that works.

---

**[← Back: Deployment](deployment.md)** | **[Up: Documentation](../../README.md)**

