///|
async fn pdf_async_io_remove_if_exists_for_test(path : String) -> Unit {
  if @fs.exists(path) {
    @fs.remove(path)
  }
}

///|
fn pdf_async_io_assert_generated_id_for_test(
  id : @pdflite.PdfObject?,
) -> Unit raise {
  guard id is Some(PdfArray([PdfString(first), PdfString(second)])) else {
    fail("expected generated trailer ID")
  }
  @test.assert_eq(first.length(), 16)
  @test.assert_eq(second, first)
}

///|
fn pdf_async_io_test_path_for_test(name : String) -> String {
  let directory = match @env.current_dir() {
    Some(current_dir) => current_dir + "/_build/"
    None => "_build/"
  }
  directory + "pdflite_async_io_" + name + "_" + @env.now().to_string() + ".pdf"
}

///|
fn pdf_async_io_repo_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
fn pdf_async_io_bytes_start_with_at_for_test(
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
fn pdf_async_io_find_bytes_for_test(
  haystack : BytesView,
  needle : BytesView,
) -> Int {
  if needle.length() == 0 {
    0
  } else if haystack.length() < needle.length() {
    -1
  } else {
    for start in 0..<=(haystack.length() - needle.length()) {
      if pdf_async_io_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn pdf_async_io_find_last_bytes_for_test(
  haystack : BytesView,
  needle : BytesView,
) -> Int {
  if needle.length() == 0 {
    0
  } else if haystack.length() < needle.length() {
    -1
  } else {
    let mut found = -1
    for start in 0..<=(haystack.length() - needle.length()) {
      if pdf_async_io_bytes_start_with_at_for_test(haystack, needle, start) {
        found = start
      }
    }
    found
  }
}

///|
fn pdf_async_io_push_ascii_for_test(
  output : Array[Byte],
  text : String,
) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn pdf_async_io_is_pdf_whitespace_for_test(byte : Byte) -> Bool {
  match byte.to_int() {
    0 | 9 | 10 | 12 | 13 | 32 => true
    _ => false
  }
}

///|
fn pdf_async_io_corrupt_startxref_pointer_at_for_test(
  bytes : @pdflite.PdfBytes,
  marker_position : Int,
) -> @pdflite.PdfBytes raise {
  let marker = @ascii.encode("startxref")
  if marker_position < 0 {
    fail("expected startxref marker")
  }
  let mut number_start = marker_position + marker.length()
  while number_start < bytes.length() &&
        pdf_async_io_is_pdf_whitespace_for_test(bytes[number_start]) {
    number_start += 1
  }
  let mut number_end = number_start
  while number_end < bytes.length() &&
        !pdf_async_io_is_pdf_whitespace_for_test(bytes[number_end]) {
    number_end += 1
  }
  let output : Array[Byte] = []
  for index in 0..<number_start {
    output.push(bytes[index])
  }
  pdf_async_io_push_ascii_for_test(output, (bytes.length() + 4096).to_string())
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn pdf_async_io_corrupt_first_in_use_xref_offset_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes raise {
  let free_row = @ascii.encode("0000000000 65535 f \n")
  let free_row_position = pdf_async_io_find_bytes_for_test(bytes, free_row)
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
fn pdf_async_io_corrupt_first_in_use_xref_marker_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes raise {
  let free_row = @ascii.encode("0000000000 65535 f \n")
  let free_row_position = pdf_async_io_find_bytes_for_test(bytes, free_row)
  if free_row_position < 0 {
    fail("expected classic xref free row")
  }
  let marker_position = free_row_position + free_row.length() + 17
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
fn pdf_async_io_corrupt_first_xref_subsection_count_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes raise {
  let header = @ascii.encode("xref\n0 ")
  let header_position = pdf_async_io_find_bytes_for_test(bytes, header)
  if header_position < 0 {
    fail("expected first classic xref subsection header")
  }
  let count_start = header_position + header.length()
  let mut count_end = count_start
  while count_end < bytes.length() &&
        !pdf_async_io_is_pdf_whitespace_for_test(bytes[count_end]) {
    count_end += 1
  }
  if count_end == count_start {
    fail("expected first classic xref subsection count")
  }
  let output : Array[Byte] = []
  for index in 0..<count_start {
    output.push(bytes[index])
  }
  pdf_async_io_push_ascii_for_test(output, "/Bad")
  for index in count_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn pdf_async_io_corrupt_startxref_pointer_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes raise {
  let marker = @ascii.encode("startxref")
  pdf_async_io_corrupt_startxref_pointer_at_for_test(
    bytes,
    pdf_async_io_find_bytes_for_test(bytes, marker),
  )
}

///|
fn pdf_async_io_corrupt_final_startxref_pointer_for_test(
  bytes : @pdflite.PdfBytes,
) -> @pdflite.PdfBytes raise {
  let marker = @ascii.encode("startxref")
  pdf_async_io_corrupt_startxref_pointer_at_for_test(
    bytes,
    pdf_async_io_find_last_bytes_for_test(bytes, marker),
  )
}

///|
fn pdf_async_io_insert_ascii_before_last_marker_for_test(
  bytes : @pdflite.PdfBytes,
  marker : BytesView,
  insertion : String,
) -> @pdflite.PdfBytes raise {
  let marker_position = pdf_async_io_find_last_bytes_for_test(bytes, marker)
  if marker_position < 0 {
    fail("expected insertion marker")
  }
  let output : Array[Byte] = []
  for index in 0..<marker_position {
    output.push(bytes[index])
  }
  pdf_async_io_push_ascii_for_test(output, insertion)
  for index in marker_position..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn pdf_async_io_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_async_io_ascii_codepoints_for_test(text : String) -> Array[Int] {
  [
    for byte in @ascii.encode(text) => byte.to_int()
  ]
}

///|
fn pdf_async_io_codepoints_contain_for_test(
  haystack : ArrayView[Int],
  needle : ArrayView[Int],
) -> Bool {
  if needle.length() == 0 {
    true
  } else if needle.length() > haystack.length() {
    false
  } else {
    for start in 0..<=(haystack.length() - needle.length()) {
      let mut matched = true
      for offset in 0..<needle.length() {
        if haystack[start + offset] != needle[offset] {
          matched = false
        }
      }
      if matched {
        break true
      }
    } nobreak {
      false
    }
  }
}

///|
fn pdf_async_io_font_resource_for_test(
  doc : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
  font_name : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
  match doc.lookup_direct(pdf_async_io_name_for_test("/Font"), resources) {
    Some(fonts) => doc.lookup_direct(font_name, fonts)
    None => None
  }
}

///|
fn pdf_async_io_push_text_codepoints_for_test(
  output : Array[Int],
  extractor : @pdflite.PdfTextExtractor,
  text : @pdflite.PdfBytes,
) -> Unit raise {
  for codepoint in extractor.codepoints_of_text(text) {
    output.push(codepoint)
  }
}

///|
fn pdf_async_io_page_text_codepoints_for_test(
  doc : @pdflite.PdfDocument,
  page_index : Int,
) -> Array[Int] raise {
  let pages = doc.pages_of_pagetree()
  guard page_index >= 0 && page_index < pages.length() else {
    fail("expected page index inside document")
  }
  let page = pages[page_index]
  let output : Array[Int] = []
  let mut extractor : @pdflite.PdfTextExtractor? = None
  for op in doc.parse_content_ops_with_resources(page.resources, page.content) {
    match op {
      Op_Tf(font_name, _) =>
        match
          pdf_async_io_font_resource_for_test(doc, page.resources, font_name) {
          Some(font) => extractor = Some(doc.text_extractor_of_font(font))
          None => extractor = None
        }
      Op_Tj(text) =>
        match extractor {
          Some(extractor) =>
            pdf_async_io_push_text_codepoints_for_test(output, extractor, text)
          None => ()
        }
      Op_TJ(PdfArray(items)) =>
        match extractor {
          Some(extractor) =>
            for item in items {
              match item {
                PdfString(text) =>
                  pdf_async_io_push_text_codepoints_for_test(
                    output, extractor, text,
                  )
                _ => ()
              }
            }
          None => ()
        }
      Op_quote(text) =>
        match extractor {
          Some(extractor) =>
            pdf_async_io_push_text_codepoints_for_test(output, extractor, text)
          None => ()
        }
      Op_double_quote(_, _, text) =>
        match extractor {
          Some(extractor) =>
            pdf_async_io_push_text_codepoints_for_test(output, extractor, text)
          None => ()
        }
      _ => ()
    }
  }
  output
}

///|
fn pdf_async_io_assert_page_text_contains_for_test(
  doc : @pdflite.PdfDocument,
  page_index : Int,
  fragments : ArrayView[String],
) -> Unit raise {
  let text = pdf_async_io_page_text_codepoints_for_test(doc, page_index)
  for fragment in fragments {
    let matched = pdf_async_io_codepoints_contain_for_test(
      text,
      pdf_async_io_ascii_codepoints_for_test(fragment),
    )
    @test.assert_eq(
      matched,
      true,
      msg="page " + page_index.to_string() + " missing " + fragment,
    )
  }
}

///|
fn pdf_async_io_assert_intro_fixture_text_for_test(
  doc : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(doc.endpage(), 10)
  pdf_async_io_assert_page_text_contains_for_test(doc, 0, [
    "CamlPDF", "Introduction",
  ])
  pdf_async_io_assert_page_text_contains_for_test(doc, 2, [
    "AFirstProgram", "ocamlfind", "opaminstall",
  ])
  pdf_async_io_assert_page_text_contains_for_test(doc, 5, [
    "NextSteps", "pdfobject", "Indirect",
  ])
  pdf_async_io_assert_page_text_contains_for_test(doc, 7, [
    "GraphicsandText", "Pdfops", "Hello,World!",
  ])
  pdf_async_io_assert_page_text_contains_for_test(doc, 9, [
    "pdfencrypt.ml", "FurtherReading",
  ])
}

///|
fn pdf_async_io_secret_object_for_test(text : String) -> @pdflite.PdfObject {
  PdfDictionary([
    (pdf_async_io_name_for_test("/Title"), PdfString(@ascii.encode(text))),
  ])
}

///|
fn pdf_async_io_push_big_endian_for_test(
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
    output.push((value / remaining_divisor % 256).to_byte())
    remaining_divisor /= 256
  }
}

///|
fn pdf_async_io_push_xref_stream_entry_for_test(
  output : Array[Byte],
  kind : Int,
  field2 : Int,
  field3 : Int,
) -> Unit {
  output.push(kind.to_byte())
  pdf_async_io_push_big_endian_for_test(output, field2, 4)
  pdf_async_io_push_big_endian_for_test(output, field3, 2)
}

///|
fn pdf_async_io_write_indirect_object_for_test(
  output : Array[Byte],
  number : Int,
  object : @pdflite.PdfObject,
) -> Unit {
  for
    byte in (try! @pdflite.pdf_write_indirect_object({
      number,
      generation: 0,
      object,
    })) {
    output.push(byte)
  }
  output.push((10).to_byte())
}

///|
fn pdf_async_io_bad_first_object_stream_physical_page_tree_pdf_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let pages_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    2,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Pages")),
      ),
      (pdf_async_io_name_for_test("/Kids"), PdfArray([PdfIndirect(5)])),
      (pdf_async_io_name_for_test("/Count"), PdfInteger(1)),
    ]),
  )
  let page_offset = output.length()
  pdf_async_io_write_indirect_object_for_test(
    output,
    5,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Page")),
      ),
      (pdf_async_io_name_for_test("/Parent"), PdfIndirect(2)),
      (
        pdf_async_io_name_for_test("/MediaBox"),
        PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(10), PdfInteger(10)]),
      ),
      (pdf_async_io_name_for_test("/Resources"), @pdflite.pdf_dictionary([])),
    ]),
  )
  let object_stream_data : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(object_stream_data, "1 0 ")
  pdf_async_io_push_ascii_for_test(
    object_stream_data, "<< /Type /Catalog /Pages 2 0 R >>",
  )
  let bad_first = object_stream_data.length() + 4
  let object_stream_offset = output.length()
  pdf_async_io_push_ascii_for_test(output, "3 0 obj\n")
  pdf_async_io_push_ascii_for_test(output, "<< /Type /ObjStm /N 1 /First ")
  pdf_async_io_push_ascii_for_test(output, bad_first.to_string())
  pdf_async_io_push_ascii_for_test(output, " /Length ")
  pdf_async_io_push_ascii_for_test(
    output,
    object_stream_data.length().to_string(),
  )
  pdf_async_io_push_ascii_for_test(output, " >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 2, 3, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, pages_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(
    xref_data, 1, object_stream_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, xref_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, page_offset, 0)
  let xref_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/XRef")),
      ),
      (pdf_async_io_name_for_test("/Size"), PdfInteger(6)),
      (pdf_async_io_name_for_test("/Root"), PdfIndirect(1)),
      (
        pdf_async_io_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
      ),
      (pdf_async_io_name_for_test("/Length"), PdfInteger(xref_data.length())),
    ]),
    StreamGot(Bytes::from_array(xref_data)),
  )
  pdf_async_io_write_indirect_object_for_test(output, 4, xref_stream)
  pdf_async_io_write_indirect_object_for_test(
    output,
    1,
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
      (pdf_async_io_name_for_test("/Pages"), PdfIndirect(2)),
    ]),
  )
  pdf_async_io_push_ascii_for_test(output, "startxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_encrypted_object_stream_pdf_for_test(
  user_password : BytesView,
  owner_password : BytesView,
  denied : ArrayView[@pdflite.PdfPermission],
) -> @pdflite.PdfBytes raise {
  let secret = pdf_async_io_secret_object_for_test(
    "async encrypted object stream",
  )
  let object_stream_data : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(object_stream_data, "2 0 ")
  let first = object_stream_data.length()
  for byte in @pdflite.pdf_write_object(secret) {
    object_stream_data.push(byte)
  }
  let object_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/ObjStm")),
      ),
      (pdf_async_io_name_for_test("/N"), PdfInteger(1)),
      (pdf_async_io_name_for_test("/First"), PdfInteger(first)),
      (
        pdf_async_io_name_for_test("/Length"),
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
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/Catalog")),
      ),
      (pdf_async_io_name_for_test("/Payload"), PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(3, object_stream)
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    user_password,
    owner_password,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async-object-stream-reader"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-objstm-id"),
  )
  let encrypt_number = match
    encrypted
    .trailer_dict()
    .lookup_immediate(pdf_async_io_name_for_test("/Encrypt")) {
    Some(PdfIndirect(number)) => number
    _ => fail("expected encrypted object reference")
  }
  let trailer_id = match
    encrypted.trailer_dict().lookup_immediate(pdf_async_io_name_for_test("/ID")) {
    Some(id) => id
    None => fail("expected encrypted trailer ID")
  }

  let output : Array[Byte] = []
  pdf_async_io_push_ascii_for_test(output, "%PDF-1.5\n")
  let catalog_offset = output.length()
  for
    byte in @pdflite.pdf_write_indirect_object({
      number: 1,
      generation: 0,
      object: encrypted.lookup_object_or_null(1),
    }) {
    output.push(byte)
  }
  output.push((10).to_byte())
  let object_stream_offset = output.length()
  for
    byte in @pdflite.pdf_write_indirect_object({
      number: 3,
      generation: 0,
      object: encrypted.lookup_object_or_null(3),
    }) {
    output.push(byte)
  }
  output.push((10).to_byte())
  let encrypt_offset = output.length()
  for
    byte in @pdflite.pdf_write_indirect_object({
      number: encrypt_number,
      generation: 0,
      object: encrypted.lookup_object_or_null(encrypt_number),
    }) {
    output.push(byte)
  }
  output.push((10).to_byte())

  let xref_stream_number = 5
  let xref_offset = output.length()
  let xref_data : Array[Byte] = []
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 0, 0, 65535)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, catalog_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 2, 3, 0)
  pdf_async_io_push_xref_stream_entry_for_test(
    xref_data, 1, object_stream_offset, 0,
  )
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, encrypt_offset, 0)
  pdf_async_io_push_xref_stream_entry_for_test(xref_data, 1, xref_offset, 0)
  let xref_stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        pdf_async_io_name_for_test("/Type"),
        PdfNameObject(pdf_async_io_name_for_test("/XRef")),
      ),
      (pdf_async_io_name_for_test("/Size"), PdfInteger(6)),
      (pdf_async_io_name_for_test("/Root"), PdfIndirect(1)),
      (pdf_async_io_name_for_test("/Encrypt"), PdfIndirect(encrypt_number)),
      (pdf_async_io_name_for_test("/ID"), trailer_id),
      (
        pdf_async_io_name_for_test("/W"),
        PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
      ),
      (pdf_async_io_name_for_test("/Length"), PdfInteger(xref_data.length())),
    ]),
    StreamGot(Bytes::from_array(xref_data)),
  )
  for
    byte in @pdflite.pdf_write_indirect_object({
      number: xref_stream_number,
      generation: 0,
      object: xref_stream,
    }) {
    output.push(byte)
  }
  pdf_async_io_push_ascii_for_test(output, "\nstartxref\n")
  pdf_async_io_push_ascii_for_test(output, xref_offset.to_string())
  pdf_async_io_push_ascii_for_test(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn pdf_async_io_assert_decrypted_object_stream_for_test(
  decrypted : @pdflite.PdfDecryptionResult,
  denied : Array[@pdflite.PdfPermission],
) -> Unit raise {
  @test.assert_eq(decrypted.denied_permissions, denied)
  @test.assert_eq(
    decrypted.document
    .catalog()
    .lookup_immediate(pdf_async_io_name_for_test("/Payload")),
    Some(PdfIndirect(2)),
  )
  @test.assert_eq(
    decrypted.document.lookup_object_or_null(2),
    pdf_async_io_secret_object_for_test("async encrypted object stream"),
  )
}

///|
fn pdf_async_io_secret_document_for_test(
  text : String,
) -> @pdflite.PdfDocument raise @pdflite.PdfError {
  let document = @pdflite.pdf_minimum_valid_pdf()
  document.add_object_given_number(
    41,
    pdf_async_io_secret_object_for_test(text),
  )
  document
}

///|
fn pdf_async_io_decryption_result_for_test(
  result : @pdflite.PdfDecryptionResult?,
) -> @pdflite.PdfDecryptionResult raise {
  match result {
    Some(result) => result
    None => fail("expected decrypted async file")
  }
}

///|
async fn pdf_async_io_assert_encrypted_file_secret_for_test(
  path : String,
  owner_password : String,
  denied : Array[@pdflite.PdfPermission],
  text : String,
) -> Unit {
  let decrypted = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      path,
      owner_password=Some(@ascii.encode(owner_password)),
    ),
  )
  @test.assert_eq(try! decrypted.document.endpage(), 1)
  @test.assert_eq(decrypted.denied_permissions, denied)
  @test.assert_eq(
    decrypted.document.lookup_object_or_null(41),
    pdf_async_io_secret_object_for_test(text),
  )
}

