// Tests for the CSV parser used by the `csv` import command.

///|
/// Render parsed rows compactly so mismatches are easy to read in `inspect`.
fn show_rows(rows : Array[Array[String]]) -> String {
  rows
  .map(fn(row) { "[" + row.map(fn(f) { "<\{f}>" }).join("|") + "]" })
  .join("\n")
}

///|
test "parse_csv: basic rows and empty fields" {
  inspect(
    show_rows(parse_csv("a,b,c\n1,,3")),
    content=(
      #|[<a>|<b>|<c>]
      #|[<1>|<>|<3>]
    ),
  )
}

///|
test "parse_csv: quoted fields with commas, quotes, and newlines" {
  // "a,b"  -> a,b in one field; "a""b" -> a"b; a quoted embedded newline.
  inspect(
    show_rows(parse_csv("\"a,b\",\"a\"\"b\",\"line1\nline2\"")),
    content=(
      #|[<a,b>|<a"b>|<line1
      #|line2>]
    ),
  )
}

///|
test "parse_csv: CRLF endings and trailing newline (no extra row)" {
  inspect(
    show_rows(parse_csv("a,b\r\nc,d\r\n")),
    content=(
      #|[<a>|<b>]
      #|[<c>|<d>]
    ),
  )
}

///|
test "parse_csv: trailing comma yields a trailing empty field" {
  inspect(show_rows(parse_csv("a,")), content="[<a>|<>]")
}

///|
test "parse_csv: empty input yields no rows" {
  inspect(parse_csv("").length(), content="0")
  inspect(parse_csv("\n").length(), content="1")
}

///|
test "parse_csv: leading BOM is stripped" {
  inspect(show_rows(parse_csv("\u{FEFF}a,b")), content="[<a>|<b>]")
}

///|
/// Round-trip property: rows serialized with `csv_field` (the `rows` command's
/// encoder) and re-parsed reproduce the original rows.
test "parse_csv round-trips csv_field output" {
  let originals = [
    ["plain", "with,comma", "with\"quote"],
    ["embedded\nnewline", "", "trailing "],
    ["carriage\rreturn", "crlf\r\ninside", "1"],
  ]
  let encoded = originals
    .map(fn(row) { row.map(csv_field).join(",") })
    .join("\n")
  inspect(show_rows(parse_csv(encoded)) == show_rows(originals), content="true")
}
