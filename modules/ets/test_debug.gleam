import gleeunit/should

pub fn test_debug() {
  True |> should.equal(True)
  False |> should.equal(False)
  "test" |> should.equal("test")
}
