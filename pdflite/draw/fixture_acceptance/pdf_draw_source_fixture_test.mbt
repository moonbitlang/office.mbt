///|
fn draw_fixture_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
async fn draw_fixture_document_for_test(path : String) -> @pdflite.PdfDocument? {
  let read_result = try? @fs.read_file(draw_fixture_path_for_test(path))
  match read_result {
    Ok(data) => Some(@pdflite.pdf_read_document_from_bytes(data.binary()))
    Err(_) => None
  }
}

///|
async fn draw_fixture_bytes_for_test(path : String) -> Bytes? {
  let read_result = try? @fs.read_file(draw_fixture_path_for_test(path))
  match read_result {
    Ok(data) => Some(data.binary())
    Err(_) => None
  }
}

///|
fn draw_fixture_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn draw_fixture_bytes_start_with_at_for_test(
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
fn draw_fixture_find_last_bytes_for_test(
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
      if draw_fixture_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn draw_fixture_find_bytes_after_for_test(
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
      if draw_fixture_bytes_start_with_at_for_test(haystack, needle, position) {
        break position
      }
    } nobreak {
      -1
    }
  }
}

///|
fn draw_fixture_push_ascii_for_test(
  output : Array[Byte],
  text : String,
) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn draw_fixture_corrupt_startxref_pointer_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let marker = @ascii.encode("startxref")
  let marker_position = draw_fixture_find_last_bytes_for_test(bytes, marker)
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
  draw_fixture_push_ascii_for_test(output, (bytes.length() + 4096).to_string())
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn draw_fixture_startxref_offset_for_test(bytes : Bytes) -> Int raise {
  let marker = @ascii.encode("startxref")
  let marker_position = draw_fixture_find_last_bytes_for_test(bytes, marker)
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
fn draw_fixture_corrupt_startxref_xref_header_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let xref_offset = draw_fixture_startxref_offset_for_test(bytes)
  guard draw_fixture_bytes_start_with_at_for_test(
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
fn draw_fixture_corrupt_startxref_trailer_keyword_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let xref_offset = draw_fixture_startxref_offset_for_test(bytes)
  let trailer_position = draw_fixture_find_bytes_after_for_test(
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
fn draw_fixture_first_in_use_xref_row_start_for_test(
  bytes : Bytes,
) -> Int raise {
  let free_row = @ascii.encode("0000000000 65535 f")
  let free_row_position = draw_fixture_find_bytes_after_for_test(
    bytes, free_row, 0,
  )
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
fn draw_fixture_corrupt_first_in_use_xref_marker_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = draw_fixture_first_in_use_xref_row_start_for_test(bytes)
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
fn draw_fixture_corrupt_first_in_use_xref_offset_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = draw_fixture_first_in_use_xref_row_start_for_test(bytes)
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
fn draw_fixture_corrupt_first_in_use_xref_generation_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = draw_fixture_first_in_use_xref_row_start_for_test(bytes)
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
fn draw_fixture_first_xref_subsection_spans_for_test(
  bytes : Bytes,
) -> (Int, Int, Int, Int) raise {
  let header = @ascii.encode("xref")
  let header_position = draw_fixture_find_bytes_after_for_test(bytes, header, 0)
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
fn draw_fixture_corrupt_first_xref_subsection_object_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let (object_start, object_end, _, _) = draw_fixture_first_xref_subsection_spans_for_test(
    bytes,
  )
  let output : Array[Byte] = []
  for index in 0..<object_start {
    output.push(bytes[index])
  }
  draw_fixture_push_ascii_for_test(output, "/Bad")
  for index in object_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn draw_fixture_corrupt_first_xref_subsection_count_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let (_, _, count_start, count_end) = draw_fixture_first_xref_subsection_spans_for_test(
    bytes,
  )
  let output : Array[Byte] = []
  for index in 0..<count_start {
    output.push(bytes[index])
  }
  draw_fixture_push_ascii_for_test(output, "/Bad")
  for index in count_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn draw_fixture_matrix_for_test(
  a : Double,
  b : Double,
  c : Double,
  d : Double,
  e : Double,
  f : Double,
) -> @pdflite.TransformMatrix {
  { a, b, c, d, e, f }
}

///|
fn draw_fixture_lookup_for_test(
  document : @pdflite.PdfDocument,
  object : @pdflite.PdfObject,
  key : String,
) -> @pdflite.PdfObject raise {
  match document.lookup_direct(draw_fixture_name_for_test(key), object) {
    Some(value) => value
    None => {
      fail("missing dictionary key " + key)
      PdfNull
    }
  }
}

///|
fn draw_fixture_count_op_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  expected : @pdflite.PdfContentOp,
) -> Int {
  let mut count = 0
  for op in ops {
    if op == expected {
      count += 1
    }
  }
  count
}

///|
fn draw_fixture_assert_no_unknown_ops_for_test(
  path : String,
  ops : ArrayView[@pdflite.PdfContentOp],
) -> Unit raise {
  for op in ops {
    match op {
      Op_Unknown(_) => fail("unexpected unknown content operator in " + path)
      _ => ()
    }
  }
}

///|
fn draw_fixture_page_ops_for_test(
  document : @pdflite.PdfDocument,
) -> Array[@pdflite.PdfContentOp] raise {
  @test.assert_eq(document.endpage(), 1)
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  document.parse_content_ops_with_resources(
    pages[0].resources,
    pages[0].content,
  )
}

///|
fn draw_fixture_reparse_compressed_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  @pdflite.pdf_read_document_from_bytes(
    @pdflite.pdf_write_document_with_compressed_xref_stream(document),
  )
}

///|
fn draw_fixture_assert_contains_for_test(
  haystack : String,
  needle : String,
) -> Unit raise {
  guard haystack.contains(needle) else {
    fail("expected text to contain " + needle)
  }
}

///|
fn draw_fixture_assert_cpdf_text_content_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let pages = document.pages_of_pagetree()
  let entries = document.content_entries_of_page(pages[0])
  @test.assert_eq(entries.length() > 0, true)
  let mut has_glyph = false
  for entry in entries {
    match entry.object {
      PdfContentGlyphObject(_, _, extracted_text) => {
        has_glyph = true
        @test.assert_eq(extracted_text.length() > 0, true)
      }
      _ => ()
    }
  }
  @test.assert_eq(has_glyph, true)
  draw_fixture_assert_contains_for_test(
    @ascii.decode_lossy(document.test_extract_text([1])),
    "Hello",
  )
  let page_json = document.content_json_of_page(pages[0])
  @test.assert_eq(
    @pdflite.pdf_content_json_of_page(document, pages[0]),
    page_json,
  )
  let content_json = document.page_content_json([1])
  @test.assert_eq(@pdflite.pdf_page_content_json(document, [1]), content_json)
  let content_text = content_json.stringify()
  draw_fixture_assert_contains_for_test(content_text, "\"page\":1")
  draw_fixture_assert_contains_for_test(content_text, "\"obj\":\"glyph\"")
  draw_fixture_assert_contains_for_test(
    content_text, "\"extracted text\":\"H\"",
  )
}

///|
fn draw_fixture_assert_cpdf_xobject_content_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let pages = document.pages_of_pagetree()
  let entries = document.content_entries_of_page(pages[0])
  @test.assert_eq(entries.length() > 0, true)
  let mut has_path = false
  for entry in entries {
    match entry.object {
      PdfContentPathObject(_) => has_path = true
      _ => ()
    }
  }
  @test.assert_eq(has_path, true)
  let page_json = document.content_json_of_page(pages[0])
  @test.assert_eq(
    @pdflite.pdf_content_json_of_page(document, pages[0]),
    page_json,
  )
  let content_json = document.page_content_json([1])
  @test.assert_eq(@pdflite.pdf_page_content_json(document, [1]), content_json)
  let content_text = content_json.stringify()
  draw_fixture_assert_contains_for_test(content_text, "\"page\":1")
  draw_fixture_assert_contains_for_test(content_text, "\"obj\":\"path\"")
  draw_fixture_assert_contains_for_test(content_text, "\"bbox\"")
}

///|
fn draw_fixture_cpdf_source_manual_image_pdf_paths_for_test() -> Array[String] {
  [
    ".repos/cpdf-source/manualimages/bez.pdf", ".repos/cpdf-source/manualimages/capjoins.pdf",
    ".repos/cpdf-source/manualimages/clip.pdf", ".repos/cpdf-source/manualimages/colfill.pdf",
    ".repos/cpdf-source/manualimages/dash.pdf", ".repos/cpdf-source/manualimages/fill.pdf",
    ".repos/cpdf-source/manualimages/fontparams.pdf", ".repos/cpdf-source/manualimages/fonts.pdf",
    ".repos/cpdf-source/manualimages/h1.pdf", ".repos/cpdf-source/manualimages/line.pdf",
    ".repos/cpdf-source/manualimages/lines.pdf", ".repos/cpdf-source/manualimages/matrix.pdf",
    ".repos/cpdf-source/manualimages/para.pdf", ".repos/cpdf-source/manualimages/paras.pdf",
    ".repos/cpdf-source/manualimages/png.pdf", ".repos/cpdf-source/manualimages/pop.pdf",
    ".repos/cpdf-source/manualimages/stext.pdf", ".repos/cpdf-source/manualimages/text.pdf",
    ".repos/cpdf-source/manualimages/textclip.pdf", ".repos/cpdf-source/manualimages/trans.pdf",
    ".repos/cpdf-source/manualimages/xobj.pdf",
  ]
}

///|
fn draw_fixture_assert_manual_image_content_for_test(
  document : @pdflite.PdfDocument,
  path : String,
) -> Unit raise {
  let ops = draw_fixture_page_ops_for_test(document)
  guard ops.length() > 0 else { fail("expected content ops in " + path) }
  draw_fixture_assert_no_unknown_ops_for_test(path, ops)
}

///|
async test "cpdf source non-image manual fixtures parse without unknown operators" {
  for
    path in [
      ".repos/cpdf-source/manualimages/bez.pdf", ".repos/cpdf-source/manualimages/capjoins.pdf",
      ".repos/cpdf-source/manualimages/clip.pdf", ".repos/cpdf-source/manualimages/colfill.pdf",
      ".repos/cpdf-source/manualimages/dash.pdf", ".repos/cpdf-source/manualimages/fill.pdf",
      ".repos/cpdf-source/manualimages/fontparams.pdf", ".repos/cpdf-source/manualimages/fonts.pdf",
      ".repos/cpdf-source/manualimages/h1.pdf", ".repos/cpdf-source/manualimages/line.pdf",
      ".repos/cpdf-source/manualimages/lines.pdf", ".repos/cpdf-source/manualimages/matrix.pdf",
      ".repos/cpdf-source/manualimages/para.pdf", ".repos/cpdf-source/manualimages/paras.pdf",
      ".repos/cpdf-source/manualimages/pop.pdf", ".repos/cpdf-source/manualimages/stext.pdf",
      ".repos/cpdf-source/manualimages/text.pdf", ".repos/cpdf-source/manualimages/textclip.pdf",
      ".repos/cpdf-source/manualimages/trans.pdf", ".repos/cpdf-source/manualimages/xobj.pdf",
    ] {
    match draw_fixture_document_for_test(path) {
      None => ()
      Some(document) => {
        let ops = draw_fixture_page_ops_for_test(document)
        guard ops.length() > 0 else { fail("expected content ops in " + path) }
        draw_fixture_assert_no_unknown_ops_for_test(path, ops)
      }
    }
  }
}

///|
async test "cpdf source manual image PDF corpus reconstructs malformed xref data for draw parsing" {
  let mut checked = 0
  for path in draw_fixture_cpdf_source_manual_image_pdf_paths_for_test() {
    match draw_fixture_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        for
          corrupted in [
            draw_fixture_corrupt_startxref_pointer_for_test(bytes),
            draw_fixture_corrupt_startxref_xref_header_for_test(bytes),
            draw_fixture_corrupt_startxref_trailer_keyword_for_test(bytes),
            draw_fixture_corrupt_first_in_use_xref_marker_for_test(bytes),
            draw_fixture_corrupt_first_in_use_xref_offset_for_test(bytes),
            draw_fixture_corrupt_first_in_use_xref_generation_for_test(bytes),
            draw_fixture_corrupt_first_xref_subsection_object_for_test(bytes),
            draw_fixture_corrupt_first_xref_subsection_count_for_test(bytes),
          ] {
          let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
            corrupted,
          )
          guard strict is Err(_) else {
            fail(
              "expected malformed xref data to require reconstruction for " +
              path,
            )
          }
          let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
          @test.assert_eq(recovered.first_xref(), 0)
          draw_fixture_assert_manual_image_content_for_test(recovered, path)
          draw_fixture_assert_manual_image_content_for_test(
            draw_fixture_reparse_compressed_for_test(recovered),
            path,
          )
        }
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      draw_fixture_cpdf_source_manual_image_pdf_paths_for_test().length(),
    )
  }
}

