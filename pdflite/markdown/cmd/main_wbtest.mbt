///|
async fn markdown_cmd_remove_if_exists_for_test(path : String) -> Unit {
  if @fs.exists(path) {
    @fs.remove(path)
  }
}

///|
fn markdown_cmd_repo_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
fn markdown_cmd_output_path_for_test(name : String) -> String {
  let directory = match @env.current_dir() {
    Some(current_dir) => current_dir + "/_build/"
    None => "_build/"
  }
  directory +
  "pdflite_markdown_cmd_" +
  name +
  "_" +
  @env.now().to_string() +
  ".md"
}

///|
fn markdown_cmd_assert_contains_for_test(
  text : String,
  fragment : String,
) -> Unit raise {
  @test.assert_eq(text.contains(fragment), true)
}

///|
test "markdown command renders argparse help" {
  inspect(
    markdown_cmd_command().render_help(),
    content=(
      #|Usage: pdflite-markdown <input> <output>
      #|
      #|Extract Markdown text from a PDF file.
      #|
      #|Arguments:
      #|  input   Input PDF path.
      #|  output  Output Markdown path.
      #|
      #|Options:
      #|  -h, --help  Show help information.
      #|
    ),
  )
}

///|
test "markdown command parses required input and output paths" {
  let (input_path, output_path) = try! markdown_cmd_parse_args(argv=[
    "input.pdf", "output.md",
  ])
  @test.assert_eq(input_path, "input.pdf")
  @test.assert_eq(output_path, "output.md")
}

///|
test "markdown command reports missing positional arguments with argparse help" {
  try markdown_cmd_parse_args(argv=[]) catch {
    err =>
      inspect(
        err.to_string(),
        content=(
          #|error: 'input' requires at least 1 values but only 0 were provided
          #|
          #|Usage: pdflite-markdown <input> <output>
          #|
          #|Extract Markdown text from a PDF file.
          #|
          #|Arguments:
          #|  input   Input PDF path.
          #|  output  Output Markdown path.
          #|
          #|Options:
          #|  -h, --help  Show help information.
          #|
        ),
      )
  } noraise {
    _ => fail("expected argparse to reject missing paths")
  }
}

///|
test "markdown command rejects extra positional arguments" {
  try markdown_cmd_parse_args(argv=["input.pdf", "output.md", "extra"]) catch {
    err => {
      let message = err.to_string()
      markdown_cmd_assert_contains_for_test(message, "unexpected value 'extra'")
      markdown_cmd_assert_contains_for_test(
        message, "Usage: pdflite-markdown <input> <output>",
      )
    }
  } noraise {
    _ => fail("expected argparse to reject extra paths")
  }
}

///|
fn markdown_cmd_raw_control_count_for_test(text : String) -> Int {
  let mut count = 0
  for char in text {
    let codepoint = char.to_int()
    if (
        codepoint < 0x20 &&
        codepoint != 0x0A &&
        codepoint != 0x09 &&
        codepoint != 0x0C
      ) ||
      (codepoint >= 0x7F && codepoint <= 0x9F) {
      count += 1
    }
  }
  count
}

///|
fn markdown_cmd_replacement_count_for_test(text : String) -> Int {
  let mut count = 0
  for char in text {
    if char.to_int() == 0xFFFD {
      count += 1
    }
  }
  count
}