///|
async test "async file wrappers write and read PDF documents" {
  let path = pdf_async_io_test_path_for_test("roundtrip")
  pdf_async_io_remove_if_exists_for_test(path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file(original, path)
  let loaded = pdf_read_document_from_file(path)
  @test.assert_eq(pdf_read_header_from_file(path), { major: 1, minor: 0 })
  @test.assert_eq(pdf_is_linearized_file(path), false)
  pdf_async_io_remove_if_exists_for_test(path)
  @test.assert_eq(try! loaded.endpage(), 1)
  @test.assert_eq(loaded.version(), original.version())
}

///|
async test "async file wrappers can write generated trailer IDs" {
  let path = pdf_async_io_test_path_for_test("generated_id")
  pdf_async_io_remove_if_exists_for_test(path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file_with_generated_id(
    original,
    path,
    mode=PdfWriteCompressedXRefStream,
  )
  let loaded = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(path)
  pdf_async_io_assert_generated_id_for_test(
    loaded.trailer_dict().lookup_immediate(pdf_async_io_name_for_test("/ID")),
  )
  @test.assert_eq(
    original.trailer_dict().lookup_immediate(pdf_async_io_name_for_test("/ID")),
    None,
  )
  @test.assert_eq(try! loaded.endpage(), 1)
}

///|
async test "async file wrappers can incrementally write generated trailer IDs" {
  let original_path = pdf_async_io_test_path_for_test("generated_id_original")
  let path = pdf_async_io_test_path_for_test("generated_id_update")
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file(original, original_path)
  pdf_write_document_incremental_update_to_file_with_generated_id(
    original_path,
    original,
    path,
    mode=PdfWriteCompressedXRefStream,
  )
  let rendered = @fs.read_file(path).binary()
  let loaded = pdf_read_document_from_file(path)
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(path)
  @test.assert_eq(try! @pdflite.pdf_revisions_from_bytes(rendered), 2)
  pdf_async_io_assert_generated_id_for_test(
    loaded.trailer_dict().lookup_immediate(pdf_async_io_name_for_test("/ID")),
  )
  @test.assert_eq(
    original.trailer_dict().lookup_immediate(pdf_async_io_name_for_test("/ID")),
    None,
  )
  @test.assert_eq(try! loaded.endpage(), 1)
}

///|
async test "async file wrappers read checked-in CamlPDF fixture PDFs" {
  let logo_path = pdf_async_io_repo_path_for_test("fixtures/camlpdf/logo.pdf")
  let intro_path = pdf_async_io_repo_path_for_test(
    "fixtures/camlpdf/introduction_to_camlpdf.pdf",
  )
  let logo_roundtrip = pdf_async_io_test_path_for_test("logo_fixture")
  let intro_roundtrip = pdf_async_io_test_path_for_test("intro_fixture")
  let intro_decompressed_roundtrip = pdf_async_io_test_path_for_test(
    "intro_decompressed_fixture",
  )
  pdf_async_io_remove_if_exists_for_test(logo_roundtrip)
  pdf_async_io_remove_if_exists_for_test(intro_roundtrip)
  pdf_async_io_remove_if_exists_for_test(intro_decompressed_roundtrip)

  let logo = pdf_read_document_from_file(logo_path)
  @test.assert_eq(pdf_read_header_from_file(logo_path), { major: 1, minor: 4 })
  @test.assert_eq(pdf_is_linearized_file(logo_path), true)
  @test.assert_eq(logo.version(), (1, 4))
  @test.assert_eq(try! logo.endpage(), 1)
  pdf_write_document_to_file_with_compressed_xref_stream(logo, logo_roundtrip)
  let logo_reparsed = pdf_read_document_from_file(logo_roundtrip)
  @test.assert_eq(try! logo_reparsed.endpage(), 1)

  let intro = pdf_read_document_from_file(intro_path)
  @test.assert_eq(pdf_read_header_from_file(intro_path), { major: 1, minor: 5 })
  @test.assert_eq(intro.version(), (1, 5))
  pdf_async_io_assert_intro_fixture_text_for_test(intro)
  pdf_write_document_to_file_with_compressed_xref_stream(intro, intro_roundtrip)
  let intro_reparsed = pdf_read_document_from_file(intro_roundtrip)
  pdf_async_io_assert_intro_fixture_text_for_test(intro_reparsed)

  let intro_decompressed = intro.copy()
  intro_decompressed.pdf_decode_streams_until_unknown()
  pdf_write_document_to_file_with_compressed_xref_stream(
    intro_decompressed, intro_decompressed_roundtrip,
  )
  let intro_decompressed_reparsed = pdf_read_document_from_file(
    intro_decompressed_roundtrip,
  )
  pdf_async_io_assert_intro_fixture_text_for_test(intro_decompressed_reparsed)

  pdf_async_io_remove_if_exists_for_test(logo_roundtrip)
  pdf_async_io_remove_if_exists_for_test(intro_roundtrip)
  pdf_async_io_remove_if_exists_for_test(intro_decompressed_roundtrip)
}

///|
async test "async file wrappers incrementally update checked-in CamlPDF intro fixture" {
  let intro_path = pdf_async_io_repo_path_for_test(
    "fixtures/camlpdf/introduction_to_camlpdf.pdf",
  )
  let updated_path = pdf_async_io_test_path_for_test(
    "intro_fixture_incremental",
  )
  pdf_async_io_remove_if_exists_for_test(updated_path)

  let updated = pdf_read_document_from_file(intro_path)
  let added_object : @pdflite.PdfObject = PdfDictionary([
    (
      pdf_async_io_name_for_test("/Title"),
      PdfString(@ascii.encode("intro fixture incremental")),
    ),
  ])
  let added_number = updated.add_object(added_object)
  pdf_write_document_incremental_update_with_compressed_xref_stream_to_file(
    intro_path, updated, updated_path,
  )
  let revision_count = pdf_revisions_from_file(updated_path)
  let newest = pdf_read_document_revision_from_file(updated_path, 1)
  let older = pdf_read_document_revision_from_file(updated_path, 2)
  pdf_async_io_remove_if_exists_for_test(updated_path)

  @test.assert_eq(revision_count, 2)
  @test.assert_eq(newest.lookup_object_or_null(added_number), added_object)
  @test.assert_eq(older.lookup_object_or_null(added_number), PdfNull)
  pdf_async_io_assert_intro_fixture_text_for_test(newest)
  pdf_async_io_assert_intro_fixture_text_for_test(older)
}

///|
async test "async file wrappers reconstruct malformed incremental CamlPDF intro fixture" {
  let intro_path = pdf_async_io_repo_path_for_test(
    "fixtures/camlpdf/introduction_to_camlpdf.pdf",
  )
  let updated_path = pdf_async_io_test_path_for_test(
    "intro_incremental_bad_startxref_source",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "intro_incremental_bad_startxref_fixture",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "intro_incremental_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)

  let updated = pdf_read_document_from_file(intro_path)
  let key_root = pdf_async_io_name_for_test("/Root")
  let key_payload = pdf_async_io_name_for_test("/Payload")
  let added_object : @pdflite.PdfObject = PdfDictionary([
    (
      pdf_async_io_name_for_test("/Title"),
      PdfString(@ascii.encode("intro fixture malformed incremental")),
    ),
  ])
  let added_number = updated.add_object(added_object)
  let new_root_number = updated.add_object(
    updated.catalog().add_dict_entry(key_payload, PdfIndirect(added_number)),
  )
  updated.set_root(new_root_number)
  updated.set_trailer_dict(
    updated
    .trailer_dict()
    .add_dict_entry(key_root, PdfIndirect(new_root_number)),
  )
  pdf_write_document_incremental_update_with_compressed_xref_stream_to_file(
    intro_path, updated, updated_path,
  )
  @test.assert_eq(pdf_revisions_from_file(updated_path), 2)
  let newest = pdf_read_document_revision_from_file(updated_path, 1)
  @test.assert_eq(newest.lookup_object_or_null(added_number), added_object)
  @test.assert_eq(
    newest.lookup_object_or_null(new_root_number),
    updated.catalog(),
  )
  @test.assert_eq(
    newest.catalog().lookup_immediate(key_payload),
    Some(PdfIndirect(added_number)),
  )
  let older = pdf_read_document_revision_from_file(updated_path, 2)
  @test.assert_eq(older.lookup_object_or_null(added_number), PdfNull)
  @test.assert_eq(older.lookup_object_or_null(new_root_number), PdfNull)
  pdf_async_io_assert_intro_fixture_text_for_test(older)

  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    @fs.read_file(updated_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_read_document_from_file(corrupted_path)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.lookup_object_or_null(added_number), added_object)
  @test.assert_eq(
    recovered.catalog().lookup_immediate(key_payload),
    Some(PdfIndirect(added_number)),
  )
  pdf_async_io_assert_intro_fixture_text_for_test(recovered)

  pdf_write_document_to_file_with_compressed_xref_stream(
    recovered, repaired_path,
  )
  let reparsed = pdf_read_document_from_file(repaired_path)
  @test.assert_eq(reparsed.first_xref() > 0, true)
  @test.assert_eq(reparsed.lookup_object_or_null(added_number), added_object)
  @test.assert_eq(
    reparsed.catalog().lookup_immediate(key_payload),
    Some(PdfIndirect(added_number)),
  )
  pdf_async_io_assert_intro_fixture_text_for_test(reparsed)

  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
}

///|
async test "async file wrappers reconstruct checked-in CamlPDF logo fixture with bad startxref" {
  let logo_path = pdf_async_io_repo_path_for_test("fixtures/camlpdf/logo.pdf")
  let corrupted_path = pdf_async_io_test_path_for_test(
    "logo_bad_startxref_fixture",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "logo_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)

  let corrupted = pdf_async_io_corrupt_startxref_pointer_for_test(
    @fs.read_file(logo_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_read_document_from_file(corrupted_path)
  @test.assert_eq(recovered.version(), (1, 4))
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), 1)

  pdf_write_document_to_file_with_compressed_xref_stream(
    recovered, repaired_path,
  )
  let reparsed = pdf_read_document_from_file(repaired_path)
  @test.assert_eq(reparsed.first_xref() > 0, true)
  @test.assert_eq(reparsed.endpage(), 1)

  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
}

///|
async test "async file wrappers reconstruct checked-in CamlPDF intro fixture with bad startxref" {
  let intro_path = pdf_async_io_repo_path_for_test(
    "fixtures/camlpdf/introduction_to_camlpdf.pdf",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "intro_bad_startxref_fixture",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "intro_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)

  let corrupted = pdf_async_io_corrupt_startxref_pointer_for_test(
    @fs.read_file(intro_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_read_document_from_file(corrupted_path)
  @test.assert_eq(recovered.version(), (1, 5))
  @test.assert_eq(recovered.first_xref(), 0)
  pdf_async_io_assert_intro_fixture_text_for_test(recovered)

  pdf_write_document_to_file_with_compressed_xref_stream(
    recovered, repaired_path,
  )
  let reparsed = pdf_read_document_from_file(repaired_path)
  @test.assert_eq(reparsed.first_xref() > 0, true)
  pdf_async_io_assert_intro_fixture_text_for_test(reparsed)

  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
}

///|
async test "async file wrappers write xref streams and read encrypted documents" {
  let xref_path = pdf_async_io_test_path_for_test("xref")
  let encrypted_path = pdf_async_io_test_path_for_test("encrypted_xref")
  pdf_async_io_remove_if_exists_for_test(xref_path)
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file_with_xref_stream(original, xref_path)
  let loaded = pdf_read_document_from_file(xref_path)
  @test.assert_eq(loaded.version(), (1, 5))
  @test.assert_eq(try! loaded.endpage(), 1)

  let encrypted = try! original.encrypt_128bit_r4(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint],
    encrypt_metadata=true,
    file_id=@ascii.encode("async-doc-id"),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    encrypted, encrypted_path,
  )
  guard pdf_read_document_from_file_with_passwords(
      encrypted_path,
      user_password=Some(@ascii.encode("bad")),
      owner_password=Some(@ascii.encode("owner")),
    )
    is Some(decrypted) else {
    fail("expected decrypted async file")
  }
  pdf_async_io_remove_if_exists_for_test(xref_path)
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  @test.assert_eq(try! decrypted.document.endpage(), 1)
  @test.assert_eq(decrypted.denied_permissions, [PdfNoPrint])
}

///|
async test "async file wrappers reconstruct physical page trees when object-stream bounds are malformed" {
  let malformed_path = pdf_async_io_test_path_for_test(
    "bad_object_stream_first_physical_pages",
  )
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  let malformed = pdf_async_io_bad_first_object_stream_physical_page_tree_pdf_for_test()
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::StreamDataExpected) else {
    fail("expected malformed object-stream bounds to require reconstruction")
  }
  let recovered = pdf_read_document_from_file(malformed_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.object_numbers(), [1, 2, 3, 5])
  @test.assert_eq(try! recovered.endpage(), 1)
  @test.assert_eq(try! recovered.page_reference_numbers(), [5])
}

///|
async test "async file wrappers read encrypted object streams and recover bad startxref" {
  let encrypted_path = pdf_async_io_test_path_for_test("encrypted_objstm")
  let corrupted_path = pdf_async_io_test_path_for_test(
    "encrypted_objstm_bad_startxref",
  )
  let blank_path = pdf_async_io_test_path_for_test("encrypted_objstm_blank")
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(blank_path)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = try! pdf_async_io_encrypted_object_stream_pdf_for_test(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied,
  )
  @fs.write_file(encrypted_path, encrypted, create=0o644)
  let decrypted = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      encrypted_path,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  pdf_async_io_assert_decrypted_object_stream_for_test(decrypted, denied)

  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    encrypted,
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let partial = pdf_read_document_from_file(corrupted_path)
  @test.assert_eq(partial.first_xref(), 0)
  @test.assert_eq(partial.lookup_object_or_null(2), PdfNull)
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      corrupted_path,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  pdf_async_io_assert_decrypted_object_stream_for_test(recovered, denied)

  let blank = try! pdf_async_io_encrypted_object_stream_pdf_for_test(
    @ascii.encode(""),
    @ascii.encode("owner"),
    denied,
  )
  @fs.write_file(blank_path, blank, create=0o644)
  let blank_decrypted = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(blank_path),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(blank_path)
  pdf_async_io_assert_decrypted_object_stream_for_test(blank_decrypted, denied)
}

///|
async test "async file wrappers recrypt encrypted object-stream payloads" {
  let source_path = pdf_async_io_test_path_for_test("encrypted_objstm_recrypt")
  let roundtrip_path = pdf_async_io_test_path_for_test(
    "encrypted_objstm_recrypt_roundtrip",
  )
  pdf_async_io_remove_if_exists_for_test(source_path)
  pdf_async_io_remove_if_exists_for_test(roundtrip_path)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let user_password = @ascii.encode("user")
  let owner_password = @ascii.encode("owner")
  let encrypted = try! pdf_async_io_encrypted_object_stream_pdf_for_test(
    user_password, owner_password, denied,
  )
  @fs.write_file(source_path, encrypted, create=0o644)
  let decrypted = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      source_path,
      owner_password=Some(owner_password),
    ),
  )
  pdf_async_io_assert_decrypted_object_stream_for_test(decrypted, denied)
  let added_object : @pdflite.PdfObject = PdfString(
    @ascii.encode("async object-stream recrypt added"),
  )
  decrypted.document.add_object_given_number(6, added_object)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    owner_password,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async object-stream recrypt iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, roundtrip_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(roundtrip_path).binary(),
      @ascii.encode("async encrypted object stream"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      roundtrip_path,
      user_password=Some(user_password),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(source_path)
  pdf_async_io_remove_if_exists_for_test(roundtrip_path)
  pdf_async_io_assert_decrypted_object_stream_for_test(roundtrip, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(6), added_object)
}

///|
async test "async file wrappers write mode-dispatched encrypted documents" {
  let mode_path = pdf_async_io_test_path_for_test("mode_dispatch")
  let arc4_40_path = pdf_async_io_test_path_for_test("encrypt_40")
  let arc4_128_path = pdf_async_io_test_path_for_test("encrypt_128")
  let arc4_r4_path = pdf_async_io_test_path_for_test("encrypt_r4")
  let aesv2_path = pdf_async_io_test_path_for_test("encrypt_aesv2")
  let aesv2_default_path = pdf_async_io_test_path_for_test(
    "encrypt_aesv2_default",
  )
  let aesv3_path = pdf_async_io_test_path_for_test("encrypt_aesv3")
  let aesv3_default_path = pdf_async_io_test_path_for_test(
    "encrypt_aesv3_default",
  )
  let aesv3_iso_path = pdf_async_io_test_path_for_test("encrypt_aesv3_iso")
  let aesv3_iso_default_path = pdf_async_io_test_path_for_test(
    "encrypt_aesv3_iso_default",
  )
  pdf_async_io_remove_if_exists_for_test(mode_path)
  pdf_async_io_remove_if_exists_for_test(arc4_40_path)
  pdf_async_io_remove_if_exists_for_test(arc4_128_path)
  pdf_async_io_remove_if_exists_for_test(arc4_r4_path)
  pdf_async_io_remove_if_exists_for_test(aesv2_path)
  pdf_async_io_remove_if_exists_for_test(aesv2_default_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_default_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_iso_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_iso_default_path)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoEdit, PdfNoPrint]
  pdf_write_document_to_file_with_mode(
    try! @pdflite.pdf_minimum_valid_pdf(),
    mode_path,
    PdfWriteCompressedXRefStream,
  )
  @test.assert_eq(pdf_read_document_from_file(mode_path).version(), (1, 5))
  pdf_write_encrypted_40bit_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-40"),
    arc4_40_path,
    user,
    owner,
    denied,
    file_id=@ascii.encode("async-40-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    arc4_40_path, "owner", denied, "async-40",
  )
  pdf_write_encrypted_128bit_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-128"),
    arc4_128_path,
    user,
    owner,
    denied,
    mode=PdfWriteXRefStream,
    file_id=@ascii.encode("async-128-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    arc4_128_path, "owner", denied, "async-128",
  )
  pdf_write_encrypted_128bit_r4_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-r4"),
    arc4_r4_path,
    user,
    owner,
    denied,
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-r4-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    arc4_r4_path, "owner", denied, "async-r4",
  )
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    try! pdf_async_io_secret_document_for_test("async-aesv2"),
    aesv2_path,
    user,
    owner,
    [PdfNoCopy],
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async-aesv2-iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-aesv2-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv2_path,
    "owner",
    [PdfNoCopy],
    "async-aesv2",
  )
  pdf_write_encrypted_aesv2_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-aesv2-default"),
    aesv2_default_path,
    user,
    owner,
    [PdfNoPrint],
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-aesv2-default-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv2_default_path,
    "owner",
    [PdfNoPrint],
    "async-aesv2-default",
  )
  pdf_write_encrypted_aesv3_document_to_file_with_providers(
    try! pdf_async_io_secret_document_for_test("async-aesv3"),
    aesv3_path,
    user,
    owner,
    [PdfNoExtract],
    @pdflite.pdf_deterministic_aesv3_random_provider_from_seed(
      @ascii.encode("async-aesv3-random"),
    ),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async-aesv3-iv"),
    ),
    mode=PdfWriteXRefStream,
    file_id=@ascii.encode("async-aesv3-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv3_path,
    "owner",
    [PdfNoExtract],
    "async-aesv3",
  )
  pdf_write_encrypted_aesv3_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-aesv3-default"),
    aesv3_default_path,
    user,
    owner,
    [PdfNoExtract],
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-aesv3-default-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv3_default_path,
    "owner",
    [PdfNoExtract],
    "async-aesv3-default",
  )
  pdf_write_encrypted_aesv3_iso_document_to_file_with_providers(
    try! pdf_async_io_secret_document_for_test("async-aesv3-iso"),
    aesv3_iso_path,
    user,
    owner,
    [PdfNoAssemble],
    @pdflite.pdf_deterministic_aesv3_random_provider_from_seed(
      @ascii.encode("async-aesv3-iso-random"),
    ),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async-aesv3-iso-iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-aesv3-iso-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv3_iso_path,
    "owner",
    [PdfNoAssemble],
    "async-aesv3-iso",
  )
  pdf_write_encrypted_aesv3_iso_document_to_file(
    try! pdf_async_io_secret_document_for_test("async-aesv3-iso-default"),
    aesv3_iso_default_path,
    user,
    owner,
    [PdfNoAssemble],
    encrypt_metadata=false,
    file_id=@ascii.encode("async-aesv3-iso-default-id"),
  )
  pdf_async_io_assert_encrypted_file_secret_for_test(
    aesv3_iso_default_path,
    "owner",
    [PdfNoAssemble],
    "async-aesv3-iso-default",
  )
  pdf_async_io_remove_if_exists_for_test(mode_path)
  pdf_async_io_remove_if_exists_for_test(arc4_40_path)
  pdf_async_io_remove_if_exists_for_test(arc4_128_path)
  pdf_async_io_remove_if_exists_for_test(arc4_r4_path)
  pdf_async_io_remove_if_exists_for_test(aesv2_path)
  pdf_async_io_remove_if_exists_for_test(aesv2_default_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_default_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_iso_path)
  pdf_async_io_remove_if_exists_for_test(aesv3_iso_default_path)
}

