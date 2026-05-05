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
    extractor.codepoints_of_text(acceptance_ascii_for_test("Hello, World!")[:]),
    [72, 101, 108, 108, 111, 44, 32, 87, 111, 114, 108, 100, 33],
  )
}

///|
fn acceptance_assert_partial_filter_stream_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  let decoded_doc = doc.copy()
  decoded_doc.pdf_decode_streams_until_unknown()
  guard decoded_doc.lookup_object_or_null(50) is PdfStreamObject(stream) else {
    fail("expected partially decoded acceptance stream")
  }
  @test.assert_eq(stream.data, StreamGot(acceptance_ascii_for_test("Hi")))
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
fn acceptance_encrypted_object_stream_pdf_for_test() -> @pdflite.PdfBytes raise {
  let secret = acceptance_secret_object_for_test("encrypted object stream")
  let object_stream_data : Array[Byte] = []
  acceptance_push_ascii_for_test(object_stream_data, "2 0 ")
  let first = object_stream_data.length()
  acceptance_push_view_for_test(
    object_stream_data,
    @pdflite.pdf_write_object(secret)[:],
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
    acceptance_ascii_for_test("user")[:],
    acceptance_ascii_for_test("owner")[:],
    [PdfNoCopy],
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      acceptance_ascii_for_test("object-stream-reader")[:],
    ),
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("object-stream-reader-id")[:],
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
    })[:],
  )
  acceptance_push_byte_for_test(output, 10)
  let object_stream_offset = output.length()
  acceptance_push_view_for_test(
    output,
    @pdflite.pdf_write_indirect_object({
      number: 3,
      generation: 0,
      object: encrypted.lookup_object_or_null(3),
    })[:],
  )
  acceptance_push_byte_for_test(output, 10)
  let encrypt_offset = output.length()
  acceptance_push_view_for_test(
    output,
    @pdflite.pdf_write_indirect_object({
      number: encrypt_number,
      generation: 0,
      object: encrypted.lookup_object_or_null(encrypt_number),
    })[:],
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
    })[:],
  )
  acceptance_push_ascii_for_test(output, "\nstartxref\n")
  acceptance_push_ascii_for_test(output, xref_offset.to_string())
  acceptance_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
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
    owner_password=Some(acceptance_ascii_for_test("bad-owner")[:]),
  )
  guard bad_password is Err(_) else {
    fail("expected bad password to fail encrypted object-stream expansion")
  }
  let decrypted = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      bytes,
      owner_password=Some(acceptance_ascii_for_test("owner")[:]),
    ),
  )
  @test.assert_eq(decrypted.denied_permissions, [PdfNoCopy])
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
test "native acceptance suite reads encrypted AES128 documents through public wrapper" {
  let doc = try! acceptance_one_page_document_for_test()
  let secret = acceptance_secret_object_for_test("native-acceptance-secret")
  doc.add_object_given_number(60, secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoEdit, PdfNoPrint]
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    acceptance_ascii_for_test("user")[:],
    acceptance_ascii_for_test("owner")[:],
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-id")[:],
  )
  let rendered = try! @pdflite.pdf_write_document(encrypted)
  let user_decrypted = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      rendered,
      user_password=Some(acceptance_ascii_for_test("user")[:]),
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
      owner_password=Some(acceptance_ascii_for_test("owner")[:]),
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
    acceptance_ascii_for_test("user")[:],
    acceptance_ascii_for_test("owner")[:],
    denied,
    fn(object_number, generation, index) {
      acceptance_aes_iv_for_test(object_number, generation, index + 1)
    },
    encrypt_metadata=false,
    file_id=acceptance_ascii_for_test("native-acceptance-recrypt-id")[:],
  )
  let original = try! @pdflite.pdf_write_document(encrypted)
  let decrypted = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_from_bytes_with_passwords(
      original,
      user_password=Some(acceptance_ascii_for_test("user")[:]),
    ),
  )
  decrypted.document.add_object_given_number(60, updated_secret)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    acceptance_ascii_for_test("owner")[:],
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
      owner_password=Some(acceptance_ascii_for_test("owner")[:]),
    ),
  )
  @test.assert_eq(newest.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(newest.document, (1, 4))
  @test.assert_eq(newest.document.lookup_object_or_null(60), updated_secret)
  let older = acceptance_unwrap_decryption_for_test(
    try! @pdflite.pdf_read_document_revision_from_bytes_with_passwords(
      updated,
      2,
      owner_password=Some(acceptance_ascii_for_test("owner")[:]),
    ),
  )
  @test.assert_eq(older.denied_permissions, denied)
  acceptance_assert_one_page_invariants_for_test(older.document, (1, 4))
  @test.assert_eq(older.document.lookup_object_or_null(60), original_secret)
}
