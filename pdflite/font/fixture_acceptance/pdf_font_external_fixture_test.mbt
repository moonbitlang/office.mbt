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
) -> @content.PdfContentOp {
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
    let max_start = haystack.length() - needle.length()
    for offset in 0..<=max_start {
      let start = max_start - offset
      if font_external_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn font_external_find_bytes_for_test(
  haystack : BytesView,
  needle : BytesView,
) -> Int {
  if needle.length() == 0 {
    0
  } else if haystack.length() < needle.length() {
    -1
  } else {
    for start in 0..<=(haystack.length() - needle.length()) {
      if font_external_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn font_external_find_bytes_after_for_test(
  haystack : BytesView,
  needle : BytesView,
  start : Int,
) -> Int {
  if needle.length() == 0 {
    start
  } else if start < 0 || haystack.length() < needle.length() {
    -1
  } else {
    for position in start..<=(haystack.length() - needle.length()) {
      if font_external_bytes_start_with_at_for_test(haystack, needle, position) {
        break position
      }
    } nobreak {
      -1
    }
  }
}

///|
fn font_external_push_ascii_for_test(
  output : Array[Byte],
  text : String,
) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn font_external_corrupt_startxref_pointer_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let marker = @ascii.encode("startxref")
  let marker_position = font_external_find_last_bytes_for_test(bytes, marker)
  if marker_position < 0 {
    fail("expected startxref marker")
  }
  let mut number_start = marker_position + marker.length()
  while number_start < bytes.length() &&
        (
          bytes[number_start] == b'\n' ||
          bytes[number_start] == b'\r' ||
          bytes[number_start] == b' ' ||
          bytes[number_start] == b'\t'
        ) {
    number_start += 1
  }
  let mut number_end = number_start
  while number_end < bytes.length() &&
        bytes[number_end] >= b'0' &&
        bytes[number_end] <= b'9' {
    number_end += 1
  }
  let output : Array[Byte] = []
  for index in 0..<number_start {
    output.push(bytes[index])
  }
  font_external_push_ascii_for_test(output, (bytes.length() + 4096).to_string())
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn font_external_startxref_offset_for_test(bytes : Bytes) -> Int raise {
  let marker = @ascii.encode("startxref")
  let marker_position = font_external_find_last_bytes_for_test(bytes, marker)
  if marker_position < 0 {
    fail("expected startxref marker")
  }
  let mut number_start = marker_position + marker.length()
  while number_start < bytes.length() &&
        (
          bytes[number_start] == b'\n' ||
          bytes[number_start] == b'\r' ||
          bytes[number_start] == b' ' ||
          bytes[number_start] == b'\t'
        ) {
    number_start += 1
  }
  let mut number = 0
  let mut current = number_start
  while current < bytes.length() &&
        bytes[current] >= b'0' &&
        bytes[current] <= b'9' {
    number = number * 10 + bytes[current].to_int() - b'0'.to_int()
    current += 1
  }
  if current == number_start {
    fail("expected startxref number")
  }
  number
}

///|
fn font_external_corrupt_startxref_xref_header_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let xref_offset = font_external_startxref_offset_for_test(bytes)
  guard font_external_bytes_start_with_at_for_test(
    bytes,
    @ascii.encode("xref"),
    xref_offset,
  ) else {
    fail("expected startxref to point at a classic xref table")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  output[xref_offset] = b'y'
  Bytes::from_array(output)
}

///|
fn font_external_corrupt_startxref_trailer_keyword_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let xref_offset = font_external_startxref_offset_for_test(bytes)
  let trailer_position = font_external_find_bytes_after_for_test(
    bytes,
    @ascii.encode("trailer"),
    xref_offset,
  )
  if trailer_position < 0 {
    fail("expected classic xref trailer keyword after startxref target")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  output[trailer_position] = b'u'
  Bytes::from_array(output)
}

///|
fn font_external_first_in_use_xref_row_start_for_test(
  bytes : Bytes,
) -> Int raise {
  let free_row = @ascii.encode("0000000000 65535 f")
  let free_row_position = font_external_find_bytes_for_test(bytes, free_row)
  if free_row_position < 0 {
    fail("expected classic xref free row")
  }
  let mut row_start = free_row_position + free_row.length()
  while row_start < bytes.length() &&
        bytes[row_start] != b'\n' &&
        bytes[row_start] != b'\r' {
    row_start += 1
  }
  while row_start < bytes.length() &&
        (bytes[row_start] == b'\n' || bytes[row_start] == b'\r') {
    row_start += 1
  }
  if row_start + 10 > bytes.length() {
    fail("expected first in-use xref row")
  }
  row_start
}

///|
fn font_external_corrupt_first_in_use_xref_marker_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = font_external_first_in_use_xref_row_start_for_test(bytes)
  let marker_position = row_start + 17
  if marker_position >= bytes.length() {
    fail("expected first in-use xref marker")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  output[marker_position] = b'x'
  Bytes::from_array(output)
}

///|
fn font_external_corrupt_first_in_use_xref_offset_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = font_external_first_in_use_xref_row_start_for_test(bytes)
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  for index in row_start..<(row_start + 10) {
    output[index] = b'9'
  }
  Bytes::from_array(output)
}

///|
fn font_external_corrupt_first_in_use_xref_generation_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = font_external_first_in_use_xref_row_start_for_test(bytes)
  if row_start + 16 > bytes.length() {
    fail("expected first in-use xref generation")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  for index in (row_start + 11)..<(row_start + 16) {
    output[index] = b'x'
  }
  Bytes::from_array(output)
}

///|
fn font_external_first_xref_subsection_spans_for_test(
  bytes : Bytes,
) -> (Int, Int, Int, Int) raise {
  let header = @ascii.encode("xref")
  let header_position = font_external_find_bytes_for_test(bytes, header)
  if header_position < 0 {
    fail("expected first classic xref header")
  }
  let mut first_start = header_position + header.length()
  while first_start < bytes.length() &&
        (
          bytes[first_start] == b'\n' ||
          bytes[first_start] == b'\r' ||
          bytes[first_start] == b' ' ||
          bytes[first_start] == b'\t'
        ) {
    first_start += 1
  }
  let mut first_end = first_start
  while first_end < bytes.length() &&
        bytes[first_end] >= b'0' &&
        bytes[first_end] <= b'9' {
    first_end += 1
  }
  if first_end == first_start {
    fail("expected first classic xref subsection object number")
  }
  let mut count_start = first_end
  while count_start < bytes.length() &&
        (
          bytes[count_start] == b'\n' ||
          bytes[count_start] == b'\r' ||
          bytes[count_start] == b' ' ||
          bytes[count_start] == b'\t'
        ) {
    count_start += 1
  }
  let mut count_end = count_start
  while count_end < bytes.length() &&
        bytes[count_end] >= b'0' &&
        bytes[count_end] <= b'9' {
    count_end += 1
  }
  if count_end == count_start {
    fail("expected first classic xref subsection count")
  }
  (first_start, first_end, count_start, count_end)
}

///|
fn font_external_corrupt_first_xref_subsection_object_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let (object_start, object_end, _, _) = font_external_first_xref_subsection_spans_for_test(
    bytes,
  )
  let output : Array[Byte] = []
  for index in 0..<object_start {
    output.push(bytes[index])
  }
  font_external_push_ascii_for_test(output, "/Bad")
  for index in object_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn font_external_corrupt_first_xref_subsection_count_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let (_, _, count_start, count_end) = font_external_first_xref_subsection_spans_for_test(
    bytes,
  )
  let output : Array[Byte] = []
  for index in 0..<count_start {
    output.push(bytes[index])
  }
  font_external_push_ascii_for_test(output, "/Bad")
  for index in count_end..<bytes.length() {
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
fn font_external_assert_contains_for_test(
  haystack : String,
  needle : String,
) -> Unit raise {
  guard haystack.contains(needle) else {
    fail("expected text to contain " + needle)
  }
}

///|
fn font_external_cpdf_font_entry_for_test(
  fonts : ArrayView[@font.PdfFontListEntry],
  basefont_fragment : String,
) -> @font.PdfFontListEntry raise {
  for entry in fonts {
    if entry.basefont.contains(basefont_fragment) {
      break entry
    }
  } nobreak {
    fail("missing font row " + basefont_fragment)
  }
}

///|
fn font_external_assert_font_table_has_unicode_for_test(
  document : @pdflite.PdfDocument,
  font : @font.PdfFontListEntry,
) -> Unit raise {
  let table = document.font_table(font.name, font.page)
  @test.assert_eq(table.length() > 0, true)
  let mut has_unicode = false
  for row in table {
    if row.unicode != "" && row.glyphnames != ".notdef" {
      has_unicode = true
    }
  }
  @test.assert_eq(has_unicode, true)
}

///|
fn font_external_assert_embedded_font_for_test(
  document : @pdflite.PdfDocument,
  fonts : ArrayView[@font.PdfFontListEntry],
  basefont_fragment : String,
) -> Unit raise {
  let font = font_external_cpdf_font_entry_for_test(fonts, basefont_fragment)
  @test.assert_eq(font.subtype, "/Type1")
  @test.assert_eq(font.encoding, "")
  match document.extract_fontfile_bytes(font.page, font.name) {
    Some(bytes) => @test.assert_eq(bytes.length() > 1000, true)
    None => fail("missing embedded fontfile for " + font.basefont)
  }
}

///|
fn font_external_missing_font_entry_for_test(
  entries : ArrayView[@font.PdfMissingFontEntry],
  basefont_fragment : String,
) -> @font.PdfMissingFontEntry raise {
  for entry in entries {
    if entry.basefont.contains(basefont_fragment) {
      break entry
    }
  } nobreak {
    fail("missing font row " + basefont_fragment)
  }
}

///|
fn font_external_assert_no_missing_font_for_test(
  entries : ArrayView[@font.PdfMissingFontEntry],
  basefont_fragment : String,
) -> Unit raise {
  for entry in entries {
    if entry.basefont.contains(basefont_fragment) {
      fail("unexpected missing font row " + basefont_fragment)
    }
  }
}

///|
fn font_external_assert_removed_embedded_font_for_test(
  document : @pdflite.PdfDocument,
  fonts : ArrayView[@font.PdfFontListEntry],
  missing : ArrayView[@font.PdfMissingFontEntry],
  basefont_fragment : String,
) -> Unit raise {
  let font = font_external_cpdf_font_entry_for_test(fonts, basefont_fragment)
  @test.assert_eq(font.subtype, "/Type1")
  @test.assert_eq(document.extract_fontfile_bytes(font.page, font.name), None)
  let missing_entry = font_external_missing_font_entry_for_test(
    missing, basefont_fragment,
  )
  @test.assert_eq(missing_entry.name, font.name)
  @test.assert_eq(missing_entry.page, font.page)
}

///|
fn font_external_assert_cpdf_manual_embedded_fonts_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let all_pages = document.parse_pagespec("")
  let fonts = document.list_fonts(all_pages)
  @test.assert_eq(fonts.length() > 20, true)
  font_external_assert_embedded_font_for_test(
    document, fonts, "NimbusSanL-Bold",
  )
  font_external_assert_embedded_font_for_test(
    document, fonts, "URWPalladioL-Roma",
  )
  font_external_assert_embedded_font_for_test(
    document, fonts, "NimbusMonL-Regu",
  )
  let helvetica = font_external_cpdf_font_entry_for_test(fonts, "/Helvetica")
  @test.assert_eq(
    document.extract_fontfile_bytes(helvetica.page, helvetica.name),
    None,
  )
  font_external_assert_font_table_has_unicode_for_test(document, helvetica)
  @test.assert_eq(document.missing_fonts(all_pages).length(), 0)
  let fonts_json = document.fonts_json(all_pages).stringify()
  font_external_assert_contains_for_test(fonts_json, "NimbusSanL-Bold")
  font_external_assert_contains_for_test(fonts_json, "URWPalladioL-Roma")
  font_external_assert_contains_for_test(fonts_json, "NimbusMonL-Regu")
  let missing_text = @ascii.decode_lossy(document.missing_fonts_text(all_pages))
  @test.assert_eq(missing_text, "")
}

///|
fn font_external_assert_cpdf_manual_removed_embedded_fonts_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let all_pages = document.parse_pagespec("")
  let fonts = document.list_fonts(all_pages)
  @test.assert_eq(fonts.length() > 20, true)
  let missing = document.missing_fonts(all_pages)
  @test.assert_eq(missing.length() > 20, true)
  font_external_assert_removed_embedded_font_for_test(
    document, fonts, missing, "NimbusSanL-Bold",
  )
  font_external_assert_removed_embedded_font_for_test(
    document, fonts, missing, "URWPalladioL-Roma",
  )
  font_external_assert_removed_embedded_font_for_test(
    document, fonts, missing, "NimbusMonL-Regu",
  )
  let fonts_json = document.fonts_json(all_pages).stringify()
  font_external_assert_contains_for_test(fonts_json, "NimbusSanL-Bold")
  font_external_assert_contains_for_test(fonts_json, "URWPalladioL-Roma")
  font_external_assert_contains_for_test(fonts_json, "NimbusMonL-Regu")
  let missing_text = @ascii.decode_lossy(document.missing_fonts_text(all_pages))
  font_external_assert_contains_for_test(missing_text, "NimbusSanL-Bold")
  font_external_assert_contains_for_test(missing_text, "URWPalladioL-Roma")
  font_external_assert_contains_for_test(missing_text, "NimbusMonL-Regu")
}

///|
fn font_external_assert_cpdf_source_hello_copied_font_for_test(
  document : @pdflite.PdfDocument,
  basefont_fragment : String,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let text = @ascii.decode_lossy(document.test_extract_text([1]))
  font_external_assert_contains_for_test(text, "Hello")
  let fonts = document.list_fonts([1])
  let copied = font_external_cpdf_font_entry_for_test(fonts, basefont_fragment)
  @test.assert_eq(copied.page, 1)
  @test.assert_eq(copied.name.contains(basefont_fragment), true)
  @test.assert_eq(copied.subtype, "/Type1")
  match document.extract_fontfile_bytes(copied.page, copied.name) {
    Some(bytes) => @test.assert_eq(bytes.length() > 1000, true)
    None => fail("missing copied fontfile for " + copied.basefont)
  }
  font_external_assert_no_missing_font_for_test(
    document.missing_fonts([1]),
    basefont_fragment,
  )
  let fonts_json = document.fonts_json([1]).stringify()
  font_external_assert_contains_for_test(fonts_json, basefont_fragment)
}

///|
fn font_external_assert_cpdf_source_fonts_fixture_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let fonts = document.list_fonts([1])
  @test.assert_eq(fonts.length(), 2)
  @test.assert_eq(fonts[0].name, "/F1")
  @test.assert_eq(fonts[0].subtype, "/Type1")
  @test.assert_eq(fonts[0].basefont, "/Times-Roman")
  @test.assert_eq(fonts[0].encoding, "/WinAnsiEncoding")
  @test.assert_eq(fonts[1].name, "/F2")
  @test.assert_eq(fonts[1].subtype, "/Type1")
  @test.assert_eq(fonts[1].basefont, "/Times-BoldItalic")
  @test.assert_eq(fonts[1].encoding, "/WinAnsiEncoding")
  let fonts_text = @ascii.decode_lossy(document.list_fonts_text([1]))
  font_external_assert_contains_for_test(
    fonts_text, "1 /F1 /Type1 /Times-Roman /WinAnsiEncoding\n",
  )
  font_external_assert_contains_for_test(
    fonts_text, "1 /F2 /Type1 /Times-BoldItalic /WinAnsiEncoding\n",
  )
  let fonts_json = document.fonts_json([1]).stringify()
  font_external_assert_contains_for_test(fonts_json, "\"name\":\"/F1\"")
  font_external_assert_contains_for_test(
    fonts_json, "\"basefont\":\"/Times-Roman\"",
  )
  font_external_assert_contains_for_test(fonts_json, "\"name\":\"/F2\"")
  font_external_assert_contains_for_test(
    fonts_json, "\"basefont\":\"/Times-BoldItalic\"",
  )
  let first_font = document.font_from_name("/F1", 1)
  @test.assert_eq(first_font != PdfNull, true)
  @test.assert_eq(document.font_from_name("/Missing", 1), PdfNull)
  let font_table = @ascii.decode_lossy(document.font_table_text("/F1", 1))
  font_external_assert_contains_for_test(
    font_table, "65 = U+0041 (A - LATIN CAPITAL LETTER A) = A\n",
  )
  let missing = document.missing_fonts([1])
  @test.assert_eq(missing.length(), 2)
  @test.assert_eq(missing[0].name, "/F1")
  @test.assert_eq(missing[0].basefont, "/Times-Roman")
  @test.assert_eq(missing[1].name, "/F2")
  @test.assert_eq(missing[1].basefont, "/Times-BoldItalic")
  let missing_text = @ascii.decode_lossy(document.missing_fonts_text([1]))
  font_external_assert_contains_for_test(
    missing_text, "1, /F1, /Type1, /Times-Roman, /WinAnsiEncoding\n",
  )
  font_external_assert_contains_for_test(
    missing_text, "1, /F2, /Type1, /Times-BoldItalic, /WinAnsiEncoding\n",
  )
}

///|
async test "cpdf source font mutations remove and copy embedded fonts" {
  match
    font_external_fixture_bytes_for_test(".repos/cpdf-source/cpdfmanual.pdf") {
    None => ()
    Some(manual_bytes) =>
      match
        font_external_fixture_bytes_for_test(".repos/cpdf-source/hello.pdf") {
        None => ()
        Some(hello_bytes) => {
          let manual = @pdflite.pdf_read_document_from_bytes(manual_bytes)
          let removed = manual.remove_embedded_fonts()
          font_external_assert_cpdf_manual_removed_embedded_fonts_for_test(
            removed,
          )
          font_external_assert_cpdf_manual_removed_embedded_fonts_for_test(
            @pdflite.pdf_remove_fonts(manual),
          )
          font_external_assert_cpdf_manual_removed_embedded_fonts_for_test(
            font_external_reparse_compressed_for_test(removed),
          )
          let removed_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
            removed,
          )
          font_external_assert_cpdf_manual_removed_embedded_fonts_for_test(
            @pdflite.pdf_read_document_from_bytes(
              font_external_corrupt_startxref_pointer_for_test(
                removed_compressed,
              ),
            ),
          )
          let hello = @pdflite.pdf_read_document_from_bytes(hello_bytes)
          let source_font = font_external_cpdf_font_entry_for_test(
            manual.list_fonts(manual.parse_pagespec("")),
            "NimbusSanL-Bold",
          )
          let copied = hello.copy_font_from(
            manual,
            source_font.name,
            source_font.page,
            [1],
          )
          font_external_assert_cpdf_source_hello_copied_font_for_test(
            copied, "NimbusSanL-Bold",
          )
          font_external_assert_cpdf_source_hello_copied_font_for_test(
            @pdflite.pdf_copy_font(
              manual,
              source_font.name,
              source_font.page,
              [1],
              hello,
            ),
            "NimbusSanL-Bold",
          )
          font_external_assert_cpdf_source_hello_copied_font_for_test(
            font_external_reparse_compressed_for_test(copied),
            "NimbusSanL-Bold",
          )
          let copied_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
            copied,
          )
          font_external_assert_cpdf_source_hello_copied_font_for_test(
            @pdflite.pdf_read_document_from_bytes(
              font_external_corrupt_startxref_pointer_for_test(
                copied_compressed,
              ),
            ),
            "NimbusSanL-Bold",
          )
        }
      }
  }
}

