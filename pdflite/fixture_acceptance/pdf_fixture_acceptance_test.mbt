///|
fn fixture_acceptance_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
async fn fixture_acceptance_bytes_for_test(path : String) -> Bytes {
  @fs.read_file(fixture_acceptance_path_for_test(path)).binary()
}

///|
async fn fixture_acceptance_optional_bytes_for_test(path : String) -> Bytes? {
  let read_result = try? @fs.read_file(fixture_acceptance_path_for_test(path))
  match read_result {
    Ok(data) => Some(data.binary())
    Err(_) => None
  }
}

///|
fn fixture_acceptance_bytes_start_with_at_for_test(
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
fn fixture_acceptance_find_last_bytes_for_test(
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
      if fixture_acceptance_bytes_start_with_at_for_test(
          haystack, needle, start,
        ) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn fixture_acceptance_find_bytes_for_test(
  haystack : BytesView,
  needle : BytesView,
) -> Int {
  if needle.length() == 0 {
    0
  } else if haystack.length() < needle.length() {
    -1
  } else {
    for start in 0..<=(haystack.length() - needle.length()) {
      if fixture_acceptance_bytes_start_with_at_for_test(
          haystack, needle, start,
        ) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn fixture_acceptance_push_ascii_for_test(
  output : Array[Byte],
  text : String,
) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn fixture_acceptance_corrupt_startxref_pointer_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let marker = @ascii.encode("startxref")
  let marker_position = fixture_acceptance_find_last_bytes_for_test(
    bytes, marker,
  )
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
  fixture_acceptance_push_ascii_for_test(
    output,
    (bytes.length() + 4096).to_string(),
  )
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn fixture_acceptance_startxref_offset_for_test(bytes : Bytes) -> Int raise {
  let marker = @ascii.encode("startxref")
  let marker_position = fixture_acceptance_find_last_bytes_for_test(
    bytes, marker,
  )
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
fn fixture_acceptance_corrupt_startxref_xref_header_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let xref_offset = fixture_acceptance_startxref_offset_for_test(bytes)
  guard fixture_acceptance_bytes_start_with_at_for_test(
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
fn fixture_acceptance_corrupt_startxref_trailer_keyword_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let xref_offset = fixture_acceptance_startxref_offset_for_test(bytes)
  let trailer_position = fixture_acceptance_find_bytes_after_for_test(
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
fn fixture_acceptance_corrupt_first_in_use_xref_marker_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let free_row = @ascii.encode("0000000000 65535 f")
  let free_row_position = fixture_acceptance_find_bytes_for_test(
    bytes, free_row,
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
fn fixture_acceptance_first_in_use_xref_row_start_for_test(
  bytes : Bytes,
) -> Int raise {
  let free_row = @ascii.encode("0000000000 65535 f")
  let free_row_position = fixture_acceptance_find_bytes_for_test(
    bytes, free_row,
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
fn fixture_acceptance_corrupt_first_in_use_xref_offset_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = fixture_acceptance_first_in_use_xref_row_start_for_test(bytes)
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
fn fixture_acceptance_corrupt_first_in_use_xref_generation_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let row_start = fixture_acceptance_first_in_use_xref_row_start_for_test(bytes)
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
fn fixture_acceptance_first_xref_subsection_spans_for_test(
  bytes : Bytes,
) -> (Int, Int, Int, Int) raise {
  let header = @ascii.encode("xref")
  let header_position = fixture_acceptance_find_bytes_for_test(bytes, header)
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
fn fixture_acceptance_corrupt_first_xref_subsection_object_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let (object_start, object_end, _, _) = fixture_acceptance_first_xref_subsection_spans_for_test(
    bytes,
  )
  let output : Array[Byte] = []
  for index in 0..<object_start {
    output.push(bytes[index])
  }
  fixture_acceptance_push_ascii_for_test(output, "/Bad")
  for index in object_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn fixture_acceptance_corrupt_first_xref_subsection_count_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let (_, _, count_start, count_end) = fixture_acceptance_first_xref_subsection_spans_for_test(
    bytes,
  )
  let output : Array[Byte] = []
  for index in 0..<count_start {
    output.push(bytes[index])
  }
  fixture_acceptance_push_ascii_for_test(output, "/Bad")
  for index in count_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn fixture_acceptance_replace_first_bytes_for_test(
  bytes : Bytes,
  target : BytesView,
  replacement : BytesView,
) -> Bytes raise {
  if target.length() != replacement.length() {
    fail("replacement must preserve byte length")
  }
  let position = fixture_acceptance_find_bytes_for_test(bytes, target)
  if position < 0 {
    fail("expected replacement target")
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
fn fixture_acceptance_find_bytes_after_for_test(
  haystack : BytesView,
  needle : BytesView,
  start : Int,
) -> Int {
  if needle.length() == 0 {
    start
  } else if start < 0 ||
    start >= haystack.length() ||
    haystack.length() - start < needle.length() {
    -1
  } else {
    for position in start..<=(haystack.length() - needle.length()) {
      if fixture_acceptance_bytes_start_with_at_for_test(
          haystack, needle, position,
        ) {
        break position
      }
    } nobreak {
      -1
    }
  }
}

///|
fn fixture_acceptance_replace_bytes_after_for_test(
  bytes : Bytes,
  anchor : BytesView,
  target : BytesView,
  replacement : BytesView,
) -> Bytes raise {
  if target.length() != replacement.length() {
    fail("replacement must preserve byte length")
  }
  let anchor_position = fixture_acceptance_find_bytes_for_test(bytes, anchor)
  if anchor_position < 0 {
    fail("expected replacement anchor")
  }
  let position = fixture_acceptance_find_bytes_after_for_test(
    bytes,
    target,
    anchor_position + anchor.length(),
  )
  if position < 0 {
    fail("expected replacement target after anchor")
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
fn fixture_acceptance_replace_bytes_after_with_padded_ascii_for_test(
  bytes : Bytes,
  anchor : BytesView,
  target : BytesView,
  replacement_text : String,
) -> Bytes raise {
  let replacement = @ascii.encode(replacement_text)
  if replacement.length() > target.length() {
    fail("replacement must fit target byte span")
  }
  let anchor_position = fixture_acceptance_find_bytes_for_test(bytes, anchor)
  if anchor_position < 0 {
    fail("expected replacement anchor")
  }
  let position = fixture_acceptance_find_bytes_after_for_test(
    bytes,
    target,
    anchor_position + anchor.length(),
  )
  if position < 0 {
    fail("expected replacement target after anchor")
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
fn fixture_acceptance_replace_bytes_at_for_test(
  bytes : Bytes,
  position : Int,
  target : BytesView,
  replacement : BytesView,
  description : String,
) -> Bytes raise {
  if target.length() != replacement.length() {
    fail("replacement must preserve byte length")
  }
  if !fixture_acceptance_bytes_start_with_at_for_test(bytes, target, position) {
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
fn fixture_acceptance_corrupt_xref_stream_widths_for_test(
  bytes : Bytes,
) -> Bytes raise {
  fixture_acceptance_replace_first_bytes_for_test(
    bytes,
    @ascii.encode("/W [1 3 1]"),
    @ascii.encode("/W /Bad   "),
  )
}

///|
fn fixture_acceptance_corrupt_bare_xref_stream_widths_for_test(
  bytes : Bytes,
) -> Bytes raise {
  fixture_acceptance_replace_first_bytes_for_test(
    bytes,
    @ascii.encode("/W[1 2 2]"),
    @ascii.encode("/W/Bad123"),
  )
}

///|
fn fixture_acceptance_corrupt_xref_stream_index_entry_for_test(
  bytes : Bytes,
  index_entry : BytesView,
) -> Bytes raise {
  fixture_acceptance_replace_bytes_after_with_padded_ascii_for_test(
    bytes,
    @ascii.encode("/Type /XRef"),
    index_entry,
    "/Index /Bad",
  )
}

///|
fn fixture_acceptance_corrupt_startxref_xref_stream_type_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let xref_offset = fixture_acceptance_startxref_offset_for_test(bytes)
  let target = @ascii.encode("/Type /XRef")
  let replacement = @ascii.encode("/Type /Bad")
  let position = fixture_acceptance_find_bytes_after_for_test(
    bytes, target, xref_offset,
  )
  if position < 0 {
    fail("expected xref stream type at startxref target")
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
fn fixture_acceptance_corrupt_startxref_xref_stream_token_for_test(
  bytes : Bytes,
  target : BytesView,
  replacement : BytesView,
  description : String,
) -> Bytes raise {
  let xref_offset = fixture_acceptance_startxref_offset_for_test(bytes)
  let position = fixture_acceptance_find_bytes_after_for_test(
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
fn fixture_acceptance_corrupt_startxref_xref_stream_marker_for_test(
  bytes : Bytes,
) -> Bytes raise {
  fixture_acceptance_corrupt_startxref_xref_stream_token_for_test(
    bytes,
    @ascii.encode("stream"),
    @ascii.encode("stramx"),
    "stream marker",
  )
}

///|
fn fixture_acceptance_corrupt_startxref_xref_stream_endstream_for_test(
  bytes : Bytes,
) -> Bytes raise {
  fixture_acceptance_corrupt_startxref_xref_stream_token_for_test(
    bytes,
    @ascii.encode("endstream"),
    @ascii.encode("endstreax"),
    "endstream marker",
  )
}

///|
fn fixture_acceptance_corrupt_startxref_xref_stream_endobj_for_test(
  bytes : Bytes,
) -> Bytes raise {
  fixture_acceptance_corrupt_startxref_xref_stream_token_for_test(
    bytes,
    @ascii.encode("endobj"),
    @ascii.encode("endobx"),
    "endobj marker",
  )
}

///|
fn fixture_acceptance_corrupt_xref_stream_root_entry_for_test(
  bytes : Bytes,
  root_entry : BytesView,
) -> Bytes raise {
  fixture_acceptance_replace_bytes_after_with_padded_ascii_for_test(
    bytes,
    @ascii.encode("/Type /XRef"),
    root_entry,
    "/Root /Bad",
  )
}

///|
fn fixture_acceptance_corrupt_xref_stream_length_entry_for_test(
  bytes : Bytes,
  length_entry : BytesView,
) -> Bytes raise {
  fixture_acceptance_replace_bytes_after_with_padded_ascii_for_test(
    bytes,
    @ascii.encode("/Type /XRef"),
    length_entry,
    "/Length /Bad",
  )
}

///|
fn fixture_acceptance_corrupt_xref_stream_decodeparms_entry_for_test(
  bytes : Bytes,
  metadata_entry : BytesView,
  replacement_text : String,
) -> Bytes raise {
  fixture_acceptance_replace_bytes_after_with_padded_ascii_for_test(
    bytes,
    @ascii.encode("/Type /XRef"),
    metadata_entry,
    replacement_text,
  )
}

///|
fn fixture_acceptance_skip_pdf_whitespace_for_test(
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
fn fixture_acceptance_stream_data_start_for_test(
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
fn fixture_acceptance_direct_length_before_for_test(
  bytes : BytesView,
  anchor_position : Int,
  limit : Int,
  description : String,
) -> Int raise {
  let length_key = @ascii.encode("/Length")
  let length_position = fixture_acceptance_find_bytes_after_for_test(
    bytes, length_key, anchor_position,
  )
  if length_position < 0 || length_position >= limit {
    fail("expected direct stream length for " + description)
  }
  let mut current = fixture_acceptance_skip_pdf_whitespace_for_test(
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
fn fixture_acceptance_first_object_stream_stream_position_for_test(
  bytes : BytesView,
) -> Int raise {
  let anchor = @ascii.encode("/Type /ObjStm")
  let anchor_position = fixture_acceptance_find_bytes_for_test(bytes, anchor)
  if anchor_position < 0 {
    fail("expected first object stream")
  }
  let stream_marker = @ascii.encode("stream")
  let stream_position = fixture_acceptance_find_bytes_after_for_test(
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
fn fixture_acceptance_first_object_stream_endstream_position_for_test(
  bytes : BytesView,
) -> Int raise {
  let anchor = @ascii.encode("/Type /ObjStm")
  let anchor_position = fixture_acceptance_find_bytes_for_test(bytes, anchor)
  if anchor_position < 0 {
    fail("expected first object stream")
  }
  let stream_position = fixture_acceptance_first_object_stream_stream_position_for_test(
    bytes,
  )
  let length = fixture_acceptance_direct_length_before_for_test(
    bytes, anchor_position, stream_position, "first object stream",
  )
  let marker_position = fixture_acceptance_skip_pdf_whitespace_for_test(
    bytes,
    fixture_acceptance_stream_data_start_for_test(bytes, stream_position) +
    length,
  )
  if !fixture_acceptance_bytes_start_with_at_for_test(
      bytes,
      @ascii.encode("endstream"),
      marker_position,
    ) {
    fail("expected first object stream endstream marker")
  }
  marker_position
}

///|
fn fixture_acceptance_first_object_stream_endobj_position_for_test(
  bytes : BytesView,
) -> Int raise {
  let endstream_position = fixture_acceptance_first_object_stream_endstream_position_for_test(
    bytes,
  )
  let endobj_position = fixture_acceptance_skip_pdf_whitespace_for_test(
    bytes,
    endstream_position + @ascii.encode("endstream").length(),
  )
  if !fixture_acceptance_bytes_start_with_at_for_test(
      bytes,
      @ascii.encode("endobj"),
      endobj_position,
    ) {
    fail("expected first object stream endobj marker")
  }
  endobj_position
}

///|
fn fixture_acceptance_corrupt_first_object_stream_count_for_test(
  bytes : Bytes,
) -> Bytes raise {
  fixture_acceptance_replace_bytes_after_with_padded_ascii_for_test(
    bytes,
    @ascii.encode("/Type /ObjStm"),
    @ascii.encode("/N 100"),
    "/N/Bad",
  )
}

///|
fn fixture_acceptance_corrupt_first_object_stream_first_for_test(
  bytes : Bytes,
) -> Bytes raise {
  fixture_acceptance_replace_bytes_after_with_padded_ascii_for_test(
    bytes,
    @ascii.encode("/Type /ObjStm"),
    @ascii.encode("/First 832"),
    "/First/Bad",
  )
}

///|
fn fixture_acceptance_corrupt_first_object_stream_length_for_test(
  bytes : Bytes,
) -> Bytes raise {
  fixture_acceptance_replace_bytes_after_with_padded_ascii_for_test(
    bytes,
    @ascii.encode("/Type /ObjStm"),
    @ascii.encode("/Length 1526"),
    "/Length /Bad",
  )
}

///|
fn fixture_acceptance_corrupt_first_object_stream_filter_for_test(
  bytes : Bytes,
) -> Bytes raise {
  fixture_acceptance_replace_bytes_after_for_test(
    bytes,
    @ascii.encode("/Type /ObjStm"),
    @ascii.encode("/Filter /FlateDecode"),
    @ascii.encode("/Filter /NoSuchThing"),
  )
}

///|
fn fixture_acceptance_corrupt_first_object_stream_marker_for_test(
  bytes : Bytes,
) -> Bytes raise {
  fixture_acceptance_replace_bytes_at_for_test(
    bytes,
    fixture_acceptance_first_object_stream_stream_position_for_test(bytes),
    @ascii.encode("stream"),
    @ascii.encode("stramx"),
    "first object stream marker",
  )
}

///|
fn fixture_acceptance_corrupt_first_object_stream_endstream_for_test(
  bytes : Bytes,
) -> Bytes raise {
  fixture_acceptance_replace_bytes_at_for_test(
    bytes,
    fixture_acceptance_first_object_stream_endstream_position_for_test(bytes),
    @ascii.encode("endstream"),
    @ascii.encode("endstreax"),
    "first object stream endstream marker",
  )
}

///|
fn fixture_acceptance_corrupt_first_object_stream_endobj_for_test(
  bytes : Bytes,
) -> Bytes raise {
  fixture_acceptance_replace_bytes_at_for_test(
    bytes,
    fixture_acceptance_first_object_stream_endobj_position_for_test(bytes),
    @ascii.encode("endobj"),
    @ascii.encode("endobx"),
    "first object stream endobj marker",
  )
}

///|
fn fixture_acceptance_corrupt_xref_stream_filter_for_test(
  bytes : Bytes,
) -> Bytes raise {
  fixture_acceptance_replace_bytes_after_for_test(
    bytes,
    @ascii.encode("/Type /XRef"),
    @ascii.encode("/Filter /FlateDecode"),
    @ascii.encode("/Filter /NoSuchThing"),
  )
}

///|
fn fixture_acceptance_reparse_compressed_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  @pdflite.pdf_read_document_from_bytes(
    @pdflite.pdf_write_document_with_compressed_xref_stream(document),
  )
}

///|
fn fixture_acceptance_assert_reads_and_rewrites_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let document = @pdflite.pdf_read_document_from_bytes(bytes)
  @test.assert_eq(document.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(document)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_startxref_pointer_for_test(bytes)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected malformed startxref to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_xref_header_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_startxref_xref_header_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected malformed xref header to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_trailer_keyword_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_startxref_trailer_keyword_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    match strict {
      Err(error) => fail(error.to_json().stringify())
      Ok(_) =>
        fail("expected malformed trailer keyword to require reconstruction")
    }
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_classic_xref_marker_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_first_in_use_xref_marker_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected malformed classic xref marker to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_classic_xref_offset_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_first_in_use_xref_offset_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected malformed classic xref offset to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_classic_xref_generation_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_first_in_use_xref_generation_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected malformed classic xref generation to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_classic_xref_object_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_first_xref_subsection_object_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail(
      "expected malformed classic xref object number to require reconstruction",
    )
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_classic_xref_count_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_first_xref_subsection_count_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(_) else {
    fail("expected malformed classic xref count to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_xref_stream_widths_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_xref_stream_widths_for_test(bytes)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref stream widths to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_bare_xref_stream_widths_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_bare_xref_stream_widths_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed bare xref stream widths to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_xref_stream_index_entry_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
  index_entry : BytesView,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_xref_stream_index_entry_for_test(
    bytes, index_entry,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected malformed xref stream index to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_xref_stream_index_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  fixture_acceptance_assert_xref_stream_index_entry_reconstructs_for_test(
    bytes,
    expected_pages,
    @ascii.encode("/Index [0 104]"),
  )
}

///|
fn fixture_acceptance_assert_xref_stream_type_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_startxref_xref_stream_type_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected malformed xref stream type to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_xref_stream_marker_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_startxref_xref_stream_marker_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected malformed xref stream marker to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_xref_stream_endstream_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_startxref_xref_stream_endstream_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::ParseEndStreamExpected) else {
    fail("expected malformed xref stream endstream to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_xref_stream_endobj_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_startxref_xref_stream_endobj_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::ParseEndObjectExpected) else {
    fail("expected malformed xref stream endobj to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_xref_stream_root_entry_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
  root_entry : BytesView,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_xref_stream_root_entry_for_test(
    bytes, root_entry,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::RootExpected) else {
    match strict {
      Err(error) => fail(error.to_json().stringify())
      Ok(_) =>
        fail("expected malformed xref stream root to require reconstruction")
    }
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_object_stream_count_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_first_object_stream_count_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    match strict {
      Err(error) => fail(error.to_json().stringify())
      Ok(_) =>
        fail("expected malformed object stream count to require reconstruction")
    }
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_object_stream_first_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_first_object_stream_first_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    match strict {
      Err(error) => fail(error.to_json().stringify())
      Ok(_) =>
        fail("expected malformed object stream first to require reconstruction")
    }
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_object_stream_length_repairs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_first_object_stream_length_for_test(
    bytes,
  )
  let document = @pdflite.pdf_read_classic_document_from_bytes(corrupted)
  @test.assert_eq(document.first_xref() > 0, true)
  @test.assert_eq(document.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(document)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_object_stream_filter_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_first_object_stream_filter_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::FilterNotSupported(_)) else {
    match strict {
      Err(error) => fail(error.to_json().stringify())
      Ok(_) =>
        fail(
          "expected malformed object stream filter to require reconstruction",
        )
    }
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_object_stream_marker_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_first_object_stream_marker_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::ParseStreamExpected) else {
    match strict {
      Err(error) => fail(error.to_json().stringify())
      Ok(_) =>
        fail(
          "expected malformed object stream marker to require reconstruction",
        )
    }
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_object_stream_endstream_repairs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_first_object_stream_endstream_for_test(
    bytes,
  )
  let document = @pdflite.pdf_read_classic_document_from_bytes(corrupted)
  @test.assert_eq(document.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(document)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_object_stream_endobj_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_first_object_stream_endobj_for_test(
    bytes,
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::ParseEndObjectExpected) else {
    match strict {
      Err(error) => fail(error.to_json().stringify())
      Ok(_) =>
        fail(
          "expected malformed object stream endobj to require reconstruction",
        )
    }
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_xref_stream_length_entry_repairs_for_test(
  bytes : Bytes,
  expected_pages : Int,
  length_entry : BytesView,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_xref_stream_length_entry_for_test(
    bytes, length_entry,
  )
  let repaired = @pdflite.pdf_read_classic_document_from_bytes(corrupted)
  @test.assert_eq(repaired.first_xref() > 0, true)
  @test.assert_eq(repaired.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(repaired)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_xref_stream_decodeparms_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  fixture_acceptance_assert_xref_stream_decodeparms_entry_reconstructs_for_test(
    bytes,
    expected_pages,
    @ascii.encode(
      "/ID [<2E7D00CFC8082E6E6E4942CA3A7D6E63> <2E7D00CFC8082E6E6E4942CA3A7D6E63>]",
    ),
  )
}

///|
fn fixture_acceptance_assert_xref_stream_decodeparms_entry_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
  metadata_entry : BytesView,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_xref_stream_decodeparms_entry_for_test(
    bytes, metadata_entry, "/DecodeParms /Bad",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::PredictorExpected) else {
    fail("expected malformed xref stream DecodeParms to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_xref_stream_decodeparms_predictor_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  fixture_acceptance_assert_xref_stream_decodeparms_predictor_entry_reconstructs_for_test(
    bytes,
    expected_pages,
    @ascii.encode(
      "/ID [<2E7D00CFC8082E6E6E4942CA3A7D6E63> <2E7D00CFC8082E6E6E4942CA3A7D6E63>]",
    ),
  )
}

///|
fn fixture_acceptance_assert_xref_stream_decodeparms_predictor_entry_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
  metadata_entry : BytesView,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_xref_stream_decodeparms_entry_for_test(
    bytes, metadata_entry, "/DecodeParms << /Predictor 9 >>",
  )
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::PredictorNotSupported(predictor)) else {
    fail("expected unsupported xref stream DecodeParms predictor")
  }
  @test.assert_eq(predictor, 9)
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
fn fixture_acceptance_assert_xref_stream_filter_reconstructs_for_test(
  bytes : Bytes,
  expected_pages : Int,
) -> Unit raise {
  let corrupted = fixture_acceptance_corrupt_xref_stream_filter_for_test(bytes)
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    corrupted,
  )
  guard strict is Err(@pdflite.PdfError::FilterNotSupported(_)) else {
    fail("expected malformed xref stream filter to require reconstruction")
  }
  let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
  @test.assert_eq(recovered.first_xref(), 0)
  @test.assert_eq(recovered.endpage(), expected_pages)
  let reparsed = fixture_acceptance_reparse_compressed_for_test(recovered)
  @test.assert_eq(reparsed.endpage(), expected_pages)
}

///|
let fixture_acceptance_cpdf_manual_image_paths_for_test : Array[String] = [
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

///|
let fixture_acceptance_cpdf_top_level_pdf_paths_for_test : Array[String] = [
  ".repos/cpdf-source/cpdfmanual.pdf", ".repos/cpdf-source/hello.pdf", ".repos/cpdf-source/logo.pdf",
]

///|
fn fixture_acceptance_cpdf_top_level_expected_pages_for_test(
  path : String,
) -> Int raise {
  match path {
    ".repos/cpdf-source/cpdfmanual.pdf" => 175
    ".repos/cpdf-source/hello.pdf" => 1
    ".repos/cpdf-source/logo.pdf" => 1
    _ => fail("unexpected cpdf source top-level PDF path: " + path)
  }
}

///|
fn fixture_acceptance_assert_cpdf_manual_pagespec_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let all = document.parse_pagespec("")
  @test.assert_eq(all.length(), 175)
  @test.assert_eq(all[0], 1)
  @test.assert_eq(all[174], 175)
  @test.assert_eq(document.parse_pagespec("1,3-5,end,~2"), [
    1, 3, 4, 5, 175, 174,
  ])
  @test.assert_eq(document.parse_pagespec("end-172"), [175, 174, 173, 172])
  @test.assert_eq(document.parse_pagespec("NOT1-172"), [173, 174, 175])
  @test.assert_eq(document.parse_pagespec("2DUP174-end"), [174, 174, 175, 175])
  @test.assert_eq(document.parse_pagespec("1-10odd"), [1, 3, 5, 7, 9])
  @test.assert_eq(document.parse_pagespec("1-10even"), [2, 4, 6, 8, 10])
  let portrait = document.parse_pagespec("portrait")
  @test.assert_eq(portrait.length(), 175)
  @test.assert_eq(portrait[0], 1)
  @test.assert_eq(portrait[174], 175)
  @test.assert_eq(document.parse_pagespec("landscape"), [])
  @test.assert_eq(document.parse_pagespec("1-10portrait"), [
    1, 2, 3, 4, 5, 6, 7, 8, 9, 10,
  ])
  @test.assert_eq(document.parse_pagespec("1-10landscape"), [])
  let annotated = document.parse_pagespec("annotated")
  @test.assert_eq(annotated.length() > 0, true)
  @test.assert_eq(annotated[0] >= 1, true)
  @test.assert_eq(annotated[annotated.length() - 1] <= 175, true)
  @test.assert_eq(
    document.string_of_pagespec(document.parse_pagespec("1,3-5,end,~2")),
    "1,3-5,174-175",
  )
}

///|
fn fixture_acceptance_assert_contains_for_test(
  text : String,
  fragment : String,
) -> Unit raise {
  @test.assert_eq(text.contains(fragment), true, msg="missing " + fragment)
}

///|
fn fixture_acceptance_pdf_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn fixture_acceptance_composition_entry_bytes_for_test(
  entries : ArrayView[@pdflite.PdfCompositionEntry],
  label : String,
) -> Int raise {
  for entry in entries {
    if entry.label == label {
      break entry.bytes
    }
  } nobreak {
    fail("missing composition entry " + label)
    0
  }
}

///|
fn fixture_acceptance_assert_cpdf_manual_reports_for_test(
  document : @pdflite.PdfDocument,
  file_size : Int,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let info_json = document.info_json().stringify()
  fixture_acceptance_assert_contains_for_test(info_json, "\"Version\":[1,7]")
  fixture_acceptance_assert_contains_for_test(info_json, "\"Pages\":175")
  fixture_acceptance_assert_contains_for_test(
    info_json, "\"Creator\":\"LaTeX with hyperref\"",
  )
  fixture_acceptance_assert_contains_for_test(
    info_json, "\"Producer\":\"pdfTeX-1.40.29\"",
  )
  let xmp_json = document.xmp_info_json().stringify()
  fixture_acceptance_assert_contains_for_test(xmp_json, "\"Subformats\":[]")
  fixture_acceptance_assert_contains_for_test(xmp_json, "\"Language\":null")
  let page_info_json = document.page_info_json([1, 175]).stringify()
  fixture_acceptance_assert_contains_for_test(page_info_json, "\"Page\":1")
  fixture_acceptance_assert_contains_for_test(page_info_json, "\"Page\":175")
  fixture_acceptance_assert_contains_for_test(page_info_json, "\"Rotation\":0")
  let page_info_text = @ascii.decode_lossy(document.page_info_text([1, 175]))
  fixture_acceptance_assert_contains_for_test(page_info_text, "Page 1:\n")
  fixture_acceptance_assert_contains_for_test(page_info_text, "Page 175:\n")
  fixture_acceptance_assert_contains_for_test(
    page_info_text, "MediaBox: 0.000000 0.000000 540.000000 666.000000\n",
  )
  fixture_acceptance_assert_contains_for_test(page_info_text, "Rotation: 0\n")
  let composition = document.composition(file_size)
  @test.assert_eq(composition.length(), 8)
  @test.assert_eq(composition[0].label, "Images")
  @test.assert_eq(composition[1].label, "Fonts")
  @test.assert_eq(composition[2].label, "Content streams")
  @test.assert_eq(composition[5].label, "XRef Table")
  @test.assert_eq(
    fixture_acceptance_composition_entry_bytes_for_test(composition, "Fonts") >
    0,
    true,
  )
  @test.assert_eq(
    fixture_acceptance_composition_entry_bytes_for_test(
      composition, "Content streams",
    ) >
    0,
    true,
  )
  @test.assert_eq(
    fixture_acceptance_composition_entry_bytes_for_test(
      composition, "XRef Table",
    ) >
    0,
    true,
  )
  let composition_json = document.composition_json(file_size).stringify()
  fixture_acceptance_assert_contains_for_test(composition_json, "[\"Fonts\",")
  fixture_acceptance_assert_contains_for_test(
    composition_json, "[\"Content streams\",",
  )
  fixture_acceptance_assert_contains_for_test(
    composition_json, "[\"XRef Table\",",
  )
}

///|
fn fixture_acceptance_assert_cpdf_manual_annotations_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let annotated = document.parse_pagespec("annotated")
  @test.assert_eq(annotated.length() > 0, true)
  let page = annotated[0]
  let annotation_json = document.annotations_json([page]).stringify()
  fixture_acceptance_assert_contains_for_test(
    annotation_json, "\"/CPDFJSONannotformatversion\"",
  )
  fixture_acceptance_assert_contains_for_test(annotation_json, "\"/Subtype\"")
  fixture_acceptance_assert_contains_for_test(annotation_json, "\"/Link\"")
  fixture_acceptance_assert_contains_for_test(annotation_json, "\"/Rect\"")
  fixture_acceptance_assert_contains_for_test(annotation_json, "\"/A\"")
  let annotation_blob = @ascii.decode_lossy(
    document.annotations_json_blob([page]),
  )
  fixture_acceptance_assert_contains_for_test(annotation_blob, "\"/Link\"")
  fixture_acceptance_assert_contains_for_test(annotation_blob, "\"/Rect\"")
}

///|
fn fixture_acceptance_cpdf_png_image_object_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfObject raise {
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/XObject"),
      pages[0].resources,
    )
    is Some(xobjects) else {
    fail("missing PNG fixture XObject resources")
  }
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/I1"),
      xobjects,
    )
    is Some(image) else {
    fail("missing PNG fixture /I1 image")
  }
  image
}

///|
fn fixture_acceptance_assert_cpdf_png_image_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let images_json = document.images_json([1]).stringify()
  fixture_acceptance_assert_contains_for_test(images_json, "\"Name\":\"/I1\"")
  fixture_acceptance_assert_contains_for_test(images_json, "\"Pages\":[1]")
  fixture_acceptance_assert_contains_for_test(images_json, "\"Width\":400")
  fixture_acceptance_assert_contains_for_test(images_json, "\"Height\":294")
  fixture_acceptance_assert_contains_for_test(
    images_json, "\"BitsPerComponent\":8",
  )
  fixture_acceptance_assert_contains_for_test(
    images_json, "\"Colourspace\":\"/DeviceRGB\"",
  )
  fixture_acceptance_assert_contains_for_test(
    images_json, "\"Filter\":\"/FlateDecode\"",
  )
  let images_blob = @ascii.decode_lossy(document.images_json_blob([1]))
  fixture_acceptance_assert_contains_for_test(images_blob, "\"Name\":\"/I1\"")
  let resolution_json = document
    .image_resolution_json([1], 1000000.0)
    .stringify()
  fixture_acceptance_assert_contains_for_test(
    resolution_json, "\"XObject\":\"/I1\"",
  )
  fixture_acceptance_assert_contains_for_test(resolution_json, "\"W\":400")
  fixture_acceptance_assert_contains_for_test(resolution_json, "\"H\":294")
  let image = fixture_acceptance_cpdf_png_image_object_for_test(document)
  match
    document.get_image_24bpp(document.pages_of_pagetree()[0].resources, image) {
    PdfRawImage(width, height, PdfBPP24, data) => {
      @test.assert_eq(width, 400)
      @test.assert_eq(height, 294)
      @test.assert_eq(data.length(), 400 * 294 * 3)
    }
    _ =>
      fail("expected extracted PNG fixture image to decode as 24bpp raw data")
  }
}

///|
fn fixture_acceptance_assert_cpdf_manual_images_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let all_pages = document.parse_pagespec("")
  let images_json = document.images_json(all_pages).stringify()
  fixture_acceptance_assert_contains_for_test(images_json, "\"Width\":400")
  fixture_acceptance_assert_contains_for_test(images_json, "\"Height\":294")
  fixture_acceptance_assert_contains_for_test(
    images_json, "\"BitsPerComponent\":8",
  )
  fixture_acceptance_assert_contains_for_test(
    images_json, "\"Colourspace\":\"/DeviceRGB\"",
  )
  fixture_acceptance_assert_contains_for_test(
    images_json, "\"Filter\":\"/FlateDecode\"",
  )
  let images_blob = @ascii.decode_lossy(document.images_json_blob(all_pages))
  fixture_acceptance_assert_contains_for_test(images_blob, "\"Width\":400")
  fixture_acceptance_assert_contains_for_test(images_blob, "\"Height\":294")
  let resolution_json = document
    .image_resolution_json(all_pages, 1000000.0)
    .stringify()
  fixture_acceptance_assert_contains_for_test(resolution_json, "\"W\":400")
  fixture_acceptance_assert_contains_for_test(resolution_json, "\"H\":294")
}

///|
async test "checked-in CamlPDF logo fixture reconstructs linearized bad startxref" {
  fixture_acceptance_assert_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("fixtures/camlpdf/logo.pdf"),
    1,
  )
}

///|
async test "checked-in CamlPDF logo fixture reconstructs malformed classic xref row" {
  fixture_acceptance_assert_classic_xref_marker_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("fixtures/camlpdf/logo.pdf"),
    1,
  )
}

///|
async test "checked-in CamlPDF logo fixture reconstructs malformed classic xref offset" {
  fixture_acceptance_assert_classic_xref_offset_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("fixtures/camlpdf/logo.pdf"),
    1,
  )
}

///|
async test "checked-in CamlPDF logo fixture reconstructs malformed classic xref generation" {
  fixture_acceptance_assert_classic_xref_generation_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("fixtures/camlpdf/logo.pdf"),
    1,
  )
}

///|
async test "checked-in CamlPDF logo fixture reconstructs malformed classic xref object number" {
  fixture_acceptance_assert_classic_xref_object_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("fixtures/camlpdf/logo.pdf"),
    1,
  )
}

///|
async test "checked-in CamlPDF logo fixture reconstructs malformed classic xref count" {
  fixture_acceptance_assert_classic_xref_count_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("fixtures/camlpdf/logo.pdf"),
    1,
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs malformed xref stream widths" {
  fixture_acceptance_assert_xref_stream_widths_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs malformed xref stream index" {
  fixture_acceptance_assert_xref_stream_index_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs malformed xref stream DecodeParms" {
  fixture_acceptance_assert_xref_stream_decodeparms_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs unsupported xref stream DecodeParms predictor" {
  fixture_acceptance_assert_xref_stream_decodeparms_predictor_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs malformed xref stream filter" {
  fixture_acceptance_assert_xref_stream_filter_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in CamlPDF introduction fixture reconstructs xref stream bad startxref" {
  fixture_acceptance_assert_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
  )
}

///|
async test "checked-in Pandoc Latin fixture reconstructs malformed bare xref stream widths" {
  fixture_acceptance_assert_bare_xref_stream_widths_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("markdown/fixtures/pandoc_latin.pdf"),
    2,
  )
}

///|
async test "checked-in Pandoc CJK fixture reconstructs malformed bare xref stream widths" {
  fixture_acceptance_assert_bare_xref_stream_widths_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("markdown/fixtures/pandoc_cjk.pdf"),
    1,
  )
}

///|
async test "checked-in Pandoc Latin fixture reconstructs object-stream bad startxref" {
  fixture_acceptance_assert_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("markdown/fixtures/pandoc_latin.pdf"),
    2,
  )
}

///|
async test "checked-in Pandoc CJK fixture reconstructs object-stream bad startxref" {
  fixture_acceptance_assert_reconstructs_for_test(
    fixture_acceptance_bytes_for_test("markdown/fixtures/pandoc_cjk.pdf"),
    1,
  )
}

///|
async test "optional cpdf source hello fixture reads and rewrites" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_reads_and_rewrites_for_test(bytes, 1)
  }
}

///|
async test "optional cpdf source hello fixture reconstructs bad startxref" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => fixture_acceptance_assert_reconstructs_for_test(bytes, 1)
  }
}

///|
async test "optional cpdf source hello fixture reconstructs malformed classic xref row" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_classic_xref_marker_reconstructs_for_test(
        bytes, 1,
      )
  }
}

///|
async test "optional cpdf source top-level PDF corpus reads rewrites and reconstructs" {
  let mut checked = 0
  let mut pages = 0
  for path in fixture_acceptance_cpdf_top_level_pdf_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        let expected_pages = fixture_acceptance_cpdf_top_level_expected_pages_for_test(
          path,
        )
        pages += expected_pages
        fixture_acceptance_assert_reads_and_rewrites_for_test(
          bytes, expected_pages,
        )
        fixture_acceptance_assert_reconstructs_for_test(bytes, expected_pages)
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      fixture_acceptance_cpdf_top_level_pdf_paths_for_test.length(),
    )
    @test.assert_eq(pages, 177)
  }
}

///|
async test "optional cpdf source manual image fixtures read rewrite and reconstruct" {
  for path in fixture_acceptance_cpdf_manual_image_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        fixture_acceptance_assert_reads_and_rewrites_for_test(bytes, 1)
        fixture_acceptance_assert_reconstructs_for_test(bytes, 1)
      }
    }
  }
}

///|
async test "optional cpdf source manual image fixtures reconstruct damaged xref headers" {
  for path in fixture_acceptance_cpdf_manual_image_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) =>
        fixture_acceptance_assert_xref_header_reconstructs_for_test(bytes, 1)
    }
  }
}

///|
async test "optional cpdf source manual image fixtures reconstruct damaged trailer keywords" {
  for path in fixture_acceptance_cpdf_manual_image_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) =>
        fixture_acceptance_assert_trailer_keyword_reconstructs_for_test(
          bytes, 1,
        )
    }
  }
}

///|
async test "optional cpdf source manual image fixtures reconstruct malformed classic xref rows" {
  for path in fixture_acceptance_cpdf_manual_image_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        fixture_acceptance_assert_classic_xref_marker_reconstructs_for_test(
          bytes, 1,
        )
        fixture_acceptance_assert_classic_xref_offset_reconstructs_for_test(
          bytes, 1,
        )
        fixture_acceptance_assert_classic_xref_generation_reconstructs_for_test(
          bytes, 1,
        )
        fixture_acceptance_assert_classic_xref_object_reconstructs_for_test(
          bytes, 1,
        )
        fixture_acceptance_assert_classic_xref_count_reconstructs_for_test(
          bytes, 1,
        )
      }
    }
  }
}

///|
async test "optional cpdf source PNG image fixture reports and extracts image" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/png.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_png_image_for_test(document)
      fixture_acceptance_assert_cpdf_png_image_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture reads and rewrites" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_reads_and_rewrites_for_test(bytes, 175)
  }
}

