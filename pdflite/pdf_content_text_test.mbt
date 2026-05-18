///|
fn content_text_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn content_text_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn content_text_font_descriptor_for_test() -> @pdflite.PdfFontDescriptor {
  {
    ascent: 0.0,
    descent: 0.0,
    avgwidth: 0.0,
    maxwidth: 0.0,
    flags: 0,
    fontbbox: { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 },
    italicangle: 0.0,
    capheight: 0.0,
    xheight: 0.0,
    stemv: 0.0,
    fontfile: None,
    charset: None,
    tounicode: None,
  }
}

///|
fn content_text_cid_font_for_test() -> @pdflite.PdfFont {
  PdfFontCIDKeyed({
    basefont: content_text_name_for_test("/Top"),
    composite: {
      cid_system_info: {
        registry: content_text_bytes_for_test([82]),
        ordering: content_text_bytes_for_test([79]),
        supplement: 0,
      },
      cid_basefont: content_text_name_for_test("/Descendant"),
      cid_fontdescriptor: content_text_font_descriptor_for_test(),
      cid_widths: [],
      cid_widths2: [],
      cid_default_width: 1000.0,
      cid_default_width2: [880.0, -1000.0],
    },
    encoding: PdfCMap(7),
  })
}

///|
test "cpdfcontent charcodes split raw bytes by font kind" {
  let standard : @pdflite.PdfFont = PdfFontStandard({
    font: PdfHelvetica,
    encoding: PdfWinAnsiEncoding,
  })
  let simple : @pdflite.PdfFont = PdfFontSimple({
    fonttype: PdfType1,
    basefont: None,
    firstchar: 0,
    lastchar: 255,
    widths: [],
    fontdescriptor: None,
    fontmetrics: None,
    encoding: PdfWinAnsiEncoding,
  })
  let one_byte_codes = [65, 0, 255]
  let one_byte_text = content_text_bytes_for_test(one_byte_codes)
  @test.assert_eq(
    standard.content_charcodes_of_bytes(one_byte_text),
    one_byte_codes,
  )
  @test.assert_eq(
    simple.content_charcodes_of_bytes(one_byte_text),
    one_byte_codes,
  )
  @test.assert_eq(
    @pdflite.pdf_content_charcodes_of_bytes(one_byte_text, standard),
    one_byte_codes,
  )
  let cid = content_text_cid_font_for_test()
  @test.assert_eq(
    cid.content_charcodes_of_bytes(
      content_text_bytes_for_test([0x01, 0x02, 0x20, 0xAC]),
    ),
    [0x0102, 0x20AC],
  )
  @test.assert_eq(
    cid.content_charcodes_of_bytes(content_text_bytes_for_test([0x01])),
    [],
  )
}
