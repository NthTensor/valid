import valid.{extend, valid, invalid, Validator}

/// Raises an issue when the output is less than the minimum.
///
pub fn greater(
  validator: Validator(x, Int, i),
  than min: Int,
  raise issue: i,
) -> Validator(x, Int, i) {
  use int <- extend(validator)
  case int < min {
    True -> invalid(int, issue)
    False -> valid(int)
  }
}

/// Raises an issue when the output is greater than the maximum.
///
pub fn less(
  validator: Validator(x, Int, i),
  than max: Int,
  raise issue: i,
) -> Validator(x, Int, i) {
  use int <- extend(validator)
  case int > max {
    True -> invalid(int, issue)
    False -> valid(int)
  }
}

/// Raises an issue when the output is not within the specified bounds.
///
pub fn bounded(
  validator: Validator(x, Int, i),
  between min: Int,
  and max: Int,
  raise issue: i,
) -> Validator(x, Int, i) {
  use int <- extend(validator)
  case min < int && int < max {
    True -> valid(int)
    False -> invalid(int, issue)
  }
}