///|
async test "optional cpdf source manual fixture parses page specifications" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_pagespec_for_test(document)
      fixture_acceptance_assert_cpdf_manual_pagespec_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture reports info page details and composition" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_reports_for_test(
        document,
        bytes.length(),
      )
      let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
        document,
      )
      fixture_acceptance_assert_cpdf_manual_reports_for_test(
        @pdflite.pdf_read_document_from_bytes(rewritten),
        rewritten.length(),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture reports embedded images" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_images_for_test(document)
      fixture_acceptance_assert_cpdf_manual_images_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture exports annotation JSON" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_annotations_for_test(document)
      fixture_acceptance_assert_cpdf_manual_annotations_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture reconstructs bad startxref" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => fixture_acceptance_assert_reconstructs_for_test(bytes, 175)
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream widths" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_widths_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream index" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_index_entry_reconstructs_for_test(
        bytes,
        175,
        @ascii.encode("/Index [0 1844]"),
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream type" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_type_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream marker" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_marker_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream terminators" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      fixture_acceptance_assert_xref_stream_endstream_reconstructs_for_test(
        bytes, 175,
      )
      fixture_acceptance_assert_xref_stream_endobj_reconstructs_for_test(
        bytes, 175,
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream root" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_root_entry_reconstructs_for_test(
        bytes,
        175,
        @ascii.encode("/Root 1841 0 R"),
      )
  }
}

