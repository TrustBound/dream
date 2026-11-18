import dream/http/response
import dream/http/status
import gleam/yielder

pub type Services {
  Services(user_names: List(String))
}

pub fn export_users(_request, _context, services: Services) {
  let user_stream =
    services.user_names
    |> yielder.from_list
    |> yielder.map(user_to_csv_row)
    |> yielder.map(fn(row) { <<row:utf8>> })

  response.stream_response(status.ok, user_stream, "text/csv")
}

fn user_to_csv_row(name: String) -> String {
  name <> "\n"
}