///|
fn markdown_cmd_find_last_bytes_for_test(
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
      let mut matched = true
      for offset in 0..<needle.length() {
        if haystack[start + offset] != needle[offset] {
          matched = false
        }
      }
      if matched {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn markdown_cmd_bytes_start_with_at_for_test(
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
fn markdown_cmd_find_bytes_after_for_test(
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
      if markdown_cmd_bytes_start_with_at_for_test(haystack, needle, position) {
        break position
      }
    } nobreak {
      -1
    }
  }
}

///|
fn markdown_cmd_push_ascii_for_test(
  output : Array[Byte],
  text : String,
) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn markdown_cmd_corrupt_startxref_pointer_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let marker = @ascii.encode("startxref")
  let marker_position = markdown_cmd_find_last_bytes_for_test(bytes, marker)
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
  markdown_cmd_push_ascii_for_test(output, (bytes.length() + 4096).to_string())
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn markdown_cmd_startxref_offset_for_test(bytes : Bytes) -> Int raise {
  let marker = @ascii.encode("startxref")
  let marker_position = markdown_cmd_find_last_bytes_for_test(bytes, marker)
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
fn markdown_cmd_corrupt_startxref_xref_header_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let xref_offset = markdown_cmd_startxref_offset_for_test(bytes)
  guard markdown_cmd_bytes_start_with_at_for_test(
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
fn markdown_cmd_corrupt_startxref_trailer_keyword_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let xref_offset = markdown_cmd_startxref_offset_for_test(bytes)
  let trailer_position = markdown_cmd_find_bytes_after_for_test(
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
fn markdown_cmd_corrupt_startxref_xref_stream_token_for_test(
  bytes : Bytes,
  target : BytesView,
  replacement : BytesView,
  description : String,
) -> Bytes raise {
  if target.length() != replacement.length() {
    fail("replacement must preserve byte length")
  }
  let xref_offset = markdown_cmd_startxref_offset_for_test(bytes)
  let position = markdown_cmd_find_bytes_after_for_test(
    bytes, target, xref_offset,
  )
  if position < 0 {
    fail("expected xref stream " + description + " at startxref target")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  for index in 0..<replacement.length() {
    output[position + index] = replacement[index]
  }
  Bytes::from_array(output)
}

///|
fn markdown_cmd_replace_xref_stream_entry_with_padded_ascii_for_test(
  bytes : Bytes,
  target : BytesView,
  replacement_text : String,
  description : String,
) -> Bytes raise {
  let replacement = @ascii.encode(replacement_text)
  if replacement.length() > target.length() {
    fail("replacement must fit xref stream " + description + " byte span")
  }
  let xref_offset = markdown_cmd_startxref_offset_for_test(bytes)
  let anchor = @ascii.encode("/Type /XRef")
  let anchor_position = markdown_cmd_find_bytes_after_for_test(
    bytes, anchor, xref_offset,
  )
  if anchor_position < 0 {
    fail("expected startxref-targeted xref stream")
  }
  let position = markdown_cmd_find_bytes_after_for_test(
    bytes,
    target,
    anchor_position + anchor.length(),
  )
  if position < 0 {
    fail("expected xref stream " + description + " entry")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  for index in 0..<target.length() {
    output[position + index] = if index < replacement.length() {
      replacement[index]
    } else {
      b' '
    }
  }
  Bytes::from_array(output)
}

///|
fn markdown_cmd_replace_bytes_after_with_padded_ascii_for_test(
  bytes : Bytes,
  anchor : BytesView,
  target : BytesView,
  replacement_text : String,
  description : String,
) -> Bytes raise {
  let replacement = @ascii.encode(replacement_text)
  if replacement.length() > target.length() {
    fail("replacement must fit " + description + " byte span")
  }
  let anchor_position = markdown_cmd_find_bytes_after_for_test(bytes, anchor, 0)
  if anchor_position < 0 {
    fail("expected " + description + " anchor")
  }
  let position = markdown_cmd_find_bytes_after_for_test(
    bytes,
    target,
    anchor_position + anchor.length(),
  )
  if position < 0 {
    fail("expected " + description + " target")
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  for index in 0..<target.length() {
    output[position + index] = if index < replacement.length() {
      replacement[index]
    } else {
      b' '
    }
  }
  Bytes::from_array(output)
}

///|
fn markdown_cmd_replace_bytes_at_for_test(
  bytes : Bytes,
  position : Int,
  target : BytesView,
  replacement : BytesView,
  description : String,
) -> Bytes raise {
  if target.length() != replacement.length() {
    fail("replacement must preserve byte length")
  }
  if !markdown_cmd_bytes_start_with_at_for_test(bytes, target, position) {
    fail("expected " + description)
  }
  let output : Array[Byte] = []
  for byte in bytes {
    output.push(byte)
  }
  for index in 0..<replacement.length() {
    output[position + index] = replacement[index]
  }
  Bytes::from_array(output)
}

///|
fn markdown_cmd_skip_pdf_whitespace_for_test(
  bytes : BytesView,
  position : Int,
) -> Int {
  let mut current = position
  while current < bytes.length() {
    let value = bytes[current].to_int()
    if value == 0 ||
      value == 9 ||
      value == 10 ||
      value == 12 ||
      value == 13 ||
      value == 32 {
      current += 1
    } else {
      break
    }
  }
  current
}

///|
fn markdown_cmd_stream_data_start_for_test(
  bytes : BytesView,
  stream_position : Int,
) -> Int {
  let mut current = stream_position + @ascii.encode("stream").length()
  while current < bytes.length() {
    let value = bytes[current].to_int()
    if value == 0 || value == 9 || value == 12 || value == 32 {
      current += 1
    } else {
      break
    }
  }
  if current < bytes.length() && bytes[current] == b'\r' {
    current += 1
    if current < bytes.length() && bytes[current] == b'\n' {
      current += 1
    }
  } else if current < bytes.length() && bytes[current] == b'\n' {
    current += 1
  }
  current
}

///|
fn markdown_cmd_direct_length_before_for_test(
  bytes : BytesView,
  anchor_position : Int,
  limit : Int,
  description : String,
) -> Int raise {
  let length_key = @ascii.encode("/Length")
  let length_position = markdown_cmd_find_bytes_after_for_test(
    bytes, length_key, anchor_position,
  )
  if length_position < 0 || length_position >= limit {
    fail("expected direct stream length for " + description)
  }
  let mut current = markdown_cmd_skip_pdf_whitespace_for_test(
    bytes,
    length_position + length_key.length(),
  )
  let mut length = 0
  let number_start = current
  while current < limit && bytes[current] >= b'0' && bytes[current] <= b'9' {
    length = length * 10 + bytes[current].to_int() - b'0'.to_int()
    current += 1
  }
  if current == number_start {
    fail("expected numeric stream length for " + description)
  }
  length
}

///|
fn markdown_cmd_corrupt_startxref_xref_stream_type_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_cmd_corrupt_startxref_xref_stream_token_for_test(
    bytes,
    @ascii.encode("/Type /XRef"),
    @ascii.encode("/Type /Bad "),
    "type",
  )
}

///|
fn markdown_cmd_corrupt_startxref_xref_stream_marker_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_cmd_corrupt_startxref_xref_stream_token_for_test(
    bytes,
    @ascii.encode("stream"),
    @ascii.encode("stramx"),
    "stream marker",
  )
}

///|
fn markdown_cmd_corrupt_startxref_xref_stream_endstream_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_cmd_corrupt_startxref_xref_stream_token_for_test(
    bytes,
    @ascii.encode("endstream"),
    @ascii.encode("endstreax"),
    "endstream marker",
  )
}

///|
fn markdown_cmd_corrupt_startxref_xref_stream_endobj_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_cmd_corrupt_startxref_xref_stream_token_for_test(
    bytes,
    @ascii.encode("endobj"),
    @ascii.encode("endobx"),
    "endobj marker",
  )
}

///|
fn markdown_cmd_corrupt_xref_stream_root_entry_for_test(
  bytes : Bytes,
  root_entry : BytesView,
) -> Bytes raise {
  markdown_cmd_replace_xref_stream_entry_with_padded_ascii_for_test(
    bytes, root_entry, "/Root /Bad", "root",
  )
}

///|
fn markdown_cmd_corrupt_xref_stream_decodeparms_entry_for_test(
  bytes : Bytes,
  metadata_entry : BytesView,
  replacement_text : String,
) -> Bytes raise {
  markdown_cmd_replace_xref_stream_entry_with_padded_ascii_for_test(
    bytes, metadata_entry, replacement_text, "decode params",
  )
}

///|
fn markdown_cmd_corrupt_xref_stream_filter_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_cmd_corrupt_startxref_xref_stream_token_for_test(
    bytes,
    @ascii.encode("/Filter /FlateDecode"),
    @ascii.encode("/Filter /NoSuchThing"),
    "filter",
  )
}

///|
fn markdown_cmd_corrupt_xref_stream_length_entry_for_test(
  bytes : Bytes,
  length_entry : BytesView,
) -> Bytes raise {
  markdown_cmd_replace_xref_stream_entry_with_padded_ascii_for_test(
    bytes, length_entry, "/Length /Bad", "length",
  )
}

///|
fn markdown_cmd_first_object_stream_marker_position_for_test(
  bytes : BytesView,
) -> Int raise {
  let anchor = @ascii.encode("/Type /ObjStm")
  let anchor_position = markdown_cmd_find_bytes_after_for_test(bytes, anchor, 0)
  if anchor_position < 0 {
    fail("expected first object stream")
  }
  let stream_marker = @ascii.encode("stream")
  let stream_position = markdown_cmd_find_bytes_after_for_test(
    bytes,
    stream_marker,
    anchor_position + anchor.length(),
  )
  if stream_position < 0 {
    fail("expected first object stream marker")
  }
  stream_position
}

///|
fn markdown_cmd_first_object_stream_endstream_position_for_test(
  bytes : BytesView,
) -> Int raise {
  let anchor = @ascii.encode("/Type /ObjStm")
  let anchor_position = markdown_cmd_find_bytes_after_for_test(bytes, anchor, 0)
  if anchor_position < 0 {
    fail("expected first object stream")
  }
  let stream_position = markdown_cmd_first_object_stream_marker_position_for_test(
    bytes,
  )
  let length = markdown_cmd_direct_length_before_for_test(
    bytes, anchor_position, stream_position, "first object stream",
  )
  let marker_position = markdown_cmd_skip_pdf_whitespace_for_test(
    bytes,
    markdown_cmd_stream_data_start_for_test(bytes, stream_position) + length,
  )
  if !markdown_cmd_bytes_start_with_at_for_test(
      bytes,
      @ascii.encode("endstream"),
      marker_position,
    ) {
    fail("expected first object stream endstream marker")
  }
  marker_position
}

///|
fn markdown_cmd_first_object_stream_endobj_position_for_test(
  bytes : BytesView,
) -> Int raise {
  let endstream_position = markdown_cmd_first_object_stream_endstream_position_for_test(
    bytes,
  )
  let endobj_position = markdown_cmd_skip_pdf_whitespace_for_test(
    bytes,
    endstream_position + @ascii.encode("endstream").length(),
  )
  if !markdown_cmd_bytes_start_with_at_for_test(
      bytes,
      @ascii.encode("endobj"),
      endobj_position,
    ) {
    fail("expected first object stream endobj marker")
  }
  endobj_position
}

///|
fn markdown_cmd_corrupt_first_object_stream_count_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_cmd_replace_bytes_after_with_padded_ascii_for_test(
    bytes,
    @ascii.encode("/Type /ObjStm"),
    @ascii.encode("/N 100"),
    "/N/Bad",
    "first object stream count",
  )
}

///|
fn markdown_cmd_corrupt_first_object_stream_first_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_cmd_replace_bytes_after_with_padded_ascii_for_test(
    bytes,
    @ascii.encode("/Type /ObjStm"),
    @ascii.encode("/First 832"),
    "/First/Bad",
    "first object stream first offset",
  )
}

