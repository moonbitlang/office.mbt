///|
fn image_external_fixture_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
fn image_external_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
async fn image_external_fixture_document_for_test(
  path : String,
) -> @pdflite.PdfDocument? {
  let read_result = try? @fs.read_file(
    image_external_fixture_path_for_test(path),
  )
  match read_result {
    Ok(data) => Some(@pdflite.pdf_read_document_from_bytes(data.binary()))
    Err(_) => None
  }
}

///|
async fn image_external_fixture_bytes_for_test(path : String) -> Bytes? {
  let read_result = try? @fs.read_file(
    image_external_fixture_path_for_test(path),
  )
  match read_result {
    Ok(data) => Some(data.binary())
    Err(_) => None
  }
}

///|
fn image_external_bytes_start_with_at_for_test(
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
fn image_external_find_last_bytes_for_test(
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
      if image_external_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn image_external_find_bytes_for_test(
  haystack : BytesView,
  needle : BytesView,
) -> Int {
  if needle.length() == 0 {
    0
  } else if haystack.length() < needle.length() {
    -1
  } else {
    for start in 0..<=(haystack.length() - needle.length()) {
      if image_external_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn image_external_find_bytes_after_for_test(
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
      if image_external_bytes_start_with_at_for_test(haystack, needle, position) {
        break position
      }
    } nobreak {
      -1
    }
  }
}

///|
fn image_external_push_ascii_for_test(
  output : Array[Byte],
  text : String,
) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn image_external_corrupt_startxref_pointer_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let marker = @ascii.encode("startxref")
  let marker_position = image_external_find_last_bytes_for_test(bytes, marker)
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
  image_external_push_ascii_for_test(
    output,
    (bytes.length() + 4096).to_string(),
  )
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn image_external_startxref_offset_for_test(bytes : Bytes) -> Int raise {
  let marker = @ascii.encode("startxref")
  let marker_position = image_external_find_last_bytes_for_test(bytes, marker)
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
fn image_external_corrupt_startxref_xref_header_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let xref_offset = image_external_startxref_offset_for_test(bytes)
  guard image_external_bytes_start_with_at_for_test(
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
fn image_external_corrupt_startxref_trailer_keyword_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let xref_offset = image_external_startxref_offset_for_test(bytes)
  let trailer_position = image_external_find_bytes_after_for_test(
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
fn image_external_first_in_use_xref_row_start_for_test(
  bytes : Bytes,
) -> Int raise {
  let free_row = @ascii.encode("0000000000 65535 f")
  let free_row_position = image_external_find_bytes_for_test(bytes, free_row)
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
fn image_external_corrupt_first_in_use_xref_marker_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = image_external_first_in_use_xref_row_start_for_test(bytes)
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
fn image_external_corrupt_first_in_use_xref_offset_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = image_external_first_in_use_xref_row_start_for_test(bytes)
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
fn image_external_corrupt_first_in_use_xref_generation_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = image_external_first_in_use_xref_row_start_for_test(bytes)
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
fn image_external_first_xref_subsection_spans_for_test(
  bytes : Bytes,
) -> (Int, Int, Int, Int) raise {
  let header = @ascii.encode("xref")
  let header_position = image_external_find_bytes_for_test(bytes, header)
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
fn image_external_corrupt_first_xref_subsection_object_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let (object_start, object_end, _, _) = image_external_first_xref_subsection_spans_for_test(
    bytes,
  )
  let output : Array[Byte] = []
  for index in 0..<object_start {
    output.push(bytes[index])
  }
  image_external_push_ascii_for_test(output, "/Bad")
  for index in object_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn image_external_corrupt_first_xref_subsection_count_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let (_, _, count_start, count_end) = image_external_first_xref_subsection_spans_for_test(
    bytes,
  )
  let output : Array[Byte] = []
  for index in 0..<count_start {
    output.push(bytes[index])
  }
  image_external_push_ascii_for_test(output, "/Bad")
  for index in count_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn image_external_images_for_test(
  document : @pdflite.PdfDocument,
) -> Array[@pdflite.PdfImage] raise {
  let subtype_key = image_external_name_for_test("/Subtype")
  let image_name = image_external_name_for_test("/Image")
  let resources = @pdflite.pdf_dictionary([])
  let images : Array[@pdflite.PdfImage] = []
  for number in document.object_numbers() {
    let object = document.lookup_object_or_null(number)
    if object.lookup_immediate(subtype_key) == Some(PdfNameObject(image_name)) {
      images.push(document.get_image_24bpp(resources, object))
    }
  }
  images
}

///|
async fn image_external_images_from_fixture_for_test(
  path : String,
) -> Array[@pdflite.PdfImage]? {
  match image_external_fixture_document_for_test(path) {
    Some(document) => Some(image_external_images_for_test(document))
    None => None
  }
}

///|
fn image_external_reparse_compressed_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  @pdflite.pdf_read_document_from_bytes(
    @pdflite.pdf_write_document_with_compressed_xref_stream(document),
  )
}

///|
fn image_external_cpdf_source_manual_image_pdf_paths_for_test() -> Array[String] {
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
fn image_external_assert_cpdf_manual_image_page_for_test(
  document : @pdflite.PdfDocument,
  path : String,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let ops = document.parse_content_ops(pages[0].content)
  guard ops.length() > 0 else {
    fail("expected cpdf source manual-image content ops for " + path)
  }
}

///|
fn image_external_assert_jpeg_for_test(
  images : Array[@pdflite.PdfImage],
) -> Unit raise {
  @test.assert_eq(images.length(), 1)
  match images[0] {
    PdfJPEG(data, decode) => {
      @test.assert_eq(data.length() > 40000, true)
      @test.assert_eq(decode, Some([0.0, 1.0, 0.0, 1.0, 0.0, 1.0]))
    }
    _ => fail("expected JPEG image payload")
  }
}

///|
fn image_external_assert_raw_rgb_for_test(
  images : Array[@pdflite.PdfImage],
  width : Int,
  height : Int,
  message : String,
) -> Unit raise {
  @test.assert_eq(images.length(), 1)
  match images[0] {
    PdfRawImage(actual_width, actual_height, layout, data) => {
      @test.assert_eq(actual_width, width)
      @test.assert_eq(actual_height, height)
      @test.assert_eq(layout, PdfBPP24)
      @test.assert_eq(data.length(), width * height * 3)
    }
    _ => fail(message)
  }
}

///|
fn image_external_assert_contains_for_test(
  haystack : String,
  needle : String,
) -> Unit raise {
  guard haystack.contains(needle) else {
    fail("expected text to contain " + needle)
  }
}

///|
fn image_external_draft_substitute_ops_for_test() -> Array[
  @pdflite.PdfContentOp,
] {
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
fn image_external_content_ops_contain_sequence_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  expected : ArrayView[@pdflite.PdfContentOp],
) -> Bool {
  if expected.length() == 0 {
    true
  } else if ops.length() < expected.length() {
    false
  } else {
    for start in 0..<=(ops.length() - expected.length()) {
      let mut matches = true
      for offset in 0..<expected.length() {
        if ops[start + offset] != expected[offset] {
          matches = false
        }
      }
      if matches {
        break true
      }
    } nobreak {
      false
    }
  }
}

///|
fn image_external_content_ops_contain_do_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  name : @pdflite.PdfName,
) -> Bool {
  for op in ops {
    match op {
      Op_Do(op_name) if op_name == name => break true
      _ => ()
    }
  } nobreak {
    false
  }
}

///|
fn image_external_assert_cpdf_png_draft_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let image_name = image_external_name_for_test("/I1")
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  guard document.lookup_direct(
      image_external_name_for_test("/XObject"),
      pages[0].resources,
    )
    is Some(PdfDictionary(xobjects)) else {
    fail("missing drafted PNG fixture XObject resources")
  }
  @test.assert_eq(xobjects.length(), 0)
  let ops = document.parse_content_ops_with_resources(
    pages[0].resources,
    pages[0].content,
  )
  @test.assert_eq(
    image_external_content_ops_contain_do_for_test(ops, image_name),
    false,
  )
  @test.assert_eq(
    image_external_content_ops_contain_sequence_for_test(
      ops,
      image_external_draft_substitute_ops_for_test(),
    ),
    true,
  )
  let images_json = document.images_json([1]).stringify()
  @test.assert_eq(images_json.contains("\"Name\""), false)
  @test.assert_eq(images_json.contains("\"Width\""), false)
}

///|
fn image_external_assert_cpdf_manual_extracted_image_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  match document.get_image_24bpp(PdfDictionary([]), PdfIndirect(1477)) {
    PdfRawImage(width, height, PdfBPP24, data) => {
      @test.assert_eq(width, 400)
      @test.assert_eq(height, 294)
      @test.assert_eq(data.length(), 400 * 294 * 3)
      @test.assert_eq(data[0].to_int(), 255)
      @test.assert_eq(data[1].to_int(), 255)
      @test.assert_eq(data[2].to_int(), 255)
      let middle_pixel = (147 * 400 + 200) * 3
      @test.assert_eq(data[middle_pixel].to_int(), 250)
      @test.assert_eq(data[middle_pixel + 1].to_int(), 250)
      @test.assert_eq(data[middle_pixel + 2].to_int(), 250)
    }
    _ => fail("expected cpdf manual embedded image to decode as 24bpp")
  }
}

///|
fn image_external_assert_cpdf_manual_image_reporting_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let all_pages = document.parse_pagespec("")
  let images = document.images_json(all_pages)
  @test.assert_eq(@pdflite.pdf_image_images(false, document, all_pages), images)
  let images_json = images.stringify()
  image_external_assert_contains_for_test(images_json, "\"Object\":1477")
  image_external_assert_contains_for_test(images_json, "\"Pages\":[128]")
  image_external_assert_contains_for_test(images_json, "\"Width\":400")
  image_external_assert_contains_for_test(images_json, "\"Height\":294")
  image_external_assert_contains_for_test(images_json, "\"BitsPerComponent\":8")
  image_external_assert_contains_for_test(
    images_json, "\"Colourspace\":\"/DeviceRGB\"",
  )
  image_external_assert_contains_for_test(
    images_json, "\"Filter\":\"/FlateDecode\"",
  )
  let images_blob = @ascii.decode_lossy(document.images_json_blob(all_pages))
  image_external_assert_contains_for_test(images_blob, "\"Width\":400")
  image_external_assert_contains_for_test(images_blob, "\"Height\":294")
  @test.assert_eq(
    @pdflite.pdf_image_images_json_blob(false, document, all_pages),
    document.images_json_blob(all_pages),
  )
  let resolution = document.image_resolution(all_pages, 1000000.0)
  @test.assert_eq(
    @pdflite.pdf_image_resolution(false, document, all_pages, 1000000.0),
    resolution,
  )
  let mut has_embedded_image_resolution = false
  for entry in resolution {
    if entry.0 == 128 && entry.2 == 400 && entry.3 == 294 && entry.6 == 1477 {
      has_embedded_image_resolution = true
    }
  }
  @test.assert_eq(has_embedded_image_resolution, true)
  let resolution_json_object = document.image_resolution_json(
    all_pages, 1000000.0,
  )
  @test.assert_eq(
    @pdflite.pdf_image_resolution_json(false, document, all_pages, 1000000.0),
    resolution_json_object,
  )
  let resolution_json = resolution_json_object.stringify()
  image_external_assert_contains_for_test(resolution_json, "\"Page\":128")
  image_external_assert_contains_for_test(resolution_json, "\"W\":400")
  image_external_assert_contains_for_test(resolution_json, "\"H\":294")
  @test.assert_eq(
    @pdflite.pdf_image_resolution_json_blob(
      false, document, all_pages, 1000000.0,
    ),
    document.image_resolution_json_blob(all_pages, 1000000.0),
  )
  image_external_assert_cpdf_manual_extracted_image_for_test(document)
}

///|
fn image_external_assert_cpdf_source_hello_text_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  image_external_assert_contains_for_test(
    @ascii.decode_lossy(document.test_extract_text([1])),
    "Hello, World!",
  )
}

///|
fn image_external_cpdf_source_inline_image_dictionary_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (image_external_name_for_test("/W"), PdfInteger(3)),
    (image_external_name_for_test("/H"), PdfInteger(2)),
    (image_external_name_for_test("/BPC"), PdfInteger(8)),
    (
      image_external_name_for_test("/CS"),
      PdfNameObject(image_external_name_for_test("/DeviceRGB")),
    ),
  ])
}

