import mist/internal/file

pub fn it_should_read_nothing_at_end_of_file_test() {
  let assert Ok(descriptor) = file.open(<<"gleam.toml":utf8>>)
  let read = file.pread(descriptor, 0, 0)
  let assert Ok(_nil) = file.close(descriptor)

  assert read == Ok(<<>>)
}
