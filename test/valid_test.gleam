import gleeunit

import gleam/dynamic
import gleam/result
import gleam/option.{Option}
import gleam/json

import valid.{validate, accept, apply, optional, valid, validatable_map, validator}
import valid/int
import valid/string

pub fn main() {
  gleeunit.main()
}

// Poets test

pub type Poet {
  Poet(birth_year: Int, start_year: Int, end_year: Option(Int))
}

fn decode_poet(data) {
  use birth_year <- result.try(
    data
    |> dynamic.field(named: "birth_year", of: dynamic.int),
  )

  use start_year <- result.try(
    data
    |> dynamic.field(named: "start_year", of: dynamic.int),
  )

  use end_year <- result.map(
    data
    |> dynamic.optional_field(named: "end_year", of: dynamic.int),
  )

  use birth_year <-
    validator()
    |> int.bounded(
      between: 1600,
      and: 2023,
      raise: "Birth year must be between 1600 and 2023"
    )
    |> apply(birth_year)

  use start_year <-
    validator()
    |> int.greater(
      than: birth_year,
      raise: "start year must be after birth year",
    )
    |> apply(start_year)

  use end_year <-
    validator()
    |> int.greater(than: birth_year, raise: "end year must be after start year")
    |> optional()
    |> apply(end_year)

  valid(Poet(birth_year, start_year, end_year))
}

pub fn decode_name(data) {
  use name <- result.map(dynamic.string(data))

  validator()
  |> string.nonempty("name must be nonempty")
  |> string.max_length(25, "names must not be longer than 25 charicters")
  |> accept(name)
}

fn decode_poets(data) {
  use poets <- result.map(
    data
    |> dynamic.map(decode_name, decode_poet),
  )

  validatable_map(poets)
}

pub fn poets_test() {
  let json_string =
  "
  {
  \"Percy Shelly\": {
  \"birth_year\": 1792,
  \"start_year\": 1810
  },
  \"George Gordon Byron\": {
  \"birth_year\": 1788,
  \"start_year\": 1805,
  \"end_year\": 1808
  }
  }
  "

  let assert Ok(validatable_poets) =
  json.decode(from: json_string, using: decode_poets)

  let assert Ok(_) = validate(validatable_poets)
}
