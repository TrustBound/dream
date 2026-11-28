import dream_test/assertions/should.{equal, fail_with, or_fail_with, should}
import dream_test/types.{AssertionOk}
import dream_test/unit.{type UnitTest, before_each, describe, it}
import gleam/result
import simplifile

const test_directory = "tmp/testing_guide_integration"

pub fn tests() -> UnitTest {
  describe("file storage integration", [
    before_each(fn() {
      // Delete files from earlier runs
      case simplifile.delete_all([test_directory]) {
        Ok(_) -> AssertionOk
        Error(_) -> fail_with("Could not delete test files")
      }
    }),
    it("saves user to disk", fn() {
      // Uses the real file system
      save_user(test_directory, "alice", "Alice")
      |> should()
      |> equal(Ok("Alice"))
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