///|
fn image_external_cpdf_source_hello_with_inline_image_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let image_ops : Array[@pdflite.PdfContentOp] = [
    Op_cm({ a: 72.0, b: 0.0, c: 0.0, d: 72.0, e: 0.0, f: 0.0 }),
    Op_InlineImage(
      image_external_cpdf_source_inline_image_dictionary_for_test(),
      None,
      @ascii.encode("abcdefghijklmnopqr"),
    ),
  ]
  let updated_page = document.postpend_operators(pages[0], image_ops, fast=true)
  document.change_pages([updated_page], change_references=true)
}

///|
fn image_external_assert_cpdf_source_inline_image_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  image_external_assert_cpdf_source_hello_text_for_test(document)
  let xobject_images = document.images_json([1])
  @test.assert_eq(
    @pdflite.pdf_image_images(false, document, [1]),
    xobject_images,
  )
  @test.assert_eq(xobject_images.stringify(), "[]")
  @test.assert_eq(document.image_resolution([1], 1000000.0), [])
  let inline_images = document.images_json([1], inline=true)
  @test.assert_eq(@pdflite.pdf_image_images(true, document, [1]), inline_images)
  let inline_images_json = inline_images.stringify()
  image_external_assert_contains_for_test(inline_images_json, "\"Object\":0")
  image_external_assert_contains_for_test(
    inline_images_json, "\"Name\":\"/InlineImage\"",
  )
  image_external_assert_contains_for_test(inline_images_json, "\"Pages\":[1]")
  image_external_assert_contains_for_test(inline_images_json, "\"Width\":3")
  image_external_assert_contains_for_test(inline_images_json, "\"Height\":2")
  image_external_assert_contains_for_test(inline_images_json, "\"Bytes\":18")
  image_external_assert_contains_for_test(
    inline_images_json, "\"BitsPerComponent\":8",
  )
  image_external_assert_contains_for_test(
    inline_images_json, "\"Colourspace\":\"/DeviceRGB\"",
  )
  image_external_assert_contains_for_test(inline_images_json, "\"Filter\":null")
  @test.assert_eq(
    @pdflite.pdf_image_images_json_blob(true, document, [1]),
    document.images_json_blob([1], inline=true),
  )
  let inline_resolution = document.image_resolution([1], 1000000.0, inline=true)
  @test.assert_eq(
    @pdflite.pdf_image_resolution(true, document, [1], 1000000.0),
    inline_resolution,
  )
  @test.assert_eq(inline_resolution, [(1, "/InlineImage", 3, 2, 3.0, 2.0, 0)])
  let inline_resolution_json = document.image_resolution_json(
    [1],
    1000000.0,
    inline=true,
  )
  @test.assert_eq(
    @pdflite.pdf_image_resolution_json(true, document, [1], 1000000.0),
    inline_resolution_json,
  )
  let inline_resolution_text = inline_resolution_json.stringify()
  image_external_assert_contains_for_test(
    inline_resolution_text, "\"XObject\":\"/InlineImage\"",
  )
  image_external_assert_contains_for_test(inline_resolution_text, "\"W\":3")
  image_external_assert_contains_for_test(inline_resolution_text, "\"H\":2")
  image_external_assert_contains_for_test(inline_resolution_text, "\"Xdpi\":3")
  image_external_assert_contains_for_test(inline_resolution_text, "\"Ydpi\":2")
  @test.assert_eq(
    @pdflite.pdf_image_resolution_json_blob(true, document, [1], 1000000.0),
    document.image_resolution_json_blob([1], 1000000.0, inline=true),
  )
}

