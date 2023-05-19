import gleam/option.{None, Option, Some}
import gleam/list
import gleam/map.{Map}

/// A validation is a list of issues about an optionally included value.
///
/// You will probably never need to use this type. `Validatables` are more common. However,
/// if you do come across a validation, you should know that `Continue` signifies that a
/// parser is at-least able to construct the desired output type, even if it has some issues.
/// When you receive a `Continue` it will contain all of the relevent issues.
///
/// `Halt` on the other hand signifies that a parser failed to construct the desired output.
/// For example when working with dates the input timestamp must be of the correct format or
/// the date cannot be parsed and any higher-level validators that operate on dates rather
/// than strings cannot be run. A `halt` stops validation early, and so may not contain all
/// issues.
///
pub type Validation(t, i) {
  Continue(value: t, issues: List(i))
  Halt(issues: List(i))
}

/// A `Validatable` is something you can pass to `validate`. Technically it's a function
/// which returns a validation, but thats less important in practice.
///
/// The input to a Validatable is a list of issues. These will be included in the returned
/// `Validation`, with possibly more added.
///
/// The `validate` function turns a `Validatable` into a `Result`.
///
/// Under the hood all of the parsing logic translates to constructing one big valadatable
/// out of a series of smaller validatables. When `validate` is called a list is passed
/// down through the entire series to accumulate the issues. This means the list of issues
/// need never be copied.
///
pub type Validatable(t, i) =
  fn(List(i)) -> Validation(t, i)

/// A `Validator` makes something `Validatable`. 12
///
/// Validators are allowed to transform the validated type, which why the input and return
/// types are different.
///
pub type Validator(x, t, i) =
  fn(x) -> Validatable(t, i)

/// Applies a function to a validation when parsing is set to continue.
///
/// This function is designed for `use`. It allows you to run code conditionally on a `Validation`
/// being `Continue`.
///
pub fn continuing(
  validation: Validation(t, i),
  fun: fn(t, List(i)) -> Validation(k, i),
) -> Validation(k, i) {
  case validation {
    Continue(value, issues) -> fun(value, issues)
    Halt(issues) -> Halt(issues)
  }
}

/// Returns a validator that does nothing.
///
/// This function is needed to create the root of a validation pipeline which can then
/// be added to with `extend`.
///
/// ## Examples
///
/// ```gleam
/// > validator()
/// > |> string.nonempty("Name must not be empty")
/// > |> string.max_length(10, "Name must be no longer than 10 charicters")
/// > |> string.no_spaces("Name must not have spaces")
/// > |> accept("Percy Shelly")
/// > |> validate()
/// Ok("Percy Shelly")
/// ```
///
pub fn validator() -> Validator(a, a, i) {
  fn(input) { fn(issues) { Continue(input, issues) } }
}

/// Combines two validators into one by evaluating the first and then the second in sequence.
///
/// ## Examples
///
/// ```gleam
/// > import valid.{validator, extend, apply}
/// > import valid/string
/// >
/// > let composable_validator = fn(field: String) {
/// >   validator()
/// >   |> string.nonempty(field <> " must not be empty")
/// >   |> string.max_length(10, field <> " must be no longer than 10 charicters")
/// >   |> string.no_spaces(field <> " must not have spaces")
/// > }
/// > 
/// > let name_validator = 
/// >   validator()
/// >   |> string.title_case("Names must be in title case")
/// >   |> extend(composable_validator("Names"))
/// >
/// > "henry james"
/// > |> name_validator()
/// > |> validate()
/// Error(["Names must be in title case", "Names must not have spaces"])
/// ```
///
/// Extend is also compatable with `use`. Most of the validators in this library
/// start with `use value <- extend(validator)`.
///
/// ```gleam
/// > import valid.{extend, valid, invalid}
/// > import gleam/string
/// >
/// > fn string_nonempty(validator, issue) {
/// >   use str <- extend(validator)
/// >   case string.is_empty(str) {
/// >     True -> invalid(str, issue)
/// >     False -> valid(str)
/// >   }
/// > }
/// ```
///
pub fn extend(
  first: Validator(a, b, i),
  second: Validator(b, c, i),
) -> Validator(a, c, i) {
  fn(input) {
    let complete_first = first(input)
    fn(issues) {
      use output, issues <- continuing(complete_first(issues))
      second(output)(issues)
    }
  }
}

/// Applies a validator to an input without providing a callback.
///
/// ## Examples
///
/// Consider the following function:
/// 
/// ```gleam
/// > fn validate_value(value) {
/// >   use value <-
/// >     validator()
/// >     |> foo()
/// >     |> bar()
/// >     |> apply(value)
/// >   valid(value)
/// > }
/// ```
///
/// Because we don't do anything with `value` before returning it, it is
/// more ergonomic and slightly more efficent to write the following:
///
/// ```gleam
/// > fn validate_value(value) {
/// >   validator()
/// >   |> foo()
/// >   |> bar()
/// >   |> accept(value)
/// > }
/// ```
///
pub fn accept(validator: Validator(a, b, i), input: a) -> Validatable(b, i) {
  let validatable = validator(input)
  fn(issues) { validatable(issues) }
}

/// Applies a validator to an input and provides a callback. Like `accept` but
/// keeps the validator going afterwards.
///
/// The return type here may be a little confusing. This returns a function
/// ```gleam
/// fn(fn(b) -> Validatible(c, i)) -> Validatable(c, i)
/// ```
/// which when combined with `use` makes the remainder of the calling function
/// work like a validator.
///
/// ## Examples
///
/// TODO
///
pub fn apply(
  first: Validator(a, b, i),
  input: a,
) -> fn(Validator(b, c, i)) -> Validatable(c, i) {
  let complete_first = first(input)
  fn(second) {
    fn(issues) {
      use output, issues <- continuing(complete_first(issues))
      second(output)(issues)
    }
  }
}

