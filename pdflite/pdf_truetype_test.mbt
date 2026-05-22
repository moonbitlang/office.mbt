///|
fn truetype_bytes_for_test(values : Array[Int]) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for value in values {
    output.push(value.to_byte())
  }
  Bytes::from_array(output)
}

///|
fn truetype_push_u16_for_test(output : Array[Int], value : Int) -> Unit {
  output.push((value >> 8) & 0xFF)
  output.push(value & 0xFF)
}

///|
fn truetype_push_u32_for_test(output : Array[Int], value : Int) -> Unit {
  output.push((value >> 24) & 0xFF)
  output.push((value >> 16) & 0xFF)
  output.push((value >> 8) & 0xFF)
  output.push(value & 0xFF)
}

///|
fn truetype_push_i16_for_test(output : Array[Int], value : Int) -> Unit {
  let mut normalized = value % 0x10000
  if normalized < 0 {
    normalized += 0x10000
  }
  truetype_push_u16_for_test(output, normalized)
}

///|
fn truetype_push_tag_for_test(output : Array[Int], tag : String) -> Unit {
  let bytes = @ascii.encode(tag)
  for index in 0..<4 {
    output.push(if index < bytes.length() { bytes[index].to_int() } else { 32 })
  }
}

///|
fn truetype_append_for_test(
  output : Array[Int],
  values : ArrayView[Int],
) -> Unit {
  for value in values {
    output.push(value)
  }
}

///|
fn truetype_table_font_for_test(
  tables : ArrayView[(String, Array[Int])],
) -> @pdflite.PdfBytes {
  let table_data_offset = 12 + tables.length() * 16
  let output : Array[Int] = []
  truetype_push_u32_for_test(output, 0x00010000)
  truetype_push_u16_for_test(output, tables.length())
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 0)
  let mut table_offset = table_data_offset
  for record in tables {
    let (tag, data) = record
    truetype_push_tag_for_test(output, tag)
    truetype_push_u32_for_test(output, 0x10000000 + data.length())
    truetype_push_u32_for_test(output, table_offset)
    truetype_push_u32_for_test(output, data.length())
    table_offset += data.length()
  }
  for record in tables {
    let (_, data) = record
    truetype_append_for_test(output, data)
  }
  truetype_bytes_for_test(output)
}

///|
fn truetype_cmap_font_for_test(
  subtables : ArrayView[(Int, Int, Array[Int])],
) -> @pdflite.PdfBytes {
  let cmap_offset = 28
  let cmap_header_length = 4 + subtables.length() * 8
  let cmap : Array[Int] = []
  truetype_push_u16_for_test(cmap, 0)
  truetype_push_u16_for_test(cmap, subtables.length())
  let mut subtable_offset = cmap_header_length
  for record in subtables {
    let (platform_id, encoding_id, subtable) = record
    truetype_push_u16_for_test(cmap, platform_id)
    truetype_push_u16_for_test(cmap, encoding_id)
    truetype_push_u32_for_test(cmap, subtable_offset)
    subtable_offset += subtable.length()
  }
  for record in subtables {
    let (_, _, subtable) = record
    truetype_append_for_test(cmap, subtable)
  }

  let output : Array[Int] = []
  truetype_push_u32_for_test(output, 0x00010000)
  truetype_push_u16_for_test(output, 1)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 0)
  truetype_append_for_test(output, [0x63, 0x6D, 0x61, 0x70])
  truetype_push_u32_for_test(output, 0)
  truetype_push_u32_for_test(output, cmap_offset)
  truetype_push_u32_for_test(output, cmap.length())
  truetype_append_for_test(output, cmap)
  truetype_bytes_for_test(output)
}

///|
fn truetype_format6_subtable_for_test(
  first_code : Int,
  glyphs : ArrayView[Int],
) -> Array[Int] {
  let output : Array[Int] = []
  truetype_push_u16_for_test(output, 6)
  truetype_push_u16_for_test(output, 10 + glyphs.length() * 2)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, first_code)
  truetype_push_u16_for_test(output, glyphs.length())
  for glyph in glyphs {
    truetype_push_u16_for_test(output, glyph)
  }
  output
}

///|
fn truetype_format0_subtable_for_test(
  codepoint : Int,
  glyph : Int,
) -> Array[Int] {
  let output : Array[Int] = []
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 262)
  truetype_push_u16_for_test(output, 0)
  for index in 0..<256 {
    output.push(if index == codepoint { glyph } else { 0 })
  }
  output
}

