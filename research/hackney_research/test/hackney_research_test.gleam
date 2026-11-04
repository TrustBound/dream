import gleam/io

pub fn main() {
  io.println("Starting hackney research...")
  run_all()
  io.println("Done.")
}

@external(erlang, "hackney_bench", "run_all")
fn run_all() -> Nil
