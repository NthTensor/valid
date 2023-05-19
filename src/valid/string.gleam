import gleam/string
import valid.{extend, valid, invalid, Validator}

/// Raises an issue when the output is the empty string.
///
pub fn nonempty(
  validator: Validator(x, String, i),
  raise issue: i,
) -> Validator(x, String, i) {
  use str <- extend(validator)
  case string.is_empty(str) {
    True -> invalid(str, issue)
    False -> valid(str)
  }
}

/// Raises an issue when the output is longer than a certian length.
///
pub fn max_length(
  validator: Validator(x, String, i),
  max_length: Int,
  raise issue: i,
) -> Validator(x, String, i) {
  use str <- extend(validator)
  let length = string.length(str)
  case length > max_length {
    True -> invalid(str, issue)
    False -> valid(str)
  }
}