///|
fn image_external_cpdf_source_nested_image_data_for_test() -> @pdflite.PdfBytes raise {
  @pdflite.pdf_flate_encode(@pdflite.pdf_bytes_of_int_array([0, 64, 128, 255]))
}

///|
fn image_external_cpdf_source_nested_image_for_test() -> @pdflite.PdfObject raise {
  let data = image_external_cpdf_source_nested_image_data_for_test()
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        image_external_name_for_test("/Type"),
        PdfNameObject(image_external_name_for_test("/XObject")),
      ),
      (
        image_external_name_for_test("/Subtype"),
        PdfNameObject(image_external_name_for_test("/Image")),
      ),
      (image_external_name_for_test("/Width"), PdfInteger(2)),
      (image_external_name_for_test("/Height"), PdfInteger(2)),
      (image_external_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        image_external_name_for_test("/ColorSpace"),
        PdfNameObject(image_external_name_for_test("/DeviceGray")),
      ),
      (
        image_external_name_for_test("/Filter"),
        PdfNameObject(image_external_name_for_test("/FlateDecode")),
      ),
      (image_external_name_for_test("/Length"), PdfInteger(data.length())),
    ]),
    StreamGot(data),
  )
}

///|
fn image_external_cpdf_source_form_image_form_for_test(
  image_number : Int,
) -> @pdflite.PdfObject raise {
  @pdflite.pdf_content_stream_of_ops([
    Op_cm({ a: 72.0, b: 0.0, c: 0.0, d: 72.0, e: 72.0, f: 72.0 }),
    Op_Do(image_external_name_for_test("/SourceNestedImage")),
  ])
  .add_dict_entry(
    image_external_name_for_test("/Type"),
    PdfNameObject(image_external_name_for_test("/XObject")),
  )
  .add_dict_entry(
    image_external_name_for_test("/Subtype"),
    PdfNameObject(image_external_name_for_test("/Form")),
  )
  .add_dict_entry(
    image_external_name_for_test("/BBox"),
    PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(72), PdfInteger(72)]),
  )
  .add_dict_entry(
    image_external_name_for_test("/Resources"),
    @pdflite.pdf_dictionary([
      (
        image_external_name_for_test("/XObject"),
        @pdflite.pdf_dictionary([
          (
            image_external_name_for_test("/SourceNestedImage"),
            PdfIndirect(image_number),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn image_external_cpdf_source_page_xobjects_for_test(
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
) -> @pdflite.PdfObject raise {
  match
    document.lookup_direct(image_external_name_for_test("/XObject"), resources) {
    Some(PdfDictionary(entries)) => PdfDictionary(entries)
    Some(_) => fail("expected source page XObject resources to be a dictionary")
    None => @pdflite.pdf_dictionary([])
  }
}

///|
fn image_external_cpdf_source_hello_with_form_image_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let output = document.copy()
  let image_number = output.add_object(
    image_external_cpdf_source_nested_image_for_test(),
  )
  let form_number = output.add_object(
    image_external_cpdf_source_form_image_form_for_test(image_number),
  )
  let pages = output.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let xobjects = image_external_cpdf_source_page_xobjects_for_test(
    output,
    pages[0].resources,
  ).add_dict_entry(
    image_external_name_for_test("/SourceImageForm"),
    PdfIndirect(form_number),
  )
  let resources = pages[0].resources.add_dict_entry(
    image_external_name_for_test("/XObject"),
    xobjects,
  )
  let page = { ..pages[0], resources, }
  let updated_page = output.postpend_operators(
    page,
    [Op_q, Op_Do(image_external_name_for_test("/SourceImageForm")), Op_Q],
    fast=true,
  )
  output.change_pages([updated_page], change_references=true)
}

///|
fn image_external_cpdf_source_form_image_resources_for_test(
  document : @pdflite.PdfDocument,
) -> (@pdflite.PdfObject, @pdflite.PdfObject) raise {
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  guard document.lookup_direct(
      image_external_name_for_test("/XObject"),
      pages[0].resources,
    )
    is Some(page_xobjects) else {
    fail("missing source page XObject resources")
  }
  guard document.lookup_direct(
      image_external_name_for_test("/SourceImageForm"),
      page_xobjects,
    )
    is Some(form) else {
    fail("missing source nested image form")
  }
  guard document.lookup_direct(image_external_name_for_test("/Resources"), form)
    is Some(form_resources) else {
    fail("missing source nested image form resources")
  }
  (form, form_resources)
}

///|
fn image_external_cpdf_source_nested_image_for_document_for_test(
  document : @pdflite.PdfDocument,
  form_resources : @pdflite.PdfObject,
) -> @pdflite.PdfObject raise {
  guard document.lookup_direct(
      image_external_name_for_test("/XObject"),
      form_resources,
    )
    is Some(form_xobjects) else {
    fail("missing source nested form XObject resources")
  }
  guard document.lookup_direct(
      image_external_name_for_test("/SourceNestedImage"),
      form_xobjects,
    )
    is Some(image) else {
    fail("missing source nested image XObject")
  }
  image
}

///|
fn image_external_assert_cpdf_source_form_image_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  image_external_assert_cpdf_source_hello_text_for_test(document)
  let images = document.images_json([1])
  @test.assert_eq(@pdflite.pdf_image_images(false, document, [1]), images)
  let images_json = images.stringify()
  image_external_assert_contains_for_test(
    images_json, "\"Name\":\"/SourceNestedImage\"",
  )
  image_external_assert_contains_for_test(images_json, "\"Pages\":[1]")
  image_external_assert_contains_for_test(images_json, "\"Width\":2")
  image_external_assert_contains_for_test(images_json, "\"Height\":2")
  image_external_assert_contains_for_test(
    images_json,
    "\"Bytes\":" +
    image_external_cpdf_source_nested_image_data_for_test().length().to_string(),
  )
  image_external_assert_contains_for_test(images_json, "\"BitsPerComponent\":8")
  image_external_assert_contains_for_test(
    images_json, "\"Colourspace\":\"/DeviceGray\"",
  )
  image_external_assert_contains_for_test(
    images_json, "\"Filter\":\"/FlateDecode\"",
  )
  @test.assert_eq(
    @pdflite.pdf_image_images_json_blob(false, document, [1]),
    document.images_json_blob([1]),
  )
  let resolution = document.image_resolution([1], 1000000.0)
  @test.assert_eq(
    @pdflite.pdf_image_resolution(false, document, [1], 1000000.0),
    resolution,
  )
  @test.assert_eq(resolution.length(), 1)
  @test.assert_eq(resolution[0].0, 1)
  @test.assert_eq(resolution[0].1, "/SourceNestedImage")
  @test.assert_eq(resolution[0].2, 2)
  @test.assert_eq(resolution[0].3, 2)
  @test.assert_eq(resolution[0].4, 2.0)
  @test.assert_eq(resolution[0].5, 2.0)
  @test.assert_eq(resolution[0].6 > 0, true)
  let resolution_json = document.image_resolution_json([1], 1000000.0)
  @test.assert_eq(
    @pdflite.pdf_image_resolution_json(false, document, [1], 1000000.0),
    resolution_json,
  )
  let resolution_text = resolution_json.stringify()
  image_external_assert_contains_for_test(
    resolution_text, "\"XObject\":\"/SourceNestedImage\"",
  )
  image_external_assert_contains_for_test(resolution_text, "\"W\":2")
  image_external_assert_contains_for_test(resolution_text, "\"H\":2")
  image_external_assert_contains_for_test(resolution_text, "\"Xdpi\":2")
  image_external_assert_contains_for_test(resolution_text, "\"Ydpi\":2")
  @test.assert_eq(
    @pdflite.pdf_image_resolution_json_blob(false, document, [1], 1000000.0),
    document.image_resolution_json_blob([1], 1000000.0),
  )
  let (form, form_resources) = image_external_cpdf_source_form_image_resources_for_test(
    document,
  )
  @test.assert_eq(
    document.parse_content_ops_with_resources(form_resources, [form]),
    [
      Op_cm({ a: 72.0, b: 0.0, c: 0.0, d: 72.0, e: 72.0, f: 72.0 }),
      Op_Do(image_external_name_for_test("/SourceNestedImage")),
    ],
  )
  let image = image_external_cpdf_source_nested_image_for_document_for_test(
    document, form_resources,
  )
  match document.get_image_24bpp(form_resources, image) {
    PdfRawImage(width, height, PdfBPP24, data) => {
      @test.assert_eq(width, 2)
      @test.assert_eq(height, 2)
      @test.assert_eq(data.length(), 2 * 2 * 3)
    }
    _ => fail("expected source nested image to decode as 24bpp raw data")
  }
}

///|
async test "external DCT image fixture extracts encoded JPEG XObject" {
  match
    image_external_images_from_fixture_for_test(
      "image/external_fixtures/downloads/pdflatex-image.pdf",
    ) {
    None => ()
    Some(images) => image_external_assert_jpeg_for_test(images)
  }
}

///|
async test "external DCT image fixture survives compressed rewrite" {
  match
    image_external_fixture_document_for_test(
      "image/external_fixtures/downloads/pdflatex-image.pdf",
    ) {
    None => ()
    Some(document) => {
      image_external_assert_jpeg_for_test(
        image_external_images_for_test(document),
      )
      let reparsed = image_external_reparse_compressed_for_test(document)
      image_external_assert_jpeg_for_test(
        image_external_images_for_test(reparsed),
      )
    }
  }
}

///|
async test "external DCT image fixture reconstructs xref stream with bad startxref" {
  match
    image_external_fixture_bytes_for_test(
      "image/external_fixtures/downloads/pdflatex-image.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let corrupted = image_external_corrupt_startxref_pointer_for_test(bytes)
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      let document = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(document.first_xref(), 0)
      image_external_assert_jpeg_for_test(
        image_external_images_for_test(document),
      )
      let reparsed = image_external_reparse_compressed_for_test(document)
      image_external_assert_jpeg_for_test(
        image_external_images_for_test(reparsed),
      )
    }
  }
}

///|
async test "external CCITT image fixture decodes to RGB24" {
  match
    image_external_images_from_fixture_for_test(
      "image/external_fixtures/downloads/imagemagick-CCITTFaxDecode.pdf",
    ) {
    None => ()
    Some(images) =>
      image_external_assert_raw_rgb_for_test(
        images, 16, 16, "expected raw RGB24 image payload",
      )
  }
}

///|
async test "external CCITT image fixture survives compressed rewrite" {
  match
    image_external_fixture_document_for_test(
      "image/external_fixtures/downloads/imagemagick-CCITTFaxDecode.pdf",
    ) {
    None => ()
    Some(document) => {
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(document),
        16,
        16,
        "expected raw RGB24 image payload",
      )
      let reparsed = image_external_reparse_compressed_for_test(document)
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(reparsed),
        16,
        16,
        "expected raw RGB24 image payload after rewrite",
      )
    }
  }
}

///|
async test "external CCITT image fixture reconstructs malformed startxref" {
  match
    image_external_fixture_bytes_for_test(
      "image/external_fixtures/downloads/imagemagick-CCITTFaxDecode.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let corrupted = image_external_corrupt_startxref_pointer_for_test(bytes)
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(recovered.first_xref(), 0)
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(recovered),
        16,
        16,
        "expected raw RGB24 image payload after reconstruction",
      )
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(
          image_external_reparse_compressed_for_test(recovered),
        ),
        16,
        16,
        "expected raw RGB24 image payload after reconstructed rewrite",
      )
    }
  }
}