///|
async test "cpdf source manual content fixtures export content JSON" {
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/text.pdf") {
    None => ()
    Some(document) => {
      draw_fixture_assert_cpdf_text_content_for_test(document)
      draw_fixture_assert_cpdf_text_content_for_test(
        draw_fixture_reparse_compressed_for_test(document),
      )
    }
  }
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/xobj.pdf") {
    None => ()
    Some(document) => {
      draw_fixture_assert_cpdf_xobject_content_for_test(document)
      draw_fixture_assert_cpdf_xobject_content_for_test(
        draw_fixture_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "cpdf source capjoins manual fixture parses line cap join operators" {
  match
    draw_fixture_document_for_test(
      ".repos/cpdf-source/manualimages/capjoins.pdf",
    ) {
    None => ()
    Some(document) =>
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_m(100.0, 100.0),
        Op_j(1),
        Op_J(1),
        Op_M(1.0),
        Op_w(40.0),
        Op_l(200.0, 200.0),
        Op_l(220.0, 100.0),
        Op_S,
      ])
  }
}

///|
async test "cpdf source bezier and paint manual fixtures parse path operators" {
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/bez.pdf") {
    None => ()
    Some(document) =>
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_m(100.0, 100.0),
        Op_c(400.0, 600.0, 600.0, 400.0, 300.0, 300.0),
        Op_S,
      ])
  }
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/line.pdf") {
    None => ()
    Some(document) =>
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_m(100.0, 100.0),
        Op_l(400.0, 400.0),
        Op_l(400.0, 100.0),
        Op_h,
        Op_S,
      ])
  }
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/fill.pdf") {
    None => ()
    Some(document) =>
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_m(100.0, 100.0),
        Op_l(400.0, 400.0),
        Op_l(400.0, 100.0),
        Op_h,
        Op_f,
      ])
  }
}