///|
fn markdown_cmd_corrupt_first_object_stream_length_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_cmd_replace_bytes_after_with_padded_ascii_for_test(
    bytes,
    @ascii.encode("/Type /ObjStm"),
    @ascii.encode("/Length 1526"),
    "/Length /Bad",
    "first object stream length",
  )
}

///|
fn markdown_cmd_corrupt_first_object_stream_filter_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_cmd_replace_bytes_after_with_padded_ascii_for_test(
    bytes,
    @ascii.encode("/Type /ObjStm"),
    @ascii.encode("/Filter /FlateDecode"),
    "/Filter /NoSuchThing",
    "first object stream filter",
  )
}

///|
fn markdown_cmd_corrupt_first_object_stream_marker_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_cmd_replace_bytes_at_for_test(
    bytes,
    markdown_cmd_first_object_stream_marker_position_for_test(bytes),
    @ascii.encode("stream"),
    @ascii.encode("stramx"),
    "first object stream marker",
  )
}

///|
fn markdown_cmd_corrupt_first_object_stream_endstream_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_cmd_replace_bytes_at_for_test(
    bytes,
    markdown_cmd_first_object_stream_endstream_position_for_test(bytes),
    @ascii.encode("endstream"),
    @ascii.encode("endstreax"),
    "first object stream endstream marker",
  )
}

///|
fn markdown_cmd_corrupt_first_object_stream_endobj_for_test(
  bytes : Bytes,
) -> Bytes raise {
  markdown_cmd_replace_bytes_at_for_test(
    bytes,
    markdown_cmd_first_object_stream_endobj_position_for_test(bytes),
    @ascii.encode("endobj"),
    @ascii.encode("endobx"),
    "first object stream endobj marker",
  )
}

