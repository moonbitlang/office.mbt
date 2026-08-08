///|
fn cid_descriptor() -> @pdflite.PdfFontDescriptor {
  {
    ascent: 880,
    descent: -120,
    avgwidth: 1000,
    maxwidth: 1000,
    flags: 4,
    fontbbox: { min_x: -100, min_y: -250, max_x: 1100, max_y: 950 },
    italicangle: 0,
    capheight: 700,
    xheight: 500,
    stemv: 80,
    fontfile: None,
    charset: None,
    tounicode: None,
  }
}

///|
/// A composite font over Adobe-Japan1, of the shape a CJK document uses:
/// Identity-H encoding, a per-CID width list, and no embedded program so
/// the consumer substitutes an installed face.
fn cid_font(widths : Array[(Int, Double)]) -> @pdflite.PdfFont {
  PdfFontCIDKeyed({
    basefont: @core.pdf_name_of_bytes(b"/NotoSansSC"),
    composite: {
      cid_system_info: {
        registry: b"Adobe",
        ordering: b"Japan1",
        supplement: 6,
      },
      cid_basefont: @core.pdf_name_of_bytes(b"/NotoSansSC"),
      cid_fontdescriptor: cid_descriptor(),
      cid_widths: widths,
      cid_widths2: [],
      cid_default_width: 1000,
      cid_default_width2: [],
    },
    encoding: PdfPredefinedCMap(@core.pdf_name_of_bytes(b"/Identity-H")),
  })
}

///|
fn cid_pdf_text(font : @pdflite.PdfFont) -> String raise @core.PdfError {
  let document = @pdflite.pdf_document_empty()
  ignore(document.write_font(font))
  let page_root = document.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(document.add_root(page_root, []))
  let bytes = @pdflite.pdf_write_document(document)
  let sb = StringBuilder()
  for i in 0..<bytes.length() {
    sb.write_char(bytes[i].to_int().unsafe_to_char())
  }
  sb.to_string()
}

///|
test "a CID-keyed font writes a Type0 over a CIDFontType2" {
  let text = cid_pdf_text(cid_font([(1, 1000.0), (2, 500.0)]))
  assert_true(text.contains("/Type0"))
  assert_true(text.contains("/CIDFontType2"))
  assert_true(text.contains("/DescendantFonts"))
  assert_true(text.contains("/Identity-H"))
  assert_true(text.contains("/CIDToGIDMap /Identity"))
  assert_true(text.contains("/Registry (Adobe)"))
  assert_true(text.contains("/Ordering (Japan1)"))
  assert_true(text.contains("/DW 1000"))
  // no program embedded, so a consumer substitutes the face
  assert_false(text.contains("/FontFile2"))
}

///|
test "consecutive CIDs share one W run" {
  // 10,11,12 are consecutive; 20 starts a new run
  let text = cid_pdf_text(
    cid_font([(10, 500.0), (11, 500.0), (12, 750.0), (20, 1000.0)]),
  )
  assert_true(text.contains("/W [10 [500 500 750] 20 [1000]]"))
}

///|
test "a written CID font reads back as the same font" {
  let document = @pdflite.pdf_document_empty()
  let number = document.write_font(cid_font([(1, 1000.0), (2, 500.0)]))
  let page_root = document.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(document.add_root(page_root, []))
  let bytes = @pdflite.pdf_write_document(document)
  // pdflite reads back what pdflite wrote
  let reread = @pdflite.pdf_read_document_from_bytes(bytes)
  let object = reread.lookup_object_or_null(number)
  let font = reread.read_font(object)
  assert_true(font.is_identity_h())
  assert_true(font.uses_two_byte_codes())
}

///|
test "a font with no widths omits the W array rather than writing an empty one" {
  let text = cid_pdf_text(cid_font([]))
  assert_true(text.contains("/Type0"))
  assert_false(text.contains("/W ["))
}

///|
/// A composite font whose descriptor carries a ToUnicode map.
fn cid_font_with_tounicode(
  tounicode : Array[(Int, @core.PdfBytes)],
) -> @pdflite.PdfFont {
  let descriptor = { ..cid_descriptor(), tounicode: Some(tounicode) }
  PdfFontCIDKeyed({
    basefont: @core.pdf_name_of_bytes(b"/NotoSansSC"),
    composite: {
      cid_system_info: {
        registry: b"Adobe",
        ordering: b"Identity",
        supplement: 0,
      },
      cid_basefont: @core.pdf_name_of_bytes(b"/NotoSansSC"),
      cid_fontdescriptor: descriptor,
      cid_widths: [],
      cid_widths2: [],
      cid_default_width: 1000,
      cid_default_width2: [],
    },
    encoding: PdfPredefinedCMap(@core.pdf_name_of_bytes(b"/Identity-H")),
  })
}

///|
test "a composite font's ToUnicode declares a two-byte codespace" {
  // U+4E2D at CID 8805 and U+6587 at CID 14750, the glyph ids Noto Sans SC
  // gives those characters. A one-byte codespace would have a reader take
  // the high byte of each CID for a whole character.
  let text = cid_pdf_text(
    cid_font_with_tounicode([(8805, b"\x4e\x2d"), (14750, b"\x65\x87")]),
  )
  assert_true(text.contains("<0000><FFFF>"))
  assert_false(text.contains("<00><FF>"))
  // codes are the CIDs the content stream writes, at the codespace's width
  assert_true(text.contains("<2265><2265><4E2D>"))
  assert_true(text.contains("<399e><399e><6587>"))
  assert_true(text.contains("/ToUnicode"))
}

///|
test "a composite ToUnicode pads CIDs to the codespace width" {
  // CID 5 is one hex digit; written as <05> it would fall outside the
  // two-byte codespace and be ignored.
  let text = cid_pdf_text(cid_font_with_tounicode([(5, b"\x00\x41")]))
  assert_true(text.contains("<0005><0005><0041>"))
}