///|
fn truetype_format4_range_offset_subtable_for_test() -> Array[Int] {
  let output : Array[Int] = []
  truetype_push_u16_for_test(output, 4)
  truetype_push_u16_for_test(output, 36)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 4)
  truetype_push_u16_for_test(output, 4)
  truetype_push_u16_for_test(output, 1)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 71)
  truetype_push_u16_for_test(output, 0xFFFF)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 70)
  truetype_push_u16_for_test(output, 0xFFFF)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 1)
  truetype_push_u16_for_test(output, 4)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 15)
  truetype_push_u16_for_test(output, 16)
  output
}

///|
fn truetype_head_table_for_test(
  units_per_em : Int,
  minx : Int,
  miny : Int,
  maxx : Int,
  maxy : Int,
  index_to_loc_format : Int,
) -> Array[Int] {
  let output : Array[Int] = []
  truetype_push_u32_for_test(output, 0x00010000)
  truetype_push_u32_for_test(output, 0)
  truetype_push_u32_for_test(output, 0)
  truetype_push_u32_for_test(output, 0)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, units_per_em)
  for _ in 0..<16 {
    output.push(0)
  }
  truetype_push_i16_for_test(output, minx)
  truetype_push_i16_for_test(output, miny)
  truetype_push_i16_for_test(output, maxx)
  truetype_push_i16_for_test(output, maxy)
  truetype_push_u16_for_test(output, 0)
  truetype_push_u16_for_test(output, 0)
  truetype_push_i16_for_test(output, 0)
  truetype_push_i16_for_test(output, index_to_loc_format)
  truetype_push_i16_for_test(output, 0)
  output
}

///|
fn truetype_maxp_table_for_test(num_glyphs : Int) -> Array[Int] {
  let output : Array[Int] = []
  truetype_push_u32_for_test(output, 0x00010000)
  truetype_push_u16_for_test(output, num_glyphs)
  output
}

///|
fn truetype_hhea_table_for_test(num_of_long_hor_metrics : Int) -> Array[Int] {
  let output : Array[Int] = []
  for _ in 0..<34 {
    output.push(0)
  }
  truetype_push_u16_for_test(output, num_of_long_hor_metrics)
  output
}

///|
fn truetype_hmtx_table_for_test(widths : ArrayView[Int]) -> Array[Int] {
  let output : Array[Int] = []
  for width in widths {
    truetype_push_u16_for_test(output, width)
    truetype_push_i16_for_test(output, 0)
  }
  output
}

