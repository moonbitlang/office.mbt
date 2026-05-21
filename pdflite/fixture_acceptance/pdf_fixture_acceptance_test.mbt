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
fn fixture_acceptance_assert_cpdf_logo_catalog_view_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  @test.assert_eq(
    document.catalog_item(fixture_acceptance_pdf_name_for_test("/PageMode")),
    "UseNone",
  )
  let expected_open_action : @pdflite.PdfObject = PdfArray([
    PdfInteger(1),
    PdfNameObject(fixture_acceptance_pdf_name_for_test("/XYZ")),
    PdfInteger(-32768),
    PdfInteger(-32768),
    PdfInteger(1),
  ])
  @test.assert_eq(document.open_action(), expected_open_action)
  @test.assert_eq(document.open_action_string(), "[1 /XYZ -32768 -32768 1]")
  let open_action_json = @ascii.decode_lossy(document.open_action_json_blob())
  fixture_acceptance_assert_contains_for_test(open_action_json, "\"I\":1")
  fixture_acceptance_assert_contains_for_test(
    open_action_json, "\"N\":\"/XYZ\"",
  )
  fixture_acceptance_assert_contains_for_test(open_action_json, "\"I\":-32768")
  let info_json = document.info_json().stringify()
  fixture_acceptance_assert_contains_for_test(info_json, "\"Pages\":1")
  fixture_acceptance_assert_contains_for_test(
    info_json, "\"PageMode\":\"UseNone\"",
  )
  fixture_acceptance_assert_contains_for_test(info_json, "\"N\":\"/XYZ\"")
  fixture_acceptance_assert_contains_for_test(info_json, "\"I\":-32768")
}

///|
fn fixture_acceptance_assert_cpdf_h1_struct_tree_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  @test.assert_eq(document.version(), (2, 0))
  @test.assert_eq(
    document.catalog_item(
      fixture_acceptance_pdf_name_for_test("/StructTreeRoot"),
    ),
    "True",
  )
  @test.assert_eq(
    document.mark_info_item(fixture_acceptance_pdf_name_for_test("/Marked")),
    false,
  )
  let info_json = document.info_json().stringify()
  fixture_acceptance_assert_contains_for_test(info_json, "\"Version\":[2,0]")
  fixture_acceptance_assert_contains_for_test(info_json, "\"Pages\":1")
  fixture_acceptance_assert_contains_for_test(info_json, "\"Marked\":false")
  let struct_text = @utf8.decode_lossy(document.struct_tree_text())
  fixture_acceptance_assert_contains_for_test(struct_text, "StructTreeRoot\n")
  fixture_acceptance_assert_contains_for_test(struct_text, "H1 (1)")
  fixture_acceptance_assert_contains_for_test(struct_text, "P (1)")
  let struct_json = document.extract_struct_tree().stringify()
  @test.assert_eq(
    @utf8.decode_lossy(document.struct_tree_json_blob()),
    struct_json,
  )
  fixture_acceptance_assert_contains_for_test(
    struct_json, "\"/CPDFJSONformatversion\"",
  )
  fixture_acceptance_assert_contains_for_test(
    struct_json, "\"/CPDFJSONpageobjnumbers\"",
  )
  fixture_acceptance_assert_contains_for_test(struct_json, "\"/Type\"")
  fixture_acceptance_assert_contains_for_test(
    struct_json, "{\"N\":\"/StructTreeRoot\"}",
  )
  fixture_acceptance_assert_contains_for_test(struct_json, "{\"N\":\"/H1\"}")
  fixture_acceptance_assert_contains_for_test(struct_json, "{\"N\":\"/P\"}")
  let replaced = document.replace_struct_tree(document.extract_struct_tree())
  @test.assert_eq(@utf8.decode_lossy(replaced.struct_tree_text()), struct_text)
}

