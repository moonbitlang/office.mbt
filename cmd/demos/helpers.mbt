///|
fn parse_int(s : StringView) -> Int? {
  let text = s.to_string().trim()
  if text == "" {
    return None
  }
  let mut first = true
  let mut neg = false
  let mut seen_digit = false
  let mut value = 0
  for ch in text {
    if first {
      first = false
      if ch == '-' {
        neg = true
        continue
      }
      if ch == '+' {
        continue
      }
    }
    if ch < '0' || ch > '9' {
      return None
    }
    seen_digit = true
    value = value * 10 + (ch.to_int() - '0'.to_int())
  }
  if !seen_digit {
    return None
  }
  Some(if neg { -value } else { value })
}

///|
fn demo_stream_big_rows_from_args(args : ArrayView[String]) -> Int {
  match args {
    [] => 20000
    [value, ..] =>
      match parse_int(value) {
        Some(v) if v > 0 => v
        _ => 20000
      }
  }
}