///|
async test "external indexed CMYK image fixture decodes to RGB24" {
  match
    image_external_images_from_fixture_for_test(
      "image/external_fixtures/downloads/cmyk-image.pdf",
    ) {
    None => ()
    Some(images) =>
      image_external_assert_raw_rgb_for_test(
        images, 756, 1008, "expected indexed CMYK image as raw RGB24 payload",
      )
  }
}

///|
async test "external indexed CMYK image fixture survives compressed rewrite" {
  match
    image_external_fixture_document_for_test(
      "image/external_fixtures/downloads/cmyk-image.pdf",
    ) {
    None => ()
    Some(document) => {
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(document),
        756,
        1008,
        "expected indexed CMYK image as raw RGB24 payload",
      )
      let reparsed = image_external_reparse_compressed_for_test(document)
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(reparsed),
        756,
        1008,
        "expected indexed CMYK image as raw RGB24 payload after rewrite",
      )
    }
  }
}

///|
async test "cpdf source manual image PDF corpus parses and rewrites" {
  let mut checked = 0
  for path in image_external_cpdf_source_manual_image_pdf_paths_for_test() {
    match image_external_fixture_document_for_test(path) {
      None => ()
      Some(document) => {
        checked += 1
        image_external_assert_cpdf_manual_image_page_for_test(document, path)
        image_external_assert_cpdf_manual_image_page_for_test(
          image_external_reparse_compressed_for_test(document),
          path,
        )
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      image_external_cpdf_source_manual_image_pdf_paths_for_test().length(),
    )
  }
}

///|
async test "cpdf source manual image PDF corpus reconstructs malformed startxref" {
  let mut checked = 0
  for path in image_external_cpdf_source_manual_image_pdf_paths_for_test() {
    match image_external_fixture_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        let corrupted = image_external_corrupt_startxref_pointer_for_test(bytes)
        let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
          corrupted,
        )
        guard strict is Err(_) else {
          fail(
            "expected bad startxref to require malformed reconstruction for " +
            path,
          )
        }
        let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
        @test.assert_eq(recovered.first_xref(), 0)
        image_external_assert_cpdf_manual_image_page_for_test(recovered, path)
        image_external_assert_cpdf_manual_image_page_for_test(
          image_external_reparse_compressed_for_test(recovered),
          path,
        )
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      image_external_cpdf_source_manual_image_pdf_paths_for_test().length(),
    )
  }
}

