///|
fn embed_standard_font_for_test() -> @pdflite.PdfFont {
  PdfFontStandard({ font: PdfHelvetica, encoding: PdfWinAnsiEncoding })
}

///|
fn embed_bold_font_for_test() -> @pdflite.PdfFont {
  PdfFontStandard({ font: PdfHelveticaBold, encoding: PdfWinAnsiEncoding })
}

///|
fn embed_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn embed_bytes_for_test(values : Array[Int]) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for value in values {
    output.push(value.to_byte())
  }
  Bytes::from_array(output)
}

///|
fn embed_push_u16_for_test(output : Array[Int], value : Int) -> Unit {
  output.push((value >> 8) & 0xFF)
  output.push(value & 0xFF)
}

///|
fn embed_push_u32_for_test(output : Array[Int], value : Int) -> Unit {
  output.push((value >> 24) & 0xFF)
  output.push((value >> 16) & 0xFF)
  output.push((value >> 8) & 0xFF)
  output.push(value & 0xFF)
}

///|
fn embed_push_i16_for_test(output : Array[Int], value : Int) -> Unit {
  let mut normalized = value % 0x10000
  if normalized < 0 {
    normalized += 0x10000
  }
  embed_push_u16_for_test(output, normalized)
}

///|
fn embed_push_tag_for_test(output : Array[Int], tag : String) -> Unit {
  let bytes = @ascii.encode(tag)
  for index in 0..<4 {
    output.push(if index < bytes.length() { bytes[index].to_int() } else { 32 })
  }
}

///|
fn embed_append_for_test(output : Array[Int], values : ArrayView[Int]) -> Unit {
  for value in values {
    output.push(value)
  }
}

///|
fn embed_table_font_for_test(
  tables : ArrayView[(String, Array[Int])],
) -> @pdflite.PdfBytes {
  let table_data_offset = 12 + tables.length() * 16
  let output : Array[Int] = []
  embed_push_u32_for_test(output, 0x00010000)
  embed_push_u16_for_test(output, tables.length())
  embed_push_u16_for_test(output, 0)
  embed_push_u16_for_test(output, 0)
  embed_push_u16_for_test(output, 0)
  let mut table_offset = table_data_offset
  for record in tables {
    let (tag, data) = record
    embed_push_tag_for_test(output, tag)
    embed_push_u32_for_test(output, 0x10000000 + data.length())
    embed_push_u32_for_test(output, table_offset)
    embed_push_u32_for_test(output, data.length())
    table_offset += data.length()
  }
  for record in tables {
    let (_, data) = record
    embed_append_for_test(output, data)
  }
  embed_bytes_for_test(output)
}

///|
fn embed_cmap_table_for_test(
  subtables : ArrayView[(Int, Int, Array[Int])],
) -> Array[Int] {
  let cmap_header_length = 4 + subtables.length() * 8
  let cmap : Array[Int] = []
  embed_push_u16_for_test(cmap, 0)
  embed_push_u16_for_test(cmap, subtables.length())
  let mut subtable_offset = cmap_header_length
  for record in subtables {
    let (platform_id, encoding_id, subtable) = record
    embed_push_u16_for_test(cmap, platform_id)
    embed_push_u16_for_test(cmap, encoding_id)
    embed_push_u32_for_test(cmap, subtable_offset)
    subtable_offset += subtable.length()
  }
  for record in subtables {
    let (_, _, subtable) = record
    embed_append_for_test(cmap, subtable)
  }
  cmap
}

///|
fn embed_format6_subtable_for_test(
  first_code : Int,
  glyphs : ArrayView[Int],
) -> Array[Int] {
  let output : Array[Int] = []
  embed_push_u16_for_test(output, 6)
  embed_push_u16_for_test(output, 10 + glyphs.length() * 2)
  embed_push_u16_for_test(output, 0)
  embed_push_u16_for_test(output, first_code)
  embed_push_u16_for_test(output, glyphs.length())
  for glyph in glyphs {
    embed_push_u16_for_test(output, glyph)
  }
  output
}

///|
fn embed_head_table_for_test() -> Array[Int] {
  let output : Array[Int] = []
  embed_push_u32_for_test(output, 0x00010000)
  embed_push_u32_for_test(output, 0)
  embed_push_u32_for_test(output, 0)
  embed_push_u32_for_test(output, 0)
  embed_push_u16_for_test(output, 0)
  embed_push_u16_for_test(output, 1000)
  for _ in 0..<16 {
    output.push(0)
  }
  embed_push_i16_for_test(output, -50)
  embed_push_i16_for_test(output, -20)
  embed_push_i16_for_test(output, 900)
  embed_push_i16_for_test(output, 1000)
  embed_push_u16_for_test(output, 0)
  embed_push_u16_for_test(output, 0)
  embed_push_i16_for_test(output, 0)
  embed_push_i16_for_test(output, 1)
  embed_push_i16_for_test(output, 0)
  output
}