///|
async test "cpdf source xobject manual fixture parses form resource reuse" {
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/xobj.pdf") {
    None => ()
    Some(document) => {
      let pages = document.pages_of_pagetree()
      @test.assert_eq(pages.length(), 1)
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_Do(draw_fixture_name_for_test("/X1")),
        Op_RG(1.0, 0.0, 0.0),
        Op_cm(@pdflite.transform_translate(20.0, 20.0)),
        Op_Do(draw_fixture_name_for_test("/X1")),
      ])
      let xobjects = draw_fixture_lookup_for_test(
        document,
        pages[0].resources,
        "/XObject",
      )
      guard draw_fixture_lookup_for_test(document, xobjects, "/X1")
        is PdfStreamObject(form_stream) else {
        fail("expected /X1 form stream")
      }
      @test.assert_eq(
        draw_fixture_lookup_for_test(
          document,
          form_stream.dictionary,
          "/Subtype",
        ),
        PdfNameObject(draw_fixture_name_for_test("/Form")),
      )
      @test.assert_eq(
        draw_fixture_lookup_for_test(document, form_stream.dictionary, "/BBox"),
        PdfArray([
          PdfInteger(0),
          PdfInteger(0),
          PdfInteger(200),
          PdfInteger(200),
        ]),
      )
      let form_resources = draw_fixture_lookup_for_test(
        document,
        form_stream.dictionary,
        "/Resources",
      )
      @test.assert_eq(
        document.parse_content_ops_with_resources(form_resources, [
          PdfStreamObject(form_stream),
        ]),
        [
          Op_m(150.0, 100.0),
          Op_c(150.0, 127.614237492, 127.614237492, 150.0, 100.0, 150.0),
          Op_c(72.3857625085, 150.0, 50.0, 127.614237492, 50.0, 100.0),
          Op_c(50.0, 72.3857625085, 72.3857625085, 50.0, 100.0, 50.0),
          Op_c(127.614237492, 50.0, 150.0, 72.3857625085, 150.0, 100.0),
          Op_S,
        ],
      )
    }
  }
}