///|
fn fixture_acceptance_assert_cpdf_logo_boxes_and_transparency_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let logo_box : @pdflite.PdfRectangle = {
    min_x: 0.0,
    min_y: 0.0,
    max_x: 56.693,
    max_y: 56.693,
  }
  @test.assert_eq(document.parse_rectangle(pages[0].mediabox), logo_box)
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/BleedBox"),
      pages[0].rest,
    )
    is Some(bleedbox) else {
    fail("missing logo BleedBox")
  }
  @test.assert_eq(document.parse_rectangle(bleedbox), logo_box)
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/TrimBox"),
      pages[0].rest,
    )
    is Some(trimbox) else {
    fail("missing logo TrimBox")
  }
  @test.assert_eq(document.parse_rectangle(trimbox), logo_box)
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/Group"),
      pages[0].rest,
    )
    is Some(group) else {
    fail("missing logo transparency group")
  }
  @test.assert_eq(
    document.lookup_direct(fixture_acceptance_pdf_name_for_test("/S"), group),
    Some(PdfNameObject(fixture_acceptance_pdf_name_for_test("/Transparency"))),
  )
  @test.assert_eq(
    document.lookup_direct(fixture_acceptance_pdf_name_for_test("/I"), group),
    Some(PdfBoolean(true)),
  )
  @test.assert_eq(
    document.lookup_direct(fixture_acceptance_pdf_name_for_test("/K"), group),
    Some(PdfBoolean(false)),
  )
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/ExtGState"),
      pages[0].resources,
    )
    is Some(extgstate) else {
    fail("missing logo ExtGState resources")
  }
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/G0"),
      extgstate,
    )
    is Some(g0) else {
    fail("missing logo /G0 ExtGState")
  }
  @test.assert_eq(
    document.lookup_direct(fixture_acceptance_pdf_name_for_test("/BM"), g0),
    Some(PdfNameObject(fixture_acceptance_pdf_name_for_test("/Compatible"))),
  )
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/G1"),
      extgstate,
    )
    is Some(g1) else {
    fail("missing logo /G1 ExtGState")
  }
  @test.assert_eq(
    document.lookup_direct(fixture_acceptance_pdf_name_for_test("/BM"), g1),
    Some(PdfNameObject(fixture_acceptance_pdf_name_for_test("/Normal"))),
  )
  let page_info_text = @ascii.decode_lossy(document.page_info_text([1]))
  fixture_acceptance_assert_contains_for_test(
    page_info_text, "MediaBox: 0.000000 0.000000 56.693000 56.693000\n",
  )
  fixture_acceptance_assert_contains_for_test(
    page_info_text, "BleedBox: 0.000000 0.000000 56.693000 56.693000\n",
  )
  fixture_acceptance_assert_contains_for_test(
    page_info_text, "TrimBox: 0.000000 0.000000 56.693000 56.693000\n",
  )
  let info_json = document.info_json().stringify()
  fixture_acceptance_assert_contains_for_test(info_json, "\"BleedBox\":[0")
  fixture_acceptance_assert_contains_for_test(info_json, "\"TrimBox\":[0")
  fixture_acceptance_assert_contains_for_test(info_json, "56.693")
}

///|
fn fixture_acceptance_content_ops_contain_gs_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  name : @pdflite.PdfName,
) -> Bool {
  for op in ops {
    match op {
      Op_gs(op_name) if op_name == name => break true
      _ => ()
    }
  } nobreak {
    false
  }
}

///|
fn fixture_acceptance_assert_cpdf_trans_extgstate_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  @test.assert_eq(document.version(), (2, 0))
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/ExtGState"),
      pages[0].resources,
    )
    is Some(extgstate) else {
    fail("missing trans ExtGState resources")
  }
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/G1"),
      extgstate,
    )
    is Some(g1) else {
    fail("missing trans /G1 ExtGState")
  }
  guard document.lookup_direct(fixture_acceptance_pdf_name_for_test("/ca"), g1)
    is Some(alpha) else {
    fail("missing trans fill alpha")
  }
  @test.assert_eq(document.get_number(alpha), 0.5)
  let ops = document.parse_content_ops_with_resources(
    pages[0].resources,
    pages[0].content,
  )
  @test.assert_eq(
    fixture_acceptance_content_ops_contain_gs_for_test(
      ops,
      fixture_acceptance_pdf_name_for_test("/G1"),
    ),
    true,
  )
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
fn fixture_acceptance_replacement_count_for_test(text : String) -> Int {
  let mut count = 0
  for char in text {
    if char.to_int() == 0xFFFD {
      count += 1
    }
  }
  count
}

