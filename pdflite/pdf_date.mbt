///|
pub(all) struct PdfDate {
  year : Int
  month : Int
  day : Int
  hour : Int
  minute : Int
  second : Int
  hour_offset : Int
  minute_offset : Int
} derive(Debug, Eq, ToJson)

///|
fn pdf_date_check(date : PdfDate) -> Unit raise PdfError {
  if date.year < 0 ||
    date.year > 9999 ||
    date.month < 1 ||
    date.month > 12 ||
    date.day < 1 ||
    date.day > 31 ||
    date.hour < 0 ||
    date.hour > 23 ||
    date.minute < 0 ||
    date.minute > 59 ||
    date.second < 0 ||
    date.second > 59 ||
    date.hour_offset < -23 ||
    date.hour_offset > 23 ||
    date.minute_offset < -59 ||
    date.minute_offset > 59 {
    raise BadDate
  }
}

///|
fn pdf_date_abs(value : Int) -> Int {
  if value < 0 {
    -value
  } else {
    value
  }
}

///|
fn pdf_date_pad2(value : Int) -> String {
  if value < 10 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn pdf_date_pad4(value : Int) -> String {
  if value < 10 {
    "000" + value.to_string()
  } else if value < 100 {
    "00" + value.to_string()
  } else if value < 1000 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
pub fn pdf_string_of_date(date : PdfDate) -> String raise PdfError {
  pdf_date_check(date)
  let offset = if date.hour_offset < 0 {
    "-" +
    pdf_date_pad2(pdf_date_abs(date.hour_offset)) +
    "'" +
    pdf_date_pad2(pdf_date_abs(date.minute_offset)) +
    "'"
  } else if date.hour_offset > 0 {
    "+" +
    pdf_date_pad2(pdf_date_abs(date.hour_offset)) +
    "'" +
    pdf_date_pad2(pdf_date_abs(date.minute_offset)) +
    "'"
  } else {
    "Z"
  }
  "D:" +
  pdf_date_pad4(date.year) +
  pdf_date_pad2(date.month) +
  pdf_date_pad2(date.day) +
  pdf_date_pad2(date.hour) +
  pdf_date_pad2(date.minute) +
  pdf_date_pad2(date.second) +
  offset
}

///|
fn pdf_date_digit(byte : Byte) -> Int? {
  let value = byte.to_int()
  if value >= 48 && value <= 57 {
    Some(value - 48)
  } else {
    None
  }
}

///|
fn pdf_date_two_digits(bytes : BytesView, index : Int) -> Int raise PdfError {
  if index + 1 >= bytes.length() {
    raise BadDate
  }
  match (pdf_date_digit(bytes[index]), pdf_date_digit(bytes[index + 1])) {
    (Some(first), Some(second)) => first * 10 + second
    _ => raise BadDate
  }
}

///|
fn pdf_date_four_digits(bytes : BytesView, index : Int) -> Int raise PdfError {
  if index + 3 >= bytes.length() {
    raise BadDate
  }
  match
    (
      pdf_date_digit(bytes[index]),
      pdf_date_digit(bytes[index + 1]),
      pdf_date_digit(bytes[index + 2]),
      pdf_date_digit(bytes[index + 3]),
    ) {
    (Some(a), Some(b), Some(c), Some(d)) => ((a * 10 + b) * 10 + c) * 10 + d
    _ => raise BadDate
  }
}

///|
fn pdf_date_is_local_time_start(byte : Byte) -> Bool {
  let value = byte.to_int()
  value == 43 || value == 45 || value == 90
}

///|
fn pdf_date_parse_optional_two(
  bytes : BytesView,
  index : Int,
  default : Int,
  hour_offset : Ref[Int],
  minute_offset : Ref[Int],
  offset_sign : Ref[Int],
) -> (Int, Int) raise PdfError {
  if index >= bytes.length() {
    (default, bytes.length())
  } else if pdf_date_is_local_time_start(bytes[index]) {
    pdf_date_parse_local_time(
      bytes, index, hour_offset, minute_offset, offset_sign,
    )
    (default, bytes.length())
  } else if index + 1 < bytes.length() {
    (pdf_date_two_digits(bytes, index), index + 2)
  } else {
    (default, bytes.length())
  }
}

///|
fn pdf_date_parse_local_time(
  bytes : BytesView,
  index : Int,
  hour_offset : Ref[Int],
  minute_offset : Ref[Int],
  offset_sign : Ref[Int],
) -> Unit raise PdfError {
  if index < bytes.length() {
    let (sign, offset_index) = match bytes[index].to_int() {
      43 => (1, index + 1)
      45 => (-1, index + 1)
      90 => (0, index + 1)
      _ => (0, bytes.length())
    }
    let (hour, next_index) = pdf_date_parse_optional_two(
      bytes, offset_index, 0, hour_offset, minute_offset, offset_sign,
    )
    if next_index < bytes.length() {
      let (minute, _) = pdf_date_parse_optional_two(
        bytes,
        next_index + 1,
        0,
        hour_offset,
        minute_offset,
        offset_sign,
      )
      hour_offset.val = hour
      minute_offset.val = minute
      offset_sign.val = sign
    }
  }
}

///|
fn pdf_date_has_distiller_y2k_bug(bytes : BytesView, index : Int) -> Bool {
  index + 4 < bytes.length() &&
  bytes[index].to_int() == 49 &&
  bytes[index + 1].to_int() == 57 &&
  bytes[index + 2].to_int() == 49 &&
  bytes[index + 3].to_int() == 48 &&
  bytes[index + 4].to_int() == 48
}

///|
pub fn pdf_date_of_view(bytes : BytesView) -> PdfDate raise PdfError {
  let mut index = if bytes.length() >= 2 &&
    bytes[0].to_int() == 68 &&
    bytes[1].to_int() == 58 {
    2
  } else {
    0
  }
  let year = if pdf_date_has_distiller_y2k_bug(bytes, index) {
    index += 5
    2000
  } else {
    let value = pdf_date_four_digits(bytes, index)
    index += 4
    value
  }
  let hour_offset : Ref[Int] = { val: 0 }
  let minute_offset : Ref[Int] = { val: 0 }
  let offset_sign : Ref[Int] = { val: 0 }
  let (month, next_index) = pdf_date_parse_optional_two(
    bytes, index, 1, hour_offset, minute_offset, offset_sign,
  )
  index = next_index
  let (day, next_index) = pdf_date_parse_optional_two(
    bytes, index, 1, hour_offset, minute_offset, offset_sign,
  )
  index = next_index
  let (hour, next_index) = pdf_date_parse_optional_two(
    bytes, index, 0, hour_offset, minute_offset, offset_sign,
  )
  index = next_index
  let (minute, next_index) = pdf_date_parse_optional_two(
    bytes, index, 0, hour_offset, minute_offset, offset_sign,
  )
  index = next_index
  let (second, next_index) = pdf_date_parse_optional_two(
    bytes, index, 0, hour_offset, minute_offset, offset_sign,
  )
  pdf_date_parse_local_time(
    bytes, next_index, hour_offset, minute_offset, offset_sign,
  )
  let date = {
    year,
    month,
    day,
    hour,
    minute,
    second,
    hour_offset: hour_offset.val * offset_sign.val,
    minute_offset: minute_offset.val * offset_sign.val,
  }
  pdf_date_check(date)
  date
}

///|
pub fn pdf_date_of_bytes(bytes : PdfBytes) -> PdfDate raise PdfError {
  pdf_date_of_view(bytes[:])
}

///|
pub fn pdf_date_of_string(text : String) -> PdfDate raise PdfError {
  let bytes = @ascii.encode(text)
  pdf_date_of_view(bytes[:])
}

///|
pub fn pdf_bytes_of_date(date : PdfDate) -> PdfBytes raise PdfError {
  let text = pdf_string_of_date(date)
  @ascii.encode(text)
}
