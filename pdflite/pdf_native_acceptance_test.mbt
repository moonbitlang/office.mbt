///|
fn acceptance_ascii_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn acceptance_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(acceptance_ascii_for_test(text))
}

///|
fn acceptance_push_byte_for_test(output : Array[Byte], value : Int) -> Unit {
  output.push(value.to_byte())
}

///|
fn acceptance_push_ascii_for_test(output : Array[Byte], text : String) -> Unit {
  for byte in @ascii.encode(text)[:] {
    output.push(byte)
  }
}

///|
fn acceptance_push_view_for_test(
  output : Array[Byte],
  view : BytesView,
) -> Unit {
  for byte in view {
    output.push(byte)
  }
}

///|
fn acceptance_bytes_start_with_at_for_test(
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
fn acceptance_find_bytes_for_test(
  haystack : BytesView,
  needle : BytesView,
) -> Int {
  if needle.length() == 0 {
    0
  } else if haystack.length() < needle.length() {
    -1
  } else {
    for start = 0
        start <= haystack.length() - needle.length()
        start = start + 1 {
      if acceptance_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn acceptance_find_last_bytes_for_test(
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
      if acceptance_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn acceptance_corrupt_first_in_use_xref_offset_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes raise {
  let free_row = acceptance_ascii_for_test("0000000000 65535 f \n")
  let free_row_position = acceptance_find_bytes_for_test(bytes, free_row)
  if free_row_position < 0 {
    fail("expected classic xref free row")
  }
  let row_start = free_row_position + free_row.length()
  if row_start + 10 > bytes.length() {
    fail("expected first in-use xref row")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  for index in row_start..<(row_start + 10) {
    output[index] = (57).to_byte()
  }
  Bytes::from_array(output)
}

///|
fn acceptance_corrupt_first_in_use_xref_marker_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes raise {
  let free_row = acceptance_ascii_for_test("0000000000 65535 f \n")
  let free_row_position = acceptance_find_bytes_for_test(bytes, free_row)
  if free_row_position < 0 {
    fail("expected classic xref free row")
  }
  let row_start = free_row_position + free_row.length()
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
fn acceptance_mark_classic_xref_entry_free_for_test(
  bytes : @pdflite.PdfBytes,
  object_number : Int,
) -> @pdflite.PdfBytes raise {
  if object_number < 0 {
    fail("expected non-negative classic xref object number")
  }
  let header = acceptance_ascii_for_test("xref\n0 ")
  let header_position = acceptance_find_bytes_for_test(bytes, header)
  if header_position < 0 {
    fail("expected first classic xref subsection header")
  }
  let mut header_end = header_position + header.length()
  while header_end < bytes.length() && bytes[header_end] != b'\n' {
    header_end += 1
  }
  let row_start = header_end + 1 + object_number * 20
  let marker_position = row_start + 17
  if marker_position >= bytes.length() || bytes[marker_position] != b'n' {
    fail("expected in-use classic xref entry")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  output[marker_position] = b'f'
  Bytes::from_array(output)
}

///|
fn acceptance_parse_positive_decimal_for_test(
  bytes : BytesView,
  start : Int,
  end : Int,
) -> Int raise {
  if start >= end {
    fail("expected decimal digits")
  }
  let mut value = 0
  for index in start..<end {
    let byte = bytes[index].to_int()
    if byte < 48 || byte > 57 {
      fail("expected decimal digit")
    }
    value = value * 10 + byte - 48
  }
  value
}

///|
fn acceptance_keep_catalog_and_encrypt_xref_entries_for_test(
  bytes : @pdflite.PdfBytes,
  encrypt_object_number : Int,
) -> @pdflite.PdfBytes raise {
  let header = acceptance_ascii_for_test("xref\n0 ")
  let header_position = acceptance_find_bytes_for_test(bytes, header)
  if header_position < 0 {
    fail("expected first classic xref subsection header")
  }
  if encrypt_object_number <= 1 {
    fail("expected encryption object after catalog")
  }
  let count_start = header_position + header.length()
  let mut count_end = count_start
  while count_end < bytes.length() && bytes[count_end] != b'\n' {
    count_end += 1
  }
  let original_count = acceptance_parse_positive_decimal_for_test(
    bytes, count_start, count_end,
  )
  if encrypt_object_number >= original_count {
    fail("expected encryption object xref row")
  }
  let rows_start = count_end + 1
  let rows_end = rows_start + original_count * 20
  let encrypt_row_start = rows_start + encrypt_object_number * 20
  let encrypt_row_end = encrypt_row_start + 20
  if rows_end > bytes.length() || encrypt_row_end > rows_end {
    fail("expected complete classic xref rows")
  }
  let output : Array[Byte] = []
  for index in 0..<(header_position + 5) {
    output.push(bytes[index])
  }
  acceptance_push_ascii_for_test(output, "0 2\n")
  for index in rows_start..<(rows_start + 40) {
    output.push(bytes[index])
  }
  acceptance_push_ascii_for_test(output, encrypt_object_number.to_string())
  acceptance_push_ascii_for_test(output, " 1\n")
  for index in encrypt_row_start..<encrypt_row_end {
    output.push(bytes[index])
  }
  for index in rows_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn acceptance_corrupt_first_xref_subsection_count_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes raise {
  let header = acceptance_ascii_for_test("xref\n0 ")
  let header_position = acceptance_find_bytes_for_test(bytes, header)
  if header_position < 0 {
    fail("expected first classic xref subsection header")
  }
  let count_start = header_position + header.length()
  let mut count_end = count_start
  while count_end < bytes.length() && bytes[count_end] != b'\n' {
    count_end += 1
  }
  if count_end == count_start {
    fail("expected first classic xref subsection count")
  }
  let output : Array[Byte] = []
  for index in 0..<count_start {
    output.push(bytes[index])
  }
  acceptance_push_ascii_for_test(output, "/Bad")
  for index in count_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn acceptance_corrupt_startxref_pointer_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes raise {
  let marker = acceptance_ascii_for_test("startxref\n")
  let marker_position = acceptance_find_last_bytes_for_test(bytes, marker)
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
  acceptance_push_ascii_for_test(output, (bytes.length() + 4096).to_string())
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn acceptance_insert_ascii_before_last_marker_for_test(
  bytes : @pdflite.PdfBytes,
  marker : BytesView,
  insertion : String,
) -> @pdflite.PdfBytes raise {
  let marker_position = acceptance_find_last_bytes_for_test(bytes, marker)
  if marker_position < 0 {
    fail("expected insertion marker")
  }
  let output : Array[Byte] = []
  for index in 0..<marker_position {
    output.push(bytes[index])
  }
  acceptance_push_ascii_for_test(output, insertion)
  for index in marker_position..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn acceptance_push_big_endian_for_test(
  output : Array[Byte],
  value : Int,
  width : Int,
) -> Unit {
  let mut divisor = 1
  if width > 1 {
    for _ in 1..<width {
      divisor *= 256
    }
  }
  let mut remaining_divisor = divisor
  while remaining_divisor > 0 {
    acceptance_push_byte_for_test(output, value / remaining_divisor % 256)
    remaining_divisor /= 256
  }
}

///|
fn acceptance_push_padded_decimal_for_test(
  output : Array[Byte],
  value : Int,
  width : Int,
) -> Unit {
  let text = value.to_string()
  if text.length() < width {
    for _ in 0..<(width - text.length()) {
      acceptance_push_byte_for_test(output, 48)
    }
  }
  acceptance_push_ascii_for_test(output, text)
}

///|
fn acceptance_push_xref_stream_entry_for_test(
  output : Array[Byte],
  kind : Int,
  field2 : Int,
  field3 : Int,
) -> Unit {
  acceptance_push_byte_for_test(output, kind)
  acceptance_push_big_endian_for_test(output, field2, 4)
  acceptance_push_big_endian_for_test(output, field3, 2)
}

///|
fn acceptance_push_xref_entry_for_test(
  output : Array[Byte],
  offset : Int,
  generation : Int,
) -> Unit {
  acceptance_push_padded_decimal_for_test(output, offset, 10)
  acceptance_push_byte_for_test(output, 32)
  acceptance_push_padded_decimal_for_test(output, generation, 5)
  acceptance_push_ascii_for_test(output, " n \n")
}

///|
fn acceptance_push_indirect_object_for_test(
  output : Array[Byte],
  number : Int,
  generation : Int,
  body : String,
) -> Int {
  let offset = output.length()
  acceptance_push_ascii_for_test(output, number.to_string())
  acceptance_push_byte_for_test(output, 32)
  acceptance_push_ascii_for_test(output, generation.to_string())
  acceptance_push_ascii_for_test(output, " obj\n")
  acceptance_push_ascii_for_test(output, body)
  acceptance_push_ascii_for_test(output, "\nendobj\n")
  offset
}

///|
fn acceptance_one_page_ops_for_test() -> Array[@pdflite.PdfContentOp] {
  [
    Op_cm(@pdflite.transform_translate(50.0, 770.0)),
    Op_BT,
    Op_Tf(acceptance_name_for_test("/F0"), 36.0),
    Op_Tj(acceptance_ascii_for_test("Hello, World!")),
    Op_ET,
  ]
}

///|
fn acceptance_text_page_ops_for_test(
  text : String,
) -> Array[@pdflite.PdfContentOp] {
  [
    Op_BT,
    Op_Tf(acceptance_name_for_test("/F0"), 12.0),
    Op_Tj(acceptance_ascii_for_test(text)),
    Op_ET,
  ]
}

///|
fn acceptance_text_page_for_test(text : String) -> @pdflite.PdfPage raise {
  {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops(
        acceptance_text_page_ops_for_test(text),
      ),
    ],
    resources: acceptance_one_page_resources_for_test(),
  }
}

///|
fn acceptance_one_page_resources_for_test() -> @pdflite.PdfObject {
  let type_name = acceptance_name_for_test("/Type")
  let subtype = acceptance_name_for_test("/Subtype")
  let basefont = acceptance_name_for_test("/BaseFont")
  let font = @pdflite.pdf_dictionary([
    (type_name, PdfNameObject(acceptance_name_for_test("/Font"))),
    (subtype, PdfNameObject(acceptance_name_for_test("/Type1"))),
    (basefont, PdfNameObject(acceptance_name_for_test("/Times-Italic"))),
  ])
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([(acceptance_name_for_test("/F0"), font)]),
    ),
  ])
}

///|
fn acceptance_partial_filter_stream_for_test() -> @pdflite.PdfObject {
  let encoded = @pdflite.pdf_ascii_hex_encode(acceptance_ascii_for_test("Hi"))
  let unsupported : @pdflite.PdfObject = PdfNameObject(
    acceptance_name_for_test("/NoSuchFilter"),
  )
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
      (
        acceptance_name_for_test("/Filter"),
        PdfArray([
          PdfNameObject(acceptance_name_for_test("/ASCIIHexDecode")),
          unsupported,
        ]),
      ),
      (acceptance_name_for_test("/DecodeParms"), PdfArray([PdfNull, PdfNull])),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_one_page_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops(acceptance_one_page_ops_for_test()),
    ],
    resources: acceptance_one_page_resources_for_test(),
  }
  let page_root = doc.add_pagetree([page])
  ignore(
    doc.add_root(page_root, [
      (
        acceptance_name_for_test("/Lang"),
        PdfString(acceptance_ascii_for_test("en-US")),
      ),
    ]),
  )
  doc.add_object_given_number(50, acceptance_partial_filter_stream_for_test())
  doc
}

///|
fn acceptance_split_content_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let ops = acceptance_one_page_ops_for_test()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops(ops[0:3]),
      @pdflite.pdf_content_stream_of_ops(ops[3:ops.length()]),
    ],
    resources: acceptance_one_page_resources_for_test(),
  }
  let page_root = doc.add_pagetree([page])
  ignore(
    doc.add_root(page_root, [
      (
        acceptance_name_for_test("/Lang"),
        PdfString(acceptance_ascii_for_test("en-US")),
      ),
    ]),
  )
  doc.add_object_given_number(
    77,
    PdfString(acceptance_ascii_for_test("pdftest-stale-object")),
  )
  doc
}

///|
fn acceptance_pdftest_rewrite_document_for_test(
  doc : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let rewritten_pages : Array[@pdflite.PdfPage] = []
  for page in doc.pages_of_pagetree() {
    let parsed_ops = doc.parse_content_ops(page.content)
    rewritten_pages.push({
      ..page,
      content: [@pdflite.pdf_content_stream_of_ops(parsed_ops)],
    })
  }
  let changed = doc.change_pages(rewritten_pages)
  changed.remove_unreferenced()
  changed
}

///|
fn acceptance_font_object_for_test(
  resources : @pdflite.PdfObject,
) -> @pdflite.PdfObject raise {
  let fonts = match
    resources.lookup_immediate(acceptance_name_for_test("/Font")) {
    Some(fonts) => fonts
    None => fail("expected page font resources")
  }
  match fonts.lookup_immediate(acceptance_name_for_test("/F0")) {
    Some(font) => font
    None => fail("expected /F0 font")
  }
}

///|
fn acceptance_assert_one_page_invariants_for_test(
  doc : @pdflite.PdfDocument,
  expected_version : (Int, Int),
) -> Unit raise {
  @test.assert_eq(doc.version(), expected_version)
  @test.assert_eq(doc.root() > 0, true)
  @test.assert_eq(try! doc.endpage(), 1)
  let catalog = doc.catalog()
  @test.assert_eq(
    catalog.lookup_immediate(acceptance_name_for_test("/Lang")),
    Some(PdfString(acceptance_ascii_for_test("en-US"))),
  )
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    doc.parse_content_ops(pages[0].content),
    acceptance_one_page_ops_for_test(),
  )
  let font_object = acceptance_font_object_for_test(pages[0].resources)
  @test.assert_eq(
    doc.read_font(font_object),
    PdfFontStandard({ font: PdfTimesItalic, encoding: PdfImplicitInFontFile }),
  )
  let extractor = doc.text_extractor_of_font(font_object)
  @test.assert_eq(
    extractor.codepoints_of_text(acceptance_ascii_for_test("Hello, World!")),
    [72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 33],
  )
}

///|
fn acceptance_text_bytes_for_test(
  values : ArrayView[Int],
) -> @pdflite.PdfBytes raise {
  @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn acceptance_tounicode_text_document_for_test() -> @pdflite.PdfDocument raise {
  let cmap = acceptance_ascii_for_test(
    "1 begincodespacerange\n" +
    "<00><FF>\n" +
    "endcodespacerange\n" +
    "1 beginbfchar\n" +
    "<41><005A>\n" +
    "endbfchar\n" +
    "1 beginbfrange\n" +
    "<43><44><0061>\n" +
    "endbfrange\n",
  )
  let encoded = @pdflite.pdf_ascii_hex_encode(cmap)
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    61,
    PdfNameObject(acceptance_name_for_test("/ASCIIHexDecode")),
  )
  doc.add_object_given_number(
    60,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
        (acceptance_name_for_test("/Filter"), PdfIndirect(61)),
      ]),
      StreamGot(encoded),
    ),
  )
  let font = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type1")),
    ),
    (
      acceptance_name_for_test("/BaseFont"),
      PdfNameObject(acceptance_name_for_test("/Custom")),
    ),
    (acceptance_name_for_test("/ToUnicode"), PdfIndirect(60)),
  ])
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([(acceptance_name_for_test("/F0"), font)]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/F0"), 12.0),
        Op_Tj(acceptance_text_bytes_for_test([65, 66])),
        Op_TJ(
          PdfArray([
            PdfString(acceptance_text_bytes_for_test([67])),
            PdfInteger(-20),
            PdfString(acceptance_text_bytes_for_test([68])),
          ]),
        ),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(
    doc.add_root(page_root, [
      (
        acceptance_name_for_test("/Lang"),
        PdfString(acceptance_ascii_for_test("en-US")),
      ),
    ]),
  )
  doc
}

///|
fn acceptance_push_text_codepoints_for_test(
  output : Array[Int],
  extractor : @pdflite.PdfTextExtractor,
  text : @pdflite.PdfBytes,
) -> Unit raise {
  for codepoint in extractor.codepoints_of_text(text) {
    output.push(codepoint)
  }
}

///|
fn acceptance_text_codepoints_of_first_page_for_test(
  doc : @pdflite.PdfDocument,
) -> Array[Int] raise {
  let pages = doc.pages_of_pagetree()
  let font = acceptance_font_object_for_test(pages[0].resources)
  let extractor = doc.text_extractor_of_font(font)
  let output : Array[Int] = []
  for op in doc.parse_content_ops(pages[0].content) {
    match op {
      Op_Tj(text) =>
        acceptance_push_text_codepoints_for_test(output, extractor, text)
      Op_TJ(PdfArray(items)) =>
        for item in items {
          match item {
            PdfString(text) =>
              acceptance_push_text_codepoints_for_test(output, extractor, text)
            _ => ()
          }
        }
      _ => ()
    }
  }
  output
}

///|
fn acceptance_assert_tounicode_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  @test.assert_eq(acceptance_text_codepoints_of_first_page_for_test(doc), [
    0x5A, 66, 0x61, 0x62,
  ])
  let pages = doc.pages_of_pagetree()
  let font = acceptance_font_object_for_test(pages[0].resources)
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(extractor.charcode_of_codepoint(0x5A), Some(65))
  @test.assert_eq(extractor.charcode_of_codepoint(0x61), Some(67))
}

///|
fn acceptance_tounicode_variation_cmap_for_test() -> @pdflite.PdfObject {
  let cmap = acceptance_ascii_for_test(
    "1 begincodespacerange\n" +
    "<00><FF>\n" +
    "endcodespacerange\n" +
    "1 beginbfchar\n" +
    "<41><D834DD1E>\n" +
    "endbfchar\n" +
    "2 beginbfrange\n" +
    "<42><44>[<0061><00620063><D83DDE00>]\n" +
    "<45><46><0064>\n" +
    "endbfrange\n",
  )
  let encoded = @pdflite.pdf_flate_encode(cmap)
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_tounicode_variation_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    62,
    acceptance_tounicode_variation_cmap_for_test(),
  )
  let font = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type1")),
    ),
    (
      acceptance_name_for_test("/BaseFont"),
      PdfNameObject(acceptance_name_for_test("/VariationFont")),
    ),
    (acceptance_name_for_test("/ToUnicode"), PdfIndirect(62)),
  ])
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([(acceptance_name_for_test("/FVar"), font)]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/FVar"), 12.0),
        Op_Tj(acceptance_text_bytes_for_test([65, 66, 67])),
        Op_TJ(
          PdfArray([
            PdfString(acceptance_text_bytes_for_test([68])),
            PdfInteger(-20),
            PdfString(acceptance_text_bytes_for_test([69, 70, 71])),
          ]),
        ),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_assert_tounicode_variation_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  @test.assert_eq(
    acceptance_font_codepoints_of_first_page_for_test(
      doc,
      acceptance_name_for_test("/FVar"),
    ),
    [0x1D11E, 0x61, 0x62, 0x63, 0x1F600, 0x64, 0x65, 71],
  )
  let pages = doc.pages_of_pagetree()
  let font = acceptance_font_object_by_name_for_test(
    pages[0].resources,
    acceptance_name_for_test("/FVar"),
  )
  guard doc.read_font(font) is PdfFontSimple(simple) else {
    fail("expected simple font with ToUnicode variations")
  }
  guard simple.fontdescriptor is Some(descriptor) else {
    fail("expected descriptor carrying variation ToUnicode")
  }
  @test.assert_eq(
    descriptor.tounicode,
    Some([
      (65, acceptance_text_bytes_for_test([0xD8, 0x34, 0xDD, 0x1E])),
      (66, acceptance_text_bytes_for_test([0x00, 0x61])),
      (67, acceptance_text_bytes_for_test([0x00, 0x62, 0x00, 0x63])),
      (68, acceptance_text_bytes_for_test([0xD8, 0x3D, 0xDE, 0x00])),
      (69, acceptance_text_bytes_for_test([0x00, 0x64])),
      (70, acceptance_text_bytes_for_test([0x00, 0x65])),
    ]),
  )
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(extractor.charcode_of_codepoint(0x1D11E), Some(65))
  @test.assert_eq(extractor.charcode_of_codepoint(0x61), Some(66))
  @test.assert_eq(extractor.charcode_of_codepoint(0x1F600), Some(68))
  @test.assert_eq(extractor.charcode_of_codepoint(0x62), None)
}

///|
fn acceptance_tounicode_parser_corner_cmap_for_test() -> @pdflite.PdfObject {
  let cmap = acceptance_ascii_for_test(
    "% /Identity-H usecmap\n" +
    "/WMode 1 def % /WMode 0 def\n" +
    "2 beginbfchar\n" +
    "<41>\n" +
    "<00 5A>\n" +
    "<4><006> % odd nibbles are padded\n" +
    "endbfchar\n" +
    "3 beginbfrange\n" +
    "<43><45>[\n" +
    "<0061>\n" +
    "<00620063> % multi-codepoint mapping\n" +
    "<D834 DD1E>\n" +
    "]\n" +
    "<46><47><0064>\n" +
    "<48><49>[<0066> % <9999>\n" +
    "<0067>]\n" +
    "endbfrange\n" +
    "1 beginbfchar <4A><03A9> endbfchar\n",
  )
  let encoded = @pdflite.pdf_flate_encode(cmap)
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_tounicode_parser_corner_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    64,
    acceptance_tounicode_parser_corner_cmap_for_test(),
  )
  let font = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type1")),
    ),
    (
      acceptance_name_for_test("/BaseFont"),
      PdfNameObject(acceptance_name_for_test("/ParserCornerFont")),
    ),
    (acceptance_name_for_test("/ToUnicode"), PdfIndirect(64)),
  ])
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([(acceptance_name_for_test("/FCorner"), font)]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/FCorner"), 12.0),
        Op_Tj(
          acceptance_text_bytes_for_test([
            0x41, 0x40, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B,
          ]),
        ),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_assert_tounicode_parser_corner_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  @test.assert_eq(
    acceptance_font_codepoints_of_first_page_for_test(
      doc,
      acceptance_name_for_test("/FCorner"),
    ),
    [
      0x5A, 0x60, 0x61, 0x62, 0x63, 0x1D11E, 0x64, 0x65, 0x66, 0x67, 0x03A9, 0x4B,
    ],
  )
  let pages = doc.pages_of_pagetree()
  let font = acceptance_font_object_by_name_for_test(
    pages[0].resources,
    acceptance_name_for_test("/FCorner"),
  )
  guard doc.read_font(font) is PdfFontSimple(simple) else {
    fail("expected simple font with parser-corner ToUnicode")
  }
  guard simple.fontdescriptor is Some(descriptor) else {
    fail("expected descriptor carrying parser-corner ToUnicode")
  }
  @test.assert_eq(
    descriptor.tounicode,
    Some([
      (0x41, acceptance_text_bytes_for_test([0x00, 0x5A])),
      (0x40, acceptance_text_bytes_for_test([0x00, 0x60])),
      (0x43, acceptance_text_bytes_for_test([0x00, 0x61])),
      (0x44, acceptance_text_bytes_for_test([0x00, 0x62, 0x00, 0x63])),
      (0x45, acceptance_text_bytes_for_test([0xD8, 0x34, 0xDD, 0x1E])),
      (0x46, acceptance_text_bytes_for_test([0x00, 0x64])),
      (0x47, acceptance_text_bytes_for_test([0x00, 0x65])),
      (0x48, acceptance_text_bytes_for_test([0x00, 0x66])),
      (0x49, acceptance_text_bytes_for_test([0x00, 0x67])),
      (0x4A, acceptance_text_bytes_for_test([0x03, 0xA9])),
    ]),
  )
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(extractor.charcode_of_codepoint(0x5A), Some(0x41))
  @test.assert_eq(extractor.charcode_of_codepoint(0x60), Some(0x40))
  @test.assert_eq(extractor.charcode_of_codepoint(0x1D11E), Some(0x45))
  @test.assert_eq(extractor.charcode_of_codepoint(0x67), Some(0x49))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03A9), Some(0x4A))
  @test.assert_eq(extractor.charcode_of_codepoint(0x62), None)
}

///|
fn acceptance_tounicode_sequence_cmap_for_test() -> @pdflite.PdfObject {
  let cmap = acceptance_ascii_for_test(
    "/CIDInit /ProcSet findresource begin\n" +
    "12 dict begin\n" +
    "begincmap\n" +
    "/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) /Supplement 0 >> def\n" +
    "/CMapName /Adobe-Identity-UCS def\n" +
    "/CMapType 2 def\n" +
    "2 begincodespacerange\n" +
    "<0000><00FF>\n" +
    "<0100><01FF>\n" +
    "endcodespacerange\n" +
    "4 beginbfchar\n" +
    "<0020><0020>\n" +
    "<0021><00660069>\n" +
    "<0022><00650301>\n" +
    "<0023><4E00FE00>\n" +
    "endbfchar\n" +
    "2 beginbfrange\n" +
    "<00FE><0101><0061>\n" +
    "<0102><0104>[<D83DDE00><D83DDC69><D83DDC69 200D D83DDCBB>]\n" +
    "endbfrange\n" +
    "endcmap\n" +
    "CMapName currentdict /CMap defineresource pop\n" +
    "end\n" +
    "end\n",
  )
  let encoded = @pdflite.pdf_flate_encode(cmap)
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_tounicode_sequence_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    72,
    acceptance_identity_h_descendant_font_for_test(),
  )
  doc.add_object_given_number(74, acceptance_tounicode_sequence_cmap_for_test())
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/Fseq"),
          acceptance_identity_h_font_for_test().add_dict_entry(
            acceptance_name_for_test("/ToUnicode"),
            PdfIndirect(74),
          ),
        ),
      ]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/Fseq"), 14.0),
        Op_Tj(
          acceptance_text_bytes_for_test([
            0x00, 0x20, 0x00, 0x21, 0x00, 0x22, 0x00, 0x23,
          ]),
        ),
        Op_TJ(
          PdfArray([
            PdfString(acceptance_text_bytes_for_test([0x00, 0xFE, 0x00, 0xFF])),
            PdfInteger(-30),
            PdfString(
              acceptance_text_bytes_for_test([
                0x01, 0x00, 0x01, 0x01, 0x01, 0x02, 0x01, 0x03, 0x01, 0x04, 0x01,
                0x05,
              ]),
            ),
          ]),
        ),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_assert_tounicode_sequence_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  @test.assert_eq(
    acceptance_font_codepoints_of_first_page_for_test(
      doc,
      acceptance_name_for_test("/Fseq"),
    ),
    [
      0x20, 0x66, 0x69, 0x65, 0x0301, 0x4E00, 0xFE00, 0x61, 0x62, 0x63, 0x64, 0x1F600,
      0x1F469, 0x1F469, 0x200D, 0x1F4BB, 0x0105,
    ],
  )
  let pages = doc.pages_of_pagetree()
  let font = acceptance_font_object_by_name_for_test(
    pages[0].resources,
    acceptance_name_for_test("/Fseq"),
  )
  let read = doc.read_font(font)
  @test.assert_eq(read.is_identity_h(), true)
  @test.assert_eq(read.uses_two_byte_codes(), true)
  guard read is PdfFontCIDKeyed(cid_font) else {
    fail("expected CID-keyed font with ToUnicode sequences")
  }
  @test.assert_eq(
    cid_font.composite.cid_fontdescriptor.tounicode,
    Some([
      (0x0020, acceptance_text_bytes_for_test([0x00, 0x20])),
      (0x0021, acceptance_text_bytes_for_test([0x00, 0x66, 0x00, 0x69])),
      (0x0022, acceptance_text_bytes_for_test([0x00, 0x65, 0x03, 0x01])),
      (0x0023, acceptance_text_bytes_for_test([0x4E, 0x00, 0xFE, 0x00])),
      (0x00FE, acceptance_text_bytes_for_test([0x00, 0x61])),
      (0x00FF, acceptance_text_bytes_for_test([0x00, 0x62])),
      (0x0100, acceptance_text_bytes_for_test([0x00, 0x63])),
      (0x0101, acceptance_text_bytes_for_test([0x00, 0x64])),
      (0x0102, acceptance_text_bytes_for_test([0xD8, 0x3D, 0xDE, 0x00])),
      (0x0103, acceptance_text_bytes_for_test([0xD8, 0x3D, 0xDC, 0x69])),
      (
        0x0104,
        acceptance_text_bytes_for_test([
          0xD8, 0x3D, 0xDC, 0x69, 0x20, 0x0D, 0xD8, 0x3D, 0xDC, 0xBB,
        ]),
      ),
    ]),
  )
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(extractor.charcode_of_codepoint(0x20), Some(0x0020))
  @test.assert_eq(extractor.charcode_of_codepoint(0x61), Some(0x00FE))
  @test.assert_eq(extractor.charcode_of_codepoint(0x64), Some(0x0101))
  @test.assert_eq(extractor.charcode_of_codepoint(0x1F600), Some(0x0102))
  @test.assert_eq(extractor.charcode_of_codepoint(0x1F469), Some(0x0103))
  @test.assert_eq(extractor.charcode_of_codepoint(0x66), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0xFE00), None)
  @test.assert_eq(extractor.charcode_of_codepoint(0x0105), None)
}

///|
fn acceptance_type3_tounicode_stream_for_test() -> @pdflite.PdfObject {
  let cmap = acceptance_ascii_for_test(
    "1 begincodespacerange\n" +
    "<00><FF>\n" +
    "endcodespacerange\n" +
    "2 beginbfchar\n" +
    "<41><2603>\n" +
    "<42><03A9>\n" +
    "endbfchar\n",
  )
  let encoded = @pdflite.pdf_flate_encode(cmap)
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_type3_charproc_stream_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> @pdflite.PdfObject raise {
  let data = @pdflite.pdf_content_bytes_of_ops(ops)
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn acceptance_type3_glyph_inline_dictionary_for_test() -> @pdflite.PdfObject {
  PdfDictionary([
    (acceptance_name_for_test("/W"), PdfInteger(2)),
    (acceptance_name_for_test("/H"), PdfInteger(1)),
    (
      acceptance_name_for_test("/CS"),
      PdfNameObject(acceptance_name_for_test("/GlyphGray")),
    ),
    (acceptance_name_for_test("/BPC"), PdfInteger(1)),
  ])
}

///|
fn acceptance_type3_glyph_inline_data_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([0x80])
}

///|
fn acceptance_type3_resource_charproc_ops_for_test() -> Array[
  @pdflite.PdfContentOp,
] raise {
  [
    Op_d0(550.0, 0.0),
    Op_Do(acceptance_name_for_test("/GlyphMark")),
    Op_InlineImage(
      acceptance_type3_glyph_inline_dictionary_for_test(),
      None,
      acceptance_type3_glyph_inline_data_for_test(),
    ),
  ]
}

///|
fn acceptance_type3_glyph_mark_xobject_for_test() -> @pdflite.PdfObject {
  let data = acceptance_ascii_for_test("q Q")
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Form")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn acceptance_type3_font_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type3")),
    ),
    (
      acceptance_name_for_test("/FontBBox"),
      PdfArray([
        PdfInteger(0),
        PdfInteger(-20),
        PdfInteger(600),
        PdfInteger(700),
      ]),
    ),
    (
      acceptance_name_for_test("/FontMatrix"),
      PdfArray([
        PdfReal(0.001),
        PdfInteger(0),
        PdfInteger(0),
        PdfReal(0.001),
        PdfInteger(0),
        PdfInteger(0),
      ]),
    ),
    (
      acceptance_name_for_test("/CharProcs"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/A"), PdfIndirect(64)),
        (acceptance_name_for_test("/B"), PdfIndirect(65)),
        (acceptance_name_for_test("/C"), PdfIndirect(66)),
      ]),
    ),
    (
      acceptance_name_for_test("/Resources"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/ProcSet"),
          PdfArray([PdfNameObject(acceptance_name_for_test("/PDF"))]),
        ),
        (
          acceptance_name_for_test("/ColorSpace"),
          @pdflite.pdf_dictionary([
            (
              acceptance_name_for_test("/GlyphGray"),
              PdfNameObject(acceptance_name_for_test("/DeviceGray")),
            ),
          ]),
        ),
        (
          acceptance_name_for_test("/XObject"),
          @pdflite.pdf_dictionary([
            (acceptance_name_for_test("/GlyphMark"), PdfIndirect(67)),
          ]),
        ),
      ]),
    ),
    (acceptance_name_for_test("/FirstChar"), PdfInteger(65)),
    (acceptance_name_for_test("/LastChar"), PdfInteger(67)),
    (
      acceptance_name_for_test("/Widths"),
      PdfArray([PdfInteger(500), PdfInteger(600), PdfInteger(550)]),
    ),
    (acceptance_name_for_test("/MissingWidth"), PdfInteger(250)),
    (
      acceptance_name_for_test("/Encoding"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/Differences"),
          PdfArray([
            PdfInteger(65),
            PdfNameObject(acceptance_name_for_test("/A")),
            PdfNameObject(acceptance_name_for_test("/B")),
            PdfNameObject(acceptance_name_for_test("/C")),
          ]),
        ),
      ]),
    ),
    (acceptance_name_for_test("/ToUnicode"), PdfIndirect(63)),
  ])
}

///|
fn acceptance_type3_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(63, acceptance_type3_tounicode_stream_for_test())
  doc.add_object_given_number(
    64,
    acceptance_type3_charproc_stream_for_test([Op_d0(500.0, 0.0)]),
  )
  doc.add_object_given_number(
    65,
    acceptance_type3_charproc_stream_for_test([
      Op_d1(600.0, 0.0, 0.0, -20.0, 600.0, 700.0),
    ]),
  )
  doc.add_object_given_number(
    66,
    acceptance_type3_charproc_stream_for_test(
      acceptance_type3_resource_charproc_ops_for_test(),
    ),
  )
  doc.add_object_given_number(
    67,
    acceptance_type3_glyph_mark_xobject_for_test(),
  )
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/Ft3"), acceptance_type3_font_for_test()),
      ]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/Ft3"), 12.0),
        Op_Tj(acceptance_text_bytes_for_test([65, 66])),
        Op_TJ(
          PdfArray([
            PdfString(acceptance_text_bytes_for_test([67])),
            PdfInteger(-20),
            PdfString(acceptance_text_bytes_for_test([65])),
          ]),
        ),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_assert_type3_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font = acceptance_font_object_by_name_for_test(
    pages[0].resources,
    acceptance_name_for_test("/Ft3"),
  )
  guard doc.read_font(font) is PdfFontSimple(simple) else {
    fail("expected simple Type3 font")
  }
  guard simple.fonttype is PdfType3(type3_data) else {
    fail("expected Type3 data")
  }
  @test.assert_eq(type3_data.fontbbox, {
    min_x: 0.0,
    min_y: -20.0,
    max_x: 600.0,
    max_y: 700.0,
  })
  @test.assert_eq(type3_data.fontmatrix, {
    a: 0.001,
    b: 0.0,
    c: 0.0,
    d: 0.001,
    e: 0.0,
    f: 0.0,
  })
  @test.assert_eq(type3_data.charprocs, [
    (acceptance_name_for_test("/A"), PdfIndirect(64)),
    (acceptance_name_for_test("/B"), PdfIndirect(65)),
    (acceptance_name_for_test("/C"), PdfIndirect(66)),
  ])
  @test.assert_eq(
    type3_data.resources,
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/ProcSet"),
        PdfArray([PdfNameObject(acceptance_name_for_test("/PDF"))]),
      ),
      (
        acceptance_name_for_test("/ColorSpace"),
        @pdflite.pdf_dictionary([
          (
            acceptance_name_for_test("/GlyphGray"),
            PdfNameObject(acceptance_name_for_test("/DeviceGray")),
          ),
        ]),
      ),
      (
        acceptance_name_for_test("/XObject"),
        @pdflite.pdf_dictionary([
          (acceptance_name_for_test("/GlyphMark"), PdfIndirect(67)),
        ]),
      ),
    ]),
  )
  @test.assert_eq(
    doc.parse_content_ops_with_resources(type3_data.resources, [
      doc.direct(PdfIndirect(66)),
    ]),
    acceptance_type3_resource_charproc_ops_for_test(),
  )
  guard doc.direct(PdfIndirect(67)) is PdfStreamObject(glyph_mark) else {
    fail("expected Type3 glyph XObject resource")
  }
  @test.assert_eq(
    @pdflite.pdf_stream(glyph_mark.dictionary, glyph_mark.data).stream_bytes(),
    acceptance_ascii_for_test("q Q"),
  )
  guard simple.fontmetrics is Some(metrics) else {
    fail("expected Type3 font metrics")
  }
  @test.assert_eq(metrics[64], 250.0)
  @test.assert_eq(metrics[65], 500.0)
  @test.assert_eq(metrics[66], 600.0)
  @test.assert_eq(metrics[67], 550.0)
  guard simple.fontdescriptor is Some(descriptor) else {
    fail("expected fabricated descriptor carrying ToUnicode")
  }
  @test.assert_eq(
    descriptor.tounicode,
    Some([
      (65, acceptance_text_bytes_for_test([0x26, 0x03])),
      (66, acceptance_text_bytes_for_test([0x03, 0xA9])),
    ]),
  )
  @test.assert_eq(
    @pdflite.pdf_parse_content_ops_from_bytes(
      doc.direct(PdfIndirect(64)).stream_bytes(),
    ),
    [Op_d0(500.0, 0.0)],
  )
  @test.assert_eq(
    @pdflite.pdf_parse_content_ops_from_bytes(
      doc.direct(PdfIndirect(65)).stream_bytes(),
    ),
    [Op_d1(600.0, 0.0, 0.0, -20.0, 600.0, 700.0)],
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_first_page_for_test(
      doc,
      acceptance_name_for_test("/Ft3"),
    ),
    [0x2603, 0x03A9, 67, 0x2603],
  )
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(extractor.charcode_of_codepoint(0x2603), Some(65))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03A9), Some(66))
}

///|
fn acceptance_type3_form_charproc_ops_for_test() -> Array[@pdflite.PdfContentOp] {
  [Op_d0(500.0, 0.0), Op_Do(acceptance_name_for_test("/GlyphForm"))]
}

///|
fn acceptance_type3_form_xobject_ops_for_test() -> Array[@pdflite.PdfContentOp] {
  [Op_Do(acceptance_name_for_test("/NestedImage"))]
}

///|
fn acceptance_type3_form_xobject_resources_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/XObject"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/NestedImage"), PdfIndirect(178)),
      ]),
    ),
  ])
}

///|
fn acceptance_type3_form_xobject_for_test() -> @pdflite.PdfObject raise {
  let data = @pdflite.pdf_content_bytes_of_ops(
    acceptance_type3_form_xobject_ops_for_test(),
  )
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Form")),
      ),
      (
        acceptance_name_for_test("/BBox"),
        PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(4), PdfInteger(1)]),
      ),
      (
        acceptance_name_for_test("/Resources"),
        acceptance_type3_form_xobject_resources_for_test(),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn acceptance_type3_form_font_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type3")),
    ),
    (
      acceptance_name_for_test("/FontBBox"),
      PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(500), PdfInteger(500)]),
    ),
    (
      acceptance_name_for_test("/FontMatrix"),
      PdfArray([
        PdfReal(0.001),
        PdfInteger(0),
        PdfInteger(0),
        PdfReal(0.001),
        PdfInteger(0),
        PdfInteger(0),
      ]),
    ),
    (
      acceptance_name_for_test("/CharProcs"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/GlyphNested"), PdfIndirect(176)),
      ]),
    ),
    (
      acceptance_name_for_test("/Resources"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/ProcSet"),
          PdfArray([
            PdfNameObject(acceptance_name_for_test("/PDF")),
            PdfNameObject(acceptance_name_for_test("/ImageC")),
          ]),
        ),
        (
          acceptance_name_for_test("/XObject"),
          @pdflite.pdf_dictionary([
            (acceptance_name_for_test("/GlyphForm"), PdfIndirect(177)),
          ]),
        ),
      ]),
    ),
    (acceptance_name_for_test("/FirstChar"), PdfInteger(65)),
    (acceptance_name_for_test("/LastChar"), PdfInteger(65)),
    (acceptance_name_for_test("/Widths"), PdfArray([PdfInteger(500)])),
    (
      acceptance_name_for_test("/Encoding"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/Differences"),
          PdfArray([
            PdfInteger(65),
            PdfNameObject(acceptance_name_for_test("/GlyphNested")),
          ]),
        ),
      ]),
    ),
  ])
}

///|
fn acceptance_type3_form_resource_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    176,
    acceptance_type3_charproc_stream_for_test(
      acceptance_type3_form_charproc_ops_for_test(),
    ),
  )
  doc.add_object_given_number(177, acceptance_type3_form_xobject_for_test())
  doc.add_object_given_number(178, acceptance_image_indexed_xobject_for_test())
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/Ft3Form"),
          acceptance_type3_form_font_for_test(),
        ),
      ]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/Ft3Form"), 12.0),
        Op_Tj(acceptance_text_bytes_for_test([65])),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_assert_type3_form_resource_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font = acceptance_font_object_by_name_for_test(
    pages[0].resources,
    acceptance_name_for_test("/Ft3Form"),
  )
  guard doc.read_font(font) is PdfFontSimple(simple) else {
    fail("expected simple Type3 form-resource font")
  }
  guard simple.fonttype is PdfType3(type3_data) else {
    fail("expected Type3 form-resource data")
  }
  @test.assert_eq(type3_data.charprocs, [
    (acceptance_name_for_test("/GlyphNested"), PdfIndirect(176)),
  ])
  @test.assert_eq(
    doc.parse_content_ops_with_resources(type3_data.resources, [
      doc.direct(PdfIndirect(176)),
    ]),
    acceptance_type3_form_charproc_ops_for_test(),
  )
  let glyph_form = acceptance_image_xobject_for_test(
    doc,
    type3_data.resources,
    acceptance_name_for_test("/GlyphForm"),
  )
  guard glyph_form is PdfStreamObject(form_stream) else {
    fail("expected nested Type3 form XObject")
  }
  guard doc.lookup_direct(acceptance_name_for_test("/Resources"), glyph_form)
    is Some(form_resources) else {
    fail("expected nested Type3 form resources")
  }
  @test.assert_eq(
    doc.parse_content_ops_with_resources(form_resources, [glyph_form]),
    acceptance_type3_form_xobject_ops_for_test(),
  )
  let nested_image = acceptance_image_xobject_for_test(
    doc,
    form_resources,
    acceptance_name_for_test("/NestedImage"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(form_resources, nested_image),
    PdfRawImage(4, 1, PdfBPP24, acceptance_expected_indexed_rgb24_for_test()),
  )
  @test.assert_eq(
    @pdflite.pdf_stream(form_stream.dictionary, form_stream.data).stream_bytes(),
    @pdflite.pdf_content_bytes_of_ops(
      acceptance_type3_form_xobject_ops_for_test(),
    ),
  )
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.glyphnames_of_text(acceptance_text_bytes_for_test([65])),
    [acceptance_name_for_test("/GlyphNested")],
  )
}

///|
fn acceptance_type3_encoded_font_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type3")),
    ),
    (
      acceptance_name_for_test("/FontBBox"),
      PdfArray([
        PdfInteger(0),
        PdfInteger(-20),
        PdfInteger(600),
        PdfInteger(700),
      ]),
    ),
    (
      acceptance_name_for_test("/FontMatrix"),
      PdfArray([
        PdfReal(0.001),
        PdfInteger(0),
        PdfInteger(0),
        PdfReal(0.001),
        PdfInteger(0),
        PdfInteger(0),
      ]),
    ),
    (
      acceptance_name_for_test("/CharProcs"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/A"), PdfIndirect(84)),
        (acceptance_name_for_test("/Omega"), PdfIndirect(85)),
      ]),
    ),
    (
      acceptance_name_for_test("/Resources"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/ProcSet"),
          PdfArray([PdfNameObject(acceptance_name_for_test("/PDF"))]),
        ),
      ]),
    ),
    (acceptance_name_for_test("/FirstChar"), PdfInteger(65)),
    (acceptance_name_for_test("/LastChar"), PdfInteger(66)),
    (
      acceptance_name_for_test("/Widths"),
      PdfArray([PdfInteger(500), PdfInteger(620)]),
    ),
    (acceptance_name_for_test("/MissingWidth"), PdfInteger(250)),
    (
      acceptance_name_for_test("/Encoding"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/Differences"),
          PdfArray([
            PdfInteger(65),
            PdfNameObject(acceptance_name_for_test("/A")),
            PdfNameObject(acceptance_name_for_test("/Omega")),
          ]),
        ),
      ]),
    ),
  ])
}

///|
fn acceptance_type3_encoded_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    84,
    acceptance_type3_charproc_stream_for_test([Op_d0(500.0, 0.0)]),
  )
  doc.add_object_given_number(
    85,
    acceptance_type3_charproc_stream_for_test([
      Op_d1(620.0, 0.0, 0.0, -20.0, 620.0, 700.0),
    ]),
  )
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/Ft3Enc"),
          acceptance_type3_encoded_font_for_test(),
        ),
      ]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/Ft3Enc"), 12.0),
        Op_Tj(acceptance_text_bytes_for_test([65, 66])),
        Op_TJ(
          PdfArray([
            PdfString(acceptance_text_bytes_for_test([67])),
            PdfInteger(-20),
            PdfString(acceptance_text_bytes_for_test([65])),
          ]),
        ),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_assert_type3_encoded_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font = acceptance_font_object_by_name_for_test(
    pages[0].resources,
    acceptance_name_for_test("/Ft3Enc"),
  )
  guard doc.read_font(font) is PdfFontSimple(simple) else {
    fail("expected simple Type3 font")
  }
  guard simple.fonttype is PdfType3(type3_data) else {
    fail("expected Type3 data")
  }
  @test.assert_eq(simple.fontdescriptor, None)
  @test.assert_eq(type3_data.charprocs, [
    (acceptance_name_for_test("/A"), PdfIndirect(84)),
    (acceptance_name_for_test("/Omega"), PdfIndirect(85)),
  ])
  @test.assert_eq(
    @pdflite.pdf_parse_content_ops_from_bytes(
      doc.direct(PdfIndirect(84)).stream_bytes(),
    ),
    [Op_d0(500.0, 0.0)],
  )
  @test.assert_eq(
    @pdflite.pdf_parse_content_ops_from_bytes(
      doc.direct(PdfIndirect(85)).stream_bytes(),
    ),
    [Op_d1(620.0, 0.0, 0.0, -20.0, 620.0, 700.0)],
  )
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      acceptance_text_bytes_for_test([65, 66, 67, 65]),
    ),
    [
      acceptance_name_for_test("/A"),
      acceptance_name_for_test("/Omega"),
      acceptance_name_for_test("/C"),
      acceptance_name_for_test("/A"),
    ],
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_first_page_for_test(
      doc,
      acceptance_name_for_test("/Ft3Enc"),
    ),
    [0x41, 0x2126, 67, 0x41],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x41), Some(65))
  @test.assert_eq(extractor.charcode_of_codepoint(0x2126), Some(66))
}

///|
fn acceptance_type3_fixture_inline_dictionary_for_test() -> @pdflite.PdfObject {
  PdfDictionary([
    (acceptance_name_for_test("/W"), PdfInteger(2)),
    (acceptance_name_for_test("/H"), PdfInteger(1)),
    (
      acceptance_name_for_test("/CS"),
      PdfNameObject(acceptance_name_for_test("/GlyphGray")),
    ),
    (acceptance_name_for_test("/BPC"), PdfInteger(1)),
    (acceptance_name_for_test("/IM"), PdfBoolean(true)),
  ])
}

///|
fn acceptance_type3_fixture_inline_data_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([0x80])
}

///|
fn acceptance_type3_fixture_t_ops_for_test() -> Array[@pdflite.PdfContentOp] raise {
  [
    Op_q,
    Op_cm({ a: 6.0, b: 0.0, c: 0.0, d: 12.0, e: 1.0, f: 2.0 }),
    Op_InlineImage(
      acceptance_type3_fixture_inline_dictionary_for_test(),
      None,
      acceptance_type3_fixture_inline_data_for_test(),
    ),
    Op_Q,
  ]
}

///|
fn acceptance_type3_fixture_font_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type3")),
    ),
    (
      acceptance_name_for_test("/FontBBox"),
      PdfArray([
        PdfInteger(-20),
        PdfInteger(-10),
        PdfInteger(1200),
        PdfInteger(900),
      ]),
    ),
    (
      acceptance_name_for_test("/FontMatrix"),
      PdfArray([
        PdfReal(0.001),
        PdfInteger(0),
        PdfInteger(0),
        PdfReal(0.001),
        PdfInteger(2),
        PdfInteger(3),
      ]),
    ),
    (
      acceptance_name_for_test("/CharProcs"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/E"), PdfIndirect(186)),
        (acceptance_name_for_test("/X"), PdfIndirect(187)),
        (acceptance_name_for_test("/T"), PdfIndirect(188)),
        (acceptance_name_for_test("/I"), PdfIndirect(189)),
      ]),
    ),
    (
      acceptance_name_for_test("/Resources"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/ProcSet"),
          PdfArray([
            PdfNameObject(acceptance_name_for_test("/PDF")),
            PdfNameObject(acceptance_name_for_test("/ImageB")),
          ]),
        ),
        (
          acceptance_name_for_test("/ColorSpace"),
          @pdflite.pdf_dictionary([
            (
              acceptance_name_for_test("/GlyphGray"),
              PdfNameObject(acceptance_name_for_test("/DeviceGray")),
            ),
          ]),
        ),
      ]),
    ),
    (acceptance_name_for_test("/FirstChar"), PdfInteger(1)),
    (acceptance_name_for_test("/LastChar"), PdfInteger(4)),
    (
      acceptance_name_for_test("/Widths"),
      PdfArray([
        PdfInteger(1150),
        PdfInteger(1160),
        PdfInteger(1170),
        PdfInteger(700),
      ]),
    ),
    (acceptance_name_for_test("/MissingWidth"), PdfInteger(99)),
    (
      acceptance_name_for_test("/Encoding"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/Differences"),
          PdfArray([
            PdfInteger(1),
            PdfNameObject(acceptance_name_for_test("/E")),
            PdfNameObject(acceptance_name_for_test("/X")),
            PdfNameObject(acceptance_name_for_test("/T")),
            PdfNameObject(acceptance_name_for_test("/I")),
          ]),
        ),
      ]),
    ),
  ])
}

///|
fn acceptance_type3_fixture_charproc_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    186,
    acceptance_type3_charproc_stream_for_test([Op_d0(1150.0, 0.0)]),
  )
  doc.add_object_given_number(
    187,
    acceptance_type3_charproc_stream_for_test([
      Op_d1(1160.0, 0.0, -20.0, -10.0, 1160.0, 900.0),
    ]),
  )
  doc.add_object_given_number(
    188,
    acceptance_type3_charproc_stream_for_test(
      acceptance_type3_fixture_t_ops_for_test(),
    ),
  )
  doc.add_object_given_number(
    189,
    acceptance_type3_charproc_stream_for_test([Op_d0(700.0, 0.0)]),
  )
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/Ft3Fixture"),
          acceptance_type3_fixture_font_for_test(),
        ),
      ]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/Ft3Fixture"), 12.0),
        Op_Tj(acceptance_text_bytes_for_test([1, 2])),
        Op_TJ(
          PdfArray([
            PdfString(acceptance_text_bytes_for_test([3])),
            PdfInteger(-20),
            PdfString(acceptance_text_bytes_for_test([4])),
          ]),
        ),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_assert_type3_fixture_charprocs_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font = acceptance_font_object_by_name_for_test(
    pages[0].resources,
    acceptance_name_for_test("/Ft3Fixture"),
  )
  guard doc.read_font(font) is PdfFontSimple(simple) else {
    fail("expected simple fixture-shaped Type3 font")
  }
  guard simple.fonttype is PdfType3(type3_data) else {
    fail("expected fixture-shaped Type3 data")
  }
  @test.assert_eq(type3_data.fontbbox, {
    min_x: -20.0,
    min_y: -10.0,
    max_x: 1200.0,
    max_y: 900.0,
  })
  @test.assert_eq(type3_data.fontmatrix, {
    a: 0.001,
    b: 0.0,
    c: 0.0,
    d: 0.001,
    e: 2.0,
    f: 3.0,
  })
  @test.assert_eq([ for charproc in type3_data.charprocs => charproc.0 ], [
    acceptance_name_for_test("/E"),
    acceptance_name_for_test("/X"),
    acceptance_name_for_test("/T"),
    acceptance_name_for_test("/I"),
  ])
  @test.assert_eq(type3_data.charprocs, [
    (acceptance_name_for_test("/E"), PdfIndirect(186)),
    (acceptance_name_for_test("/X"), PdfIndirect(187)),
    (acceptance_name_for_test("/T"), PdfIndirect(188)),
    (acceptance_name_for_test("/I"), PdfIndirect(189)),
  ])
  @test.assert_eq(
    @pdflite.pdf_parse_content_ops_from_bytes(
      doc.direct(PdfIndirect(186)).stream_bytes(),
    ),
    [Op_d0(1150.0, 0.0)],
  )
  @test.assert_eq(
    @pdflite.pdf_parse_content_ops_from_bytes(
      doc.direct(PdfIndirect(187)).stream_bytes(),
    ),
    [Op_d1(1160.0, 0.0, -20.0, -10.0, 1160.0, 900.0)],
  )
  @test.assert_eq(
    doc.parse_content_ops_with_resources(type3_data.resources, [
      doc.direct(PdfIndirect(188)),
    ]),
    acceptance_type3_fixture_t_ops_for_test(),
  )
  @test.assert_eq(
    @pdflite.pdf_parse_content_ops_from_bytes(
      doc.direct(PdfIndirect(189)).stream_bytes(),
    ),
    [Op_d0(700.0, 0.0)],
  )
  @test.assert_eq(
    type3_data.resources,
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/ProcSet"),
        PdfArray([
          PdfNameObject(acceptance_name_for_test("/PDF")),
          PdfNameObject(acceptance_name_for_test("/ImageB")),
        ]),
      ),
      (
        acceptance_name_for_test("/ColorSpace"),
        @pdflite.pdf_dictionary([
          (
            acceptance_name_for_test("/GlyphGray"),
            PdfNameObject(acceptance_name_for_test("/DeviceGray")),
          ),
        ]),
      ),
    ]),
  )
  guard simple.fontmetrics is Some(metrics) else {
    fail("expected fixture-shaped Type3 font metrics")
  }
  @test.assert_eq(metrics[0], 99.0)
  @test.assert_eq(metrics[1], 1150.0)
  @test.assert_eq(metrics[2], 1160.0)
  @test.assert_eq(metrics[3], 1170.0)
  @test.assert_eq(metrics[4], 700.0)
  @test.assert_eq(metrics[5], 99.0)
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(
    try! extractor.glyphnames_of_text(
      acceptance_text_bytes_for_test([1, 2, 3, 4]),
    ),
    [
      acceptance_name_for_test("/E"),
      acceptance_name_for_test("/X"),
      acceptance_name_for_test("/T"),
      acceptance_name_for_test("/I"),
    ],
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_first_page_for_test(
      doc,
      acceptance_name_for_test("/Ft3Fixture"),
    ),
    [69, 88, 84, 73],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(69), Some(1))
  @test.assert_eq(extractor.charcode_of_codepoint(84), Some(3))
  @test.assert_eq(extractor.charcode_of_codepoint(73), Some(4))
}

///|
fn acceptance_identity_h_text_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([0x00, 0x41, 0x20, 0xAC])
}

///|
fn acceptance_identity_h_descendant_font_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/CIDFontType2")),
    ),
    (
      acceptance_name_for_test("/BaseFont"),
      PdfNameObject(acceptance_name_for_test("/IdentityDescendant")),
    ),
    (
      acceptance_name_for_test("/CIDSystemInfo"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/Registry"),
          PdfString(acceptance_ascii_for_test("Adobe")),
        ),
        (
          acceptance_name_for_test("/Ordering"),
          PdfString(acceptance_ascii_for_test("Identity")),
        ),
        (acceptance_name_for_test("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      acceptance_name_for_test("/FontDescriptor"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/Ascent"), PdfInteger(880)),
        (acceptance_name_for_test("/Descent"), PdfInteger(-120)),
      ]),
    ),
    (
      acceptance_name_for_test("/W"),
      PdfArray([
        PdfInteger(0x41),
        PdfArray([PdfInteger(500)]),
        PdfInteger(0x20AC),
        PdfInteger(0x20AC),
        PdfInteger(1000),
      ]),
    ),
  ])
}

///|
fn acceptance_identity_h_font_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type0")),
    ),
    (
      acceptance_name_for_test("/BaseFont"),
      PdfNameObject(acceptance_name_for_test("/IdentityTop")),
    ),
    (
      acceptance_name_for_test("/Encoding"),
      PdfNameObject(acceptance_name_for_test("/Identity-H")),
    ),
    (acceptance_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(72)])),
  ])
}

///|
fn acceptance_identity_v_text_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([0x00, 0x43, 0x30, 0xA2])
}

///|
fn acceptance_identity_v_descendant_font_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/CIDFontType2")),
    ),
    (
      acceptance_name_for_test("/BaseFont"),
      PdfNameObject(acceptance_name_for_test("/IdentityVerticalDescendant")),
    ),
    (
      acceptance_name_for_test("/CIDSystemInfo"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/Registry"),
          PdfString(acceptance_ascii_for_test("Adobe")),
        ),
        (
          acceptance_name_for_test("/Ordering"),
          PdfString(acceptance_ascii_for_test("Identity")),
        ),
        (acceptance_name_for_test("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      acceptance_name_for_test("/FontDescriptor"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/Ascent"), PdfInteger(880)),
        (acceptance_name_for_test("/Descent"), PdfInteger(-120)),
      ]),
    ),
    (
      acceptance_name_for_test("/W2"),
      PdfArray([
        PdfInteger(0x43),
        PdfArray([
          PdfInteger(1000),
          PdfInteger(20),
          PdfInteger(880),
          PdfInteger(900),
          PdfInteger(25),
          PdfInteger(870),
        ]),
        PdfInteger(0x4E8C),
        PdfInteger(0x4E8C),
        PdfInteger(1200),
        PdfInteger(30),
        PdfInteger(860),
      ]),
    ),
    (
      acceptance_name_for_test("/DW2"),
      PdfArray([PdfInteger(880), PdfInteger(-1000)]),
    ),
  ])
}

///|
fn acceptance_identity_v_font_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type0")),
    ),
    (
      acceptance_name_for_test("/BaseFont"),
      PdfNameObject(acceptance_name_for_test("/IdentityVerticalTop")),
    ),
    (
      acceptance_name_for_test("/Encoding"),
      PdfNameObject(acceptance_name_for_test("/Identity-V")),
    ),
    (acceptance_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(72)])),
  ])
}

///|
fn acceptance_identity_h_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    72,
    acceptance_identity_h_descendant_font_for_test(),
  )
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/Fcid"),
          acceptance_identity_h_font_for_test(),
        ),
      ]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/Fcid"), 14.0),
        Op_Tj(acceptance_identity_h_text_for_test()),
        Op_TJ(
          PdfArray([
            PdfString(acceptance_text_bytes_for_test([0x00, 0x42])),
            PdfInteger(-30),
            PdfString(acceptance_text_bytes_for_test([0x4E, 0x00])),
          ]),
        ),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_identity_v_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    72,
    acceptance_identity_v_descendant_font_for_test(),
  )
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/Fcid"),
          acceptance_identity_v_font_for_test(),
        ),
      ]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/Fcid"), 14.0),
        Op_Tj(acceptance_identity_v_text_for_test()),
        Op_TJ(
          PdfArray([
            PdfString(acceptance_text_bytes_for_test([0x00, 0x44])),
            PdfInteger(-30),
            PdfString(acceptance_text_bytes_for_test([0x4E, 0x8C])),
          ]),
        ),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_identity_h_tounicode_cmap_for_test() -> @pdflite.PdfObject {
  let cmap = acceptance_ascii_for_test(
    "1 begincodespacerange\n" +
    "<0000><FFFF>\n" +
    "endcodespacerange\n" +
    "2 beginbfchar\n" +
    "<0041><2603>\n" +
    "<20AC><03A9>\n" +
    "endbfchar\n" +
    "1 beginbfrange\n" +
    "<0042><0043><0061>\n" +
    "endbfrange\n",
  )
  let encoded = @pdflite.pdf_ascii_hex_encode(cmap)
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/ASCIIHexDecode")),
      ),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_identity_h_tounicode_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    72,
    acceptance_identity_h_descendant_font_for_test(),
  )
  doc.add_object_given_number(
    73,
    acceptance_identity_h_tounicode_cmap_for_test(),
  )
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/Fcid"),
          acceptance_identity_h_font_for_test().add_dict_entry(
            acceptance_name_for_test("/ToUnicode"),
            PdfIndirect(73),
          ),
        ),
      ]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/Fcid"), 14.0),
        Op_Tj(acceptance_text_bytes_for_test([0x00, 0x41, 0x20, 0xAC])),
        Op_TJ(
          PdfArray([
            PdfString(acceptance_text_bytes_for_test([0x00, 0x42])),
            PdfInteger(-30),
            PdfString(acceptance_text_bytes_for_test([0x00, 0x43])),
          ]),
        ),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_predefined_cmap_descendant_font_for_test(
  basefont : String,
  ordering : String,
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/CIDFontType2")),
    ),
    (
      acceptance_name_for_test("/BaseFont"),
      PdfNameObject(acceptance_name_for_test(basefont)),
    ),
    (
      acceptance_name_for_test("/CIDSystemInfo"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/Registry"),
          PdfString(acceptance_ascii_for_test("Adobe")),
        ),
        (
          acceptance_name_for_test("/Ordering"),
          PdfString(acceptance_ascii_for_test(ordering)),
        ),
        (acceptance_name_for_test("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      acceptance_name_for_test("/FontDescriptor"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/Ascent"), PdfInteger(880)),
        (acceptance_name_for_test("/Descent"), PdfInteger(-120)),
      ]),
    ),
  ])
}

///|
fn acceptance_gbk2k_text_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([
    0x41, 0x81, 0x40, 0xC4, 0xE3, 0xFE, 0x51, 0x81, 0x30, 0x84, 0x36,
  ])
}

///|
fn acceptance_gbk2k_font_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type0")),
    ),
    (
      acceptance_name_for_test("/BaseFont"),
      PdfNameObject(acceptance_name_for_test("/GBK2KTop")),
    ),
    (
      acceptance_name_for_test("/Encoding"),
      PdfNameObject(acceptance_name_for_test("/GBK2K-H")),
    ),
    (acceptance_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(92)])),
  ])
}

///|
fn acceptance_gbk2k_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    92,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/GBK2KDescendant", "GB1",
    ),
  )
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/Fgbk2k"), acceptance_gbk2k_font_for_test()),
      ]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/Fgbk2k"), 14.0),
        Op_Tj(acceptance_gbk2k_text_for_test()),
        Op_TJ(
          PdfArray([
            PdfString(acceptance_text_bytes_for_test([0x82, 0x36, 0x94, 0x35])),
          ]),
        ),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_big5_text_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([
    0x41, 0xA7, 0x41, 0xA6, 0x6E, 0xA4, 0x40, 0xA4, 0xA4, 0xA1, 0x40,
  ])
}

///|
fn acceptance_big5_font_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type0")),
    ),
    (
      acceptance_name_for_test("/BaseFont"),
      PdfNameObject(acceptance_name_for_test("/ETenB5Top")),
    ),
    (
      acceptance_name_for_test("/Encoding"),
      PdfNameObject(acceptance_name_for_test("/ETen-B5-H")),
    ),
    (acceptance_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(94)])),
  ])
}

///|
fn acceptance_big5_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    94,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/ETenB5Descendant", "CNS1",
    ),
  )
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/Fbig5"), acceptance_big5_font_for_test()),
      ]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/Fbig5"), 14.0),
        Op_Tj(acceptance_big5_text_for_test()),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_hkscs_text_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([
    0x41, 0x87, 0x40, 0x87, 0x45, 0x89, 0x43, 0xA1, 0x40, 0xA7, 0x41, 0xA6, 0x6E,
    0xC6, 0xE4, 0xFE, 0xFE, 0x80,
  ])
}

///|
fn acceptance_hkscs_font_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type0")),
    ),
    (
      acceptance_name_for_test("/BaseFont"),
      PdfNameObject(acceptance_name_for_test("/HKscsB5Top")),
    ),
    (
      acceptance_name_for_test("/Encoding"),
      PdfNameObject(acceptance_name_for_test("/HKscs-B5-H")),
    ),
    (acceptance_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(96)])),
  ])
}

///|
fn acceptance_hkscs_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    96,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/HKscsB5Descendant", "CNS1",
    ),
  )
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/Fhkscs"), acceptance_hkscs_font_for_test()),
      ]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/Fhkscs"), 14.0),
        Op_Tj(acceptance_hkscs_text_for_test()),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_cns_euc_text_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([
    0x20, 0x80, 0xA1, 0xA1, 0xA1, 0xAC, 0x8E, 0xA2, 0xA1, 0xA1,
  ])
}

///|
fn acceptance_cns_euc_vertical_text_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([0xA1, 0xAC, 0x8E, 0xA1, 0xA1, 0xAC])
}

///|
fn acceptance_cns_euc_font_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type0")),
    ),
    (
      acceptance_name_for_test("/BaseFont"),
      PdfNameObject(acceptance_name_for_test("/CNSEUCTop")),
    ),
    (
      acceptance_name_for_test("/Encoding"),
      PdfNameObject(acceptance_name_for_test("/CNS-EUC-H")),
    ),
    (acceptance_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(98)])),
  ])
}

///|
fn acceptance_cns_euc_vertical_font_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type0")),
    ),
    (
      acceptance_name_for_test("/BaseFont"),
      PdfNameObject(acceptance_name_for_test("/CNSEUCVerticalTop")),
    ),
    (
      acceptance_name_for_test("/Encoding"),
      PdfNameObject(acceptance_name_for_test("/CNS-EUC-V")),
    ),
    (acceptance_name_for_test("/DescendantFonts"), PdfArray([PdfIndirect(100)])),
  ])
}

///|
fn acceptance_cns_euc_resources_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/Fcns"), acceptance_cns_euc_font_for_test()),
      ]),
    ),
  ])
}

///|
fn acceptance_cns_euc_vertical_resources_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/FcnsV"),
          acceptance_cns_euc_vertical_font_for_test(),
        ),
      ]),
    ),
  ])
}

///|
fn acceptance_cns_euc_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    98,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/CNSEUCDescendant", "CNS1",
    ),
  )
  doc.add_object_given_number(
    100,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/CNSEUCVerticalDescendant", "CNS1",
    ),
  )
  let horizontal_page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/Fcns"), 14.0),
        Op_Tj(acceptance_cns_euc_text_for_test()),
        Op_ET,
      ]),
    ],
    resources: acceptance_cns_euc_resources_for_test(),
  }
  let vertical_page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/FcnsV"), 14.0),
        Op_Tj(acceptance_cns_euc_vertical_text_for_test()),
        Op_ET,
      ]),
    ],
    resources: acceptance_cns_euc_vertical_resources_for_test(),
  }
  let page_root = doc.add_pagetree([horizontal_page, vertical_page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_vertical_predefined_cmap_cases_for_test() -> Array[
  (
    String,
    String,
    String,
    String,
    String,
    Int,
    Array[Int],
    Array[Int],
    Int,
    Int,
  ),
] {
  [
    (
      "/FvGbEuc",
      "/VerticalGBEUC",
      "/GB-EUC-V",
      "/VerticalGBEUCDescendant",
      "GB1",
      140,
      [0xA1, 0xA2],
      [0x3001],
      0x3001,
      0xA1A2,
    ),
    (
      "/FvGbpc",
      "/VerticalGBpcEUC",
      "/GBpc-EUC-V",
      "/VerticalGBpcEUCDescendant",
      "GB1",
      142,
      [0xA1, 0xA2],
      [0x3001],
      0x3001,
      0xA1A2,
    ),
    (
      "/FvGbk",
      "/VerticalGBK",
      "/GBK-EUC-V",
      "/VerticalGBKDescendant",
      "GB1",
      144,
      [0xA1, 0xA2],
      [0x3001],
      0x3001,
      0xA1A2,
    ),
    (
      "/FvGbkp",
      "/VerticalGBKp",
      "/GBKp-EUC-V",
      "/VerticalGBKpDescendant",
      "GB1",
      146,
      [0xA1, 0xA2],
      [0x3001],
      0x3001,
      0xA1A2,
    ),
    (
      "/FvGbk2k",
      "/VerticalGBK2K",
      "/GBK2K-V",
      "/VerticalGBK2KDescendant",
      "GB1",
      148,
      [0xA4, 0xC3],
      [0x3064],
      0x3064,
      0xA4C3,
    ),
    (
      "/FvB5",
      "/VerticalB5",
      "/B5-V",
      "/VerticalB5Descendant",
      "CNS1",
      150,
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/FvB5pc",
      "/VerticalB5pc",
      "/B5pc-V",
      "/VerticalB5pcDescendant",
      "CNS1",
      152,
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/FvETen",
      "/VerticalETen",
      "/ETen-B5-V",
      "/VerticalETenDescendant",
      "CNS1",
      154,
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/FvETenms",
      "/VerticalETenms",
      "/ETenms-B5-V",
      "/VerticalETenmsDescendant",
      "CNS1",
      156,
      [0xA1, 0x4C],
      [0xFE30],
      0xFE30,
      0xA14C,
    ),
    (
      "/FvHKdla",
      "/VerticalHKdla",
      "/HKdla-B5-V",
      "/VerticalHKdlaDescendant",
      "CNS1",
      158,
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/FvHKdlb",
      "/VerticalHKdlb",
      "/HKdlb-B5-V",
      "/VerticalHKdlbDescendant",
      "CNS1",
      160,
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/FvHKgccs",
      "/VerticalHKgccs",
      "/HKgccs-B5-V",
      "/VerticalHKgccsDescendant",
      "CNS1",
      162,
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/FvHKm314",
      "/VerticalHKm314",
      "/HKm314-B5-V",
      "/VerticalHKm314Descendant",
      "CNS1",
      164,
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/FvHKm471",
      "/VerticalHKm471",
      "/HKm471-B5-V",
      "/VerticalHKm471Descendant",
      "CNS1",
      166,
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/FvHKscs",
      "/VerticalHKscs",
      "/HKscs-B5-V",
      "/VerticalHKscsDescendant",
      "CNS1",
      168,
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/FvKsc",
      "/VerticalKSCEUC",
      "/KSC-EUC-V",
      "/VerticalKSCEUCDescendant",
      "Korea1",
      170,
      [0xA1, 0xA6],
      [0x22EF],
      0x22EF,
      0xA1A6,
    ),
    (
      "/FvKscpc",
      "/VerticalKSCpcEUC",
      "/KSCpc-EUC-V",
      "/VerticalKSCpcEUCDescendant",
      "Korea1",
      172,
      [0xA1, 0xA6],
      [0x22EF],
      0x22EF,
      0xA1A6,
    ),
    (
      "/FvUhc",
      "/VerticalKSCmsUHC",
      "/KSCms-UHC-V",
      "/VerticalKSCmsUHCDescendant",
      "Korea1",
      174,
      [0xA1, 0xA6],
      [0x22EF],
      0x22EF,
      0xA1A6,
    ),
  ]
}

///|
fn acceptance_vertical_predefined_cmap_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let pages : Array[@pdflite.PdfPage] = []
  for case in acceptance_vertical_predefined_cmap_cases_for_test() {
    doc.add_object_given_number(
      case.5,
      acceptance_predefined_cmap_descendant_font_for_test(case.3, case.4),
    )
    pages.push(
      acceptance_predefined_cmap_page_for_test(
        case.0,
        acceptance_predefined_cmap_type0_font_for_test(case.1, case.2, case.5),
        acceptance_text_bytes_for_test(case.6),
      ),
    )
  }
  let page_root = doc.add_pagetree(pages)
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_korea_cmap_text_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([
    0x41, 0xB0, 0xA1, 0xC7, 0xD1, 0xB1, 0xDB, 0x81, 0x41, 0xA4, 0xD4, 0x81, 0x40,
  ])
}

///|
fn acceptance_ksc_euc_text_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([
    0x41, 0x7E, 0xA1, 0xA1, 0xB0, 0xA1, 0xC7, 0xD1, 0x80, 0xA4, 0xD4,
  ])
}

///|
fn acceptance_kscpc_euc_text_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([
    0x41, 0x80, 0x81, 0x84, 0x9F, 0xFE, 0xFF, 0xA1, 0x41, 0xA1, 0x51, 0xA2, 0xE6,
    0xA2, 0xEF, 0xB0, 0xA1, 0xC7, 0xD1, 0xA1, 0x40,
  ])
}

///|
fn acceptance_predefined_cmap_type0_font_for_test(
  basefont : String,
  encoding : String,
  descendant_object : Int,
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type0")),
    ),
    (
      acceptance_name_for_test("/BaseFont"),
      PdfNameObject(acceptance_name_for_test(basefont)),
    ),
    (
      acceptance_name_for_test("/Encoding"),
      PdfNameObject(acceptance_name_for_test(encoding)),
    ),
    (
      acceptance_name_for_test("/DescendantFonts"),
      PdfArray([PdfIndirect(descendant_object)]),
    ),
  ])
}

///|
fn acceptance_predefined_cmap_page_for_test(
  font_name : String,
  font : @pdflite.PdfObject,
  text : @pdflite.PdfBytes,
) -> @pdflite.PdfPage raise {
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([(acceptance_name_for_test(font_name), font)]),
    ),
  ])
  {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test(font_name), 14.0),
        Op_Tj(text),
        Op_ET,
      ]),
    ],
    resources,
  }
}

///|
fn acceptance_unicode_predefined_tounicode_cmap_for_test() -> @pdflite.PdfObject {
  let cmap = acceptance_ascii_for_test(
    "2 begincodespacerange\n" +
    "<E38182><E38182>\n" +
    "<F09D849E><F09D849E>\n" +
    "endcodespacerange\n" +
    "2 beginbfchar\n" +
    "<E38182><2603>\n" +
    "<F09D849E><03A9>\n" +
    "endbfchar\n",
  )
  let encoded = @pdflite.pdf_flate_encode(cmap)
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_unicode_predefined_cmap_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    130,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/UniJISUCS2Descendant", "Japan1",
    ),
  )
  doc.add_object_given_number(
    131,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/UniCNSUCS2Descendant", "CNS1",
    ),
  )
  doc.add_object_given_number(
    132,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/UniJISUTF16Descendant", "Japan1",
    ),
  )
  doc.add_object_given_number(
    133,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/UniCNSUTF16Descendant", "CNS1",
    ),
  )
  doc.add_object_given_number(
    134,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/UniJISUTF8Descendant", "Japan1",
    ),
  )
  doc.add_object_given_number(
    135,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/UniCNSUTF32Descendant", "CNS1",
    ),
  )
  doc.add_object_given_number(
    136,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/UniJISUTF8ToUnicodeDescendant", "Japan1",
    ),
  )
  doc.add_object_given_number(
    137,
    acceptance_unicode_predefined_tounicode_cmap_for_test(),
  )
  let pages : ReadOnlyArray[@pdflite.PdfPage] = [
    acceptance_predefined_cmap_page_for_test(
      "/FUcs2H",
      acceptance_predefined_cmap_type0_font_for_test(
        "/UniJISUCS2Top", "/UniJIS-UCS2-H", 130,
      ),
      acceptance_text_bytes_for_test([0x00, 0x41, 0x4E, 0x00]),
    ),
    acceptance_predefined_cmap_page_for_test(
      "/FUcs2V",
      acceptance_predefined_cmap_type0_font_for_test(
        "/UniCNSUCS2VerticalTop", "/UniCNS-UCS2-V", 131,
      ),
      acceptance_text_bytes_for_test([0x00, 0x42, 0x4E, 0x8C]),
    ),
    acceptance_predefined_cmap_page_for_test(
      "/FUtf16H",
      acceptance_predefined_cmap_type0_font_for_test(
        "/UniJISUTF16Top", "/UniJIS-UTF16-H", 132,
      ),
      acceptance_text_bytes_for_test([
        0x30, 0x42, 0x30, 0xA2, 0xD8, 0x34, 0xDD, 0x1E,
      ]),
    ),
    acceptance_predefined_cmap_page_for_test(
      "/FUtf16V",
      acceptance_predefined_cmap_type0_font_for_test(
        "/UniCNSUTF16VerticalTop", "/UniCNS-UTF16-V", 133,
      ),
      acceptance_text_bytes_for_test([0x4E, 0x00, 0x4E, 0x8C]),
    ),
    acceptance_predefined_cmap_page_for_test(
      "/FUtf8H",
      acceptance_predefined_cmap_type0_font_for_test(
        "/UniJISUTF8Top", "/UniJIS-UTF8-H", 134,
      ),
      acceptance_text_bytes_for_test([
        0x41, 0xE3, 0x81, 0x82, 0xF0, 0x9D, 0x84, 0x9E,
      ]),
    ),
    acceptance_predefined_cmap_page_for_test(
      "/FUtf32V",
      acceptance_predefined_cmap_type0_font_for_test(
        "/UniCNSUTF32VerticalTop", "/UniCNS-UTF32-V", 135,
      ),
      acceptance_text_bytes_for_test([
        0x00, 0x00, 0x00, 0x41, 0x00, 0x01, 0xD1, 0x1E,
      ]),
    ),
    acceptance_predefined_cmap_page_for_test(
      "/FUtf8TU",
      acceptance_predefined_cmap_type0_font_for_test(
        "/UniJISUTF8ToUnicodeTop", "/UniJIS-UTF8-H", 136,
      ).add_dict_entry(acceptance_name_for_test("/ToUnicode"), PdfIndirect(137)),
      acceptance_text_bytes_for_test([0xE3, 0x81, 0x82, 0xF0, 0x9D, 0x84, 0x9E]),
    ),
  ]
  let page_root = doc.add_pagetree(pages)
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_korea_cmap_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    102,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/KSCmsUHCDescendant", "Korea1",
    ),
  )
  doc.add_object_given_number(
    104,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/KSCEUCDescendant", "Korea1",
    ),
  )
  doc.add_object_given_number(
    106,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/KSCpcEUCDescendant", "Korea1",
    ),
  )
  let uhc_page = acceptance_predefined_cmap_page_for_test(
    "/Fuhc",
    acceptance_predefined_cmap_type0_font_for_test(
      "/KSCmsUHCTop", "/KSCms-UHC-H", 102,
    ),
    acceptance_korea_cmap_text_for_test(),
  )
  let ksc_euc_page = acceptance_predefined_cmap_page_for_test(
    "/Fksc",
    acceptance_predefined_cmap_type0_font_for_test(
      "/KSCEUCTop", "/KSC-EUC-H", 104,
    ),
    acceptance_ksc_euc_text_for_test(),
  )
  let kscpc_euc_page = acceptance_predefined_cmap_page_for_test(
    "/Fkscpc",
    acceptance_predefined_cmap_type0_font_for_test(
      "/KSCpcEUCTop", "/KSCpc-EUC-H", 106,
    ),
    acceptance_kscpc_euc_text_for_test(),
  )
  let page_root = doc.add_pagetree([uhc_page, ksc_euc_page, kscpc_euc_page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_gb_euc_text_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([
    0x41, 0xC4, 0xE3, 0xBA, 0xC3, 0xA1, 0xA1, 0xA3, 0xC1,
  ])
}

///|
fn acceptance_gbpc_euc_text_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([
    0x41, 0x80, 0x83, 0xA0, 0xFD, 0xFE, 0xFF, 0xA1, 0xA1, 0xA1, 0xAB, 0xA8, 0xBF,
    0xC4, 0xE3, 0xBA, 0xC3,
  ])
}

///|
fn acceptance_gbk_text_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([
    0x41, 0x80, 0x81, 0x40, 0xC4, 0xE3, 0xBA, 0xC3, 0xA1, 0xA1, 0xA3, 0xC1, 0xA1,
    0x40, 0xA8, 0xBC, 0xFE, 0xFE, 0xFF, 0x81, 0x39,
  ])
}

///|
fn acceptance_gb1_cmap_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    108,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/GBEUCDescendant", "GB1",
    ),
  )
  doc.add_object_given_number(
    110,
    acceptance_predefined_cmap_descendant_font_for_test(
      "/GBpcEUCDescendant", "GB1",
    ),
  )
  doc.add_object_given_number(
    112,
    acceptance_predefined_cmap_descendant_font_for_test("/GBKDescendant", "GB1"),
  )
  let gb_euc_page = acceptance_predefined_cmap_page_for_test(
    "/Fgbeuc",
    acceptance_predefined_cmap_type0_font_for_test(
      "/GBEUCTop", "/GB-EUC-H", 108,
    ),
    acceptance_gb_euc_text_for_test(),
  )
  let gbpc_euc_page = acceptance_predefined_cmap_page_for_test(
    "/Fgbpc",
    acceptance_predefined_cmap_type0_font_for_test(
      "/GBpcEUCTop", "/GBpc-EUC-H", 110,
    ),
    acceptance_gbpc_euc_text_for_test(),
  )
  let gbk_page = acceptance_predefined_cmap_page_for_test(
    "/Fgbk",
    acceptance_predefined_cmap_type0_font_for_test("/GBKTop", "/GBK-EUC-H", 112),
    acceptance_gbk_text_for_test(),
  )
  let page_root = doc.add_pagetree([gb_euc_page, gbpc_euc_page, gbk_page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_cns1_variant_cmap_cases_for_test() -> Array[
  (String, String, String, String, Int, Array[Int], Array[Int], Int, Int),
] {
  [
    (
      "/Fb5pc",
      "/B5pcTop",
      "/B5pc-H",
      "/B5pcDescendant",
      114,
      [
        0x41, 0x80, 0x83, 0xA0, 0xFD, 0xFE, 0xFF, 0xA1, 0x40, 0xA7, 0x41, 0xA6, 0x6E,
        0xA1, 0x4B, 0xA1, 0x51,
      ],
      [
        0x41, 0x005C, 0x83, 0x00A0, 0x00A9, 0x2122, 0x2026, 0x3000, 0x4F60, 0x597D,
        0x22EF, 0xFE54,
      ],
      0x22EF,
      0xA14B,
    ),
    (
      "/Fetenms",
      "/ETenmsTop",
      "/ETenms-B5-H",
      "/ETenmsDescendant",
      116,
      [0x41, 0xA1, 0xC2, 0xA2, 0x41, 0xC7, 0xFD, 0x80],
      [0x41, 0x00AF, 0x2215, 0x0419, 0x80],
      0x0419,
      0xC7FD,
    ),
    (
      "/Fhkdla",
      "/HKdlaTop",
      "/HKdla-B5-H",
      "/HKdlaDescendant",
      118,
      [0x41, 0xFA, 0x41, 0x80],
      [0x41, 0x5F0D, 0x80],
      0x5F0D,
      0xFA41,
    ),
    (
      "/Fhkdlb",
      "/HKdlbTop",
      "/HKdlb-B5-H",
      "/HKdlbDescendant",
      120,
      [0x41, 0x8E, 0x40, 0x80],
      [0x41, 0x99C4, 0x80],
      0x99C4,
      0x8E40,
    ),
    (
      "/Fhkgccs",
      "/HKgccsTop",
      "/HKgccs-B5-H",
      "/HKgccsDescendant",
      122,
      [0x41, 0x8A, 0x43, 0x80],
      [0x41, 0x20C42, 0x80],
      0x20C42,
      0x8A43,
    ),
    (
      "/Fhkm314",
      "/HKm314Top",
      "/HKm314-B5-H",
      "/HKm314Descendant",
      124,
      [0x41, 0xC7, 0x40, 0x80],
      [0x41, 0x4E21, 0x80],
      0x4E21,
      0xC740,
    ),
    (
      "/Fhkm471",
      "/HKm471Top",
      "/HKm471-B5-H",
      "/HKm471Descendant",
      126,
      [0x41, 0xFA, 0x40, 0x80],
      [0x41, 0x4E21, 0x80],
      0x4E21,
      0xFA40,
    ),
  ]
}

///|
fn acceptance_cns1_variant_cmap_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let pages : Array[@pdflite.PdfPage] = []
  for case in acceptance_cns1_variant_cmap_cases_for_test() {
    doc.add_object_given_number(
      case.4,
      acceptance_predefined_cmap_descendant_font_for_test(case.3, "CNS1"),
    )
    pages.push(
      acceptance_predefined_cmap_page_for_test(
        case.0,
        acceptance_predefined_cmap_type0_font_for_test(case.1, case.2, case.4),
        acceptance_text_bytes_for_test(case.5),
      ),
    )
  }
  let page_root = doc.add_pagetree(pages)
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_japan1_cmap_cases_for_test() -> Array[
  (
    String,
    String,
    String,
    String,
    Int,
    Array[Int],
    Array[Int],
    Int,
    Int,
    Bool,
    Int,
  ),
] {
  [
    (
      "/Frksj",
      "/RKSJTop",
      "/90ms-RKSJ-H",
      "/RKSJDescendant",
      128,
      [0x41, 0xA6, 0x81, 0x40, 0x93, 0xF1],
      [0x41, 0xFF66, 0x3000, 0x4E8C],
      0x4E8C,
      0x93F1,
      false,
      -1,
    ),
    (
      "/Fpv",
      "/RKSJ90pvTop",
      "/90pv-RKSJ-H",
      "/RKSJ90pvDescendant",
      130,
      [0x5C, 0x80, 0xA0, 0x81, 0x7C, 0x85, 0x91],
      [0x00A5, 0x005C, 0x00A0, 0x2212, 0xF860, 0x0030, 0x002E],
      0x2212,
      0x817C,
      false,
      0xF860,
    ),
    (
      "/Fjis",
      "/JISTop",
      "/H",
      "/JISDescendant",
      132,
      [0x21, 0x21, 0x24, 0x22],
      [0x3000, 0x3042],
      0x3042,
      0x2422,
      true,
      -1,
    ),
    (
      "/Feuc",
      "/JapanEUCTop",
      "/EUC-H",
      "/JapanEUCDescendant",
      134,
      [0xA1, 0xA1, 0xA4, 0xA2],
      [0x3000, 0x3042],
      0x3042,
      0xA4A2,
      false,
      -1,
    ),
    (
      "/Fhojo",
      "/HojoEUCTop",
      "/Hojo-EUC-H",
      "/HojoEUCDescendant",
      136,
      [0x8F, 0xB4, 0xAE],
      [0x4EDD],
      0x4EDD,
      0x8FB4AE,
      false,
      -1,
    ),
  ]
}

///|
fn acceptance_japan1_cmap_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let pages : Array[@pdflite.PdfPage] = []
  for case in acceptance_japan1_cmap_cases_for_test() {
    doc.add_object_given_number(
      case.4,
      acceptance_predefined_cmap_descendant_font_for_test(case.3, "Japan1"),
    )
    pages.push(
      acceptance_predefined_cmap_page_for_test(
        case.0,
        acceptance_predefined_cmap_type0_font_for_test(case.1, case.2, case.4),
        acceptance_text_bytes_for_test(case.5),
      ),
    )
  }
  let page_root = doc.add_pagetree(pages)
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_japan1_90msp_cmap_cases_for_test() -> Array[
  (
    String,
    String,
    String,
    String,
    Int,
    Array[Int],
    Array[Int],
    Int,
    Int,
    Bool,
    Int,
  ),
] {
  [
    (
      "/F90mspH",
      "/RKSJ90mspTop",
      "/90msp-RKSJ-H",
      "/RKSJ90mspDescendant",
      138,
      [0x41, 0x5C, 0xA6, 0x81, 0x40, 0x93, 0xF1],
      [0x41, 0x00A5, 0xFF66, 0x3000, 0x4E8C],
      0x00A5,
      0x5C,
      false,
      0x1F600,
    ),
    (
      "/F90mspV",
      "/RKSJ90mspVerticalTop",
      "/90msp-RKSJ-V",
      "/RKSJ90mspVerticalDescendant",
      140,
      [0x41, 0x5C, 0xA6, 0x81, 0x40, 0x82, 0x9F, 0x93, 0xF1],
      [0x41, 0x00A5, 0xFF66, 0x3000, 0x3041, 0x4E8C],
      0x3041,
      0x829F,
      false,
      0x1F600,
    ),
  ]
}

///|
fn acceptance_japan1_90msp_cmap_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let pages : Array[@pdflite.PdfPage] = []
  for case in acceptance_japan1_90msp_cmap_cases_for_test() {
    doc.add_object_given_number(
      case.4,
      acceptance_predefined_cmap_descendant_font_for_test(case.3, "Japan1"),
    )
    pages.push(
      acceptance_predefined_cmap_page_for_test(
        case.0,
        acceptance_predefined_cmap_type0_font_for_test(case.1, case.2, case.4),
        acceptance_text_bytes_for_test(case.5),
      ),
    )
  }
  let page_root = doc.add_pagetree(pages)
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_japan1_legacy_cmap_cases_for_test() -> Array[
  (
    String,
    String,
    String,
    String,
    Int,
    Array[Int],
    Array[Int],
    Int,
    Int,
    Bool,
    Int,
  ),
] {
  [
    (
      "/F78H",
      "/Legacy78Top",
      "/78-H",
      "/Legacy78Descendant",
      142,
      [0x21, 0x21, 0x24, 0x22],
      [0x3000, 0x3042],
      0x3042,
      0x2422,
      true,
      0x1F600,
    ),
    (
      "/F78V",
      "/Legacy78VerticalTop",
      "/78-V",
      "/Legacy78VerticalDescendant",
      144,
      [0x21, 0x21, 0x24, 0x21],
      [0x3000, 0x3041],
      0x3041,
      0x2421,
      true,
      0x1F600,
    ),
    (
      "/F78RKSJH",
      "/Legacy78RKSJTop",
      "/78-RKSJ-H",
      "/Legacy78RKSJDescendant",
      146,
      [0x81, 0x40, 0x82, 0xA0],
      [0x3000, 0x3042],
      0x3042,
      0x82A0,
      false,
      0x1F600,
    ),
    (
      "/F78RKSJV",
      "/Legacy78RKSJVerticalTop",
      "/78-RKSJ-V",
      "/Legacy78RKSJVerticalDescendant",
      148,
      [0x81, 0x40, 0x82, 0x9F],
      [0x3000, 0x3041],
      0x3041,
      0x829F,
      false,
      0x1F600,
    ),
    (
      "/F78msRKSJH",
      "/Legacy78msRKSJTop",
      "/78ms-RKSJ-H",
      "/Legacy78msRKSJDescendant",
      150,
      [0x81, 0x40, 0x82, 0xA0],
      [0x3000, 0x3042],
      0x3042,
      0x82A0,
      false,
      0x1F600,
    ),
    (
      "/F78msRKSJV",
      "/Legacy78msRKSJVerticalTop",
      "/78ms-RKSJ-V",
      "/Legacy78msRKSJVerticalDescendant",
      152,
      [0x81, 0x40, 0x82, 0x9F],
      [0x3000, 0x3041],
      0x3041,
      0x829F,
      false,
      0x1F600,
    ),
    (
      "/F83pvRKSJH",
      "/Legacy83pvRKSJTop",
      "/83pv-RKSJ-H",
      "/Legacy83pvRKSJDescendant",
      154,
      [0x80, 0x81, 0x40, 0x82, 0xA0],
      [0x005C, 0x3000, 0x3042],
      0x005C,
      0x80,
      false,
      0x1F600,
    ),
    (
      "/F90msRKSJV",
      "/Legacy90msRKSJVerticalTop",
      "/90ms-RKSJ-V",
      "/Legacy90msRKSJVerticalDescendant",
      156,
      [0x81, 0x40, 0x82, 0x9F],
      [0x3000, 0x3041],
      0x3041,
      0x829F,
      false,
      0x1F600,
    ),
    (
      "/F90pvRKSJV",
      "/Legacy90pvRKSJVerticalTop",
      "/90pv-RKSJ-V",
      "/Legacy90pvRKSJVerticalDescendant",
      158,
      [0x80, 0x81, 0x40, 0x82, 0x9F],
      [0x005C, 0x3000, 0x3041],
      0x005C,
      0x80,
      false,
      0x1F600,
    ),
    (
      "/FRKSJH",
      "/GenericRKSJTop",
      "/RKSJ-H",
      "/GenericRKSJDescendant",
      160,
      [0x81, 0x40, 0x82, 0xA0],
      [0x3000, 0x3042],
      0x3042,
      0x82A0,
      false,
      0x1F600,
    ),
    (
      "/FRKSJV",
      "/GenericRKSJVerticalTop",
      "/RKSJ-V",
      "/GenericRKSJVerticalDescendant",
      162,
      [0x81, 0x40, 0x82, 0x9F],
      [0x3000, 0x3041],
      0x3041,
      0x829F,
      false,
      0x1F600,
    ),
  ]
}

///|
fn acceptance_japan1_legacy_cmap_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let pages : Array[@pdflite.PdfPage] = []
  for case in acceptance_japan1_legacy_cmap_cases_for_test() {
    doc.add_object_given_number(
      case.4,
      acceptance_predefined_cmap_descendant_font_for_test(case.3, "Japan1"),
    )
    pages.push(
      acceptance_predefined_cmap_page_for_test(
        case.0,
        acceptance_predefined_cmap_type0_font_for_test(case.1, case.2, case.4),
        acceptance_text_bytes_for_test(case.5),
      ),
    )
  }
  let page_root = doc.add_pagetree(pages)
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_japan1_supplemental_cmap_cases_for_test() -> Array[
  (
    String,
    String,
    String,
    String,
    Int,
    Array[Int],
    Array[Int],
    Int,
    Int,
    Bool,
    Int,
  ),
] {
  [
    (
      "/F78EUCH",
      "/Legacy78EUCTop",
      "/78-EUC-H",
      "/Legacy78EUCDescendant",
      164,
      [0xA1, 0xA1, 0xA4, 0xA2],
      [0x3000, 0x3042],
      0x3042,
      0xA4A2,
      false,
      0x1F600,
    ),
    (
      "/F78EUCV",
      "/Legacy78EUCVerticalTop",
      "/78-EUC-V",
      "/Legacy78EUCVerticalDescendant",
      166,
      [0xA1, 0xA1, 0xA4, 0xA1],
      [0x3000, 0x3041],
      0x3041,
      0xA4A1,
      false,
      0x1F600,
    ),
    (
      "/FEUCV",
      "/JapanEUCVerticalTop",
      "/EUC-V",
      "/JapanEUCVerticalDescendant",
      168,
      [0xA1, 0xA1, 0xA4, 0xA1],
      [0x3000, 0x3041],
      0x3041,
      0xA4A1,
      false,
      0x1F600,
    ),
    (
      "/FAddH",
      "/AddTop",
      "/Add-H",
      "/AddDescendant",
      170,
      [0x28, 0x21, 0x24, 0x22],
      [0x2500, 0x3042],
      0x2500,
      0x2821,
      true,
      0x1F600,
    ),
    (
      "/FAddV",
      "/AddVerticalTop",
      "/Add-V",
      "/AddVerticalDescendant",
      172,
      [0x28, 0x21, 0x24, 0x21],
      [0x2500, 0x3041],
      0x3041,
      0x2421,
      true,
      0x1F600,
    ),
    (
      "/FAddRKSJH",
      "/AddRKSJTop",
      "/Add-RKSJ-H",
      "/AddRKSJDescendant",
      174,
      [0x84, 0x9F, 0x82, 0xA0],
      [0x2500, 0x3042],
      0x2500,
      0x849F,
      false,
      0x1F600,
    ),
    (
      "/FAddRKSJV",
      "/AddRKSJVerticalTop",
      "/Add-RKSJ-V",
      "/AddRKSJVerticalDescendant",
      176,
      [0x84, 0x9F, 0x82, 0x9F],
      [0x2500, 0x3041],
      0x3041,
      0x829F,
      false,
      0x1F600,
    ),
    (
      "/FExtH",
      "/ExtTop",
      "/Ext-H",
      "/ExtDescendant",
      178,
      [0x2C, 0x24, 0x24, 0x22],
      [0x2500, 0x3042],
      0x3042,
      0x2422,
      true,
      0x1F600,
    ),
    (
      "/FExtV",
      "/ExtVerticalTop",
      "/Ext-V",
      "/ExtVerticalDescendant",
      180,
      [0x2C, 0x24, 0x24, 0x21],
      [0x2500, 0x3041],
      0x3041,
      0x2421,
      true,
      0x1F600,
    ),
    (
      "/FExtRKSJH",
      "/ExtRKSJTop",
      "/Ext-RKSJ-H",
      "/ExtRKSJDescendant",
      182,
      [0x86, 0xA2, 0x82, 0xA0],
      [0x2500, 0x3042],
      0x3042,
      0x82A0,
      false,
      0x1F600,
    ),
    (
      "/FExtRKSJV",
      "/ExtRKSJVerticalTop",
      "/Ext-RKSJ-V",
      "/ExtRKSJVerticalDescendant",
      184,
      [0x86, 0xA2, 0x82, 0x9F],
      [0x2500, 0x3041],
      0x3041,
      0x829F,
      false,
      0x1F600,
    ),
    (
      "/FHojoH",
      "/HojoTop",
      "/Hojo-H",
      "/HojoDescendant",
      186,
      [0x34, 0x2E],
      [0x4EDD],
      0x4EDD,
      0x342E,
      true,
      0x1F600,
    ),
    (
      "/FHojoV",
      "/HojoVerticalTop",
      "/Hojo-V",
      "/HojoVerticalDescendant",
      188,
      [0x34, 0x2E],
      [0x4EDD],
      0x4EDD,
      0x342E,
      true,
      0x1F600,
    ),
    (
      "/FHojoEUCV",
      "/HojoEUCVerticalTop",
      "/Hojo-EUC-V",
      "/HojoEUCVerticalDescendant",
      190,
      [0x8F, 0xB4, 0xAE],
      [0x4EDD],
      0x4EDD,
      0x8FB4AE,
      false,
      0x1F600,
    ),
    (
      "/FNWPH",
      "/NWPTop",
      "/NWP-H",
      "/NWPDescendant",
      192,
      [0x2E, 0x21, 0x2C, 0x24, 0x24, 0x22],
      [0xFF01, 0x2500, 0x3042],
      0x3042,
      0x2422,
      true,
      0x1F600,
    ),
    (
      "/FNWPV",
      "/NWPVerticalTop",
      "/NWP-V",
      "/NWPVerticalDescendant",
      194,
      [0x2E, 0x21, 0x24, 0x21],
      [0xFF01, 0x3041],
      0x3041,
      0x2421,
      true,
      0x1F600,
    ),
  ]
}

///|
fn acceptance_japan1_supplemental_cmap_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  let pages : Array[@pdflite.PdfPage] = []
  for case in acceptance_japan1_supplemental_cmap_cases_for_test() {
    doc.add_object_given_number(
      case.4,
      acceptance_predefined_cmap_descendant_font_for_test(case.3, "Japan1"),
    )
    pages.push(
      acceptance_predefined_cmap_page_for_test(
        case.0,
        acceptance_predefined_cmap_type0_font_for_test(case.1, case.2, case.4),
        acceptance_text_bytes_for_test(case.5),
      ),
    )
  }
  let page_root = doc.add_pagetree(pages)
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_font_object_by_name_for_test(
  resources : @pdflite.PdfObject,
  name : @pdflite.PdfName,
) -> @pdflite.PdfObject raise {
  let fonts = match
    resources.lookup_immediate(acceptance_name_for_test("/Font")) {
    Some(fonts) => fonts
    None => fail("expected page font resources")
  }
  match fonts.lookup_immediate(name) {
    Some(font) => font
    None => fail("expected named font")
  }
}

///|
fn acceptance_identity_h_codepoints_of_first_page_for_test(
  doc : @pdflite.PdfDocument,
) -> Array[Int] raise {
  acceptance_font_codepoints_of_first_page_for_test(
    doc,
    acceptance_name_for_test("/Fcid"),
  )
}

///|
fn acceptance_font_codepoints_of_first_page_for_test(
  doc : @pdflite.PdfDocument,
  font_name : @pdflite.PdfName,
) -> Array[Int] raise {
  let pages = doc.pages_of_pagetree()
  acceptance_font_codepoints_of_page_for_test(doc, pages[0], font_name)
}

///|
fn acceptance_font_codepoints_of_page_for_test(
  doc : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
  font_name : @pdflite.PdfName,
) -> Array[Int] raise {
  let font = acceptance_font_object_by_name_for_test(page.resources, font_name)
  let extractor = doc.text_extractor_of_font(font)
  let output : Array[Int] = []
  for op in doc.parse_content_ops(page.content) {
    match op {
      Op_Tj(text) =>
        acceptance_push_text_codepoints_for_test(output, extractor, text)
      Op_TJ(PdfArray(items)) =>
        for item in items {
          match item {
            PdfString(text) =>
              acceptance_push_text_codepoints_for_test(output, extractor, text)
            _ => ()
          }
        }
      _ => ()
    }
  }
  output
}

///|
fn acceptance_assert_identity_h_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font = acceptance_font_object_by_name_for_test(
    pages[0].resources,
    acceptance_name_for_test("/Fcid"),
  )
  let read = doc.read_font(font)
  @test.assert_eq(read.is_identity_h(), true)
  @test.assert_eq(read.uses_two_byte_codes(), true)
  @test.assert_eq(
    acceptance_identity_h_codepoints_of_first_page_for_test(doc),
    [0x41, 0x20AC, 0x42, 0x4E00],
  )
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(extractor.charcode_of_codepoint(0x41), None)
}

///|
fn acceptance_assert_identity_v_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font = acceptance_font_object_by_name_for_test(
    pages[0].resources,
    acceptance_name_for_test("/Fcid"),
  )
  let read = doc.read_font(font)
  @test.assert_eq(read.is_identity_h(), false)
  @test.assert_eq(read.is_identity_v(), true)
  @test.assert_eq(read.uses_two_byte_codes(), true)
  guard read is PdfFontCIDKeyed(cid_font) else {
    fail("expected CID-keyed font")
  }
  @test.assert_eq(
    cid_font.encoding,
    PdfPredefinedCMap(acceptance_name_for_test("/Identity-V")),
  )
  @test.assert_eq(cid_font.composite.cid_widths2, [
    (0x43, { width: 1000.0, vx: 20.0, vy: 880.0 }),
    (0x44, { width: 900.0, vx: 25.0, vy: 870.0 }),
    (0x4E8C, { width: 1200.0, vx: 30.0, vy: 860.0 }),
  ])
  @test.assert_eq(cid_font.composite.cid_default_width2, [880.0, -1000.0])
  @test.assert_eq(
    acceptance_font_codepoints_of_first_page_for_test(
      doc,
      acceptance_name_for_test("/Fcid"),
    ),
    [0x43, 0x30A2, 0x44, 0x4E8C],
  )
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(extractor.charcode_of_codepoint(0x43), None)
}

///|
fn acceptance_assert_identity_h_tounicode_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font = acceptance_font_object_by_name_for_test(
    pages[0].resources,
    acceptance_name_for_test("/Fcid"),
  )
  let read = doc.read_font(font)
  @test.assert_eq(read.is_identity_h(), true)
  @test.assert_eq(read.uses_two_byte_codes(), true)
  @test.assert_eq(
    acceptance_identity_h_codepoints_of_first_page_for_test(doc),
    [0x2603, 0x03A9, 0x61, 0x62],
  )
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(extractor.charcode_of_codepoint(0x2603), Some(0x0041))
  @test.assert_eq(extractor.charcode_of_codepoint(0x61), Some(0x0042))
}

///|
fn acceptance_assert_gbk2k_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font = acceptance_font_object_by_name_for_test(
    pages[0].resources,
    acceptance_name_for_test("/Fgbk2k"),
  )
  let read = doc.read_font(font)
  @test.assert_eq(read.is_identity_h(), false)
  @test.assert_eq(read.is_identity_v(), false)
  @test.assert_eq(read.uses_two_byte_codes(), false)
  guard read is PdfFontCIDKeyed(cid_font) else {
    fail("expected CID-keyed GBK2K font")
  }
  @test.assert_eq(
    cid_font.encoding,
    PdfPredefinedCMap(acceptance_name_for_test("/GBK2K-H")),
  )
  @test.assert_eq(
    cid_font.composite.cid_system_info.ordering,
    acceptance_ascii_for_test("GB1"),
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_first_page_for_test(
      doc,
      acceptance_name_for_test("/Fgbk2k"),
    ),
    [0x41, 0x4E02, 0x4F60, 0x20087, 0x00A5, 0xA4C6],
  )
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(extractor.charcode_of_codepoint(0x41), Some(0x41))
  @test.assert_eq(extractor.charcode_of_codepoint(0x4E02), Some(0x8140))
  @test.assert_eq(extractor.charcode_of_codepoint(0x4F60), Some(0xC4E3))
  @test.assert_eq(extractor.charcode_of_codepoint(0x20087), Some(0xFE51))
  @test.assert_eq(extractor.charcode_of_codepoint(0x00A5), Some(0x81308436))
  @test.assert_eq(extractor.charcode_of_codepoint(0xA4C6), Some(0x82369435))
  @test.assert_eq(extractor.charcode_of_codepoint(0x1F600), None)
}

///|
fn acceptance_assert_big5_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font = acceptance_font_object_by_name_for_test(
    pages[0].resources,
    acceptance_name_for_test("/Fbig5"),
  )
  let read = doc.read_font(font)
  @test.assert_eq(read.is_identity_h(), false)
  @test.assert_eq(read.is_identity_v(), false)
  @test.assert_eq(read.uses_two_byte_codes(), false)
  guard read is PdfFontCIDKeyed(cid_font) else {
    fail("expected CID-keyed Big5 font")
  }
  @test.assert_eq(
    cid_font.encoding,
    PdfPredefinedCMap(acceptance_name_for_test("/ETen-B5-H")),
  )
  @test.assert_eq(
    cid_font.composite.cid_system_info.ordering,
    acceptance_ascii_for_test("CNS1"),
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_first_page_for_test(
      doc,
      acceptance_name_for_test("/Fbig5"),
    ),
    [0x41, 0x4F60, 0x597D, 0x4E00, 0x4E2D, 0x3000],
  )
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(extractor.charcode_of_codepoint(0x41), Some(0x41))
  @test.assert_eq(extractor.charcode_of_codepoint(0x4F60), Some(0xA741))
  @test.assert_eq(extractor.charcode_of_codepoint(0x597D), Some(0xA66E))
  @test.assert_eq(extractor.charcode_of_codepoint(0x4E00), Some(0xA440))
  @test.assert_eq(extractor.charcode_of_codepoint(0x4E2D), Some(0xA4A4))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3000), Some(0xA140))
  @test.assert_eq(extractor.charcode_of_codepoint(0x20AC), None)
}

///|
fn acceptance_assert_hkscs_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font = acceptance_font_object_by_name_for_test(
    pages[0].resources,
    acceptance_name_for_test("/Fhkscs"),
  )
  let read = doc.read_font(font)
  @test.assert_eq(read.is_identity_h(), false)
  @test.assert_eq(read.is_identity_v(), false)
  @test.assert_eq(read.uses_two_byte_codes(), false)
  guard read is PdfFontCIDKeyed(cid_font) else {
    fail("expected CID-keyed HKSCS font")
  }
  @test.assert_eq(
    cid_font.encoding,
    PdfPredefinedCMap(acceptance_name_for_test("/HKscs-B5-H")),
  )
  @test.assert_eq(
    cid_font.composite.cid_system_info.ordering,
    acceptance_ascii_for_test("CNS1"),
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_first_page_for_test(
      doc,
      acceptance_name_for_test("/Fhkscs"),
    ),
    [
      0x41, 0x43F0, 0x27267, 0x650A, 0x3000, 0x4F60, 0x597D, 0xFF3B, 0x79D4, 0x80,
    ],
  )
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(extractor.charcode_of_codepoint(0x41), Some(0x41))
  @test.assert_eq(extractor.charcode_of_codepoint(0x43F0), Some(0x8740))
  @test.assert_eq(extractor.charcode_of_codepoint(0x27267), Some(0x8745))
  @test.assert_eq(extractor.charcode_of_codepoint(0x650A), Some(0x8943))
  @test.assert_eq(extractor.charcode_of_codepoint(0x3000), Some(0xA140))
  @test.assert_eq(extractor.charcode_of_codepoint(0x4F60), Some(0xA741))
  @test.assert_eq(extractor.charcode_of_codepoint(0x597D), Some(0xA66E))
  @test.assert_eq(extractor.charcode_of_codepoint(0xFF3B), Some(0xC6E4))
  @test.assert_eq(extractor.charcode_of_codepoint(0x79D4), Some(0xFEFE))
  @test.assert_eq(extractor.charcode_of_codepoint(0x1F600), None)
}

///|
fn acceptance_assert_cns_euc_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 2)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 2)
  let horizontal_font = acceptance_font_object_by_name_for_test(
    pages[0].resources,
    acceptance_name_for_test("/Fcns"),
  )
  let horizontal_read = doc.read_font(horizontal_font)
  @test.assert_eq(horizontal_read.is_identity_h(), false)
  @test.assert_eq(horizontal_read.is_identity_v(), false)
  @test.assert_eq(horizontal_read.uses_two_byte_codes(), false)
  guard horizontal_read is PdfFontCIDKeyed(horizontal_cid_font) else {
    fail("expected CID-keyed CNS-EUC font")
  }
  @test.assert_eq(
    horizontal_cid_font.encoding,
    PdfPredefinedCMap(acceptance_name_for_test("/CNS-EUC-H")),
  )
  @test.assert_eq(
    horizontal_cid_font.composite.cid_system_info.ordering,
    acceptance_ascii_for_test("CNS1"),
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_page_for_test(
      doc,
      pages[0],
      acceptance_name_for_test("/Fcns"),
    ),
    [0x20, 0x80, 0x3000, 0x2026, 0x4E42],
  )
  let horizontal_extractor = doc.text_extractor_of_font(horizontal_font)
  @test.assert_eq(horizontal_extractor.charcode_of_codepoint(0x20), Some(0x20))
  @test.assert_eq(
    horizontal_extractor.charcode_of_codepoint(0x3000),
    Some(0xA1A1),
  )
  @test.assert_eq(
    horizontal_extractor.charcode_of_codepoint(0x2026),
    Some(0xA1AC),
  )
  @test.assert_eq(
    horizontal_extractor.charcode_of_codepoint(0x4E42),
    Some(0x8EA2A1A1),
  )
  @test.assert_eq(horizontal_extractor.charcode_of_codepoint(0x1F600), None)
  let vertical_font = acceptance_font_object_by_name_for_test(
    pages[1].resources,
    acceptance_name_for_test("/FcnsV"),
  )
  let vertical_read = doc.read_font(vertical_font)
  @test.assert_eq(vertical_read.is_identity_h(), false)
  @test.assert_eq(vertical_read.is_identity_v(), false)
  @test.assert_eq(vertical_read.uses_two_byte_codes(), false)
  guard vertical_read is PdfFontCIDKeyed(vertical_cid_font) else {
    fail("expected CID-keyed CNS-EUC vertical font")
  }
  @test.assert_eq(
    vertical_cid_font.encoding,
    PdfPredefinedCMap(acceptance_name_for_test("/CNS-EUC-V")),
  )
  @test.assert_eq(
    vertical_cid_font.composite.cid_system_info.ordering,
    acceptance_ascii_for_test("CNS1"),
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_page_for_test(
      doc,
      pages[1],
      acceptance_name_for_test("/FcnsV"),
    ),
    [0xFE19, 0xFE19],
  )
  let vertical_extractor = doc.text_extractor_of_font(vertical_font)
  @test.assert_eq(
    vertical_extractor.charcode_of_codepoint(0xFE19),
    Some(0xA1AC),
  )
  @test.assert_eq(vertical_extractor.charcode_of_codepoint(0x1F600), None)
}

///|
fn acceptance_assert_vertical_predefined_cmap_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 18)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 18)
  let cases = acceptance_vertical_predefined_cmap_cases_for_test()
  for index, case in cases {
    let font = acceptance_assert_predefined_cmap_font_shape_for_test(
      doc,
      pages[index],
      case.0,
      case.2,
      case.4,
    )
    @test.assert_eq(
      acceptance_font_codepoints_of_page_for_test(
        doc,
        pages[index],
        acceptance_name_for_test(case.0),
      ),
      case.7,
    )
    let extractor = doc.text_extractor_of_font(font)
    @test.assert_eq(extractor.charcode_of_codepoint(case.8), Some(case.9))
    @test.assert_eq(extractor.charcode_of_codepoint(0x1F600), None)
  }
}

///|
fn acceptance_assert_predefined_cmap_font_shape_for_test(
  doc : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
  font_name : String,
  encoding : String,
  ordering : String,
) -> @pdflite.PdfObject raise {
  acceptance_assert_predefined_cmap_font_shape_with_two_byte_for_test(
    doc, page, font_name, encoding, ordering, false,
  )
}

///|
fn acceptance_assert_predefined_cmap_font_shape_with_two_byte_for_test(
  doc : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
  font_name : String,
  encoding : String,
  ordering : String,
  uses_two_byte_codes : Bool,
) -> @pdflite.PdfObject raise {
  let font = acceptance_font_object_by_name_for_test(
    page.resources,
    acceptance_name_for_test(font_name),
  )
  let read = doc.read_font(font)
  @test.assert_eq(read.is_identity_h(), false)
  @test.assert_eq(read.is_identity_v(), false)
  @test.assert_eq(read.uses_two_byte_codes(), uses_two_byte_codes)
  guard read is PdfFontCIDKeyed(cid_font) else {
    fail("expected CID-keyed predefined CMap font")
  }
  @test.assert_eq(
    cid_font.encoding,
    PdfPredefinedCMap(acceptance_name_for_test(encoding)),
  )
  @test.assert_eq(
    cid_font.composite.cid_system_info.ordering,
    acceptance_ascii_for_test(ordering),
  )
  font
}

///|
fn acceptance_assert_bad_predefined_text_for_test(
  extractor : @pdflite.PdfTextExtractor,
  text : @pdflite.PdfBytes,
  message : String,
) -> Unit raise {
  let result = try? extractor.codepoints_of_text(text)
  guard result is Err(_) else { fail(message) }
}

///|
fn acceptance_assert_unicode_predefined_page_for_test(
  doc : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
  font_name : String,
  encoding : String,
  ordering : String,
  uses_two_byte_codes : Bool,
  expected_codepoints : Array[Int],
) -> @pdflite.PdfTextExtractor raise {
  let font = acceptance_assert_predefined_cmap_font_shape_with_two_byte_for_test(
    doc, page, font_name, encoding, ordering, uses_two_byte_codes,
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_page_for_test(
      doc,
      page,
      acceptance_name_for_test(font_name),
    ),
    expected_codepoints,
  )
  doc.text_extractor_of_font(font)
}

///|
fn acceptance_assert_unicode_predefined_cmap_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 7)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 7)
  let ucs2_h = acceptance_assert_unicode_predefined_page_for_test(
    doc,
    pages[0],
    "/FUcs2H",
    "/UniJIS-UCS2-H",
    "Japan1",
    true,
    [0x41, 0x4E00],
  )
  @test.assert_eq(ucs2_h.charcode_of_codepoint(0x4E00), Some(0x4E00))
  acceptance_assert_bad_predefined_text_for_test(
    ucs2_h,
    acceptance_text_bytes_for_test([0x00, 0x41, 0x4E]),
    "expected malformed UCS2 predefined CMap text",
  )
  let ucs2_v = acceptance_assert_unicode_predefined_page_for_test(
    doc,
    pages[1],
    "/FUcs2V",
    "/UniCNS-UCS2-V",
    "CNS1",
    true,
    [0x42, 0x4E8C],
  )
  @test.assert_eq(ucs2_v.charcode_of_codepoint(0x4E8C), Some(0x4E8C))
  let utf16_h = acceptance_assert_unicode_predefined_page_for_test(
    doc,
    pages[2],
    "/FUtf16H",
    "/UniJIS-UTF16-H",
    "Japan1",
    true,
    [0x3042, 0x30A2, 0x1D11E],
  )
  @test.assert_eq(utf16_h.charcode_of_codepoint(0x3042), Some(0x3042))
  @test.assert_eq(utf16_h.charcode_of_codepoint(0x1D11E), Some(0xD834DD1E))
  acceptance_assert_bad_predefined_text_for_test(
    utf16_h,
    acceptance_text_bytes_for_test([0xD8, 0x34, 0x30, 0x42]),
    "expected malformed UTF16 predefined CMap text",
  )
  let utf16_v = acceptance_assert_unicode_predefined_page_for_test(
    doc,
    pages[3],
    "/FUtf16V",
    "/UniCNS-UTF16-V",
    "CNS1",
    true,
    [0x4E00, 0x4E8C],
  )
  @test.assert_eq(utf16_v.charcode_of_codepoint(0x4E8C), Some(0x4E8C))
  let utf8_h = acceptance_assert_unicode_predefined_page_for_test(
    doc,
    pages[4],
    "/FUtf8H",
    "/UniJIS-UTF8-H",
    "Japan1",
    false,
    [0x41, 0x3042, 0x1D11E],
  )
  @test.assert_eq(utf8_h.charcode_of_codepoint(0x3042), Some(0xE38182))
  @test.assert_eq(utf8_h.charcode_of_codepoint(0x1D11E), Some(0xF09D849E))
  acceptance_assert_bad_predefined_text_for_test(
    utf8_h,
    acceptance_text_bytes_for_test([0xE3, 0x81]),
    "expected malformed UTF8 predefined CMap text",
  )
  let utf32_v = acceptance_assert_unicode_predefined_page_for_test(
    doc,
    pages[5],
    "/FUtf32V",
    "/UniCNS-UTF32-V",
    "CNS1",
    false,
    [0x41, 0x1D11E],
  )
  @test.assert_eq(utf32_v.charcode_of_codepoint(0x1D11E), Some(0x1D11E))
  acceptance_assert_bad_predefined_text_for_test(
    utf32_v,
    acceptance_text_bytes_for_test([0x00, 0x00, 0xD8, 0x00]),
    "expected malformed UTF32 predefined CMap text",
  )
  let utf8_tounicode = acceptance_assert_unicode_predefined_page_for_test(
    doc,
    pages[6],
    "/FUtf8TU",
    "/UniJIS-UTF8-H",
    "Japan1",
    false,
    [0x2603, 0x03A9],
  )
  @test.assert_eq(utf8_tounicode.charcode_of_codepoint(0x2603), Some(0xE38182))
  @test.assert_eq(
    utf8_tounicode.charcode_of_codepoint(0x03A9),
    Some(0xF09D849E),
  )
}

///|
fn acceptance_assert_korea_cmap_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 3)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 3)
  let uhc_font = acceptance_assert_predefined_cmap_font_shape_for_test(
    doc,
    pages[0],
    "/Fuhc",
    "/KSCms-UHC-H",
    "Korea1",
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_page_for_test(
      doc,
      pages[0],
      acceptance_name_for_test("/Fuhc"),
    ),
    [0x41, 0xAC00, 0xD55C, 0xAE00, 0xAC02, 0x3164, 0x8140],
  )
  let uhc_extractor = doc.text_extractor_of_font(uhc_font)
  @test.assert_eq(uhc_extractor.charcode_of_codepoint(0x41), Some(0x41))
  @test.assert_eq(uhc_extractor.charcode_of_codepoint(0xAC00), Some(0xB0A1))
  @test.assert_eq(uhc_extractor.charcode_of_codepoint(0xD55C), Some(0xC7D1))
  @test.assert_eq(uhc_extractor.charcode_of_codepoint(0xAC02), Some(0x8141))
  @test.assert_eq(uhc_extractor.charcode_of_codepoint(0x3164), Some(0xA4D4))
  @test.assert_eq(uhc_extractor.charcode_of_codepoint(0x1F600), None)
  let ksc_euc_font = acceptance_assert_predefined_cmap_font_shape_for_test(
    doc,
    pages[1],
    "/Fksc",
    "/KSC-EUC-H",
    "Korea1",
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_page_for_test(
      doc,
      pages[1],
      acceptance_name_for_test("/Fksc"),
    ),
    [0x41, 0x203E, 0x3000, 0xAC00, 0xD55C, 0x80, 0xA4D4],
  )
  let ksc_euc_extractor = doc.text_extractor_of_font(ksc_euc_font)
  @test.assert_eq(ksc_euc_extractor.charcode_of_codepoint(0x41), Some(0x41))
  @test.assert_eq(ksc_euc_extractor.charcode_of_codepoint(0x203E), Some(0x7E))
  @test.assert_eq(ksc_euc_extractor.charcode_of_codepoint(0x3000), Some(0xA1A1))
  @test.assert_eq(ksc_euc_extractor.charcode_of_codepoint(0xAC00), Some(0xB0A1))
  @test.assert_eq(ksc_euc_extractor.charcode_of_codepoint(0xD55C), Some(0xC7D1))
  @test.assert_eq(ksc_euc_extractor.charcode_of_codepoint(0x4E0D), Some(0xDCF4))
  @test.assert_eq(ksc_euc_extractor.charcode_of_codepoint(0x3164), None)
  let kscpc_euc_font = acceptance_assert_predefined_cmap_font_shape_for_test(
    doc,
    pages[2],
    "/Fkscpc",
    "/KSCpc-EUC-H",
    "Korea1",
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_page_for_test(
      doc,
      pages[2],
      acceptance_name_for_test("/Fkscpc"),
    ),
    [
      0x41, 0x00A0, 0x20A9, 0xFF3F, 0x9F, 0x2122, 0x22EF, 0x300C, 0x28, 0x28, 0x31,
      0x20DE, 0x5B, 0x31, 0x30, 0x5D, 0xAC00, 0xD55C, 0xA140,
    ],
  )
  let kscpc_euc_extractor = doc.text_extractor_of_font(kscpc_euc_font)
  @test.assert_eq(kscpc_euc_extractor.charcode_of_codepoint(0x28), Some(0x28))
  @test.assert_eq(kscpc_euc_extractor.charcode_of_codepoint(0x20A9), Some(0x81))
  @test.assert_eq(kscpc_euc_extractor.charcode_of_codepoint(0xFF3F), Some(0x84))
  @test.assert_eq(kscpc_euc_extractor.charcode_of_codepoint(0x2122), Some(0xFE))
  @test.assert_eq(kscpc_euc_extractor.charcode_of_codepoint(0x22EF), Some(0xFF))
  @test.assert_eq(
    kscpc_euc_extractor.charcode_of_codepoint(0x300C),
    Some(0xA141),
  )
  @test.assert_eq(
    kscpc_euc_extractor.charcode_of_codepoint(0xAC00),
    Some(0xB0A1),
  )
  @test.assert_eq(kscpc_euc_extractor.charcode_of_codepoint(0x20DE), None)
}

///|
fn acceptance_assert_gb1_cmap_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 3)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 3)
  let gb_euc_font = acceptance_assert_predefined_cmap_font_shape_for_test(
    doc,
    pages[0],
    "/Fgbeuc",
    "/GB-EUC-H",
    "GB1",
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_page_for_test(
      doc,
      pages[0],
      acceptance_name_for_test("/Fgbeuc"),
    ),
    [0x41, 0x4F60, 0x597D, 0x3000, 0xFF21],
  )
  let gb_euc_extractor = doc.text_extractor_of_font(gb_euc_font)
  @test.assert_eq(gb_euc_extractor.charcode_of_codepoint(0x41), Some(0x41))
  @test.assert_eq(gb_euc_extractor.charcode_of_codepoint(0x4F60), Some(0xC4E3))
  @test.assert_eq(gb_euc_extractor.charcode_of_codepoint(0x597D), Some(0xBAC3))
  @test.assert_eq(gb_euc_extractor.charcode_of_codepoint(0x3000), Some(0xA1A1))
  @test.assert_eq(gb_euc_extractor.charcode_of_codepoint(0xFF21), Some(0xA3C1))
  @test.assert_eq(gb_euc_extractor.charcode_of_codepoint(0x20AC), None)
  let gbpc_euc_font = acceptance_assert_predefined_cmap_font_shape_for_test(
    doc,
    pages[1],
    "/Fgbpc",
    "/GBpc-EUC-H",
    "GB1",
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_page_for_test(
      doc,
      pages[1],
      acceptance_name_for_test("/Fgbpc"),
    ),
    [
      0x41, 0x00FC, 0x83, 0x00A0, 0x00A9, 0x2122, 0x2026, 0x3000, 0x301C, 0x006E,
      0x0300, 0x4F60, 0x597D,
    ],
  )
  let gbpc_euc_extractor = doc.text_extractor_of_font(gbpc_euc_font)
  @test.assert_eq(gbpc_euc_extractor.charcode_of_codepoint(0x41), Some(0x41))
  @test.assert_eq(gbpc_euc_extractor.charcode_of_codepoint(0x00FC), Some(0x80))
  @test.assert_eq(gbpc_euc_extractor.charcode_of_codepoint(0x00A9), Some(0xFD))
  @test.assert_eq(gbpc_euc_extractor.charcode_of_codepoint(0x2122), Some(0xFE))
  @test.assert_eq(gbpc_euc_extractor.charcode_of_codepoint(0x2026), Some(0xFF))
  @test.assert_eq(
    gbpc_euc_extractor.charcode_of_codepoint(0x301C),
    Some(0xA1AB),
  )
  @test.assert_eq(
    gbpc_euc_extractor.charcode_of_codepoint(0x4F60),
    Some(0xC4E3),
  )
  @test.assert_eq(
    gbpc_euc_extractor.charcode_of_codepoint(0x597D),
    Some(0xBAC3),
  )
  @test.assert_eq(gbpc_euc_extractor.charcode_of_codepoint(0x0300), None)
  let gbk_font = acceptance_assert_predefined_cmap_font_shape_for_test(
    doc,
    pages[2],
    "/Fgbk",
    "/GBK-EUC-H",
    "GB1",
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_page_for_test(
      doc,
      pages[2],
      acceptance_name_for_test("/Fgbk"),
    ),
    [
      0x41, 0x80, 0x4E02, 0x4F60, 0x597D, 0x3000, 0xFF21, 0xE4C6, 0x1E3F, 0xE4C5,
      0xF8F5, 0x8139,
    ],
  )
  let gbk_extractor = doc.text_extractor_of_font(gbk_font)
  @test.assert_eq(gbk_extractor.charcode_of_codepoint(0x41), Some(0x41))
  @test.assert_eq(gbk_extractor.charcode_of_codepoint(0x80), Some(0x80))
  @test.assert_eq(gbk_extractor.charcode_of_codepoint(0x4E02), Some(0x8140))
  @test.assert_eq(gbk_extractor.charcode_of_codepoint(0x4F60), Some(0xC4E3))
  @test.assert_eq(gbk_extractor.charcode_of_codepoint(0x597D), Some(0xBAC3))
  @test.assert_eq(gbk_extractor.charcode_of_codepoint(0xE4C6), Some(0xA140))
  @test.assert_eq(gbk_extractor.charcode_of_codepoint(0x1E3F), Some(0xA8BC))
  @test.assert_eq(gbk_extractor.charcode_of_codepoint(0xE4C5), Some(0xFEFE))
  @test.assert_eq(gbk_extractor.charcode_of_codepoint(0xF8F5), Some(0xFF))
  @test.assert_eq(gbk_extractor.charcode_of_codepoint(0x1F600), None)
}

///|
fn acceptance_assert_cns1_variant_cmap_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  let cases = acceptance_cns1_variant_cmap_cases_for_test()
  @test.assert_eq(doc.endpage(), cases.length())
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), cases.length())
  for index in 0..<cases.length() {
    let case = cases[index]
    let font = acceptance_assert_predefined_cmap_font_shape_for_test(
      doc,
      pages[index],
      case.0,
      case.2,
      "CNS1",
    )
    @test.assert_eq(
      acceptance_font_codepoints_of_page_for_test(
        doc,
        pages[index],
        acceptance_name_for_test(case.0),
      ),
      case.6,
    )
    let extractor = doc.text_extractor_of_font(font)
    @test.assert_eq(extractor.charcode_of_codepoint(case.7), Some(case.8))
    @test.assert_eq(extractor.charcode_of_codepoint(0x1F600), None)
  }
}

///|
fn acceptance_assert_japan1_cmap_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  let cases = acceptance_japan1_cmap_cases_for_test()
  @test.assert_eq(doc.endpage(), cases.length())
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), cases.length())
  for index in 0..<cases.length() {
    let case = cases[index]
    let font = acceptance_assert_predefined_cmap_font_shape_with_two_byte_for_test(
      doc,
      pages[index],
      case.0,
      case.2,
      "Japan1",
      case.9,
    )
    @test.assert_eq(
      acceptance_font_codepoints_of_page_for_test(
        doc,
        pages[index],
        acceptance_name_for_test(case.0),
      ),
      case.6,
    )
    let extractor = doc.text_extractor_of_font(font)
    @test.assert_eq(extractor.charcode_of_codepoint(case.7), Some(case.8))
    if case.10 >= 0 {
      @test.assert_eq(extractor.charcode_of_codepoint(case.10), None)
    }
  }
}

///|
fn acceptance_assert_japan1_90msp_cmap_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  let cases = acceptance_japan1_90msp_cmap_cases_for_test()
  @test.assert_eq(doc.endpage(), cases.length())
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), cases.length())
  for index in 0..<cases.length() {
    let case = cases[index]
    let font = acceptance_assert_predefined_cmap_font_shape_with_two_byte_for_test(
      doc,
      pages[index],
      case.0,
      case.2,
      "Japan1",
      case.9,
    )
    @test.assert_eq(
      acceptance_font_codepoints_of_page_for_test(
        doc,
        pages[index],
        acceptance_name_for_test(case.0),
      ),
      case.6,
    )
    let extractor = doc.text_extractor_of_font(font)
    @test.assert_eq(extractor.charcode_of_codepoint(case.7), Some(case.8))
    @test.assert_eq(extractor.charcode_of_codepoint(case.10), None)
  }
}

///|
fn acceptance_assert_japan1_legacy_cmap_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  let cases = acceptance_japan1_legacy_cmap_cases_for_test()
  @test.assert_eq(doc.endpage(), cases.length())
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), cases.length())
  for index in 0..<cases.length() {
    let case = cases[index]
    let font = acceptance_assert_predefined_cmap_font_shape_with_two_byte_for_test(
      doc,
      pages[index],
      case.0,
      case.2,
      "Japan1",
      case.9,
    )
    @test.assert_eq(
      acceptance_font_codepoints_of_page_for_test(
        doc,
        pages[index],
        acceptance_name_for_test(case.0),
      ),
      case.6,
    )
    let extractor = doc.text_extractor_of_font(font)
    @test.assert_eq(extractor.charcode_of_codepoint(case.7), Some(case.8))
    @test.assert_eq(extractor.charcode_of_codepoint(case.10), None)
  }
}

///|
fn acceptance_assert_japan1_supplemental_cmap_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  let cases = acceptance_japan1_supplemental_cmap_cases_for_test()
  @test.assert_eq(doc.endpage(), cases.length())
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), cases.length())
  for index in 0..<cases.length() {
    let case = cases[index]
    let font = acceptance_assert_predefined_cmap_font_shape_with_two_byte_for_test(
      doc,
      pages[index],
      case.0,
      case.2,
      "Japan1",
      case.9,
    )
    @test.assert_eq(
      acceptance_font_codepoints_of_page_for_test(
        doc,
        pages[index],
        acceptance_name_for_test(case.0),
      ),
      case.6,
    )
    let extractor = doc.text_extractor_of_font(font)
    @test.assert_eq(extractor.charcode_of_codepoint(case.7), Some(case.8))
    @test.assert_eq(extractor.charcode_of_codepoint(case.10), None)
  }
}

///|
fn acceptance_truetype_font_file_for_test() -> @pdflite.PdfObject {
  let data = acceptance_ascii_for_test("minimal-ttf-data")
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn acceptance_truetype_descriptor_for_test() -> @pdflite.PdfFontDescriptor raise {
  {
    ascent: 720.0,
    descent: -180.0,
    avgwidth: 501.0,
    maxwidth: 1000.0,
    flags: 32,
    fontbbox: { min_x: -10.0, min_y: -200.0, max_x: 500.0, max_y: 700.0 },
    italicangle: -12.0,
    capheight: 680.0,
    xheight: 450.0,
    stemv: 90.0,
    fontfile: Some(PdfFontFile2(70)),
    charset: None,
    tounicode: Some([
      (65, acceptance_text_bytes_for_test([0x26, 0x03])),
      (66, acceptance_text_bytes_for_test([0x03, 0xA9])),
    ]),
  }
}

///|
fn acceptance_truetype_text_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(70, acceptance_truetype_font_file_for_test())
  let font_number = doc.write_font(
    PdfFontSimple({
      fonttype: PdfTrueType,
      basefont: Some(acceptance_name_for_test("/Subset+NativeTT")),
      firstchar: 33,
      lastchar: 34,
      widths: [500, 610],
      fontdescriptor: Some(acceptance_truetype_descriptor_for_test()),
      fontmetrics: None,
      encoding: PdfWinAnsiEncoding,
    }),
    objnum=Some(73),
  )
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/Ftt"), PdfIndirect(font_number)),
      ]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_BT,
        Op_Tf(acceptance_name_for_test("/Ftt"), 12.0),
        Op_Tj(acceptance_text_bytes_for_test([33, 34])),
        Op_ET,
      ]),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_assert_truetype_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font = acceptance_font_object_by_name_for_test(
    pages[0].resources,
    acceptance_name_for_test("/Ftt"),
  )
  guard doc.read_font(font) is PdfFontSimple(simple) else {
    fail("expected simple TrueType font")
  }
  let font_object = doc.direct(font)
  @test.assert_eq(simple.fonttype, PdfTrueType)
  @test.assert_eq(
    simple.basefont,
    Some(acceptance_name_for_test("/Subset+NativeTT")),
  )
  @test.assert_eq(
    font_object.lookup_immediate(acceptance_name_for_test("/FirstChar")),
    Some(PdfInteger(33)),
  )
  @test.assert_eq(
    font_object.lookup_immediate(acceptance_name_for_test("/LastChar")),
    Some(PdfInteger(34)),
  )
  @test.assert_eq(
    font_object.lookup_immediate(acceptance_name_for_test("/Widths")),
    Some(PdfArray([PdfInteger(500), PdfInteger(610)])),
  )
  guard simple.fontmetrics is Some(metrics) else {
    fail("expected TrueType font metrics")
  }
  @test.assert_eq(metrics[33], 500.0)
  @test.assert_eq(metrics[34], 610.0)
  guard simple.fontdescriptor is Some(descriptor) else {
    fail("expected TrueType font descriptor")
  }
  @test.assert_eq(descriptor.ascent, 720.0)
  @test.assert_eq(descriptor.descent, -180.0)
  @test.assert_eq(descriptor.avgwidth, 501.0)
  @test.assert_eq(descriptor.maxwidth, 1000.0)
  @test.assert_eq(descriptor.flags, 32)
  @test.assert_eq(descriptor.fontbbox, {
    min_x: -10.0,
    min_y: -200.0,
    max_x: 500.0,
    max_y: 700.0,
  })
  @test.assert_eq(descriptor.italicangle, -12.0)
  @test.assert_eq(descriptor.capheight, 680.0)
  @test.assert_eq(descriptor.xheight, 450.0)
  @test.assert_eq(descriptor.stemv, 90.0)
  @test.assert_eq(descriptor.fontfile, Some(PdfFontFile2(70)))
  @test.assert_eq(
    descriptor.tounicode,
    Some([
      (33, acceptance_text_bytes_for_test([0x26, 0x03])),
      (34, acceptance_text_bytes_for_test([0x03, 0xA9])),
    ]),
  )
  @test.assert_eq(
    acceptance_font_codepoints_of_first_page_for_test(
      doc,
      acceptance_name_for_test("/Ftt"),
    ),
    [0x2603, 0x03A9],
  )
  let extractor = doc.text_extractor_of_font(font)
  @test.assert_eq(extractor.charcode_of_codepoint(0x2603), Some(33))
  @test.assert_eq(extractor.charcode_of_codepoint(0x03A9), Some(34))
}

///|
fn acceptance_indexed_image_palette_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255])
}

///|
fn acceptance_indexed_image_sample_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([0x1B])
}

///|
fn acceptance_expected_indexed_rgb24_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([0, 0, 0, 255, 0, 0, 0, 255, 0, 0, 0, 255])
}

///|
fn acceptance_expected_ccitt_rgb24_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([
    255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 255, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0,
  ])
}

///|
fn acceptance_image_indexed_xobject_for_test() -> @pdflite.PdfObject raise {
  let encoded = @pdflite.pdf_flate_encode(
    acceptance_indexed_image_sample_for_test(),
  )
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(4)),
      (acceptance_name_for_test("/Height"), PdfInteger(1)),
      (
        acceptance_name_for_test("/ColorSpace"),
        PdfArray([
          PdfNameObject(acceptance_name_for_test("/Indexed")),
          PdfNameObject(acceptance_name_for_test("/DeviceRGB")),
          PdfInteger(3),
          PdfString(acceptance_indexed_image_palette_for_test()),
        ]),
      ),
      (acceptance_name_for_test("/BitsPerComponent"), PdfInteger(2)),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_image_ccitt_xobject_for_test() -> @pdflite.PdfObject raise {
  let encoded = acceptance_text_bytes_for_test([
    0xB6, 0x6A, 0x28, 0x00, 0x80, 0x08,
  ])
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(8)),
      (acceptance_name_for_test("/Height"), PdfInteger(2)),
      (
        acceptance_name_for_test("/ColorSpace"),
        PdfNameObject(acceptance_name_for_test("/DeviceGray")),
      ),
      (acceptance_name_for_test("/BitsPerComponent"), PdfInteger(1)),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/CCITTFaxDecode")),
      ),
      (
        acceptance_name_for_test("/DecodeParms"),
        @pdflite.pdf_dictionary([
          (acceptance_name_for_test("/Columns"), PdfInteger(8)),
          (acceptance_name_for_test("/Rows"), PdfInteger(2)),
        ]),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_jpeg_payload_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([
    0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x04, 0x45, 0x49, 0xFF, 0x00, 0xFF, 0xD9,
  ])
}

///|
fn acceptance_image_jpeg_xobject_for_test() -> @pdflite.PdfObject raise {
  let encoded = @pdflite.pdf_flate_encode(acceptance_jpeg_payload_for_test())
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(1)),
      (acceptance_name_for_test("/Height"), PdfInteger(1)),
      (
        acceptance_name_for_test("/ColorSpace"),
        PdfNameObject(acceptance_name_for_test("/DeviceGray")),
      ),
      (
        acceptance_name_for_test("/Decode"),
        PdfArray([PdfInteger(1), PdfInteger(0)]),
      ),
      (
        acceptance_name_for_test("/Filter"),
        PdfArray([
          PdfNameObject(acceptance_name_for_test("/FlateDecode")),
          PdfNameObject(acceptance_name_for_test("/DCTDecode")),
        ]),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_image_jpx_xobject_for_test() -> @pdflite.PdfObject {
  let data = acceptance_ascii_for_test("jpx-data")
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(1)),
      (acceptance_name_for_test("/Height"), PdfInteger(1)),
      (
        acceptance_name_for_test("/ColorSpace"),
        PdfNameObject(acceptance_name_for_test("/DeviceRGB")),
      ),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/JPXDecode")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn acceptance_image_jbig2_globals_for_test() -> @pdflite.PdfObject {
  let data = acceptance_ascii_for_test("jbig2-globals")
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn acceptance_image_jbig2_xobject_for_test() -> @pdflite.PdfObject {
  let encoded = @pdflite.pdf_flate_encode(
    acceptance_ascii_for_test("jbig2-data"),
  )
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(1)),
      (acceptance_name_for_test("/Height"), PdfInteger(1)),
      (
        acceptance_name_for_test("/Filter"),
        PdfArray([
          PdfNameObject(acceptance_name_for_test("/FlateDecode")),
          PdfNameObject(acceptance_name_for_test("/JBIG2Decode")),
        ]),
      ),
      (
        acceptance_name_for_test("/DecodeParms"),
        PdfArray([
          PdfNull,
          @pdflite.pdf_dictionary([
            (acceptance_name_for_test("/JBIG2Globals"), PdfIndirect(73)),
          ]),
        ]),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_inline_image_dictionary_for_test() -> @pdflite.PdfObject {
  PdfDictionary([
    (acceptance_name_for_test("/W"), PdfInteger(3)),
    (acceptance_name_for_test("/H"), PdfInteger(1)),
    (
      acceptance_name_for_test("/CS"),
      PdfNameObject(acceptance_name_for_test("/G")),
    ),
    (acceptance_name_for_test("/BPC"), PdfInteger(1)),
  ])
}

///|
fn acceptance_inline_image_data_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([0xA0])
}

///|
fn acceptance_inline_jpeg_dictionary_for_test() -> @pdflite.PdfObject {
  PdfDictionary([
    (acceptance_name_for_test("/W"), PdfInteger(1)),
    (acceptance_name_for_test("/H"), PdfInteger(1)),
    (
      acceptance_name_for_test("/F"),
      PdfNameObject(acceptance_name_for_test("/DCT")),
    ),
  ])
}

///|
fn acceptance_image_content_ops_for_test() -> Array[@pdflite.PdfContentOp] raise {
  [
    Op_Do(acceptance_name_for_test("/ImRaw")),
    Op_Do(acceptance_name_for_test("/ImCcitt")),
    Op_Do(acceptance_name_for_test("/ImJpeg")),
    Op_Do(acceptance_name_for_test("/ImJpx")),
    Op_Do(acceptance_name_for_test("/ImJbig2")),
    Op_InlineImage(
      acceptance_inline_image_dictionary_for_test(),
      None,
      acceptance_inline_image_data_for_test(),
    ),
    Op_InlineImage(
      acceptance_inline_jpeg_dictionary_for_test(),
      None,
      acceptance_jpeg_payload_for_test(),
    ),
  ]
}

///|
fn acceptance_image_lifecycle_document_for_test() -> @pdflite.PdfDocument raise {
  let raw_name = acceptance_name_for_test("/ImRaw")
  let ccitt_name = acceptance_name_for_test("/ImCcitt")
  let jpeg_name = acceptance_name_for_test("/ImJpeg")
  let jpx_name = acceptance_name_for_test("/ImJpx")
  let jbig2_name = acceptance_name_for_test("/ImJbig2")
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(70, acceptance_image_indexed_xobject_for_test())
  doc.add_object_given_number(75, acceptance_image_ccitt_xobject_for_test())
  doc.add_object_given_number(71, acceptance_image_jpeg_xobject_for_test())
  doc.add_object_given_number(72, acceptance_image_jpx_xobject_for_test())
  doc.add_object_given_number(73, acceptance_image_jbig2_globals_for_test())
  doc.add_object_given_number(74, acceptance_image_jbig2_xobject_for_test())
  let resources = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/XObject"),
      @pdflite.pdf_dictionary([
        (raw_name, PdfIndirect(70)),
        (ccitt_name, PdfIndirect(75)),
        (jpeg_name, PdfIndirect(71)),
        (jpx_name, PdfIndirect(72)),
        (jbig2_name, PdfIndirect(74)),
      ]),
    ),
  ])
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops(
        acceptance_image_content_ops_for_test(),
      ),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_encoded_image_alias_lab_space_for_test() -> @pdflite.PdfObject {
  PdfArray([
    PdfNameObject(acceptance_name_for_test("/Lab")),
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/WhitePoint"),
        PdfArray([PdfInteger(1), PdfInteger(1), PdfInteger(1)]),
      ),
      (
        acceptance_name_for_test("/Range"),
        PdfArray([
          PdfInteger(-80),
          PdfInteger(90),
          PdfInteger(-70),
          PdfInteger(85),
        ]),
      ),
    ]),
  ])
}

///|
fn acceptance_encoded_image_alias_jpeg_payload_for_test() -> @pdflite.PdfBytes {
  acceptance_ascii_for_test("alias-lab-jpeg")
}

///|
fn acceptance_encoded_image_alias_jpeg_xobject_for_test() -> @pdflite.PdfObject {
  let data = acceptance_encoded_image_alias_jpeg_payload_for_test()
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/W"), PdfInteger(1)),
      (acceptance_name_for_test("/H"), PdfInteger(1)),
      (
        acceptance_name_for_test("/ColorSpace"),
        PdfNameObject(acceptance_name_for_test("/NamedLabJpeg")),
      ),
      (
        acceptance_name_for_test("/F"),
        PdfNameObject(acceptance_name_for_test("/DCT")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn acceptance_encoded_image_alias_jpx_payload_for_test() -> @pdflite.PdfBytes {
  acceptance_ascii_for_test("alias-jpx")
}

///|
fn acceptance_encoded_image_alias_jpx_xobject_for_test() -> @pdflite.PdfObject {
  let data = acceptance_encoded_image_alias_jpx_payload_for_test()
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/W"), PdfInteger(1)),
      (acceptance_name_for_test("/H"), PdfInteger(1)),
      (
        acceptance_name_for_test("/F"),
        PdfNameObject(acceptance_name_for_test("/JPXDecode")),
      ),
      (
        acceptance_name_for_test("/Decode"),
        PdfArray([
          PdfInteger(0),
          PdfInteger(1),
          PdfInteger(1),
          PdfInteger(0),
          PdfInteger(0),
          PdfInteger(1),
        ]),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn acceptance_encoded_image_alias_jbig2_globals_for_test() -> @pdflite.PdfObject {
  let data = acceptance_ascii_for_test("alias-jbig2-globals")
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn acceptance_encoded_image_alias_jbig2_payload_for_test() -> @pdflite.PdfBytes {
  acceptance_ascii_for_test("alias-jbig2")
}

///|
fn acceptance_encoded_image_alias_jbig2_xobject_for_test() -> @pdflite.PdfObject {
  let data = acceptance_encoded_image_alias_jbig2_payload_for_test()
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/W"), PdfInteger(1)),
      (acceptance_name_for_test("/H"), PdfInteger(1)),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/JBIG2Decode")),
      ),
      (
        acceptance_name_for_test("/DP"),
        @pdflite.pdf_dictionary([
          (acceptance_name_for_test("/JBIG2Globals"), PdfIndirect(198)),
        ]),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn acceptance_encoded_image_alias_content_ops_for_test() -> Array[
  @pdflite.PdfContentOp,
] {
  [
    Op_Do(acceptance_name_for_test("/ImAliasJpeg")),
    Op_Do(acceptance_name_for_test("/ImAliasJpx")),
    Op_Do(acceptance_name_for_test("/ImAliasJbig2")),
  ]
}

///|
fn acceptance_encoded_image_alias_resources_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/ColorSpace"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/NamedLabJpeg"),
          acceptance_encoded_image_alias_lab_space_for_test(),
        ),
      ]),
    ),
    (
      acceptance_name_for_test("/XObject"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/ImAliasJpeg"), PdfIndirect(196)),
        (acceptance_name_for_test("/ImAliasJpx"), PdfIndirect(197)),
        (acceptance_name_for_test("/ImAliasJbig2"), PdfIndirect(199)),
      ]),
    ),
  ])
}

///|
fn acceptance_encoded_image_alias_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(
    196,
    acceptance_encoded_image_alias_jpeg_xobject_for_test(),
  )
  doc.add_object_given_number(
    197,
    acceptance_encoded_image_alias_jpx_xobject_for_test(),
  )
  doc.add_object_given_number(
    198,
    acceptance_encoded_image_alias_jbig2_globals_for_test(),
  )
  doc.add_object_given_number(
    199,
    acceptance_encoded_image_alias_jbig2_xobject_for_test(),
  )
  let resources = acceptance_encoded_image_alias_resources_for_test()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops(
        acceptance_encoded_image_alias_content_ops_for_test(),
      ),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_named_image_rgb_sample_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([9, 40, 80, 200, 210, 220])
}

///|
fn acceptance_named_image_rgb_xobject_for_test() -> @pdflite.PdfObject raise {
  let encoded = @pdflite.pdf_flate_encode(
    acceptance_named_image_rgb_sample_for_test(),
  )
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(2)),
      (acceptance_name_for_test("/Height"), PdfInteger(1)),
      (
        acceptance_name_for_test("/CS"),
        PdfNameObject(acceptance_name_for_test("/NamedRGB")),
      ),
      (acceptance_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_named_image_gray_sample_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([0, 255])
}

///|
fn acceptance_named_image_gray_xobject_for_test() -> @pdflite.PdfObject raise {
  let encoded = @pdflite.pdf_flate_encode(
    acceptance_named_image_gray_sample_for_test(),
  )
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(2)),
      (acceptance_name_for_test("/Height"), PdfInteger(1)),
      (
        acceptance_name_for_test("/ColorSpace"),
        PdfNameObject(acceptance_name_for_test("/NamedGray")),
      ),
      (acceptance_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        acceptance_name_for_test("/Decode"),
        PdfArray([PdfInteger(255), PdfInteger(0)]),
      ),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_named_image_mask_xobject_for_test() -> @pdflite.PdfObject raise {
  let encoded = @pdflite.pdf_flate_encode(
    acceptance_text_bytes_for_test([0x80]),
  )
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(2)),
      (acceptance_name_for_test("/Height"), PdfInteger(1)),
      (acceptance_name_for_test("/ImageMask"), PdfBoolean(true)),
      (
        acceptance_name_for_test("/Decode"),
        PdfArray([PdfInteger(1), PdfInteger(0)]),
      ),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_named_image_indexed_palette_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([10, 20, 30, 40, 50, 60])
}

///|
fn acceptance_named_image_indexed_sample_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([0b0100_0000])
}

///|
fn acceptance_named_image_indexed_xobject_for_test() -> @pdflite.PdfObject raise {
  let encoded = @pdflite.pdf_flate_encode(
    acceptance_named_image_indexed_sample_for_test(),
  )
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(2)),
      (acceptance_name_for_test("/Height"), PdfInteger(1)),
      (
        acceptance_name_for_test("/ColorSpace"),
        PdfNameObject(acceptance_name_for_test("/NamedIndexed")),
      ),
      (acceptance_name_for_test("/BitsPerComponent"), PdfInteger(1)),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_named_image_content_ops_for_test() -> Array[@pdflite.PdfContentOp] {
  [
    Op_Do(acceptance_name_for_test("/ImNamedRGB")),
    Op_Do(acceptance_name_for_test("/ImNamedGray")),
    Op_Do(acceptance_name_for_test("/ImMask")),
    Op_Do(acceptance_name_for_test("/ImNamedIndexed")),
  ]
}

///|
fn acceptance_named_image_resources_for_test() -> @pdflite.PdfObject raise {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/ColorSpace"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/NamedRGB"),
          PdfNameObject(acceptance_name_for_test("/DeviceRGB")),
        ),
        (
          acceptance_name_for_test("/NamedGray"),
          PdfNameObject(acceptance_name_for_test("/DeviceGray")),
        ),
        (
          acceptance_name_for_test("/NamedIndexed"),
          PdfArray([
            PdfNameObject(acceptance_name_for_test("/Indexed")),
            PdfNameObject(acceptance_name_for_test("/DeviceRGB")),
            PdfInteger(1),
            PdfString(acceptance_named_image_indexed_palette_for_test()),
          ]),
        ),
      ]),
    ),
    (
      acceptance_name_for_test("/XObject"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/ImNamedRGB"), PdfIndirect(80)),
        (acceptance_name_for_test("/ImNamedGray"), PdfIndirect(81)),
        (acceptance_name_for_test("/ImMask"), PdfIndirect(82)),
        (acceptance_name_for_test("/ImNamedIndexed"), PdfIndirect(83)),
      ]),
    ),
  ])
}

///|
fn acceptance_named_image_resource_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(80, acceptance_named_image_rgb_xobject_for_test())
  doc.add_object_given_number(
    81,
    acceptance_named_image_gray_xobject_for_test(),
  )
  doc.add_object_given_number(
    82,
    acceptance_named_image_mask_xobject_for_test(),
  )
  doc.add_object_given_number(
    83,
    acceptance_named_image_indexed_xobject_for_test(),
  )
  let resources = acceptance_named_image_resources_for_test()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops(
        acceptance_named_image_content_ops_for_test(),
      ),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_cmyk_image_sample_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([
    0, 0, 0, 0, 0, 255, 255, 0, 255, 0, 255, 0, 255, 255, 0, 0,
  ])
}

///|
fn acceptance_expected_cmyk_rgb24_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([
    255, 255, 255, 255, 0, 0, 0, 255, 0, 0, 0, 255,
  ])
}

///|
fn acceptance_cmyk_image_xobject_for_test() -> @pdflite.PdfObject raise {
  let encoded = @pdflite.pdf_flate_encode(
    acceptance_cmyk_image_sample_for_test(),
  )
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(4)),
      (acceptance_name_for_test("/Height"), PdfInteger(1)),
      (
        acceptance_name_for_test("/CS"),
        PdfNameObject(acceptance_name_for_test("/NamedCMYK")),
      ),
      (acceptance_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_cmyk_decoded_xobject_for_test() -> @pdflite.PdfObject raise {
  let encoded = @pdflite.pdf_flate_encode(
    acceptance_text_bytes_for_test([0, 0, 0, 0]),
  )
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(1)),
      (acceptance_name_for_test("/Height"), PdfInteger(1)),
      (
        acceptance_name_for_test("/ColorSpace"),
        PdfNameObject(acceptance_name_for_test("/DeviceCMYK")),
      ),
      (acceptance_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        acceptance_name_for_test("/Decode"),
        PdfArray([
          PdfInteger(0),
          PdfInteger(255),
          PdfInteger(0),
          PdfInteger(255),
          PdfInteger(0),
          PdfInteger(255),
          PdfInteger(255),
          PdfInteger(0),
        ]),
      ),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_indexed_cmyk_image_sample_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([0b0001_1011])
}

///|
fn acceptance_indexed_cmyk_image_xobject_for_test() -> @pdflite.PdfObject raise {
  let encoded = @pdflite.pdf_flate_encode(
    acceptance_indexed_cmyk_image_sample_for_test(),
  )
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(4)),
      (acceptance_name_for_test("/Height"), PdfInteger(1)),
      (
        acceptance_name_for_test("/ColorSpace"),
        PdfNameObject(acceptance_name_for_test("/NamedIndexedCMYK")),
      ),
      (acceptance_name_for_test("/BitsPerComponent"), PdfInteger(2)),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_cmyk_image_content_ops_for_test() -> Array[@pdflite.PdfContentOp] {
  [
    Op_Do(acceptance_name_for_test("/ImRawCMYK")),
    Op_Do(acceptance_name_for_test("/ImDecodeCMYK")),
    Op_Do(acceptance_name_for_test("/ImIndexedCMYK")),
  ]
}

///|
fn acceptance_cmyk_image_resources_for_test() -> @pdflite.PdfObject raise {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/ColorSpace"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/NamedCMYK"),
          PdfNameObject(acceptance_name_for_test("/DeviceCMYK")),
        ),
        (
          acceptance_name_for_test("/NamedIndexedCMYK"),
          PdfArray([
            PdfNameObject(acceptance_name_for_test("/Indexed")),
            PdfNameObject(acceptance_name_for_test("/DeviceCMYK")),
            PdfInteger(3),
            PdfString(acceptance_cmyk_image_sample_for_test()),
          ]),
        ),
      ]),
    ),
    (
      acceptance_name_for_test("/XObject"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/ImRawCMYK"), PdfIndirect(88)),
        (acceptance_name_for_test("/ImDecodeCMYK"), PdfIndirect(89)),
        (acceptance_name_for_test("/ImIndexedCMYK"), PdfIndirect(90)),
      ]),
    ),
  ])
}

///|
fn acceptance_cmyk_image_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(88, acceptance_cmyk_image_xobject_for_test())
  doc.add_object_given_number(89, acceptance_cmyk_decoded_xobject_for_test())
  doc.add_object_given_number(
    90,
    acceptance_indexed_cmyk_image_xobject_for_test(),
  )
  let resources = acceptance_cmyk_image_resources_for_test()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops(
        acceptance_cmyk_image_content_ops_for_test(),
      ),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_alt_image_icc_profile_for_test() -> @pdflite.PdfObject {
  let data = acceptance_ascii_for_test("icc")
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/N"), PdfInteger(1)),
      (acceptance_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn acceptance_alt_image_icc_gray_sample_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([9, 10])
}

///|
fn acceptance_alt_image_icc_gray_xobject_for_test() -> @pdflite.PdfObject raise {
  let encoded = @pdflite.pdf_flate_encode(
    acceptance_alt_image_icc_gray_sample_for_test(),
  )
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(2)),
      (acceptance_name_for_test("/Height"), PdfInteger(1)),
      (
        acceptance_name_for_test("/ColorSpace"),
        PdfNameObject(acceptance_name_for_test("/NamedICCGray")),
      ),
      (acceptance_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_alt_image_separation_tint_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (acceptance_name_for_test("/FunctionType"), PdfInteger(2)),
    (
      acceptance_name_for_test("/Domain"),
      PdfArray([PdfInteger(0), PdfInteger(1)]),
    ),
    (
      acceptance_name_for_test("/C0"),
      PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(0), PdfInteger(0)]),
    ),
    (
      acceptance_name_for_test("/C1"),
      PdfArray([PdfInteger(0), PdfInteger(1), PdfInteger(0), PdfInteger(0)]),
    ),
    (acceptance_name_for_test("/N"), PdfInteger(1)),
  ])
}

///|
fn acceptance_alt_image_separation_xobject_for_test() -> @pdflite.PdfObject raise {
  let encoded = @pdflite.pdf_flate_encode(acceptance_text_bytes_for_test([255]))
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(1)),
      (acceptance_name_for_test("/Height"), PdfInteger(1)),
      (
        acceptance_name_for_test("/ColorSpace"),
        PdfNameObject(acceptance_name_for_test("/NamedSpot")),
      ),
      (acceptance_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_alt_image_device_n_palette_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([0, 0, 0, 0, 0, 255, 255, 0])
}

///|
fn acceptance_alt_image_device_n_xobject_for_test() -> @pdflite.PdfObject raise {
  let encoded = @pdflite.pdf_flate_encode(
    acceptance_text_bytes_for_test([0, 1]),
  )
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(2)),
      (acceptance_name_for_test("/Height"), PdfInteger(1)),
      (
        acceptance_name_for_test("/ColorSpace"),
        PdfNameObject(acceptance_name_for_test("/NamedIndexedDeviceN")),
      ),
      (acceptance_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_alt_image_lab_palette_for_test() -> @pdflite.PdfBytes raise {
  acceptance_text_bytes_for_test([
    127, 127, 127, 255, 127, 127, 255, 255, 255, 255, 0, 0,
  ])
}

///|
fn acceptance_alt_image_lab_xobject_for_test() -> @pdflite.PdfObject raise {
  let encoded = @pdflite.pdf_flate_encode(
    acceptance_text_bytes_for_test([0, 1, 2, 3]),
  )
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XObject")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Image")),
      ),
      (acceptance_name_for_test("/Width"), PdfInteger(4)),
      (acceptance_name_for_test("/Height"), PdfInteger(1)),
      (
        acceptance_name_for_test("/ColorSpace"),
        PdfNameObject(acceptance_name_for_test("/NamedIndexedLab")),
      ),
      (acceptance_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(encoded.length())),
    ]),
    StreamGot(encoded),
  )
}

///|
fn acceptance_alt_image_content_ops_for_test() -> Array[@pdflite.PdfContentOp] {
  [
    Op_Do(acceptance_name_for_test("/ImICCGray")),
    Op_Do(acceptance_name_for_test("/ImSpot")),
    Op_Do(acceptance_name_for_test("/ImDeviceN")),
    Op_Do(acceptance_name_for_test("/ImLab")),
  ]
}

///|
fn acceptance_alt_image_resources_for_test() -> @pdflite.PdfObject raise {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/ColorSpace"),
      @pdflite.pdf_dictionary([
        (
          acceptance_name_for_test("/NamedICCGray"),
          PdfArray([
            PdfNameObject(acceptance_name_for_test("/ICCBased")),
            PdfIndirect(91),
          ]),
        ),
        (
          acceptance_name_for_test("/NamedSpot"),
          PdfArray([
            PdfNameObject(acceptance_name_for_test("/Separation")),
            PdfNameObject(acceptance_name_for_test("/Spot")),
            PdfNameObject(acceptance_name_for_test("/DeviceCMYK")),
            acceptance_alt_image_separation_tint_for_test(),
          ]),
        ),
        (
          acceptance_name_for_test("/NamedIndexedDeviceN"),
          PdfArray([
            PdfNameObject(acceptance_name_for_test("/Indexed")),
            PdfArray([
              PdfNameObject(acceptance_name_for_test("/DeviceN")),
              PdfArray([PdfNameObject(acceptance_name_for_test("/Spot"))]),
              PdfNameObject(acceptance_name_for_test("/DeviceCMYK")),
              PdfNull,
            ]),
            PdfInteger(1),
            PdfString(acceptance_alt_image_device_n_palette_for_test()),
          ]),
        ),
        (
          acceptance_name_for_test("/NamedIndexedLab"),
          PdfArray([
            PdfNameObject(acceptance_name_for_test("/Indexed")),
            PdfArray([
              PdfNameObject(acceptance_name_for_test("/Lab")),
              @pdflite.pdf_dictionary([
                (
                  acceptance_name_for_test("/WhitePoint"),
                  PdfArray([
                    PdfInteger(1000),
                    PdfInteger(1000),
                    PdfInteger(1000),
                  ]),
                ),
              ]),
            ]),
            PdfInteger(3),
            PdfString(acceptance_alt_image_lab_palette_for_test()),
          ]),
        ),
      ]),
    ),
    (
      acceptance_name_for_test("/XObject"),
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/ImICCGray"), PdfIndirect(92)),
        (acceptance_name_for_test("/ImSpot"), PdfIndirect(93)),
        (acceptance_name_for_test("/ImDeviceN"), PdfIndirect(94)),
        (acceptance_name_for_test("/ImLab"), PdfIndirect(95)),
      ]),
    ),
  ])
}

///|
fn acceptance_alt_image_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.add_object_given_number(91, acceptance_alt_image_icc_profile_for_test())
  doc.add_object_given_number(
    92,
    acceptance_alt_image_icc_gray_xobject_for_test(),
  )
  doc.add_object_given_number(
    93,
    acceptance_alt_image_separation_xobject_for_test(),
  )
  doc.add_object_given_number(
    94,
    acceptance_alt_image_device_n_xobject_for_test(),
  )
  doc.add_object_given_number(95, acceptance_alt_image_lab_xobject_for_test())
  let resources = acceptance_alt_image_resources_for_test()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [
      @pdflite.pdf_content_stream_of_ops(
        acceptance_alt_image_content_ops_for_test(),
      ),
    ],
    resources,
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_image_xobject_for_test(
  doc : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  name : @pdflite.PdfName,
) -> @pdflite.PdfObject raise {
  guard doc.lookup_direct(acceptance_name_for_test("/XObject"), resources)
    is Some(xobjects) else {
    fail("expected XObject resources")
  }
  guard doc.lookup_direct(name, xobjects) is Some(image) else {
    fail("expected image XObject")
  }
  image
}

///|
fn acceptance_assert_image_lifecycle_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    doc.parse_content_ops_with_resources(pages[0].resources, pages[0].content),
    acceptance_image_content_ops_for_test(),
  )
  let raw_image = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImRaw"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, raw_image),
    PdfRawImage(4, 1, PdfBPP24, acceptance_expected_indexed_rgb24_for_test()),
  )
  let ccitt_image = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImCcitt"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, ccitt_image),
    PdfRawImage(8, 2, PdfBPP24, acceptance_expected_ccitt_rgb24_for_test()),
  )
  let jpeg_image = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImJpeg"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, jpeg_image),
    PdfJPEG(acceptance_jpeg_payload_for_test(), Some([1.0, 0.0])),
  )
  let jpx_image = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImJpx"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, jpx_image),
    PdfJPEG2000(
      acceptance_ascii_for_test("jpx-data"),
      Some([0.0, 1.0, 0.0, 1.0, 0.0, 1.0]),
    ),
  )
  let jbig2_image = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImJbig2"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, jbig2_image),
    PdfJBIG2(acceptance_ascii_for_test("jbig2-data"), None, Some(73)),
  )
}

///|
fn acceptance_assert_encoded_image_aliases_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    doc.parse_content_ops_with_resources(pages[0].resources, pages[0].content),
    acceptance_encoded_image_alias_content_ops_for_test(),
  )
  let jpeg = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImAliasJpeg"),
  )
  guard jpeg is PdfStreamObject(jpeg_stream) else {
    fail("expected alias JPEG stream")
  }
  @test.assert_eq(
    jpeg_stream.dictionary.lookup_immediate(acceptance_name_for_test("/W")),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(
    jpeg_stream.dictionary.lookup_immediate(acceptance_name_for_test("/H")),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(
    jpeg_stream.dictionary.lookup_immediate(acceptance_name_for_test("/F")),
    Some(PdfNameObject(acceptance_name_for_test("/DCT"))),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, jpeg),
    PdfJPEG(
      acceptance_encoded_image_alias_jpeg_payload_for_test(),
      Some([0.0, 1.0, -80.0, 90.0, -70.0, 85.0]),
    ),
  )
  let jpx = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImAliasJpx"),
  )
  guard jpx is PdfStreamObject(jpx_stream) else {
    fail("expected alias JPX stream")
  }
  @test.assert_eq(
    jpx_stream.dictionary.lookup_immediate(acceptance_name_for_test("/F")),
    Some(PdfNameObject(acceptance_name_for_test("/JPXDecode"))),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, jpx),
    PdfJPEG2000(
      acceptance_encoded_image_alias_jpx_payload_for_test(),
      Some([0.0, 1.0, 1.0, 0.0, 0.0, 1.0]),
    ),
  )
  let jbig2 = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImAliasJbig2"),
  )
  guard jbig2 is PdfStreamObject(jbig2_stream) else {
    fail("expected alias JBIG2 stream")
  }
  @test.assert_eq(
    jbig2_stream.dictionary.lookup_immediate(acceptance_name_for_test("/DP")),
    Some(
      @pdflite.pdf_dictionary([
        (acceptance_name_for_test("/JBIG2Globals"), PdfIndirect(198)),
      ]),
    ),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, jbig2),
    PdfJBIG2(
      acceptance_encoded_image_alias_jbig2_payload_for_test(),
      None,
      Some(198),
    ),
  )
  guard doc.lookup_object_or_null(198) is PdfStreamObject(globals) else {
    fail("expected JBIG2 globals stream")
  }
  @test.assert_eq(
    @pdflite.pdf_stream(globals.dictionary, globals.data).stream_bytes(),
    acceptance_ascii_for_test("alias-jbig2-globals"),
  )
}

///|
fn acceptance_assert_named_image_resources_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    doc.parse_content_ops_with_resources(pages[0].resources, pages[0].content),
    acceptance_named_image_content_ops_for_test(),
  )
  let named_rgb = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImNamedRGB"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, named_rgb),
    PdfRawImage(2, 1, PdfBPP24, acceptance_named_image_rgb_sample_for_test()),
  )
  let named_gray = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImNamedGray"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, named_gray),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      acceptance_text_bytes_for_test([255, 255, 255, 0, 0, 0]),
    ),
  )
  let image_mask = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImMask"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, image_mask),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      acceptance_text_bytes_for_test([0, 0, 0, 255, 255, 255]),
    ),
  )
  let named_indexed = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImNamedIndexed"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, named_indexed),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      acceptance_text_bytes_for_test([10, 20, 30, 40, 50, 60]),
    ),
  )
}

///|
fn acceptance_assert_cmyk_images_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    doc.parse_content_ops_with_resources(pages[0].resources, pages[0].content),
    acceptance_cmyk_image_content_ops_for_test(),
  )
  let raw_cmyk = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImRawCMYK"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, raw_cmyk),
    PdfRawImage(4, 1, PdfBPP24, acceptance_expected_cmyk_rgb24_for_test()),
  )
  let decoded_cmyk = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImDecodeCMYK"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, decoded_cmyk),
    PdfRawImage(1, 1, PdfBPP24, acceptance_text_bytes_for_test([0, 0, 0])),
  )
  let indexed_cmyk = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImIndexedCMYK"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, indexed_cmyk),
    PdfRawImage(4, 1, PdfBPP24, acceptance_expected_cmyk_rgb24_for_test()),
  )
}

///|
fn acceptance_assert_alt_images_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    doc.parse_content_ops_with_resources(pages[0].resources, pages[0].content),
    acceptance_alt_image_content_ops_for_test(),
  )
  let icc_gray = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImICCGray"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, icc_gray),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      acceptance_text_bytes_for_test([9, 9, 9, 10, 10, 10]),
    ),
  )
  let spot = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImSpot"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, spot),
    PdfRawImage(1, 1, PdfBPP24, acceptance_text_bytes_for_test([255, 255, 0])),
  )
  let device_n = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImDeviceN"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, device_n),
    PdfRawImage(
      2,
      1,
      PdfBPP24,
      acceptance_text_bytes_for_test([255, 255, 255, 255, 0, 0]),
    ),
  )
  let lab = acceptance_image_xobject_for_test(
    doc,
    pages[0].resources,
    acceptance_name_for_test("/ImLab"),
  )
  @test.assert_eq(
    doc.get_image_24bpp(pages[0].resources, lab),
    PdfRawImage(
      4,
      1,
      PdfBPP24,
      acceptance_text_bytes_for_test([
        0, 0, 0, 141, 141, 141, 255, 104, 47, 25, 178, 235,
      ]),
    ),
  )
}

///|
fn acceptance_assert_partial_filter_stream_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  let decoded_doc = doc.copy()
  decoded_doc.pdf_decode_streams_until_unknown()
  acceptance_assert_decompressed_partial_filter_stream_for_test(decoded_doc)
}

///|
fn acceptance_assert_decompressed_partial_filter_stream_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  guard doc.lookup_object_or_null(50) is PdfStreamObject(stream) else {
    fail("expected partially decoded acceptance stream")
  }
  @test.assert_eq(
    @pdflite.pdf_stream(stream.dictionary, stream.data).stream_bytes(),
    acceptance_ascii_for_test("Hi"),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(acceptance_name_for_test("/Length")),
    Some(PdfInteger(2)),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(acceptance_name_for_test("/Filter")),
    Some(PdfArray([PdfNameObject(acceptance_name_for_test("/NoSuchFilter"))])),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(acceptance_name_for_test("/DecodeParms")),
    Some(PdfArray([PdfNull])),
  )
}

///|
fn acceptance_assert_public_read_write_for_test(
  bytes : @pdflite.PdfBytes,
  expected_version : (Int, Int),
) -> Unit raise {
  @test.assert_eq(@pdflite.pdf_revisions_from_bytes(bytes), 1)
  let parsed = @pdflite.pdf_read_document_from_bytes(bytes)
  acceptance_assert_one_page_invariants_for_test(parsed, expected_version)
  acceptance_assert_partial_filter_stream_for_test(parsed)
  let rewritten = @pdflite.pdf_write_document(parsed)
  let reparsed = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_one_page_invariants_for_test(reparsed, expected_version)
  acceptance_assert_partial_filter_stream_for_test(reparsed)
}

///|
fn acceptance_add_revision_marker_for_test(
  source : @pdflite.PdfDocument,
  object_number : Int,
  text : String,
) -> @pdflite.PdfDocument raise {
  let updated = source.copy()
  let marker : @pdflite.PdfObject = PdfString(acceptance_ascii_for_test(text))
  updated.add_object_given_number(object_number, marker)
  let catalog = updated.lookup_object_or_null(updated.root())
  updated.add_object_given_number(
    updated.root(),
    catalog.add_dict_entry(
      acceptance_name_for_test("/AcceptanceMarker"),
      PdfIndirect(object_number),
    ),
  )
  updated
}

///|
fn acceptance_assert_revision_marker_for_test(
  doc : @pdflite.PdfDocument,
  object_number : Int,
  text : String,
) -> Unit raise {
  let catalog = doc.catalog()
  @test.assert_eq(
    catalog.lookup_immediate(acceptance_name_for_test("/AcceptanceMarker")),
    Some(PdfIndirect(object_number)),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(object_number),
    PdfString(acceptance_ascii_for_test(text)),
  )
}

///|
fn acceptance_assert_no_revision_marker_for_test(
  doc : @pdflite.PdfDocument,
  object_number : Int,
) -> Unit raise {
  let catalog = doc.catalog()
  @test.assert_eq(
    catalog.lookup_immediate(acceptance_name_for_test("/AcceptanceMarker")),
    None,
  )
  @test.assert_eq(doc.lookup_object_or_null(object_number), PdfNull)
}

///|
fn acceptance_pdf_with_omitted_page_tree_xrefs_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  acceptance_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = acceptance_push_indirect_object_for_test(
    output, 1, 0, "<< /Type /Catalog /Pages 2 0 R >>",
  )
  ignore(
    acceptance_push_indirect_object_for_test(
      output, 2, 0, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    ),
  )
  ignore(
    acceptance_push_indirect_object_for_test(
      output, 3, 0, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] /Resources << >> >>",
    ),
  )
  let xref_offset = output.length()
  acceptance_push_ascii_for_test(output, "xref\n0 2\n0000000000 65535 f \n")
  acceptance_push_xref_entry_for_test(output, catalog_offset, 0)
  acceptance_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 4 >>\nstartxref\n",
  )
  acceptance_push_ascii_for_test(output, xref_offset.to_string())
  acceptance_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn acceptance_pdf_with_tolerated_malformed_xref_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  acceptance_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = acceptance_push_indirect_object_for_test(
    output, 1, 0, "<< /Type /Catalog /Pages 2 0 R >>",
  )
  let pages_offset = acceptance_push_indirect_object_for_test(
    output, 2, 0, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let page_offset = acceptance_push_indirect_object_for_test(
    output, 3, 0, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] /Resources << >> >>",
  )
  let xref_offset = output.length()
  acceptance_push_ascii_for_test(output, "xref 0 4\n0000000000 abcde nJunk\n")
  acceptance_push_padded_decimal_for_test(output, catalog_offset, 10)
  acceptance_push_byte_for_test(output, 95)
  acceptance_push_padded_decimal_for_test(output, 0, 5)
  acceptance_push_ascii_for_test(output, " n \n")
  acceptance_push_xref_entry_for_test(output, pages_offset, 0)
  acceptance_push_xref_entry_for_test(output, page_offset, 0)
  acceptance_push_ascii_for_test(
    output, "trailer<< /Root 1 0 R /Size 4 >>\nstartxref ",
  )
  acceptance_push_ascii_for_test(output, xref_offset.to_string())
  acceptance_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn acceptance_cr_line_endings_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(if byte.to_int() == 10 { (13).to_byte() } else { byte })
  }
  Bytes::from_array(output)
}

///|
fn acceptance_pdf_with_tokenized_xref_rows_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  acceptance_push_ascii_for_test(output, "%PDF-1.4\n")
  let catalog_offset = acceptance_push_indirect_object_for_test(
    output, 1, 0, "<< /Type /Catalog /Pages 2 0 R >>",
  )
  let pages_offset = acceptance_push_indirect_object_for_test(
    output, 2, 0, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
  )
  let page_offset = acceptance_push_indirect_object_for_test(
    output, 3, 0, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] /Resources << >> >>",
  )
  let xref_offset = output.length()
  acceptance_push_ascii_for_test(output, "xref\n1 3\n")
  acceptance_push_ascii_for_test(output, catalog_offset.to_string())
  acceptance_push_ascii_for_test(output, " 0 n\n")
  acceptance_push_ascii_for_test(output, pages_offset.to_string())
  acceptance_push_ascii_for_test(output, " 0 n\n")
  acceptance_push_ascii_for_test(output, page_offset.to_string())
  acceptance_push_ascii_for_test(output, " 0 n\n")
  acceptance_push_ascii_for_test(
    output, "trailer\n<< /Root 1 0 R /Size 4 >>\nstartxref\n",
  )
  acceptance_push_ascii_for_test(output, xref_offset.to_string())
  acceptance_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn acceptance_assert_minimal_page_tree_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 4))
  @test.assert_eq(try! doc.endpage(), 1)
  @test.assert_eq(try! doc.page_reference_numbers(), [3])
  @test.assert_eq(
    doc.lookup_object_or_null(2),
    PdfDictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/Pages")),
      ),
      (acceptance_name_for_test("/Kids"), PdfArray([PdfIndirect(3)])),
      (acceptance_name_for_test("/Count"), PdfInteger(1)),
    ]),
  )
}

///|
fn acceptance_secret_object_for_test(text : String) -> @pdflite.PdfObject {
  PdfDictionary([
    (
      acceptance_name_for_test("/Title"),
      PdfString(acceptance_ascii_for_test(text)),
    ),
  ])
}

///|
fn acceptance_metadata_bytes_for_test() -> @pdflite.PdfBytes {
  acceptance_ascii_for_test("<x:xmpmeta>native metadata gate</x:xmpmeta>")
}

///|
fn acceptance_metadata_stream_for_test(
  data : @pdflite.PdfBytes,
) -> @pdflite.PdfObject {
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/Length"), PdfInteger(data.length())),
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/Metadata")),
      ),
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/XML")),
      ),
    ]),
    StreamGot(data),
  )
}

///|
fn acceptance_metadata_encryption_document_for_test(
  metadata : @pdflite.PdfBytes,
  secret : @pdflite.PdfObject,
) -> @pdflite.PdfDocument raise {
  let doc = acceptance_one_page_document_for_test()
  doc.add_object_given_number(62, acceptance_metadata_stream_for_test(metadata))
  doc.add_object_given_number(63, secret)
  acceptance_add_catalog_entry_for_test(
    doc,
    acceptance_name_for_test("/Metadata"),
    PdfIndirect(62),
  )
  acceptance_add_catalog_entry_for_test(
    doc,
    acceptance_name_for_test("/Secret"),
    PdfIndirect(63),
  )
  doc
}

///|
fn acceptance_assert_metadata_stream_for_test(
  doc : @pdflite.PdfDocument,
  number : Int,
  expected : @pdflite.PdfBytes,
) -> Unit raise {
  guard doc.lookup_object_or_null(number) is PdfStreamObject(stream) else {
    fail("expected metadata stream")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(acceptance_name_for_test("/Type")),
    Some(PdfNameObject(acceptance_name_for_test("/Metadata"))),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(acceptance_name_for_test("/Subtype")),
    Some(PdfNameObject(acceptance_name_for_test("/XML"))),
  )
  @test.assert_eq(
    @pdflite.pdf_stream(stream.dictionary, stream.data).stream_bytes(),
    expected,
  )
}

///|
fn acceptance_assert_metadata_encryption_for_test(
  doc : @pdflite.PdfDocument,
  metadata : @pdflite.PdfBytes,
  secret : @pdflite.PdfObject,
) -> Unit raise {
  acceptance_assert_one_page_invariants_for_test(doc, (1, 5))
  let catalog = doc.catalog()
  @test.assert_eq(
    catalog.lookup_immediate(acceptance_name_for_test("/Metadata")),
    Some(PdfIndirect(62)),
  )
  @test.assert_eq(
    catalog.lookup_immediate(acceptance_name_for_test("/Secret")),
    Some(PdfIndirect(63)),
  )
  acceptance_assert_metadata_stream_for_test(doc, 62, metadata)
  @test.assert_eq(doc.lookup_object_or_null(63), secret)
}

///|
fn acceptance_encrypted_object_stream_pdf_with_passwords_for_test(
  user_password : @pdflite.PdfBytes,
  owner_password : @pdflite.PdfBytes,
  denied_permissions : ArrayView[@pdflite.PdfPermission],
) -> @pdflite.PdfBytes raise {
  let secret = acceptance_secret_object_for_test("encrypted object stream")
  let object_stream_data : Array[Byte] = []
  acceptance_push_ascii_for_test(object_stream_data, "2 0 ")
  let first = object_stream_data.length()
  acceptance_push_view_for_test(
    object_stream_data,
    @pdflite.pdf_write_object(secret),
  )
  let object_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/ObjStm")),
      ),
      (acceptance_name_for_test("/N"), PdfInteger(1)),
      (acceptance_name_for_test("/First"), PdfInteger(first)),
      (
        acceptance_name_for_test("/Length"),
        PdfInteger(object_stream_data.length()),
      ),
    ]),
    StreamGot(Bytes::from_array(object_stream_data)),
  )
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 5)
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/Catalog")),
      ),
      (acceptance_name_for_test("/Payload"), PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(3, object_stream)
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied_permissions,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      acceptance_ascii_for_test("object-stream-reader"),
    ),
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("object-stream-reader-id"),
  )
  let encrypt_number = match
    encrypted
    .trailer_dict()
    .lookup_immediate(acceptance_name_for_test("/Encrypt")) {
    Some(PdfIndirect(number)) => number
    _ => fail("expected encrypted object reference")
  }
  @test.assert_eq(encrypt_number, 4)
  let trailer_id = match
    encrypted.trailer_dict().lookup_immediate(acceptance_name_for_test("/ID")) {
    Some(id) => id
    None => fail("expected encrypted trailer ID")
  }

  let output : Array[Byte] = []
  acceptance_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = output.length()
  acceptance_push_view_for_test(
    output,
    @pdflite.pdf_write_indirect_object({
      number: 1,
      generation: 0,
      object: encrypted.lookup_object_or_null(1),
    }),
  )
  acceptance_push_byte_for_test(output, 10)
  let object_stream_offset = output.length()
  acceptance_push_view_for_test(
    output,
    @pdflite.pdf_write_indirect_object({
      number: 3,
      generation: 0,
      object: encrypted.lookup_object_or_null(3),
    }),
  )
  acceptance_push_byte_for_test(output, 10)
  let encrypt_offset = output.length()
  acceptance_push_view_for_test(
    output,
    @pdflite.pdf_write_indirect_object({
      number: encrypt_number,
      generation: 0,
      object: encrypted.lookup_object_or_null(encrypt_number),
    }),
  )
  acceptance_push_byte_for_test(output, 10)

  let xref_stream_number = 5
  let xref_offset = output.length()
  let xref_data : Array[Byte] = []
  acceptance_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  acceptance_push_xref_stream_entry_for_test(xref_data, 1, catalog_offset, 0)
  acceptance_push_xref_stream_entry_for_test(xref_data, 2, 3, 0)
  acceptance_push_xref_stream_entry_for_test(
    xref_data, 1, object_stream_offset, 0,
  )
  acceptance_push_xref_stream_entry_for_test(xref_data, 1, encrypt_offset, 0)
  acceptance_push_xref_stream_entry_for_test(xref_data, 1, xref_offset, 0)
  let xref_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/XRef")),
      ),
      (acceptance_name_for_test("/Size"), PdfInteger(6)),
      (acceptance_name_for_test("/Root"), PdfIndirect(1)),
      (acceptance_name_for_test("/Encrypt"), PdfIndirect(encrypt_number)),
      (acceptance_name_for_test("/ID"), trailer_id),
      (
        acceptance_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(xref_data.length())),
    ]),
    StreamGot(Bytes::from_array(xref_data)),
  )
  acceptance_push_view_for_test(
    output,
    @pdflite.pdf_write_indirect_object({
      number: xref_stream_number,
      generation: 0,
      object: xref_stream,
    }),
  )
  acceptance_push_ascii_for_test(output, "\nstartxref\n")
  acceptance_push_ascii_for_test(output, xref_offset.to_string())
  acceptance_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn acceptance_encrypted_object_stream_pdf_for_test() -> @pdflite.PdfBytes raise {
  acceptance_encrypted_object_stream_pdf_with_passwords_for_test(
    acceptance_ascii_for_test("user"),
    acceptance_ascii_for_test("owner"),
    [PdfNoCopy],
  )
}

///|
fn acceptance_object_stream_pdf_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  acceptance_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = acceptance_push_indirect_object_for_test(
    output, 1, 0, "<< /Type /Catalog /Pages 2 0 R >>",
  )
  let pages_object = "<< /Type /Pages /Kids [5 0 R] /Count 1 >>"
  let page_object = "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] /Resources << >> >>"
  let second_offset = @ascii.encode(pages_object).length() + 1
  let object_stream_data : Array[Byte] = []
  acceptance_push_ascii_for_test(
    object_stream_data,
    "2 0 5 " + second_offset.to_string() + " ",
  )
  let first = object_stream_data.length()
  acceptance_push_ascii_for_test(object_stream_data, pages_object)
  acceptance_push_byte_for_test(object_stream_data, 32)
  acceptance_push_ascii_for_test(object_stream_data, page_object)
  let object_stream_offset = output.length()
  acceptance_push_ascii_for_test(output, "3 0 obj\n")
  acceptance_push_ascii_for_test(output, "<< /Type /ObjStm /N 2 /First ")
  acceptance_push_ascii_for_test(output, first.to_string())
  acceptance_push_ascii_for_test(output, " /Length ")
  acceptance_push_ascii_for_test(
    output,
    object_stream_data.length().to_string(),
  )
  acceptance_push_ascii_for_test(output, " >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  acceptance_push_xref_stream_entry_for_test(stream_data, 0, 0, 65535)
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, catalog_offset, 0)
  acceptance_push_xref_stream_entry_for_test(stream_data, 2, 3, 0)
  acceptance_push_xref_stream_entry_for_test(
    stream_data, 1, object_stream_offset, 0,
  )
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, xref_offset, 0)
  acceptance_push_xref_stream_entry_for_test(stream_data, 2, 3, 1)
  acceptance_push_ascii_for_test(output, "4 0 obj\n")
  acceptance_push_ascii_for_test(output, "<< /Type /XRef /Length ")
  acceptance_push_ascii_for_test(output, stream_data.length().to_string())
  acceptance_push_ascii_for_test(
    output, " /Size 6 /Root 1 0 R /W [1 4 2] >>\nstream\n",
  )
  for byte in stream_data {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\nstartxref\n")
  acceptance_push_ascii_for_test(output, xref_offset.to_string())
  acceptance_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn acceptance_indirect_filtered_object_stream_pages_for_test() -> String {
  "<< /Type /Pages /Kids [5 0 R] /Count 1 >>"
}

///|
fn acceptance_indirect_filtered_object_stream_page_for_test() -> String {
  "<< /Type /Page /Parent 4 0 R /MediaBox [0 0 10 10] /Resources << >> >>"
}

///|
fn acceptance_indirect_filtered_object_stream_payload_for_test() -> @pdflite.PdfBytes {
  let pages_object = acceptance_indirect_filtered_object_stream_pages_for_test()
  let page_object = acceptance_indirect_filtered_object_stream_page_for_test()
  let second_offset = @ascii.encode(pages_object).length() + 1
  let object_stream_data : Array[Byte] = []
  acceptance_push_ascii_for_test(
    object_stream_data,
    "4 0 5 " + second_offset.to_string() + " ",
  )
  acceptance_push_ascii_for_test(object_stream_data, pages_object)
  acceptance_push_byte_for_test(object_stream_data, 32)
  acceptance_push_ascii_for_test(object_stream_data, page_object)
  Bytes::from_array(object_stream_data)
}

///|
fn acceptance_indirect_filtered_object_stream_first_for_test() -> Int {
  let pages_object = acceptance_indirect_filtered_object_stream_pages_for_test()
  let second_offset = @ascii.encode(pages_object).length() + 1
  @ascii.encode("4 0 5 " + second_offset.to_string() + " ").length()
}

///|
fn acceptance_indirect_filtered_object_stream_pdf_for_test(
  startxref_override : Int?,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  acceptance_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = acceptance_push_indirect_object_for_test(
    output, 1, 0, "<< /Type /Catalog /Pages 4 0 R >>",
  )
  let count_offset = acceptance_push_indirect_object_for_test(output, 2, 0, "2")
  let object_stream_data = acceptance_indirect_filtered_object_stream_payload_for_test()
  let encoded_object_stream = @pdflite.pdf_ascii_hex_encode(object_stream_data)
  let object_stream_offset = output.length()
  acceptance_push_ascii_for_test(output, "3 0 obj\n")
  acceptance_push_ascii_for_test(
    output, "<< /Type /ObjStm /N 2 0 R /First 6 0 R /Filter 8 0 R /Length ",
  )
  acceptance_push_ascii_for_test(
    output,
    encoded_object_stream.length().to_string(),
  )
  acceptance_push_ascii_for_test(output, " >>\nstream\n")
  for byte in encoded_object_stream {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let first_offset = acceptance_push_indirect_object_for_test(
    output,
    6,
    0,
    acceptance_indirect_filtered_object_stream_first_for_test().to_string(),
  )
  let filter_offset = acceptance_push_indirect_object_for_test(
    output, 8, 0, "/ASCIIHexDecode",
  )
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  acceptance_push_xref_stream_entry_for_test(stream_data, 0, 0, 65535)
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, catalog_offset, 0)
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, count_offset, 0)
  acceptance_push_xref_stream_entry_for_test(
    stream_data, 1, object_stream_offset, 0,
  )
  acceptance_push_xref_stream_entry_for_test(stream_data, 2, 3, 0)
  acceptance_push_xref_stream_entry_for_test(stream_data, 2, 3, 1)
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, first_offset, 0)
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, xref_offset, 0)
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, filter_offset, 0)
  acceptance_push_ascii_for_test(output, "7 0 obj\n")
  acceptance_push_ascii_for_test(output, "<< /Type /XRef /Length ")
  acceptance_push_ascii_for_test(output, stream_data.length().to_string())
  acceptance_push_ascii_for_test(
    output, " /Size 9 /Root 1 0 R /W [1 4 2] >>\nstream\n",
  )
  for byte in stream_data {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\nstartxref\n")
  let startxref = match startxref_override {
    Some(value) => value
    None => xref_offset
  }
  acceptance_push_ascii_for_test(output, startxref.to_string())
  acceptance_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn acceptance_prev_object_stream_catalog_for_test() -> String {
  "<< /Type /Catalog /Pages 5 0 R >>"
}

///|
fn acceptance_prev_object_stream_pages_for_test() -> String {
  "<< /Type /Pages /Kids [6 0 R] /Count 1 >>"
}

///|
fn acceptance_prev_object_stream_page_for_test() -> String {
  "<< /Type /Page /Parent 5 0 R /MediaBox [0 0 10 10] /Resources << >> >>"
}

///|
fn acceptance_prev_object_stream_payload_for_test() -> @pdflite.PdfBytes {
  let catalog_object = acceptance_prev_object_stream_catalog_for_test()
  let pages_object = acceptance_prev_object_stream_pages_for_test()
  let page_object = acceptance_prev_object_stream_page_for_test()
  let pages_offset = @ascii.encode(catalog_object).length() + 1
  let page_offset = pages_offset + @ascii.encode(pages_object).length() + 1
  let object_stream_data : Array[Byte] = []
  acceptance_push_ascii_for_test(
    object_stream_data,
    "1 0 5 " + pages_offset.to_string() + " 6 " + page_offset.to_string() + " ",
  )
  acceptance_push_ascii_for_test(object_stream_data, catalog_object)
  acceptance_push_byte_for_test(object_stream_data, 32)
  acceptance_push_ascii_for_test(object_stream_data, pages_object)
  acceptance_push_byte_for_test(object_stream_data, 32)
  acceptance_push_ascii_for_test(object_stream_data, page_object)
  Bytes::from_array(object_stream_data)
}

///|
fn acceptance_prev_object_stream_first_for_test() -> Int {
  let catalog_object = acceptance_prev_object_stream_catalog_for_test()
  let pages_object = acceptance_prev_object_stream_pages_for_test()
  let pages_offset = @ascii.encode(catalog_object).length() + 1
  let page_offset = pages_offset + @ascii.encode(pages_object).length() + 1
  @ascii.encode(
    "1 0 5 " + pages_offset.to_string() + " 6 " + page_offset.to_string() + " ",
  ).length()
}

///|
fn acceptance_prev_object_stream_pdf_for_test(
  startxref_override : Int?,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  acceptance_push_ascii_for_test(output, "%PDF-1.5\n")
  let old_catalog_offset = acceptance_push_indirect_object_for_test(
    output, 1, 0, "<< /Type /Catalog /Old true >>",
  )
  let first_xref_offset = output.length()
  let first_xref_data : Array[Byte] = []
  acceptance_push_xref_stream_entry_for_test(first_xref_data, 0, 0, 65535)
  acceptance_push_xref_stream_entry_for_test(
    first_xref_data, 1, old_catalog_offset, 0,
  )
  acceptance_push_xref_stream_entry_for_test(
    first_xref_data, 1, first_xref_offset, 0,
  )
  acceptance_push_ascii_for_test(output, "2 0 obj\n")
  acceptance_push_ascii_for_test(output, "<< /Type /XRef /Length ")
  acceptance_push_ascii_for_test(output, first_xref_data.length().to_string())
  acceptance_push_ascii_for_test(
    output, " /Size 3 /Root 1 0 R /W [1 4 2] >>\nstream\n",
  )
  for byte in first_xref_data {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\nstartxref\n")
  acceptance_push_ascii_for_test(output, first_xref_offset.to_string())
  acceptance_push_ascii_for_test(output, "\n%%EOF\n")

  let object_stream_data = acceptance_prev_object_stream_payload_for_test()
  let object_stream_offset = output.length()
  acceptance_push_ascii_for_test(output, "3 0 obj\n")
  acceptance_push_ascii_for_test(output, "<< /Type /ObjStm /N 3 /First ")
  acceptance_push_ascii_for_test(
    output,
    acceptance_prev_object_stream_first_for_test().to_string(),
  )
  acceptance_push_ascii_for_test(output, " /Length ")
  acceptance_push_ascii_for_test(
    output,
    object_stream_data.length().to_string(),
  )
  acceptance_push_ascii_for_test(output, " >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let second_xref_offset = output.length()
  let second_xref_data : Array[Byte] = []
  acceptance_push_xref_stream_entry_for_test(second_xref_data, 0, 0, 65535)
  acceptance_push_xref_stream_entry_for_test(second_xref_data, 2, 3, 0)
  acceptance_push_xref_stream_entry_for_test(second_xref_data, 0, 0, 0)
  acceptance_push_xref_stream_entry_for_test(
    second_xref_data, 1, object_stream_offset, 0,
  )
  acceptance_push_xref_stream_entry_for_test(
    second_xref_data, 1, second_xref_offset, 0,
  )
  acceptance_push_xref_stream_entry_for_test(second_xref_data, 2, 3, 1)
  acceptance_push_xref_stream_entry_for_test(second_xref_data, 2, 3, 2)
  acceptance_push_ascii_for_test(output, "4 0 obj\n")
  acceptance_push_ascii_for_test(output, "<< /Type /XRef /Length ")
  acceptance_push_ascii_for_test(output, second_xref_data.length().to_string())
  acceptance_push_ascii_for_test(output, " /Size 7 /Root 1 0 R /Prev ")
  acceptance_push_ascii_for_test(output, first_xref_offset.to_string())
  acceptance_push_ascii_for_test(output, " /W [1 4 2] >>\nstream\n")
  for byte in second_xref_data {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\nstartxref\n")
  let startxref = match startxref_override {
    Some(value) => value
    None => second_xref_offset
  }
  acceptance_push_ascii_for_test(output, startxref.to_string())
  acceptance_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn acceptance_bad_first_object_stream_physical_page_tree_pdf_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  acceptance_push_ascii_for_test(output, "%PDF-1.5\n")
  let pages_offset = acceptance_push_indirect_object_for_test(
    output, 2, 0, "<< /Type /Pages /Kids [5 0 R] /Count 1 >>",
  )
  let page_offset = acceptance_push_indirect_object_for_test(
    output, 5, 0, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] /Resources << >> >>",
  )
  let object_stream_data : Array[Byte] = []
  acceptance_push_ascii_for_test(object_stream_data, "1 0 ")
  acceptance_push_ascii_for_test(
    object_stream_data, "<< /Type /Catalog /Pages 2 0 R >>",
  )
  let bad_first = object_stream_data.length() + 4
  let object_stream_offset = output.length()
  acceptance_push_ascii_for_test(output, "3 0 obj\n")
  acceptance_push_ascii_for_test(output, "<< /Type /ObjStm /N 1 /First ")
  acceptance_push_ascii_for_test(output, bad_first.to_string())
  acceptance_push_ascii_for_test(output, " /Length ")
  acceptance_push_ascii_for_test(
    output,
    object_stream_data.length().to_string(),
  )
  acceptance_push_ascii_for_test(output, " >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  acceptance_push_xref_stream_entry_for_test(stream_data, 0, 0, 65535)
  acceptance_push_xref_stream_entry_for_test(stream_data, 2, 3, 0)
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, pages_offset, 0)
  acceptance_push_xref_stream_entry_for_test(
    stream_data, 1, object_stream_offset, 0,
  )
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, xref_offset, 0)
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, page_offset, 0)
  acceptance_push_ascii_for_test(output, "4 0 obj\n")
  acceptance_push_ascii_for_test(output, "<< /Type /XRef /Length ")
  acceptance_push_ascii_for_test(output, stream_data.length().to_string())
  acceptance_push_ascii_for_test(
    output, " /Size 6 /Root 1 0 R /W [1 4 2] >>\nstream\n",
  )
  for byte in stream_data {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\n")
  ignore(
    acceptance_push_indirect_object_for_test(
      output, 1, 0, "<< /Type /Catalog /Pages 2 0 R >>",
    ),
  )
  acceptance_push_ascii_for_test(output, "startxref\n")
  acceptance_push_ascii_for_test(output, xref_offset.to_string())
  acceptance_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn acceptance_mismatched_object_stream_root_pdf_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  acceptance_push_ascii_for_test(output, "%PDF-1.5\n")
  let object_stream_data : Array[Byte] = []
  acceptance_push_ascii_for_test(object_stream_data, "2 0 ")
  let first = object_stream_data.length()
  acceptance_push_ascii_for_test(
    object_stream_data, "<< /Type /Catalog /Mismatched true >>",
  )
  let object_stream_offset = output.length()
  acceptance_push_ascii_for_test(output, "3 0 obj\n")
  acceptance_push_ascii_for_test(output, "<< /Type /ObjStm /N 1 /First ")
  acceptance_push_ascii_for_test(output, first.to_string())
  acceptance_push_ascii_for_test(output, " /Length ")
  acceptance_push_ascii_for_test(
    output,
    object_stream_data.length().to_string(),
  )
  acceptance_push_ascii_for_test(output, " >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  acceptance_push_xref_stream_entry_for_test(stream_data, 0, 0, 65535)
  acceptance_push_xref_stream_entry_for_test(stream_data, 2, 3, 0)
  acceptance_push_xref_stream_entry_for_test(stream_data, 0, 0, 0)
  acceptance_push_xref_stream_entry_for_test(
    stream_data, 1, object_stream_offset, 0,
  )
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, xref_offset, 0)
  acceptance_push_ascii_for_test(output, "4 0 obj\n")
  acceptance_push_ascii_for_test(output, "<< /Type /XRef /Length ")
  acceptance_push_ascii_for_test(output, stream_data.length().to_string())
  acceptance_push_ascii_for_test(
    output, " /Size 5 /Root 1 0 R /W [1 4 2] >>\nstream\n",
  )
  for byte in stream_data {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\n")
  ignore(
    acceptance_push_indirect_object_for_test(
      output, 1, 0, "<< /Type /Catalog /PhysicalFallback true >>",
    ),
  )
  acceptance_push_ascii_for_test(output, "startxref\n")
  acceptance_push_ascii_for_test(output, xref_offset.to_string())
  acceptance_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn acceptance_filtered_object_stream_root_pdf_for_test(
  filter_entries : String,
  flate_encoded : Bool,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  acceptance_push_ascii_for_test(output, "%PDF-1.5\n")
  let object_stream_data : Array[Byte] = []
  acceptance_push_ascii_for_test(object_stream_data, "1 0 ")
  let first = object_stream_data.length()
  acceptance_push_ascii_for_test(object_stream_data, "<< /Type /Catalog >>")
  let payload = if flate_encoded {
    @pdflite.pdf_flate_encode(Bytes::from_array(object_stream_data))
  } else {
    Bytes::from_array(object_stream_data)
  }
  let object_stream_offset = output.length()
  acceptance_push_ascii_for_test(output, "3 0 obj\n")
  acceptance_push_ascii_for_test(output, "<< /Type /ObjStm /N 1 /First ")
  acceptance_push_ascii_for_test(output, first.to_string())
  acceptance_push_ascii_for_test(output, " /Length ")
  acceptance_push_ascii_for_test(output, payload.length().to_string())
  acceptance_push_ascii_for_test(output, filter_entries)
  acceptance_push_ascii_for_test(output, " >>\nstream\n")
  for byte in payload {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  acceptance_push_xref_stream_entry_for_test(stream_data, 0, 0, 65535)
  acceptance_push_xref_stream_entry_for_test(stream_data, 2, 3, 0)
  acceptance_push_xref_stream_entry_for_test(stream_data, 0, 0, 65535)
  acceptance_push_xref_stream_entry_for_test(
    stream_data, 1, object_stream_offset, 0,
  )
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, xref_offset, 0)
  acceptance_push_ascii_for_test(output, "4 0 obj\n")
  acceptance_push_ascii_for_test(output, "<< /Type /XRef /Length ")
  acceptance_push_ascii_for_test(output, stream_data.length().to_string())
  acceptance_push_ascii_for_test(
    output, " /Size 5 /Root 1 0 R /W [1 4 2] >>\nstream\n",
  )
  for byte in stream_data {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\nstartxref\n")
  acceptance_push_ascii_for_test(output, xref_offset.to_string())
  acceptance_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn acceptance_bad_first_object_stream_entry_pdf_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  acceptance_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = acceptance_push_indirect_object_for_test(
    output, 1, 0, "<< /Type /Catalog /Payload 2 0 R >>",
  )
  let object_stream_data : Array[Byte] = []
  acceptance_push_ascii_for_test(object_stream_data, "2 0 ")
  let bad_first = object_stream_data.length() + 32
  acceptance_push_ascii_for_test(object_stream_data, "<< /Answer 42 >>")
  let object_stream_offset = output.length()
  acceptance_push_ascii_for_test(output, "3 0 obj\n")
  acceptance_push_ascii_for_test(output, "<< /Type /ObjStm /N 1 /First ")
  acceptance_push_ascii_for_test(output, bad_first.to_string())
  acceptance_push_ascii_for_test(output, " /Length ")
  acceptance_push_ascii_for_test(
    output,
    object_stream_data.length().to_string(),
  )
  acceptance_push_ascii_for_test(output, " >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  acceptance_push_xref_stream_entry_for_test(stream_data, 0, 0, 65535)
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, catalog_offset, 0)
  acceptance_push_xref_stream_entry_for_test(stream_data, 2, 3, 0)
  acceptance_push_xref_stream_entry_for_test(
    stream_data, 1, object_stream_offset, 0,
  )
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, xref_offset, 0)
  acceptance_push_ascii_for_test(output, "4 0 obj\n")
  acceptance_push_ascii_for_test(output, "<< /Type /XRef /Length ")
  acceptance_push_ascii_for_test(output, stream_data.length().to_string())
  acceptance_push_ascii_for_test(
    output, " /Size 5 /Root 1 0 R /W [1 4 2] >>\nstream\n",
  )
  for byte in stream_data {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\nstartxref\n")
  acceptance_push_ascii_for_test(output, xref_offset.to_string())
  acceptance_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn acceptance_startxref_object_pdf_for_test(body : String) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  acceptance_push_ascii_for_test(output, "%PDF-1.5\n")
  let offset = acceptance_push_indirect_object_for_test(output, 2, 0, body)
  acceptance_push_ascii_for_test(output, "startxref\n")
  acceptance_push_ascii_for_test(output, offset.to_string())
  acceptance_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn acceptance_xref_stream_pdf_with_type_for_test(
  type_entry : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  acceptance_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = acceptance_push_indirect_object_for_test(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  acceptance_push_xref_stream_entry_for_test(stream_data, 0, 0, 65535)
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, catalog_offset, 0)
  acceptance_push_xref_stream_entry_for_test(stream_data, 1, xref_offset, 0)
  acceptance_push_ascii_for_test(output, "2 0 obj\n")
  acceptance_push_ascii_for_test(output, "<< ")
  acceptance_push_ascii_for_test(output, type_entry)
  acceptance_push_ascii_for_test(output, " /Length ")
  acceptance_push_ascii_for_test(output, stream_data.length().to_string())
  acceptance_push_ascii_for_test(
    output, " /Size 3 /Root 1 0 R /W [1 4 2] >>\nstream\n",
  )
  for byte in stream_data {
    output.push(byte)
  }
  acceptance_push_ascii_for_test(output, "\nendstream\nendobj\nstartxref\n")
  acceptance_push_ascii_for_test(output, xref_offset.to_string())
  acceptance_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn acceptance_assert_object_stream_document_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.object_numbers(), [1, 2, 3, 5])
  @test.assert_eq(try! doc.endpage(), 1)
  @test.assert_eq(try! doc.page_reference_numbers(), [5])
  @test.assert_eq(
    doc.lookup_object_or_null(2),
    PdfDictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/Pages")),
      ),
      (acceptance_name_for_test("/Kids"), PdfArray([PdfIndirect(5)])),
      (acceptance_name_for_test("/Count"), PdfInteger(1)),
    ]),
  )
  guard doc.lookup_object_or_null(3) is PdfStreamObject(object_stream) else {
    fail("expected retained object stream")
  }
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(acceptance_name_for_test("/Type")),
    Some(PdfNameObject(acceptance_name_for_test("/ObjStm"))),
  )
}

///|
fn acceptance_assert_indirect_filtered_object_stream_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.object_numbers(), [1, 2, 3, 4, 5, 6, 8])
  @test.assert_eq(doc.lookup_object_or_null(2), PdfInteger(2))
  @test.assert_eq(
    doc.lookup_object_or_null(6),
    PdfInteger(acceptance_indirect_filtered_object_stream_first_for_test()),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(8),
    PdfNameObject(acceptance_name_for_test("/ASCIIHexDecode")),
  )
  @test.assert_eq(try! doc.endpage(), 1)
  @test.assert_eq(try! doc.page_reference_numbers(), [5])
  @test.assert_eq(
    doc.lookup_object_or_null(4),
    PdfDictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/Pages")),
      ),
      (acceptance_name_for_test("/Kids"), PdfArray([PdfIndirect(5)])),
      (acceptance_name_for_test("/Count"), PdfInteger(1)),
    ]),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(5),
    PdfDictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/Page")),
      ),
      (acceptance_name_for_test("/Parent"), PdfIndirect(4)),
      (
        acceptance_name_for_test("/MediaBox"),
        PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(10), PdfInteger(10)]),
      ),
      (acceptance_name_for_test("/Resources"), PdfDictionary([])),
    ]),
  )
  guard doc.lookup_object_or_null(3) is PdfStreamObject(object_stream) else {
    fail("expected retained indirect-filter object stream")
  }
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(acceptance_name_for_test("/Type")),
    Some(PdfNameObject(acceptance_name_for_test("/ObjStm"))),
  )
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(acceptance_name_for_test("/N")),
    Some(PdfIndirect(2)),
  )
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(
      acceptance_name_for_test("/First"),
    ),
    Some(PdfIndirect(6)),
  )
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(
      acceptance_name_for_test("/Filter"),
    ),
    Some(PdfIndirect(8)),
  )
  @test.assert_eq(
    @pdflite.pdf_stream(object_stream.dictionary, object_stream.data).stream_bytes(),
    @pdflite.pdf_ascii_hex_encode(
      acceptance_indirect_filtered_object_stream_payload_for_test(),
    ),
  )
  @test.assert_eq(
    @pdflite.pdf_ascii_hex_decode(
      @pdflite.pdf_stream(object_stream.dictionary, object_stream.data).stream_bytes(),
    ),
    acceptance_indirect_filtered_object_stream_payload_for_test(),
  )
}

///|
fn acceptance_assert_prev_object_stream_page_tree_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 5))
  @test.assert_eq(doc.root(), 1)
  @test.assert_eq(doc.object_numbers(), [1, 3, 5, 6])
  @test.assert_eq(
    doc.trailer_dict().lookup_immediate(acceptance_name_for_test("/Prev")),
    None,
  )
  @test.assert_eq(try! doc.endpage(), 1)
  @test.assert_eq(try! doc.page_reference_numbers(), [6])
  @test.assert_eq(
    doc.lookup_object_or_null(1),
    PdfDictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/Catalog")),
      ),
      (acceptance_name_for_test("/Pages"), PdfIndirect(5)),
    ]),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(5),
    PdfDictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/Pages")),
      ),
      (acceptance_name_for_test("/Kids"), PdfArray([PdfIndirect(6)])),
      (acceptance_name_for_test("/Count"), PdfInteger(1)),
    ]),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(6),
    PdfDictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/Page")),
      ),
      (acceptance_name_for_test("/Parent"), PdfIndirect(5)),
      (
        acceptance_name_for_test("/MediaBox"),
        PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(10), PdfInteger(10)]),
      ),
      (acceptance_name_for_test("/Resources"), PdfDictionary([])),
    ]),
  )
  guard doc.lookup_object_or_null(3) is PdfStreamObject(object_stream) else {
    fail("expected retained /Prev-chain object stream")
  }
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(acceptance_name_for_test("/Type")),
    Some(PdfNameObject(acceptance_name_for_test("/ObjStm"))),
  )
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(acceptance_name_for_test("/N")),
    Some(PdfInteger(3)),
  )
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(
      acceptance_name_for_test("/First"),
    ),
    Some(PdfInteger(acceptance_prev_object_stream_first_for_test())),
  )
  @test.assert_eq(
    @pdflite.pdf_stream(object_stream.dictionary, object_stream.data).stream_bytes(),
    acceptance_prev_object_stream_payload_for_test(),
  )
}

///|
fn acceptance_assert_pages_have_hello_content_for_test(
  doc : @pdflite.PdfDocument,
  expected_count : Int,
) -> Unit raise {
  @test.assert_eq(try! doc.endpage(), expected_count)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), expected_count)
  for page in pages {
    @test.assert_eq(
      doc.parse_content_ops(page.content),
      acceptance_one_page_ops_for_test(),
    )
  }
}

///|
fn acceptance_assert_text_pages_for_test(
  doc : @pdflite.PdfDocument,
  expected_texts : ArrayView[String],
) -> Unit raise {
  @test.assert_eq(doc.endpage(), expected_texts.length())
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), expected_texts.length())
  for index, text in expected_texts {
    @test.assert_eq(
      doc.parse_content_ops(pages[index].content),
      acceptance_text_page_ops_for_test(text),
    )
  }
}

///|
fn acceptance_document_contains_object_for_test(
  doc : @pdflite.PdfDocument,
  object : @pdflite.PdfObject,
) -> Bool {
  for number in doc.object_numbers() {
    if doc.lookup_object_or_null(number) == object {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn acceptance_assert_pdftest_rewrite_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  acceptance_assert_one_page_invariants_for_test(doc, (1, 5))
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages[0].content.length(), 1)
  @test.assert_eq(doc.lookup_object_or_null(77), PdfNull)
}

///|
fn acceptance_labelled_bookmarked_document_for_test(
  prefix : String,
  bookmark_text : String,
  style : @pdflite.PdfPageLabelStyle,
  start_value : Int,
) -> @pdflite.PdfDocument raise {
  let labelled = acceptance_one_page_document_for_test().write_page_labels([
    {
      label_style: style,
      label_prefix: Some(acceptance_ascii_for_test(prefix)),
      start_page: 1,
      start_value,
    },
  ])
  let page_refs = labelled.page_reference_numbers()
  labelled.add_bookmarks([
    {
      level: 0,
      text: acceptance_ascii_for_test(bookmark_text),
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: true,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
fn acceptance_assert_bookmarks_target_pages_for_test(
  doc : @pdflite.PdfDocument,
  first_text : String,
  second_text : String,
) -> Unit raise {
  let bookmarks = doc.read_bookmarks()
  @test.assert_eq(bookmarks.length(), 2)
  @test.assert_eq([ for bookmark in bookmarks => bookmark.text ], [
    acceptance_ascii_for_test(first_text),
    acceptance_ascii_for_test(second_text),
  ])
  @test.assert_eq(doc.page_number_of_target(bookmarks[0].target), 1)
  @test.assert_eq(doc.page_number_of_target(bookmarks[1].target), 2)
}

///|
fn acceptance_add_catalog_entry_for_test(
  doc : @pdflite.PdfDocument,
  key : @pdflite.PdfName,
  value : @pdflite.PdfObject,
) -> Unit raise {
  let root = doc.root()
  doc.add_object_given_number(
    root,
    doc.lookup_object_or_null(root).add_dict_entry(key, value),
  )
}

///|
fn acceptance_document_feature_lifecycle_document_for_test() -> @pdflite.PdfDocument raise {
  let key_annots = acceptance_name_for_test("/Annots")
  let key_subtype = acceptance_name_for_test("/Subtype")
  let key_rect = acceptance_name_for_test("/Rect")
  let key_dest = acceptance_name_for_test("/Dest")
  let key_open_action = acceptance_name_for_test("/OpenAction")
  let key_dests = acceptance_name_for_test("/Dests")
  let key_names = acceptance_name_for_test("/Names")
  let type_link = acceptance_name_for_test("/Link")
  let type_xyz = acceptance_name_for_test("/XYZ")
  let type_fith = acceptance_name_for_test("/FitH")
  let type_fitv = acceptance_name_for_test("/FitV")
  let named_destination = acceptance_name_for_test("/Chapter")
  let string_destination = acceptance_ascii_for_test("chapter-string")
  let doc = acceptance_one_page_document_for_test().write_page_labels([
    {
      label_style: PageLabelLowercaseLetters,
      label_prefix: Some(acceptance_ascii_for_test("gate-")),
      start_page: 1,
      start_value: 2,
    },
  ])
  let page_numbers = doc.page_reference_numbers()
  doc.add_object_given_number(
    page_numbers[0],
    doc
    .lookup_object_or_null(page_numbers[0])
    .add_dict_entry(
      key_annots,
      PdfArray([
        @pdflite.pdf_dictionary([
          (key_subtype, PdfNameObject(type_link)),
          (
            key_rect,
            PdfArray([
              PdfInteger(1),
              PdfInteger(2),
              PdfInteger(3),
              PdfInteger(4),
            ]),
          ),
          (
            key_dest,
            PdfArray([
              PdfIndirect(page_numbers[0]),
              PdfNameObject(type_xyz),
              PdfInteger(10),
              PdfInteger(20),
              PdfNull,
            ]),
          ),
        ]),
      ]),
    ),
  )
  acceptance_add_catalog_entry_for_test(
    doc,
    key_open_action,
    PdfArray([
      PdfIndirect(page_numbers[0]),
      PdfNameObject(type_fith),
      PdfInteger(50),
    ]),
  )
  acceptance_add_catalog_entry_for_test(
    doc,
    key_dests,
    PdfDictionary([
      (
        named_destination,
        PdfArray([
          PdfIndirect(page_numbers[0]),
          PdfNameObject(type_fitv),
          PdfInteger(40),
        ]),
      ),
    ]),
  )
  acceptance_add_catalog_entry_for_test(
    doc,
    key_names,
    PdfDictionary([
      (
        key_dests,
        doc.build_name_tree([
          (
            string_destination,
            PdfArray([
              PdfIndirect(page_numbers[0]),
              PdfNameObject(type_xyz),
              PdfInteger(5),
              PdfInteger(6),
              PdfNull,
            ]),
          ),
        ]),
      ),
    ]),
  )
  doc
}

///|
fn acceptance_assert_document_feature_lifecycle_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  let key_annots = acceptance_name_for_test("/Annots")
  let key_dest = acceptance_name_for_test("/Dest")
  let key_open_action = acceptance_name_for_test("/OpenAction")
  let page_numbers = doc.page_reference_numbers()
  @test.assert_eq(doc.read_page_labels(), [
    {
      label_style: PageLabelLowercaseLetters,
      label_prefix: Some(acceptance_ascii_for_test("gate-")),
      start_page: 1,
      start_value: 2,
    },
  ])
  let pages = doc.pages_of_pagetree()
  match pages[0].rest.lookup_immediate(key_annots) {
    Some(PdfArray([PdfDictionary(_) as annotation])) =>
      match annotation.lookup_immediate(key_dest) {
        Some(destination) =>
          @test.assert_eq(
            doc.read_destination(destination),
            DestXYZ(
              TargetPageObject(page_numbers[0]),
              Some(15.0),
              Some(14.0),
              None,
            ),
          )
        _ => fail("expected transformed link annotation destination")
      }
    _ => fail("expected link annotation")
  }
  match doc.catalog().lookup_immediate(key_open_action) {
    Some(action) =>
      @test.assert_eq(
        doc.read_destination(action),
        DestFitH(TargetPageObject(page_numbers[0]), Some(44.0)),
      )
    _ => fail("expected transformed OpenAction")
  }
  @test.assert_eq(
    doc.read_destination(PdfNameObject(acceptance_name_for_test("/Chapter"))),
    DestFitV(TargetPageObject(page_numbers[0]), Some(45.0)),
  )
  @test.assert_eq(
    doc.read_destination(PdfString(acceptance_ascii_for_test("chapter-string"))),
    DestXYZ(TargetPageObject(page_numbers[0]), Some(10.0), Some(0.0), None),
  )
}

///|
fn acceptance_count_change_document_for_test() -> @pdflite.PdfDocument raise {
  let key_id = acceptance_name_for_test("/ID")
  let key_lang = acceptance_name_for_test("/Lang")
  let key_open_action = acceptance_name_for_test("/OpenAction")
  let type_xyz = acceptance_name_for_test("/XYZ")
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 6)
  let page_root = doc.add_pagetree([
    acceptance_text_page_for_test("first-page"),
    acceptance_text_page_for_test("second-page"),
  ])
  ignore(
    doc.add_root(page_root, [
      (key_lang, PdfString(acceptance_ascii_for_test("en-US"))),
    ]),
  )
  let old_numbers = doc.page_reference_numbers()
  acceptance_add_catalog_entry_for_test(
    doc,
    key_open_action,
    PdfArray([
      PdfIndirect(old_numbers[1]),
      PdfNameObject(type_xyz),
      PdfInteger(1),
      PdfInteger(2),
      PdfNull,
    ]),
  )
  doc.set_trailer_dict(
    doc
    .trailer_dict()
    .add_dict_entry(
      key_id,
      PdfArray([
        PdfString(acceptance_ascii_for_test("first-id")),
        PdfString(acceptance_ascii_for_test("second-id")),
      ]),
    ),
  )
  doc.add_bookmarks([
    {
      level: 0,
      text: acceptance_ascii_for_test("Second"),
      target: DestXYZ(
        TargetPageObject(old_numbers[1]),
        Some(5.0),
        Some(6.0),
        None,
      ),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
fn acceptance_count_change_replacement_page_for_test() -> @pdflite.PdfPage raise {
  acceptance_text_page_for_test("replacement-page")
}

///|
fn acceptance_reused_annotation_document_for_test() -> @pdflite.PdfDocument raise {
  let key_annots = acceptance_name_for_test("/Annots")
  let key_subtype = acceptance_name_for_test("/Subtype")
  let key_popup = acceptance_name_for_test("/Popup")
  let key_parent = acceptance_name_for_test("/Parent")
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 6)
  doc.add_object_given_number(
    10,
    @pdflite.pdf_dictionary([
      (key_subtype, PdfNameObject(acceptance_name_for_test("/Text"))),
      (key_popup, PdfIndirect(11)),
    ]),
  )
  doc.add_object_given_number(
    11,
    @pdflite.pdf_dictionary([
      (key_subtype, PdfNameObject(acceptance_name_for_test("/Popup"))),
      (key_parent, PdfIndirect(10)),
    ]),
  )
  let page = {
    ..acceptance_text_page_for_test("annotated-page"),
    rest: @pdflite.pdf_dictionary([
      (key_annots, PdfArray([PdfIndirect(10), PdfIndirect(11)])),
    ]),
  }
  let page_root = doc.add_pagetree([page, page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_annotation_numbers_for_test(
  page : @pdflite.PdfPage,
) -> Array[Int] raise {
  match page.rest.lookup_immediate(acceptance_name_for_test("/Annots")) {
    Some(PdfArray(items)) => {
      let numbers : Array[Int] = []
      for item in items {
        match item {
          PdfIndirect(number) => numbers.push(number)
          _ => fail("expected indirect annotation")
        }
      }
      numbers
    }
    _ => fail("expected page annotations")
  }
}

///|
fn acceptance_assert_annotation_pair_for_test(
  doc : @pdflite.PdfDocument,
  numbers : ArrayView[Int],
) -> Unit raise {
  let key_popup = acceptance_name_for_test("/Popup")
  let key_parent = acceptance_name_for_test("/Parent")
  @test.assert_eq(numbers.length(), 2)
  @test.assert_eq(
    doc.lookup_object_or_null(numbers[0]).lookup_immediate(key_popup),
    Some(PdfIndirect(numbers[1])),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(numbers[1]).lookup_immediate(key_parent),
    Some(PdfIndirect(numbers[0])),
  )
}

///|
fn acceptance_assert_extracted_reused_annotations_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 6))
  @test.assert_eq(doc.endpage(), 2)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 2)
  for page in pages {
    @test.assert_eq(
      doc.parse_content_ops(page.content),
      acceptance_text_page_ops_for_test("annotated-page"),
    )
  }
  let first_annots = acceptance_annotation_numbers_for_test(pages[0])
  let second_annots = acceptance_annotation_numbers_for_test(pages[1])
  acceptance_assert_annotation_pair_for_test(doc, first_annots)
  acceptance_assert_annotation_pair_for_test(doc, second_annots)
  @test.assert_eq(first_annots[0] == second_annots[0], false)
  @test.assert_eq(first_annots[1] == second_annots[1], false)
}

///|
fn acceptance_assert_count_changed_document_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  let key_id = acceptance_name_for_test("/ID")
  let key_lang = acceptance_name_for_test("/Lang")
  let key_open_action = acceptance_name_for_test("/OpenAction")
  @test.assert_eq(doc.version(), (1, 6))
  @test.assert_eq(doc.endpage(), 1)
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    doc.parse_content_ops(pages[0].content),
    acceptance_text_page_ops_for_test("replacement-page"),
  )
  @test.assert_eq(
    doc.trailer_dict().lookup_immediate(key_id),
    Some(
      PdfArray([
        PdfString(acceptance_ascii_for_test("first-id")),
        PdfString(acceptance_ascii_for_test("second-id")),
      ]),
    ),
  )
  @test.assert_eq(
    doc.catalog().lookup_immediate(key_lang),
    Some(PdfString(acceptance_ascii_for_test("en-US"))),
  )
  let new_numbers = doc.page_reference_numbers()
  @test.assert_eq(doc.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: acceptance_ascii_for_test("Second"),
      target: DestXYZ(
        TargetPageObject(new_numbers[0]),
        Some(5.0),
        Some(6.0),
        None,
      ),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
  guard doc.catalog().lookup_immediate(key_open_action) is Some(open_action) else {
    fail("expected OpenAction")
  }
  @test.assert_eq(
    doc.read_destination(open_action),
    DestXYZ(TargetPageObject(new_numbers[0]), Some(11.0), Some(22.0), None),
  )
}

///|
fn acceptance_catalog_merge_document_for_test(
  label : String,
  title : String,
  ocg_number : Int,
  need_appearances : Bool,
) -> @pdflite.PdfDocument raise {
  let key_acroform = acceptance_name_for_test("/AcroForm")
  let key_fields = acceptance_name_for_test("/Fields")
  let key_t = acceptance_name_for_test("/T")
  let key_need_appearances = acceptance_name_for_test("/NeedAppearances")
  let key_info = acceptance_name_for_test("/Info")
  let key_title = acceptance_name_for_test("/Title")
  let key_struct_tree_root = acceptance_name_for_test("/StructTreeRoot")
  let key_parent_tree = acceptance_name_for_test("/ParentTree")
  let key_struct_parents = acceptance_name_for_test("/StructParents")
  let key_k = acceptance_name_for_test("/K")
  let key_pg = acceptance_name_for_test("/Pg")
  let doc = acceptance_one_page_document_for_test()
  doc.set_version(1, 6)
  let page_numbers = doc.page_reference_numbers()
  doc.add_object_given_number(
    70,
    PdfDictionary([(key_t, PdfString(acceptance_ascii_for_test(label)))]),
  )
  acceptance_add_catalog_entry_for_test(
    doc,
    key_acroform,
    PdfDictionary([
      (key_fields, PdfArray([PdfIndirect(70)])),
      (key_need_appearances, PdfBoolean(need_appearances)),
    ]),
  )
  doc.add_object_given_number(
    page_numbers[0],
    doc
    .lookup_object_or_null(page_numbers[0])
    .add_dict_entry(key_struct_parents, PdfInteger(0)),
  )
  doc.add_object_given_number(
    80,
    PdfDictionary([
      (key_k, PdfIndirect(81)),
      (key_parent_tree, doc.build_number_tree([(0, PdfIndirect(81))])),
    ]),
  )
  doc.add_object_given_number(
    81,
    PdfDictionary([
      (key_pg, PdfIndirect(page_numbers[0])),
      (key_k, PdfInteger(0)),
    ]),
  )
  acceptance_add_catalog_entry_for_test(
    doc,
    key_struct_tree_root,
    PdfIndirect(80),
  )
  let info_number = doc.add_object(
    PdfDictionary([(key_title, PdfString(acceptance_ascii_for_test(title)))]),
  )
  doc.set_trailer_dict(
    doc.trailer_dict().add_dict_entry(key_info, PdfIndirect(info_number)),
  )
  doc.write_optional_content_groups({
    ocgs: [
      (
        ocg_number,
        {
          name: acceptance_ascii_for_test(label),
          intent: [acceptance_name_for_test("/View")],
          usage: None,
        },
      ),
    ],
    default_config: {
      ..@pdflite.pdf_ocg_default_config(),
      on: [ocg_number],
      order: Some([(Some(acceptance_ascii_for_test(label)), [ocg_number])]),
    },
    configs: [],
  })
}

///|
fn acceptance_compressed_roundtrip_for_test(
  doc : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  @pdflite.pdf_read_document_from_bytes(
    @pdflite.pdf_write_document_with_compressed_xref_stream(doc),
  )
}

///|
fn acceptance_raw_stream_for_test(text : String) -> @pdflite.PdfObject {
  let bytes = acceptance_ascii_for_test(text)
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/Length"), PdfInteger(bytes.length())),
    ]),
    StreamGot(bytes),
  )
}

///|
fn acceptance_pdfmergeexample_document_for_test(
  text : String,
  minor_version : Int,
  detached_number : Int,
) -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, minor_version)
  let page_root = doc.add_pagetree([acceptance_text_page_for_test(text)])
  ignore(doc.add_root(page_root, []))
  doc.add_object_given_number(
    detached_number,
    PdfString(acceptance_ascii_for_test("detached-" + text)),
  )
  doc
}

///|
fn acceptance_pdfmergeexample_workflow_for_test(
  documents : ArrayView[@pdflite.PdfDocument],
) -> @pdflite.PdfDocument raise {
  let renumbered = @pdflite.pdf_renumber_documents(documents)
  let merged = @pdflite.pdf_document_empty()
  let pages : Array[@pdflite.PdfPage] = []
  let mut max_minor = 0
  for document in renumbered {
    let (_, minor) = document.version()
    if minor > max_minor {
      max_minor = minor
    }
    for number in document.object_numbers() {
      merged.add_object_given_number(
        number,
        document.lookup_object_or_null(number),
      )
    }
    for page in document.pages_of_pagetree() {
      pages.push(page)
    }
  }
  let page_root = merged.add_pagetree(pages)
  ignore(merged.add_root(page_root, []))
  merged.set_version(1, max_minor)
  merged.remove_unreferenced()
  merged
}

///|
fn acceptance_structure_extraction_document_for_test() -> @pdflite.PdfDocument raise {
  let key_struct_tree_root = acceptance_name_for_test("/StructTreeRoot")
  let key_parent_tree = acceptance_name_for_test("/ParentTree")
  let key_struct_parents = acceptance_name_for_test("/StructParents")
  let key_k = acceptance_name_for_test("/K")
  let key_pg = acceptance_name_for_test("/Pg")
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 6)
  let page_root = doc.add_pagetree([
    acceptance_text_page_for_test("structured-keep"),
    acceptance_text_page_for_test("structured-drop"),
  ])
  ignore(doc.add_root(page_root, []))
  let page_numbers = doc.page_reference_numbers()
  for index, page_number in page_numbers {
    doc.add_object_given_number(
      page_number,
      doc
      .lookup_object_or_null(page_number)
      .add_dict_entry(key_struct_parents, PdfInteger(index)),
    )
  }
  doc.add_object_given_number(
    90,
    PdfDictionary([
      (key_k, PdfArray([PdfIndirect(91), PdfIndirect(92)])),
      (
        key_parent_tree,
        doc.build_number_tree([(0, PdfIndirect(91)), (1, PdfIndirect(92))]),
      ),
    ]),
  )
  doc.add_object_given_number(
    91,
    PdfDictionary([
      (key_pg, PdfIndirect(page_numbers[0])),
      (key_k, PdfInteger(0)),
    ]),
  )
  doc.add_object_given_number(
    92,
    PdfDictionary([
      (key_pg, PdfIndirect(page_numbers[1])),
      (key_k, PdfInteger(0)),
    ]),
  )
  acceptance_add_catalog_entry_for_test(
    doc,
    key_struct_tree_root,
    PdfIndirect(90),
  )
  doc
}

///|
fn acceptance_assert_structure_extraction_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  let key_struct_tree_root = acceptance_name_for_test("/StructTreeRoot")
  let key_k = acceptance_name_for_test("/K")
  let key_pg = acceptance_name_for_test("/Pg")
  @test.assert_eq(doc.version(), (1, 6))
  acceptance_assert_text_pages_for_test(doc, ["structured-keep"])
  let page_numbers = doc.page_reference_numbers()
  guard doc.catalog().lookup_immediate(key_struct_tree_root)
    is Some(PdfIndirect(struct_root_number)) else {
    fail("expected extracted StructTreeRoot")
  }
  let struct_root = doc.lookup_object_or_null(struct_root_number)
  @test.assert_eq(struct_root.lookup_immediate(key_k), Some(PdfIndirect(91)))
  @test.assert_eq(
    doc.lookup_object_or_null(91).lookup_immediate(key_pg),
    Some(PdfIndirect(page_numbers[0])),
  )
  @test.assert_eq(doc.lookup_object_or_null(92), PdfNull)
}

///|
fn acceptance_resource_lifecycle_font_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Type"),
      PdfNameObject(acceptance_name_for_test("/Font")),
    ),
    (
      acceptance_name_for_test("/Subtype"),
      PdfNameObject(acceptance_name_for_test("/Type1")),
    ),
    (
      acceptance_name_for_test("/BaseFont"),
      PdfNameObject(acceptance_name_for_test("/Times-Italic")),
    ),
  ])
}

///|
fn acceptance_resource_lifecycle_resources_for_test(
  font_name : @pdflite.PdfName,
  form_name : @pdflite.PdfName,
  form_number : Int,
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/Font"),
      @pdflite.pdf_dictionary([
        (font_name, acceptance_resource_lifecycle_font_for_test()),
      ]),
    ),
    (
      acceptance_name_for_test("/XObject"),
      @pdflite.pdf_dictionary([(form_name, PdfIndirect(form_number))]),
    ),
  ])
}

///|
fn acceptance_resource_lifecycle_form_for_test() -> @pdflite.PdfObject {
  let bytes = acceptance_ascii_for_test("FORM-OLD")
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Form")),
      ),
      (
        acceptance_name_for_test("/Filter"),
        PdfNameObject(acceptance_name_for_test("/FlateDecode")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(bytes.length())),
      (acceptance_name_for_test("/Keep"), PdfInteger(1)),
    ]),
    StreamGot(bytes),
  )
}

///|
fn acceptance_resource_lifecycle_document_for_test() -> @pdflite.PdfDocument raise {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 6)
  doc.add_object_given_number(70, acceptance_resource_lifecycle_form_for_test())
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: acceptance_resource_lifecycle_resources_for_test(
      acceptance_name_for_test("/F0"),
      acceptance_name_for_test("/Fm1"),
      70,
    ),
    content: [
      acceptance_raw_stream_for_test("BT /F0"),
      acceptance_raw_stream_for_test("12 Tf (Lifecycle) Tj ET /Fm1 Do"),
    ],
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_page_resource_for_test(
  doc : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
  resource_key : @pdflite.PdfName,
  name : @pdflite.PdfName,
) -> @pdflite.PdfObject raise {
  guard doc.lookup_direct(resource_key, page.resources) is Some(resources) else {
    fail("expected resource dictionary")
  }
  guard doc.lookup_direct(name, resources) is Some(value) else {
    fail("expected named resource")
  }
  value
}

///|
fn acceptance_assert_resource_form_for_test(
  doc : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
  name : @pdflite.PdfName,
) -> Unit raise {
  let value = acceptance_page_resource_for_test(
    doc,
    page,
    acceptance_name_for_test("/XObject"),
    name,
  )
  guard doc.direct(value) is PdfStreamObject(stream) else {
    fail("expected form stream")
  }
  @test.assert_eq(
    @pdflite.pdf_stream(stream.dictionary, stream.data).stream_bytes(),
    acceptance_ascii_for_test("FORM-LIFECYCLE"),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(acceptance_name_for_test("/Filter")),
    None,
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(acceptance_name_for_test("/Keep")),
    Some(PdfInteger(1)),
  )
  @test.assert_eq(
    stream.dictionary.lookup_immediate(acceptance_name_for_test("/Processed")),
    Some(PdfBoolean(true)),
  )
}

///|
fn acceptance_resource_lifecycle_ops_for_test(
  font_name : @pdflite.PdfName,
  form_name : @pdflite.PdfName,
) -> Array[@pdflite.PdfContentOp] {
  [
    Op_BT,
    Op_Tf(font_name, 12.0),
    Op_Tj(acceptance_ascii_for_test("Lifecycle")),
    Op_ET,
    Op_Do(form_name),
  ]
}

///|
fn acceptance_process_resource_lifecycle_forms_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  for page in doc.pages_of_pagetree() {
    doc.process_xobjects(page, fn(_, _, streams) raise @pdflite.PdfError {
      if streams.length() != 1 {
        raise @pdflite.PdfError::ParseStreamExpected
      }
      let bytes = acceptance_ascii_for_test("FORM-LIFECYCLE")
      [
        @pdflite.pdf_stream(
          @pdflite.pdf_dictionary([
            (
              acceptance_name_for_test("/Filter"),
              PdfNameObject(acceptance_name_for_test("/ASCIIHexDecode")),
            ),
            (acceptance_name_for_test("/Length"), PdfInteger(bytes.length())),
            (acceptance_name_for_test("/Processed"), PdfBoolean(true)),
          ]),
          StreamGot(bytes),
        ),
      ]
    })
  }
}

///|
fn acceptance_assert_resource_lifecycle_prefixed_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 6))
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(pages[0].content.length(), 1)
  @test.assert_eq(
    doc.parse_content_ops(pages[0].content),
    acceptance_resource_lifecycle_ops_for_test(
      acceptance_name_for_test("/pF0"),
      acceptance_name_for_test("/pFm1"),
    ),
  )
  ignore(
    acceptance_page_resource_for_test(
      doc,
      pages[0],
      acceptance_name_for_test("/Font"),
      acceptance_name_for_test("/pF0"),
    ),
  )
  acceptance_assert_resource_form_for_test(
    doc,
    pages[0],
    acceptance_name_for_test("/pFm1"),
  )
}

///|
fn acceptance_assert_resource_lifecycle_renumbered_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.version(), (1, 6))
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 2)
  @test.assert_eq(
    doc.parse_content_ops(pages[0].content),
    acceptance_resource_lifecycle_ops_for_test(
      acceptance_name_for_test("/r1"),
      acceptance_name_for_test("/r3"),
    ),
  )
  @test.assert_eq(
    doc.parse_content_ops(pages[1].content),
    acceptance_resource_lifecycle_ops_for_test(
      acceptance_name_for_test("/r2"),
      acceptance_name_for_test("/r4"),
    ),
  )
  ignore(
    acceptance_page_resource_for_test(
      doc,
      pages[0],
      acceptance_name_for_test("/Font"),
      acceptance_name_for_test("/r1"),
    ),
  )
  ignore(
    acceptance_page_resource_for_test(
      doc,
      pages[1],
      acceptance_name_for_test("/Font"),
      acceptance_name_for_test("/r2"),
    ),
  )
  acceptance_assert_resource_form_for_test(
    doc,
    pages[0],
    acceptance_name_for_test("/r3"),
  )
  acceptance_assert_resource_form_for_test(
    doc,
    pages[1],
    acceptance_name_for_test("/r4"),
  )
}

///|
fn acceptance_change_pages_form_for_test() -> @pdflite.PdfObject {
  let bytes = acceptance_ascii_for_test("q Q")
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Subtype"),
        PdfNameObject(acceptance_name_for_test("/Form")),
      ),
      (acceptance_name_for_test("/Length"), PdfInteger(bytes.length())),
    ]),
    StreamGot(bytes),
  )
}

///|
fn acceptance_change_pages_resource_ops_for_test(
  text : String,
) -> Array[@pdflite.PdfContentOp] {
  [
    Op_BT,
    Op_Tf(acceptance_name_for_test("/F0"), 12.0),
    Op_Tj(acceptance_ascii_for_test(text)),
    Op_ET,
    Op_Do(acceptance_name_for_test("/Fm1")),
  ]
}

///|
fn acceptance_change_pages_resource_page_for_test(
  text : String,
) -> @pdflite.PdfPage raise {
  {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: acceptance_resource_lifecycle_resources_for_test(
      acceptance_name_for_test("/F0"),
      acceptance_name_for_test("/Fm1"),
      70,
    ),
    content: [
      @pdflite.pdf_content_stream_of_ops(
        acceptance_change_pages_resource_ops_for_test(text),
      ),
    ],
  }
}

///|
fn acceptance_change_pages_xyz_for_test(
  page_number : Int,
  left : Int,
  top : Int,
) -> @pdflite.PdfObject {
  PdfArray([
    PdfIndirect(page_number),
    PdfNameObject(acceptance_name_for_test("/XYZ")),
    PdfInteger(left),
    PdfInteger(top),
    PdfNull,
  ])
}

///|
fn acceptance_change_pages_goto_for_test(
  destination : @pdflite.PdfObject,
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/S"),
      PdfNameObject(acceptance_name_for_test("/GoTo")),
    ),
    (acceptance_name_for_test("/D"), destination),
  ])
}

///|
fn acceptance_resource_heavy_change_pages_document_for_test() -> @pdflite.PdfDocument raise {
  let key_annots = acceptance_name_for_test("/Annots")
  let key_subtype = acceptance_name_for_test("/Subtype")
  let key_rect = acceptance_name_for_test("/Rect")
  let key_dest = acceptance_name_for_test("/Dest")
  let key_action = acceptance_name_for_test("/A")
  let key_open_action = acceptance_name_for_test("/OpenAction")
  let key_dests = acceptance_name_for_test("/Dests")
  let key_names = acceptance_name_for_test("/Names")
  let type_link = acceptance_name_for_test("/Link")
  let named_destination = acceptance_name_for_test("/Chapter")
  let string_destination = acceptance_ascii_for_test("chapter-action")
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 6)
  doc.add_object_given_number(70, acceptance_change_pages_form_for_test())
  let page_root = doc.add_pagetree([
    acceptance_change_pages_resource_page_for_test("Before"),
  ])
  ignore(doc.add_root(page_root, []))
  let page_numbers = doc.page_reference_numbers()
  let page_number = page_numbers[0]
  let indirect_annotation = @pdflite.pdf_dictionary([
    (key_subtype, PdfNameObject(type_link)),
    (
      key_rect,
      PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(10), PdfInteger(10)]),
    ),
    (key_dest, acceptance_change_pages_xyz_for_test(page_number, 1, 2)),
  ])
  let direct_action_annotation = @pdflite.pdf_dictionary([
    (key_subtype, PdfNameObject(type_link)),
    (
      key_rect,
      PdfArray([PdfInteger(10), PdfInteger(10), PdfInteger(20), PdfInteger(20)]),
    ),
    (
      key_action,
      acceptance_change_pages_goto_for_test(
        acceptance_change_pages_xyz_for_test(page_number, 3, 4),
      ),
    ),
  ])
  doc.add_object_given_number(80, indirect_annotation)
  doc.add_object_given_number(
    page_number,
    doc
    .lookup_object_or_null(page_number)
    .add_dict_entry(
      key_annots,
      PdfArray([PdfIndirect(80), direct_action_annotation]),
    ),
  )
  acceptance_add_catalog_entry_for_test(
    doc,
    key_open_action,
    acceptance_change_pages_goto_for_test(
      acceptance_change_pages_xyz_for_test(page_number, 5, 6),
    ),
  )
  acceptance_add_catalog_entry_for_test(
    doc,
    key_dests,
    PdfDictionary([
      (
        named_destination,
        PdfArray([
          PdfIndirect(page_number),
          PdfNameObject(acceptance_name_for_test("/FitH")),
          PdfInteger(7),
        ]),
      ),
    ]),
  )
  acceptance_add_catalog_entry_for_test(
    doc,
    key_names,
    PdfDictionary([
      (
        key_dests,
        doc.build_name_tree([
          (
            string_destination,
            acceptance_change_pages_goto_for_test(
              acceptance_change_pages_xyz_for_test(page_number, 8, 9),
            ),
          ),
        ]),
      ),
    ]),
  )
  doc.add_bookmarks([
    {
      level: 0,
      text: acceptance_ascii_for_test("Chapter"),
      target: DestString(string_destination),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
fn acceptance_assert_resource_heavy_change_pages_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  let key_annots = acceptance_name_for_test("/Annots")
  let key_dest = acceptance_name_for_test("/Dest")
  let key_action = acceptance_name_for_test("/A")
  let key_open_action = acceptance_name_for_test("/OpenAction")
  let page_numbers = doc.page_reference_numbers()
  @test.assert_eq(doc.version(), (1, 6))
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    doc.parse_content_ops(pages[0].content),
    acceptance_change_pages_resource_ops_for_test("After"),
  )
  ignore(
    acceptance_page_resource_for_test(
      doc,
      pages[0],
      acceptance_name_for_test("/Font"),
      acceptance_name_for_test("/F0"),
    ),
  )
  let form = acceptance_page_resource_for_test(
    doc,
    pages[0],
    acceptance_name_for_test("/XObject"),
    acceptance_name_for_test("/Fm1"),
  )
  guard doc.direct(form) is PdfStreamObject(_) else {
    fail("expected retained form XObject")
  }
  match pages[0].rest.lookup_immediate(key_annots) {
    Some(
      PdfArray(
        [
          PdfIndirect(indirect_annotation),
          PdfDictionary(_) as action_annotation,
        ]
      )
    ) => {
      match
        doc
        .lookup_object_or_null(indirect_annotation)
        .lookup_immediate(key_dest) {
        Some(destination) =>
          @test.assert_eq(
            doc.read_destination(destination),
            DestXYZ(
              TargetPageObject(page_numbers[0]),
              Some(11.0),
              Some(22.0),
              None,
            ),
          )
        _ => fail("expected transformed indirect annotation destination")
      }
      match action_annotation.lookup_immediate(key_action) {
        Some(action) =>
          @test.assert_eq(
            doc.read_destination(action),
            DestXYZ(
              TargetPageObject(page_numbers[0]),
              Some(13.0),
              Some(24.0),
              None,
            ),
          )
        _ => fail("expected transformed direct action annotation")
      }
    }
    _ => fail("expected mixed direct and indirect annotations")
  }
  match doc.catalog().lookup_immediate(key_open_action) {
    Some(action) =>
      @test.assert_eq(
        doc.read_destination(action),
        DestXYZ(TargetPageObject(page_numbers[0]), Some(15.0), Some(26.0), None),
      )
    _ => fail("expected transformed OpenAction action")
  }
  @test.assert_eq(
    doc.read_destination(PdfNameObject(acceptance_name_for_test("/Chapter"))),
    DestFitH(TargetPageObject(page_numbers[0]), Some(27.0)),
  )
  @test.assert_eq(
    doc.read_destination(PdfString(acceptance_ascii_for_test("chapter-action"))),
    DestXYZ(TargetPageObject(page_numbers[0]), Some(18.0), Some(29.0), None),
  )
  @test.assert_eq(doc.read_bookmarks(), [
    {
      level: 0,
      text: acceptance_ascii_for_test("Chapter"),
      target: DestXYZ(
        TargetPageObject(page_numbers[0]),
        Some(18.0),
        Some(29.0),
        None,
      ),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
fn acceptance_inherited_change_pages_mediabox_for_test() -> @pdflite.PdfObject {
  PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(500), PdfInteger(700)])
}

///|
fn acceptance_inherited_change_pages_cropbox_for_test() -> @pdflite.PdfObject {
  PdfArray([PdfInteger(10), PdfInteger(20), PdfInteger(490), PdfInteger(680)])
}

///|
fn acceptance_inherited_change_pages_document_for_test() -> @pdflite.PdfDocument raise {
  let key_type = acceptance_name_for_test("/Type")
  let key_parent = acceptance_name_for_test("/Parent")
  let key_kids = acceptance_name_for_test("/Kids")
  let key_count = acceptance_name_for_test("/Count")
  let key_resources = acceptance_name_for_test("/Resources")
  let key_mediabox = acceptance_name_for_test("/MediaBox")
  let key_cropbox = acceptance_name_for_test("/CropBox")
  let key_rotate = acceptance_name_for_test("/Rotate")
  let key_contents = acceptance_name_for_test("/Contents")
  let key_annots = acceptance_name_for_test("/Annots")
  let key_subtype = acceptance_name_for_test("/Subtype")
  let key_rect = acceptance_name_for_test("/Rect")
  let key_action = acceptance_name_for_test("/A")
  let key_open_action = acceptance_name_for_test("/OpenAction")
  let key_dests = acceptance_name_for_test("/Dests")
  let key_names = acceptance_name_for_test("/Names")
  let type_pages = acceptance_name_for_test("/Pages")
  let type_page = acceptance_name_for_test("/Page")
  let type_link = acceptance_name_for_test("/Link")
  let named_destination = acceptance_name_for_test("/InheritedChapter")
  let string_destination = acceptance_ascii_for_test("inherited-chapter")
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 6)
  doc.add_object_given_number(70, acceptance_change_pages_form_for_test())
  doc.add_object_given_number(
    71,
    acceptance_resource_lifecycle_resources_for_test(
      acceptance_name_for_test("/F0"),
      acceptance_name_for_test("/Fm1"),
      70,
    ),
  )
  doc.add_object_given_number(
    72,
    @pdflite.pdf_content_stream_of_ops(
      acceptance_change_pages_resource_ops_for_test("InheritedBefore"),
    ),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(type_pages)),
      (key_kids, PdfArray([PdfIndirect(3)])),
      (key_count, PdfInteger(1)),
      (key_resources, PdfIndirect(71)),
      (key_mediabox, acceptance_inherited_change_pages_mediabox_for_test()),
      (key_cropbox, acceptance_inherited_change_pages_cropbox_for_test()),
      (key_rotate, PdfInteger(90)),
    ]),
  )
  doc.add_object_given_number(
    3,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(type_page)),
      (key_parent, PdfIndirect(2)),
      (key_contents, PdfIndirect(72)),
    ]),
  )
  ignore(doc.add_root(2, []))
  let page_number = doc.page_reference_numbers()[0]
  doc.add_object_given_number(
    81,
    acceptance_change_pages_goto_for_test(
      acceptance_change_pages_xyz_for_test(page_number, 1, 2),
    ),
  )
  doc.add_object_given_number(
    80,
    @pdflite.pdf_dictionary([
      (key_subtype, PdfNameObject(type_link)),
      (
        key_rect,
        PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(10), PdfInteger(10)]),
      ),
      (key_action, PdfIndirect(81)),
    ]),
  )
  let uri_action = @pdflite.pdf_dictionary([
    (
      acceptance_name_for_test("/S"),
      PdfNameObject(acceptance_name_for_test("/URI")),
    ),
    (
      acceptance_name_for_test("/URI"),
      PdfString(acceptance_ascii_for_test("https://example.test")),
    ),
  ])
  let uri_annotation = @pdflite.pdf_dictionary([
    (key_subtype, PdfNameObject(type_link)),
    (
      key_rect,
      PdfArray([PdfInteger(10), PdfInteger(10), PdfInteger(20), PdfInteger(20)]),
    ),
    (key_action, uri_action),
  ])
  doc.add_object_given_number(
    page_number,
    doc
    .lookup_object_or_null(page_number)
    .add_dict_entry(key_annots, PdfArray([PdfIndirect(80), uri_annotation])),
  )
  doc.add_object_given_number(
    90,
    acceptance_change_pages_goto_for_test(
      acceptance_change_pages_xyz_for_test(page_number, 3, 4),
    ),
  )
  doc.add_object_given_number(
    91,
    PdfDictionary([
      (
        named_destination,
        PdfArray([
          PdfIndirect(page_number),
          PdfNameObject(acceptance_name_for_test("/FitV")),
          PdfInteger(5),
        ]),
      ),
    ]),
  )
  doc.add_object_given_number(
    92,
    PdfDictionary([
      (
        key_dests,
        doc.build_name_tree([
          (
            string_destination,
            acceptance_change_pages_goto_for_test(
              acceptance_change_pages_xyz_for_test(page_number, 6, 7),
            ),
          ),
        ]),
      ),
    ]),
  )
  acceptance_add_catalog_entry_for_test(doc, key_open_action, PdfIndirect(90))
  acceptance_add_catalog_entry_for_test(doc, key_dests, PdfIndirect(91))
  acceptance_add_catalog_entry_for_test(doc, key_names, PdfIndirect(92))
  doc.add_bookmarks([
    {
      level: 0,
      text: acceptance_ascii_for_test("Inherited"),
      target: DestString(string_destination),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
fn acceptance_assert_inherited_change_pages_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  let key_annots = acceptance_name_for_test("/Annots")
  let key_action = acceptance_name_for_test("/A")
  let key_cropbox = acceptance_name_for_test("/CropBox")
  let key_open_action = acceptance_name_for_test("/OpenAction")
  let key_s = acceptance_name_for_test("/S")
  let key_uri = acceptance_name_for_test("/URI")
  let page_numbers = doc.page_reference_numbers()
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(doc.version(), (1, 6))
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    pages[0].mediabox,
    acceptance_inherited_change_pages_mediabox_for_test(),
  )
  @test.assert_eq(
    pages[0].rest.lookup_immediate(key_cropbox),
    Some(acceptance_inherited_change_pages_cropbox_for_test()),
  )
  @test.assert_eq(pages[0].rotate, Rotate90)
  @test.assert_eq(
    doc.parse_content_ops(pages[0].content),
    acceptance_change_pages_resource_ops_for_test("InheritedAfter"),
  )
  ignore(
    acceptance_page_resource_for_test(
      doc,
      pages[0],
      acceptance_name_for_test("/Font"),
      acceptance_name_for_test("/F0"),
    ),
  )
  ignore(
    acceptance_page_resource_for_test(
      doc,
      pages[0],
      acceptance_name_for_test("/XObject"),
      acceptance_name_for_test("/Fm1"),
    ),
  )
  match pages[0].rest.lookup_immediate(key_annots) {
    Some(PdfArray([PdfIndirect(indirect_annotation), PdfDictionary(_) as uri])) => {
      match
        doc
        .lookup_object_or_null(indirect_annotation)
        .lookup_immediate(key_action) {
        Some(action) =>
          @test.assert_eq(
            doc.read_destination(action),
            DestXYZ(
              TargetPageObject(page_numbers[0]),
              Some(11.0),
              Some(22.0),
              None,
            ),
          )
        _ => fail("expected transformed indirect action annotation")
      }
      match uri.lookup_immediate(key_action) {
        Some(action) => {
          @test.assert_eq(
            action.lookup_immediate(key_s),
            Some(PdfNameObject(acceptance_name_for_test("/URI"))),
          )
          @test.assert_eq(
            action.lookup_immediate(key_uri),
            Some(PdfString(acceptance_ascii_for_test("https://example.test"))),
          )
        }
        _ => fail("expected preserved URI action annotation")
      }
    }
    _ => fail("expected inherited-page annotations")
  }
  match doc.catalog().lookup_immediate(key_open_action) {
    Some(action) =>
      @test.assert_eq(
        doc.read_destination(action),
        DestXYZ(TargetPageObject(page_numbers[0]), Some(13.0), Some(24.0), None),
      )
    _ => fail("expected transformed indirect OpenAction")
  }
  @test.assert_eq(
    doc.read_destination(
      PdfNameObject(acceptance_name_for_test("/InheritedChapter")),
    ),
    DestFitV(TargetPageObject(page_numbers[0]), Some(15.0)),
  )
  @test.assert_eq(
    doc.read_destination(
      PdfString(acceptance_ascii_for_test("inherited-chapter")),
    ),
    DestXYZ(TargetPageObject(page_numbers[0]), Some(16.0), Some(27.0), None),
  )
  @test.assert_eq(doc.read_bookmarks(), [
    {
      level: 0,
      text: acceptance_ascii_for_test("Inherited"),
      target: DestXYZ(
        TargetPageObject(page_numbers[0]),
        Some(16.0),
        Some(27.0),
        None,
      ),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
fn acceptance_assert_catalog_merge_lifecycle_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  let key_acroform = acceptance_name_for_test("/AcroForm")
  let key_fields = acceptance_name_for_test("/Fields")
  let key_t = acceptance_name_for_test("/T")
  let key_need_appearances = acceptance_name_for_test("/NeedAppearances")
  let key_info = acceptance_name_for_test("/Info")
  let key_title = acceptance_name_for_test("/Title")
  let key_struct_tree_root = acceptance_name_for_test("/StructTreeRoot")
  let key_parent_tree = acceptance_name_for_test("/ParentTree")
  let key_k = acceptance_name_for_test("/K")
  let key_p = acceptance_name_for_test("/P")
  let key_pg = acceptance_name_for_test("/Pg")
  acceptance_assert_pages_have_hello_content_for_test(doc, 2)
  @test.assert_eq(doc.version(), (1, 6))
  guard doc.lookup_direct(key_acroform, doc.catalog()) is Some(form) else {
    fail("expected merged AcroForm")
  }
  guard form.lookup_immediate(key_fields) is Some(PdfArray(fields)) else {
    fail("expected AcroForm fields")
  }
  @test.assert_eq(fields.length(), 2)
  guard fields[0] is PdfIndirect(first_field) else {
    fail("expected first AcroForm field")
  }
  guard fields[1] is PdfIndirect(second_field) else {
    fail("expected second AcroForm field")
  }
  @test.assert_eq(
    doc.lookup_object_or_null(first_field).lookup_immediate(key_t),
    Some(PdfString(acceptance_ascii_for_test("first-field"))),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(second_field).lookup_immediate(key_t),
    Some(PdfString(acceptance_ascii_for_test("second-field"))),
  )
  @test.assert_eq(
    form.lookup_immediate(key_need_appearances),
    Some(PdfBoolean(true)),
  )
  guard doc.read_optional_content_groups() is Some(content) else {
    fail("expected merged optional content")
  }
  @test.assert_eq(content.ocgs.length(), 2)
  @test.assert_eq(
    content.ocgs[0].1.name,
    acceptance_ascii_for_test("first-field"),
  )
  @test.assert_eq(
    content.ocgs[1].1.name,
    acceptance_ascii_for_test("second-field"),
  )
  @test.assert_eq(content.default_config.on.length(), 2)
  let catalog = doc.catalog()
  guard catalog.lookup_immediate(key_struct_tree_root)
    is Some(PdfIndirect(struct_root_number)) else {
    fail("expected merged StructTreeRoot")
  }
  let struct_root = doc.lookup_object_or_null(struct_root_number)
  guard struct_root.lookup_immediate(key_k) is Some(PdfArray(kids)) else {
    fail("expected structure kids")
  }
  @test.assert_eq(kids.length(), 2)
  guard kids[0] is PdfIndirect(first_kid) else {
    fail("expected first structure child")
  }
  guard kids[1] is PdfIndirect(second_kid) else {
    fail("expected second structure child")
  }
  let page_numbers = doc.page_reference_numbers()
  @test.assert_eq(
    doc.lookup_object_or_null(first_kid).lookup_immediate(key_p),
    Some(PdfIndirect(struct_root_number)),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(second_kid).lookup_immediate(key_p),
    Some(PdfIndirect(struct_root_number)),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(first_kid).lookup_immediate(key_pg),
    Some(PdfIndirect(page_numbers[0])),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(second_kid).lookup_immediate(key_pg),
    Some(PdfIndirect(page_numbers[1])),
  )
  guard doc.lookup_direct(key_parent_tree, struct_root) is Some(parent_tree) else {
    fail("expected merged ParentTree")
  }
  let parent_entries = doc.read_number_tree(parent_tree)
  @test.assert_eq(parent_entries.length(), 2)
  @test.assert_eq([ for entry in parent_entries => entry.0 ], [0, 1])
  guard doc.lookup_direct(key_info, doc.trailer_dict()) is Some(info) else {
    fail("expected retained Info dictionary")
  }
  @test.assert_eq(
    info.lookup_immediate(key_title),
    Some(PdfString(acceptance_ascii_for_test("first-title"))),
  )
}

///|
fn acceptance_draft_substitute_ops_for_test() -> Array[@pdflite.PdfContentOp] {
  [
    Op_q,
    Op_w(0.0),
    Op_G(0.0),
    Op_re(0.0, 0.0, 1.0, 1.0),
    Op_m(0.0, 0.0),
    Op_l(1.0, 1.0),
    Op_m(0.0, 1.0),
    Op_l(1.0, 0.0),
    Op_S,
    Op_Q,
  ]
}

///|
fn acceptance_draft_xobject_is_image_for_test(
  doc : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  name : @pdflite.PdfName,
) -> Bool {
  match doc.lookup_direct(acceptance_name_for_test("/XObject"), resources) {
    Some(xobjects) =>
      match doc.lookup_direct(name, xobjects) {
        Some(xobject) =>
          match
            doc.lookup_direct(acceptance_name_for_test("/Subtype"), xobject) {
            Some(PdfNameObject(subtype)) =>
              subtype == acceptance_name_for_test("/Image")
            _ => false
          }
        None => false
      }
    None => false
  }
}

///|
fn acceptance_draft_remove_image_xobjects_for_test(
  doc : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
) -> @pdflite.PdfObject {
  let key_xobject = acceptance_name_for_test("/XObject")
  match resources {
    PdfDictionary(entries) => {
      let retained : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = []
      for entry in entries {
        let (key, value) = entry
        if key == key_xobject {
          match doc.direct(value) {
            PdfDictionary(xobjects) => {
              let kept : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = []
              for xobject_entry in xobjects {
                let (resource_name, _) = xobject_entry
                if !acceptance_draft_xobject_is_image_for_test(
                    doc, resources, resource_name,
                  ) {
                  kept.push(xobject_entry)
                }
              }
              retained.push((key, PdfDictionary(kept)))
            }
            _ => retained.push(entry)
          }
        } else {
          retained.push(entry)
        }
      }
      PdfDictionary(retained)
    }
    _ => resources
  }
}

///|
fn acceptance_draft_ops_for_test(
  doc : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  ops : ArrayView[@pdflite.PdfContentOp],
) -> Array[@pdflite.PdfContentOp] {
  let output : Array[@pdflite.PdfContentOp] = []
  for op in ops {
    match op {
      Op_Do(name) if acceptance_draft_xobject_is_image_for_test(
          doc, resources, name,
        ) =>
        for replacement in acceptance_draft_substitute_ops_for_test() {
          output.push(replacement)
        }
      Op_InlineImage(_, _, _) =>
        for replacement in acceptance_draft_substitute_ops_for_test() {
          output.push(replacement)
        }
      _ => output.push(op)
    }
  }
  output
}

///|
fn acceptance_draft_page_for_test(
  doc : @pdflite.PdfDocument,
  page : @pdflite.PdfPage,
) -> @pdflite.PdfPage raise {
  let ops = doc.parse_content_ops(page.content)
  let stream = @pdflite.pdf_content_stream_of_ops(
    acceptance_draft_ops_for_test(doc, page.resources, ops),
  )
  let encoded = @pdflite.pdf_encode_stream_with_filter(
    acceptance_name_for_test("/FlateDecode"),
    stream,
  )
  {
    ..page,
    content: [encoded],
    resources: acceptance_draft_remove_image_xobjects_for_test(
      doc,
      page.resources,
    ),
  }
}

///|
fn acceptance_draft_document_for_test(
  doc : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let pages = doc.pages_of_pagetree()
  let rewritten : Array[@pdflite.PdfPage] = []
  for page in pages {
    rewritten.push(acceptance_draft_page_for_test(doc, page))
  }
  let page_root = doc.add_pagetree(rewritten)
  ignore(doc.add_root(page_root, []))
  doc.remove_unreferenced()
  doc
}

///|
fn acceptance_draft_source_document_for_test() -> @pdflite.PdfDocument raise {
  let key_length = acceptance_name_for_test("/Length")
  let key_subtype = acceptance_name_for_test("/Subtype")
  let image_name = acceptance_name_for_test("/Im1")
  let form_name = acceptance_name_for_test("/Fm1")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    7,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (key_subtype, PdfNameObject(acceptance_name_for_test("/Image"))),
        (key_length, PdfInteger(0)),
      ]),
      StreamGot([]),
    ),
  )
  doc.add_object_given_number(
    8,
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (key_subtype, PdfNameObject(acceptance_name_for_test("/Form"))),
        (key_length, PdfInteger(3)),
      ]),
      StreamGot(acceptance_ascii_for_test("q Q")),
    ),
  )
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    resources: @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/XObject"),
        @pdflite.pdf_dictionary([
          (image_name, PdfIndirect(7)),
          (form_name, PdfIndirect(8)),
        ]),
      ),
    ]),
    content: [
      @pdflite.pdf_content_stream_of_ops([
        Op_Do(image_name),
        Op_Do(form_name),
        Op_InlineImage(
          PdfDictionary([
            (acceptance_name_for_test("/W"), PdfInteger(1)),
            (acceptance_name_for_test("/H"), PdfInteger(1)),
            (
              acceptance_name_for_test("/CS"),
              PdfNameObject(acceptance_name_for_test("/DeviceGray")),
            ),
            (acceptance_name_for_test("/BPC"), PdfInteger(1)),
          ]),
          None,
          Bytes::from_array([0]),
        ),
      ]),
    ],
  }
  let page_root = doc.add_pagetree([page])
  ignore(doc.add_root(page_root, []))
  doc
}

///|
fn acceptance_assert_drafted_document_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  let form_name = acceptance_name_for_test("/Fm1")
  let pages = doc.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    doc.parse_content_ops(pages[0].content),
    [
      ..acceptance_draft_substitute_ops_for_test(),
      Op_Do(form_name),
      ..acceptance_draft_substitute_ops_for_test(),
    ],
  )
  @test.assert_eq(doc.lookup_object_or_null(7), PdfNull)
  guard doc.lookup_object_or_null(8) is PdfStreamObject(_) else {
    fail("expected form xobject to remain")
  }
  guard doc.lookup_direct(
      acceptance_name_for_test("/XObject"),
      pages[0].resources,
    )
    is Some(PdfDictionary(xobjects)) else {
    fail("expected retained XObject dictionary")
  }
  @test.assert_eq(xobjects, [(form_name, PdfIndirect(8))])
}

///|
fn acceptance_aes_iv_for_test(
  object_number : Int,
  generation : Int,
  index : Int,
) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(
    [
      for offset in 0..<16 => {
        (object_number * 17 + generation * 5 + index * 31 + offset) % 256
      }
    ],
  )
}

///|
fn acceptance_unwrap_decryption_for_test(
  result : @pdflite.PdfDecryptionResult?,
) -> @pdflite.PdfDecryptionResult raise {
  match result {
    Some(value) => value
    None => fail("expected decryption to succeed")
  }
}

///|
fn acceptance_assert_decrypted_object_stream_payload_for_test(
  decrypted : @pdflite.PdfDecryptionResult,
  denied_permissions : Array[@pdflite.PdfPermission],
) -> Unit raise {
  @test.assert_eq(decrypted.denied_permissions, denied_permissions)
  @test.assert_eq(
    decrypted.document.lookup_object_or_null(2),
    acceptance_secret_object_for_test("encrypted object stream"),
  )
  let catalog = decrypted.document.catalog()
  @test.assert_eq(
    catalog.lookup_immediate(acceptance_name_for_test("/Payload")),
    Some(PdfIndirect(2)),
  )
}

///|
test "native acceptance suite roundtrips classic and xref-stream documents" {
  acceptance_assert_public_read_write_for_test(
    try! @pdflite.pdf_write_document(
      try! acceptance_one_page_document_for_test(),
    ),
    (1, 4),
  )
  acceptance_assert_public_read_write_for_test(
    try! @pdflite.pdf_write_document_with_xref_stream(
      try! acceptance_one_page_document_for_test(),
    ),
    (1, 5),
  )
  acceptance_assert_public_read_write_for_test(
    try! @pdflite.pdf_write_document_with_compressed_xref_stream(
      try! acceptance_one_page_document_for_test(),
    ),
    (1, 5),
  )
}

///|
test "native acceptance suite extracts ToUnicode text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_tounicode_text_document_for_test(),
  )
  acceptance_assert_tounicode_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_tounicode_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts ToUnicode variation text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_tounicode_variation_document_for_test(),
  )
  acceptance_assert_tounicode_variation_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_tounicode_variation_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts ToUnicode parser corner cases through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_tounicode_parser_corner_document_for_test(),
  )
  acceptance_assert_tounicode_parser_corner_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_tounicode_parser_corner_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts ToUnicode sequence text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_tounicode_sequence_document_for_test(),
  )
  acceptance_assert_tounicode_sequence_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_tounicode_sequence_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Type3 ToUnicode text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_type3_text_document_for_test(),
  )
  acceptance_assert_type3_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_type3_text_for_test(reparsed)
}

///|
test "native acceptance suite resolves Type3 nested form resources through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_type3_form_resource_document_for_test(),
  )
  acceptance_assert_type3_form_resource_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_type3_form_resource_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Type3 encoded glyph text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_type3_encoded_text_document_for_test(),
  )
  acceptance_assert_type3_encoded_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_type3_encoded_text_for_test(reparsed)
}

///|
test "native acceptance suite preserves Type3 fixture-shaped CharProcs through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_type3_fixture_charproc_document_for_test(),
  )
  acceptance_assert_type3_fixture_charprocs_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_type3_fixture_charprocs_for_test(reparsed)
}

///|
test "native acceptance suite extracts Identity-H CID text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_identity_h_text_document_for_test(),
  )
  acceptance_assert_identity_h_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_identity_h_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Identity-V CID text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_identity_v_text_document_for_test(),
  )
  acceptance_assert_identity_v_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_identity_v_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts GBK2K predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_gbk2k_text_document_for_test(),
  )
  acceptance_assert_gbk2k_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_gbk2k_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Big5 predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_big5_text_document_for_test(),
  )
  acceptance_assert_big5_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_big5_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts HKSCS predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_hkscs_text_document_for_test(),
  )
  acceptance_assert_hkscs_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_hkscs_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts CNS-EUC predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_cns_euc_text_document_for_test(),
  )
  acceptance_assert_cns_euc_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_cns_euc_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts vertical predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_vertical_predefined_cmap_text_document_for_test(),
  )
  acceptance_assert_vertical_predefined_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_vertical_predefined_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Unicode predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_unicode_predefined_cmap_document_for_test(),
  )
  acceptance_assert_unicode_predefined_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_unicode_predefined_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Adobe-Korea1 predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_korea_cmap_text_document_for_test(),
  )
  acceptance_assert_korea_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_korea_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Adobe-GB1 predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_gb1_cmap_text_document_for_test(),
  )
  acceptance_assert_gb1_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_gb1_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Adobe-CNS1 variant predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_cns1_variant_cmap_text_document_for_test(),
  )
  acceptance_assert_cns1_variant_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_cns1_variant_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Adobe-Japan1 predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_japan1_cmap_text_document_for_test(),
  )
  acceptance_assert_japan1_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_japan1_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Adobe-Japan1 90msp predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_japan1_90msp_cmap_text_document_for_test(),
  )
  acceptance_assert_japan1_90msp_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_japan1_90msp_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Adobe-Japan1 legacy predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_japan1_legacy_cmap_text_document_for_test(),
  )
  acceptance_assert_japan1_legacy_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_japan1_legacy_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Adobe-Japan1 supplemental predefined CMap text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_japan1_supplemental_cmap_text_document_for_test(),
  )
  acceptance_assert_japan1_supplemental_cmap_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_japan1_supplemental_cmap_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts Type0 ToUnicode CID text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_identity_h_tounicode_text_document_for_test(),
  )
  acceptance_assert_identity_h_tounicode_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_identity_h_tounicode_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts embedded TrueType text through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_truetype_text_document_for_test(),
  )
  acceptance_assert_truetype_text_for_test(parsed)
  let reparsed = acceptance_compressed_roundtrip_for_test(parsed)
  acceptance_assert_truetype_text_for_test(reparsed)
}

///|
test "native acceptance suite extracts images through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_image_lifecycle_document_for_test(),
  )
  acceptance_assert_image_lifecycle_for_test(parsed)
  let decompressed = parsed.copy()
  decompressed.pdf_decode_streams_until_unknown()
  acceptance_assert_image_lifecycle_for_test(decompressed)
  let reparsed = acceptance_compressed_roundtrip_for_test(decompressed)
  acceptance_assert_image_lifecycle_for_test(reparsed)
}

///|
test "native acceptance suite preserves encoded image aliases through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_encoded_image_alias_document_for_test(),
  )
  acceptance_assert_encoded_image_aliases_for_test(parsed)
  let decompressed = parsed.copy()
  decompressed.pdf_decode_streams_until_unknown()
  acceptance_assert_encoded_image_aliases_for_test(decompressed)
  let reparsed = acceptance_compressed_roundtrip_for_test(decompressed)
  acceptance_assert_encoded_image_aliases_for_test(reparsed)
}

///|
test "native acceptance suite resolves named image resources through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_named_image_resource_document_for_test(),
  )
  acceptance_assert_named_image_resources_for_test(parsed)
  let decompressed = parsed.copy()
  decompressed.pdf_decode_streams_until_unknown()
  acceptance_assert_named_image_resources_for_test(decompressed)
  let reparsed = acceptance_compressed_roundtrip_for_test(decompressed)
  acceptance_assert_named_image_resources_for_test(reparsed)
}

///|
test "native acceptance suite decodes CMYK images through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_cmyk_image_document_for_test(),
  )
  acceptance_assert_cmyk_images_for_test(parsed)
  let decompressed = parsed.copy()
  decompressed.pdf_decode_streams_until_unknown()
  acceptance_assert_cmyk_images_for_test(decompressed)
  let reparsed = acceptance_compressed_roundtrip_for_test(decompressed)
  acceptance_assert_cmyk_images_for_test(reparsed)
}

///|
test "native acceptance suite decodes alternate image colour spaces through reader boundaries" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_alt_image_document_for_test(),
  )
  acceptance_assert_alt_images_for_test(parsed)
  let decompressed = parsed.copy()
  decompressed.pdf_decode_streams_until_unknown()
  acceptance_assert_alt_images_for_test(decompressed)
  let reparsed = acceptance_compressed_roundtrip_for_test(decompressed)
  acceptance_assert_alt_images_for_test(reparsed)
}

///|
test "native acceptance suite reads classic and xref-stream incremental revisions" {
  let original = try! @pdflite.pdf_write_document(
    try! acceptance_one_page_document_for_test(),
  )
  let original_parsed = try! @pdflite.pdf_read_document_from_bytes(original)
  let classic_updated = try! acceptance_add_revision_marker_for_test(
    original_parsed, 90, "classic-update",
  )
  let classic_update = try! @pdflite.pdf_write_document_incremental_update(
    original, classic_updated,
  )
  @test.assert_eq(try! @pdflite.pdf_revisions_from_bytes(classic_update), 2)
  let classic_newest = try! @pdflite.pdf_read_document_revision_from_bytes(
    classic_update, 1,
  )
  acceptance_assert_one_page_invariants_for_test(classic_newest, (1, 4))
  acceptance_assert_revision_marker_for_test(
    classic_newest, 90, "classic-update",
  )
  let classic_older = try! @pdflite.pdf_read_document_revision_from_bytes(
    classic_update, 2,
  )
  acceptance_assert_one_page_invariants_for_test(classic_older, (1, 4))
  acceptance_assert_no_revision_marker_for_test(classic_older, 90)

  let xref_original = try! @pdflite.pdf_write_document_with_xref_stream(
    try! acceptance_one_page_document_for_test(),
  )
  let xref_original_parsed = try! @pdflite.pdf_read_document_from_bytes(
    xref_original,
  )
  let xref_updated = try! acceptance_add_revision_marker_for_test(
    xref_original_parsed, 91, "xref-update",
  )
  let xref_update = try! @pdflite.pdf_write_document_incremental_update_with_compressed_xref_stream(
    xref_original, xref_updated,
  )
  @test.assert_eq(try! @pdflite.pdf_revisions_from_bytes(xref_update), 2)
  let xref_newest = try! @pdflite.pdf_read_document_revision_from_bytes(
    xref_update, 1,
  )
  acceptance_assert_one_page_invariants_for_test(xref_newest, (1, 5))
  acceptance_assert_revision_marker_for_test(xref_newest, 91, "xref-update")
  let xref_older = try! @pdflite.pdf_read_document_revision_from_bytes(
    xref_update, 2,
  )
  acceptance_assert_one_page_invariants_for_test(xref_older, (1, 5))
  acceptance_assert_no_revision_marker_for_test(xref_older, 91)
}

///|
test "native acceptance suite reconstructs compressed xref incremental revisions with bad startxref" {
  let xref_original = @pdflite.pdf_write_document_with_xref_stream(
    acceptance_one_page_document_for_test(),
  )
  let xref_original_parsed = @pdflite.pdf_read_document_from_bytes(
    xref_original,
  )
  let xref_updated = acceptance_add_revision_marker_for_test(
    xref_original_parsed, 93, "xref-bad-startxref-update",
  )
  let xref_update = @pdflite.pdf_write_document_incremental_update_with_compressed_xref_stream(
    xref_original, xref_updated,
  )
  let corrupted = acceptance_corrupt_startxref_pointer_for_test(xref_update)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected bad startxref to require malformed reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  acceptance_assert_one_page_invariants_for_test(recovered, (1, 5))
  acceptance_assert_revision_marker_for_test(
    recovered, 93, "xref-bad-startxref-update",
  )
  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered,
  )
  let reparsed = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_one_page_invariants_for_test(reparsed, (1, 5))
  acceptance_assert_revision_marker_for_test(
    reparsed, 93, "xref-bad-startxref-update",
  )
}

///|
test "native acceptance suite updates documents through public writer modes" {
  let original = @pdflite.pdf_write_document_with_mode(
    acceptance_one_page_document_for_test(),
    PdfWriteXRefStream,
  )
  let original_parsed = @pdflite.pdf_read_document_from_bytes(original)
  acceptance_assert_one_page_invariants_for_test(original_parsed, (1, 5))

  let updated = acceptance_add_revision_marker_for_test(
    original_parsed, 92, "mode-dispatched-update",
  )
  let rendered = @pdflite.pdf_write_document_incremental_update_with_mode(
    original,
    updated,
    PdfWriteCompressedXRefStream,
  )
  @test.assert_eq(@pdflite.pdf_revisions_from_bytes(rendered), 2)
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rendered,
      acceptance_ascii_for_test("/FlateDecode"),
    ) >
    original.length(),
    true,
  )
  let newest = @pdflite.pdf_read_document_revision_from_bytes(rendered, 1)
  acceptance_assert_one_page_invariants_for_test(newest, (1, 5))
  acceptance_assert_revision_marker_for_test(
    newest, 92, "mode-dispatched-update",
  )
  let older = @pdflite.pdf_read_document_revision_from_bytes(rendered, 2)
  acceptance_assert_one_page_invariants_for_test(older, (1, 5))
  acceptance_assert_no_revision_marker_for_test(older, 92)
}

///|
test "native acceptance suite normalizes object-stream pages through writer" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    acceptance_object_stream_pdf_for_test(),
  )
  acceptance_assert_object_stream_document_for_test(parsed)
  let normalized = try! @pdflite.pdf_write_document(parsed)
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(normalized)
  acceptance_assert_object_stream_document_for_test(reparsed)
}

///|
test "native acceptance suite reconstructs indirect-filter object-stream page trees" {
  let strict = @pdflite.pdf_read_document_from_bytes(
    acceptance_indirect_filtered_object_stream_pdf_for_test(None),
  )
  acceptance_assert_indirect_filtered_object_stream_for_test(strict)

  let malformed = acceptance_indirect_filtered_object_stream_pdf_for_test(
    Some(0),
  )
  let strict_malformed : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict_malformed is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected malformed startxref to require object-stream reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(malformed)
  @test.assert_eq(recovered.first_xref(), 0)
  acceptance_assert_indirect_filtered_object_stream_for_test(recovered)

  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered,
  )
  let reparsed = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_indirect_filtered_object_stream_for_test(reparsed)
}

///|
test "native acceptance suite reconstructs prev-chain object-stream page trees" {
  let strict = @pdflite.pdf_read_document_from_bytes(
    acceptance_prev_object_stream_pdf_for_test(None),
  )
  acceptance_assert_prev_object_stream_page_tree_for_test(strict)

  let malformed = acceptance_prev_object_stream_pdf_for_test(Some(0))
  let strict_malformed : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict_malformed is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected bad final startxref to require /Prev-chain reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(malformed)
  @test.assert_eq(recovered.first_xref(), 0)
  acceptance_assert_prev_object_stream_page_tree_for_test(recovered)

  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered,
  )
  let reparsed = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_prev_object_stream_page_tree_for_test(reparsed)
}

///|
test "native acceptance suite reconstructs physical page trees when object-stream bounds are malformed" {
  let bytes = acceptance_bad_first_object_stream_physical_page_tree_pdf_for_test()
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    bytes,
  )
  guard strict is Err(@pdflite.PdfError::StreamDataExpected) else {
    fail("expected malformed object-stream bounds to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(bytes)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.version(), (1, 5))
  @test.assert_eq(recovered.object_numbers(), [1, 2, 3, 5])
  @test.assert_eq(try! recovered.endpage(), 1)
  @test.assert_eq(try! recovered.page_reference_numbers(), [5])
  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered,
  )
  let reparsed = @pdflite.pdf_read_document_from_bytes(rewritten)
  @test.assert_eq(try! reparsed.endpage(), 1)
  @test.assert_eq(try! reparsed.page_reference_numbers(), [5])
}

///|
test "native acceptance suite rejects mismatched object-stream root recovery" {
  let bytes = acceptance_mismatched_object_stream_root_pdf_for_test()
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    bytes,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected strict object-stream root mismatch failure")
  }
  let public : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    bytes,
  )
  guard public is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected public reader to reject physical fallback after mismatch")
  }
}

///|
test "native acceptance suite rejects unsupported object-stream filters" {
  let bad_filter : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    acceptance_filtered_object_stream_root_pdf_for_test(
      " /Filter /BadObjectStreamFilter", false,
    ),
  )
  let filter = match bad_filter {
    Err(@pdflite.PdfError::FilterNotSupported(filter)) => filter
    Err(_) => fail("expected unsupported object-stream filter")
    Ok(_) => fail("expected unsupported object-stream filter failure")
  }
  @test.assert_eq(filter, acceptance_name_for_test("/BadObjectStreamFilter"))

  let bad_decodeparms : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    acceptance_filtered_object_stream_root_pdf_for_test(
      " /Filter /FlateDecode /DecodeParms /Bad", true,
    ),
  )
  guard bad_decodeparms is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected malformed object-stream DecodeParms failure")
  }

  let bad_predictor : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    acceptance_filtered_object_stream_root_pdf_for_test(
      " /Filter /FlateDecode /DecodeParms << /Predictor 9 >>", true,
    ),
  )
  guard bad_predictor
    is Err(@pdflite.PdfError::PredictorNotSupported(predictor)) else {
    fail("expected unsupported object-stream predictor failure")
  }
  @test.assert_eq(predictor, 9)
}

///|
test "native acceptance suite rejects invalid object-stream data slices" {
  let bytes = acceptance_bad_first_object_stream_entry_pdf_for_test()
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    bytes,
  )
  guard strict is Err(@pdflite.PdfError::StreamDataExpected) else {
    fail("expected strict invalid object-stream slice failure")
  }
  let public : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    bytes,
  )
  guard public is Err(@pdflite.PdfError::StreamDataExpected) else {
    fail("expected public invalid object-stream slice failure")
  }
}

///|
test "native acceptance suite rejects non-xref startxref targets" {
  let non_stream : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    acceptance_startxref_object_pdf_for_test("7"),
  )
  guard non_stream is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected non-stream startxref target rejection")
  }

  let wrong_stream_type : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    acceptance_startxref_object_pdf_for_test(
      "<< /Length 0 >>\nstream\n\nendstream",
    ),
  )
  guard wrong_stream_type is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected stream without xref type rejection")
  }

  let explicit_wrong_type : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    acceptance_xref_stream_pdf_with_type_for_test("/Type /Catalog"),
  )
  guard explicit_wrong_type is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected explicit wrong xref stream type rejection")
  }

  let non_name_type : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    acceptance_xref_stream_pdf_with_type_for_test("/Type 99"),
  )
  guard non_name_type is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected non-name xref stream type rejection")
  }
}

///|
test "native acceptance suite decrypts object streams during password reads" {
  let bytes = try! acceptance_encrypted_object_stream_pdf_for_test()
  let no_password : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    bytes,
  )
  guard no_password is Err(_) else {
    fail("expected encrypted object stream to require password-aware reading")
  }
  let bad_password : Result[@pdflite.PdfDecryptionResult?, Error] = try? @pdflite.pdf_read_document_from_bytes_with_passwords(
    bytes,
    owner_password=Some(acceptance_ascii_for_test("bad-owner")),
  )
  guard bad_password is Err(_) else {
    fail("expected bad password to fail encrypted object-stream expansion")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      bytes,
      owner_password=Some(acceptance_ascii_for_test("owner")),
    ),
  )
  acceptance_assert_decrypted_object_stream_payload_for_test(decrypted, [
    PdfNoCopy,
  ])
}

///|
test "native acceptance suite reconstructs encrypted object streams with bad startxref" {
  let bytes = acceptance_corrupt_startxref_pointer_for_test(
    acceptance_encrypted_object_stream_pdf_for_test(),
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    bytes,
  )
  guard strict is Err(_) else {
    fail("expected bad startxref to require malformed reconstruction")
  }
  let partial = @pdflite.pdf_read_document_from_bytes(bytes)
  @test.assert_eq(partial.first_xref(), 0)
  @test.assert_eq(partial.lookup_object_or_null(2), PdfNull)
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      bytes,
      owner_password=Some(acceptance_ascii_for_test("owner")),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  acceptance_assert_decrypted_object_stream_payload_for_test(decrypted, [
    PdfNoCopy,
  ])
}

///|
test "native acceptance suite decrypts object streams with blank user password" {
  let bytes = acceptance_encrypted_object_stream_pdf_with_passwords_for_test(
    acceptance_ascii_for_test(""),
    acceptance_ascii_for_test("owner"),
    [PdfNoCopy],
  )
  let default_decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(bytes),
  )
  acceptance_assert_decrypted_object_stream_payload_for_test(
    default_decrypted,
    [PdfNoCopy],
  )
  let owner_decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      bytes,
      owner_password=Some(acceptance_ascii_for_test("owner")),
    ),
  )
  acceptance_assert_decrypted_object_stream_payload_for_test(owner_decrypted, [
    PdfNoCopy,
  ])
}

///|
test "native acceptance suite recrypts non-stream encrypted object-stream payloads" {
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let bytes = acceptance_encrypted_object_stream_pdf_for_test()
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      bytes,
      owner_password=Some(owner_password),
    ),
  )
  acceptance_assert_decrypted_object_stream_payload_for_test(decrypted, [
    PdfNoCopy,
  ])
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("object-stream-recrypt-added"),
  )
  decrypted.document.add_object_given_number(6, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 16)
    },
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rendered,
      acceptance_ascii_for_test("encrypted object stream"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(user_password),
    ),
  )
  acceptance_assert_decrypted_object_stream_payload_for_test(roundtrip, [
    PdfNoCopy,
  ])
  @test.assert_eq(roundtrip.document.lookup_object_or_null(6), added_object)
}

///|
test "native acceptance suite reconstructs omitted page-tree xrefs" {
  let bytes = acceptance_pdf_with_omitted_page_tree_xrefs_for_test()
  let parsed = try! @pdflite.pdf_read_document_from_bytes(bytes)
  acceptance_assert_minimal_page_tree_for_test(parsed)
  let password_wrapper = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(bytes),
  )
  @test.assert_eq(password_wrapper.denied_permissions, [])
  acceptance_assert_minimal_page_tree_for_test(password_wrapper.document)
  let normalized = try! @pdflite.pdf_write_document(parsed)
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(normalized)
  acceptance_assert_minimal_page_tree_for_test(reparsed)
}

///|
test "native acceptance suite normalizes tolerated malformed classic xrefs" {
  let bytes = acceptance_pdf_with_tolerated_malformed_xref_for_test()
  let strict = try! @pdflite.pdf_read_classic_document_from_bytes(bytes)
  @test.assert_eq(strict.first_xref() > 0, true)
  acceptance_assert_minimal_page_tree_for_test(strict)
  let parsed = try! @pdflite.pdf_read_document_from_bytes(bytes)
  @test.assert_eq(parsed.first_xref() > 0, true)
  acceptance_assert_minimal_page_tree_for_test(parsed)
  let normalized = try! @pdflite.pdf_write_document(parsed)
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(normalized)
  acceptance_assert_minimal_page_tree_for_test(reparsed)
}

///|
test "native acceptance suite normalizes tokenized and CR-only classic xrefs" {
  let tokenized = acceptance_pdf_with_tokenized_xref_rows_for_test()
  let strict_tokenized = @pdflite.pdf_read_classic_document_from_bytes(
    tokenized,
  )
  @test.assert_eq(strict_tokenized.first_xref() > 0, true)
  acceptance_assert_minimal_page_tree_for_test(strict_tokenized)
  let public_tokenized = @pdflite.pdf_read_document_from_bytes(tokenized)
  @test.assert_eq(public_tokenized.first_xref() > 0, true)
  acceptance_assert_minimal_page_tree_for_test(public_tokenized)

  let cr_only = acceptance_cr_line_endings_for_test(tokenized)
  let strict_cr = @pdflite.pdf_read_classic_document_from_bytes(cr_only)
  @test.assert_eq(strict_cr.first_xref() > 0, true)
  acceptance_assert_minimal_page_tree_for_test(strict_cr)
  let public_cr = @pdflite.pdf_read_document_from_bytes(cr_only)
  @test.assert_eq(public_cr.first_xref() > 0, true)
  acceptance_assert_minimal_page_tree_for_test(public_cr)

  let normalized = @pdflite.pdf_write_document(public_cr)
  let reparsed = @pdflite.pdf_read_document_from_bytes(normalized)
  acceptance_assert_minimal_page_tree_for_test(reparsed)
}

///|
test "native acceptance suite reconstructs malformed feature-rich classic documents" {
  let bytes = @pdflite.pdf_write_document(
    acceptance_document_feature_lifecycle_document_for_test(),
  )
  let corrupted = acceptance_corrupt_first_in_use_xref_offset_for_test(bytes)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected corrupted xref offset to require reconstruction")
  }
  let parsed = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(parsed.first_xref(), 0)
  acceptance_assert_one_page_invariants_for_test(parsed, (1, 4))
  let changed = parsed.change_pages(
    parsed.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @pdflite.transform_translate(5.0, -6.0))],
  )
  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    changed,
  )
  let reparsed = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_one_page_invariants_for_test(reparsed, (1, 5))
  acceptance_assert_document_feature_lifecycle_for_test(reparsed)
}

///|
test "native acceptance suite merges and extracts pages through reader boundaries" {
  let first = try! acceptance_one_page_document_for_test()
  let second = try! acceptance_one_page_document_for_test()
  second.set_version(1, 7)
  let merged = try! @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  @test.assert_eq(merged.version(), (1, 7))
  acceptance_assert_pages_have_hello_content_for_test(merged, 2)
  let merged_bytes = try! @pdflite.pdf_write_document_with_compressed_xref_stream(
    merged,
  )
  let parsed = try! @pdflite.pdf_read_document_from_bytes(merged_bytes)
  @test.assert_eq(parsed.version(), (1, 7))
  acceptance_assert_pages_have_hello_content_for_test(parsed, 2)
  let extracted = try! parsed.pdf_of_pages([2, 1])
  let extracted_bytes = try! @pdflite.pdf_write_document(extracted)
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(extracted_bytes)
  acceptance_assert_pages_have_hello_content_for_test(reparsed, 2)
  let page_refs = try! reparsed.page_reference_numbers()
  @test.assert_eq(page_refs.length(), 2)
  @test.assert_eq(page_refs[0] != page_refs[1], true)
}

///|
test "native acceptance suite runs pdfmergeexample manual merge workflow" {
  let first = acceptance_compressed_roundtrip_for_test(
    acceptance_pdfmergeexample_document_for_test("manual-first", 4, 88),
  )
  let second = acceptance_compressed_roundtrip_for_test(
    acceptance_pdfmergeexample_document_for_test("manual-second", 7, 89),
  )
  let merged = acceptance_pdfmergeexample_workflow_for_test([first, second])
  @test.assert_eq(merged.version(), (1, 7))
  acceptance_assert_text_pages_for_test(merged, [
    "manual-first", "manual-second",
  ])
  @test.assert_eq(
    acceptance_document_contains_object_for_test(
      merged,
      PdfString(acceptance_ascii_for_test("detached-manual-first")),
    ),
    false,
  )
  @test.assert_eq(
    acceptance_document_contains_object_for_test(
      merged,
      PdfString(acceptance_ascii_for_test("detached-manual-second")),
    ),
    false,
  )
  let reparsed = acceptance_compressed_roundtrip_for_test(merged)
  @test.assert_eq(reparsed.version(), (1, 7))
  acceptance_assert_text_pages_for_test(reparsed, [
    "manual-first", "manual-second",
  ])
  let page_refs = reparsed.page_reference_numbers()
  @test.assert_eq(page_refs.length(), 2)
  @test.assert_eq(page_refs[0] != page_refs[1], true)
}

///|
test "native acceptance suite preserves labels and bookmarks across merge boundary" {
  let first = acceptance_labelled_bookmarked_document_for_test(
    "A-",
    "First",
    PageLabelDecimalArabic,
    1,
  )
  let second = acceptance_labelled_bookmarked_document_for_test(
    "B-",
    "Second",
    PageLabelLowercaseRoman,
    4,
  )
  let expected_labels = @pdflite.pdf_page_label_merge([first, second], [
    [1],
    [1],
  ])
  let merged = @pdflite.pdf_merge_documents(
    [first, second],
    [[1], [1]],
    retain_numbering=true,
  )
  @test.assert_eq(merged.read_page_labels(), expected_labels)
  acceptance_assert_bookmarks_target_pages_for_test(merged, "First", "Second")
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(merged)
  let reparsed = @pdflite.pdf_read_document_from_bytes(rendered)
  @test.assert_eq(reparsed.read_page_labels(), expected_labels)
  acceptance_assert_bookmarks_target_pages_for_test(reparsed, "First", "Second")
}

///|
test "native acceptance suite merges catalog feature lifecycle" {
  let first = acceptance_compressed_roundtrip_for_test(
    acceptance_catalog_merge_document_for_test(
      "first-field", "first-title", 90, false,
    ),
  )
  let second = acceptance_compressed_roundtrip_for_test(
    acceptance_catalog_merge_document_for_test(
      "second-field", "second-title", 90, true,
    ),
  )
  let merged = @pdflite.pdf_merge_documents([first, second], [[1], [1]])
  let reparsed = acceptance_compressed_roundtrip_for_test(merged)
  acceptance_assert_catalog_merge_lifecycle_for_test(reparsed)
}

///|
test "native acceptance suite extracts pages with structure tree pruning" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_structure_extraction_document_for_test(),
  )
  @test.assert_eq(parsed.endpage(), 2)
  let extracted = parsed.pdf_of_pages([1], process_struct_tree=true)
  acceptance_assert_structure_extraction_for_test(extracted)
  let reparsed = acceptance_compressed_roundtrip_for_test(extracted)
  acceptance_assert_structure_extraction_for_test(reparsed)
}

///|
test "native acceptance suite runs page resource lifecycle workflow" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_resource_lifecycle_document_for_test(),
  )
  acceptance_process_resource_lifecycle_forms_for_test(parsed)
  parsed.add_prefix("p")
  acceptance_assert_resource_lifecycle_prefixed_for_test(parsed)
  let prefixed_pages = parsed.pages_of_pagetree()
  let renumbered_pages = parsed.renumber_pages([
    prefixed_pages[0],
    prefixed_pages[0],
  ])
  let changed = parsed.change_pages(renumbered_pages)
  let reparsed = acceptance_compressed_roundtrip_for_test(changed)
  acceptance_assert_resource_lifecycle_renumbered_for_test(reparsed)
}

///|
test "native acceptance suite changes resource-heavy pages with mixed references" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_resource_heavy_change_pages_document_for_test(),
  )
  let pages = parsed.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let changed = parsed.change_pages(
    [
      {
        ..pages[0],
        content: [
          @pdflite.pdf_content_stream_of_ops(
            acceptance_change_pages_resource_ops_for_test("After"),
          ),
        ],
      },
    ],
    change_references=true,
    matrices=[(1, @pdflite.transform_translate(10.0, 20.0))],
  )
  let reparsed = acceptance_compressed_roundtrip_for_test(changed)
  acceptance_assert_resource_heavy_change_pages_for_test(reparsed)
}

///|
test "native acceptance suite changes inherited pages with indirect actions" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_inherited_change_pages_document_for_test(),
  )
  let pages = parsed.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let changed = parsed.change_pages(
    [
      {
        ..pages[0],
        content: [
          @pdflite.pdf_content_stream_of_ops(
            acceptance_change_pages_resource_ops_for_test("InheritedAfter"),
          ),
        ],
      },
    ],
    change_references=true,
    matrices=[(1, @pdflite.transform_translate(10.0, 20.0))],
  )
  let reparsed = acceptance_compressed_roundtrip_for_test(changed)
  acceptance_assert_inherited_change_pages_for_test(reparsed)
}

///|
test "native acceptance suite runs pdfdecomp stream decompression workflow" {
  let source = @pdflite.pdf_write_document_with_xref_stream(
    acceptance_one_page_document_for_test(),
  )
  let parsed = @pdflite.pdf_read_document_from_bytes(source)
  acceptance_assert_one_page_invariants_for_test(parsed, (1, 5))
  parsed.pdf_decode_streams_until_unknown()
  acceptance_assert_decompressed_partial_filter_stream_for_test(parsed)
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(parsed)
  let reparsed = @pdflite.pdf_read_document_from_bytes(rendered)
  acceptance_assert_one_page_invariants_for_test(reparsed, (1, 5))
  acceptance_assert_decompressed_partial_filter_stream_for_test(reparsed)
}

///|
test "native acceptance suite runs pdftest content rewrite workflow" {
  let source = acceptance_split_content_document_for_test()
  let bytes = @pdflite.pdf_write_document_with_xref_stream(source)
  let parsed = @pdflite.pdf_read_document_from_bytes(bytes)
  let source_pages = parsed.pages_of_pagetree()
  @test.assert_eq(source_pages.length(), 1)
  @test.assert_eq(source_pages[0].content.length(), 2)
  @test.assert_eq(
    parsed.parse_content_ops(source_pages[0].content),
    acceptance_one_page_ops_for_test(),
  )
  let rewritten = acceptance_pdftest_rewrite_document_for_test(parsed)
  acceptance_assert_pdftest_rewrite_for_test(rewritten)
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    rewritten,
  )
  let reparsed = @pdflite.pdf_read_document_from_bytes(rendered)
  acceptance_assert_pdftest_rewrite_for_test(reparsed)
}

///|
test "native acceptance suite runs pdfdraft image replacement workflow" {
  let drafted = acceptance_draft_document_for_test(
    acceptance_draft_source_document_for_test(),
  )
  acceptance_assert_drafted_document_for_test(drafted)
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    drafted,
  )
  let reparsed = @pdflite.pdf_read_document_from_bytes(rendered)
  acceptance_assert_drafted_document_for_test(reparsed)
}

///|
test "native acceptance suite changes pages after compressed reader boundary" {
  let doc = try! acceptance_one_page_document_for_test()
  let old_numbers = try! doc.page_reference_numbers()
  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: acceptance_ascii_for_test("Acceptance"),
      target: DestXYZ(
        TargetPageObject(old_numbers[0]),
        Some(12.0),
        Some(34.0),
        None,
      ),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let bytes = try! @pdflite.pdf_write_document_with_compressed_xref_stream(
    bookmarked,
  )
  let parsed = try! @pdflite.pdf_read_document_from_bytes(bytes)
  acceptance_assert_one_page_invariants_for_test(parsed, (1, 5))
  let changed = try! parsed.change_pages(
    try! parsed.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @pdflite.transform_translate(5.0, -6.0))],
  )
  let rewritten = try! @pdflite.pdf_write_document(changed)
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_one_page_invariants_for_test(reparsed, (1, 5))
  let new_numbers = try! reparsed.page_reference_numbers()
  @test.assert_eq(try! reparsed.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: acceptance_ascii_for_test("Acceptance"),
      target: DestXYZ(
        TargetPageObject(new_numbers[0]),
        Some(17.0),
        Some(28.0),
        None,
      ),
      is_open: false,
      colour: @pdflite.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
test "native acceptance suite changes page count with explicit reference mapping" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_count_change_document_for_test(),
  )
  @test.assert_eq(parsed.endpage(), 2)
  let changed = parsed.change_pages(
    [acceptance_count_change_replacement_page_for_test()],
    change_references=true,
    changes=[(2, 1)],
    matrices=[(1, @pdflite.transform_translate(10.0, 20.0))],
  )
  acceptance_assert_count_changed_document_for_test(changed)
  let reparsed = acceptance_compressed_roundtrip_for_test(changed)
  acceptance_assert_count_changed_document_for_test(reparsed)
}

///|
test "native acceptance suite extracts reused annotations with repaired links" {
  let parsed = acceptance_compressed_roundtrip_for_test(
    acceptance_reused_annotation_document_for_test(),
  )
  @test.assert_eq(parsed.endpage(), 2)
  let extracted = parsed.pdf_of_pages([1, 2])
  acceptance_assert_extracted_reused_annotations_for_test(extracted)
  let reparsed = acceptance_compressed_roundtrip_for_test(extracted)
  acceptance_assert_extracted_reused_annotations_for_test(reparsed)
}

///|
test "native acceptance suite preserves document feature lifecycle" {
  let bytes = @pdflite.pdf_write_document_with_compressed_xref_stream(
    acceptance_document_feature_lifecycle_document_for_test(),
  )
  let parsed = @pdflite.pdf_read_document_from_bytes(bytes)
  acceptance_assert_one_page_invariants_for_test(parsed, (1, 5))
  let changed = parsed.change_pages(
    parsed.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @pdflite.transform_translate(5.0, -6.0))],
  )
  let rewritten = @pdflite.pdf_write_document(changed)
  let reparsed = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_one_page_invariants_for_test(reparsed, (1, 5))
  acceptance_assert_document_feature_lifecycle_for_test(reparsed)
}

///|
test "native acceptance suite reads encrypted AES128 documents through public wrapper" {
  let doc = try! acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test("native-acceptance-secret")
  doc.add_object_given_number(60, secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoEdit, PdfNoPrint]
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    acceptance_ascii_for_test("user"),
    acceptance_ascii_for_test("owner"),
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-id"),
  )
  let rendered = try! @pdflite.pdf_write_document(encrypted)
  let user_decrypted = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(acceptance_ascii_for_test("user")),
    ),
  )
  @test.assert_eq(user_decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(
    user_decrypted.document,
    (1, 4),
  )
  @test.assert_eq(user_decrypted.document.lookup_object_or_null(60), secret)
  let owner_decrypted = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      owner_password=Some(acceptance_ascii_for_test("owner")),
    ),
  )
  @test.assert_eq(owner_decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(
    owner_decrypted.document,
    (1, 4),
  )
  @test.assert_eq(owner_decrypted.document.lookup_object_or_null(60), secret)
}

///|
test "native acceptance suite preserves unencrypted metadata through AES recrypt" {
  let metadata = acceptance_metadata_bytes_for_test()
  let secret = acceptance_secret_object_for_test("metadata-encrypted-secret")
  let input = acceptance_metadata_encryption_document_for_test(metadata, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoExtract, PdfNoCopy]
  let rendered = @pdflite.pdf_write_encrypted_aesv2_document_with_iv_provider(
    input,
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 8)
    },
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=acceptance_ascii_for_test("native-metadata-encryption-id"),
  )
  @test.assert_eq(acceptance_find_bytes_for_test(rendered, metadata) >= 0, true)
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rendered,
      acceptance_ascii_for_test("metadata-encrypted-secret"),
    ) <
    0,
    true,
  )
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_metadata_encryption_for_test(
    decrypted.document,
    metadata,
    secret,
  )
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("metadata-added"),
  )
  decrypted.document.add_object_given_number(64, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 12)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(rerendered, metadata) >= 0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_metadata_encryption_for_test(
    roundtrip.document,
    metadata,
    secret,
  )
  @test.assert_eq(roundtrip.document.lookup_object_or_null(64), added_object)
}

///|
test "native acceptance suite runs pdfencrypt owner-password workflow" {
  let input = acceptance_one_page_document_for_test()
  let user_password = acceptance_ascii_for_test("")
  let owner_password = acceptance_ascii_for_test("owner-password")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoEdit, PdfNoPrint]
  let encrypted = @pdflite.pdf_write_encrypted_aesv2_document_with_iv_provider(
    input,
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=false,
    mode=PdfWriteClassic,
    file_id=acceptance_ascii_for_test("native-acceptance-pdfencrypt-id"),
  )
  let default_decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(encrypted),
  )
  @test.assert_eq(default_decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(
    default_decrypted.document,
    (1, 4),
  )
  let user_decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      encrypted,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(user_decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(
    user_decrypted.document,
    (1, 4),
  )
  let owner_decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      encrypted,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(owner_decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(
    owner_decrypted.document,
    (1, 4),
  )
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed trailers" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-malformed-trailer-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 21)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-malformed-trailer-id"),
  )
  let rendered = @pdflite.pdf_write_document(encrypted)
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("trailer\n"),
    "trailer\n1\n",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected malformed trailer to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 4))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-trailer-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 22)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-malformed-trailer-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed encrypted missing-root trailers" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-missing-root-trailer-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 23)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-missing-root-trailer-id",
    ),
  )
  let rendered = @pdflite.pdf_write_document(encrypted)
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("trailer\n"),
    "trailer\n<< /Size 999 >>\n",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected missing-root trailer to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 4))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("missing-root-trailer-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 24)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-missing-root-trailer-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed encrypted catalogs missing from xref" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-catalog-missing-xref-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 25)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-catalog-missing-xref-id",
    ),
  )
  let root_number = encrypted.root()
  let rendered = @pdflite.pdf_write_document(encrypted)
  let malformed = acceptance_mark_classic_xref_entry_free_for_test(
    rendered, root_number,
  )
  let strict = @pdflite.pdf_read_classic_document_from_bytes(malformed)
  @test.assert_eq(strict.root(), root_number)
  let strict_catalog : Result[@pdflite.PdfObject, Error] = try? strict.catalog()
  guard strict_catalog is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected missing root object to require reconstruction")
  }
  @test.assert_eq(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      user_password=Some(acceptance_ascii_for_test("bad-user")),
    ),
    None,
  )
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 4))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("catalog-missing-xref-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 26)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-catalog-missing-xref-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed encrypted page trees missing from xref" {
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 4)
  doc.set_root(1)
  doc.set_trailer_dict(
    @pdflite.pdf_dictionary([
      (acceptance_name_for_test("/Root"), PdfIndirect(1)),
    ]),
  )
  doc.add_object_given_number(
    1,
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/Catalog")),
      ),
      (acceptance_name_for_test("/Pages"), PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/Pages")),
      ),
      (acceptance_name_for_test("/Kids"), PdfArray([PdfIndirect(3)])),
      (acceptance_name_for_test("/Count"), PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    3,
    @pdflite.pdf_dictionary([
      (
        acceptance_name_for_test("/Type"),
        PdfNameObject(acceptance_name_for_test("/Page")),
      ),
      (acceptance_name_for_test("/Parent"), PdfIndirect(2)),
      (
        acceptance_name_for_test("/MediaBox"),
        PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(10), PdfInteger(10)]),
      ),
    ]),
  )
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-page-tree-missing-xref-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 27)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-page-tree-missing-xref-id",
    ),
  )
  let encrypt_object_number = match
    encrypted
    .trailer_dict()
    .lookup_immediate(acceptance_name_for_test("/Encrypt")) {
    Some(PdfIndirect(number)) => number
    _ => fail("expected encryption object reference")
  }
  let rendered = @pdflite.pdf_write_document(encrypted)
  let malformed = acceptance_keep_catalog_and_encrypt_xref_entries_for_test(
    rendered, encrypt_object_number,
  )
  let strict = @pdflite.pdf_read_classic_document_from_bytes(malformed)
  @test.assert_eq(strict.root(), 1)
  @test.assert_eq(strict.object_numbers(), [1, encrypt_object_number])
  let strict_pages : Result[Int, Error] = try? strict.endpage()
  guard strict_pages is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected missing page tree to require reconstruction")
  }
  @test.assert_eq(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      user_password=Some(acceptance_ascii_for_test("bad-user")),
    ),
    None,
  )
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  @test.assert_eq(decrypted.document.root(), 1)
  @test.assert_eq(try! decrypted.document.endpage(), 1)
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("page-tree-missing-xref-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 28)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test(
        "native-acceptance-page-tree-missing-xref-secret",
      ),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.root(), 1)
  @test.assert_eq(try! roundtrip.document.endpage(), 1)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed malformed xref documents" {
  let doc = try! acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-reconstructed-secret",
  )
  doc.add_object_given_number(60, secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    acceptance_ascii_for_test("user"),
    acceptance_ascii_for_test("owner"),
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 3)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-malformed-id"),
  )
  let rendered = try! @pdflite.pdf_write_document(encrypted)
  let corrupted = try! acceptance_corrupt_first_in_use_xref_offset_for_test(
    rendered,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected corrupted xref to require malformed reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      corrupted,
      user_password=Some(acceptance_ascii_for_test("user")),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 4))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed xref markers" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-marker-secret",
  )
  doc.add_object_given_number(60, secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let user_password = acceptance_ascii_for_test("user")
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    acceptance_ascii_for_test("owner"),
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 11)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-xref-marker-id"),
  )
  let rendered = @pdflite.pdf_write_document(encrypted)
  let corrupted = acceptance_corrupt_first_in_use_xref_marker_for_test(rendered)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref marker to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      corrupted,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 4))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed xref subsections" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-subsection-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 12)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-bad-xref-subsection-id",
    ),
  )
  let rendered = @pdflite.pdf_write_document(encrypted)
  let corrupted = acceptance_corrupt_first_xref_subsection_count_for_test(
    rendered,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected malformed xref subsection to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      corrupted,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 4))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-xref-subsection-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 13)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-xref-subsection-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed xref-stream metadata" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-index-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 14)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-bad-xref-stream-id"),
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/W ["),
    "/Index [0] ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref stream metadata to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 5))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-xref-stream-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 15)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-xref-stream-index-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed xref-stream widths" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-width-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 16)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-bad-xref-stream-width-id",
    ),
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/W ["),
    "/W [1 4] ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref stream widths to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 5))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-xref-stream-width-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 17)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-xref-stream-width-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed xref-stream size" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-size-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 18)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-bad-xref-stream-size-id",
    ),
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/Size "),
    "/Size /Bad ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref stream size to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 5))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-xref-stream-size-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 19)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-xref-stream-size-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite reconstructs malformed xref-stream filters" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-filter-secret",
  )
  doc.add_object_given_number(60, secret)
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(doc)
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/Filter "),
    "/Filter /BadXRefFilter ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::FilterNotSupported(filter)) else {
    fail("expected malformed xref stream filter to require reconstruction")
  }
  @test.assert_eq(filter, acceptance_name_for_test("/BadXRefFilter"))
  let recovered = @pdflite.pdf_read_document_from_bytes(malformed)
  @test.assert_eq(recovered.first_xref(), 0)
  acceptance_assert_one_page_invariants_for_test(recovered, (1, 5))
  @test.assert_eq(recovered.lookup_object_or_null(60), secret)
  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered,
  )
  let roundtrip = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_one_page_invariants_for_test(roundtrip, (1, 5))
  @test.assert_eq(roundtrip.lookup_object_or_null(60), secret)
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed xref-stream filters" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-filter-encrypted-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 20)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-bad-xref-stream-filter-id",
    ),
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/Filter "),
    "/Filter /BadXRefFilter ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::FilterNotSupported(filter)) else {
    fail("expected malformed xref stream filter to require reconstruction")
  }
  @test.assert_eq(filter, acceptance_name_for_test("/BadXRefFilter"))
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 5))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-xref-stream-filter-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 21)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test(
        "native-acceptance-xref-stream-filter-encrypted-secret",
      ),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite reconstructs malformed xref-stream decodeparms" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-decodeparms-secret",
  )
  doc.add_object_given_number(60, secret)
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(doc)
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/Filter "),
    "/DecodeParms /Bad ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected malformed xref stream DecodeParms to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(malformed)
  @test.assert_eq(recovered.first_xref(), 0)
  acceptance_assert_one_page_invariants_for_test(recovered, (1, 5))
  @test.assert_eq(recovered.lookup_object_or_null(60), secret)
  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered,
  )
  let roundtrip = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_one_page_invariants_for_test(roundtrip, (1, 5))
  @test.assert_eq(roundtrip.lookup_object_or_null(60), secret)
}

///|
test "native acceptance suite reconstructs xref-stream unsupported predictor decodeparms" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-unsupported-predictor-secret",
  )
  doc.add_object_given_number(60, secret)
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(doc)
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/Filter "),
    "/DecodeParms << /Predictor 9 >> ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::PredictorNotSupported(predictor)) else {
    fail("expected unsupported xref stream DecodeParms predictor")
  }
  @test.assert_eq(predictor, 9)
  let recovered = @pdflite.pdf_read_document_from_bytes(malformed)
  @test.assert_eq(recovered.first_xref(), 0)
  acceptance_assert_one_page_invariants_for_test(recovered, (1, 5))
  @test.assert_eq(recovered.lookup_object_or_null(60), secret)
  let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered,
  )
  let roundtrip = @pdflite.pdf_read_document_from_bytes(rewritten)
  acceptance_assert_one_page_invariants_for_test(roundtrip, (1, 5))
  @test.assert_eq(roundtrip.lookup_object_or_null(60), secret)
}

///|
test "native acceptance suite decrypts reconstructed encrypted malformed xref-stream decodeparms" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-decodeparms-encrypted-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 22)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-bad-xref-decodeparms-id"),
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/Filter "),
    "/DecodeParms /Bad ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected malformed xref stream DecodeParms to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 5))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-xref-stream-decodeparms-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 23)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test(
        "native-acceptance-xref-stream-decodeparms-encrypted-secret",
      ),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite decrypts reconstructed encrypted xref-stream unsupported predictor" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-xref-stream-unsupported-predictor-encrypted-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 24)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-bad-xref-predictor-id"),
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    encrypted,
  )
  let malformed = acceptance_insert_ascii_before_last_marker_for_test(
    rendered,
    acceptance_ascii_for_test("/Filter "),
    "/DecodeParms << /Predictor 9 >> ",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    malformed,
  )
  guard strict is Err(@pdflite.PdfError::PredictorNotSupported(predictor)) else {
    fail("expected unsupported encrypted xref stream DecodeParms predictor")
  }
  @test.assert_eq(predictor, 9)
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      malformed,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 5))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("xref-stream-unsupported-predictor-recrypt-added"),
  )
  decrypted.document.add_object_given_number(62, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 25)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test(
        "native-acceptance-xref-stream-unsupported-predictor-encrypted-secret",
      ),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(62), added_object)
}

///|
test "native acceptance suite recrypts reconstructed bad-startxref encrypted documents" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-bad-startxref-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoPrint]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 20)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-bad-startxref-id"),
  )
  let rendered = @pdflite.pdf_write_document(encrypted)
  let corrupted = acceptance_corrupt_startxref_pointer_for_test(rendered)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected bad startxref to require malformed reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      corrupted,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_pages_have_hello_content_for_test(decrypted.document, 1)
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)
  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("bad-startxref-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 24)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-bad-startxref-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_pages_have_hello_content_for_test(roundtrip.document, 1)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite reconstructs compressed encrypted documents with bad startxref" {
  let doc = acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test(
    "native-acceptance-compressed-encrypted-secret",
  )
  doc.add_object_given_number(60, secret)
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy, PdfNoPrint]
  let rendered = @pdflite.pdf_write_encrypted_aesv2_document_with_iv_provider(
    doc,
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 28)
    },
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=acceptance_ascii_for_test(
      "native-acceptance-compressed-encrypted-id",
    ),
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rendered,
      acceptance_ascii_for_test("native-acceptance-compressed-encrypted-secret"),
    ) <
    0,
    true,
  )
  let corrupted = acceptance_corrupt_startxref_pointer_for_test(rendered)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected bad compressed xref startxref to require reconstruction")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      corrupted,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(decrypted.document.first_xref(), 0)
  @test.assert_eq(decrypted.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(decrypted.document, (1, 5))
  @test.assert_eq(decrypted.document.lookup_object_or_null(60), secret)

  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("compressed-encrypted-recrypt-added"),
  )
  decrypted.document.add_object_given_number(61, added_object)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 29)
    },
  )
  let rerendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rerendered,
      acceptance_ascii_for_test("native-acceptance-compressed-encrypted-secret"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rerendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}

///|
test "native acceptance suite recrypts encrypted incremental revisions" {
  let original_secret = acceptance_secret_object_for_test(
    "native-acceptance-original",
  )
  let updated_secret = acceptance_secret_object_for_test(
    "native-acceptance-updated",
  )
  let doc = try! acceptance_one_page_document_for_test()
  doc.add_object_given_number(60, original_secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoEdit, PdfNoPrint]
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    acceptance_ascii_for_test("user"),
    acceptance_ascii_for_test("owner"),
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 1)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-recrypt-id"),
  )
  let original = try! @pdflite.pdf_write_document(encrypted)
  let decrypted = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      original,
      user_password=Some(acceptance_ascii_for_test("user")),
    ),
  )
  decrypted.document.add_object_given_number(60, updated_secret)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    acceptance_ascii_for_test("owner"),
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 2)
    },
  )
  let updated = try! @pdflite.pdf_write_document_incremental_update(
    original, recrypted,
  )
  @test.assert_eq(try! @pdflite.pdf_revisions_from_bytes(updated), 2)
  let newest = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_revision_from_bytes_with_passwords(
      updated,
      1,
      owner_password=Some(acceptance_ascii_for_test("owner")),
    ),
  )
  @test.assert_eq(newest.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(newest.document, (1, 4))
  @test.assert_eq(newest.document.lookup_object_or_null(60), updated_secret)
  let older = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_revision_from_bytes_with_passwords(
      updated,
      2,
      owner_password=Some(acceptance_ascii_for_test("owner")),
    ),
  )
  @test.assert_eq(older.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(older.document, (1, 4))
  @test.assert_eq(older.document.lookup_object_or_null(60), original_secret)
}

///|
test "native acceptance suite reconstructs encrypted incremental revisions with bad startxref" {
  let original_secret = acceptance_secret_object_for_test(
    "native-acceptance-malformed-original",
  )
  let updated_secret = acceptance_secret_object_for_test(
    "native-acceptance-malformed-updated",
  )
  let user_password = acceptance_ascii_for_test("user")
  let owner_password = acceptance_ascii_for_test("owner")
  let doc = acceptance_one_page_document_for_test()
  doc.add_object_given_number(60, original_secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy, PdfNoEdit]
  let encrypted = doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 30)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-bad-incremental-id"),
  )
  let original = @pdflite.pdf_write_document(encrypted)
  let decrypted = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      original,
      user_password=Some(user_password),
    ),
  )
  decrypted.document.add_object_given_number(60, updated_secret)
  let recrypted = decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 31)
    },
  )
  let updated = @pdflite.pdf_write_document_incremental_update(
    original, recrypted,
  )
  let corrupted = acceptance_corrupt_startxref_pointer_for_test(updated)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected bad startxref to require malformed reconstruction")
  }
  let recovered = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      corrupted,
      owner_password=Some(owner_password),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(recovered.document, (1, 4))
  @test.assert_eq(recovered.document.lookup_object_or_null(60), updated_secret)

  let added_object : @pdflite.PdfObject = PdfString(
    acceptance_ascii_for_test("malformed-incremental-recrypt-added"),
  )
  recovered.document.add_object_given_number(61, added_object)
  let recovered_recrypted = recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 32)
    },
  )
  let rendered = @pdflite.pdf_write_document_with_compressed_xref_stream(
    recovered_recrypted,
  )
  @test.assert_eq(
    acceptance_find_bytes_for_test(
      rendered,
      acceptance_ascii_for_test("native-acceptance-malformed-updated"),
    ) <
    0,
    true,
  )
  let roundtrip = acceptance_unwrap_decryption_for_test(
    @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(user_password),
    ),
  )
  @test.assert_eq(roundtrip.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(roundtrip.document, (1, 5))
  @test.assert_eq(roundtrip.document.lookup_object_or_null(60), updated_secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(61), added_object)
}