///|
fn fixture_acceptance_raw_control_count_for_test(text : String) -> Int {
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
fn fixture_acceptance_assert_cpdf_manual_page_labels_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let expected_labels : Array[@pdflite.PdfPageLabel] = [
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: None,
      start_page: 1,
      start_value: 1,
    },
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: None,
      start_page: 19,
      start_value: 1,
    },
  ]
  @test.assert_eq(document.read_page_labels(), expected_labels)
  let page_info_json = document.page_info_json([1, 19, 175]).stringify()
  fixture_acceptance_assert_contains_for_test(page_info_json, "\"Page\":1")
  fixture_acceptance_assert_contains_for_test(page_info_json, "\"Page\":19")
  fixture_acceptance_assert_contains_for_test(page_info_json, "\"Page\":175")
  fixture_acceptance_assert_contains_for_test(page_info_json, "\"Label\":\"i\"")
  fixture_acceptance_assert_contains_for_test(page_info_json, "\"Label\":\"1\"")
  fixture_acceptance_assert_contains_for_test(
    page_info_json, "\"Label\":\"157\"",
  )
  let page_info_text = @ascii.decode_lossy(
    document.page_info_text([1, 19, 175]),
  )
  fixture_acceptance_assert_contains_for_test(
    page_info_text, "Page 1:\nLabel: i\n",
  )
  fixture_acceptance_assert_contains_for_test(
    page_info_text, "Page 19:\nLabel: 1\n",
  )
  fixture_acceptance_assert_contains_for_test(
    page_info_text, "Page 175:\nLabel: 157\n",
  )
  @test.assert_eq(document.addtext_page_label(1), "i")
  @test.assert_eq(document.addtext_page_label(19), "1")
  @test.assert_eq(document.addtext_page_label(175), "157")
  let replacement_values = document.addtext_replacement_values(
    document.read_bookmarks(preserve_actions=true),
    19,
    175,
    "cpdfmanual.pdf",
    42,
    Some(5),
  )
  @test.assert_eq(replacement_values.page_label, "1")
  @test.assert_eq(replacement_values.end_label, "157")
  @test.assert_eq(
    @pdflite.pdf_addtext_process_text_with_time(
      @pdflite.pdf_strftime_dummy_time(),
      "%Label|%EndLabel|%Page|%EndPage|%filename|%Bates",
      @pdflite.pdf_addtext_replacement_pairs(replacement_values),
    ),
    "1|157|19|175|cpdfmanual.pdf|00060",
  )
}

