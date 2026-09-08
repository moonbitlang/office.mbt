///|
fn pdf_coord_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_coord_is_digit(value : Int) -> Bool {
  value >= 48 && value <= 57
}

///|
fn pdf_coord_is_number_start(value : Int) -> Bool {
  pdf_coord_is_digit(value) || value == 43 || value == 45 || value == 46
}

///|
fn pdf_coord_is_word_boundary(value : Int) -> Bool {
  @core.pdf_is_whitespace_byte(value)
}

///|
fn pdf_coord_is_unit_pair(first : Int, second : Int) -> Bool {
  (first == 109 && second == 109) ||
  (first == 99 && second == 109) ||
  (first == 105 && second == 110) ||
  (first == 112 && second == 116)
}

///|
fn pdf_coord_spaced_units_length(bytes : BytesView) -> Int {
  let mut length = 0
  let mut index = 0
  while index < bytes.length() {
    if index + 1 < bytes.length() &&
      pdf_coord_is_unit_pair(bytes[index].to_int(), bytes[index + 1].to_int()) {
      length += 4
      index += 2
    } else {
      length += 1
      index += 1
    }
  }
  length
}

///|
fn pdf_coord_space_units(text : String) -> String {
  let bytes = @utf8.encode(text)
  let output = Array::make(pdf_coord_spaced_units_length(bytes), b'\x00')
  let mut index = 0
  let mut position = 0
  while index < bytes.length() {
    if index + 1 < bytes.length() &&
      pdf_coord_is_unit_pair(bytes[index].to_int(), bytes[index + 1].to_int()) {
      output[position] = b' '
      output[position + 1] = bytes[index]
      output[position + 2] = bytes[index + 1]
      output[position + 3] = b' '
      position += 4
      index += 2
    } else {
      output[position] = bytes[index]
      position += 1
      index += 1
    }
  }
  @utf8.decode_lossy(Bytes::from_array(output))
}

///|
fn pdf_coord_number_end(bytes : BytesView, start : Int) -> Int {
  let mut index = start
  if index < bytes.length() &&
    (bytes[index].to_int() == 43 || bytes[index].to_int() == 45) {
    index += 1
  }
  while index < bytes.length() && pdf_coord_is_digit(bytes[index].to_int()) {
    index += 1
  }
  if index < bytes.length() && bytes[index].to_int() == 46 {
    index += 1
    while index < bytes.length() && pdf_coord_is_digit(bytes[index].to_int()) {
      index += 1
    }
  }
  if index < bytes.length() &&
    (bytes[index].to_int() == 69 || bytes[index].to_int() == 101) {
    let exponent_start = index
    index += 1
    if index < bytes.length() &&
      (bytes[index].to_int() == 43 || bytes[index].to_int() == 45) {
      index += 1
    }
    let digits_start = index
    while index < bytes.length() && pdf_coord_is_digit(bytes[index].to_int()) {
      index += 1
    }
    if index == digits_start {
      exponent_start
    } else {
      index
    }
  } else {
    index
  }
}

///|
fn pdf_coord_tokenize(text : String) -> Array[PdfCoordToken] {
  let bytes = @utf8.encode(pdf_coord_space_units(text))
  let tokens : Array[PdfCoordToken] = Array::new(capacity=bytes.length())
  let mut index = 0
  while index < bytes.length() {
    let value = bytes[index].to_int()
    if @core.pdf_is_whitespace_byte(value) {
      index += 1
    } else if pdf_coord_is_number_start(value) {
      let end = pdf_coord_number_end(bytes, index)
      if end > index {
        let number_text = @ascii.decode_lossy(bytes[index:end])
        let parsed : Result[Double, Error] = try
          @strconv.from_str(number_text)
        catch {
          err => Err(err)
        } noraise {
          value => Ok(value)
        }
        match parsed {
          Ok(number) => {
            tokens.push(CoordNumber(number))
            index = end
          }
          Err(_) => {
            tokens.push(CoordWord(number_text))
            index = end
          }
        }
      } else {
        tokens.push(CoordWord(@ascii.decode_lossy(bytes[index:index + 1])))
        index += 1
      }
    } else {
      let start = index
      while index < bytes.length() &&
            !pdf_coord_is_word_boundary(bytes[index].to_int()) {
        index += 1
      }
      tokens.push(CoordWord(@ascii.decode_lossy(bytes[start:index])))
    }
  }
  tokens
}