///|
async test "cpdf source clipping and colour manual fixtures parse graphics operators" {
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/clip.pdf") {
    None => ()
    Some(document) => {
      let ops = draw_fixture_page_ops_for_test(document)
      @test.assert_eq(ops.length(), 13)
      @test.assert_eq(ops[0], Op_m(400.0, 300.0))
      @test.assert_eq(ops[5], Op_W)
      @test.assert_eq(ops[6], Op_n)
      @test.assert_eq(ops[12], Op_f)
    }
  }
  match
    draw_fixture_document_for_test(
      ".repos/cpdf-source/manualimages/colfill.pdf",
    ) {
    None => ()
    Some(document) => {
      let ops = draw_fixture_page_ops_for_test(document)
      @test.assert_eq(ops.length(), 9)
      @test.assert_eq(ops[0], Op_w(20.0))
      @test.assert_eq(ops[6], Op_G(0.5))
      @test.assert_eq(ops[7], Op_rg(0.2, 0.7, 0.2))
      @test.assert_eq(ops[8], Op_B)
    }
  }
}

///|
async test "cpdf source matrix manual fixture parses save restore transforms" {
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/matrix.pdf") {
    None => ()
    Some(document) => {
      let ops = draw_fixture_page_ops_for_test(document)
      @test.assert_eq(ops.length(), 22)
      @test.assert_eq(ops[5], Op_S)
      @test.assert_eq(ops[6], Op_q)
      @test.assert_eq(
        ops[7],
        Op_cm(
          draw_fixture_matrix_for_test(
            0.955336489126, -0.295520206661, 0.295520206661, 0.955336489126, 0.0,
            0.0,
          ),
        ),
      )
      @test.assert_eq(
        ops[8],
        Op_cm(draw_fixture_matrix_for_test(1.5, 0.0, 0.0, 2.0, 0.0, 0.0)),
      )
      @test.assert_eq(ops[15], Op_Q)
      @test.assert_eq(ops[21], Op_f)
    }
  }
}

