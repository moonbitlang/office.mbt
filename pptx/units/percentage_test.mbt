///|
test "Percentage round trip via OOXML integer" {
  let p = @units.Percentage(50.0)
  debug_inspect(p.to_ooxml(), content="50000")
  debug_inspect(@units.Percentage::from_ooxml(50_000).value(), content="50")
}

///|
test "Percentage scale and constants" {
  debug_inspect(@units.ooxml_per_percent, content="1000")
  debug_inspect(@units.Percentage(0.0).to_ooxml(), content="0")
  debug_inspect(@units.Percentage(100.0).to_ooxml(), content="100000")
  debug_inspect(@units.Percentage(0.5).to_ooxml(), content="500")
}

///|
test "Percentage can be negative (e.g. tint -10%)" {
  debug_inspect(@units.Percentage(-10.0).to_ooxml(), content="-10000")
}
