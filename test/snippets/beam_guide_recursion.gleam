//// BEAM guide: recursion that is not a tail call

/// Wrong: the addition happens after the recursive call returns, so each
/// call keeps a stack frame until the end
pub fn sum_to(n: Int) -> Int {
  case n {
    0 -> 0
    _ -> n + sum_to(n - 1)
  }
}

/// Fix: the recursive call is the last thing the function does, so the
/// stack does not grow
pub fn sum_to_with_total(n: Int, total: Int) -> Int {
  case n {
    0 -> total
    _ -> sum_to_with_total(n - 1, total + n)
  }
}
