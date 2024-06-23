import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/int
import gleam/io
import gleam/list
import gleam/result
import gleam/string

pub fn main() {
  io.println("Hello from gleabencode!")
}

pub type BencodeType {

  Dict(dict: Dict(BencodeType, BencodeType))
  List(list: List(BencodeType))
  String(string: String)
  Int(int: Int)
}

type DecodeResult {
  DecodeResult(value: BencodeType, rest: String)
}

pub fn decode_term(raw: String) -> Result(BencodeType, String) {
  case do_decode(raw) {
    Ok(DecodeResult(value: value, rest: "")) -> Ok(value)
    Ok(DecodeResult(rest: rest, ..)) ->
      Error("Syntax error, unclosed term. Rest: \"" <> rest <> "\"")
    Error(error) -> Error(error)
  }
}

fn do_decode(raw: String) -> Result(DecodeResult, String) {
  case bit_array.from_string(raw) {
    <<"i":utf8, _:bytes>> -> decode_integer(raw)
    <<"d":utf8, _:bytes>> -> decode_dict0(raw)
    <<"l":utf8, _:bytes>> -> decode_list0(raw)
    // starts with a digit
    <<a, _:bytes>> if 48 <= a && a <= 57 -> decode_string(raw)
    _ -> Error("Invalid data type")
  }
}

fn decode_integer(raw: String) -> Result(DecodeResult, String) {
  let assert "i" <> rest = raw
  use #(raw_int, rest) <- result.try(next_term(rest))

  use int <- result.try(
    raw_int
    |> int.parse()
    |> result.map_error(fn(_) { "Syntax error: invalid integer" }),
  )

  Ok(DecodeResult(value: Int(int: int), rest: rest))
}

fn decode_string(raw: String) -> Result(DecodeResult, String) {
  use #(raw_length, rest) <- result.try(
    raw
    |> string.split_once(":")
    |> result.map_error(fn(_) {
      "Syntax error: No separator for string length found"
    }),
  )
  use length <- result.try(
    raw_length
    |> int.parse()
    |> result.map_error(fn(_) { "Syntax error: Invalid string length" }),
  )

  case bit_array.from_string(rest) {
    <<content:bytes-size(length), rest:bytes>> -> {
      let assert Ok(content) = bit_array.to_string(content)
      let assert Ok(rest) = bit_array.to_string(rest)
      Ok(DecodeResult(value: String(string: content), rest: rest))
    }
    _ -> Error("Given string length is too long")
  }
}

fn decode_list0(raw: String) -> Result(DecodeResult, String) {
  let assert "l" <> rest = raw
  decode_list1(DecodeResult(value: List(list: []), rest: rest))
}

fn decode_list1(decoder: DecodeResult) -> Result(DecodeResult, String) {
  let assert DecodeResult(value: List(list: agg), rest: rest) = decoder

  case do_decode(rest) {
    Ok(DecodeResult(value: value, rest: "e" <> rest)) ->
      Ok(DecodeResult(
        value: List(list: list.reverse([value, ..agg])),
        rest: rest,
      ))

    Ok(DecodeResult(value: value, rest: rest)) ->
      decode_list1(DecodeResult(value: List(list: [value, ..agg]), rest: rest))
    Error(error) -> Error(error)
  }
}

fn decode_dict0(raw: String) -> Result(DecodeResult, String) {
  let assert "d" <> rest = raw
  decode_dict1(DecodeResult(value: Dict(dict: dict.new()), rest: rest))
}

fn decode_dict1(decoder: DecodeResult) -> Result(DecodeResult, String) {
  let assert DecodeResult(value: Dict(dict: agg), rest: rest) = decoder
  use DecodeResult(value: key, rest: rest) <- result.try(do_decode(rest))

  case do_decode(rest) {
    Ok(DecodeResult(value: value, rest: "e" <> rest)) ->
      Ok(DecodeResult(
        value: Dict(dict: dict.insert(agg, key, value)),
        rest: rest,
      ))
    Ok(DecodeResult(..)) -> Error("Syntax error: unclosed term")
    other -> other
  }
}

fn next_term(raw: String) -> Result(#(String, String), String) {
  raw
  |> string.split_once("e")
  |> result.map_error(fn(_) { "Syntax error: unclosed term" })
}