///|
async test "cpdf source manual image PDF corpus reconstructs damaged classic xref metadata" {
  let mut checked = 0
  for path in image_external_cpdf_source_manual_image_pdf_paths_for_test() {
    match image_external_fixture_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        for
          corrupted in [
            image_external_corrupt_startxref_xref_header_for_test(bytes),
            image_external_corrupt_startxref_trailer_keyword_for_test(bytes),
          ] {
          let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
            corrupted,
          )
          guard strict is Err(_) else {
            fail(
              "expected damaged classic xref metadata to require malformed reconstruction for " +
              path,
            )
          }
          let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
          @test.assert_eq(recovered.first_xref(), 0)
          image_external_assert_cpdf_manual_image_page_for_test(recovered, path)
          image_external_assert_cpdf_manual_image_page_for_test(
            image_external_reparse_compressed_for_test(recovered),
            path,
          )
        }
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      image_external_cpdf_source_manual_image_pdf_paths_for_test().length(),
    )
  }
}

///|
async test "cpdf source manual image PDF corpus reconstructs malformed classic xref rows" {
  let mut checked = 0
  for path in image_external_cpdf_source_manual_image_pdf_paths_for_test() {
    match image_external_fixture_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        for
          corrupted in [
            image_external_corrupt_first_in_use_xref_marker_for_test(bytes),
            image_external_corrupt_first_in_use_xref_offset_for_test(bytes),
            image_external_corrupt_first_in_use_xref_generation_for_test(bytes),
            image_external_corrupt_first_xref_subsection_object_for_test(bytes),
            image_external_corrupt_first_xref_subsection_count_for_test(bytes),
          ] {
          let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
            corrupted,
          )
          guard strict is Err(_) else {
            fail(
              "expected malformed classic xref row to require reconstruction for " +
              path,
            )
          }
          let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
          @test.assert_eq(recovered.first_xref(), 0)
          image_external_assert_cpdf_manual_image_page_for_test(recovered, path)
          image_external_assert_cpdf_manual_image_page_for_test(
            image_external_reparse_compressed_for_test(recovered),
            path,
          )
        }
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      image_external_cpdf_source_manual_image_pdf_paths_for_test().length(),
    )
  }
}

