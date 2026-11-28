//// Operations guide: an operation that coordinates several services
////
//// Shown in an excerpt in docs/guides/database-api.md.

import dream/http/error.{type Error, NotFound}
import gleam/list
import gleam/result

pub type Post {
  Post(id: Int, title: String, published: Bool)
}

pub type Services {
  Services(
    posts: List(Post),
    add_to_search_index: fn(Post) -> Result(Nil, Error),
    notify_subscribers: fn(Post) -> Result(Nil, Error),
  )
}

pub fn publish_post(services: Services, post_id: Int) -> Result(Post, Error) {
  use post <- result.try(find_post(services.posts, post_id))
  let published_post = Post(..post, published: True)

  // Side effects coordinated here. A failure stops the chain and comes
  // back to the controller as an Error.
  use Nil <- result.try(services.add_to_search_index(published_post))
  use Nil <- result.try(services.notify_subscribers(published_post))

  Ok(published_post)
}

fn find_post(posts: List(Post), post_id: Int) -> Result(Post, Error) {
  list.find(posts, fn(post) { post.id == post_id })
  |> result.replace_error(NotFound("Post not found"))
}