///|
fn fixture_acceptance_assert_cpdf_manual_text_extraction_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let text = @utf8.decode_lossy(document.test_extract_text([1, 19, 31, 33]))
  fixture_acceptance_assert_contains_for_test(text, "CoherentPDF")
  fixture_acceptance_assert_contains_for_test(text, "CommandLineTools")
  fixture_acceptance_assert_contains_for_test(text, "Chapter1BasicUsage")
  fixture_acceptance_assert_contains_for_test(
    text, "Chapter2MergingandSplitting",
  )
  fixture_acceptance_assert_contains_for_test(text, "SplittingonBookmarks")
  @test.assert_eq(text.length() > 2000, true)
  @test.assert_eq(fixture_acceptance_replacement_count_for_test(text), 0)
  @test.assert_eq(fixture_acceptance_raw_control_count_for_test(text), 0)
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
fn fixture_acceptance_assert_cpdf_manual_bookmarks_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let bookmarks = document.read_bookmarks(preserve_actions=true)
  @test.assert_eq(bookmarks.length(), 163)
  @test.assert_eq(bookmarks[0].level, 0)
  @test.assert_eq(document.page_number_of_target(bookmarks[0].target), 19)
  @test.assert_eq(bookmarks[21].level, 0)
  @test.assert_eq(document.page_number_of_target(bookmarks[21].target), 31)
  let bookmarks_json = document
    .bookmarks_json(json_preserve_actions=true)
    .stringify()
  fixture_acceptance_assert_contains_for_test(
    bookmarks_json, "\"text\":\"1 Basic Usage\"",
  )
  fixture_acceptance_assert_contains_for_test(
    bookmarks_json, "\"text\":\"2 Merging and Splitting\"",
  )
  fixture_acceptance_assert_contains_for_test(
    bookmarks_json, "\"text\":\"6 Bookmarks\"",
  )
  fixture_acceptance_assert_contains_for_test(bookmarks_json, "\"page\":19")
  let bookmarks_blob = @ascii.decode_lossy(
    document.bookmarks_json_blob(json_preserve_actions=true),
  )
  fixture_acceptance_assert_contains_for_test(
    bookmarks_blob, "\"text\":\"1 Basic Usage\"",
  )
  let listed = @ascii.decode_lossy(
    document.list_bookmarks([19, 31, 33], encoding=PdfMetadataUTF8),
  )
  fixture_acceptance_assert_contains_for_test(listed, "0 \"1 Basic Usage\" 19")
  fixture_acceptance_assert_contains_for_test(
    listed, "0 \"2 Merging and Splitting\" 31",
  )
  fixture_acceptance_assert_contains_for_test(
    listed, "1 \"2.4 Splitting on Bookmarks\" 33",
  )
}

///|
fn fixture_acceptance_cpdf_toc_fontpack_for_test() -> @pdflite.PdfFontPack raise {
  @pdflite.pdf_fontpack_of_standard_font(
    PdfFontStandard({ font: PdfHelvetica, encoding: PdfWinAnsiEncoding }),
  )
}

///|
fn fixture_acceptance_type_text_contains_for_test(
  elements : ArrayView[@pdflite.PdfTypeElement],
  fragment : String,
) -> Bool {
  for element in elements {
    match element {
      PdfTypeText(text) =>
        if @ascii.decode_lossy(text).contains(fragment) {
          break true
        }
      _ => ()
    }
  } nobreak {
    false
  }
}

///|
fn fixture_acceptance_type_dest_contains_for_test(
  elements : ArrayView[@pdflite.PdfTypeElement],
  fragment : String,
) -> Bool {
  for element in elements {
    match element {
      PdfTypeBeginDest(_, Some(text)) =>
        if text.contains(fragment) {
          break true
        }
      _ => ()
    }
  } nobreak {
    false
  }
}

///|
fn fixture_acceptance_assert_cpdf_manual_toc_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let original_bookmarks = document.read_bookmarks(preserve_actions=true)
  @test.assert_eq(original_bookmarks.length(), 163)
  let title = @ascii.encode("Contents\\nGenerated")
  let pack = fixture_acceptance_cpdf_toc_fontpack_for_test()
  let toc_bookmarks = [
    original_bookmarks[0],
    original_bookmarks[21],
    original_bookmarks[25],
  ]
  let used = document.toc_used_codepoints([], title, toc_bookmarks)
  @test.assert_eq(used.contains(46), true)
  @test.assert_eq(used.contains(67), true)
  @test.assert_eq(used.contains(49), true)
  let elements = document.toc_type_elements(
    pack,
    9.0,
    title,
    true,
    false,
    [],
    toc_bookmarks,
    540.0,
    54.0,
  )
  @test.assert_eq(
    fixture_acceptance_type_text_contains_for_test(elements, "Contents"),
    true,
  )
  @test.assert_eq(
    fixture_acceptance_type_text_contains_for_test(elements, "Basic"),
    true,
  )
  @test.assert_eq(
    fixture_acceptance_type_text_contains_for_test(elements, "Usage"),
    true,
  )
  @test.assert_eq(
    fixture_acceptance_type_text_contains_for_test(elements, "31"),
    true,
  )
  @test.assert_eq(
    fixture_acceptance_type_text_contains_for_test(elements, "."),
    true,
  )
  @test.assert_eq(
    fixture_acceptance_type_dest_contains_for_test(elements, "Basic"),
    true,
  )
  @test.assert_eq(
    fixture_acceptance_type_dest_contains_for_test(elements, "Merging"),
    true,
  )
  let updated = document.toc_add_bookmark(title)
  let bookmarks = updated.read_bookmarks(preserve_actions=true)
  @test.assert_eq(bookmarks.length(), original_bookmarks.length() + 1)
  @test.assert_eq(bookmarks[0].text, @pdflite.pdf_toc_bookmark_text(title))
  @test.assert_eq(updated.page_number_of_target(bookmarks[0].target), 1)
  @test.assert_eq(bookmarks[1].text, original_bookmarks[0].text)
  @test.assert_eq(updated.page_number_of_target(bookmarks[1].target), 19)
}

