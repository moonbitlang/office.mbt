///|
test "Angle round trip via OOXML integer" {
  let a = @units.Angle(90.0)
  debug_inspect(a.to_ooxml(), content="5400000")
  debug_inspect(@units.Angle::from_ooxml(5_400_000).degrees(), content="90")
}

///|
test "Angle scale and constants" {
  debug_inspect(@units.ooxml_per_degree, content="60000")
  debug_inspect(@units.Angle(0.0).to_ooxml(), content="0")
  debug_inspect(@units.Angle(360.0).to_ooxml(), content="21600000")
  debug_inspect(@units.Angle(45.0).to_ooxml(), content="2700000")
}

///|
test "Angle can be negative (counter-clockwise)" {
  debug_inspect(@units.Angle(-90.0).to_ooxml(), content="-5400000")
}