///|
async test "async file wrappers reconstruct compressed ARC4 encrypted documents with bad startxref" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "compressed_arc4_bad_startxref",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "compressed_arc4_bad_startxref_corrupted",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "compressed_arc4_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async compressed arc4 secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoPrint]
  pdf_write_encrypted_128bit_r4_document_to_file(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-arc4-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async compressed arc4 secret"),
    ) <
    0,
    true,
  )
  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      corrupted_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async compressed arc4 repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password(owner)
  @test.assert_eq(try! recrypted.what_encryption(), Some(PdfEncryption128Bit))
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async fn pdf_async_io_assert_legacy_arc4_recovery_for_test(
  label : String,
  key_length_bits : Int,
  expected_encryption : @pdflite.PdfEncryptionMethod,
) -> Unit {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "compressed_arc4_" + label + "_bad_startxref",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "compressed_arc4_" + label + "_bad_startxref_corrupted",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "compressed_arc4_" + label + "_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret_text = "async compressed arc4 " + label + " secret"
  let secret = pdf_async_io_secret_object_for_test(secret_text)
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoPrint]
  if key_length_bits == 40 {
    pdf_write_encrypted_40bit_document_to_file(
      doc,
      encrypted_path,
      user,
      owner,
      denied,
      mode=PdfWriteCompressedXRefStream,
      file_id=@ascii.encode("a40-id"),
    )
  } else {
    pdf_write_encrypted_128bit_document_to_file(
      doc,
      encrypted_path,
      user,
      owner,
      denied,
      mode=PdfWriteCompressedXRefStream,
      file_id=@ascii.encode("a128-id"),
    )
  }
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode(secret_text),
    ) <
    0,
    true,
  )
  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      corrupted_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async compressed arc4 " + label + " repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password(owner)
  @test.assert_eq(try! recrypted.what_encryption(), Some(expected_encryption))
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct compressed legacy ARC4 encrypted documents with bad startxref" {
  pdf_async_io_assert_legacy_arc4_recovery_for_test(
    "40",
    40,
    PdfEncryption40Bit,
  )
  pdf_async_io_assert_legacy_arc4_recovery_for_test(
    "128",
    128,
    PdfEncryption128Bit,
  )
}

