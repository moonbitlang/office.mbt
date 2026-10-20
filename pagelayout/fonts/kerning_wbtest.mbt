///|
fn kern_sfnt(table : Bytes) -> Bytes {
  // A directory containing only kern: outline and metric parsing is unrelated
  // to the table reader exercised here.
  b"\x00\x01\x00\x00\x00\x01\x00\x10\x00\x00\x00\x00kern\x00\x00\x00\x00\x00\x00\x00\x1c" +
  Bytes::makei(4, index => {
    ((table.length() >> ((3 - index) * 8)) & 255).to_byte()
  }) +
  table
}

///|
test "horizontal kerning reads signed pairs and skips Apple version-one tables" {
  let table = b"\x00\x00\x00\x01\x00\x00\x00\x1a\x00\x01\x00\x02\x00\x0c\x00\x01\x00\x00\x00\x01\x00\x02\xff\x9c\x00\x02\x00\x01\xff\xce"
  let pairs = parse_legacy_kerning(kern_sfnt(table))
  debug_inspect(pairs.get((1, 2)), content="Some(-100)")
  debug_inspect(pairs.get((2, 1)), content="Some(-50)")
  inspect(
    parse_legacy_kerning(kern_sfnt(b"\x00\x01\x00\x00")).length(),
    content="0",
  )
}

///|
test "a truncated kerning pair list fails within the enclosing table" {
  let table = b"\x00\x00\x00\x01\x00\x00\x00\x0e\x00\x01\x00\x02\x00\x0c\x00\x01\x00\x00"
  try parse_legacy_kerning(kern_sfnt(table)) catch {
    error =>
      assert_true(
        error.to_string().contains("truncated TrueType kerning pairs"),
      )
  } noraise {
    _ => fail("a pair count outside the subtable must be rejected")
  }
}
