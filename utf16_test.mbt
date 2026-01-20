///|
test "utf length and offsets" {
  let s = "A😀中"
  inspect((utf16_len(s), utf8_len(s)), content="(4, 8)")
  let bytes = @encoding/utf8.encode(s)
  inspect(utf8_offset_to_utf16_index(bytes, 0), content="0")
  inspect(utf8_offset_to_utf16_index(bytes, 1), content="1")
  inspect(utf8_offset_to_utf16_index(bytes, 5), content="3")
  inspect(utf8_offset_to_utf16_index(bytes, 8), content="4")
  inspect(utf16_index_to_utf8_offset(s, 0), content="0")
  inspect(utf16_index_to_utf8_offset(s, 1), content="1")
  inspect(utf16_index_to_utf8_offset(s, 3), content="5")
  inspect(utf16_index_to_utf8_offset(s, 4), content="8")
}

///|
test "utf index errors" {
  let s = "A😀中"
  let bytes = @encoding/utf8.encode(s)
  let bad_offset = try? utf8_offset_to_utf16_index(bytes, 2)
  inspect(bad_offset, content="Err(InvalidUtf8(offset=2))")
  let bad_index = try? utf16_index_to_utf8_offset(s, 2)
  inspect(bad_index, content="Err(InvalidBoundary(index=2))")
  let out_of_range = try? utf16_index_to_utf8_offset(s, 5)
  inspect(out_of_range, content="Err(OutOfRange(index=5, len=4))")
}

///|
test "utf index bounds" {
  let s = "A😀中"
  let bytes = @encoding/utf8.encode(s)
  let negative_offset = try? utf8_offset_to_utf16_index(bytes, -1)
  inspect(negative_offset, content="Err(OutOfRange(index=-1, len=8))")
  let past_end = try? utf8_offset_to_utf16_index(bytes, 9)
  inspect(past_end, content="Err(OutOfRange(index=9, len=8))")
  let negative_index = try? utf16_index_to_utf8_offset(s, -1)
  inspect(negative_index, content="Err(OutOfRange(index=-1, len=4))")
}