///|
async test "async file wrappers reconstruct compressed encrypted documents with bad startxref" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "compressed_encrypted_bad_startxref",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "compressed_encrypted_bad_startxref_corrupted",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "compressed_encrypted_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async compressed encrypted secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy, PdfNoPrint]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async compressed encrypted iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-compressed-encrypted-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async compressed encrypted secret"),
    ) <
    0,
    true,
  )
  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      corrupted_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async compressed encrypted repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async compressed encrypted repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed classic xref offsets" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_offset",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_offset_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_offset_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async classic xref offset secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async classic xref offset iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-classic-xref-offset-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async classic xref offset secret"),
    ) <
    0,
    true,
  )
  let malformed = pdf_async_io_corrupt_first_in_use_xref_offset_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(_) else {
    fail("expected malformed classic xref offset to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(try! recovered.document.endpage(), 1)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async classic xref offset repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async classic xref offset repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async classic xref offset secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(try! roundtrip.document.endpage(), 1)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed classic xref markers" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_marker",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_marker_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_marker_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async classic xref marker secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async classic xref marker iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-classic-xref-marker-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async classic xref marker secret"),
    ) <
    0,
    true,
  )
  let malformed = pdf_async_io_corrupt_first_in_use_xref_marker_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed classic xref marker to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(try! recovered.document.endpage(), 1)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async classic xref marker repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async classic xref marker repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async classic xref marker secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(try! roundtrip.document.endpage(), 1)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed classic xref subsections" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_subsection",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_subsection_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_classic_xref_subsection_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async classic xref subsection secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async classic xref subsection iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-classic-xref-subsection-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async classic xref subsection secret"),
    ) <
    0,
    true,
  )
  let malformed = pdf_async_io_corrupt_first_xref_subsection_count_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected malformed classic xref subsection to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(try! recovered.document.endpage(), 1)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async classic xref subsection repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async classic xref subsection repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async classic xref subsection secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(try! roundtrip.document.endpage(), 1)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed xref-stream metadata" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_metadata",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_metadata_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_metadata_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async xref-stream metadata secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream metadata iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-bad-xref-stream-metadata-id"),
  )
  let malformed = pdf_async_io_insert_ascii_before_last_marker_for_test(
    @fs.read_file(encrypted_path).binary(),
    @ascii.encode("/W ["),
    "/Index [0] ",
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref stream metadata to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async xref-stream metadata repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream metadata repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async xref-stream metadata secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed xref-stream widths" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_widths",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_widths_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_widths_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async xref-stream widths secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream widths iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-bad-xref-stream-widths-id"),
  )
  let malformed = pdf_async_io_insert_ascii_before_last_marker_for_test(
    @fs.read_file(encrypted_path).binary(),
    @ascii.encode("/W ["),
    "/W [1 4] ",
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref stream widths to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async xref-stream widths repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream widths repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async xref-stream widths secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed xref-stream size" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_size",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_size_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_size_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async xref-stream size secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream size iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-bad-xref-stream-size-id"),
  )
  let malformed = pdf_async_io_insert_ascii_before_last_marker_for_test(
    @fs.read_file(encrypted_path).binary(),
    @ascii.encode("/Size "),
    "/Size /Bad ",
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref stream size to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async xref-stream size repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream size repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async xref-stream size secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed xref-stream filters" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_filter",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_filter_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_filter_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async xref-stream filter secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream filter iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-bad-xref-stream-filter-id"),
  )
  let malformed = pdf_async_io_insert_ascii_before_last_marker_for_test(
    @fs.read_file(encrypted_path).binary(),
    @ascii.encode("/Filter "),
    "/Filter /BadXRefFilter ",
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::FilterNotSupported(filter)) else {
    fail("expected malformed xref stream filter to require reconstruction")
  }
  @test.assert_eq(filter, pdf_async_io_name_for_test("/BadXRefFilter"))
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async xref-stream filter repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream filter repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async xref-stream filter secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct encrypted malformed xref-stream decodeparms" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_decodeparms",
  )
  let malformed_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_decodeparms_malformed",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_xref_stream_decodeparms_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async xref-stream decodeparms secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  pdf_write_encrypted_aesv2_document_to_file_with_iv_provider(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream decodeparms iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-bad-xref-decodeparms-id"),
  )
  let malformed = pdf_async_io_insert_ascii_before_last_marker_for_test(
    @fs.read_file(encrypted_path).binary(),
    @ascii.encode("/Filter "),
    "/DecodeParms /Bad ",
  )
  @fs.write_file(malformed_path, malformed, create=0o644)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    @fs.read_file(malformed_path).binary(),
  )
  guard strict is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected malformed xref stream DecodeParms to require reconstruction")
  }
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      malformed_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async xref-stream decodeparms repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async xref-stream decodeparms repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(repaired_path).binary(),
      @ascii.encode("async xref-stream decodeparms secret"),
    ) <
    0,
    true,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(malformed_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct compressed AESV3 encrypted documents with bad startxref" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "compressed_aesv3_bad_startxref",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "compressed_aesv3_bad_startxref_corrupted",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "compressed_aesv3_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async compressed aesv3 secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoAssemble, PdfNoExtract]
  pdf_write_encrypted_aesv3_document_to_file_with_providers(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aesv3_random_provider_from_seed(
      @ascii.encode("async compressed aesv3 random"),
    ),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async compressed aesv3 iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-compressed-aesv3-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async compressed aesv3 secret"),
    ) <
    0,
    true,
  )
  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      corrupted_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async compressed aesv3 repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv3_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async compressed aesv3 repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers reconstruct compressed AESV3 ISO encrypted documents with bad startxref" {
  let encrypted_path = pdf_async_io_test_path_for_test(
    "compressed_aesv3_iso_bad_startxref",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "compressed_aesv3_iso_bad_startxref_corrupted",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "compressed_aesv3_iso_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let secret = pdf_async_io_secret_object_for_test(
    "async compressed aesv3 iso secret",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, secret)
  let user = @ascii.encode("user")
  let owner = @ascii.encode("owner")
  let denied : Array[@pdflite.PdfPermission] = [PdfNoAssemble]
  pdf_write_encrypted_aesv3_iso_document_to_file_with_providers(
    doc,
    encrypted_path,
    user,
    owner,
    denied,
    @pdflite.pdf_deterministic_aesv3_random_provider_from_seed(
      @ascii.encode("async compressed aesv3 iso random"),
    ),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async compressed aesv3 iso iv"),
    ),
    encrypt_metadata=false,
    mode=PdfWriteCompressedXRefStream,
    file_id=@ascii.encode("async-compressed-aesv3-iso-id"),
  )
  @test.assert_eq(
    pdf_async_io_find_bytes_for_test(
      @fs.read_file(encrypted_path).binary(),
      @ascii.encode("async compressed aesv3 iso secret"),
    ) <
    0,
    true,
  )
  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    @fs.read_file(encrypted_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      corrupted_path,
      owner_password=Some(owner),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async compressed aesv3 iso repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recrypted = try! recovered.document.recrypt_with_password_aesv3_with_iv_provider(
    owner,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async compressed aesv3 iso repair iv"),
    ),
  )
  @test.assert_eq(
    try! recrypted.what_encryption(),
    Some(PdfEncryptionAES256ISO(false)),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recrypted, repaired_path,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(user),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(encrypted_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}

///|
async test "async file wrappers write incremental updates" {
  let original_path = pdf_async_io_test_path_for_test("original")
  let updated_path = pdf_async_io_test_path_for_test("incremental")
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file(original, original_path)
  let updated = pdf_read_document_from_file(original_path)
  let key_title = pdf_async_io_name_for_test("/Title")
  let added_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("async incremental"))),
  ])
  updated.add_object_given_number(20, added_object)
  pdf_write_document_incremental_update_to_file(
    original_path, updated, updated_path,
  )
  let reparsed = pdf_read_document_from_file(updated_path)
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  @test.assert_eq(try! reparsed.endpage(), 1)
  @test.assert_eq(reparsed.lookup_object_or_null(20), added_object)
}

