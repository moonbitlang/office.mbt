///|
// The embedded subsets' `head` tables, against TTFunk 1.7.0 (Prawn's
// subsetter, and so asciidoctor-pdf's) on the same programs and characters.
// TTFunk writes a subset's bounding box as the union of its glyphs' boxes;
// Poppler sizes its glyph cache from that box, so a subset carrying the
// whole font's box is anti-aliased differently from Prawn's.
//
// The expected boxes were produced by subsetting the bundled programs
// (`@fontoutlines.outline_sfnt`) with TTFunk 1.7.0's `Subset::Unicode`
// and reading the encoded `head`. TTFunk always adds the space, which has
// no outline in these faces and so does not move the box.

///|
/// The `head` bounding box of a font program, `(xMin, yMin, xMax, yMax)`.
fn head_bbox(font : BytesView) -> (Int, Int, Int, Int) {
  let head = @pdflite.pdf_truetype_table(font, "head").unwrap().offset
  let i16 = (at : Int) => {
    let value = (font[at].to_int() << 8) | font[at + 1].to_int()
    if value >= 0x8000 {
      value - 0x10000
    } else {
      value
    }
  }
  (i16(head + 36), i16(head + 38), i16(head + 40), i16(head + 42))
}

///|
/// The OpenType checksum of `length` bytes from `offset`.
fn sfnt_checksum(font : BytesView, offset : Int, length : Int) -> UInt {
  let mut sum = 0U
  for word = offset; word < offset + length; word = word + 4 {
    let mut value = 0U
    for at in word..<(word + 4) {
      value = (value << 8) |
        (if at < offset + length { font[at].to_uint() } else { 0U })
    }
    sum = sum + value
  }
  sum
}

///|
/// Whether every table checksum in the directory is right (the `head`
/// table's taken with `checkSumAdjustment` zero) and the whole program sums
/// to `0xB1B0AFBA`.
fn sfnt_checksums_valid(font : BytesView) -> Bool {
  let head = @pdflite.pdf_truetype_table(font, "head").unwrap()
  let adjustment = sfnt_checksum(font, head.offset + 8, 4)
  @pdflite.pdf_truetype_tables(font)
  .iter()
  .all(record => {
    let sum = sfnt_checksum(font, record.offset, record.length)
    record.checksum ==
    (if record.tag == "head" { sum - adjustment } else { sum })
  }) &&
  sfnt_checksum(font, 0, font.length()) == 0xB1B0AFBAU
}

///|
fn bundled_program(family : String) -> Bytes raise {
  match @fontoutlines.outline_sfnt(@fonts.resolve_family(family)) {
    Some(program) => program
    None => fail("no bundled program for \{family}")
  }
}

///|
test "a subset's head box is TTFunk's" {
  // (family, characters, TTFunk's box)
  let cases : Array[(String, String, (Int, Int, Int, Int))] = [
    ("Calibri", "Hello, World!", (12, -262, 1810, 1422)),
    // composite accented letters, with their components
    ("Calibri", "éÅçñ", (0, -344, 1178, 1810)),
    // only .notdef has an outline
    ("Calibri", " ", (43, 0, 985, 1383)),
    ("Calibri", "0123456789", (0, -15, 1026, 1399)),
    ("Times New Roman", "Hello, World!", (2, -315, 1929, 1421)),
    ("Times New Roman", "éÅçñ", (18, -436, 1464, 1679)),
    // no glyph has an outline, .notdef included: TTFunk writes zeros
    ("Times New Roman", " ", (0, 0, 0, 0)),
    ("Times New Roman", "0123456789", (40, -20, 992, 1362)),
  ]
  for case in cases {
    let (family, text, expected) = case
    let program = bundled_program(family)
    let codepoints = text.iter().map(c => c.to_int()).collect()
    let subset = @pdflite.pdf_truetype_subset_font(
      program,
      codepoints,
      recompute_head=true,
    )
    assert_eq(head_bbox(subset), expected)
    assert_true(sfnt_checksums_valid(subset))
    // the whole program's box is what the subset carried before
    assert_true(head_bbox(program) != expected)
  }
}

///|
test "the embedded program carries its own box and valid checksums" {
  let bytes = @pdf.render_pdf(text_model("Hello, World!"))
  let document = @pdflite.pdf_read_document_from_bytes(bytes)
  let page = document.pages_of_pagetree()[0]
  guard document.lookup_direct(name("/Font"), page.resources)
    is Some(PdfDictionary([(_, font)])) else {
    fail("expected one font resource")
  }
  guard document.lookup_chain(font, [
      name("/FontDescriptor"),
      name("/FontFile2"),
    ])
    is Some(file) &&
    document.pdf_decode_stream(file) is PdfStreamObject(stream) else {
    fail("no /FontFile2 stream")
  }
  let program = @syntax.pdf_stream_data_bytes(stream.data)
  assert_eq(head_bbox(program), (12, -262, 1810, 1422))
  assert_true(sfnt_checksums_valid(program))
}
