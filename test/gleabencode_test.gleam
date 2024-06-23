import gleabencode
import gleam/dict
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

// decoding tests
pub fn decode_string_test() {
  "11:Hello world"
  |> gleabencode.decode_term()
  |> should.be_ok()
  |> should.equal(gleabencode.String(string: "Hello world"))
}

pub fn handle_string_length_too_long_test() {
  "12:Hello world"
  |> gleabencode.decode_term()
  |> should.be_error()
  |> should.equal("Given string length is too long")
}

pub fn handle_string_no_separator_test() {
  "11Hello world"
  |> gleabencode.decode_term()
  |> should.be_error()
  |> should.equal("Syntax error: No separator for string length found")
}

pub fn handle_string_invalid_string_length_test() {
  "11a:Hello world"
  |> gleabencode.decode_term()
  |> should.be_error()
  |> should.equal("Syntax error: Invalid string length")
}

pub fn decode_positive_integer_test() {
  "i42e"
  |> gleabencode.decode_term()
  |> should.be_ok()
  |> should.equal(gleabencode.Int(int: 42))
}

pub fn decode_negative_integer_test() {
  "i-42e"
  |> gleabencode.decode_term()
  |> should.be_ok()
  |> should.equal(gleabencode.Int(int: -42))
}

pub fn handle_integer_unclosed_test() {
  "i42a"
  |> gleabencode.decode_term()
  |> should.be_error()
  |> should.equal("Syntax error: unclosed term")
}

pub fn handle_integer_invalid_test() {
  "i42ae"
  |> gleabencode.decode_term()
  |> should.be_error()
  |> should.equal("Syntax error: invalid integer")
}

pub fn decode_list_test() {
  "li42ei-42ee"
  |> gleabencode.decode_term()
  |> should.be_ok()
  |> should.equal(
    gleabencode.List(list: [gleabencode.Int(int: 42), gleabencode.Int(int: -42)]),
  )
}

pub fn handle_list_unclosed_test() {
  "li42ei42e"
  |> gleabencode.decode_term()
  |> should.be_error()
  |> should.equal("Invalid data type")
}

pub fn decode_dict_test() {
  "di42ei-42ee"
  |> gleabencode.decode_term()
  |> should.be_ok()
  |> should.equal(
    gleabencode.Dict(
      dict: dict.from_list([
        #(gleabencode.Int(int: 42), gleabencode.Int(int: -42)),
      ]),
    ),
  )
}

pub fn handle_dict_unclosed_test() {
  "di42ei42e"
  |> gleabencode.decode_term()
  |> should.be_error()
  |> should.equal("Syntax error: unclosed term")
}

// encoding tests

pub fn encode_string() {
  gleabencode.String(string: "Hello world")
  |> gleabencode.encode_term()
  |> should.equal("11:Hello world")
}

pub fn encode_integer() {
  gleabencode.Int(int: 42)
  |> gleabencode.encode_term()
  |> should.equal("i42e")

  gleabencode.Int(int: -42)
  |> gleabencode.encode_term()
  |> should.equal("i-42e")
}

pub fn encode_list() {
  // Easier to write the test like this
  "li42ei-42ee"
  |> gleabencode.decode_term()
  |> should.be_ok()
  |> gleabencode.encode_term()
  |> should.equal("li42ei-42ee")
}

pub fn encode_dict() {
  // Easier to write the test like this
  "di42ei-42ee"
  |> gleabencode.decode_term()
  |> should.be_ok()
  |> gleabencode.encode_term()
  |> should.equal("dli42ei-42ee")
}