///|
async test "cpdf source PNG manual image fixture decodes predictor RGB24" {
  match
    image_external_fixture_document_for_test(
      ".repos/cpdf-source/manualimages/png.pdf",
    ) {
    None => ()
    Some(document) => {
      @test.assert_eq(document.endpage(), 1)
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(document),
        400,
        294,
        "expected cpdf source PNG image as raw RGB24 payload",
      )
      let reparsed = image_external_reparse_compressed_for_test(document)
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(reparsed),
        400,
        294,
        "expected cpdf source PNG image as raw RGB24 payload after rewrite",
      )
    }
  }
}

///|
async test "cpdf source PNG manual image fixture reconstructs malformed startxref" {
  match
    image_external_fixture_bytes_for_test(
      ".repos/cpdf-source/manualimages/png.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let corrupted = image_external_corrupt_startxref_pointer_for_test(bytes)
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(recovered.first_xref(), 0)
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(recovered),
        400,
        294,
        "expected cpdf source PNG image after reconstruction",
      )
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(
          image_external_reparse_compressed_for_test(recovered),
        ),
        400,
        294,
        "expected cpdf source PNG image after reconstructed rewrite",
      )
    }
  }
}

///|
async test "cpdf source PNG manual image fixture drafts replacement boxes" {
  match
    image_external_fixture_bytes_for_test(
      ".repos/cpdf-source/manualimages/png.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      @test.assert_eq(document.endpage(), 1)
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(document),
        400,
        294,
        "expected cpdf source PNG image before drafting",
      )
      let drafted = @pdflite.pdf_draft(None, true, [1], document)
      image_external_assert_cpdf_png_draft_for_test(drafted)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        drafted,
      )
      image_external_assert_cpdf_png_draft_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      let corrupted = image_external_corrupt_startxref_pointer_for_test(
        compressed,
      )
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      image_external_assert_cpdf_png_draft_for_test(
        @pdflite.pdf_read_document_from_bytes(corrupted),
      )
    }
  }
}

