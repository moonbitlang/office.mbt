///|
/// Return whether a byte is PDF white space.
///
/// Recognized values are NUL, horizontal tab, line feed, form feed, carriage
/// return, and space.
pub fn pdf_is_whitespace_byte(value : Int) -> Bool {
  match value {
    0 | 9 | 10 | 12 | 13 | 32 => true
    _ => false
  }
}

///|
/// Return whether a byte is a PDF line break byte.
pub fn pdf_is_newline_byte(value : Int) -> Bool {
  value == 10 || value == 13
}

///|
/// Return whether a byte is not PDF white space.
pub fn pdf_is_not_whitespace_byte(value : Int) -> Bool {
  !pdf_is_whitespace_byte(value)
}

///|
/// Return whether a byte is an ASCII digit.
pub fn pdf_is_digit_byte(value : Int) -> Bool {
  value >= 48 && value <= 57
}

///|
/// Return whether a byte is a PDF token delimiter.
///
/// Delimiters are parentheses, slash, angle brackets, square brackets, braces,
/// and percent.
pub fn pdf_is_delimiter_byte(value : Int) -> Bool {
  match value {
    40 | 41 | 47 | 60 | 62 | 91 | 93 | 123 | 125 | 37 => true
    _ => false
  }
}

///|
/// Return whether a byte terminates a regular PDF token.
pub fn pdf_is_whitespace_or_delimiter_byte(value : Int) -> Bool {
  pdf_is_whitespace_byte(value) || pdf_is_delimiter_byte(value)
}
