import valid.{extend, valid, invalid, Validator}

/// Raises an issue when the output is less than the minimum.
///
pub fn greater(
  validator: Validator(x, Float, i),
  than min: Float,
  raise issue: i,
) -> Validator(x, Float, i) {
  use float <- extend(validator)
  case float <. min {
    True -> invalid(float, issue)
    False -> valid(float)
  }
}

/// Raises an issue when the output is greater than the maximum.
///
pub fn less(
  validator: Validator(x, Float, i),
  than max: Float,
  raise issue: i,
) -> Validator(x, Float, i) {
  use float <- extend(validator)
  case float >. max {
    True -> invalid(float, issue)
    False -> valid(float)
  }
}

/// Raises an issue when the output is not within the specified bounds.
///
pub fn bounded(
  validator: Validator(x, Float, i),
  between min: Float,
  and max: Float,
  raise issue: i,
) -> Validator(x, Float, i) {
  use float <- extend(validator)
  case min <. float && float <. max {
    True -> valid(float)
    False -> invalid(float, issue)
  }
}