///|
async test "cpdf source manual fixture decodes embedded RGB24 image" {
  match
    image_external_fixture_document_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(document) => {
      @test.assert_eq(document.endpage(), 175)
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(document),
        400,
        294,
        "expected cpdf source manual embedded image as raw RGB24 payload",
      )
      let reparsed = image_external_reparse_compressed_for_test(document)
      @test.assert_eq(reparsed.endpage(), 175)
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(reparsed),
        400,
        294,
        "expected cpdf source manual embedded image as raw RGB24 payload after rewrite",
      )
    }
  }
}

///|
async test "cpdf source manual fixture reconstructs embedded RGB24 image" {
  match
    image_external_fixture_bytes_for_test(".repos/cpdf-source/cpdfmanual.pdf") {
    None => ()
    Some(bytes) => {
      let corrupted = image_external_corrupt_startxref_pointer_for_test(bytes)
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(recovered.first_xref(), 0)
      @test.assert_eq(recovered.endpage(), 175)
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(recovered),
        400,
        294,
        "expected cpdf source manual image after reconstruction",
      )
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(
          image_external_reparse_compressed_for_test(recovered),
        ),
        400,
        294,
        "expected cpdf source manual image after reconstructed rewrite",
      )
    }
  }
}

///|
async test "cpdf source manual fixture reports embedded image metadata" {
  match
    image_external_fixture_bytes_for_test(".repos/cpdf-source/cpdfmanual.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      image_external_assert_cpdf_manual_image_reporting_for_test(document)
      image_external_assert_cpdf_manual_image_reporting_for_test(
        image_external_reparse_compressed_for_test(document),
      )
      let corrupted = image_external_corrupt_startxref_pointer_for_test(bytes)
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(recovered.first_xref(), 0)
      image_external_assert_cpdf_manual_image_reporting_for_test(recovered)
      image_external_assert_cpdf_manual_image_reporting_for_test(
        image_external_reparse_compressed_for_test(recovered),
      )
    }
  }
}