///|
async test "async file wrappers read incremental revisions" {
  let original_path = pdf_async_io_test_path_for_test("revision_original")
  let updated_path = pdf_async_io_test_path_for_test("revision_incremental")
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file(original, original_path)
  let updated = pdf_read_document_from_file(original_path)
  let key_title = pdf_async_io_name_for_test("/Title")
  let added_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("async revision"))),
  ])
  updated.add_object_given_number(22, added_object)
  pdf_write_document_incremental_update_to_file(
    original_path, updated, updated_path,
  )
  let revision_count = pdf_revisions_from_file(updated_path)
  let latest = pdf_read_document_revision_from_file(updated_path, 1)
  let older = pdf_read_document_revision_from_file(updated_path, 2)
  guard pdf_read_document_revision_from_file_with_passwords(updated_path, 2)
    is Some(older_password_result) else {
    fail("expected revision decryption result")
  }
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  @test.assert_eq(revision_count, 2)
  @test.assert_eq(latest.lookup_object_or_null(22), added_object)
  @test.assert_eq(older.lookup_object_or_null(22), PdfNull)
  @test.assert_eq(
    older_password_result.document.lookup_object_or_null(22),
    PdfNull,
  )
  @test.assert_eq(older_password_result.denied_permissions, [])
}

///|
async test "async file wrappers write xref stream incremental updates" {
  let original_path = pdf_async_io_test_path_for_test("xref_original")
  let updated_path = pdf_async_io_test_path_for_test("xref_incremental")
  let compressed_path = pdf_async_io_test_path_for_test(
    "xref_incremental_compressed",
  )
  let mode_path = pdf_async_io_test_path_for_test("xref_incremental_mode")
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(compressed_path)
  pdf_async_io_remove_if_exists_for_test(mode_path)
  let original = try! @pdflite.pdf_minimum_valid_pdf()
  pdf_write_document_to_file_with_xref_stream(original, original_path)
  let updated = pdf_read_document_from_file(original_path)
  let key_title = pdf_async_io_name_for_test("/Title")
  let added_object : @pdflite.PdfObject = PdfDictionary([
    (key_title, PdfString(@ascii.encode("async xref incremental"))),
  ])
  updated.add_object_given_number(21, added_object)
  pdf_write_document_incremental_update_with_xref_stream_to_file(
    original_path, updated, updated_path,
  )
  pdf_write_document_incremental_update_with_compressed_xref_stream_to_file(
    original_path, updated, compressed_path,
  )
  pdf_write_document_incremental_update_to_file_with_mode(
    original_path,
    updated,
    mode_path,
    PdfWriteCompressedXRefStream,
  )
  let reparsed = pdf_read_document_from_file(updated_path)
  let compressed_reparsed = pdf_read_document_from_file(compressed_path)
  let mode_reparsed = pdf_read_document_from_file(mode_path)
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(compressed_path)
  pdf_async_io_remove_if_exists_for_test(mode_path)
  @test.assert_eq(reparsed.lookup_object_or_null(21), added_object)
  @test.assert_eq(compressed_reparsed.lookup_object_or_null(21), added_object)
  @test.assert_eq(mode_reparsed.lookup_object_or_null(21), added_object)
}

