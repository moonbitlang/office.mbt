///|
fn font_external_fixture_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
fn font_external_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn font_external_ascii_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn font_external_inline_image_op_for_test(
  width : Int,
  height : Int,
  data_length : Int,
) -> @pdflite.PdfContentOp {
  Op_InlineImage(
    @pdflite.pdf_dictionary([
      (font_external_name_for_test("/W"), PdfInteger(width)),
      (font_external_name_for_test("/H"), PdfInteger(height)),
      (font_external_name_for_test("/BPC"), PdfInteger(1)),
      (font_external_name_for_test("/IM"), PdfBoolean(true)),
    ]),
    None,
    font_external_ascii_for_test("x".repeat(data_length)),
  )
}

///|
async fn font_external_fixture_document_for_test(
  path : String,
) -> @pdflite.PdfDocument? {
  let read_result = try? @fs.read_file(
    font_external_fixture_path_for_test(path),
  )
  match read_result {
    Ok(data) => Some(@pdflite.pdf_read_document_from_bytes(data.binary()))
    Err(_) => None
  }
}

///|
async fn font_external_fixture_bytes_for_test(path : String) -> Bytes? {
  let read_result = try? @fs.read_file(
    font_external_fixture_path_for_test(path),
  )
  match read_result {
    Ok(data) => Some(data.binary())
    Err(_) => None
  }
}

///|
fn font_external_first_page_font_for_test(
  document : @pdflite.PdfDocument,
  font_name : String,
) -> @pdflite.PdfObject raise {
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font_resources = match
    document.lookup_direct(
      font_external_name_for_test("/Font"),
      pages[0].resources,
    ) {
    Some(resources) => resources
    None => fail("expected page font resources")
  }
  match
    document.lookup_direct(
      font_external_name_for_test(font_name),
      font_resources,
    ) {
    Some(font) => font
    None => fail("expected requested page font")
  }
}

///|
fn font_external_tj_texts_for_test(
  document : @pdflite.PdfDocument,
) -> Array[@pdflite.PdfBytes] raise {
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let texts : Array[@pdflite.PdfBytes] = []
  for op in document.parse_content_ops(pages[0].content) {
    match op {
      Op_Tj(text) => texts.push(text)
      _ => ()
    }
  }
  texts
}

///|
fn font_external_reparse_compressed_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  @pdflite.pdf_read_document_from_bytes(
    @pdflite.pdf_write_document_with_compressed_xref_stream(document),
  )
}

