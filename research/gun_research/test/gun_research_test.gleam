import gleam/io

@external(erlang, "gun_bench", "run_all")
fn run_all() -> Nil

pub fn main() {
  io.println("Running gun research benchmarks...")
  run_all()
  io.println("Done.")
}