/// Returns an valid `Validatable` which allows validation to progress and
/// raises no issues.
///
/// This function should be used when constructing validators much like
/// `gleam/result.Ok` is used when working with results.
///
/// ```gleam
/// > import valid.{extend, valid, invalid}
/// > import gleam/string
/// >
/// > fn string_nonempty(validator, issue) {
/// >   use str <- extend(validator)
/// >   case string.is_empty(str) {
/// >     True -> invalid(str, issue)
/// >     False -> valid(str)
/// >   }
/// > }
/// ```
///
pub fn valid(input: t) -> Validatable(t, i) {
  fn(issues) { Continue(input, issues) }
}

/// Returns an invalid `Validatable` which pushes an issue onto the list
/// of issues but still allows validation to progress.
///
/// This function should be used when constructing validators much like
/// `gleam/result.Error` is used when working with results.
///
/// ```gleam
/// > import valid.{extend, valid, invalid}
/// > import gleam/string
/// >
/// > fn string_nonempty(validator, issue) {
/// >   use str <- extend(validator)
/// >   case string.is_empty(str) {
/// >     True -> invalid(str, issue)
/// >     False -> valid(str)
/// >   }
/// > }
/// ```
///
pub fn invalid(input: t, issue: i) -> Validatable(t, i) {
  fn(issues) { Continue(input, [issue, ..issues]) }
}

/// Returns an invalid `Validatable` which pushes an issue onto the list
/// of issues and immediately stops validation.
///
/// The benifit of `halt` as opposed to `invalid` is that you need not return
/// a value. This is useful when parsing cannot progress, for example when
/// checking the encoding of a string, or the format of a timestamp.
///
pub fn halt(issue: i) -> Validatable(t, i) {
  fn(issues) { Halt([issue, ..issues]) }
}

/// Turns a `Validatable` into a result.
///
/// Returns `Ok(value)` if the list of issues is empty, or `Error(issues)` if
/// there is at-least one issue or parsing halted.
///
pub fn validate(validatable: Validatable(t, i)) {
  case validatable([]) {
    Continue(value, []) -> Ok(value)
    Continue(_, issues) -> Error(issues)
    Halt(issues) -> Error(issues)
  }
}

/// Applies a function to the value within a validator.
///
pub fn map(validator: Validator(a, b, i), fun: fn(b) -> c) -> Validator(a, c, i) {
  use value <- extend(validator)
  valid(fun(value))
}

/// Turns a normal validator into a validator on options.
///
/// This runs the validation only when the input is `Some`.
///
pub fn optional(
  validator: Validator(x, y, i),
) -> Validator(Option(x), Option(y), i) {
  fn(option) {
    case option {
      Some(value) -> {
        fn(issues) {
          use output, issues <- continuing(validator(value)(issues))
          Continue(Some(output), issues)
        }
      }
      None -> valid(None)
    }
  }
}

/// Turns a normal validator into a validator on lists.
///
/// ## Examples
///
/// TODO
///
pub fn vector(validator: Validator(x, y, i)) -> Validator(List(x), List(y), i) {
  fn(list) {
    fn(issues) {
      let validation =
        list.fold(
          over: list,
          from: Continue([], issues),
          with: fn(state, value) {
            use values, issues <- continuing(state)
            use value, issues <- continuing(validator(value)(issues))
            Continue([value, ..values], issues)
          },
        )
      use values, issues <- continuing(validation)
      Continue(list.reverse(values), issues)
    }
  }
}

/// Turns a map of validatables into a validatable map. This particularly useful
/// when validating data decoded from a dynamicly typed value.
///
/// ## Examples
///
/// ```gleam
/// > import gleam/dynamic
/// > import gleam/result
/// > import valid.{validatable_map}
/// >
/// > let decode_entry = fn(dynamic) {
/// >   use entry <- result.map(dynamic.string(data))
/// >   validator()
/// >   |> string_nonempty("entry must be nonempty")
/// >   |> string_max_length(9, "entry must not be longer than 9 charicters")
/// >   |> accept(entry)
/// > }
/// >
/// > let decode_map = dynamic.map(decode_entry, decode_entry)
/// > use map <- result.try(deocde_map(dynamic))
/// > validatable_map(map)
/// > |> validate()
/// ```
///
pub fn validatable_map(
  input: Map(Validatable(a, i), Validatable(b, i)),
) -> Validatable(Map(a, b), i) {
  fn(issues) {
    map.fold(
      over: input,
      from: Continue(map.new(), issues),
      with: fn(state, key_validator, value_validator) {
        use map, issues <- continuing(state)
        use key, issues <- continuing(key_validator(issues))
        use value, issues <- continuing(value_validator(issues))
        Continue(map.insert(map, key, value), issues)
      },
    )
  }
}

/// Turns a list of validatables into a validatable list.
///
/// ## Examples
///
/// TODO
///
pub fn validatable_list(
  input: List(Validatable(a, i)),
) -> Validatable(List(a), i) {
  fn(issues) {
    let validation =
      list.fold(
        over: input,
        from: Continue([], issues),
        with: fn(validation, validatable_element) {
          use values, issues <- continuing(validation)
          use new_value, issues <- continuing(validatable_element(issues))
          Continue([new_value, ..values], issues)
        },
      )
    use values, issues <- continuing(validation)
    Continue(list.reverse(values), issues)
  }
}
