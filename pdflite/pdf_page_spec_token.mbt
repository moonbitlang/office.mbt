///|
fn pdf_pagespec_is_digit(value : Int) -> Bool {
  value >= 48 && value <= 57
}

///|
fn pdf_pagespec_is_separator(value : Int) -> Bool {
  value == 45 || value == 44 || pdf_is_whitespace_byte(value)
}

///|
fn pdf_pagespec_parse_nonnegative_int(text : String) -> Int? {
  if text.length() == 0 {
    None
  } else {
    let mut valid = true
    for char in text {
      let value = char.to_int()
      if !pdf_pagespec_is_digit(value) {
        valid = false
      }
    }
    if !valid {
      None
    } else {
      let parsed : Result[Int, Error] = try? @strconv.from_str(text)
      match parsed {
        Ok(value) if value >= 0 => Some(value)
        _ => None
      }
    }
  }
}

///|
fn pdf_pagespec_token_of_view(
  view : BytesView,
  context : PdfPageSpecContext,
) -> PdfPageSpecToken raise PdfError {
  let text = @ascii.decode_lossy(view)
  match pdf_pagespec_parse_nonnegative_int(text) {
    Some(value) => PageSpecNumber(value)
    None =>
      if text.length() == 0 {
        context.bad()
        PageSpecWord("")
      } else {
        PageSpecWord(text)
      }
  }
}

///|
fn pdf_pagespec_tokenize(
  text : String,
  context : PdfPageSpecContext,
) -> Array[PdfPageSpecToken] raise PdfError {
  let bytes = @utf8.encode(text)
  let tokens : Array[PdfPageSpecToken] = Array::new(capacity=bytes.length())
  let mut index = 0
  while index < bytes.length() {
    let value = bytes[index].to_int()
    if pdf_is_whitespace_byte(value) {
      index += 1
    } else if value == 45 {
      tokens.push(PageSpecDash)
      index += 1
    } else if value == 44 {
      tokens.push(PageSpecComma)
      index += 1
    } else {
      let start = index
      while index < bytes.length() &&
            !pdf_pagespec_is_separator(bytes[index].to_int()) {
        index += 1
      }
      tokens.push(pdf_pagespec_token_of_view(bytes[start:index], context))
    }
  }
  tokens
}
