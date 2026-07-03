///|
test "utf length and offsets" {
  let s = "A😀中"
  debug_inspect((utf16_len(s), utf8_len(s)), content="(4, 8)")
  let bytes = @encoding/utf8.encode(s)
  inspect(utf8_offset_to_utf16_index(bytes, 0), content="0")
  inspect(utf8_offset_to_utf16_index(bytes, 1), content="1")
  inspect(utf8_offset_to_utf16_index(bytes, 5), content="3")
  inspect(utf8_offset_to_utf16_index(bytes, 8), content="4")
  inspect(utf16_index_to_utf8_offset(s, 0), content="0")
  inspect(utf16_index_to_utf8_offset(s, 1), content="1")
  inspect(utf16_index_to_utf8_offset(s, 3), content="5")
  inspect(utf16_index_to_utf8_offset(s, 4), content="8")

  // 2-byte UTF-8 codepoint (U+00E9).
  debug_inspect((utf16_len("é"), utf8_len("é")), content="(1, 2)")
}

///|
test "utf index errors" {
  let s = "A😀中"
  let bytes = @encoding/utf8.encode(s)
  let bad_offset = try? utf8_offset_to_utf16_index(bytes, 2)
  debug_inspect(bad_offset, content="Err(InvalidUtf8(offset=2))")
  let bad_index = try? utf16_index_to_utf8_offset(s, 2)
  debug_inspect(bad_index, content="Err(InvalidBoundary(index=2))")
  let out_of_range = try? utf16_index_to_utf8_offset(s, 5)
  debug_inspect(out_of_range, content="Err(OutOfRange(index=5, len=4))")
}

///|
test "utf index bounds" {
  let s = "A😀中"
  let bytes = @encoding/utf8.encode(s)
  let negative_offset = try? utf8_offset_to_utf16_index(bytes, -1)
  debug_inspect(negative_offset, content="Err(OutOfRange(index=-1, len=8))")
  let past_end = try? utf8_offset_to_utf16_index(bytes, 9)
  debug_inspect(past_end, content="Err(OutOfRange(index=9, len=8))")
  let negative_index = try? utf16_index_to_utf8_offset(s, -1)
  debug_inspect(negative_index, content="Err(OutOfRange(index=-1, len=4))")
}

///|
test "utf8 offset invalid sequences" {
  let two = Bytes::from_array([(0xC2).to_byte(), (0xA2).to_byte()])
  debug_inspect(
    try? utf8_offset_to_utf16_index(two, 1),
    content="Err(InvalidUtf8(offset=1))",
  )
  let bad_two = Bytes::from_array([(0xC2).to_byte(), (0x00).to_byte()])
  debug_inspect(
    try? utf8_offset_to_utf16_index(bad_two, 2),
    content="Err(InvalidUtf8(offset=2))",
  )
  let bad_three_overlong = Bytes::from_array([
    (0xE0).to_byte(),
    (0x9F).to_byte(),
    (0x80).to_byte(),
  ])
  debug_inspect(
    try? utf8_offset_to_utf16_index(bad_three_overlong, 3),
    content="Err(InvalidUtf8(offset=3))",
  )
  let bad_three_surrogate = Bytes::from_array([
    (0xED).to_byte(),
    (0xA0).to_byte(),
    (0x80).to_byte(),
  ])
  debug_inspect(
    try? utf8_offset_to_utf16_index(bad_three_surrogate, 3),
    content="Err(InvalidUtf8(offset=3))",
  )
  let four = Bytes::from_array([
    (0xF0).to_byte(),
    (0x9F).to_byte(),
    (0x98).to_byte(),
    (0x80).to_byte(),
  ])
  debug_inspect(
    try? utf8_offset_to_utf16_index(four, 2),
    content="Err(InvalidUtf8(offset=2))",
  )
  let bad_four_min = Bytes::from_array([
    (0xF0).to_byte(),
    (0x8F).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
  debug_inspect(
    try? utf8_offset_to_utf16_index(bad_four_min, 4),
    content="Err(InvalidUtf8(offset=4))",
  )
  let bad_four_max = Bytes::from_array([
    (0xF4).to_byte(),
    (0x90).to_byte(),
    (0x80).to_byte(),
    (0x80).to_byte(),
  ])
  debug_inspect(
    try? utf8_offset_to_utf16_index(bad_four_max, 4),
    content="Err(InvalidUtf8(offset=4))",
  )
  let bad_lead = Bytes::from_array([(0x80).to_byte()])
  debug_inspect(
    try? utf8_offset_to_utf16_index(bad_lead, 1),
    content="Err(InvalidUtf8(offset=1))",
  )
}

///|
test "utf8 offset invalid continuation bytes" {
  let bad_three_cont = Bytes::from_array([
    (0xE1).to_byte(),
    (0x28).to_byte(),
    (0x80).to_byte(),
  ])
  debug_inspect(
    try? utf8_offset_to_utf16_index(bad_three_cont, 3),
    content="Err(InvalidUtf8(offset=3))",
  )
  let bad_four_cont = Bytes::from_array([
    (0xF1).to_byte(),
    (0x80).to_byte(),
    (0x28).to_byte(),
    (0x80).to_byte(),
  ])
  debug_inspect(
    try? utf8_offset_to_utf16_index(bad_four_cont, 4),
    content="Err(InvalidUtf8(offset=4))",
  )
}

///|
test "utf8 offset invalid: truncated 3-byte sequence" {
  let euro = Bytes::from_array([
    (0xE2).to_byte(),
    (0x82).to_byte(),
    (0xAC).to_byte(),
  ])
  debug_inspect(
    try? utf8_offset_to_utf16_index(euro, 2),
    content="Err(InvalidUtf8(offset=2))",
  )
}
