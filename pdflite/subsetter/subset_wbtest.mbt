// Ports of the unit tests of the `subsetter` crate (`src/lib.rs`,
// `src/name.rs`, `src/cff/number.rs`, `src/cff/remapper.rs`), plus tests of
// the Rust float formatting and parsing helpers.

///|
fn write_to_bytes(f : (Writer) -> Unit) -> Bytes {
  let w = Writer::new()
  f(w)
  w.finish()
}

///|
test "u24" {
  for num in [0, 45, 345, 54045, 32849324 & 0xFFFFFF, 16777215] {
    let first = write_to_bytes(w => w.write_u24(num))
    let rewritten = Reader::new(first).read_u24().unwrap()
    let second = write_to_bytes(w => w.write_u24(rewritten))
    assert_eq(first, second)
  }
}

///|
fn integer_roundtrip(nums : Array[Int], len : Int) -> Unit raise {
  for num in nums {
    let buffer = write_to_bytes(w => Integer(num).write(w))
    let reparsed = parse_integer(Reader::new(buffer)).unwrap()
    let bytes = write_to_bytes(w => Integer(reparsed).write(w))
    assert_eq(bytes.length(), len)
    assert_eq(reparsed, num)
  }
}

///|
test "size1_roundtrip" {
  integer_roundtrip([0, 1, -1, 93, 107, -107], 1)
}

///|
test "size2_roundtrip" {
  integer_roundtrip(
    [108, -108, 255, -255, 349, -349, 845, -845, 1131, -1131],
    2,
  )
}

///|
test "size3_roundtrip" {
  integer_roundtrip(
    [1132, -1132, 2450, -2450, 4096, -4096, 8965, -8965, 32767, -32768],
    3,
  )
}

///|
test "size5_roundtrip" {
  integer_roundtrip([32768, -32769, 0x7FFFFFFF, -0x80000000], 5)
}

///|
test "parse_float" {
  let num = b"\x1E\xE2\x49\x32\xA1\x2C\x2F"
  let real = parse_real(Reader::new(num)).unwrap()
  assert_eq(real, Float::from_double(-249.3212))
}

///|
test "float_roundtrip" {
  for num in [0.58, -0.21, 3.98, 16.49, 159.18, 5906.2] {
    let float = Float::from_double(num)
    let buffer = write_to_bytes(w => Real(float).write(w))
    let reparsed = parse_real(Reader::new(buffer)).unwrap()
    assert_eq(reparsed, float)
  }
}

///|
test "fixed" {
  let num = b"\xFF\x9A\x68\x78\x28"
  let parsed = parse_fixed(Reader::new(num)).unwrap()
  assert_eq(write_to_bytes(w => Fixed(parsed).write(w)), num)
}

///|
test "test_remap_1" {
  let sid_remapper = SidRemapper::new()
  assert_eq(sid_remapper.remap(b"hi"), 391)
  assert_eq(sid_remapper.remap(b"there"), 392)
  assert_eq(sid_remapper.remap(b"hi"), 391)
  assert_eq(sid_remapper.remap(b"test"), 393)
  assert_eq(sid_remapper.sorted_strings().map(s => s.to_owned()), [
    b"hi", b"there", b"test",
  ])
}

///|
test "parse_respects_storage_offset" {
  let w = Writer::new()
  w.write_u16(0) // version
  w.write_u16(1) // count
  w.write_u16(22) // storageOffset
  w.write_u16(3) // nameRecord[0].platformID
  w.write_u16(1) // nameRecord[0].encodingID
  w.write_u16(0x0409) // nameRecord[0].languageID
  w.write_u16(0) // nameRecord[0].nameID
  w.write_u16(4) // nameRecord[0].length
  w.write_u16(0) // nameRecord[0].stringOffset
  w.write_bytes(b"BAD!") // padding before storageOffset
  w.write_bytes(b"\x00O\x00K") // storage
  let data = w.finish()
  let table = NameTable::parse(data).unwrap()
  let subset = name_subset_table(table).unwrap()
  assert_eq(subset.storage.to_owned(), b"\x00O\x00K")
}

