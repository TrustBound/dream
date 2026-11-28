//// The controller of `GET /items/:id/share`.

import dream/context.{type EmptyContext}
import dream/http.{type Request, type Response, require_string}
import dream/http/error
import dream/http/response.{text_response}
import dream/http/status
import gleam/option.{Some}
import gleam/uri.{Uri}
import links/services.{type Services}
import links/signing_key

/// Answers with a signed link to the item. The site URL and the key come
/// from the services, not from the environment.
pub fn share(
  request: Request,
  _context: EmptyContext,
  services: Services,
) -> Response {
  case require_string(request, "id") {
    Ok(id) -> text_response(status.ok, share_link(services, id))
    Error(param_error) ->
      text_response(status.bad_request, error.message(param_error))
  }
}

fn share_link(services: Services, id: String) -> String {
  let path = "/items/" <> id
  let signature = signing_key.sign(services.signing_key, path)
  Uri(..services.site_url, path:, query: Some("signature=" <> signature))
  |> uri.to_string
}
