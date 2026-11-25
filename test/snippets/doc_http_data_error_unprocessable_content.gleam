//// Example for the doc of `error.UnprocessableContent`.

import dream/http/error.{type Error, UnprocessableContent}

pub fn check_dates(start_date: Int, end_date: Int) -> Result(Nil, Error) {
  case start_date < end_date {
    True -> Ok(Nil)
    False -> Error(UnprocessableContent("Start date must be before end date"))
  }
}
