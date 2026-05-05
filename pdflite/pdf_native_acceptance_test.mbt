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
test "native acceptance suite reconstructs omitted page-tree xrefs" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    acceptance_pdf_with_omitted_page_tree_xrefs_for_test(),
  )
  acceptance_assert_minimal_page_tree_for_test(parsed)
  let normalized = try! @pdflite.pdf_write_document(parsed)
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(normalized)
  acceptance_assert_minimal_page_tree_for_test(reparsed)
}

///|
test "native acceptance suite reads encrypted AES128 documents through public wrapper" {
  let doc = try! acceptance_one_page_document_for_test()
  let secret : @pdflite.PdfObject = PdfDictionary([
    (
      acceptance_name_for_test("/Title"),
      PdfString(acceptance_ascii_for_test("native-acceptance-secret")),
    ),
  ])
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
