//// This module contains the code to run the sql queries defined in
//// `./src/models/post/sql`.
//// > 🐿️ This module was generated automatically using v4.5.0 of
//// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
////

import gleam/dynamic/decode
import gleam/time/timestamp.{type Timestamp}
import pog

/// A row you get from running the `create_post` query
/// defined in `./src/models/post/sql/create_post.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.5.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type CreatePostRow {
  CreatePostRow(
    id: Int,
    title: String,
    content: String,
    author_id: Int,
    status: String,
    created_at: Timestamp,
  )
}

/// Create a new post
///
/// > 🐿️ This function was generated automatically using v4.5.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn create_post(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Int,
) -> Result(pog.Returned(CreatePostRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use content <- decode.field(2, decode.string)
    use author_id <- decode.field(3, decode.int)
    use status <- decode.field(4, decode.string)
    use created_at <- decode.field(5, pog.timestamp_decoder())
    decode.success(CreatePostRow(
      id:,
      title:,
      content:,
      author_id:,
      status:,
      created_at:,
    ))
  }

  "-- Create a new post
INSERT INTO posts (title, content, author_id, status)
VALUES ($1, $2, $3, 'draft')
RETURNING id, title, content, author_id, status, created_at

"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_post` query
/// defined in `./src/models/post/sql/get_post.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.5.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetPostRow {
  GetPostRow(
    id: Int,
    title: String,
    content: String,
    author_id: Int,
    status: String,
    created_at: Timestamp,
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
    use title <- decode.field(1, decode.string)
    use content <- decode.field(2, decode.string)
    use author_id <- decode.field(3, decode.int)
    use status <- decode.field(4, decode.string)
    use created_at <- decode.field(5, pog.timestamp_decoder())
    decode.success(GetPostRow(
      id:,
      title:,
      content:,
      author_id:,
      status:,
      created_at:,
    ))
  }

  "-- Get a single post by ID
SELECT id, title, content, author_id, status, created_at
FROM posts
WHERE id = $1

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `list_posts` query
/// defined in `./src/models/post/sql/list_posts.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.5.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ListPostsRow {
  ListPostsRow(
    id: Int,
    title: String,
    content: String,
    author_id: Int,
    status: String,
    created_at: Timestamp,
  )
}

/// List all posts
///
/// > 🐿️ This function was generated automatically using v4.5.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn list_posts(
  db: pog.Connection,
) -> Result(pog.Returned(ListPostsRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use content <- decode.field(2, decode.string)
    use author_id <- decode.field(3, decode.int)
    use status <- decode.field(4, decode.string)
    use created_at <- decode.field(5, pog.timestamp_decoder())
    decode.success(ListPostsRow(
      id:,
      title:,
      content:,
      author_id:,
      status:,
      created_at:,
    ))
  }

  "-- List all posts
SELECT id, title, content, author_id, status, created_at
FROM posts
ORDER BY created_at DESC

"
  |> pog.query
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `publish_post` query
/// defined in `./src/models/post/sql/publish_post.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.5.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type PublishPostRow {
  PublishPostRow(
    id: Int,
    title: String,
    content: String,
    author_id: Int,
    status: String,
    created_at: Timestamp,
  )
}

/// Publish a post
///
/// > 🐿️ This function was generated automatically using v4.5.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn publish_post(
  db: pog.Connection,
  arg_1: Int,
) -> Result(pog.Returned(PublishPostRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use content <- decode.field(2, decode.string)
    use author_id <- decode.field(3, decode.int)
    use status <- decode.field(4, decode.string)
    use created_at <- decode.field(5, pog.timestamp_decoder())
    decode.success(PublishPostRow(
      id:,
      title:,
      content:,
      author_id:,
      status:,
      created_at:,
    ))
  }

  "-- Publish a post
UPDATE posts
SET status = 'published'
WHERE id = $1
RETURNING id, title, content, author_id, status, created_at

"
  |> pog.query
  |> pog.parameter(pog.int(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `update_post` query
/// defined in `./src/models/post/sql/update_post.sql`.
///
/// > 🐿️ This type definition was generated automatically using v4.5.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type UpdatePostRow {
  UpdatePostRow(
    id: Int,
    title: String,
    content: String,
    author_id: Int,
    status: String,
    created_at: Timestamp,
  )
}

/// Update a post
///
/// > 🐿️ This function was generated automatically using v4.5.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn update_post(
  db: pog.Connection,
  arg_1: String,
  arg_2: String,
  arg_3: Int,
) -> Result(pog.Returned(UpdatePostRow), pog.QueryError) {
  let decoder = {
    use id <- decode.field(0, decode.int)
    use title <- decode.field(1, decode.string)
    use content <- decode.field(2, decode.string)
    use author_id <- decode.field(3, decode.int)
    use status <- decode.field(4, decode.string)
    use created_at <- decode.field(5, pog.timestamp_decoder())
    decode.success(UpdatePostRow(
      id:,
      title:,
      content:,
      author_id:,
      status:,
      created_at:,
    ))
  }

  "-- Update a post
UPDATE posts
SET title = $1, content = $2
WHERE id = $3
RETURNING id, title, content, author_id, status, created_at

"
  |> pog.query
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