///|
fn embed_maxp_table_for_test() -> Array[Int] {
  let output : Array[Int] = []
  embed_push_u32_for_test(output, 0x00010000)
  embed_push_u16_for_test(output, 2)
  output
}

///|
fn embed_hhea_table_for_test() -> Array[Int] {
  let output : Array[Int] = []
  for _ in 0..<34 {
    output.push(0)
  }
  embed_push_u16_for_test(output, 2)
  output
}

///|
fn embed_hmtx_table_for_test() -> Array[Int] {
  let output : Array[Int] = []
  for width in [1000, 1500] {
    embed_push_u16_for_test(output, width)
    embed_push_i16_for_test(output, 0)
  }
  output
}

///|
fn embed_os2_table_for_test() -> Array[Int] {
  let output : Array[Int] = []
  embed_push_u16_for_test(output, 2)
  embed_push_i16_for_test(output, 500)
  for _ in 0..<64 {
    output.push(0)
  }
  embed_push_i16_for_test(output, 800)
  embed_push_i16_for_test(output, -200)
  for _ in 0..<14 {
    output.push(0)
  }
  embed_push_i16_for_test(output, 450)
  embed_push_i16_for_test(output, 700)
  output
}

///|
fn embed_post_table_for_test() -> Array[Int] {
  let output : Array[Int] = []
  embed_push_u32_for_test(output, 0x00020000)
  embed_push_i16_for_test(output, 11)
  embed_push_u16_for_test(output, 0)
  output
}

///|
fn embed_simple_glyph_for_test() -> Array[Int] {
  let output : Array[Int] = []
  embed_push_i16_for_test(output, 1)
  for _ in 0..<8 {
    output.push(0)
  }
  output
}

///|
fn embed_glyf_table_for_test(
  glyphs : ArrayView[Array[Int]],
) -> (Array[Int], Array[Int]) {
  let glyf : Array[Int] = []
  let offsets : Array[Int] = [0]
  let mut offset = 0
  for glyph in glyphs {
    embed_append_for_test(glyf, glyph)
    offset += glyph.length()
    offsets.push(offset)
  }
  (glyf, offsets)
}

///|
fn embed_loca_long_table_for_test(offsets : ArrayView[Int]) -> Array[Int] {
  let output : Array[Int] = []
  for offset in offsets {
    embed_push_u32_for_test(output, offset)
  }
  output
}

///|
fn embed_cmap_for_test() -> Array[Int] {
  let glyphs : Array[Int] = []
  for code in 65..<=0x0100 {
    glyphs.push(if code == 65 || code == 0x0100 { 1 } else { 0 })
  }
  embed_cmap_table_for_test([
    (3, 1, embed_format6_subtable_for_test(65, glyphs)),
  ])
}

///|
fn embed_truetype_font_for_test() -> @pdflite.PdfBytes {
  let (glyf, offsets) = embed_glyf_table_for_test([
    embed_simple_glyph_for_test(),
    embed_simple_glyph_for_test(),
  ])
  embed_table_font_for_test([
    ("head", embed_head_table_for_test()),
    ("maxp", embed_maxp_table_for_test()),
    ("hhea", embed_hhea_table_for_test()),
    ("hmtx", embed_hmtx_table_for_test()),
    ("OS/2", embed_os2_table_for_test()),
    ("post", embed_post_table_for_test()),
    ("cmap", embed_cmap_for_test()),
    ("loca", embed_loca_long_table_for_test(offsets)),
    ("glyf", glyf),
  ])
}

///|
fn embed_assert_fontfile_stream_for_test(
  document : @pdflite.PdfDocument,
  number : Int,
) -> Unit raise {
  guard document.lookup_object_or_null(number) is PdfStreamObject(stream) else {
    fail("expected embedded font stream")
  }
  guard stream.data is StreamGot(bytes) else {
    fail("expected materialized font stream bytes")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(embed_name_for_test("/Length")),
    Some(PdfInteger(bytes.length())),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(embed_name_for_test("/Length1")),
    Some(PdfInteger(bytes.length())),
  )
  @test.assert_eq(bytes.length() > 0, true)
}

