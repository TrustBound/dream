//// Shopping lists in PostgreSQL. Each function takes the connection as
//// its first parameter, so a test can give it a recorded connection.

import dream_postgres_client.{
  type Connection, type QueryError, ConstraintViolated, TransactionQueryError,
  TransactionRolledBack,
}
import gleam/dynamic/decode
import gleam/list
import gleam/result

pub type ShoppingList {
  ShoppingList(id: Int, name: String, items: List(String))
}

pub type ListError {
  NoSuchList(id: Int)
  ItemTooLong
  QueryFailed(error: QueryError)
}

/// Creates a list and its items in one transaction: when one item cannot
/// be saved, the database keeps nothing.
pub fn create(
  db: Connection,
  name: String,
  items: List(String),
) -> Result(ShoppingList, ListError) {
  let created = {
    use transaction <- dream_postgres_client.transaction(db)
    use id <- result.try(insert_list(transaction, name))
    use Nil <- result.try(list.try_each(items, insert_item(transaction, id, _)))
    Ok(ShoppingList(id:, name:, items:))
  }
  case created {
    Ok(shopping_list) -> Ok(shopping_list)
    Error(TransactionRolledBack(ConstraintViolated(
      constraint: "item_title_length",
      ..,
    ))) -> Error(ItemTooLong)
    Error(TransactionRolledBack(error)) -> Error(QueryFailed(error))
    Error(TransactionQueryError(error)) -> Error(QueryFailed(error))
  }
}

/// The list with `id`, and its items in the order they were added.
pub fn get(db: Connection, id: Int) -> Result(ShoppingList, ListError) {
  use rows <- result.try(
    dream_postgres_client.query("SELECT name FROM lists WHERE id = $1")
    |> dream_postgres_client.parameter(dream_postgres_client.int(id))
    |> dream_postgres_client.returning(decode.at([0], decode.string))
    |> run(db),
  )
  case rows {
    [] -> Error(NoSuchList(id))
    [name, ..] -> {
      use items <- result.try(
        dream_postgres_client.query(
          "SELECT title FROM items WHERE list_id = $1 ORDER BY id",
        )
        |> dream_postgres_client.parameter(dream_postgres_client.int(id))
        |> dream_postgres_client.returning(decode.at([0], decode.string))
        |> run(db),
      )
      Ok(ShoppingList(id:, name:, items:))
    }
  }
}

/// The id and the name of each list, oldest first.
pub fn all(db: Connection) -> Result(List(#(Int, String)), ListError) {
  dream_postgres_client.query("SELECT id, name FROM lists ORDER BY id")
  |> dream_postgres_client.returning({
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    decode.success(#(id, name))
  })
  |> run(db)
}

/// The secret token of the share link of a list.
pub fn share_token(db: Connection, id: Int) -> Result(String, ListError) {
  let rows =
    dream_postgres_client.query("SELECT share_token FROM lists WHERE id = $1")
    |> dream_postgres_client.parameter(dream_postgres_client.int(id))
    |> dream_postgres_client.returning(decode.at([0], decode.string))
    |> run(db)
  case rows {
    Ok([token, ..]) -> Ok(token)
    Ok([]) -> Error(NoSuchList(id))
    Error(error) -> Error(error)
  }
}

fn insert_list(db: Connection, name: String) -> Result(Int, QueryError) {
  let inserted =
    dream_postgres_client.query(
      "INSERT INTO lists (name) VALUES ($1) RETURNING id",
    )
    |> dream_postgres_client.parameter(dream_postgres_client.text(name))
    |> dream_postgres_client.returning(decode.at([0], decode.int))
    |> dream_postgres_client.execute(db)
  case inserted {
    Ok(dream_postgres_client.Returned(rows: [id, ..], ..)) -> Ok(id)
    Ok(_) -> Error(dream_postgres_client.UnexpectedResultType([]))
    Error(error) -> Error(error)
  }
}

fn insert_item(
  db: Connection,
  list_id: Int,
  title: String,
) -> Result(Nil, QueryError) {
  dream_postgres_client.query(
    "INSERT INTO items (list_id, title) VALUES ($1, $2)",
  )
  |> dream_postgres_client.parameter(dream_postgres_client.int(list_id))
  |> dream_postgres_client.parameter(dream_postgres_client.text(title))
  |> dream_postgres_client.execute(db)
  |> result.replace(Nil)
}

fn run(
  query: dream_postgres_client.Query(row),
  db: Connection,
) -> Result(List(row), ListError) {
  dream_postgres_client.execute(query, db)
  |> result.map(fn(returned) { returned.rows })
  |> result.map_error(QueryFailed)
}