///|
test "pdf_truetype_cmaps returns cmap platform encoding pairs" {
  let font = truetype_bytes_for_test([
    0x00, 0x01, 0x00, 0x00, // scaler type
     0x00, 0x01, // numTables
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // search metadata
     0x63, 0x6D, 0x61, 0x70, // cmap
     0x00, 0x00, 0x00, 0x00, // checksum
     0x00, 0x00, 0x00, 0x1C, // offset
     0x00, 0x00, 0x00, 0x14, // length
     0x00, 0x00, // cmap version
     0x00, 0x02, // cmap records
     0x00, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, 0x14, 0x00, 0x01, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x14,
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmaps(font), [(1, 0), (3, 1)])
}

///|
test "pdf_truetype_cmaps scans past non-cmap tables" {
  let font = truetype_bytes_for_test([
    0x00, 0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x68,
    0x65, 0x61, 0x64, // head
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2C, 0x00, 0x00, 0x00, 0x00, 0x63,
    0x6D, 0x61, 0x70, // cmap
     0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x2C, 0x00, 0x00, 0x00, 0x0C, 0x00,
    0x00, 0x00, 0x01, 0x00, 0x03, 0x00, 0x0A, 0x00, 0x00, 0x00, 0x0C,
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmaps(font), [(3, 10)])
}

///|
test "pdf_truetype_cmaps ignores malformed tails after complete records" {
  let font = truetype_bytes_for_test([
    0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x63,
    0x6D, 0x61, 0x70, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x1C, 0x00, 0x00,
    0x00, 0x14, 0x00, 0x00, 0x00, 0x02, 0x00, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00,
    0x14, 0x00, 0x01, // truncated second record
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmaps(font), [(3, 1)])
  @test.assert_eq(
    @pdflite.pdf_truetype_cmaps(truetype_bytes_for_test([0x00])),
    [],
  )
}

///|
test "pdf_truetype_tables reads table directory records" {
  let font = truetype_table_font_for_test([
    ("head", [1, 2]),
    ("maxp", [3, 4, 5]),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_tables(font), [
    { tag: "head", checksum: 0x10000002U, offset: 44, length: 2 },
    { tag: "maxp", checksum: 0x10000003U, offset: 46, length: 3 },
  ])
  @test.assert_eq(
    @pdflite.pdf_truetype_table(font, "maxp"),
    Some({ tag: "maxp", checksum: 0x10000003U, offset: 46, length: 3 }),
  )
  @test.assert_eq(@pdflite.pdf_truetype_table(font, "hhea"), None)
}

///|
test "pdf_truetype_metrics reads cpdftruetype table prerequisites" {
  let font = truetype_table_font_for_test([
    ("head", truetype_head_table_for_test(2048, -100, -200, 1000, 1500, 1)),
    ("maxp", truetype_maxp_table_for_test(3)),
    ("hhea", truetype_hhea_table_for_test(3)),
    ("hmtx", truetype_hmtx_table_for_test([500, 750, 1000])),
  ])
  @test.assert_eq(try! @pdflite.pdf_truetype_metrics(font), {
    units_per_em: 2048,
    minx: -49,
    miny: -98,
    maxx: 488,
    maxy: 732,
    index_to_loc_format: 1,
    num_glyphs: 3,
    num_of_long_hor_metrics: 3,
    advance_widths: [500, 750, 1000],
    max_width: 488,
  })
  let missing_hmtx : Result[@pdflite.PdfTrueTypeMetrics, Error] = try? @pdflite.pdf_truetype_metrics(
    truetype_table_font_for_test([
      ("head", truetype_head_table_for_test(1000, 0, 0, 10, 10, 0)),
      ("maxp", truetype_maxp_table_for_test(1)),
      ("hhea", truetype_hhea_table_for_test(1)),
    ]),
  )
  guard missing_hmtx
    is Err(@pdflite.PdfError::SoftError("No hmtx table found in TrueType font")) else {
    fail("expected missing hmtx table to fail")
  }
}

///|
test "pdf_truetype_metrics mirrors source optional hhea default" {
  let font = truetype_table_font_for_test([
    ("head", truetype_head_table_for_test(1000, -10, -20, 30, 40, 0)),
    ("maxp", truetype_maxp_table_for_test(1)),
    ("hmtx", truetype_hmtx_table_for_test([500])),
  ])
  @test.assert_eq(try! @pdflite.pdf_truetype_metrics(font), {
    units_per_em: 1000,
    minx: -10,
    miny: -20,
    maxx: 30,
    maxy: 40,
    index_to_loc_format: 0,
    num_glyphs: 1,
    num_of_long_hor_metrics: 0,
    advance_widths: [],
    max_width: 0,
  })
}

///|
test "pdf_truetype_cmap_glyphs reads source-supported format 6 tables" {
  let font = truetype_cmap_font_for_test([
    (3, 1, truetype_format6_subtable_for_test(30, [7, 8, 9])),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyphs(font), [
    { codepoint: 30, glyph_index: 7 },
    { codepoint: 31, glyph_index: 8 },
    { codepoint: 32, glyph_index: 9 },
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyph(font, 31), Some(8))
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyph(font, 99), None)
}

///|
test "pdf_truetype_cmap_glyphs reads format 4 range-offset glyph arrays" {
  let font = truetype_cmap_font_for_test([
    (3, 1, truetype_format4_range_offset_subtable_for_test()),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyphs(font), [
    { codepoint: 70, glyph_index: 15 },
    { codepoint: 71, glyph_index: 16 },
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyph(font, 70), Some(15))
}

///|
test "pdf_truetype_cmap_glyphs mirrors source table replacement and no-cmap fallback" {
  let format0_font = truetype_cmap_font_for_test([
    (1, 0, truetype_format0_subtable_for_test(65, 9)),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyph(format0_font, 65), Some(9))

  let font = truetype_cmap_font_for_test([
    (3, 1, truetype_format6_subtable_for_test(65, [1])),
    (3, 10, truetype_format6_subtable_for_test(65, [2, 3])),
  ])
  @test.assert_eq(@pdflite.pdf_truetype_cmaps(font), [(3, 10), (3, 1)])
  @test.assert_eq(@pdflite.pdf_truetype_cmap_glyphs(font), [
    { codepoint: 65, glyph_index: 2 },
    { codepoint: 66, glyph_index: 3 },
  ])
  @test.assert_eq(
    @pdflite.pdf_truetype_cmap_glyphs(
      truetype_bytes_for_test([
        0x00, 0x01, 0x00, 0x00, // scaler type
         0x00, 0x00, // no table records
         0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ]),
    ).length(),
    256,
  )
  @test.assert_eq(
    @pdflite.pdf_truetype_cmap_glyph(
      truetype_bytes_for_test([
        0x00, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
      ]),
      200,
    ),
    Some(200),
  )
}