///|
test "pdf_fontpack_of_standard_font maps Unicode codepoints to charcodes" {
  let font = embed_standard_font_for_test()
  let pack = try! @pdflite.pdf_fontpack_of_standard_font(font)
  let cpdf_pack = try! @pdflite.pdf_fontpack_of_standardfont(font)
  @test.assert_eq(pack.fonts, [font])
  @test.assert_eq(cpdf_pack, pack)
  @test.assert_eq(pack.entries.length(), 256)
  guard pack.get_char(65) is Some((65, 0, mapped_font)) else {
    fail("expected capital A mapping")
  }
  @test.assert_eq(mapped_font, font)
  @test.assert_eq(@pdflite.pdf_fontpack_get_char(pack, 0x2603), None)
  @test.assert_eq(@pdflite.pdf_embed_get_char(pack, 65), Some((65, 0, font)))
}

///|
test "PdfFontPack::get_char follows cpdf duplicate and missing semantics" {
  let first = embed_standard_font_for_test()
  let second = embed_bold_font_for_test()
  let pack : @pdflite.PdfFontPack = {
    fonts: [first, second],
    entries: [
      { codepoint: 65, font_index: 0, charcode: 41 },
      { codepoint: 66, font_index: 7, charcode: 42 },
      { codepoint: 65, font_index: 1, charcode: 43 },
      { codepoint: 67, font_index: -1, charcode: 44 },
    ],
  }
  @test.assert_eq(pack.get_char(65), Some((43, 1, second)))
  @test.assert_eq(pack.get_char(66), None)
  @test.assert_eq(pack.get_char(67), None)
  @test.assert_eq(pack.get_char(68), None)
}

///|
test "pdf_embed_truetype skips parsing for empty codepoints" {
  let document = @pdflite.pdf_document_empty()
  let pack = try! @pdflite.pdf_embed_truetype(
    document,
    @ascii.encode("not a real font"),
    "UnitTT",
    [],
    PdfWinAnsiEncoding,
  )
  @test.assert_eq(pack.fonts.length(), 0)
  @test.assert_eq(pack.entries.length(), 0)
  @test.assert_eq(document.object_count(), 0)
}

///|
test "pdf_embed_truetype builds font pack and embedded font streams" {
  let document = @pdflite.pdf_document_empty()
  let pack = try! @pdflite.pdf_embed_truetype(
    document,
    embed_truetype_font_for_test(),
    "UnitTT",
    [65, 0x0100],
    PdfWinAnsiEncoding,
  )
  @test.assert_eq(pack.fonts.length(), 2)
  @test.assert_eq(pack.entries, [
    { codepoint: 65, font_index: 0, charcode: 65 },
    { codepoint: 0x0100, font_index: 1, charcode: 33 },
  ])
  @test.assert_eq(pack.get_char(65), Some((65, 0, pack.fonts[0])))
  @test.assert_eq(pack.get_char(0x0100), Some((33, 1, pack.fonts[1])))
  @test.assert_eq(document.object_count(), 2)

  guard pack.fonts[0] is PdfFontSimple(main) else {
    fail("expected main TrueType simple font")
  }
  @test.assert_eq(main.fonttype, PdfTrueType)
  @test.assert_eq(main.firstchar, 65)
  @test.assert_eq(main.lastchar, 65)
  @test.assert_eq(main.widths, [1500])
  guard main.basefont is Some(main_basefont) else {
    fail("expected main basefont")
  }
  let main_basefont_text = @ascii.decode_lossy(main_basefont.bytes())
  @test.assert_eq(main_basefont_text.has_prefix("/AAAAA"), true)
  @test.assert_eq(main_basefont_text.has_suffix("+UnitTT"), true)
  guard main.fontmetrics is Some(main_metrics) else {
    fail("expected main font metrics")
  }
  @test.assert_eq(main_metrics[65], 1500.0)
  guard main.fontdescriptor is Some(main_descriptor) else {
    fail("expected main font descriptor")
  }
  @test.assert_eq(main_descriptor.fontfile, Some(PdfFontFile2(1)))
  @test.assert_eq(main_descriptor.tounicode, None)
  @test.assert_eq(main_descriptor.ascent, 800.0)
  @test.assert_eq(main_descriptor.descent, -200.0)
  @test.assert_eq(main_descriptor.fontbbox, {
    min_x: -50.0,
    min_y: -20.0,
    max_x: 900.0,
    max_y: 1000.0,
  })

  guard pack.fonts[1] is PdfFontSimple(higher) else {
    fail("expected higher TrueType simple font")
  }
  @test.assert_eq(higher.fonttype, PdfTrueType)
  @test.assert_eq(higher.firstchar, 33)
  @test.assert_eq(higher.lastchar, 33)
  @test.assert_eq(higher.widths, [1500])
  guard higher.fontmetrics is Some(higher_metrics) else {
    fail("expected higher font metrics")
  }
  @test.assert_eq(higher_metrics[33], 1500.0)
  guard higher.fontdescriptor is Some(higher_descriptor) else {
    fail("expected higher font descriptor")
  }
  @test.assert_eq(higher_descriptor.fontfile, Some(PdfFontFile2(2)))
  @test.assert_eq(
    higher_descriptor.tounicode,
    Some([(33, embed_bytes_for_test([0x01, 0x00]))]),
  )

  embed_assert_fontfile_stream_for_test(document, 1)
  embed_assert_fontfile_stream_for_test(document, 2)

  let main_font_number = try! document.write_font(pack.fonts[0])
  let higher_font_number = try! document.write_font(pack.fonts[1])
  @test.assert_eq(main_font_number, 4)
  @test.assert_eq(higher_font_number, 7)
  let higher_object = document.lookup_object_or_null(higher_font_number)
  guard higher_object is PdfDictionary(_) else {
    fail("expected written higher font object")
  }
  guard higher_object.lookup_immediate(embed_name_for_test("/ToUnicode"))
    is Some(PdfIndirect(_)) else {
    fail("expected written higher font ToUnicode stream")
  }
}

