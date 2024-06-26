import gleam/bit_array
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub type BencodeType {

  Dict(dict: Dict(BencodeType, BencodeType))
  List(list: List(BencodeType))
  String(string: String)
  Int(int: Int)
}

type DecodeResult {
  DecodeResult(value: BencodeType, rest: String)
}

// decoding api

pub fn decode_term(raw: String) -> Result(BencodeType, String) {
  case do_decode(raw) {
    Ok(DecodeResult(value: value, rest: "")) -> Ok(value)
    Ok(DecodeResult(rest: rest, ..)) ->
      Error("Syntax error, unclosed term. Rest: \"" <> rest <> "\"")
    Error(error) -> Error(error)
  }
}

pub fn decode_string(raw: String) -> Result(String, String) {
  raw
  |> do_decode()
  |> result.try(fn(result) {
    case result {
      DecodeResult(value: String(string: string), ..) -> Ok(string)
      _ -> Error("Decoded value is not a string")
    }
  })
}

pub fn decode_int(raw: String) -> Result(Int, String) {
  raw
  |> do_decode()
  |> result.try(fn(result) {
    case result {
      DecodeResult(value: Int(int: int), ..) -> Ok(int)
      _ -> Error("Decoded value is not an intewer")
    }
  })
}

pub fn decode_list(raw: String) -> Result(List(BencodeType), String) {
  raw
  |> do_decode()
  |> result.try(fn(result) {
    case result {
      DecodeResult(value: List(list: list), ..) -> Ok(list)
      _ -> Error("Decoded value is not a list")
    }
  })
}

pub fn decode_dict(
  raw: String,
) -> Result(Dict(BencodeType, BencodeType), String) {
  raw
  |> do_decode()
  |> result.try(fn(result) {
    case result {
      DecodeResult(value: Dict(dict: dict), ..) -> Ok(dict)
      _ -> Error("Decoded value is not a dict")
    }
  })
}

fn do_decode(raw: String) -> Result(DecodeResult, String) {
  case bit_array.from_string(raw) {
    <<"i":utf8, _:bytes>> -> do_decode_integer(raw)
    <<"d":utf8, _:bytes>> -> decode_dict0(raw)
    <<"l":utf8, _:bytes>> -> decode_list0(raw)
    // starts with a digit
    <<a, _:bytes>> if 48 <= a && a <= 57 -> do_decode_string(raw)
    _ -> Error("Invalid data type")
  }
}

fn do_decode_integer(raw: String) -> Result(DecodeResult, String) {
  let assert "i" <> rest = raw
  use #(raw_int, rest) <- result.try(next_term(rest))

  use int <- result.try(
    raw_int
    |> int.parse()
    |> result.map_error(fn(_) { "Syntax error: invalid integer" }),
  )

  Ok(DecodeResult(value: Int(int: int), rest: rest))
}

fn do_decode_string(raw: String) -> Result(DecodeResult, String) {
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
  do_decode_dict1(DecodeResult(value: Dict(dict: dict.new()), rest: rest))
}

fn do_decode_dict1(decoder: DecodeResult) -> Result(DecodeResult, String) {
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

// encoding api

pub fn encode_term(term: BencodeType) -> String {
  case term {
    String(string: string) -> encode_string(string)
    Int(int: int) -> encode_int(int)
    List(list: list) -> encode_list(list)
    Dict(dict: dict) -> encode_dict(dict)
  }
}

pub fn encode_string(string: String) -> String {
  let length =
    string
    |> string.length()
    |> int.to_string()

  length <> ":" <> string
}

pub fn encode_int(int: Int) -> String {
  "i" <> int.to_string(int) <> "e"
}

pub fn encode_list(list: List(BencodeType)) -> String {
  let encoded_values =
    list
    |> list.map(encode_term)
    |> string.concat()

  "i" <> encoded_values <> "e"
}

pub fn encode_dict(dict: Dict(BencodeType, BencodeType)) -> String {
  let encoded_values =
    dict
    |> dict.to_list()
    |> list.flat_map(fn(el) { [encode_term(el.0), encode_term(el.1)] })
    |> string.concat()

  "i" <> encoded_values <> "e"
}
