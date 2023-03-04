// RUN: %verify "%s"

include "../Wrappers.dfy"
include "../BoundedInts.dfy"
include "Utils/Str.dfy"

module {:options "-functionSyntax:4"} JSON.Errors {
  import Wrappers
  import opened BoundedInts
  import Utils.Str

  datatype DeserializationError =
    | UnterminatedSequence
    | UnsupportedEscape(str: string)
    | EscapeAtEOS
    | EmptyNumber
    | ExpectingEOF
    | IntOverflow
    | ReachedEOF
    | ExpectingByte(expected: byte, b: opt_byte)
    | ExpectingAnyByte(expected_sq: seq<byte>, b: opt_byte)
  {
    function ToString() : string {
      match this
        case UnterminatedSequence => "Unterminated sequence"
        case UnsupportedEscape(str) => "Unsupported escape sequence: " + str
        case EscapeAtEOS => "Escape character at end of string"
        case EmptyNumber => "Number must contain at least one digit"
        case ExpectingEOF => "Expecting EOF"
        case IntOverflow => "Input length does not fit in a 32-bit counter"
        case ReachedEOF => "Reached EOF"
        case ExpectingByte(b0, b) =>
          var c := if b > 0 then "'" + [b as char] + "'" else "EOF";
          "Expecting '" + [b0 as char] + "', read " + c
        case ExpectingAnyByte(bs0, b) =>
          var c := if b > 0 then "'" + [b as char] + "'" else "EOF";
          var c0s := seq(|bs0|, idx requires 0 <= idx < |bs0| => bs0[idx] as char);
          "Expecting one of '" + c0s + "', read " + c
    }
  }

  datatype SerializationError =
    | OutOfMemory
    | IntTooLarge(i: int)
    | StringTooLong(s: string)
  {
    function ToString() : string {
      match this
        case OutOfMemory => "Out of memory"
        case IntTooLarge(i: int) => "Integer too large: " + Str.OfInt(i)
        case StringTooLong(s: string) => "String too long: " + s
    }
  }

  type SerializationResult<+T> = Wrappers.Result<T, SerializationError>
  type DeserializationResult<+T> = Wrappers.Result<T, DeserializationError>
}
