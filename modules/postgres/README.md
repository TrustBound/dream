# dream_postgres

PostgreSQL utilities for Dream applications.

Provides:
- Query result helpers (extracting rows, error handling)
- Singleton service pattern for connection pooling
- Re-exports of common Pog functionality

## Usage

```gleam
import dream_postgres/query
import dream_postgres/client

// Use with Squirrel-generated queries
let result = sql.get_user(db, id)
  |> query.first_row()

case result {
  Ok(row) -> // Process row
  Error(query.NotFound) -> // Handle not found
  Error(query.DatabaseError) -> // Handle error
}
```