///|
async test "cpdf source textclip manual fixture parses clipping text mode" {
  match
    draw_fixture_document_for_test(
      ".repos/cpdf-source/manualimages/textclip.pdf",
    ) {
    None => ()
    Some(document) => {
      let ops = draw_fixture_page_ops_for_test(document)
      @test.assert_eq(ops.length(), 19)
      @test.assert_eq(ops[0], Op_Tr(7))
      @test.assert_eq(ops[1], Op_cm(@pdflite.transform_translate(100.0, 200.0)))
      @test.assert_eq(ops[2], Op_TL(55.0))
      @test.assert_eq(draw_fixture_count_op_for_test(ops, Op_Tstar), 2)
      @test.assert_eq(ops[18], Op_f)
    }
  }
}

///|
async test "cpdf source transparency manual fixture exposes extgstate and fill ops" {
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/trans.pdf") {
    None => ()
    Some(document) => {
      let pages = document.pages_of_pagetree()
      @test.assert_eq(pages.length(), 1)
      let extgstate = draw_fixture_lookup_for_test(
        document,
        pages[0].resources,
        "/ExtGState",
      )
      let graphics_state = draw_fixture_lookup_for_test(
        document, extgstate, "/G1",
      )
      @test.assert_eq(
        draw_fixture_lookup_for_test(document, graphics_state, "/ca"),
        PdfReal(0.5),
      )
      let ops = draw_fixture_page_ops_for_test(document)
      @test.assert_eq(ops[0], Op_gs(draw_fixture_name_for_test("/G1")))
      let mut fill_count = 0
      for op in ops {
        if op == Op_f {
          fill_count += 1
        }
      }
      @test.assert_eq(fill_count, 2)
    }
  }
}

///|
async test "cpdf source fontparams manual fixture parses text-state operators" {
  match
    draw_fixture_document_for_test(
      ".repos/cpdf-source/manualimages/fontparams.pdf",
    ) {
    None => ()
    Some(document) =>
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_cm(@pdflite.transform_translate(10.0, 20.0)),
        Op_BT,
        Op_Tz(75.0),
        Op_Tc(5.0),
        Op_Tw(20.0),
        Op_Tf(draw_fixture_name_for_test("/F1"), 72.0),
        Op_Tj(@ascii.encode("Different ")),
        Op_Tf(draw_fixture_name_for_test("/F2"), 72.0),
        Op_Tj(@ascii.encode("fonts")),
        Op_Ts(40.0),
        Op_Tf(draw_fixture_name_for_test("/F2"), 36.0),
        Op_Tj(@ascii.encode(" and sizes")),
        Op_ET,
      ])
  }
}

///|
async test "cpdf source dash manual fixture parses dash operators" {
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/dash.pdf") {
    None => ()
    Some(document) =>
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_m(100.0, 100.0),
        Op_w(20.0),
        Op_d([30.0, 20.0], 0.0),
        Op_l(400.0, 300.0),
        Op_S,
      ])
  }
}

///|
async test "cpdf source text manual fixture parses text section operators" {
  match
    draw_fixture_document_for_test(".repos/cpdf-source/manualimages/text.pdf") {
    None => ()
    Some(document) =>
      @test.assert_eq(draw_fixture_page_ops_for_test(document), [
        Op_cm(@pdflite.transform_translate(50.0, 50.0)),
        Op_BT,
        Op_Tf(draw_fixture_name_for_test("/F1"), 144.0),
        Op_Tj(@ascii.encode("Hello")),
        Op_ET,
      ])
  }
}
