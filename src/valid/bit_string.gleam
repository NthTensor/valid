import valid.{Validator, extend, halt, valid}
import gleam/bit_string

pub fn utf8(
  validator: Validator(x, BitString, i),
  raise issue: i,
) -> Validator(x, String, i) {
  use bit_str <- extend(validator)
  case bit_string.to_string(bit_str) {
    Ok(str) -> valid(str)
    Error(_) -> halt(issue)
  }
}
