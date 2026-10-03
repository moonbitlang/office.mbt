// Port of read-fonts 0.39.2 `src/ps/error.rs`.

///|
using @font_types {type GlyphId, type Fixed, type FontMatrix}

///|
/// Errors that are specific to PostScript processing.
pub(all) suberror PsError {
  InvalidFontFormat
  InvalidIndexOffsetSize(Int)
  ZeroOffsetInIndex
  InvalidVariationStoreIndex(Int)
  StackOverflow
  StackUnderflow
  InvalidStackAccess(Int)
  ExpectedI32StackEntry(Int)
  InvalidNumber
  InvalidDictOperator(Int)
  InvalidCharstringOperator(Int)
  CharstringNestingDepthLimitExceeded
  MissingSubroutines
  MissingBlendState
  MissingFdArray
  MissingPrivateDict
  MissingCharstrings
  MissingCharset
  InvalidSeacCode(Int)
  Read(@read_fonts.ReadError)
}

///|
pub impl Show for PsError with fn output(self, f) {
  match self {
    InvalidFontFormat => f.write_string("invalid font format")
    InvalidIndexOffsetSize(size) =>
      f.write_string("invalid offset size of \{size} for INDEX (expected 1-4)")
    ZeroOffsetInIndex =>
      f.write_string("invalid offset of 0 in INDEX (must be >= 1)")
    InvalidVariationStoreIndex(index) =>
      f.write_string(
        "variation store index \{index} referenced an invalid variation region",
      )
    StackOverflow => f.write_string("attempted to push a value to a full stack")
    StackUnderflow =>
      f.write_string("attempted to pop a value from an empty stack")
    InvalidStackAccess(index) =>
      f.write_string("invalid stack access for index \{index}")
    ExpectedI32StackEntry(index) =>
      f.write_string(
        "attempted to read an integer at stack index \{index}, but found a fixed point value",
      )
    InvalidNumber => f.write_string("number is in an invalid format")
    InvalidDictOperator(operator) =>
      f.write_string("dictionary operator \{operator} is invalid")
    InvalidCharstringOperator(operator) =>
      f.write_string("charstring operator \{operator} is invalid")
    CharstringNestingDepthLimitExceeded =>
      f.write_string(
        "exceeded subroutine nesting depth limit 10 while evaluating a charstring",
      )
    MissingSubroutines =>
      f.write_string(
        "encountered a callsubr operator but no subroutine index was provided",
      )
    MissingBlendState =>
      f.write_string(
        "encountered a blend operator but no blend state was provided",
      )
    MissingFdArray =>
      f.write_string("CFF table does not contain a font dictionary index")
    MissingPrivateDict =>
      f.write_string("CFF table does not contain a private dictionary")
    MissingCharstrings =>
      f.write_string("CFF table does not contain a charstrings index")
    MissingCharset =>
      f.write_string("CFF table does not contain a valid charset")
    InvalidSeacCode(code) => f.write_string("seac code \{code} is not valid")
    Read(err) => f.write_string(err.to_string())
  }
}

///|
fn oob() -> PsError {
  Read(@read_fonts.ReadError::OutOfBounds)
}
