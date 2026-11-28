import dream_test/matchers.{be_equal, or_fail_with, should}
import dream_test/suite.{type TestSuite}
import dream_test/unit.{before_each, describe, it}
import gleam/result
import simplifile

const test_directory = "tmp/testing_guide_integration"

pub fn tests() -> TestSuite {
  describe("file storage integration", [
    before_each(fn() {
      // Delete files from earlier runs
      case simplifile.delete_all([test_directory]) {
        Ok(_) -> Ok(Nil)
        Error(_) -> Error("Could not delete test files")
      }
    }),
    it("saves user to disk", fn() {
      // Uses the real file system
      save_user(test_directory, "alice", "Alice")
      |> should()
      |> be_equal(Ok("Alice"))
      |> or_fail_with("Should read back the saved user")
    }),
  ])
}

pub fn save_user(
  directory: String,
  id: String,
  name: String,
) -> Result(String, simplifile.FileError) {
  let path = directory <> "/" <> id <> ".txt"
  use _ <- result.try(simplifile.create_directory_all(directory))
  use _ <- result.try(simplifile.write(to: path, contents: name))
  simplifile.read(path)
}