///|
async test "async file wrappers read encrypted incremental revisions" {
  let original_path = pdf_async_io_test_path_for_test(
    "encrypted_revision_original",
  )
  let updated_path = pdf_async_io_test_path_for_test(
    "encrypted_revision_incremental",
  )
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  let original_secret = pdf_async_io_secret_object_for_test(
    "async encrypted original",
  )
  let updated_secret = pdf_async_io_secret_object_for_test(
    "async encrypted updated",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, original_secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy]
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async encrypted revision iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-encrypted-revision-id"),
  )
  pdf_write_document_to_file(encrypted, original_path)
  let decrypted = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      original_path,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  decrypted.document.add_object_given_number(30, updated_secret)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("owner"),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async encrypted revision recrypt iv"),
    ),
  )
  pdf_write_document_incremental_update_with_compressed_xref_stream_to_file(
    original_path, recrypted, updated_path,
  )
  let revision_count = pdf_revisions_from_file(updated_path)
  let newest = pdf_async_io_decryption_result_for_test(
    pdf_read_document_revision_from_file_with_passwords(
      updated_path,
      1,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  let older = pdf_async_io_decryption_result_for_test(
    pdf_read_document_revision_from_file_with_passwords(
      updated_path,
      2,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  @test.assert_eq(revision_count, 2)
  @test.assert_eq(newest.denied_permissions, denied)
  @test.assert_eq(newest.document.lookup_object_or_null(30), updated_secret)
  @test.assert_eq(older.denied_permissions, denied)
  @test.assert_eq(older.document.lookup_object_or_null(30), original_secret)
}

///|
async test "async file wrappers reconstruct encrypted incremental revisions with bad startxref" {
  let original_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_startxref_original",
  )
  let updated_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_startxref_incremental",
  )
  let corrupted_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_startxref_corrupted",
  )
  let repaired_path = pdf_async_io_test_path_for_test(
    "encrypted_bad_startxref_repaired",
  )
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  let original_secret = pdf_async_io_secret_object_for_test(
    "async malformed encrypted original",
  )
  let updated_secret = pdf_async_io_secret_object_for_test(
    "async malformed encrypted updated",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  doc.add_object_given_number(30, original_secret)
  let denied : Array[@pdflite.PdfPermission] = [PdfNoCopy, PdfNoEdit]
  let encrypted = try! doc.encrypt_128bit_aesv2_with_iv_provider(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    denied,
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async encrypted bad startxref iv"),
    ),
    encrypt_metadata=false,
    file_id=@ascii.encode("async-encrypted-bad-startxref-id"),
  )
  pdf_write_document_to_file(encrypted, original_path)
  let decrypted = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      original_path,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  decrypted.document.add_object_given_number(30, updated_secret)
  let recrypted = try! decrypted.document.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("owner"),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async encrypted bad startxref recrypt iv"),
    ),
  )
  pdf_write_document_incremental_update_with_compressed_xref_stream_to_file(
    original_path, recrypted, updated_path,
  )
  @test.assert_eq(pdf_revisions_from_file(updated_path), 2)
  let corrupted = pdf_async_io_corrupt_final_startxref_pointer_for_test(
    @fs.read_file(updated_path).binary(),
  )
  @fs.write_file(corrupted_path, corrupted, create=0o644)
  let recovered = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      corrupted_path,
      owner_password=Some(@ascii.encode("owner")),
    ),
  )
  @test.assert_eq(recovered.document.first_xref(), 0)
  @test.assert_eq(recovered.denied_permissions, denied)
  @test.assert_eq(recovered.document.lookup_object_or_null(30), updated_secret)
  let added_secret = pdf_async_io_secret_object_for_test(
    "async malformed encrypted repaired",
  )
  recovered.document.add_object_given_number(31, added_secret)
  let recovered_recrypted = try! recovered.document.recrypt_with_password_aesv2_with_iv_provider(
    @ascii.encode("owner"),
    @pdflite.pdf_deterministic_aes_iv_provider_from_seed(
      @ascii.encode("async encrypted bad startxref repair iv"),
    ),
  )
  pdf_write_document_to_file_with_compressed_xref_stream(
    recovered_recrypted, repaired_path,
  )
  let roundtrip = pdf_async_io_decryption_result_for_test(
    pdf_read_document_from_file_with_passwords(
      repaired_path,
      user_password=Some(@ascii.encode("user")),
    ),
  )
  pdf_async_io_remove_if_exists_for_test(original_path)
  pdf_async_io_remove_if_exists_for_test(updated_path)
  pdf_async_io_remove_if_exists_for_test(corrupted_path)
  pdf_async_io_remove_if_exists_for_test(repaired_path)
  @test.assert_eq(roundtrip.denied_permissions, denied)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(30), updated_secret)
  @test.assert_eq(roundtrip.document.lookup_object_or_null(31), added_secret)
}