///|
fn fixture_acceptance_assert_cpdf_manual_toc_bookmark_roundtrip_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  let original_bookmarks = document.read_bookmarks(preserve_actions=true)
  @test.assert_eq(original_bookmarks.length(), 164)
  @test.assert_eq(
    original_bookmarks[0].text,
    @pdflite.pdf_toc_bookmark_text(@ascii.encode("Contents\\nGenerated")),
  )
  @test.assert_eq(
    document.page_number_of_target(original_bookmarks[0].target),
    1,
  )
  @test.assert_eq(
    document.page_number_of_target(original_bookmarks[1].target),
    19,
  )
}

///|
fn fixture_acceptance_cpdf_manual_toc_bookmark_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  document.toc_add_bookmark(@ascii.encode("Contents\\nGenerated"))
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
fn fixture_acceptance_image_document_i0_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfObject raise {
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/XObject"),
      pages[0].resources,
    )
    is Some(xobjects) else {
    fail("missing image document XObject resources")
  }
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/I0"),
      xobjects,
    )
    is Some(image) else {
    fail("missing image document /I0 image")
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
fn fixture_acceptance_assert_cpdf_sheet_png_image_document_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let pages = document.pages_of_pagetree()
  @test.assert_eq(document.parse_rectangle(pages[0].mediabox), {
    min_x: 0.0,
    min_y: 0.0,
    max_x: 400.0,
    max_y: 294.0,
  })
  let images_json = document.images_json([1]).stringify()
  fixture_acceptance_assert_contains_for_test(images_json, "\"Name\":\"/I0\"")
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
  let image = fixture_acceptance_image_document_i0_for_test(document)
  match
    document.get_image_24bpp(document.pages_of_pagetree()[0].resources, image) {
    PdfRawImage(width, height, PdfBPP24, data) => {
      @test.assert_eq(width, 400)
      @test.assert_eq(height, 294)
      @test.assert_eq(data.length(), 400 * 294 * 3)
    }
    _ => fail("expected source sheet PNG image document to decode as 24bpp")
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
fn fixture_acceptance_assert_cpdf_fonts_fixture_for_test(
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
  fixture_acceptance_assert_contains_for_test(
    fonts_text, "1 /F1 /Type1 /Times-Roman /WinAnsiEncoding\n",
  )
  fixture_acceptance_assert_contains_for_test(
    fonts_text, "1 /F2 /Type1 /Times-BoldItalic /WinAnsiEncoding\n",
  )
  let fonts_json = document.fonts_json([1]).stringify()
  fixture_acceptance_assert_contains_for_test(fonts_json, "\"name\":\"/F1\"")
  fixture_acceptance_assert_contains_for_test(
    fonts_json, "\"basefont\":\"/Times-Roman\"",
  )
  fixture_acceptance_assert_contains_for_test(fonts_json, "\"name\":\"/F2\"")
  fixture_acceptance_assert_contains_for_test(
    fonts_json, "\"basefont\":\"/Times-BoldItalic\"",
  )
  let fonts_blob = @ascii.decode_lossy(document.fonts_json_blob([1]))
  fixture_acceptance_assert_contains_for_test(fonts_blob, "\"name\":\"/F1\"")
  let first_font = document.font_from_name("/F1", 1)
  @test.assert_eq(first_font != PdfNull, true)
  @test.assert_eq(document.font_from_name("/Missing", 1), PdfNull)
  let font_table = @ascii.decode_lossy(document.font_table_text("/F1", 1))
  fixture_acceptance_assert_contains_for_test(
    font_table, "65 = U+0041 (A - LATIN CAPITAL LETTER A) = A\n",
  )
  let missing = document.missing_fonts([1])
  @test.assert_eq(missing.length(), 2)
  @test.assert_eq(missing[0].name, "/F1")
  @test.assert_eq(missing[0].basefont, "/Times-Roman")
  @test.assert_eq(missing[1].name, "/F2")
  @test.assert_eq(missing[1].basefont, "/Times-BoldItalic")
  let missing_text = @ascii.decode_lossy(document.missing_fonts_text([1]))
  fixture_acceptance_assert_contains_for_test(
    missing_text, "1, /F1, /Type1, /Times-Roman, /WinAnsiEncoding\n",
  )
  fixture_acceptance_assert_contains_for_test(
    missing_text, "1, /F2, /Type1, /Times-BoldItalic, /WinAnsiEncoding\n",
  )
}

///|
fn fixture_acceptance_assert_cpdf_text_content_for_test(
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
  let text = @ascii.decode_lossy(document.test_extract_text([1]))
  fixture_acceptance_assert_contains_for_test(text, "Hello")
  let content_json = document.page_content_json([1]).stringify()
  fixture_acceptance_assert_contains_for_test(content_json, "\"page\":1")
  fixture_acceptance_assert_contains_for_test(content_json, "\"obj\":\"glyph\"")
  fixture_acceptance_assert_contains_for_test(
    content_json, "\"extracted text\":\"H\"",
  )
}

///|
fn fixture_acceptance_assert_cpdf_xobject_content_for_test(
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
  let content_json = document.page_content_json([1]).stringify()
  fixture_acceptance_assert_contains_for_test(content_json, "\"page\":1")
  fixture_acceptance_assert_contains_for_test(content_json, "\"obj\":\"path\"")
  fixture_acceptance_assert_contains_for_test(content_json, "\"bbox\"")
}

///|
fn fixture_acceptance_assert_cpdf_manual_image_content_corpus_for_test(
  document : @pdflite.PdfDocument,
) -> (Int, Int, Int) raise {
  @test.assert_eq(document.endpage(), 1)
  let pages = document.pages_of_pagetree()
  let entries = document.content_entries_of_page(pages[0])
  @test.assert_eq(entries.length() > 0, true)
  let mut glyphs = 0
  let mut images = 0
  let mut paths = 0
  for entry in entries {
    match entry.object {
      PdfContentGlyphObject(_, _, extracted_text) => {
        glyphs += 1
        @test.assert_eq(extracted_text.length() > 0, true)
      }
      PdfContentImageObject(_) => images += 1
      PdfContentPathObject(_) => paths += 1
      _ => ()
    }
  }
  let content_json = document.page_content_json([1]).stringify()
  fixture_acceptance_assert_contains_for_test(content_json, "\"page\":1")
  fixture_acceptance_assert_contains_for_test(content_json, "\"bbox\"")
  (glyphs, images, paths)
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
async test "optional cpdf source logo fixture reports catalog view metadata" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/logo.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_logo_catalog_view_for_test(document)
      fixture_acceptance_assert_cpdf_logo_catalog_view_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      fixture_acceptance_assert_cpdf_logo_catalog_view_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source transparency fixtures preserve resources" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/logo.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_logo_boxes_and_transparency_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_logo_boxes_and_transparency_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      fixture_acceptance_assert_cpdf_logo_boxes_and_transparency_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
  }
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/trans.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_trans_extgstate_for_test(document)
      fixture_acceptance_assert_cpdf_trans_extgstate_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      fixture_acceptance_assert_cpdf_trans_extgstate_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
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
async test "optional cpdf source raw sheet PNG creates image document" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/sheet.png",
    ) {
    None => ()
    Some(bytes) => {
      let png = @pdflite.pdf_read_png(bytes)
      @test.assert_eq(png.width, 400)
      @test.assert_eq(png.height, 294)
      @test.assert_eq(png.bit_depth, 8)
      @test.assert_eq(png.color_type, 2)
      @test.assert_eq(png.idat.length() > 0, true)
      let document = @pdflite.pdf_image_document_of_png_data(bytes)
      fixture_acceptance_assert_cpdf_sheet_png_image_document_for_test(document)
      fixture_acceptance_assert_cpdf_sheet_png_image_document_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "optional cpdf source manual font fixture reports font tables" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/fonts.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_fonts_fixture_for_test(document)
      fixture_acceptance_assert_cpdf_fonts_fixture_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "optional cpdf source manual content fixtures export content JSON" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/text.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_text_content_for_test(document)
      fixture_acceptance_assert_cpdf_text_content_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/xobj.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_xobject_content_for_test(document)
      fixture_acceptance_assert_cpdf_xobject_content_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "optional cpdf source h1 fixture reports structure tree" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/h1.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_h1_struct_tree_for_test(document)
      fixture_acceptance_assert_cpdf_h1_struct_tree_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      fixture_acceptance_assert_cpdf_h1_struct_tree_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source manual image fixtures traverse content entries" {
  let mut checked = 0
  let mut glyphs = 0
  let mut images = 0
  let mut paths = 0
  for path in fixture_acceptance_cpdf_manual_image_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        let document = @pdflite.pdf_read_document_from_bytes(bytes)
        let (doc_glyphs, doc_images, doc_paths) = fixture_acceptance_assert_cpdf_manual_image_content_corpus_for_test(
          document,
        )
        let (rewritten_glyphs, rewritten_images, rewritten_paths) = fixture_acceptance_assert_cpdf_manual_image_content_corpus_for_test(
          fixture_acceptance_reparse_compressed_for_test(document),
        )
        @test.assert_eq(rewritten_glyphs, doc_glyphs)
        @test.assert_eq(rewritten_images, doc_images)
        @test.assert_eq(rewritten_paths, doc_paths)
        glyphs += doc_glyphs
        images += doc_images
        paths += doc_paths
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      fixture_acceptance_cpdf_manual_image_paths_for_test.length(),
    )
    @test.assert_eq(glyphs > 0, true)
    @test.assert_eq(images > 0, true)
    @test.assert_eq(paths > 0, true)
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
async test "optional cpdf source manual fixture reports page label fallbacks" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_page_labels_for_test(document)
      fixture_acceptance_assert_cpdf_manual_page_labels_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      fixture_acceptance_assert_cpdf_manual_page_labels_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture extracts selected text" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_text_extraction_for_test(document)
      fixture_acceptance_assert_cpdf_manual_text_extraction_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      fixture_acceptance_assert_cpdf_manual_text_extraction_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
        ),
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
async test "optional cpdf source manual fixture lists bookmarks" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_bookmarks_for_test(document)
      fixture_acceptance_assert_cpdf_manual_bookmarks_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      let rebuilt = try! document
        .remove_bookmarks()
        .add_bookmarks(document.read_bookmarks(preserve_actions=true))
      fixture_acceptance_assert_cpdf_manual_bookmarks_for_test(rebuilt)
      fixture_acceptance_assert_cpdf_manual_bookmarks_for_test(
        fixture_acceptance_reparse_compressed_for_test(rebuilt),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixture builds table of contents" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_toc_for_test(document)
      fixture_acceptance_assert_cpdf_manual_toc_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      let bookmarked = fixture_acceptance_cpdf_manual_toc_bookmark_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_manual_toc_bookmark_roundtrip_for_test(
        bookmarked,
      )
      fixture_acceptance_assert_cpdf_manual_toc_bookmark_roundtrip_for_test(
        fixture_acceptance_reparse_compressed_for_test(bookmarked),
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
