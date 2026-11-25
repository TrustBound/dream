//// BEAM guide: add to the front of a list, then reverse it

import gleam/list

/// Wrong: `list.append` copies the whole list on each step
pub fn squares_by_appending(numbers: List(Int)) -> List(Int) {
  list.fold(numbers, [], fn(squares, number) {
    list.append(squares, [number * number])
  })
}

/// Fix: add each item to the front, then reverse the list one time
pub fn squares(numbers: List(Int)) -> List(Int) {
  list.fold(numbers, [], fn(squares, number) { [number * number, ..squares] })
  |> list.reverse
}
