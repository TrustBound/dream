import dream/http/response
import dream/http/status
import gleam/int

pub fn create_post(_request, _context, _services) {
  // After creating post, redirect to view it
  let post_id = 123
  response.redirect_response(
    status.see_other,
    "/posts/" <> int.to_string(post_id),
  )
}