///|
fn font_external_bytes_start_with_at_for_test(
  haystack : BytesView,
  needle : BytesView,
  start : Int,
) -> Bool {
  if start < 0 || start + needle.length() > haystack.length() {
    false
  } else {
    for index in 0..<needle.length() {
      if haystack[start + index] != needle[index] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn font_external_find_last_bytes_for_test(
  haystack : BytesView,
  needle : BytesView,
) -> Int {
  if needle.length() == 0 {
    haystack.length()
  } else if haystack.length() < needle.length() {
    -1
  } else {
    for start = haystack.length() - needle.length()
        start >= 0
        start = start - 1 {
      if font_external_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn font_external_corrupt_startxref_pointer_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let marker = @ascii.encode("startxref\n")
  let marker_position = font_external_find_last_bytes_for_test(bytes, marker)
  if marker_position < 0 {
    fail("expected startxref marker")
  }
  let number_start = marker_position + marker.length()
  let mut number_end = number_start
  while number_end < bytes.length() && bytes[number_end] != b'\n' {
    number_end += 1
  }
  let output : Array[Byte] = []
  for index in 0..<number_start {
    output.push(bytes[index])
  }
  for byte in @ascii.encode((bytes.length() + 4096).to_string()) {
    output.push(byte)
  }
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn font_external_assert_pdfium_resource_fixture_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  let font_object = font_external_first_page_font_for_test(document, "/F1")
  let font = document.read_font(font_object)
  guard font is PdfFontSimple(simple) else {
    fail("expected simple Type3 font")
  }
  guard simple.fonttype is PdfType3(type3_data) else {
    fail("expected Type3 font data")
  }
  guard simple.fontmetrics is Some(metrics) else {
    fail("expected Type3 font metrics")
  }
  @test.assert_eq(metrics.length(), 256)
  @test.assert_eq(metrics[49], 8.0)
  @test.assert_eq(metrics[50], 10.0)
  @test.assert_eq(type3_data.fontbbox, {
    min_x: -1.0,
    min_y: -8.0,
    max_x: 28.0,
    max_y: 27.0,
  })
  @test.assert_eq(type3_data.fontmatrix, {
    a: 0.001,
    b: 0.0,
    c: 0.0,
    d: 0.001,
    e: 0.0,
    f: 0.0,
  })
  @test.assert_eq(
    type3_data.resources,
    @pdflite.pdf_dictionary([
      (
        font_external_name_for_test("/ProcSet"),
        PdfArray([
          PdfNameObject(font_external_name_for_test("/PDF")),
          PdfNameObject(font_external_name_for_test("/ImageB")),
        ]),
      ),
    ]),
  )
  @test.assert_eq(type3_data.charprocs, [
    (font_external_name_for_test("/uniE022"), PdfIndirect(8)),
    (font_external_name_for_test("/uniE023"), PdfIndirect(9)),
  ])
  let extractor = font.text_extractor()
  let texts = font_external_tj_texts_for_test(document)
  @test.assert_eq(texts.length(), 3)
  @test.assert_eq(extractor.codepoints_of_text(texts[0][:]), [0xE022])
  @test.assert_eq(extractor.codepoints_of_text(texts[1][:]), [0xE023])
  @test.assert_eq(extractor.codepoints_of_text(texts[2][:]), [0xE022])
  @test.assert_eq(
    document.parse_content_ops_with_resources(type3_data.resources, [
      document.direct(type3_data.charprocs[0].1),
    ]),
    [
      Op_q,
      Op_cm({ a: 6.0, b: 0.0, c: 0.0, d: 48.0, e: 6.0, f: 0.0 }),
      font_external_inline_image_op_for_test(6, 48, 48),
      Op_Q,
    ],
  )
  @test.assert_eq(
    document.parse_content_ops_with_resources(type3_data.resources, [
      document.direct(type3_data.charprocs[1].1),
    ]),
    [Op_q, font_external_inline_image_op_for_test(4, 4, 4), Op_Q],
  )
}

///|
async test "external Type3 resource fixture reads resources and glyph inline images" {
  match
    font_external_fixture_document_for_test(
      "font/external_fixtures/downloads/pdfium_bug_1591.pdf",
    ) {
    None => ()
    Some(document) =>
      font_external_assert_pdfium_resource_fixture_for_test(document)
  }
}

///|
async test "external Type3 resource fixture reconstructs malformed startxref" {
  match
    font_external_fixture_bytes_for_test(
      "font/external_fixtures/downloads/pdfium_bug_1591.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let corrupted = font_external_corrupt_startxref_pointer_for_test(bytes)
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(recovered.first_xref(), 0)
      font_external_assert_pdfium_resource_fixture_for_test(recovered)
      font_external_assert_pdfium_resource_fixture_for_test(
        font_external_reparse_compressed_for_test(recovered),
      )
    }
  }
}

///|
fn font_external_assert_itext_logo_fixture_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  let font_object = font_external_first_page_font_for_test(document, "/F1")
  let font = document.read_font(font_object)
  guard font is PdfFontSimple(simple) else {
    fail("expected simple Type3 font")
  }
  guard simple.fonttype is PdfType3(type3_data) else {
    fail("expected Type3 font data")
  }
  @test.assert_eq(simple.firstchar, 0)
  @test.assert_eq(simple.lastchar, 0)
  @test.assert_eq(simple.widths.length(), 0)
  guard simple.fontmetrics is Some(metrics) else {
    fail("expected Type3 width metrics")
  }
  @test.assert_eq(metrics.length(), 256)
  @test.assert_eq(metrics[69], 1150.0)
  @test.assert_eq(metrics[73], 700.0)
  @test.assert_eq(metrics[84], 1170.0)
  @test.assert_eq(metrics[88], 1160.0)
  @test.assert_eq(type3_data.fontmatrix, {
    a: 0.001,
    b: 0.0,
    c: 0.0,
    d: 0.001,
    e: 0.0,
    f: 0.0,
  })
  @test.assert_eq([ for entry in type3_data.charprocs => entry.0 ], [
    font_external_name_for_test("/E"),
    font_external_name_for_test("/X"),
    font_external_name_for_test("/T"),
    font_external_name_for_test("/I"),
  ])
  let extractor = font.text_extractor()
  let texts = font_external_tj_texts_for_test(document)
  @test.assert_eq(texts.length(), 6)
  @test.assert_eq(extractor.codepoints_of_text(texts[0][:]), [
    73, 84, 69, 88, 84,
  ])
  @test.assert_eq(extractor.codepoints_of_text(texts[1][:]), [73])
  @test.assert_eq(extractor.codepoints_of_text(texts[2][:]), [84])
  @test.assert_eq(extractor.codepoints_of_text(texts[3][:]), [69])
  @test.assert_eq(extractor.codepoints_of_text(texts[4][:]), [88])
  @test.assert_eq(extractor.codepoints_of_text(texts[5][:]), [84])
}

///|
async test "external Type3 font fixture reads CharProcs and text encoding" {
  match
    font_external_fixture_document_for_test(
      "font/external_fixtures/downloads/cmp_itext_logo.pdf",
    ) {
    None => ()
    Some(document) => font_external_assert_itext_logo_fixture_for_test(document)
  }
}

///|
async test "external Type3 font fixture reconstructs malformed startxref" {
  match
    font_external_fixture_bytes_for_test(
      "font/external_fixtures/downloads/cmp_itext_logo.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let corrupted = font_external_corrupt_startxref_pointer_for_test(bytes)
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(recovered.first_xref(), 0)
      font_external_assert_itext_logo_fixture_for_test(recovered)
      font_external_assert_itext_logo_fixture_for_test(
        font_external_reparse_compressed_for_test(recovered),
      )
    }
  }
}