///|
test "table_record_with_invalid_bounds_returns_none" {
  let face = Face::{
    data: b"",
    records: [{ tag: Tag::head(), offset: 0xFFFFFFFFU, length: 0xFFFFFFFFU, }],
  }
  assert_true(face.table(Tag::head()) is None)
}

///|
test "binary search probes like Rust's slice::binary_search_by" {
  let xs = [1, 3, 5, 7, 9]
  assert_eq(binary_search_by(xs, x => x.compare(7)), Ok(3))
  assert_eq(binary_search_by(xs, x => x.compare(4)), Err(2))
  assert_eq(binary_search_by(xs, x => x.compare(10)), Err(5))
  assert_eq(binary_search_by(([] : Array[Int]), x => x.compare(1)), Err(0))
  // Duplicates: the last probed one is found.
  assert_eq(binary_search_by([2, 2, 2, 2], x => x.compare(2)), Ok(3))
}

///|
test "Rust f32 Display" {
  let show = (d : Double) => rust_display_f32(Float::from_double(d))
  inspect(show(0.001), content="0.001")
  inspect(show(1000.0), content="1000")
  inspect(show(-0.0), content="-0")
  inspect(show(0.1), content="0.1")
  inspect(show(1.0e-7), content="0.0000001")
  inspect(
    show(3.4028234663852886e38),
    content="340282350000000000000000000000000000000",
  )
  inspect(show(16777217.0), content="16777216")
  inspect(show(0.039625), content="0.039625")
}

///|
test "Rust f32 parsing" {
  let parse = (s : String) => parse_f32(s).map(f => f.to_double())
  debug_inspect(parse("1"), content="Some(1)")
  debug_inspect(parse("-.5"), content="Some(-0.5)")
  debug_inspect(parse("1."), content="Some(1)")
  debug_inspect(parse("2.5E-1"), content="Some(0.25)")
  debug_inspect(parse("1E39"), content="Some(Infinity)")
  debug_inspect(parse("1E-50"), content="Some(0)")
  // Halfway between two f32s: ties to even.
  debug_inspect(parse("16777217"), content="Some(16777216)")
  debug_inspect(parse("16777219"), content="Some(16777220)")
  // The smallest subnormal and the largest finite value.
  debug_inspect(
    parse("1.401298464324817E-45").map(d => {
      Float::from_double(d).reinterpret_as_uint()
    }),
    content="Some(1)",
  )
  debug_inspect(
    parse("3.4028235E38").map(d => Float::from_double(d).reinterpret_as_uint()),
    content="Some(2139095039)",
  )
  debug_inspect(parse("."), content="None")
  debug_inspect(parse("E5"), content="None")
  debug_inspect(parse("1E"), content="None")
  debug_inspect(parse("1-2"), content="None")
}

///|
test "Tag::from_str takes strings of four UTF-8 bytes" {
  debug_inspect(
    Tag::from_str("wght").map(t => t.get()),
    content=(
      #|Some(<Bytes: [0x77, 0x67, 0x68, 0x74]>)
    ),
  )
  debug_inspect(
    Tag::from_str("éab").map(t => t.get()),
    content=(
      #|Some(<Bytes: [0xc3, 0xa9, 0x61, 0x62]>)
    ),
  )
  inspect(Tag::from_str("wghtx") is None, content="true")
  inspect(Tag::from_str("éabc") is None, content="true")
  debug_inspect(
    Tag::from_str("😀").map(t => t.get()),
    content=(
      #|Some(<Bytes: [0xf0, 0x9f, 0x98, 0x80]>)
    ),
  )
}

///|
test "tags display like Rust" {
  inspect(Tag::from_str("wght").unwrap(), content="wght")
  inspect(Tag::from_str("éab").unwrap(), content="éab")
  inspect(Tag::from_bytes(b"\xff\xfeab").unwrap(), content="...")
  inspect(Tag::from_bytes(b"\xed\xa0\x80a").unwrap(), content="...")
  inspect(Tag::from_bytes(b"\xc0\x80ab").unwrap(), content="...")
}
