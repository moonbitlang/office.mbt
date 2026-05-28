///|
fn pdf_tweak_is_digit_byte(byte : Byte) -> Bool {
  byte >= 48 && byte <= 57
}

///|
fn pdf_tweak_parse_digits(
  bytes : BytesView,
  start : Int,
  finish : Int,
  source : String,
) -> Int raise PdfError {
  if start >= finish {
    raise BadPageSpecification(source)
  }
  let mut value = 0
  for index in start..<finish {
    value = value * 10 + bytes[index].to_int() - 48
  }
  value
}

///|
fn pdf_tweak_digit_end(bytes : BytesView, start : Int) -> Int {
  let mut index = start
  while index < bytes.length() && pdf_tweak_is_digit_byte(bytes[index]) {
    index += 1
  }
  index
}

///|
fn pdf_tweak_split_chain(bytes : BytesView, start : Int) -> Array[PdfName] {
  let output : Array[PdfName] = []
  let mut index = start
  while index < bytes.length() {
    if bytes[index].to_int() == 47 {
      let segment_start = index
      index += 1
      while index < bytes.length() && bytes[index].to_int() != 47 {
        index += 1
      }
      output.push(pdf_name_of_bytes(bytes[segment_start:index].to_owned()))
    } else {
      index = bytes.length()
    }
  }
  output
}

///|
fn pdf_tweak_number_spec(spec : String) -> Int raise PdfError {
  let bytes = @ascii.encode(spec)
  if bytes.length() == 0 {
    raise BadPageSpecification(spec)
  }
  let digit_end = pdf_tweak_digit_end(bytes, 0)
  if digit_end != bytes.length() {
    raise BadPageSpecification(spec)
  }
  pdf_tweak_parse_digits(bytes, 0, digit_end, spec)
}