///|
test "pdf_fontpack_collate_runs groups consecutive equal font numbers" {
  let first = embed_standard_font_for_test()
  let second = embed_bold_font_for_test()
  let runs = [
    (65, 0, first),
    (66, 0, first),
    (67, 1, second),
    (68, 1, second),
    (69, 0, first),
  ]
  @test.assert_eq(@pdflite.pdf_fontpack_collate_runs(runs), [
    [(65, 0, first), (66, 0, first)],
    [(67, 1, second), (68, 1, second)],
    [(69, 0, first)],
  ])
  @test.assert_eq(@pdflite.pdf_fontpack_collate_runs([]), [])
  @test.assert_eq(
    @pdflite.pdf_embed_collate_runs([
      ("A", "Latin", 1),
      ("B", "Latin", 2),
      ("Omega", "Greek", 3),
      ("Snowman", "Symbol", 4),
      ("Euro", "Symbol", 5),
    ]),
    [
      [("A", "Latin", 1), ("B", "Latin", 2)],
      [("Omega", "Greek", 3)],
      [("Snowman", "Symbol", 4), ("Euro", "Symbol", 5)],
    ],
  )
  @test.assert_eq(
    @pdflite.pdf_collate_runs([
      ("A", "Latin", 1),
      ("B", "Latin", 2),
      ("Omega", "Greek", 3),
    ]),
    [[("A", "Latin", 1), ("B", "Latin", 2)], [("Omega", "Greek", 3)]],
  )
}

///|
test "PdfEmbedFontSource variants preserve cpdfembed font source shape" {
  let font = embed_standard_font_for_test()
  let pack = try! @pdflite.pdf_fontpack_of_standardfont(font)
  let premade : @pdflite.PdfEmbedFontSource = PdfEmbedPreMadeFontPack(pack)
  let embed : @pdflite.PdfEmbedFontSource = PdfEmbedInfo(
    @ascii.encode("ttf"),
    "NimbusSans",
    PdfWinAnsiEncoding,
  )
  let existing : @pdflite.PdfEmbedFontSource = PdfEmbedExistingNamedFont
  @test.assert_eq(premade, PdfEmbedPreMadeFontPack(pack))
  @test.assert_eq(
    embed,
    PdfEmbedInfo(@ascii.encode("ttf"), "NimbusSans", PdfWinAnsiEncoding),
  )
  @test.assert_eq(existing, PdfEmbedExistingNamedFont)
}

///|
test "pdf_standard_font_substitute_filenames mirrors cpdf table" {
  @test.assert_eq(
    @pdflite.pdf_standard_font_substitute_filenames(PdfTimesRoman),
    ["NimbusRoman-Regular.ttf"],
  )
  @test.assert_eq(
    @pdflite.pdf_standard_font_substitute_filenames(PdfHelveticaBoldOblique),
    ["NimbusSans-BoldItalic.ttf"],
  )
  @test.assert_eq(
    @pdflite.pdf_standard_font_substitute_filenames(PdfCourierOblique),
    ["NimbusMonoPS-Italic.ttf"],
  )
  @test.assert_eq(@pdflite.pdf_standard_font_substitute_filenames(PdfSymbol), [
    "StandardSymbolsPS.ttf",
  ])
  @test.assert_eq(
    @pdflite.pdf_standard_font_substitute_filenames(PdfZapfDingbats),
    ["D050000L.ttf"],
  )
}

///|
test "pdf_standard_font_substitute_font_name strips ttf suffix" {
  @test.assert_eq(
    @pdflite.pdf_standard_font_substitute_font_name(PdfHelvetica),
    "NimbusSans-Regular",
  )
  @test.assert_eq(
    @pdflite.pdf_standard_font_substitute_font_name(PdfZapfDingbats),
    "D050000L",
  )
}