///|
fn markdown_cmd_first_in_use_xref_row_start_for_test(
  bytes : Bytes,
) -> Int raise {
  let free_row = @ascii.encode("0000000000 65535 f")
  let free_row_position = markdown_cmd_find_bytes_after_for_test(
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
fn markdown_cmd_corrupt_first_in_use_xref_marker_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = markdown_cmd_first_in_use_xref_row_start_for_test(bytes)
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
fn markdown_cmd_corrupt_first_in_use_xref_offset_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = markdown_cmd_first_in_use_xref_row_start_for_test(bytes)
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
fn markdown_cmd_corrupt_first_in_use_xref_generation_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = markdown_cmd_first_in_use_xref_row_start_for_test(bytes)
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
fn markdown_cmd_first_xref_subsection_spans_for_test(
  bytes : Bytes,
) -> (Int, Int, Int, Int) raise {
  let header = @ascii.encode("xref")
  let header_position = markdown_cmd_find_bytes_after_for_test(bytes, header, 0)
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
fn markdown_cmd_corrupt_first_xref_subsection_object_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let (object_start, object_end, _, _) = markdown_cmd_first_xref_subsection_spans_for_test(
    bytes,
  )
  let output : Array[Byte] = []
  for index in 0..<object_start {
    output.push(bytes[index])
  }
  markdown_cmd_push_ascii_for_test(output, "/Bad")
  for index in object_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn markdown_cmd_corrupt_first_xref_subsection_count_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let (_, _, count_start, count_end) = markdown_cmd_first_xref_subsection_spans_for_test(
    bytes,
  )
  let output : Array[Byte] = []
  for index in 0..<count_start {
    output.push(bytes[index])
  }
  markdown_cmd_push_ascii_for_test(output, "/Bad")
  for index in count_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn markdown_cmd_unique_cjk_unified_count_for_test(text : String) -> Int {
  let lower = 0x4E00
  let upper = 0x9FFF
  let seen = Array::make(upper - lower + 1, false)
  let mut count = 0
  for char in text {
    let codepoint = char.to_int()
    if codepoint >= lower && codepoint <= upper {
      let index = codepoint - lower
      if !seen[index] {
        seen[index] = true
        count += 1
      }
    }
  }
  count
}

///|
fn markdown_cmd_cpdf_source_top_level_classic_pdf_paths_for_test() -> Array[
  String,
] {
  [".repos/cpdf-source/hello.pdf", ".repos/cpdf-source/logo.pdf"]
}

///|
fn markdown_cmd_cpdf_source_manual_image_pdf_paths_for_test() -> Array[String] {
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
fn markdown_cmd_assert_cpdf_top_level_classic_markdown_for_test(
  markdown : String,
  path : String,
) -> Unit raise {
  markdown_cmd_assert_contains_for_test(markdown, "# Page 1")
  match path {
    ".repos/cpdf-source/hello.pdf" =>
      markdown_cmd_assert_contains_for_test(markdown, "Hello, World!")
    ".repos/cpdf-source/logo.pdf" =>
      @test.assert_eq(markdown, "# Page 1\n\n\n", msg=path)
    _ => fail("unexpected cpdf top-level classic PDF path: " + path)
  }
  @test.assert_eq(
    markdown_cmd_raw_control_count_for_test(markdown),
    0,
    msg=path,
  )
  @test.assert_eq(
    markdown_cmd_replacement_count_for_test(markdown),
    0,
    msg=path,
  )
}

///|
fn markdown_cmd_assert_cpdf_manual_image_markdown_for_test(
  markdown : String,
  path : String,
) -> Unit raise {
  markdown_cmd_assert_contains_for_test(markdown, "# Page 1")
  @test.assert_eq(
    markdown_cmd_raw_control_count_for_test(markdown),
    0,
    msg=path,
  )
  @test.assert_eq(
    markdown_cmd_replacement_count_for_test(markdown),
    0,
    msg=path,
  )
}

///|
async test "markdown command converts generated Latin fixture to UTF-8 file" {
  let input_path = markdown_cmd_repo_path_for_test(
    "markdown/fixtures/pandoc_latin.pdf",
  )
  let output_path = markdown_cmd_output_path_for_test("pandoc_latin")
  markdown_cmd_remove_if_exists_for_test(output_path)
  markdown_cmd_convert_file(input_path, output_path)
  let output = @utf8.decode_lossy(@fs.read_file(output_path).binary())
  markdown_cmd_assert_contains_for_test(output, "# Page 1")
  markdown_cmd_assert_contains_for_test(output, "Pandoc Latin Fixture")
  markdown_cmd_assert_contains_for_test(
    output, "stable marker: alpha beta 123.",
  )
  markdown_cmd_remove_if_exists_for_test(output_path)
}

///|
async test "markdown command converts checked-in CamlPDF introduction fixture" {
  let input_path = markdown_cmd_repo_path_for_test(
    "fixtures/camlpdf/introduction_to_camlpdf.pdf",
  )
  let output_path = markdown_cmd_output_path_for_test("camlpdf_introduction")
  markdown_cmd_remove_if_exists_for_test(output_path)
  markdown_cmd_convert_file(input_path, output_path)
  let output = @utf8.decode_lossy(@fs.read_file(output_path).binary())
  markdown_cmd_assert_contains_for_test(
    output, "An Introduction to PDF with CamlPDF",
  )
  markdown_cmd_assert_contains_for_test(output, "Pdfread.pdf_of_file")
  markdown_cmd_assert_contains_for_test(output, "PDF is a directed graph")
  @test.assert_eq(markdown_cmd_raw_control_count_for_test(output), 0)
  @test.assert_eq(markdown_cmd_replacement_count_for_test(output), 0)
  markdown_cmd_remove_if_exists_for_test(output_path)
}

///|
async test "markdown command converts optional cpdf source manual fixture" {
  let input_path = markdown_cmd_repo_path_for_test(
    ".repos/cpdf-source/cpdfmanual.pdf",
  )
  if @fs.exists(input_path) {
    let output_path = markdown_cmd_output_path_for_test("cpdf_source_manual")
    markdown_cmd_remove_if_exists_for_test(output_path)
    markdown_cmd_convert_file(input_path, output_path)
    let output = @utf8.decode_lossy(@fs.read_file(output_path).binary())
    markdown_cmd_assert_contains_for_test(output, "Coherent PDF")
    markdown_cmd_assert_contains_for_test(output, "Command Line Tools")
    markdown_cmd_assert_contains_for_test(output, "Chapter 15: PDF and JSON")
    markdown_cmd_assert_contains_for_test(output, "Accessible PDFs with PDF/UA")
    @test.assert_eq(output.length() > 200000, true)
    @test.assert_eq(markdown_cmd_replacement_count_for_test(output), 0)
    markdown_cmd_remove_if_exists_for_test(output_path)
  }
}

///|
async test "markdown command reconstructs optional cpdf source manual fixture with bad startxref" {
  let input_path = markdown_cmd_repo_path_for_test(
    ".repos/cpdf-source/cpdfmanual.pdf",
  )
  if @fs.exists(input_path) {
    let clean_output_path = markdown_cmd_output_path_for_test(
      "cpdf_source_manual_clean",
    )
    let corrupt_input_path = markdown_cmd_output_path_for_test(
      "cpdf_source_manual_bad_startxref_input",
    )
    let corrupt_output_path = markdown_cmd_output_path_for_test(
      "cpdf_source_manual_bad_startxref",
    )
    markdown_cmd_remove_if_exists_for_test(clean_output_path)
    markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
    markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
    markdown_cmd_convert_file(input_path, clean_output_path)
    @fs.write_file(
      corrupt_input_path,
      markdown_cmd_corrupt_startxref_pointer_for_test(
        @fs.read_file(input_path).binary(),
      ),
      create=0o644,
    )
    markdown_cmd_convert_file(corrupt_input_path, corrupt_output_path)
    let clean_output = @utf8.decode_lossy(
      @fs.read_file(clean_output_path).binary(),
    )
    let corrupt_output = @utf8.decode_lossy(
      @fs.read_file(corrupt_output_path).binary(),
    )
    markdown_cmd_assert_contains_for_test(corrupt_output, "Coherent PDF")
    markdown_cmd_assert_contains_for_test(corrupt_output, "Command Line Tools")
    markdown_cmd_assert_contains_for_test(
      corrupt_output, "Chapter 15: PDF and JSON",
    )
    markdown_cmd_assert_contains_for_test(
      corrupt_output, "Accessible PDFs with PDF/UA",
    )
    @test.assert_eq(corrupt_output, clean_output)
    @test.assert_eq(markdown_cmd_replacement_count_for_test(corrupt_output), 0)
    markdown_cmd_remove_if_exists_for_test(clean_output_path)
    markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
    markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
  }
}

///|
async test "markdown command reconstructs optional cpdf source manual fixture with malformed xref stream metadata" {
  let input_path = markdown_cmd_repo_path_for_test(
    ".repos/cpdf-source/cpdfmanual.pdf",
  )
  if @fs.exists(input_path) {
    let clean_output_path = markdown_cmd_output_path_for_test(
      "cpdf_source_manual_xref_metadata_clean",
    )
    markdown_cmd_remove_if_exists_for_test(clean_output_path)
    markdown_cmd_convert_file(input_path, clean_output_path)
    let clean_output = @utf8.decode_lossy(
      @fs.read_file(clean_output_path).binary(),
    )
    let input_bytes = @fs.read_file(input_path).binary()
    let mut case_index = 0
    for
      corrupted in [
        markdown_cmd_corrupt_startxref_xref_stream_type_for_test(input_bytes),
        markdown_cmd_corrupt_startxref_xref_stream_marker_for_test(input_bytes),
      ] {
      case_index += 1
      let corrupt_input_path = markdown_cmd_output_path_for_test(
        "cpdf_source_manual_xref_metadata_input_" + case_index.to_string(),
      )
      let corrupt_output_path = markdown_cmd_output_path_for_test(
        "cpdf_source_manual_xref_metadata_" + case_index.to_string(),
      )
      markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
      markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
      @fs.write_file(corrupt_input_path, corrupted, create=0o644)
      markdown_cmd_convert_file(corrupt_input_path, corrupt_output_path)
      let corrupt_output = @utf8.decode_lossy(
        @fs.read_file(corrupt_output_path).binary(),
      )
      markdown_cmd_assert_contains_for_test(corrupt_output, "Coherent PDF")
      markdown_cmd_assert_contains_for_test(
        corrupt_output, "Command Line Tools",
      )
      markdown_cmd_assert_contains_for_test(
        corrupt_output, "Chapter 15: PDF and JSON",
      )
      markdown_cmd_assert_contains_for_test(
        corrupt_output, "Accessible PDFs with PDF/UA",
      )
      @test.assert_eq(corrupt_output, clean_output)
      @test.assert_eq(
        markdown_cmd_replacement_count_for_test(corrupt_output),
        0,
      )
      markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
      markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
    }
    markdown_cmd_remove_if_exists_for_test(clean_output_path)
  }
}

///|
async test "markdown command reconstructs optional cpdf source manual fixture with malformed xref stream terminators" {
  let input_path = markdown_cmd_repo_path_for_test(
    ".repos/cpdf-source/cpdfmanual.pdf",
  )
  if @fs.exists(input_path) {
    let clean_output_path = markdown_cmd_output_path_for_test(
      "cpdf_source_manual_xref_terminators_clean",
    )
    markdown_cmd_remove_if_exists_for_test(clean_output_path)
    markdown_cmd_convert_file(input_path, clean_output_path)
    let clean_output = @utf8.decode_lossy(
      @fs.read_file(clean_output_path).binary(),
    )
    let input_bytes = @fs.read_file(input_path).binary()
    let mut case_index = 0
    for
      corrupted in [
        markdown_cmd_corrupt_startxref_xref_stream_endstream_for_test(
          input_bytes,
        ),
        markdown_cmd_corrupt_startxref_xref_stream_endobj_for_test(input_bytes),
      ] {
      case_index += 1
      let corrupt_input_path = markdown_cmd_output_path_for_test(
        "cpdf_source_manual_xref_terminators_input_" + case_index.to_string(),
      )
      let corrupt_output_path = markdown_cmd_output_path_for_test(
        "cpdf_source_manual_xref_terminators_" + case_index.to_string(),
      )
      markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
      markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
      @fs.write_file(corrupt_input_path, corrupted, create=0o644)
      markdown_cmd_convert_file(corrupt_input_path, corrupt_output_path)
      let corrupt_output = @utf8.decode_lossy(
        @fs.read_file(corrupt_output_path).binary(),
      )
      markdown_cmd_assert_contains_for_test(corrupt_output, "Coherent PDF")
      markdown_cmd_assert_contains_for_test(
        corrupt_output, "Command Line Tools",
      )
      markdown_cmd_assert_contains_for_test(
        corrupt_output, "Chapter 15: PDF and JSON",
      )
      markdown_cmd_assert_contains_for_test(
        corrupt_output, "Accessible PDFs with PDF/UA",
      )
      @test.assert_eq(corrupt_output, clean_output)
      @test.assert_eq(
        markdown_cmd_replacement_count_for_test(corrupt_output),
        0,
      )
      markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
      markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
    }
    markdown_cmd_remove_if_exists_for_test(clean_output_path)
  }
}

///|
async test "markdown command reconstructs optional cpdf source manual fixture with malformed xref stream dictionary entries" {
  let input_path = markdown_cmd_repo_path_for_test(
    ".repos/cpdf-source/cpdfmanual.pdf",
  )
  if @fs.exists(input_path) {
    let clean_output_path = markdown_cmd_output_path_for_test(
      "cpdf_source_manual_xref_dictionary_clean",
    )
    markdown_cmd_remove_if_exists_for_test(clean_output_path)
    markdown_cmd_convert_file(input_path, clean_output_path)
    let clean_output = @utf8.decode_lossy(
      @fs.read_file(clean_output_path).binary(),
    )
    let input_bytes = @fs.read_file(input_path).binary()
    let manual_root_entry = @ascii.encode("/Root 1841 0 R")
    let manual_id_entry = @ascii.encode(
      "/ID [<CA2FED47397E566603B0A9A8E7328C79> <CA2FED47397E566603B0A9A8E7328C79>]",
    )
    let mut case_index = 0
    for
      corrupted in [
        markdown_cmd_corrupt_xref_stream_root_entry_for_test(
          input_bytes, manual_root_entry,
        ),
        markdown_cmd_corrupt_xref_stream_decodeparms_entry_for_test(
          input_bytes, manual_id_entry, "/DecodeParms /Bad",
        ),
        markdown_cmd_corrupt_xref_stream_decodeparms_entry_for_test(
          input_bytes, manual_id_entry, "/DecodeParms << /Predictor 9 >>",
        ),
        markdown_cmd_corrupt_xref_stream_filter_for_test(input_bytes),
      ] {
      case_index += 1
      let corrupt_input_path = markdown_cmd_output_path_for_test(
        "cpdf_source_manual_xref_dictionary_input_" + case_index.to_string(),
      )
      let corrupt_output_path = markdown_cmd_output_path_for_test(
        "cpdf_source_manual_xref_dictionary_" + case_index.to_string(),
      )
      markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
      markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
      @fs.write_file(corrupt_input_path, corrupted, create=0o644)
      markdown_cmd_convert_file(corrupt_input_path, corrupt_output_path)
      let corrupt_output = @utf8.decode_lossy(
        @fs.read_file(corrupt_output_path).binary(),
      )
      markdown_cmd_assert_contains_for_test(corrupt_output, "Coherent PDF")
      markdown_cmd_assert_contains_for_test(
        corrupt_output, "Command Line Tools",
      )
      markdown_cmd_assert_contains_for_test(
        corrupt_output, "Chapter 15: PDF and JSON",
      )
      markdown_cmd_assert_contains_for_test(
        corrupt_output, "Accessible PDFs with PDF/UA",
      )
      @test.assert_eq(corrupt_output, clean_output)
      @test.assert_eq(
        markdown_cmd_replacement_count_for_test(corrupt_output),
        0,
      )
      markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
      markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
    }
    markdown_cmd_remove_if_exists_for_test(clean_output_path)
  }
}

///|
async test "markdown command reconstructs optional cpdf source manual fixture with malformed object stream entries" {
  let input_path = markdown_cmd_repo_path_for_test(
    ".repos/cpdf-source/cpdfmanual.pdf",
  )
  if @fs.exists(input_path) {
    let clean_output_path = markdown_cmd_output_path_for_test(
      "cpdf_source_manual_object_stream_clean",
    )
    markdown_cmd_remove_if_exists_for_test(clean_output_path)
    markdown_cmd_convert_file(input_path, clean_output_path)
    let clean_output = @utf8.decode_lossy(
      @fs.read_file(clean_output_path).binary(),
    )
    let input_bytes = @fs.read_file(input_path).binary()
    let mut case_index = 0
    for
      corrupted in [
        markdown_cmd_corrupt_first_object_stream_count_for_test(input_bytes),
        markdown_cmd_corrupt_first_object_stream_first_for_test(input_bytes),
        markdown_cmd_corrupt_first_object_stream_filter_for_test(input_bytes),
        markdown_cmd_corrupt_first_object_stream_marker_for_test(input_bytes),
        markdown_cmd_corrupt_first_object_stream_endstream_for_test(input_bytes),
        markdown_cmd_corrupt_first_object_stream_endobj_for_test(input_bytes),
      ] {
      case_index += 1
      let corrupt_input_path = markdown_cmd_output_path_for_test(
        "cpdf_source_manual_object_stream_input_" + case_index.to_string(),
      )
      let corrupt_output_path = markdown_cmd_output_path_for_test(
        "cpdf_source_manual_object_stream_" + case_index.to_string(),
      )
      markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
      markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
      @fs.write_file(corrupt_input_path, corrupted, create=0o644)
      markdown_cmd_convert_file(corrupt_input_path, corrupt_output_path)
      let corrupt_output = @utf8.decode_lossy(
        @fs.read_file(corrupt_output_path).binary(),
      )
      markdown_cmd_assert_contains_for_test(corrupt_output, "Coherent PDF")
      markdown_cmd_assert_contains_for_test(
        corrupt_output, "Command Line Tools",
      )
      markdown_cmd_assert_contains_for_test(
        corrupt_output, "Chapter 15: PDF and JSON",
      )
      markdown_cmd_assert_contains_for_test(
        corrupt_output, "Accessible PDFs with PDF/UA",
      )
      @test.assert_eq(corrupt_output, clean_output)
      @test.assert_eq(
        markdown_cmd_replacement_count_for_test(corrupt_output),
        0,
      )
      markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
      markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
    }
    markdown_cmd_remove_if_exists_for_test(clean_output_path)
  }
}

///|
async test "markdown command repairs optional cpdf source manual fixture with malformed stream length entries" {
  let input_path = markdown_cmd_repo_path_for_test(
    ".repos/cpdf-source/cpdfmanual.pdf",
  )
  if @fs.exists(input_path) {
    let clean_output_path = markdown_cmd_output_path_for_test(
      "cpdf_source_manual_stream_length_clean",
    )
    markdown_cmd_remove_if_exists_for_test(clean_output_path)
    markdown_cmd_convert_file(input_path, clean_output_path)
    let clean_output = @utf8.decode_lossy(
      @fs.read_file(clean_output_path).binary(),
    )
    let input_bytes = @fs.read_file(input_path).binary()
    let mut case_index = 0
    for
      corrupted in [
        markdown_cmd_corrupt_xref_stream_length_entry_for_test(
          input_bytes,
          @ascii.encode("/Length 4551"),
        ),
        markdown_cmd_corrupt_first_object_stream_length_for_test(input_bytes),
      ] {
      case_index += 1
      let corrupt_input_path = markdown_cmd_output_path_for_test(
        "cpdf_source_manual_stream_length_input_" + case_index.to_string(),
      )
      let corrupt_output_path = markdown_cmd_output_path_for_test(
        "cpdf_source_manual_stream_length_" + case_index.to_string(),
      )
      markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
      markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
      @fs.write_file(corrupt_input_path, corrupted, create=0o644)
      markdown_cmd_convert_file(corrupt_input_path, corrupt_output_path)
      let corrupt_output = @utf8.decode_lossy(
        @fs.read_file(corrupt_output_path).binary(),
      )
      markdown_cmd_assert_contains_for_test(corrupt_output, "Coherent PDF")
      markdown_cmd_assert_contains_for_test(
        corrupt_output, "Command Line Tools",
      )
      markdown_cmd_assert_contains_for_test(
        corrupt_output, "Chapter 15: PDF and JSON",
      )
      markdown_cmd_assert_contains_for_test(
        corrupt_output, "Accessible PDFs with PDF/UA",
      )
      @test.assert_eq(corrupt_output, clean_output)
      @test.assert_eq(
        markdown_cmd_replacement_count_for_test(corrupt_output),
        0,
      )
      markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
      markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
    }
    markdown_cmd_remove_if_exists_for_test(clean_output_path)
  }
}

///|
async test "markdown command converts optional cpdf source manual image PDF corpus" {
  let mut checked = 0
  let mut textful = 0
  for path in markdown_cmd_cpdf_source_manual_image_pdf_paths_for_test() {
    let input_path = markdown_cmd_repo_path_for_test(path)
    if @fs.exists(input_path) {
      checked += 1
      let output_path = markdown_cmd_output_path_for_test(
        "cpdf_source_manual_image_" + checked.to_string(),
      )
      markdown_cmd_remove_if_exists_for_test(output_path)
      markdown_cmd_convert_file(input_path, output_path)
      let output = @utf8.decode_lossy(@fs.read_file(output_path).binary())
      markdown_cmd_assert_cpdf_manual_image_markdown_for_test(output, path)
      if output != "# Page 1\n\n\n" {
        textful += 1
      }
      markdown_cmd_remove_if_exists_for_test(output_path)
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      markdown_cmd_cpdf_source_manual_image_pdf_paths_for_test().length(),
    )
    @test.assert_eq(textful > 0, true)
  }
}

///|
async test "markdown command reconstructs optional cpdf source manual image PDF corpus with malformed classic xref metadata and rows" {
  let mut checked = 0
  let mut textful = 0
  for path in markdown_cmd_cpdf_source_manual_image_pdf_paths_for_test() {
    let input_path = markdown_cmd_repo_path_for_test(path)
    if @fs.exists(input_path) {
      checked += 1
      let clean_output_path = markdown_cmd_output_path_for_test(
        "cpdf_source_manual_image_clean_" + checked.to_string(),
      )
      markdown_cmd_remove_if_exists_for_test(clean_output_path)
      markdown_cmd_convert_file(input_path, clean_output_path)
      let clean_output = @utf8.decode_lossy(
        @fs.read_file(clean_output_path).binary(),
      )
      markdown_cmd_assert_cpdf_manual_image_markdown_for_test(
        clean_output, path,
      )
      if clean_output != "# Page 1\n\n\n" {
        textful += 1
      }
      let input_bytes = @fs.read_file(input_path).binary()
      let mut case_index = 0
      for
        corrupted in [
          markdown_cmd_corrupt_startxref_pointer_for_test(input_bytes),
          markdown_cmd_corrupt_startxref_xref_header_for_test(input_bytes),
          markdown_cmd_corrupt_startxref_trailer_keyword_for_test(input_bytes),
          markdown_cmd_corrupt_first_in_use_xref_marker_for_test(input_bytes),
          markdown_cmd_corrupt_first_in_use_xref_offset_for_test(input_bytes),
          markdown_cmd_corrupt_first_in_use_xref_generation_for_test(
            input_bytes,
          ),
          markdown_cmd_corrupt_first_xref_subsection_object_for_test(
            input_bytes,
          ),
          markdown_cmd_corrupt_first_xref_subsection_count_for_test(input_bytes),
        ] {
        case_index += 1
        let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
          corrupted,
        )
        guard strict is Err(_) else {
          fail(
            "expected malformed classic xref data to require malformed reconstruction for " +
            path,
          )
        }
        let corrupt_input_path = markdown_cmd_output_path_for_test(
          "cpdf_source_manual_image_input_" +
          checked.to_string() +
          "_" +
          case_index.to_string(),
        )
        let corrupt_output_path = markdown_cmd_output_path_for_test(
          "cpdf_source_manual_image_recovered_" +
          checked.to_string() +
          "_" +
          case_index.to_string(),
        )
        markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
        markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
        @fs.write_file(corrupt_input_path, corrupted, create=0o644)
        markdown_cmd_convert_file(corrupt_input_path, corrupt_output_path)
        let corrupt_output = @utf8.decode_lossy(
          @fs.read_file(corrupt_output_path).binary(),
        )
        markdown_cmd_assert_cpdf_manual_image_markdown_for_test(
          corrupt_output, path,
        )
        @test.assert_eq(corrupt_output, clean_output, msg=path)
        markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
        markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
      }
      markdown_cmd_remove_if_exists_for_test(clean_output_path)
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      markdown_cmd_cpdf_source_manual_image_pdf_paths_for_test().length(),
    )
    @test.assert_eq(textful > 0, true)
  }
}

///|
async test "markdown command converts optional cpdf source top-level classic PDF corpus" {
  let mut checked = 0
  let mut textful = 0
  for path in markdown_cmd_cpdf_source_top_level_classic_pdf_paths_for_test() {
    let input_path = markdown_cmd_repo_path_for_test(path)
    if @fs.exists(input_path) {
      checked += 1
      let output_path = markdown_cmd_output_path_for_test(
        "cpdf_source_top_level_classic_" + checked.to_string(),
      )
      markdown_cmd_remove_if_exists_for_test(output_path)
      markdown_cmd_convert_file(input_path, output_path)
      let output = @utf8.decode_lossy(@fs.read_file(output_path).binary())
      markdown_cmd_assert_cpdf_top_level_classic_markdown_for_test(output, path)
      if output != "# Page 1\n\n\n" {
        textful += 1
      }
      markdown_cmd_remove_if_exists_for_test(output_path)
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      markdown_cmd_cpdf_source_top_level_classic_pdf_paths_for_test().length(),
    )
    @test.assert_eq(textful > 0, true)
  }
}

///|
async test "markdown command reconstructs optional cpdf source top-level classic PDF corpus with malformed xref metadata and rows" {
  let mut checked = 0
  let mut textful = 0
  for path in markdown_cmd_cpdf_source_top_level_classic_pdf_paths_for_test() {
    let input_path = markdown_cmd_repo_path_for_test(path)
    if @fs.exists(input_path) {
      checked += 1
      let clean_output_path = markdown_cmd_output_path_for_test(
        "cpdf_source_top_level_classic_clean_" + checked.to_string(),
      )
      markdown_cmd_remove_if_exists_for_test(clean_output_path)
      markdown_cmd_convert_file(input_path, clean_output_path)
      let clean_output = @utf8.decode_lossy(
        @fs.read_file(clean_output_path).binary(),
      )
      markdown_cmd_assert_cpdf_top_level_classic_markdown_for_test(
        clean_output, path,
      )
      if clean_output != "# Page 1\n\n\n" {
        textful += 1
      }
      let input_bytes = @fs.read_file(input_path).binary()
      let mut case_index = 0
      for
        corrupted in [
          markdown_cmd_corrupt_startxref_pointer_for_test(input_bytes),
          markdown_cmd_corrupt_startxref_xref_header_for_test(input_bytes),
          markdown_cmd_corrupt_startxref_trailer_keyword_for_test(input_bytes),
          markdown_cmd_corrupt_first_in_use_xref_marker_for_test(input_bytes),
          markdown_cmd_corrupt_first_in_use_xref_offset_for_test(input_bytes),
          markdown_cmd_corrupt_first_in_use_xref_generation_for_test(
            input_bytes,
          ),
          markdown_cmd_corrupt_first_xref_subsection_object_for_test(
            input_bytes,
          ),
          markdown_cmd_corrupt_first_xref_subsection_count_for_test(input_bytes),
        ] {
        case_index += 1
        let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
          corrupted,
        )
        guard strict is Err(_) else {
          fail(
            "expected malformed classic xref data to require malformed reconstruction for " +
            path,
          )
        }
        let corrupt_input_path = markdown_cmd_output_path_for_test(
          "cpdf_source_top_level_classic_input_" +
          checked.to_string() +
          "_" +
          case_index.to_string(),
        )
        let corrupt_output_path = markdown_cmd_output_path_for_test(
          "cpdf_source_top_level_classic_" +
          checked.to_string() +
          "_" +
          case_index.to_string(),
        )
        markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
        markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
        @fs.write_file(corrupt_input_path, corrupted, create=0o644)
        markdown_cmd_convert_file(corrupt_input_path, corrupt_output_path)
        let corrupt_output = @utf8.decode_lossy(
          @fs.read_file(corrupt_output_path).binary(),
        )
        markdown_cmd_assert_cpdf_top_level_classic_markdown_for_test(
          corrupt_output, path,
        )
        @test.assert_eq(corrupt_output, clean_output, msg=path)
        markdown_cmd_remove_if_exists_for_test(corrupt_input_path)
        markdown_cmd_remove_if_exists_for_test(corrupt_output_path)
      }
      markdown_cmd_remove_if_exists_for_test(clean_output_path)
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      markdown_cmd_cpdf_source_top_level_classic_pdf_paths_for_test().length(),
    )
    @test.assert_eq(textful > 0, true)
  }
}

///|
async test "markdown command converts optional external Adobe supplement fixture" {
  let input_path = markdown_cmd_repo_path_for_test(
    "markdown/external_fixtures/downloads/adobe_supplement_iso32000_1.pdf",
  )
  if @fs.exists(input_path) {
    let output_path = markdown_cmd_output_path_for_test("adobe_supplement")
    markdown_cmd_remove_if_exists_for_test(output_path)
    markdown_cmd_convert_file(input_path, output_path)
    let output = @utf8.decode_lossy(@fs.read_file(output_path).binary())
    markdown_cmd_assert_contains_for_test(output, "Adobe® Supplement to")
    markdown_cmd_assert_contains_for_test(output, "ISO 32000-1")
    markdown_cmd_assert_contains_for_test(output, "ExtensionLevel: 5")
    @test.assert_eq(markdown_cmd_raw_control_count_for_test(output), 0)
    markdown_cmd_remove_if_exists_for_test(output_path)
  }
}

///|
async test "markdown command converts optional external Unicode CJK chart fixture" {
  let input_path = markdown_cmd_repo_path_for_test(
    "markdown/external_fixtures/downloads/unicode_cjk_unified_ideographs_u4e00.pdf",
  )
  if @fs.exists(input_path) {
    let output_path = markdown_cmd_output_path_for_test("unicode_cjk_chart")
    markdown_cmd_remove_if_exists_for_test(output_path)
    markdown_cmd_convert_file(input_path, output_path)
    let output = @utf8.decode_lossy(@fs.read_file(output_path).binary())
    markdown_cmd_assert_contains_for_test(output, "CJK Unified Ideographs")
    markdown_cmd_assert_contains_for_test(output, "Range: 4E00")
    markdown_cmd_assert_contains_for_test(output, "9FFF")
    markdown_cmd_assert_contains_for_test(output, "一")
    markdown_cmd_assert_contains_for_test(output, "鿿")
    @test.assert_eq(markdown_cmd_raw_control_count_for_test(output), 0)
    @test.assert_eq(markdown_cmd_replacement_count_for_test(output), 0)
    @test.assert_eq(
      markdown_cmd_unique_cjk_unified_count_for_test(output),
      20963,
    )
    markdown_cmd_remove_if_exists_for_test(output_path)
  }
}
