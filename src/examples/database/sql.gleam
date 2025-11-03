//// This module contains the code to run the sql queries defined in
//// `./src/examples/database/sql`.
//// > 🐿️ This module was generated automatically using v4.5.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/option.{type Option}
import gleam/time/timestamp.{type Timestamp}
import pog

/// A row you get from running the `create_post` query
/// defined in `./src/examples/database/sql/create_post.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.5.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CreatePostRow {
  CreatePostRow(
    id: Int,
    user_id: Int,
    title: String,
    content: Option(String),
    created_at: Option(Timestamp),
  )
}

/// Create a new post for a user
///
/// > 🐿️ This function was generated automatically using v4.5.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_post(
  db: pog.Connection,
  arg_1: Int,
  arg_2: String,
  arg_3: String,
) -> Result(pog.Returned(CreatePostRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use user_id <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use content <- decode.field(3, decode.optional(decode.string))
    use created_at <- decode.field(4, decode.optional(pog.timestamp_decoder()))
    decode.success(CreatePostRow(id:, user_id:, title:, content:, created_at:))
  }

  "-- Create a new post for a user
INSERT INTO posts (user_id, title, content) VALUES ($1, $2, $3) RETURNING id, user_id, title, content, created_at

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `create_user` query
/// defined in `./src/examples/database/sql/create_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.5.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CreateUserRow {
  CreateUserRow(
    id: Int,
    name: String,
    email: String,
    created_at: Option(Timestamp),
  )
}

/// Create a new user
///
/// > 🐿️ This function was generated automatically using v4.5.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_user(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
) -> Result(pog.Returned(CreateUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use email <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.optional(pog.timestamp_decoder()))
    decode.success(CreateUserRow(id:, name:, email:, created_at:))
  }

  "-- Create a new user
INSERT INTO users (name, email) VALUES ($1, $2) RETURNING id, name, email, created_at

"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Delete a user
///
/// > 🐿️ This function was generated automatically using v4.5.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn delete_user(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(Nil), pog.QueryError) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  "-- Delete a user
DELETE FROM users WHERE id = $1

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_post` query
/// defined in `./src/examples/database/sql/get_post.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.5.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetPostRow {
  GetPostRow(
    id: Int,
    user_id: Int,
    title: String,
    content: Option(String),
    created_at: Option(Timestamp),
  )
}

/// Get a single post by ID
///
/// > 🐿️ This function was generated automatically using v4.5.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_post(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(GetPostRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use user_id <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use content <- decode.field(3, decode.optional(decode.string))
    use created_at <- decode.field(4, decode.optional(pog.timestamp_decoder()))
    decode.success(GetPostRow(id:, user_id:, title:, content:, created_at:))
  }

  "-- Get a single post by ID
SELECT id, user_id, title, content, created_at FROM posts WHERE id = $1

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_user` query
/// defined in `./src/examples/database/sql/get_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.5.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetUserRow {
  GetUserRow(
    id: Int,
    name: String,
    email: String,
    created_at: Option(Timestamp),
  )
}

/// Get a single user by ID
///
/// > 🐿️ This function was generated automatically using v4.5.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_user(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(GetUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use email <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.optional(pog.timestamp_decoder()))
    decode.success(GetUserRow(id:, name:, email:, created_at:))
  }

  "-- Get a single user by ID
SELECT id, name, email, created_at FROM users WHERE id = $1

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `list_posts` query
/// defined in `./src/examples/database/sql/list_posts.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.5.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListPostsRow {
  ListPostsRow(
    id: Int,
    user_id: Int,
    title: String,
    content: Option(String),
    created_at: Option(Timestamp),
  )
}

/// List all posts for a user
///
/// > 🐿️ This function was generated automatically using v4.5.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_posts(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(ListPostsRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use user_id <- decode.field(1, decode.int)
    use title <- decode.field(2, decode.string)
    use content <- decode.field(3, decode.optional(decode.string))
    use created_at <- decode.field(4, decode.optional(pog.timestamp_decoder()))
    decode.success(ListPostsRow(id:, user_id:, title:, content:, created_at:))
  }

  "-- List all posts for a user
SELECT id, user_id, title, content, created_at FROM posts WHERE user_id = $1 ORDER BY id

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `list_users` query
/// defined in `./src/examples/database/sql/list_users.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.5.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListUsersRow {
  ListUsersRow(
    id: Int,
    name: String,
    email: String,
    created_at: Option(Timestamp),
  )
}

/// List all users
///
/// > 🐿️ This function was generated automatically using v4.5.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_users(
  db: pog.Connection,
) -> Result(pog.Returned(ListUsersRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use email <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.optional(pog.timestamp_decoder()))
    decode.success(ListUsersRow(id:, name:, email:, created_at:))
  }

  "-- List all users
SELECT id, name, email, created_at FROM users ORDER BY id

"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `update_user` query
/// defined in `./src/examples/database/sql/update_user.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.5.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UpdateUserRow {
  UpdateUserRow(
    id: Int,
    name: String,
    email: String,
    created_at: Option(Timestamp),
  )
}

/// Update a user
///
/// > 🐿️ This function was generated automatically using v4.5.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn update_user(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Int,
) -> Result(pog.Returned(UpdateUserRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use name <- decode.field(1, decode.string)
    use email <- decode.field(2, decode.string)
    use created_at <- decode.field(3, decode.optional(pog.timestamp_decoder()))
    decode.success(UpdateUserRow(id:, name:, email:, created_at:))
  }

  "-- Update a user
UPDATE users SET name = $1, email = $2 WHERE id = $3 RETURNING id, name, email, created_at

"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
