///|
fn pdf_bookmark_import_is_whitespace(value : Int) -> Bool {
  pdf_is_whitespace_byte(value)
}

///|
fn pdf_bookmark_import_trim_line_end(line : BytesView) -> BytesView {
  let mut end = line.length()
  while end > 0 {
    let value = line[end - 1].to_int()
    if value == 10 || value == 13 {
      end -= 1
    } else {
      break
    }
  }
  line[:end]
}

///|
fn pdf_bookmark_import_skip_whitespace(
  line : BytesView,
  index : Ref[Int],
) -> Unit {
  while index.val < line.length() &&
        pdf_bookmark_import_is_whitespace(line[index.val].to_int()) {
    index.val += 1
  }
}

///|
fn pdf_bookmark_import_parse_int(line : BytesView, index : Ref[Int]) -> Int? {
  pdf_bookmark_import_skip_whitespace(line, index)
  let start = index.val
  let mut negative = false
  if index.val < line.length() {
    match line[index.val].to_int() {
      43 => index.val += 1
      45 => {
        negative = true
        index.val += 1
      }
      _ => ()
    }
  }
  let digits_start = index.val
  let mut value : Int64 = 0L
  let limit : Int64 = if negative { 2147483648L } else { 2147483647L }
  while index.val < line.length() {
    let digit = line[index.val].to_int()
    if digit < 48 || digit > 57 {
      break
    }
    value = value * 10L + (digit - 48).to_int64()
    if value > limit {
      index.val = start
      return None
    }
    index.val += 1
  }
  if index.val == digits_start {
    index.val = start
    None
  } else if negative {
    Some((0L - value).to_int())
  } else {
    Some(value.to_int())
  }
}