///|
async test "optional cpdf source manual fixture repairs malformed xref stream length" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_length_entry_repairs_for_test(
        bytes,
        175,
        @ascii.encode("/Length 4551"),
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream DecodeParms" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_decodeparms_entry_reconstructs_for_test(
        bytes,
        175,
        @ascii.encode(
          "/ID [<CA2FED47397E566603B0A9A8E7328C79> <CA2FED47397E566603B0A9A8E7328C79>]",
        ),
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs unsupported xref stream DecodeParms predictor" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_decodeparms_predictor_entry_reconstructs_for_test(
        bytes,
        175,
        @ascii.encode(
          "/ID [<CA2FED47397E566603B0A9A8E7328C79> <CA2FED47397E566603B0A9A8E7328C79>]",
        ),
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed object stream count" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_count_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed object stream first" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_first_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture repairs malformed object stream length" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_length_repairs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed object stream filter" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_filter_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed object stream marker" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_marker_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture repairs malformed object stream endstream" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_endstream_repairs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed object stream endobj" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_object_stream_endobj_reconstructs_for_test(
        bytes, 175,
      )
  }
}

///|
async test "optional cpdf source manual fixture reconstructs malformed xref stream filter" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) =>
      fixture_acceptance_assert_xref_stream_filter_reconstructs_for_test(
        bytes, 175,
      )
  }
}
