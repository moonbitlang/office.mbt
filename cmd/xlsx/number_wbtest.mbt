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