///|
async test "cpdf source hello fixture reports inline image metadata" {
  match image_external_fixture_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      image_external_assert_cpdf_source_hello_text_for_test(document)
      @test.assert_eq(document.images_json([1], inline=true).stringify(), "[]")
      let with_inline = image_external_cpdf_source_hello_with_inline_image_for_test(
        document,
      )
      image_external_assert_cpdf_source_inline_image_for_test(with_inline)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_inline,
      )
      image_external_assert_cpdf_source_inline_image_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      let corrupted = image_external_corrupt_startxref_pointer_for_test(
        compressed,
      )
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      image_external_assert_cpdf_source_inline_image_for_test(
        @pdflite.pdf_read_document_from_bytes(corrupted),
      )
    }
  }
}

///|
async test "cpdf source hello fixture reports nested form image metadata" {
  match image_external_fixture_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      image_external_assert_cpdf_source_hello_text_for_test(document)
      @test.assert_eq(document.images_json([1]).stringify(), "[]")
      @test.assert_eq(document.image_resolution([1], 1000000.0), [])
      let with_form_image = image_external_cpdf_source_hello_with_form_image_for_test(
        document,
      )
      image_external_assert_cpdf_source_form_image_for_test(with_form_image)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_form_image,
      )
      image_external_assert_cpdf_source_form_image_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      let corrupted = image_external_corrupt_startxref_pointer_for_test(
        compressed,
      )
      let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
        corrupted,
      )
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      image_external_assert_cpdf_source_form_image_for_test(
        @pdflite.pdf_read_document_from_bytes(corrupted),
      )
    }
  }
}

///|
async test "cpdf source raw PNG sheet fixture creates image document" {
  match
    image_external_fixture_bytes_for_test(
      ".repos/cpdf-source/manualimages/sheet.png",
    ) {
    None => ()
    Some(bytes) => {
      let png = @pdflite.pdf_read_png(bytes)
      @test.assert_eq(png.width, 400)
      @test.assert_eq(png.height, 294)
      @test.assert_eq(png.bit_depth, 8)
      @test.assert_eq(png.color_type, 2)
      @test.assert_eq(png.idat.length() > 50000, true)
      let document = @pdflite.pdf_image_document_of_png_data(
        bytes,
        title=Some("cpdf source sheet"),
      )
      @test.assert_eq(document.endpage(), 1)
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(document),
        400,
        294,
        "expected cpdf source sheet PNG as raw RGB24 payload",
      )
      let reparsed = image_external_reparse_compressed_for_test(document)
      @test.assert_eq(reparsed.endpage(), 1)
      image_external_assert_raw_rgb_for_test(
        image_external_images_for_test(reparsed),
        400,
        294,
        "expected cpdf source sheet PNG after compressed rewrite",
      )
    }
  }
}