///|
async test "cpdf source manual fixture reports embedded fonts" {
  match
    font_external_fixture_bytes_for_test(".repos/cpdf-source/cpdfmanual.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      font_external_assert_cpdf_manual_embedded_fonts_for_test(document)
      font_external_assert_cpdf_manual_embedded_fonts_for_test(
        font_external_reparse_compressed_for_test(document),
      )
      let corrupted = font_external_corrupt_startxref_pointer_for_test(bytes)
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(recovered.first_xref(), 0)
      font_external_assert_cpdf_manual_embedded_fonts_for_test(recovered)
      font_external_assert_cpdf_manual_embedded_fonts_for_test(
        font_external_reparse_compressed_for_test(recovered),
      )
    }
  }
}

///|
async test "cpdf source manual font fixture reports font tables" {
  match
    font_external_fixture_document_for_test(
      ".repos/cpdf-source/manualimages/fonts.pdf",
    ) {
    None => ()
    Some(document) => {
      font_external_assert_cpdf_source_fonts_fixture_for_test(document)
      font_external_assert_cpdf_source_fonts_fixture_for_test(
        font_external_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "cpdf source manual font fixture reconstructs malformed classic xref data" {
  match
    font_external_fixture_bytes_for_test(
      ".repos/cpdf-source/manualimages/fonts.pdf",
    ) {
    None => ()
    Some(bytes) =>
      for
        corrupted in [
          font_external_corrupt_startxref_pointer_for_test(bytes),
          font_external_corrupt_startxref_xref_header_for_test(bytes),
          font_external_corrupt_startxref_trailer_keyword_for_test(bytes),
          font_external_corrupt_first_in_use_xref_marker_for_test(bytes),
          font_external_corrupt_first_in_use_xref_offset_for_test(bytes),
          font_external_corrupt_first_in_use_xref_generation_for_test(bytes),
          font_external_corrupt_first_xref_subsection_object_for_test(bytes),
          font_external_corrupt_first_xref_subsection_count_for_test(bytes),
        ] {
        let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
          corrupted,
        )
        guard strict is Err(_) else {
          fail("expected malformed classic xref data to require reconstruction")
        }
        let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
        @test.assert_eq(recovered.first_xref(), 0)
        font_external_assert_cpdf_source_fonts_fixture_for_test(recovered)
        font_external_assert_cpdf_source_fonts_fixture_for_test(
          font_external_reparse_compressed_for_test(recovered),
        )
      }
  }
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
