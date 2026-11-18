//// Example for the doc comment of `params.require_json`.

import dream/http/error.{type Error}
import dream/http/params
import dream/http/request.{type Request}
import gleam/dynamic/decode
import gleam/result

pub type NewTask {
  NewTask(title: String, priority: Int)
}

fn new_task_decoder() -> decode.Decoder(NewTask) {
  use title <- decode.field("title", decode.string)
  use priority <- decode.field("priority", decode.int)
  decode.success(NewTask(title: title, priority: priority))
}

pub fn read_task(request: Request) -> Result(NewTask, Error) {
  use task <- result.try(params.require_json(request, new_task_decoder()))
  Ok(task)
}
