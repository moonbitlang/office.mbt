// Numeric detection for cell values, so `set`/`csv` store numbers as real
// numeric cells (making formulas evaluate and number formats render in Excel)
// while leaving anything ambiguous as text.

///|
enum CellKind {
  AsInt(Int)
  AsFloat(Double)
  AsText
}

///|
/// Whether `s` is a plain, canonical number: an optional leading `-`, an
/// integer part with no redundant leading zero (`0`, or `1`-`9` then digits),
/// and an optional `.` followed by at least one digit. This deliberately
/// rejects things a spreadsheet should keep as text — leading zeros (`007`),
/// a leading `+`, exponent forms (`1e3`), thousands separators, and
/// whitespace — so identifiers that merely look numeric aren't coerced.
fn is_plain_number(s : String) -> Bool {
  let chars = []
  for c in s {
    chars.push(c)
  }
  let n = chars.length()
  let mut i = 0
  if i < n && chars[i] == '-' {
    i = i + 1
  }
  // Integer part.
  if i >= n {
    return false
  }
  if chars[i] == '0' {
    i = i + 1
  } else if chars[i] >= '1' && chars[i] <= '9' {
    i = i + 1
    while i < n && chars[i] >= '0' && chars[i] <= '9' {
      i = i + 1
    }
  } else {
    return false
  }
  // Optional fractional part.
  if i < n && chars[i] == '.' {
    i = i + 1
    let frac_start = i
    while i < n && chars[i] >= '0' && chars[i] <= '9' {
      i = i + 1
    }
    if i == frac_start {
      return false
    }
  }
  i == n
}

///|
/// Classify a raw cell string as an integer, a float, or text. A value is only
/// treated as a number when it is a plain canonical number (`is_plain_number`);
/// an integer that round-trips exactly through `Int` is an `AsInt`, a larger or
/// fractional number is an `AsFloat`, and everything else stays text.
fn classify_cell_value(raw : String) -> CellKind {
  if !is_plain_number(raw) {
    return AsText
  }
  // Canonical integer that fits in `Int` (round-trip rejects overflow, where
  // parsing would fail or wrap).
  let as_int = Some(@string.parse_int(raw)) catch { _ => None }
  match as_int {
    Some(value) => if value.to_string() == raw { return AsInt(value) }
    None => ()
  }
  match (Some(@string.parse_double(raw)) catch { _ => None }) {
    Some(value) => AsFloat(value)
    None => AsText
  }
}

// Tests for numeric cell-value detection.

///|
/// Render a `CellKind` compactly for assertions (exhaustive match — a new
/// variant would fail to compile here rather than silently pass).
fn kind_str(kind : CellKind) -> String {
  match kind {
    AsInt(value) => "int:\{value}"
    AsFloat(value) => "float:\{value}"
    AsText => "text"
  }
}

///|
test "classify_cell_value: integers" {
  inspect(kind_str(classify_cell_value("42")), content="int:42")
  inspect(kind_str(classify_cell_value("0")), content="int:0")
  inspect(kind_str(classify_cell_value("-5")), content="int:-5")
  inspect(kind_str(classify_cell_value("1000000")), content="int:1000000")
}

///|
test "classify_cell_value: floats" {
  inspect(kind_str(classify_cell_value("9.99")), content="float:9.99")
  inspect(kind_str(classify_cell_value("-3.5")), content="float:-3.5")
  inspect(kind_str(classify_cell_value("0.5")), content="float:0.5")
  // An integer too large for Int becomes a float rather than text.
  inspect(
    kind_str(classify_cell_value("3000000000")),
    content="float:3000000000",
  )
}

///|
test "classify_cell_value: kept as text" {
  // Leading zero (zip codes, ids), leading '+', exponent, separators, and
  // non-numeric strings must all stay text.
  inspect(kind_str(classify_cell_value("007")), content="text")
  inspect(kind_str(classify_cell_value("+5")), content="text")
  inspect(kind_str(classify_cell_value("1e3")), content="text")
  inspect(kind_str(classify_cell_value("1,000")), content="text")
  inspect(kind_str(classify_cell_value("")), content="text")
  inspect(kind_str(classify_cell_value("9.99.9")), content="text")
  inspect(kind_str(classify_cell_value("9.")), content="text")
  inspect(kind_str(classify_cell_value("-")), content="text")
  inspect(kind_str(classify_cell_value("Widget")), content="text")
  inspect(kind_str(classify_cell_value("  10")), content="text")
}
