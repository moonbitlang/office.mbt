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
let fixture_acceptance_cpdf_draw_operator_paths_for_test : Array[String] = [
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
let fixture_acceptance_cpdf_manual_image_text_paths_for_test : Array[String] = [
  ".repos/cpdf-source/manualimages/fontparams.pdf", ".repos/cpdf-source/manualimages/fonts.pdf",
  ".repos/cpdf-source/manualimages/h1.pdf", ".repos/cpdf-source/manualimages/lines.pdf",
  ".repos/cpdf-source/manualimages/para.pdf", ".repos/cpdf-source/manualimages/paras.pdf",
  ".repos/cpdf-source/manualimages/stext.pdf", ".repos/cpdf-source/manualimages/text.pdf",
  ".repos/cpdf-source/manualimages/textclip.pdf",
]

///|
fn fixture_acceptance_cpdf_manual_image_expected_content_counts_for_test(
  path : String,
) -> (Int, Int, Int) raise {
  match path {
    ".repos/cpdf-source/manualimages/bez.pdf" => (0, 0, 1)
    ".repos/cpdf-source/manualimages/capjoins.pdf" => (0, 0, 1)
    ".repos/cpdf-source/manualimages/clip.pdf" => (0, 0, 1)
    ".repos/cpdf-source/manualimages/colfill.pdf" => (0, 0, 1)
    ".repos/cpdf-source/manualimages/dash.pdf" => (0, 0, 1)
    ".repos/cpdf-source/manualimages/fill.pdf" => (0, 0, 1)
    ".repos/cpdf-source/manualimages/fontparams.pdf" => (25, 0, 0)
    ".repos/cpdf-source/manualimages/fonts.pdf" => (25, 0, 0)
    ".repos/cpdf-source/manualimages/h1.pdf" => (132, 0, 0)
    ".repos/cpdf-source/manualimages/line.pdf" => (0, 0, 1)
    ".repos/cpdf-source/manualimages/lines.pdf" => (23, 0, 0)
    ".repos/cpdf-source/manualimages/matrix.pdf" => (0, 0, 3)
    ".repos/cpdf-source/manualimages/para.pdf" => (81, 0, 0)
    ".repos/cpdf-source/manualimages/paras.pdf" => (156, 0, 0)
    ".repos/cpdf-source/manualimages/png.pdf" => (0, 1, 0)
    ".repos/cpdf-source/manualimages/pop.pdf" => (0, 0, 3)
    ".repos/cpdf-source/manualimages/stext.pdf" => (6, 0, 0)
    ".repos/cpdf-source/manualimages/text.pdf" => (5, 0, 0)
    ".repos/cpdf-source/manualimages/textclip.pdf" => (23, 0, 1)
    ".repos/cpdf-source/manualimages/trans.pdf" => (0, 0, 2)
    ".repos/cpdf-source/manualimages/xobj.pdf" => (0, 0, 2)
    _ => fail("unexpected cpdf manual image path: " + path)
  }
}

///|
fn fixture_acceptance_cpdf_manual_image_expected_text_for_test(
  path : String,
) -> String raise {
  match path {
    ".repos/cpdf-source/manualimages/fontparams.pdf" =>
      "\nDifferent fonts and sizes"
    ".repos/cpdf-source/manualimages/fonts.pdf" => "\nDifferent fonts and sizes"
    ".repos/cpdf-source/manualimages/h1.pdf" =>
      "\nThis is the headingThis is the firstparagraph, whichspreads over more thanone lineHere is the second,which also has multiplelines..."
    ".repos/cpdf-source/manualimages/lines.pdf" => "\nThis ison multiplelines"
    ".repos/cpdf-source/manualimages/para.pdf" =>
      "\nThis is a paragraph ofwidth 200pt,left-justified, containingmore than one line..."
    ".repos/cpdf-source/manualimages/paras.pdf" =>
      "\nThis is the first paragraph, which isspread over multiple lines at thiswidth... And here is the second, alsotaking more than one line. Here is a little one."
    ".repos/cpdf-source/manualimages/stext.pdf" => "\nPage 1"
    ".repos/cpdf-source/manualimages/text.pdf" => "\nHello"
    ".repos/cpdf-source/manualimages/textclip.pdf" =>
      "\nThis ison multiplelines"
    _ => fail("unexpected cpdf manual image text path: " + path)
  }
}

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
fn fixture_acceptance_assert_cpdf_source_show_page_boxes_for_test(
  original : @pdflite.PdfDocument,
  marked : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_same_page_shape_for_test(
    original, marked,
  )
  fixture_acceptance_assert_cpdf_logo_boxes_and_transparency_for_test(marked)
  let ops = fixture_acceptance_page_content_ops_for_test(marked)
  fixture_acceptance_assert_content_op_for_test(
    ops,
    @pdflite.pdf_content_begin_artifact(),
  )
  fixture_acceptance_assert_content_op_for_test(
    ops,
    @pdflite.pdf_content_end_artifact(),
  )
  fixture_acceptance_assert_content_op_for_test(ops, Op_RG(1.0, 0.0, 0.0))
  fixture_acceptance_assert_content_op_for_test(
    ops,
    Op_RG(1.0, 0.588235294118, 0.0),
  )
  fixture_acceptance_assert_content_op_for_test(
    ops,
    Op_RG(1.0, 0.0352941176471, 0.576470588235),
  )
  fixture_acceptance_assert_content_op_for_test(ops, Op_d([], 0.0))
  fixture_acceptance_assert_content_op_for_test(ops, Op_d([3.0, 3.0], 0.0))
  fixture_acceptance_assert_content_op_for_test(ops, Op_d([2.0, 2.0], 0.0))
  @test.assert_eq(
    fixture_acceptance_content_op_count_for_test(
      ops,
      Op_re(0.0, 0.0, 56.693, 56.693),
    ) >=
    3,
    true,
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_trim_marks_for_test(
  original : @pdflite.PdfDocument,
  marked : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_same_page_shape_for_test(
    original, marked,
  )
  fixture_acceptance_assert_cpdf_logo_boxes_and_transparency_for_test(marked)
  let ops = fixture_acceptance_page_content_ops_for_test(marked)
  fixture_acceptance_assert_content_op_for_test(ops, Op_K(1.0, 1.0, 1.0, 1.0))
  fixture_acceptance_assert_content_op_for_test(ops, Op_w(1.0))
  fixture_acceptance_assert_content_op_for_test(
    ops,
    @pdflite.pdf_content_begin_artifact(),
  )
  fixture_acceptance_assert_content_op_for_test(
    ops,
    @pdflite.pdf_content_end_artifact(),
  )
  fixture_acceptance_assert_content_op_for_test(ops, Op_m(0.0, 56.693))
  fixture_acceptance_assert_content_op_for_test(ops, Op_l(-9.0, 56.693))
  fixture_acceptance_assert_content_op_for_test(ops, Op_m(56.693, -9.0))
  fixture_acceptance_assert_content_op_for_test(ops, Op_l(56.693, 0.0))
  @test.assert_eq(
    fixture_acceptance_content_op_count_for_test(ops, Op_s) >= 8,
    true,
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_prefixed_logo_resources_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/ExtGState"),
      pages[0].resources,
    )
    is Some(extgstate) else {
    fail("missing stamped logo ExtGState resources")
  }
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/aG0"),
      extgstate,
    )
    is Some(g0) else {
    fail("missing prefixed stamped logo /aG0 ExtGState")
  }
  @test.assert_eq(
    document.lookup_direct(fixture_acceptance_pdf_name_for_test("/BM"), g0),
    Some(PdfNameObject(fixture_acceptance_pdf_name_for_test("/Compatible"))),
  )
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/aG1"),
      extgstate,
    )
    is Some(g1) else {
    fail("missing prefixed stamped logo /aG1 ExtGState")
  }
  @test.assert_eq(
    document.lookup_direct(fixture_acceptance_pdf_name_for_test("/BM"), g1),
    Some(PdfNameObject(fixture_acceptance_pdf_name_for_test("/Normal"))),
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_logo_rest_merged_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let logo_box : @pdflite.PdfRectangle = {
    min_x: 0.0,
    min_y: 0.0,
    max_x: 56.693,
    max_y: 56.693,
  }
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/BleedBox"),
      pages[0].rest,
    )
    is Some(bleedbox) else {
    fail("missing merged logo BleedBox")
  }
  @test.assert_eq(document.parse_rectangle(bleedbox), logo_box)
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/TrimBox"),
      pages[0].rest,
    )
    is Some(trimbox) else {
    fail("missing merged logo TrimBox")
  }
  @test.assert_eq(document.parse_rectangle(trimbox), logo_box)
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/Group"),
      pages[0].rest,
    )
    is Some(group) else {
    fail("missing merged logo transparency group")
  }
  @test.assert_eq(
    document.lookup_direct(fixture_acceptance_pdf_name_for_test("/S"), group),
    Some(PdfNameObject(fixture_acceptance_pdf_name_for_test("/Transparency"))),
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_stamp_for_test(
  original : @pdflite.PdfDocument,
  stamped : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(original.endpage(), 1)
  @test.assert_eq(stamped.endpage(), 1)
  let original_pages = original.pages_of_pagetree()
  let stamped_pages = stamped.pages_of_pagetree()
  @test.assert_eq(stamped_pages[0].mediabox, original_pages[0].mediabox)
  @test.assert_eq(stamped_pages[0].rotate, original_pages[0].rotate)
  fixture_acceptance_assert_cpdf_source_prefixed_logo_resources_for_test(
    stamped,
  )
  fixture_acceptance_assert_cpdf_source_logo_rest_merged_for_test(stamped)
  let text = @utf8.decode_lossy(stamped.test_extract_text([1]))
  fixture_acceptance_assert_contains_for_test(text, "Hello, World!")
  let ops = fixture_acceptance_page_content_ops_for_test(stamped)
  fixture_acceptance_assert_content_op_for_test(
    ops,
    Op_Tj(@ascii.encode("Hello, World!")),
  )
  @test.assert_eq(
    fixture_acceptance_content_ops_contain_translation_cm_for_test(
      ops, 10.0, 20.0,
    ),
    true,
  )
  @test.assert_eq(
    fixture_acceptance_content_ops_contain_gs_for_test(
      ops,
      fixture_acceptance_pdf_name_for_test("/aG0"),
    ) ||
    fixture_acceptance_content_ops_contain_gs_for_test(
      ops,
      fixture_acceptance_pdf_name_for_test("/aG1"),
    ),
    true,
  )
  @test.assert_eq(
    fixture_acceptance_content_save_count_for_test(ops) >= 2,
    true,
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_combine_for_test(
  original : @pdflite.PdfDocument,
  combined : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(original.endpage(), 1)
  @test.assert_eq(combined.endpage(), 1)
  let original_pages = original.pages_of_pagetree()
  let combined_pages = combined.pages_of_pagetree()
  @test.assert_eq(combined_pages[0].mediabox, original_pages[0].mediabox)
  @test.assert_eq(combined_pages[0].rotate, original_pages[0].rotate)
  fixture_acceptance_assert_cpdf_source_prefixed_logo_resources_for_test(
    combined,
  )
  fixture_acceptance_assert_cpdf_source_logo_rest_merged_for_test(combined)
  let text = @utf8.decode_lossy(combined.test_extract_text([1]))
  fixture_acceptance_assert_contains_for_test(text, "Hello, World!")
  let ops = fixture_acceptance_page_content_ops_for_test(combined)
  fixture_acceptance_assert_content_op_for_test(
    ops,
    Op_Tj(@ascii.encode("Hello, World!")),
  )
  @test.assert_eq(
    fixture_acceptance_content_ops_contain_scaled_cm_for_test(ops),
    true,
  )
  @test.assert_eq(
    fixture_acceptance_content_ops_contain_gs_for_test(
      ops,
      fixture_acceptance_pdf_name_for_test("/aG0"),
    ) ||
    fixture_acceptance_content_ops_contain_gs_for_test(
      ops,
      fixture_acceptance_pdf_name_for_test("/aG1"),
    ),
    true,
  )
  @test.assert_eq(
    fixture_acceptance_content_save_count_for_test(ops) >= 2,
    true,
  )
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
fn fixture_acceptance_page_content_ops_for_test(
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
fn fixture_acceptance_content_ops_contain_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  expected : @pdflite.PdfContentOp,
) -> Bool {
  for op in ops {
    if op == expected {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn fixture_acceptance_content_op_count_for_test(
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
fn fixture_acceptance_double_close_for_test(
  actual : Double,
  expected : Double,
) -> Bool {
  let difference = if actual > expected {
    actual - expected
  } else {
    expected - actual
  }
  difference < 0.000001
}

///|
fn fixture_acceptance_content_ops_contain_translation_cm_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  x : Double,
  y : Double,
) -> Bool {
  for op in ops {
    match op {
      Op_cm(matrix) =>
        if fixture_acceptance_double_close_for_test(matrix.a, 1.0) &&
          fixture_acceptance_double_close_for_test(matrix.b, 0.0) &&
          fixture_acceptance_double_close_for_test(matrix.c, 0.0) &&
          fixture_acceptance_double_close_for_test(matrix.d, 1.0) &&
          fixture_acceptance_double_close_for_test(matrix.e, x) &&
          fixture_acceptance_double_close_for_test(matrix.f, y) {
          break true
        }
      _ => ()
    }
  } nobreak {
    false
  }
}

///|
fn fixture_acceptance_content_ops_contain_scaled_cm_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> Bool {
  for op in ops {
    match op {
      Op_cm(matrix) =>
        if matrix.a > 1.0 &&
          fixture_acceptance_double_close_for_test(matrix.a, matrix.d) &&
          fixture_acceptance_double_close_for_test(matrix.b, 0.0) &&
          fixture_acceptance_double_close_for_test(matrix.c, 0.0) {
          break true
        }
      _ => ()
    }
  } nobreak {
    false
  }
}

///|
fn fixture_acceptance_content_stroke_count_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> Int {
  let mut count = 0
  for op in ops {
    match op {
      Op_S => count += 1
      _ => ()
    }
  }
  count
}

///|
fn fixture_acceptance_content_save_count_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> Int {
  let mut count = 0
  for op in ops {
    match op {
      Op_q => count += 1
      _ => ()
    }
  }
  count
}

///|
fn fixture_acceptance_content_clip_op_count_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> Int {
  let mut count = 0
  for op in ops {
    match op {
      Op_W | Op_Wstar => count += 1
      _ => ()
    }
  }
  count
}

///|
fn fixture_acceptance_content_clip_setup_count_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> Int {
  let mut count = 0
  if ops.length() >= 2 {
    for index in 0..<(ops.length() - 1) {
      if ops[index] == Op_W && ops[index + 1] == Op_n {
        count += 1
      }
    }
  }
  count
}

///|
fn fixture_acceptance_content_text_rendering_mode_count_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> Int {
  let mut count = 0
  for op in ops {
    match op {
      Op_Tr(_) => count += 1
      _ => ()
    }
  }
  count
}

///|
fn fixture_acceptance_stream_count_for_test(
  document : @pdflite.PdfDocument,
) -> Int {
  let mut count = 0
  for entry in document.parsed_object_entries() {
    match entry.2 {
      PdfStreamObject(_) => count += 1
      _ => ()
    }
  }
  count
}

///|
fn fixture_acceptance_filtered_stream_count_for_test(
  document : @pdflite.PdfDocument,
) -> Int {
  let key_filter = fixture_acceptance_pdf_name_for_test("/Filter")
  let key_short_filter = fixture_acceptance_pdf_name_for_test("/F")
  let mut count = 0
  for entry in document.parsed_object_entries() {
    match entry.2 {
      PdfStreamObject(stream) =>
        if stream.dictionary.lookup_immediate(key_filter) != None ||
          stream.dictionary.lookup_immediate(key_short_filter) != None {
          count += 1
        }
      _ => ()
    }
  }
  count
}

///|
fn fixture_acceptance_assert_content_op_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  expected : @pdflite.PdfContentOp,
) -> Unit raise {
  if !fixture_acceptance_content_ops_contain_for_test(ops, expected) {
    fail("missing expected content op: " + expected.to_json().stringify())
  }
}

///|
fn fixture_acceptance_assert_no_content_op_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  unexpected : @pdflite.PdfContentOp,
) -> Unit raise {
  if fixture_acceptance_content_ops_contain_for_test(ops, unexpected) {
    fail("unexpected content op: " + unexpected.to_json().stringify())
  }
}

///|
fn fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
  path : String,
  document : @pdflite.PdfDocument,
) -> Unit raise {
  let ops = fixture_acceptance_page_content_ops_for_test(document)
  match path {
    ".repos/cpdf-source/manualimages/bez.pdf" => {
      fixture_acceptance_assert_content_op_for_test(ops, Op_m(100.0, 100.0))
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_c(400.0, 600.0, 600.0, 400.0, 300.0, 300.0),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_S)
    }
    ".repos/cpdf-source/manualimages/dash.pdf" => {
      fixture_acceptance_assert_content_op_for_test(ops, Op_m(100.0, 100.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_w(20.0))
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_d([30.0, 20.0], 0.0),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_l(400.0, 300.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_S)
    }
    ".repos/cpdf-source/manualimages/capjoins.pdf" => {
      fixture_acceptance_assert_content_op_for_test(ops, Op_m(100.0, 100.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_j(1))
      fixture_acceptance_assert_content_op_for_test(ops, Op_J(1))
      fixture_acceptance_assert_content_op_for_test(ops, Op_M(1.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_w(40.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_S)
    }
    ".repos/cpdf-source/manualimages/colfill.pdf" => {
      fixture_acceptance_assert_content_op_for_test(ops, Op_w(20.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_m(300.0, 200.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_G(0.5))
      fixture_acceptance_assert_content_op_for_test(ops, Op_rg(0.2, 0.7, 0.2))
      fixture_acceptance_assert_content_op_for_test(ops, Op_B)
    }
    ".repos/cpdf-source/manualimages/clip.pdf" => {
      fixture_acceptance_assert_content_op_for_test(ops, Op_m(400.0, 300.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_W)
      fixture_acceptance_assert_content_op_for_test(ops, Op_n)
      fixture_acceptance_assert_content_op_for_test(ops, Op_m(400.0, 350.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_f)
    }
    ".repos/cpdf-source/manualimages/fill.pdf" => {
      fixture_acceptance_assert_content_op_for_test(ops, Op_m(100.0, 100.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_l(400.0, 400.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_l(400.0, 100.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_h)
      fixture_acceptance_assert_content_op_for_test(ops, Op_f)
    }
    ".repos/cpdf-source/manualimages/line.pdf" => {
      fixture_acceptance_assert_content_op_for_test(ops, Op_m(100.0, 100.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_l(400.0, 400.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_l(400.0, 100.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_h)
      fixture_acceptance_assert_content_op_for_test(ops, Op_S)
    }
    ".repos/cpdf-source/manualimages/textclip.pdf" => {
      fixture_acceptance_assert_content_op_for_test(ops, Op_Tr(7))
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_cm({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 100.0, f: 200.0 }),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_TL(55.0))
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("This is")),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("on multiple")),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("lines")),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_f)
    }
    ".repos/cpdf-source/manualimages/matrix.pdf" => {
      fixture_acceptance_assert_content_op_for_test(ops, Op_q)
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_cm({ a: 1.5, b: 0.0, c: 0.0, d: 2.0, e: 0.0, f: 0.0 }),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_Q)
      fixture_acceptance_assert_content_op_for_test(ops, Op_S)
    }
    ".repos/cpdf-source/manualimages/png.pdf" => {
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_cm({ a: 400.0, b: 0.0, c: 0.0, d: 294.0, e: 0.0, f: 0.0 }),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Do(fixture_acceptance_pdf_name_for_test("/I1")),
      )
    }
    ".repos/cpdf-source/manualimages/pop.pdf" => {
      fixture_acceptance_assert_content_op_for_test(ops, Op_rg(1.0, 0.0, 0.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_q)
      fixture_acceptance_assert_content_op_for_test(ops, Op_rg(0.0, 0.0, 1.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_Q)
      fixture_acceptance_assert_content_op_for_test(ops, Op_f)
    }
    ".repos/cpdf-source/manualimages/fontparams.pdf" => {
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_cm({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 10.0, f: 20.0 }),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_Tz(75.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_Tc(5.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_Tw(20.0))
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tf(fixture_acceptance_pdf_name_for_test("/F1"), 72.0),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tf(fixture_acceptance_pdf_name_for_test("/F2"), 72.0),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_Ts(40.0))
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tf(fixture_acceptance_pdf_name_for_test("/F2"), 36.0),
      )
    }
    ".repos/cpdf-source/manualimages/fonts.pdf" => {
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_cm({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 10.0, f: 20.0 }),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_BT)
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tf(fixture_acceptance_pdf_name_for_test("/F1"), 72.0),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("Different ")),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tf(fixture_acceptance_pdf_name_for_test("/F2"), 72.0),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("fonts")),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tf(fixture_acceptance_pdf_name_for_test("/F2"), 36.0),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode(" and sizes")),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_ET)
    }
    ".repos/cpdf-source/manualimages/h1.pdf" => {
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_BMC(fixture_acceptance_pdf_name_for_test("/Artifact")),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_BDC(
          fixture_acceptance_pdf_name_for_test("/H1"),
          PdfDictionary([
            (fixture_acceptance_pdf_name_for_test("/MCID"), PdfInteger(0)),
          ]),
        ),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("This is the heading")),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("paragraph,")),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("lines...")),
      )
      @test.assert_eq(
        fixture_acceptance_content_op_count_for_test(ops, Op_EMC),
        5,
      )
    }
    ".repos/cpdf-source/manualimages/lines.pdf" => {
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_cm({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 100.0, f: 200.0 }),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_TL(55.0))
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tf(fixture_acceptance_pdf_name_for_test("/F1"), 50.0),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("This is")),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("on multiple")),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("lines")),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_Tstar)
    }
    ".repos/cpdf-source/manualimages/stext.pdf" => {
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_cm({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 50.0, f: 50.0 }),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_BT)
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tf(fixture_acceptance_pdf_name_for_test("/F1"), 144.0),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("Page 1")),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_ET)
    }
    ".repos/cpdf-source/manualimages/text.pdf" => {
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_cm({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 50.0, f: 50.0 }),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_BT)
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tf(fixture_acceptance_pdf_name_for_test("/F1"), 144.0),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("Hello")),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_ET)
    }
    ".repos/cpdf-source/manualimages/para.pdf" => {
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_cm({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 200.0, f: 400.0 }),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_TL(25.0))
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("paragraph")),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("line...")),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_Tstar)
    }
    ".repos/cpdf-source/manualimages/paras.pdf" => {
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_cm({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 200.0, f: 500.0 }),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_TL(25.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_Td(0.0, 0.0))
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("first")),
      )
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_Tj(@ascii.encode("second,")),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_Tstar)
    }
    ".repos/cpdf-source/manualimages/trans.pdf" => {
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_gs(fixture_acceptance_pdf_name_for_test("/G1")),
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_m(400.0, 300.0))
      fixture_acceptance_assert_content_op_for_test(ops, Op_m(500.0, 300.0))
      @test.assert_eq(
        fixture_acceptance_content_op_count_for_test(ops, Op_f),
        2,
      )
    }
    ".repos/cpdf-source/manualimages/xobj.pdf" => {
      let xobject_name = fixture_acceptance_pdf_name_for_test("/X1")
      @test.assert_eq(
        fixture_acceptance_content_op_count_for_test(ops, Op_Do(xobject_name)),
        2,
      )
      fixture_acceptance_assert_content_op_for_test(ops, Op_RG(1.0, 0.0, 0.0))
      fixture_acceptance_assert_content_op_for_test(
        ops,
        Op_cm({ a: 1.0, b: 0.0, c: 0.0, d: 1.0, e: 20.0, f: 20.0 }),
      )
    }
    _ => fail("unexpected cpdf draw operator fixture path: " + path)
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
fn fixture_acceptance_assert_cpdf_source_attachments_for_test(
  document : @pdflite.PdfDocument,
  readme_payload : Bytes,
  changes_payload : Bytes,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let attachments = document.list_attached_files()
  @test.assert_eq(attachments, [
    {
      name: "README.md",
      pagenumber: 0,
      data: Some(readme_payload),
      description: Some("cpdf source README"),
      relationship: Some("/Source"),
    },
    {
      name: "Changes.txt",
      pagenumber: 1,
      data: Some(changes_payload),
      description: Some("cpdf source changes"),
      relationship: Some("/Supplement"),
    },
  ])
  @test.assert_eq(
    document.size_attached_files(),
    readme_payload.length() + changes_payload.length(),
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_attachments_removed_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  @test.assert_eq(document.list_attached_files(), [])
  @test.assert_eq(document.size_attached_files(), 0)
}

///|
fn fixture_acceptance_lookup_required_for_test(
  document : @pdflite.PdfDocument,
  key : String,
  object : @pdflite.PdfObject,
) -> @pdflite.PdfObject raise {
  match
    document.lookup_direct(fixture_acceptance_pdf_name_for_test(key), object) {
    Some(value) => value
    None => fail("missing PDF dictionary key " + key)
  }
}

///|
fn fixture_acceptance_rect_object_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @pdflite.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn fixture_acceptance_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @pdflite.PdfRectangle {
  { min_x, min_y, max_x, max_y }
}

///|
fn fixture_acceptance_chop_source_hello_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let decorated_rest = pages[0].rest
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/CropBox"),
      fixture_acceptance_rect_object_for_test(10.0, 20.0, 210.0, 420.0),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/BleedBox"),
      fixture_acceptance_rect_object_for_test(1.0, 2.0, 3.0, 4.0),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/TrimBox"),
      fixture_acceptance_rect_object_for_test(1.0, 2.0, 3.0, 4.0),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/ArtBox"),
      fixture_acceptance_rect_object_for_test(1.0, 2.0, 3.0, 4.0),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/Annots"),
      PdfArray([PdfInteger(99)]),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/Keep"),
      PdfInteger(7),
    )
  let decorated = document.change_pages(
    [{ ..pages[0], rest: decorated_rest }],
    change_references=true,
  )
  decorated.chop(2, 2, false, false, false, [1])
}

///|
fn fixture_acceptance_assert_cpdf_source_chop_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 4)
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 4)
  let expected_boxes = [
    fixture_acceptance_rect_for_test(10.0, 220.0, 110.0, 420.0),
    fixture_acceptance_rect_for_test(110.0, 220.0, 210.0, 420.0),
    fixture_acceptance_rect_for_test(10.0, 20.0, 110.0, 220.0),
    fixture_acceptance_rect_for_test(110.0, 20.0, 210.0, 220.0),
  ]
  for index in 0..<pages.length() {
    @test.assert_eq(
      document.parse_rectangle(pages[index].mediabox),
      expected_boxes[index],
    )
    @test.assert_eq(
      document.lookup_direct(
        fixture_acceptance_pdf_name_for_test("/CropBox"),
        pages[index].rest,
      ),
      None,
    )
    @test.assert_eq(
      document.lookup_direct(
        fixture_acceptance_pdf_name_for_test("/BleedBox"),
        pages[index].rest,
      ),
      None,
    )
    @test.assert_eq(
      document.lookup_direct(
        fixture_acceptance_pdf_name_for_test("/TrimBox"),
        pages[index].rest,
      ),
      None,
    )
    @test.assert_eq(
      document.lookup_direct(
        fixture_acceptance_pdf_name_for_test("/ArtBox"),
        pages[index].rest,
      ),
      None,
    )
    @test.assert_eq(
      document.lookup_direct(
        fixture_acceptance_pdf_name_for_test("/Annots"),
        pages[index].rest,
      ),
      None,
    )
    @test.assert_eq(
      document.lookup_direct(
        fixture_acceptance_pdf_name_for_test("/Keep"),
        pages[index].rest,
      ),
      Some(PdfInteger(7)),
    )
  }
}

///|
fn fixture_acceptance_has_text_showing_op_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
) -> Bool {
  for op in ops {
    match op {
      Op_Tj(_) | Op_TJ(_) | Op_quote(_) | Op_double_quote(_, _, _) => break true
      _ => ()
    }
  } nobreak {
    false
  }
}

///|
fn fixture_acceptance_cpdf_source_hello_ops_for_test(
  document : @pdflite.PdfDocument,
) -> Array[@pdflite.PdfContentOp] raise {
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  document.parse_content_ops_with_resources(
    pages[0].resources,
    pages[0].content,
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_hello_text_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let text = @utf8.decode_lossy(document.test_extract_text([1]))
  fixture_acceptance_assert_contains_for_test(text, "Hello, World!")
  let ops = fixture_acceptance_cpdf_source_hello_ops_for_test(document)
  @test.assert_eq(fixture_acceptance_has_text_showing_op_for_test(ops), true)
}

///|
fn fixture_acceptance_assert_cpdf_source_hello_text_removed_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let text = @utf8.decode_lossy(document.test_extract_text([1]))
  @test.assert_eq(text.contains("Hello, World!"), false)
  let ops = fixture_acceptance_cpdf_source_hello_ops_for_test(document)
  @test.assert_eq(fixture_acceptance_has_text_showing_op_for_test(ops), false)
  @test.assert_eq(ops.length() > 0, true)
}

///|
fn fixture_acceptance_cpdf_source_hello_with_spot_colours_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument {
  let output = document.copy()
  let indirect_colourant = output.add_object(
    PdfNameObject(fixture_acceptance_pdf_name_for_test("/SourceIndirectSpot")),
  )
  ignore(
    output.add_object(
      PdfArray([
        PdfNameObject(fixture_acceptance_pdf_name_for_test("/Separation")),
        PdfNameObject(fixture_acceptance_pdf_name_for_test("/SourceSpot")),
        PdfNameObject(fixture_acceptance_pdf_name_for_test("/DeviceCMYK")),
        PdfNull,
      ]),
    ),
  )
  ignore(
    output.add_object(
      PdfArray([
        PdfNameObject(fixture_acceptance_pdf_name_for_test("/Separation")),
        PdfIndirect(indirect_colourant),
        PdfNameObject(fixture_acceptance_pdf_name_for_test("/DeviceGray")),
        PdfNull,
      ]),
    ),
  )
  output
}

///|
fn fixture_acceptance_assert_cpdf_source_spot_colours_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let expected = [
    fixture_acceptance_pdf_name_for_test("/SourceSpot"),
    fixture_acceptance_pdf_name_for_test("/SourceIndirectSpot"),
  ]
  @test.assert_eq(document.list_spot_colours(), expected)
  @test.assert_eq(@pdflite.pdf_list_spot_colours(document), expected)
}

///|
fn fixture_acceptance_cpdf_source_ocg_layer_for_test(text : String) -> Bytes {
  @ascii.encode(text)
}

///|
fn fixture_acceptance_cpdf_source_ocg_content_for_test() -> @pdflite.PdfOptionalContent {
  let usage : @pdflite.PdfOcgUsage = {
    creator_info: Some(
      (
        fixture_acceptance_cpdf_source_ocg_layer_for_test("fixture"),
        fixture_acceptance_pdf_name_for_test("/Artwork"),
      ),
    ),
    language: Some(
      (
        fixture_acceptance_cpdf_source_ocg_layer_for_test("en-US"),
        Some(fixture_acceptance_pdf_name_for_test("/ON")),
      ),
    ),
    export_state: Some(fixture_acceptance_pdf_name_for_test("/ON")),
    zoom_min: Some(0.25),
    zoom_max: Some(4.0),
    print_subtype: Some(fixture_acceptance_pdf_name_for_test("/Watermark")),
    print_state: Some(fixture_acceptance_pdf_name_for_test("/OFF")),
    view_state: Some(fixture_acceptance_pdf_name_for_test("/ON")),
    user: Some(
      (
        fixture_acceptance_pdf_name_for_test("/Ind"),
        [
          fixture_acceptance_cpdf_source_ocg_layer_for_test("Alice"),
          fixture_acceptance_cpdf_source_ocg_layer_for_test("Bob"),
        ],
      ),
    ),
    page_element_subtype: Some(fixture_acceptance_pdf_name_for_test("/FG")),
  }
  {
    ocgs: [
      (
        20,
        {
          name: fixture_acceptance_cpdf_source_ocg_layer_for_test(
            "Source Layer",
          ),
          intent: [fixture_acceptance_pdf_name_for_test("/View")],
          usage: None,
        },
      ),
      (
        21,
        {
          name: fixture_acceptance_cpdf_source_ocg_layer_for_test(
            "Source Layer",
          ),
          intent: [fixture_acceptance_pdf_name_for_test("/Print")],
          usage: None,
        },
      ),
      (
        22,
        {
          name: fixture_acceptance_cpdf_source_ocg_layer_for_test("Print Layer"),
          intent: [
            fixture_acceptance_pdf_name_for_test("/View"),
            fixture_acceptance_pdf_name_for_test("/Print"),
          ],
          usage: Some(usage),
        },
      ),
    ],
    default_config: {
      name: Some(
        fixture_acceptance_cpdf_source_ocg_layer_for_test("Source Default"),
      ),
      creator: Some(
        fixture_acceptance_cpdf_source_ocg_layer_for_test("MoonBit fixture"),
      ),
      base_state: OcgOff,
      on: [20, 21],
      off: [22],
      intent: [
        fixture_acceptance_pdf_name_for_test("/View"),
        fixture_acceptance_pdf_name_for_test("/Print"),
      ],
      usage_applications: [
        {
          event: OcgPrint,
          ocgs: [22],
          category: [fixture_acceptance_pdf_name_for_test("/Print")],
        },
        {
          event: OcgView,
          ocgs: [20, 21],
          category: [fixture_acceptance_pdf_name_for_test("/View")],
        },
      ],
      order: Some([
        (
          Some(
            fixture_acceptance_cpdf_source_ocg_layer_for_test("Source Layers"),
          ),
          [20, 21],
        ),
        (
          Some(fixture_acceptance_cpdf_source_ocg_layer_for_test("Output")),
          [22],
        ),
      ]),
      list_mode: OcgVisiblePages,
      radio_button_groups: Some([[20, 21], [22]]),
      locked: [22],
    },
    configs: [
      {
        ..@pdflite.pdf_ocg_default_config(),
        name: Some(
          fixture_acceptance_cpdf_source_ocg_layer_for_test("Alternate Source"),
        ),
        base_state: OcgUnchanged,
        on: [22],
        off: [20, 21],
        locked: [21],
      },
    ],
  }
}

///|
fn fixture_acceptance_add_cpdf_source_ocg_witness_for_test(
  document : @pdflite.PdfDocument,
) -> Int {
  document.add_object(
    PdfDictionary([
      (fixture_acceptance_pdf_name_for_test("/Custom"), PdfIndirect(21)),
    ]),
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_ocg_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let expected = fixture_acceptance_cpdf_source_ocg_content_for_test()
  guard (try! document.read_optional_content_groups()) is Some(content) else {
    fail("missing cpdf source optional content")
  }
  @test.assert_eq(content, expected)
  let expected_names = [
    fixture_acceptance_cpdf_source_ocg_layer_for_test("Source Layer"),
    fixture_acceptance_cpdf_source_ocg_layer_for_test("Source Layer"),
    fixture_acceptance_cpdf_source_ocg_layer_for_test("Print Layer"),
  ]
  @test.assert_eq(try! document.ocg_get_list(), expected_names)
  @test.assert_eq(try! @pdflite.pdf_ocg_get_list(document), expected_names)
  let json = try! document.ocg_list_json()
  @test.assert_eq(try! @pdflite.pdf_ocg_list_json(document), json)
  @test.assert_eq(try! @pdflite.pdf_ocg_read_json(json), Some(content))
  let json_text = json.stringify()
  fixture_acceptance_assert_contains_for_test(json_text, "Source Layer")
  fixture_acceptance_assert_contains_for_test(json_text, "Print Layer")
  fixture_acceptance_assert_contains_for_test(json_text, "/Watermark")
  fixture_acceptance_assert_contains_for_test(json_text, "/VisiblePages")
  @test.assert_eq(try! document.ocg_list_json_blob(), @utf8.encode(json_text))
  @test.assert_eq(
    try! @pdflite.pdf_ocg_list_json_blob(document),
    @utf8.encode(json_text),
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_ocg_renamed_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let renamed = fixture_acceptance_cpdf_source_ocg_layer_for_test(
    "Renamed Layer",
  )
  @test.assert_eq(try! document.ocg_get_list(), [
    renamed,
    renamed,
    fixture_acceptance_cpdf_source_ocg_layer_for_test("Print Layer"),
  ])
}

///|
fn fixture_acceptance_assert_cpdf_source_ocg_ordered_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  guard (try! document.read_optional_content_groups()) is Some(content) else {
    fail("missing ordered cpdf source optional content")
  }
  @test.assert_eq(
    content.default_config.order,
    Some([(None, [20]), (None, [21]), (None, [22])]),
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_ocg_coalesced_for_test(
  document : @pdflite.PdfDocument,
  witness_number : Int,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  guard (try! document.read_optional_content_groups()) is Some(content) else {
    fail("missing coalesced cpdf source optional content")
  }
  @test.assert_eq(content.ocgs.length(), 2)
  @test.assert_eq(content.ocgs[0].0, 20)
  @test.assert_eq(
    content.ocgs[0].1.name,
    fixture_acceptance_cpdf_source_ocg_layer_for_test("Source Layer"),
  )
  @test.assert_eq(content.ocgs[1].0, 22)
  @test.assert_eq(
    content.ocgs[1].1.name,
    fixture_acceptance_cpdf_source_ocg_layer_for_test("Print Layer"),
  )
  @test.assert_eq(content.default_config.on, [20])
  @test.assert_eq(content.default_config.off, [22])
  @test.assert_eq(content.default_config.usage_applications[0].ocgs, [22])
  @test.assert_eq(content.default_config.usage_applications[1].ocgs, [20])
  @test.assert_eq(
    content.default_config.order,
    Some([
      (
        Some(fixture_acceptance_cpdf_source_ocg_layer_for_test("Source Layers")),
        [20],
      ),
      (Some(fixture_acceptance_cpdf_source_ocg_layer_for_test("Output")), [22]),
    ]),
  )
  @test.assert_eq(
    content.default_config.radio_button_groups,
    Some([[20], [22]]),
  )
  @test.assert_eq(content.default_config.locked, [22])
  @test.assert_eq(content.configs[0].off, [20])
  @test.assert_eq(content.configs[0].locked, [20])
  @test.assert_eq(
    document
    .lookup_object_or_null(witness_number)
    .lookup_immediate(fixture_acceptance_pdf_name_for_test("/Custom")),
    Some(PdfIndirect(20)),
  )
  @test.assert_eq(document.lookup_object_or_null(21), PdfNull)
}

///|
fn fixture_acceptance_cpdf_source_redact_path_for_test() -> Array[
  (Double, Double),
] {
  [(0.0, 0.0), (72.0, 0.0), (72.0, 72.0), (0.0, 72.0)]
}

///|
fn fixture_acceptance_assert_cpdf_source_redact_stub_for_test(
  document : @pdflite.PdfDocument,
  expected_ops : Array[@pdflite.PdfContentOp],
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  @test.assert_eq(
    fixture_acceptance_cpdf_source_hello_ops_for_test(document),
    expected_ops,
  )
}

///|
fn fixture_acceptance_page_transform_source_hello_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let decorated_rest = pages[0].rest
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/CropBox"),
      fixture_acceptance_rect_object_for_test(10.0, 20.0, 210.0, 420.0),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/Annots"),
      PdfArray([
        PdfDictionary([
          (
            fixture_acceptance_pdf_name_for_test("/Rect"),
            fixture_acceptance_rect_object_for_test(1.0, 2.0, 3.0, 4.0),
          ),
        ]),
      ]),
    )
  let decorated = document.change_pages(
    [{ ..pages[0], rest: decorated_rest }],
    change_references=true,
  )
  let rotated = @pdflite.pdf_rotate_pages(decorated, 90, [1])
  let shifted = @pdflite.pdf_shift_pages(rotated, [1], [(12.0, 34.0)])
  @pdflite.pdf_hard_box(
    shifted,
    [1],
    fixture_acceptance_pdf_name_for_test("/CropBox"),
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_page_transform_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(pages[0].rotate, Rotate90)
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/CropBox"),
      pages[0].rest,
    )
    is Some(crop_box) else {
    fail("missing cpdf source transformed crop box")
  }
  @test.assert_eq(
    document.parse_rectangle(crop_box),
    fixture_acceptance_rect_for_test(10.0, 20.0, 210.0, 420.0),
  )
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/Annots"),
      pages[0].rest,
    )
    is Some(PdfArray([PdfDictionary(_) as annotation])) else {
    fail("missing cpdf source transformed annotation")
  }
  @test.assert_eq(
    document.parse_rectangle(
      fixture_acceptance_lookup_required_for_test(document, "/Rect", annotation),
    ),
    fixture_acceptance_rect_for_test(13.0, 36.0, 15.0, 38.0),
  )
  let ops = document.parse_content_ops_with_resources(
    pages[0].resources,
    pages[0].content,
  )
  @test.assert_eq(ops.length() >= 5, true)
  @test.assert_eq(ops[0], Op_re(10.0, 20.0, 200.0, 400.0))
  @test.assert_eq(ops[1], Op_W)
  @test.assert_eq(ops[2], Op_n)
  @test.assert_eq(ops[3], Op_cm(@pdflite.transform_translate(12.0, 34.0)))
  @test.assert_eq(fixture_acceptance_has_text_showing_op_for_test(ops), true)
  let text = @utf8.decode_lossy(document.test_extract_text([1]))
  fixture_acceptance_assert_contains_for_test(text, "Hello, World!")
}

///|
fn fixture_acceptance_pad_source_hello_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let decorated_rest = pages[0].rest
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/Annots"),
      PdfArray([PdfInteger(123)]),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/Keep"),
      PdfInteger(7),
    )
  let decorated = document.change_pages(
    [{ ..pages[0], rest: decorated_rest }],
    change_references=true,
  )
  @pdflite.pdf_pad_after(decorated, [1])
}

///|
fn fixture_acceptance_assert_cpdf_source_pad_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 2)
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 2)
  @test.assert_eq(
    document.parse_rectangle(pages[1].mediabox),
    document.parse_rectangle(pages[0].mediabox),
  )
  @test.assert_eq(pages[1].rotate, pages[0].rotate)
  @test.assert_eq(pages[1].content, [])
  @test.assert_eq(pages[1].resources, PdfDictionary([]))
  @test.assert_eq(
    document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/Annots"),
      pages[0].rest,
    ),
    Some(PdfArray([PdfInteger(123)])),
  )
  @test.assert_eq(
    document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/Annots"),
      pages[1].rest,
    ),
    None,
  )
  @test.assert_eq(
    document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/Keep"),
      pages[1].rest,
    ),
    Some(PdfInteger(7)),
  )
  let first_page_text = @utf8.decode_lossy(document.test_extract_text([1]))
  fixture_acceptance_assert_contains_for_test(first_page_text, "Hello, World!")
  let second_page_text = @utf8.decode_lossy(document.test_extract_text([2]))
  @test.assert_eq(second_page_text.contains("Hello, World!"), false)
}

///|
fn fixture_acceptance_add_cpdf_source_javascript_for_test(
  document : @pdflite.PdfDocument,
) -> (Int, Int, Int) raise {
  let key_js = fixture_acceptance_pdf_name_for_test("/JS")
  let key_uri = fixture_acceptance_pdf_name_for_test("/URI")
  let action_number = document.add_object(
    PdfDictionary([
      (key_js, PdfString(@ascii.encode("app.alert('source')"))),
      (fixture_acceptance_pdf_name_for_test("/Keep"), PdfInteger(7)),
    ]),
  )
  let uri_number = document.add_object(
    PdfArray([
      PdfDictionary([
        (key_js, PdfString(@ascii.encode("nested alert"))),
        (key_uri, PdfString(@ascii.encode("javascript:app.alert('uri')"))),
      ]),
      PdfDictionary([
        (key_uri, PdfString(@ascii.encode("https://example.invalid"))),
      ]),
    ]),
  )
  let stream_number = document.add_object(
    PdfStreamObject({
      dictionary: PdfDictionary([
        (key_js, PdfString(@ascii.encode("stream alert"))),
      ]),
      data: StreamGot(@ascii.encode("stream payload")),
    }),
  )
  let javascript_tree = document.build_name_tree([
    (
      @ascii.encode("cpdf-source-script"),
      PdfString(@ascii.encode("app.alert('tree')")),
    ),
  ])
  document.replace_chain(
    [
      fixture_acceptance_pdf_name_for_test("/Root"),
      fixture_acceptance_pdf_name_for_test("/Names"),
      fixture_acceptance_pdf_name_for_test("/JavaScript"),
    ],
    javascript_tree,
  )
  (action_number, uri_number, stream_number)
}

///|
fn fixture_acceptance_assert_cpdf_source_javascript_for_test(
  document : @pdflite.PdfDocument,
  action_number : Int,
  uri_number : Int,
  stream_number : Int,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  @test.assert_eq(document.contains_javascript(), true)
  let key_root = fixture_acceptance_pdf_name_for_test("/Root")
  let key_names = fixture_acceptance_pdf_name_for_test("/Names")
  let key_javascript = fixture_acceptance_pdf_name_for_test("/JavaScript")
  guard document.lookup_chain(document.trailer_dict(), [
      key_root, key_names, key_javascript,
    ])
    is Some(javascript_tree) else {
    fail("missing cpdf source JavaScript name tree")
  }
  @test.assert_eq(document.read_name_tree(javascript_tree), [
    (
      @ascii.encode("cpdf-source-script"),
      PdfString(@ascii.encode("app.alert('tree')")),
    ),
  ])
  let action = document.lookup_object_or_null(action_number)
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/JS", action),
    PdfString(@ascii.encode("app.alert('source')")),
  )
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/Keep", action),
    PdfInteger(7),
  )
  guard document.lookup_object_or_null(uri_number)
    is PdfArray([PdfDictionary(first_entries), PdfDictionary(second_entries)]) else {
    fail("expected cpdf source JavaScript URI array")
  }
  let first_uri : @pdflite.PdfObject = PdfDictionary(first_entries)
  let second_uri : @pdflite.PdfObject = PdfDictionary(second_entries)
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/JS", first_uri),
    PdfString(@ascii.encode("nested alert")),
  )
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/URI", first_uri),
    PdfString(@ascii.encode("javascript:app.alert('uri')")),
  )
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/URI", second_uri),
    PdfString(@ascii.encode("https://example.invalid")),
  )
  let stream_object = document.lookup_object_or_null(stream_number)
  @test.assert_eq(stream_object.stream_bytes(), @ascii.encode("stream payload"))
  guard stream_object is PdfStreamObject(stream) else {
    fail("expected cpdf source JavaScript stream")
  }
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(
      document,
      "/JS",
      stream.dictionary,
    ),
    PdfString(@ascii.encode("stream alert")),
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_javascript_removed_for_test(
  document : @pdflite.PdfDocument,
  action_number : Int,
  uri_number : Int,
  stream_number : Int,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  @test.assert_eq(document.contains_javascript(), false)
  let key_root = fixture_acceptance_pdf_name_for_test("/Root")
  let key_names = fixture_acceptance_pdf_name_for_test("/Names")
  let key_javascript = fixture_acceptance_pdf_name_for_test("/JavaScript")
  @test.assert_eq(
    document.lookup_chain(document.trailer_dict(), [
      key_root, key_names, key_javascript,
    ]),
    None,
  )
  let action = document.lookup_object_or_null(action_number)
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/JS", action),
    PdfString(@ascii.encode("")),
  )
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/Keep", action),
    PdfInteger(7),
  )
  guard document.lookup_object_or_null(uri_number)
    is PdfArray([PdfDictionary(first_entries), PdfDictionary(second_entries)]) else {
    fail("expected scrubbed cpdf source JavaScript URI array")
  }
  let first_uri : @pdflite.PdfObject = PdfDictionary(first_entries)
  let second_uri : @pdflite.PdfObject = PdfDictionary(second_entries)
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/JS", first_uri),
    PdfString(@ascii.encode("")),
  )
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/URI", first_uri),
    PdfString(@ascii.encode("")),
  )
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/URI", second_uri),
    PdfString(@ascii.encode("https://example.invalid")),
  )
  let stream_object = document.lookup_object_or_null(stream_number)
  @test.assert_eq(stream_object.stream_bytes(), @ascii.encode("stream payload"))
  guard stream_object is PdfStreamObject(stream) else {
    fail("expected scrubbed cpdf source JavaScript stream")
  }
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(
      document,
      "/JS",
      stream.dictionary,
    ),
    PdfString(@ascii.encode("")),
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_portfolio_entry_for_test(
  document : @pdflite.PdfDocument,
  object : @pdflite.PdfObject,
  basename : String,
  description : String,
  relationship : String,
  payload : Bytes,
  mod_date : Bytes,
) -> Unit raise {
  let file_spec = document.direct(object)
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/Type", file_spec),
    PdfNameObject(fixture_acceptance_pdf_name_for_test("/FileSpec")),
  )
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/Desc", file_spec),
    PdfString(@utf8.encode(description)),
  )
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/F", file_spec),
    PdfString(@utf8.encode(basename)),
  )
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/UF", file_spec),
    PdfString(@utf8.encode(basename)),
  )
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(
      document, "/AFRelationship", file_spec,
    ),
    PdfNameObject(fixture_acceptance_pdf_name_for_test(relationship)),
  )
  let ef = fixture_acceptance_lookup_required_for_test(
    document, "/EF", file_spec,
  )
  let stream_reference = fixture_acceptance_lookup_required_for_test(
    document, "/F", ef,
  )
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/UF", ef),
    stream_reference,
  )
  let stream = document.direct(stream_reference)
  @test.assert_eq(stream.stream_bytes(), payload)
  guard stream is PdfStreamObject(stream_object) else {
    fail("expected cpdf source portfolio embedded file stream")
  }
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(
      document,
      "/Length",
      stream_object.dictionary,
    ),
    PdfInteger(payload.length()),
  )
  let params = fixture_acceptance_lookup_required_for_test(
    document,
    "/Params",
    stream_object.dictionary,
  )
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/ModDate", params),
    PdfString(mod_date),
  )
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/Size", params),
    PdfInteger(payload.length()),
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_portfolio_for_test(
  document : @pdflite.PdfDocument,
  readme_payload : Bytes,
  changes_payload : Bytes,
  mod_date : Bytes,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let catalog = document.catalog()
  let collection = fixture_acceptance_lookup_required_for_test(
    document, "/Collection", catalog,
  )
  @test.assert_eq(
    fixture_acceptance_lookup_required_for_test(document, "/View", collection),
    PdfNameObject(fixture_acceptance_pdf_name_for_test("/T")),
  )
  let names = fixture_acceptance_lookup_required_for_test(
    document, "/Names", catalog,
  )
  let embedded_files = fixture_acceptance_lookup_required_for_test(
    document, "/EmbeddedFiles", names,
  )
  let entries = document.read_name_tree(embedded_files)
  @test.assert_eq(entries.length(), 2)
  @test.assert_eq(entries[0].0, @utf8.encode("0/.repos/cpdf-source/README.md"))
  @test.assert_eq(
    entries[1].0,
    @utf8.encode("1/.repos/cpdf-source/Changes.txt"),
  )
  fixture_acceptance_assert_cpdf_source_portfolio_entry_for_test(
    document,
    entries[0].1,
    "README.md",
    "cpdf source README",
    "/Source",
    readme_payload,
    mod_date,
  )
  fixture_acceptance_assert_cpdf_source_portfolio_entry_for_test(
    document,
    entries[1].1,
    "Changes.txt",
    "Changes.txt",
    "/Unspecified",
    changes_payload,
    mod_date,
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_presentation_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/Trans"),
      pages[0].rest,
    )
    is Some(PdfDictionary(trans_entries)) else {
    fail("missing cpdf source presentation transition")
  }
  let trans : @pdflite.PdfObject = PdfDictionary(trans_entries)
  @test.assert_eq(
    document.lookup_direct(fixture_acceptance_pdf_name_for_test("/S"), trans),
    Some(PdfNameObject(fixture_acceptance_pdf_name_for_test("/Split"))),
  )
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/D"),
      trans,
    )
    is Some(effect_duration) else {
    fail("missing cpdf source presentation effect duration")
  }
  @test.assert_eq(document.get_number(effect_duration), 1.25)
  @test.assert_eq(
    document.lookup_direct(fixture_acceptance_pdf_name_for_test("/Dm"), trans),
    Some(PdfNameObject(fixture_acceptance_pdf_name_for_test("/H"))),
  )
  @test.assert_eq(
    document.lookup_direct(fixture_acceptance_pdf_name_for_test("/M"), trans),
    Some(PdfNameObject(fixture_acceptance_pdf_name_for_test("/O"))),
  )
  @test.assert_eq(
    document.lookup_direct(fixture_acceptance_pdf_name_for_test("/Di"), trans),
    None,
  )
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/Dur"),
      pages[0].rest,
    )
    is Some(delay) else {
    fail("missing cpdf source presentation page duration")
  }
  @test.assert_eq(document.get_number(delay), 2.0)
}

///|
fn fixture_acceptance_assert_cpdf_manual_metadata_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  @test.assert_eq(document.language(), Some(@ascii.encode("en-GB")))
  @test.assert_eq(
    document.info_utf8(fixture_acceptance_pdf_name_for_test("/Title")),
    "cpdf source & metadata",
  )
  @test.assert_eq(
    document.info_utf8(fixture_acceptance_pdf_name_for_test("/Author")),
    "MoonBit port",
  )
  @test.assert_eq(
    document.info_utf8(fixture_acceptance_pdf_name_for_test("/Creator")),
    "LaTeX with hyperref",
  )
  @test.assert_eq(
    document.info_utf8(fixture_acceptance_pdf_name_for_test("/Producer")),
    "pdfTeX-1.40.29",
  )
  let metadata = match document.metadata() {
    Some(metadata) => metadata
    None => fail("missing cpdf manual metadata")
  }
  let metadata_text = @utf8.decode_lossy(metadata)
  fixture_acceptance_assert_contains_for_test(
    metadata_text, "<pdf:Producer>pdfTeX-1.40.29</pdf:Producer>",
  )
  fixture_acceptance_assert_contains_for_test(
    metadata_text, "<pdf:Creator>LaTeX with hyperref</pdf:Creator>",
  )
  fixture_acceptance_assert_contains_for_test(
    metadata_text, "<xap:CreatorTool>LaTeX with hyperref</xap:CreatorTool>",
  )
  fixture_acceptance_assert_contains_for_test(
    metadata_text, "<pdf:Title>cpdf source &amp; metadata</pdf:Title>",
  )
  fixture_acceptance_assert_contains_for_test(
    metadata_text, "<pdf:Author>MoonBit port</pdf:Author>",
  )
  fixture_acceptance_assert_contains_for_test(
    metadata_text, "2026-05-08T20:26:06+01:00",
  )
  let info_json = document.info_json().stringify()
  fixture_acceptance_assert_contains_for_test(
    info_json, "\"Title\":\"cpdf source & metadata\"",
  )
  fixture_acceptance_assert_contains_for_test(
    info_json, "\"Author\":\"MoonBit port\"",
  )
  fixture_acceptance_assert_contains_for_test(
    info_json, "\"Creator\":\"LaTeX with hyperref\"",
  )
  fixture_acceptance_assert_contains_for_test(
    info_json, "\"Producer\":\"pdfTeX-1.40.29\"",
  )
  let xmp_json = document.xmp_info_json().stringify()
  fixture_acceptance_assert_contains_for_test(
    xmp_json, "\"Language\":\"en-GB\"",
  )
  fixture_acceptance_assert_contains_for_test(
    xmp_json, "\"XMP pdf:Producer\":\"pdfTeX-1.40.29\"",
  )
  fixture_acceptance_assert_contains_for_test(
    xmp_json, "\"XMP pdf:Creator\":\"LaTeX with hyperref\"",
  )
  fixture_acceptance_assert_contains_for_test(
    xmp_json, "\"XMP xmp:CreatorTool\":\"LaTeX with hyperref\"",
  )
  fixture_acceptance_assert_contains_for_test(
    xmp_json, "\"XMP pdf:Title\":\"cpdf source &amp; metadata\"",
  )
  fixture_acceptance_assert_contains_for_test(
    xmp_json, "\"XMP pdf:Author\":\"MoonBit port\"",
  )
}

///|
fn fixture_acceptance_assert_cpdf_manual_metadata_removed_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  @test.assert_eq(document.language(), Some(@ascii.encode("en-GB")))
  @test.assert_eq(document.metadata(), None)
  let xmp_json = document.xmp_info_json().stringify()
  fixture_acceptance_assert_contains_for_test(
    xmp_json, "\"Language\":\"en-GB\"",
  )
  fixture_acceptance_assert_contains_for_test(xmp_json, "\"Subformats\":[]")
  @test.assert_eq(xmp_json.contains("XMP pdf:Title"), false)
  @test.assert_eq(xmp_json.contains("XMP pdf:Author"), false)
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
  let selected_pages = [1, 2, 19, 31, 33]
  let extracted = document.test_extract_text(selected_pages)
  @test.assert_eq(
    @pdflite.pdf_test_extract_text(document, selected_pages),
    extracted,
  )
  let text = @utf8.decode_lossy(extracted)
  fixture_acceptance_assert_contains_for_test(text, "CoherentPDF")
  fixture_acceptance_assert_contains_for_test(text, "©CoherentGraphicsLimited")
  fixture_acceptance_assert_contains_for_test(text, "PDFAssociation")
  fixture_acceptance_assert_contains_for_test(text, "CommandLineTools")
  fixture_acceptance_assert_contains_for_test(text, "Chapter1BasicUsage")
  fixture_acceptance_assert_contains_for_test(
    text, "Chapter2MergingandSplitting",
  )
  fixture_acceptance_assert_contains_for_test(text, "SplittingonBookmarks")
  @test.assert_eq(text.length() > 2000, true)
  @test.assert_eq(fixture_acceptance_replacement_count_for_test(text), 0)
  @test.assert_eq(fixture_acceptance_raw_control_count_for_test(text), 0)
  let pages = document.pages_of_pagetree()
  let entries = document.content_entries_of_page(pages[1])
  @test.assert_eq(
    @pdflite.pdf_content_entries_of_page(document, pages[1]),
    entries,
  )
  @test.assert_eq(entries.length() > 0, true)
  let mut glyph_text = ""
  for entry in entries {
    match entry.object {
      PdfContentGlyphObject(_, _, extracted_text) =>
        glyph_text = glyph_text + extracted_text
      _ => ()
    }
  }
  fixture_acceptance_assert_contains_for_test(
    glyph_text, "©CoherentGraphicsLimited",
  )
  @test.assert_eq(fixture_acceptance_replacement_count_for_test(glyph_text), 0)
  @test.assert_eq(fixture_acceptance_raw_control_count_for_test(glyph_text), 0)
  let content_json = document.page_content_json([2])
  @test.assert_eq(@pdflite.pdf_page_content_json(document, [2]), content_json)
  let content_json_text = content_json.stringify()
  fixture_acceptance_assert_contains_for_test(content_json_text, "\"page\":2")
  fixture_acceptance_assert_contains_for_test(
    content_json_text, "\"obj\":\"glyph\"",
  )
  fixture_acceptance_assert_contains_for_test(
    content_json_text, "\"extracted text\"",
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
fn fixture_acceptance_assert_cpdf_manual_bookmarks_open_to_level_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let bookmarks = document.read_bookmarks(preserve_actions=true)
  @test.assert_eq(bookmarks.length(), 163)
  let mut saw_child = false
  for bookmark in bookmarks {
    if bookmark.level > 0 {
      @test.assert_eq(bookmark.is_open, false)
      saw_child = true
    }
  }
  @test.assert_eq(saw_child, true)
  @test.assert_eq(bookmarks[0].level, 0)
  @test.assert_eq(document.page_number_of_target(bookmarks[0].target), 19)
  @test.assert_eq(bookmarks[0].is_open, true)
  @test.assert_eq(bookmarks[21].level, 0)
  @test.assert_eq(document.page_number_of_target(bookmarks[21].target), 31)
  @test.assert_eq(bookmarks[21].is_open, true)
  let bookmarks_json = document
    .bookmarks_json(json_preserve_actions=true)
    .stringify()
  fixture_acceptance_assert_contains_for_test(
    bookmarks_json, "\"text\":\"1 Basic Usage\"",
  )
  fixture_acceptance_assert_contains_for_test(bookmarks_json, "\"open\":true")
  fixture_acceptance_assert_contains_for_test(bookmarks_json, "\"open\":false")
  let listed = @ascii.decode_lossy(
    document.list_bookmarks([19, 31, 33], encoding=PdfMetadataUTF8),
  )
  fixture_acceptance_assert_contains_for_test(
    listed, "0 \"1 Basic Usage\" 19 open \"",
  )
  fixture_acceptance_assert_contains_for_test(
    listed, "0 \"2 Merging and Splitting\" 31 open \"",
  )
  fixture_acceptance_assert_contains_for_test(
    listed, "1 \"2.4 Splitting on Bookmarks\" 33 \"",
  )
}

///|
fn fixture_acceptance_assert_cpdf_manual_title_bookmark_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let bookmarks = document.read_bookmarks(preserve_actions=true)
  @test.assert_eq(bookmarks.length(), 164)
  @test.assert_eq(bookmarks[0].level, 0)
  @test.assert_eq(
    @utf8.decode_lossy(@pdflite.pdf_utf8_of_pdfdocstring(bookmarks[0].text)),
    "cpdfmanual.pdf",
  )
  @test.assert_eq(document.page_number_of_target(bookmarks[0].target), 1)
  @test.assert_eq(bookmarks[0].is_open, false)
  @test.assert_eq(bookmarks[0].colour, @pdflite.pdf_bookmark_black)
  @test.assert_eq(bookmarks[0].flags, 0)
  @test.assert_eq(bookmarks[1].level, 1)
  @test.assert_eq(
    @utf8.decode_lossy(@pdflite.pdf_utf8_of_pdfdocstring(bookmarks[1].text)),
    "1 Basic Usage",
  )
  @test.assert_eq(document.page_number_of_target(bookmarks[1].target), 19)
  @test.assert_eq(bookmarks[22].level, 1)
  @test.assert_eq(document.page_number_of_target(bookmarks[22].target), 31)
  for index in 1..<bookmarks.length() {
    @test.assert_eq(bookmarks[index].level >= 1, true)
  }
  let bookmarks_json = document
    .bookmarks_json(json_preserve_actions=true)
    .stringify()
  fixture_acceptance_assert_contains_for_test(
    bookmarks_json, "\"text\":\"cpdfmanual.pdf\"",
  )
  fixture_acceptance_assert_contains_for_test(bookmarks_json, "\"page\":1")
  fixture_acceptance_assert_contains_for_test(
    bookmarks_json, "\"text\":\"1 Basic Usage\"",
  )
  let listed = @ascii.decode_lossy(
    document.list_bookmarks([1, 19, 31, 33], encoding=PdfMetadataUTF8),
  )
  fixture_acceptance_assert_contains_for_test(
    listed, "0 \"cpdfmanual.pdf\" 1 \"",
  )
  fixture_acceptance_assert_contains_for_test(listed, "1 \"1 Basic Usage\" 19")
  fixture_acceptance_assert_contains_for_test(
    listed, "1 \"2 Merging and Splitting\" 31",
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
  let images = document.images_json([1])
  @test.assert_eq(@pdflite.pdf_image_images(false, document, [1]), images)
  let images_json = images.stringify()
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
  @test.assert_eq(resolution[0].1, "/I1")
  @test.assert_eq(resolution[0].2, 400)
  @test.assert_eq(resolution[0].3, 294)
  @test.assert_eq(resolution[0].6 > 0, true)
  let resolution_json_object = document.image_resolution_json([1], 1000000.0)
  @test.assert_eq(
    @pdflite.pdf_image_resolution_json(false, document, [1], 1000000.0),
    resolution_json_object,
  )
  let resolution_json = resolution_json_object.stringify()
  fixture_acceptance_assert_contains_for_test(
    resolution_json, "\"XObject\":\"/I1\"",
  )
  fixture_acceptance_assert_contains_for_test(resolution_json, "\"W\":400")
  fixture_acceptance_assert_contains_for_test(resolution_json, "\"H\":294")
  @test.assert_eq(
    @pdflite.pdf_image_resolution_json_blob(false, document, [1], 1000000.0),
    document.image_resolution_json_blob([1], 1000000.0),
  )
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
fn fixture_acceptance_cpdf_source_inline_image_dictionary_for_test() -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (fixture_acceptance_pdf_name_for_test("/W"), PdfInteger(3)),
    (fixture_acceptance_pdf_name_for_test("/H"), PdfInteger(2)),
    (fixture_acceptance_pdf_name_for_test("/BPC"), PdfInteger(8)),
    (
      fixture_acceptance_pdf_name_for_test("/CS"),
      PdfNameObject(fixture_acceptance_pdf_name_for_test("/DeviceRGB")),
    ),
  ])
}

///|
fn fixture_acceptance_cpdf_source_hello_with_inline_image_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let image_ops : Array[@pdflite.PdfContentOp] = [
    Op_cm({ a: 72.0, b: 0.0, c: 0.0, d: 72.0, e: 0.0, f: 0.0 }),
    Op_InlineImage(
      fixture_acceptance_cpdf_source_inline_image_dictionary_for_test(),
      None,
      @ascii.encode("abcdefghijklmnopqr"),
    ),
  ]
  let updated_page = document.postpend_operators(pages[0], image_ops, fast=true)
  document.change_pages([updated_page], change_references=true)
}

///|
fn fixture_acceptance_assert_cpdf_source_inline_image_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
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
  fixture_acceptance_assert_contains_for_test(
    inline_images_json, "\"Object\":0",
  )
  fixture_acceptance_assert_contains_for_test(
    inline_images_json, "\"Name\":\"/InlineImage\"",
  )
  fixture_acceptance_assert_contains_for_test(
    inline_images_json, "\"Pages\":[1]",
  )
  fixture_acceptance_assert_contains_for_test(inline_images_json, "\"Width\":3")
  fixture_acceptance_assert_contains_for_test(
    inline_images_json, "\"Height\":2",
  )
  fixture_acceptance_assert_contains_for_test(
    inline_images_json, "\"Bytes\":18",
  )
  fixture_acceptance_assert_contains_for_test(
    inline_images_json, "\"BitsPerComponent\":8",
  )
  fixture_acceptance_assert_contains_for_test(
    inline_images_json, "\"Colourspace\":\"/DeviceRGB\"",
  )
  fixture_acceptance_assert_contains_for_test(
    inline_images_json, "\"Filter\":null",
  )
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
  fixture_acceptance_assert_contains_for_test(
    inline_resolution_text, "\"XObject\":\"/InlineImage\"",
  )
  fixture_acceptance_assert_contains_for_test(inline_resolution_text, "\"W\":3")
  fixture_acceptance_assert_contains_for_test(inline_resolution_text, "\"H\":2")
  fixture_acceptance_assert_contains_for_test(
    inline_resolution_text, "\"Xdpi\":3",
  )
  fixture_acceptance_assert_contains_for_test(
    inline_resolution_text, "\"Ydpi\":2",
  )
  @test.assert_eq(
    @pdflite.pdf_image_resolution_json_blob(true, document, [1], 1000000.0),
    document.image_resolution_json_blob([1], 1000000.0, inline=true),
  )
}

///|
fn fixture_acceptance_cpdf_source_nested_image_data_for_test() -> @pdflite.PdfBytes raise {
  @pdflite.pdf_flate_encode(@pdflite.pdf_bytes_of_int_array([0, 64, 128, 255]))
}

///|
fn fixture_acceptance_cpdf_source_nested_image_for_test() -> @pdflite.PdfObject raise {
  let data = fixture_acceptance_cpdf_source_nested_image_data_for_test()
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        fixture_acceptance_pdf_name_for_test("/Type"),
        PdfNameObject(fixture_acceptance_pdf_name_for_test("/XObject")),
      ),
      (
        fixture_acceptance_pdf_name_for_test("/Subtype"),
        PdfNameObject(fixture_acceptance_pdf_name_for_test("/Image")),
      ),
      (fixture_acceptance_pdf_name_for_test("/Width"), PdfInteger(2)),
      (fixture_acceptance_pdf_name_for_test("/Height"), PdfInteger(2)),
      (fixture_acceptance_pdf_name_for_test("/BitsPerComponent"), PdfInteger(8)),
      (
        fixture_acceptance_pdf_name_for_test("/ColorSpace"),
        PdfNameObject(fixture_acceptance_pdf_name_for_test("/DeviceGray")),
      ),
      (
        fixture_acceptance_pdf_name_for_test("/Filter"),
        PdfNameObject(fixture_acceptance_pdf_name_for_test("/FlateDecode")),
      ),
      (
        fixture_acceptance_pdf_name_for_test("/Length"),
        PdfInteger(data.length()),
      ),
    ]),
    StreamGot(data),
  )
}

///|
fn fixture_acceptance_cpdf_source_form_image_form_for_test(
  image_number : Int,
) -> @pdflite.PdfObject raise {
  @pdflite.pdf_content_stream_of_ops([
    Op_cm({ a: 72.0, b: 0.0, c: 0.0, d: 72.0, e: 72.0, f: 72.0 }),
    Op_Do(fixture_acceptance_pdf_name_for_test("/SourceNestedImage")),
  ])
  .add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/Type"),
    PdfNameObject(fixture_acceptance_pdf_name_for_test("/XObject")),
  )
  .add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/Subtype"),
    PdfNameObject(fixture_acceptance_pdf_name_for_test("/Form")),
  )
  .add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/BBox"),
    PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(72), PdfInteger(72)]),
  )
  .add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/Resources"),
    @pdflite.pdf_dictionary([
      (
        fixture_acceptance_pdf_name_for_test("/XObject"),
        @pdflite.pdf_dictionary([
          (
            fixture_acceptance_pdf_name_for_test("/SourceNestedImage"),
            PdfIndirect(image_number),
          ),
        ]),
      ),
    ]),
  )
}

///|
fn fixture_acceptance_cpdf_source_page_xobjects_for_test(
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
) -> @pdflite.PdfObject raise {
  match
    document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/XObject"),
      resources,
    ) {
    Some(PdfDictionary(entries)) => PdfDictionary(entries)
    Some(_) => fail("expected source page XObject resources to be a dictionary")
    None => @pdflite.pdf_dictionary([])
  }
}

///|
fn fixture_acceptance_cpdf_source_hello_with_form_image_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let output = document.copy()
  let image_number = output.add_object(
    fixture_acceptance_cpdf_source_nested_image_for_test(),
  )
  let form_number = output.add_object(
    fixture_acceptance_cpdf_source_form_image_form_for_test(image_number),
  )
  let pages = output.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let xobjects = fixture_acceptance_cpdf_source_page_xobjects_for_test(
    output,
    pages[0].resources,
  ).add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/SourceImageForm"),
    PdfIndirect(form_number),
  )
  let resources = pages[0].resources.add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/XObject"),
    xobjects,
  )
  let page = { ..pages[0], resources, }
  let updated_page = output.postpend_operators(
    page,
    [
      Op_q,
      Op_Do(fixture_acceptance_pdf_name_for_test("/SourceImageForm")),
      Op_Q,
    ],
    fast=true,
  )
  output.change_pages([updated_page], change_references=true)
}

///|
fn fixture_acceptance_cpdf_source_form_image_resources_for_test(
  document : @pdflite.PdfDocument,
) -> (@pdflite.PdfObject, @pdflite.PdfObject) raise {
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/XObject"),
      pages[0].resources,
    )
    is Some(page_xobjects) else {
    fail("missing source page XObject resources")
  }
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/SourceImageForm"),
      page_xobjects,
    )
    is Some(form) else {
    fail("missing source nested image form")
  }
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/Resources"),
      form,
    )
    is Some(form_resources) else {
    fail("missing source nested image form resources")
  }
  (form, form_resources)
}

///|
fn fixture_acceptance_cpdf_source_nested_image_for_document_for_test(
  document : @pdflite.PdfDocument,
  form_resources : @pdflite.PdfObject,
) -> @pdflite.PdfObject raise {
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/XObject"),
      form_resources,
    )
    is Some(form_xobjects) else {
    fail("missing source nested form XObject resources")
  }
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/SourceNestedImage"),
      form_xobjects,
    )
    is Some(image) else {
    fail("missing source nested image XObject")
  }
  image
}

///|
fn fixture_acceptance_assert_cpdf_source_form_image_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let images = document.images_json([1])
  @test.assert_eq(@pdflite.pdf_image_images(false, document, [1]), images)
  let images_json = images.stringify()
  fixture_acceptance_assert_contains_for_test(
    images_json, "\"Name\":\"/SourceNestedImage\"",
  )
  fixture_acceptance_assert_contains_for_test(images_json, "\"Pages\":[1]")
  fixture_acceptance_assert_contains_for_test(images_json, "\"Width\":2")
  fixture_acceptance_assert_contains_for_test(images_json, "\"Height\":2")
  fixture_acceptance_assert_contains_for_test(
    images_json,
    "\"Bytes\":" +
    fixture_acceptance_cpdf_source_nested_image_data_for_test()
    .length()
    .to_string(),
  )
  fixture_acceptance_assert_contains_for_test(
    images_json, "\"BitsPerComponent\":8",
  )
  fixture_acceptance_assert_contains_for_test(
    images_json, "\"Colourspace\":\"/DeviceGray\"",
  )
  fixture_acceptance_assert_contains_for_test(
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
  fixture_acceptance_assert_contains_for_test(
    resolution_text, "\"XObject\":\"/SourceNestedImage\"",
  )
  fixture_acceptance_assert_contains_for_test(resolution_text, "\"W\":2")
  fixture_acceptance_assert_contains_for_test(resolution_text, "\"H\":2")
  fixture_acceptance_assert_contains_for_test(resolution_text, "\"Xdpi\":2")
  fixture_acceptance_assert_contains_for_test(resolution_text, "\"Ydpi\":2")
  @test.assert_eq(
    @pdflite.pdf_image_resolution_json_blob(false, document, [1], 1000000.0),
    document.image_resolution_json_blob([1], 1000000.0),
  )
  let (form, form_resources) = fixture_acceptance_cpdf_source_form_image_resources_for_test(
    document,
  )
  @test.assert_eq(
    document.parse_content_ops_with_resources(form_resources, [form]),
    [
      Op_cm({ a: 72.0, b: 0.0, c: 0.0, d: 72.0, e: 72.0, f: 72.0 }),
      Op_Do(fixture_acceptance_pdf_name_for_test("/SourceNestedImage")),
    ],
  )
  let image = fixture_acceptance_cpdf_source_nested_image_for_document_for_test(
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
fn fixture_acceptance_cpdf_source_type3_tounicode_for_test() -> @pdflite.PdfObject {
  let data = @ascii.encode(
    "1 begincodespacerange\n" +
    "<00><FF>\n" +
    "endcodespacerange\n" +
    "2 beginbfchar\n" +
    "<41><005A>\n" +
    "<42><0059>\n" +
    "endbfchar\n",
  )
  @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([
      (
        fixture_acceptance_pdf_name_for_test("/Length"),
        PdfInteger(data.length()),
      ),
    ]),
    StreamGot(data),
  )
}

///|
fn fixture_acceptance_cpdf_source_type3_mark_for_test() -> @pdflite.PdfObject raise {
  @pdflite.pdf_content_stream_of_ops([Op_q, Op_Q])
  .add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/Subtype"),
    PdfNameObject(fixture_acceptance_pdf_name_for_test("/Form")),
  )
  .add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/BBox"),
    PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(1), PdfInteger(1)]),
  )
}

///|
fn fixture_acceptance_cpdf_source_type3_font_for_test(
  glyph_a : Int,
  glyph_b : Int,
  glyph_mark : Int,
  tounicode : Int,
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      fixture_acceptance_pdf_name_for_test("/Subtype"),
      PdfNameObject(fixture_acceptance_pdf_name_for_test("/Type3")),
    ),
    (
      fixture_acceptance_pdf_name_for_test("/BaseFont"),
      PdfNameObject(fixture_acceptance_pdf_name_for_test("/SourceType3")),
    ),
    (
      fixture_acceptance_pdf_name_for_test("/FontBBox"),
      PdfArray([
        PdfInteger(0),
        PdfInteger(-10),
        PdfInteger(600),
        PdfInteger(700),
      ]),
    ),
    (
      fixture_acceptance_pdf_name_for_test("/FontMatrix"),
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
      fixture_acceptance_pdf_name_for_test("/CharProcs"),
      @pdflite.pdf_dictionary([
        (fixture_acceptance_pdf_name_for_test("/A"), PdfIndirect(glyph_a)),
        (fixture_acceptance_pdf_name_for_test("/B"), PdfIndirect(glyph_b)),
      ]),
    ),
    (
      fixture_acceptance_pdf_name_for_test("/Resources"),
      @pdflite.pdf_dictionary([
        (
          fixture_acceptance_pdf_name_for_test("/ProcSet"),
          PdfArray([PdfNameObject(fixture_acceptance_pdf_name_for_test("/PDF"))]),
        ),
        (
          fixture_acceptance_pdf_name_for_test("/XObject"),
          @pdflite.pdf_dictionary([
            (
              fixture_acceptance_pdf_name_for_test("/GlyphMark"),
              PdfIndirect(glyph_mark),
            ),
          ]),
        ),
      ]),
    ),
    (fixture_acceptance_pdf_name_for_test("/FirstChar"), PdfInteger(65)),
    (fixture_acceptance_pdf_name_for_test("/LastChar"), PdfInteger(66)),
    (
      fixture_acceptance_pdf_name_for_test("/Widths"),
      PdfArray([PdfInteger(500), PdfInteger(600)]),
    ),
    (
      fixture_acceptance_pdf_name_for_test("/Encoding"),
      @pdflite.pdf_dictionary([
        (
          fixture_acceptance_pdf_name_for_test("/Differences"),
          PdfArray([
            PdfInteger(65),
            PdfNameObject(fixture_acceptance_pdf_name_for_test("/A")),
            PdfNameObject(fixture_acceptance_pdf_name_for_test("/B")),
          ]),
        ),
      ]),
    ),
    (fixture_acceptance_pdf_name_for_test("/ToUnicode"), PdfIndirect(tounicode)),
  ])
}

///|
fn fixture_acceptance_cpdf_source_page_fonts_for_test(
  document : @pdflite.PdfDocument,
  resources : @pdflite.PdfObject,
) -> @pdflite.PdfObject raise {
  match
    document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/Font"),
      resources,
    ) {
    Some(PdfDictionary(entries)) => PdfDictionary(entries)
    Some(_) => fail("expected source page font resources to be a dictionary")
    None => @pdflite.pdf_dictionary([])
  }
}

///|
fn fixture_acceptance_cpdf_source_hello_with_type3_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let output = document.copy()
  let tounicode = output.add_object(
    fixture_acceptance_cpdf_source_type3_tounicode_for_test(),
  )
  let glyph_mark = output.add_object(
    fixture_acceptance_cpdf_source_type3_mark_for_test(),
  )
  let glyph_a = output.add_object(
    @pdflite.pdf_content_stream_of_ops([Op_d0(500.0, 0.0)]),
  )
  let glyph_b = output.add_object(
    @pdflite.pdf_content_stream_of_ops([
      Op_d1(600.0, 0.0, 0.0, -10.0, 600.0, 700.0),
      Op_Do(fixture_acceptance_pdf_name_for_test("/GlyphMark")),
    ]),
  )
  let font_number = output.add_object(
    fixture_acceptance_cpdf_source_type3_font_for_test(
      glyph_a, glyph_b, glyph_mark, tounicode,
    ),
  )
  let pages = output.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font_resources = fixture_acceptance_cpdf_source_page_fonts_for_test(
    output,
    pages[0].resources,
  ).add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/SourceT3"),
    PdfIndirect(font_number),
  )
  let resources = pages[0].resources.add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/Font"),
    font_resources,
  )
  let page = { ..pages[0], resources, }
  let updated_page = output.postpend_operators(
    page,
    [
      Op_BT,
      Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceT3"), 24.0),
      Op_Tj(@pdflite.pdf_bytes_of_int_array([65, 66])),
      Op_ET,
    ],
    fast=true,
  )
  output.change_pages([updated_page], change_references=true)
}

///|
fn fixture_acceptance_cpdf_source_font_entry_for_test(
  entries : ArrayView[@pdflite.PdfFontListEntry],
  name : String,
) -> @pdflite.PdfFontListEntry raise {
  for entry in entries {
    if entry.name == name {
      break entry
    }
  } nobreak {
    fail("missing source font entry " + name)
  }
}

///|
fn fixture_acceptance_cpdf_source_font_table_entry_for_test(
  entries : ArrayView[@pdflite.PdfFontTableEntry],
  code : Int,
) -> @pdflite.PdfFontTableEntry raise {
  for entry in entries {
    if entry.code == code {
      break entry
    }
  } nobreak {
    fail("missing source font table code " + code.to_string())
  }
}

///|
fn fixture_acceptance_assert_cpdf_source_type3_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let text = @utf8.decode_lossy(document.test_extract_text([1]))
  fixture_acceptance_assert_contains_for_test(text, "ZY")
  let fonts = document.list_fonts([1])
  @test.assert_eq(@pdflite.pdf_list_fonts(document, [1]), fonts)
  let source_font = fixture_acceptance_cpdf_source_font_entry_for_test(
    fonts, "/SourceT3",
  )
  @test.assert_eq(source_font.subtype, "/Type3")
  @test.assert_eq(source_font.basefont, "/SourceType3")
  guard document.read_font(source_font.font) is PdfFontSimple(simple) else {
    fail("expected source Type3 simple font")
  }
  guard simple.fonttype is PdfType3(type3_data) else {
    fail("expected source Type3 glyph data")
  }
  @test.assert_eq(type3_data.fontbbox, {
    min_x: 0.0,
    min_y: -10.0,
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
  @test.assert_eq([ for charproc in type3_data.charprocs => charproc.0 ], [
    fixture_acceptance_pdf_name_for_test("/A"),
    fixture_acceptance_pdf_name_for_test("/B"),
  ])
  @test.assert_eq(
    document.parse_content_ops_with_resources(type3_data.resources, [
      document.direct(type3_data.charprocs[0].1),
    ]),
    [Op_d0(500.0, 0.0)],
  )
  @test.assert_eq(
    document.parse_content_ops_with_resources(type3_data.resources, [
      document.direct(type3_data.charprocs[1].1),
    ]),
    [
      Op_d1(600.0, 0.0, 0.0, -10.0, 600.0, 700.0),
      Op_Do(fixture_acceptance_pdf_name_for_test("/GlyphMark")),
    ],
  )
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/XObject"),
      type3_data.resources,
    )
    is Some(xobjects) else {
    fail("missing source Type3 XObject resources")
  }
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/GlyphMark"),
      xobjects,
    )
    is Some(mark) else {
    fail("missing source Type3 glyph mark XObject")
  }
  @test.assert_eq(
    document.parse_content_ops_with_resources(type3_data.resources, [mark]),
    [Op_q, Op_Q],
  )
  guard simple.fontmetrics is Some(metrics) else {
    fail("expected source Type3 font metrics")
  }
  @test.assert_eq(metrics[64], 0.0)
  @test.assert_eq(metrics[65], 500.0)
  @test.assert_eq(metrics[66], 600.0)
  @test.assert_eq(metrics[67], 0.0)
  guard simple.fontdescriptor is Some(descriptor) else {
    fail("expected source Type3 descriptor carrying ToUnicode")
  }
  @test.assert_eq(
    descriptor.tounicode,
    Some([
      (65, @pdflite.pdf_bytes_of_int_array([0, 0x5A])),
      (66, @pdflite.pdf_bytes_of_int_array([0, 0x59])),
    ]),
  )
  let table = document.font_table("/SourceT3", 1)
  let row_a = fixture_acceptance_cpdf_source_font_table_entry_for_test(
    table, 65,
  )
  @test.assert_eq(
    row_a.glyphnames,
    @utf8.decode_lossy(@pdflite.pdf_bytes_of_int_array([0, 0x5A])),
  )
  @test.assert_eq(row_a.unicode, "005A")
  @test.assert_eq(row_a.utf8, "Z")
  @test.assert_eq(row_a.unicode_name, "LATIN CAPITAL LETTER Z")
  let row_b = fixture_acceptance_cpdf_source_font_table_entry_for_test(
    table, 66,
  )
  @test.assert_eq(
    row_b.glyphnames,
    @utf8.decode_lossy(@pdflite.pdf_bytes_of_int_array([0, 0x59])),
  )
  @test.assert_eq(row_b.unicode, "0059")
  @test.assert_eq(row_b.utf8, "Y")
  @test.assert_eq(row_b.unicode_name, "LATIN CAPITAL LETTER Y")
  @test.assert_eq(@pdflite.pdf_font_table(document, "/SourceT3", 1), table)
}

///|
fn fixture_acceptance_cpdf_source_variation_cmap_for_test() -> @pdflite.PdfObject {
  let cmap = @ascii.encode(
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
      (
        fixture_acceptance_pdf_name_for_test("/Length"),
        PdfInteger(encoded.length()),
      ),
      (
        fixture_acceptance_pdf_name_for_test("/Filter"),
        PdfNameObject(fixture_acceptance_pdf_name_for_test("/FlateDecode")),
      ),
    ]),
    StreamGot(encoded),
  )
}

///|
fn fixture_acceptance_cpdf_source_variation_font_for_test(
  tounicode : Int,
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      fixture_acceptance_pdf_name_for_test("/Subtype"),
      PdfNameObject(fixture_acceptance_pdf_name_for_test("/Type1")),
    ),
    (
      fixture_acceptance_pdf_name_for_test("/BaseFont"),
      PdfNameObject(fixture_acceptance_pdf_name_for_test("/SourceVariation")),
    ),
    (fixture_acceptance_pdf_name_for_test("/ToUnicode"), PdfIndirect(tounicode)),
  ])
}

///|
fn fixture_acceptance_cpdf_source_hello_with_variation_tounicode_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let output = document.copy()
  let tounicode = output.add_object(
    fixture_acceptance_cpdf_source_variation_cmap_for_test(),
  )
  let font_number = output.add_object(
    fixture_acceptance_cpdf_source_variation_font_for_test(tounicode),
  )
  let pages = output.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font_resources = fixture_acceptance_cpdf_source_page_fonts_for_test(
    output,
    pages[0].resources,
  ).add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/SourceVar"),
    PdfIndirect(font_number),
  )
  let resources = pages[0].resources.add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/Font"),
    font_resources,
  )
  let page = { ..pages[0], resources, }
  let updated_page = output.postpend_operators(
    page,
    [
      Op_BT,
      Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceVar"), 12.0),
      Op_Tj(@pdflite.pdf_bytes_of_int_array([65, 66, 67])),
      Op_TJ(
        PdfArray([
          PdfString(@pdflite.pdf_bytes_of_int_array([68])),
          PdfInteger(-20),
          PdfString(@pdflite.pdf_bytes_of_int_array([69, 70, 71])),
        ]),
      ),
      Op_ET,
    ],
    fast=true,
  )
  output.change_pages([updated_page], change_references=true)
}

///|
fn fixture_acceptance_assert_cpdf_source_variation_tounicode_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let expected_codepoints = [0x1D11E, 0x61, 0x62, 0x63, 0x1F600, 0x64, 0x65, 71]
  let expected_text = @utf8.decode_lossy(
    @pdflite.pdf_utf8_of_codepoints(expected_codepoints),
  )
  let text = @utf8.decode_lossy(document.test_extract_text([1]))
  fixture_acceptance_assert_contains_for_test(text, expected_text)
  let source_font = fixture_acceptance_cpdf_source_font_entry_for_test(
    document.list_fonts([1]),
    "/SourceVar",
  )
  @test.assert_eq(source_font.subtype, "/Type1")
  @test.assert_eq(source_font.basefont, "/SourceVariation")
  guard document.read_font(source_font.font) is PdfFontSimple(simple) else {
    fail("expected source variation simple font")
  }
  guard simple.fontdescriptor is Some(descriptor) else {
    fail("expected source variation descriptor carrying ToUnicode")
  }
  @test.assert_eq(
    descriptor.tounicode,
    Some([
      (65, @pdflite.pdf_bytes_of_int_array([0xD8, 0x34, 0xDD, 0x1E])),
      (66, @pdflite.pdf_bytes_of_int_array([0x00, 0x61])),
      (67, @pdflite.pdf_bytes_of_int_array([0x00, 0x62, 0x00, 0x63])),
      (68, @pdflite.pdf_bytes_of_int_array([0xD8, 0x3D, 0xDE, 0x00])),
      (69, @pdflite.pdf_bytes_of_int_array([0x00, 0x64])),
      (70, @pdflite.pdf_bytes_of_int_array([0x00, 0x65])),
    ]),
  )
  let extractor = document.text_extractor_of_font(source_font.font)
  @test.assert_eq(
    extractor.codepoints_of_text(
      @pdflite.pdf_bytes_of_int_array([65, 66, 67, 68, 69, 70, 71]),
    ),
    expected_codepoints,
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x1D11E), Some(65))
  @test.assert_eq(extractor.charcode_of_codepoint(0x61), Some(66))
  @test.assert_eq(extractor.charcode_of_codepoint(0x1F600), Some(68))
  @test.assert_eq(extractor.charcode_of_codepoint(0x62), None)
  @test.assert_eq(extractor.charcode_of_codepoint(71), None)
  let table = document.font_table("/SourceVar", 1)
  let row_a = fixture_acceptance_cpdf_source_font_table_entry_for_test(
    table, 65,
  )
  @test.assert_eq(row_a.unicode, "1D11E")
  @test.assert_eq(row_a.unicode_name, "MUSICAL SYMBOL G CLEF")
  let row_c = fixture_acceptance_cpdf_source_font_table_entry_for_test(
    table, 67,
  )
  @test.assert_eq(row_c.unicode, "***multiple")
  @test.assert_eq(row_c.utf8, "bc")
  @test.assert_eq(row_c.unicode_name, "***multiple")
  @test.assert_eq(@pdflite.pdf_font_table(document, "/SourceVar", 1), table)
}

///|
fn fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
  basefont : String,
  ordering : String,
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      fixture_acceptance_pdf_name_for_test("/Subtype"),
      PdfNameObject(fixture_acceptance_pdf_name_for_test("/CIDFontType2")),
    ),
    (
      fixture_acceptance_pdf_name_for_test("/BaseFont"),
      PdfNameObject(fixture_acceptance_pdf_name_for_test(basefont)),
    ),
    (
      fixture_acceptance_pdf_name_for_test("/CIDSystemInfo"),
      @pdflite.pdf_dictionary([
        (
          fixture_acceptance_pdf_name_for_test("/Registry"),
          PdfString(@ascii.encode("Adobe")),
        ),
        (
          fixture_acceptance_pdf_name_for_test("/Ordering"),
          PdfString(@ascii.encode(ordering)),
        ),
        (fixture_acceptance_pdf_name_for_test("/Supplement"), PdfInteger(0)),
      ]),
    ),
    (
      fixture_acceptance_pdf_name_for_test("/FontDescriptor"),
      @pdflite.pdf_dictionary([
        (fixture_acceptance_pdf_name_for_test("/Ascent"), PdfInteger(880)),
        (fixture_acceptance_pdf_name_for_test("/Descent"), PdfInteger(-120)),
      ]),
    ),
  ])
}

///|
fn fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
  basefont : String,
  encoding : String,
  descendant : Int,
) -> @pdflite.PdfObject {
  @pdflite.pdf_dictionary([
    (
      fixture_acceptance_pdf_name_for_test("/Subtype"),
      PdfNameObject(fixture_acceptance_pdf_name_for_test("/Type0")),
    ),
    (
      fixture_acceptance_pdf_name_for_test("/BaseFont"),
      PdfNameObject(fixture_acceptance_pdf_name_for_test(basefont)),
    ),
    (
      fixture_acceptance_pdf_name_for_test("/Encoding"),
      PdfNameObject(fixture_acceptance_pdf_name_for_test(encoding)),
    ),
    (
      fixture_acceptance_pdf_name_for_test("/DescendantFonts"),
      PdfArray([PdfIndirect(descendant)]),
    ),
  ])
}

///|
fn fixture_acceptance_cpdf_source_hello_with_uniakr_predefined_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let output = document.copy()
  let descendant_utf8 = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceUniAKRUTF8Descendant", "Korea1",
    ),
  )
  let descendant_utf16 = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceUniAKRUTF16Descendant", "Korea1",
    ),
  )
  let descendant_utf32 = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceUniAKRUTF32Descendant", "Korea1",
    ),
  )
  let font_utf8 = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceUniAKRUTF8Top", "/UniAKR-UTF8-H", descendant_utf8,
    ),
  )
  let font_utf16 = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceUniAKRUTF16Top", "/UniAKR-UTF16-H", descendant_utf16,
    ),
  )
  let font_utf32 = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceUniAKRUTF32Top", "/UniAKR-UTF32-H", descendant_utf32,
    ),
  )
  let pages = output.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font_resources = fixture_acceptance_cpdf_source_page_fonts_for_test(
      output,
      pages[0].resources,
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceAKR8"),
      PdfIndirect(font_utf8),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceAKR16"),
      PdfIndirect(font_utf16),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceAKR32"),
      PdfIndirect(font_utf32),
    )
  let resources = pages[0].resources.add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/Font"),
    font_resources,
  )
  let page = { ..pages[0], resources, }
  let updated_page = output.postpend_operators(
    page,
    [
      Op_BT,
      Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceAKR16"), 12.0),
      Op_Tj(@pdflite.pdf_bytes_of_int_array([0xAC, 0x00, 0xB0, 0x98])),
      Op_ET,
    ],
    fast=true,
  )
  output.change_pages([updated_page], change_references=true)
}

///|
fn fixture_acceptance_assert_cpdf_source_uniakr_predefined_font_for_test(
  document : @pdflite.PdfDocument,
  name : String,
  basefont : String,
  encoding : String,
  text : @pdflite.PdfBytes,
  first_charcode : Int,
  second_charcode : Int,
  uses_two_byte_codes : Bool,
) -> Unit raise {
  let source_font = fixture_acceptance_cpdf_source_font_entry_for_test(
    document.list_fonts([1]),
    name,
  )
  @test.assert_eq(source_font.subtype, "/Type0")
  @test.assert_eq(source_font.basefont, basefont)
  @test.assert_eq(source_font.encoding, encoding)
  let font = document.read_font(source_font.font)
  @test.assert_eq(font.uses_two_byte_codes(), uses_two_byte_codes)
  guard font is PdfFontCIDKeyed(cid_font) else {
    fail("expected source UniAKR predefined CID-keyed font")
  }
  @test.assert_eq(
    cid_font.encoding,
    PdfPredefinedCMap(fixture_acceptance_pdf_name_for_test(encoding)),
  )
  @test.assert_eq(
    cid_font.composite.cid_system_info.ordering,
    @ascii.encode("Korea1"),
  )
  let extractor = document.text_extractor_of_font(source_font.font)
  @test.assert_eq(extractor.codepoints_of_text(text), [0xAC00, 0xB098])
  @test.assert_eq(extractor.charcode_of_codepoint(0xAC00), Some(first_charcode))
  @test.assert_eq(
    extractor.charcode_of_codepoint(0xB098),
    Some(second_charcode),
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_uniakr_predefined_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let expected_text = @utf8.decode_lossy(
    @pdflite.pdf_utf8_of_codepoints([0xAC00, 0xB098]),
  )
  let text = @utf8.decode_lossy(document.test_extract_text([1]))
  fixture_acceptance_assert_contains_for_test(text, expected_text)
  fixture_acceptance_assert_cpdf_source_uniakr_predefined_font_for_test(
    document,
    "/SourceAKR8",
    "/SourceUniAKRUTF8Top",
    "/UniAKR-UTF8-H",
    @pdflite.pdf_bytes_of_int_array([0xEA, 0xB0, 0x80, 0xEB, 0x82, 0x98]),
    0xEAB080,
    0xEB8298,
    false,
  )
  fixture_acceptance_assert_cpdf_source_uniakr_predefined_font_for_test(
    document,
    "/SourceAKR16",
    "/SourceUniAKRUTF16Top",
    "/UniAKR-UTF16-H",
    @pdflite.pdf_bytes_of_int_array([0xAC, 0x00, 0xB0, 0x98]),
    0xAC00,
    0xB098,
    true,
  )
  fixture_acceptance_assert_cpdf_source_uniakr_predefined_font_for_test(
    document,
    "/SourceAKR32",
    "/SourceUniAKRUTF32Top",
    "/UniAKR-UTF32-H",
    @pdflite.pdf_bytes_of_int_array([
      0x00, 0x00, 0xAC, 0x00, 0x00, 0x00, 0xB0, 0x98,
    ]),
    0xAC00,
    0xB098,
    false,
  )
}

///|
fn fixture_acceptance_cpdf_source_hello_with_uniks_predefined_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let output = document.copy()
  let descendant_h = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceUniKSUCS2Descendant", "Korea1",
    ),
  )
  let descendant_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceUniKSUCS2VerticalDescendant", "Korea1",
    ),
  )
  let font_h = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceUniKSUCS2Top", "/UniKS-UCS2-H", descendant_h,
    ),
  )
  let font_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceUniKSUCS2VerticalTop", "/UniKS-UCS2-V", descendant_v,
    ),
  )
  let pages = output.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font_resources = fixture_acceptance_cpdf_source_page_fonts_for_test(
      output,
      pages[0].resources,
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceKSUCS2H"),
      PdfIndirect(font_h),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceKSUCS2V"),
      PdfIndirect(font_v),
    )
  let resources = pages[0].resources.add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/Font"),
    font_resources,
  )
  let page = { ..pages[0], resources, }
  let updated_page = output.postpend_operators(
    page,
    [
      Op_BT,
      Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceKSUCS2H"), 12.0),
      Op_Tj(@pdflite.pdf_bytes_of_int_array([0xAC, 0x00, 0xB0, 0x98])),
      Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceKSUCS2V"), 12.0),
      Op_Tj(@pdflite.pdf_bytes_of_int_array([0xAC, 0x00, 0xB0, 0x98])),
      Op_ET,
    ],
    fast=true,
  )
  output.change_pages([updated_page], change_references=true)
}

///|
fn fixture_acceptance_assert_cpdf_source_uniks_predefined_font_for_test(
  document : @pdflite.PdfDocument,
  name : String,
  basefont : String,
  encoding : String,
) -> Unit raise {
  let source_font = fixture_acceptance_cpdf_source_font_entry_for_test(
    document.list_fonts([1]),
    name,
  )
  @test.assert_eq(source_font.subtype, "/Type0")
  @test.assert_eq(source_font.basefont, basefont)
  @test.assert_eq(source_font.encoding, encoding)
  let font = document.read_font(source_font.font)
  @test.assert_eq(font.uses_two_byte_codes(), true)
  guard font is PdfFontCIDKeyed(cid_font) else {
    fail("expected source UniKS predefined CID-keyed font")
  }
  @test.assert_eq(
    cid_font.encoding,
    PdfPredefinedCMap(fixture_acceptance_pdf_name_for_test(encoding)),
  )
  @test.assert_eq(
    cid_font.composite.cid_system_info.ordering,
    @ascii.encode("Korea1"),
  )
  let extractor = document.text_extractor_of_font(source_font.font)
  @test.assert_eq(
    extractor.codepoints_of_text(
      @pdflite.pdf_bytes_of_int_array([0xAC, 0x00, 0xB0, 0x98]),
    ),
    [0xAC00, 0xB098],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0xAC00), Some(0xAC00))
  @test.assert_eq(extractor.charcode_of_codepoint(0xB098), Some(0xB098))
  @test.assert_eq(extractor.charcode_of_codepoint(0x1F600), None)
}

///|
fn fixture_acceptance_assert_cpdf_source_uniks_predefined_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let expected_text = @utf8.decode_lossy(
    @pdflite.pdf_utf8_of_codepoints([0xAC00, 0xB098]),
  )
  let text = @utf8.decode_lossy(document.test_extract_text([1]))
  fixture_acceptance_assert_contains_for_test(text, expected_text)
  fixture_acceptance_assert_cpdf_source_uniks_predefined_font_for_test(
    document, "/SourceKSUCS2H", "/SourceUniKSUCS2Top", "/UniKS-UCS2-H",
  )
  fixture_acceptance_assert_cpdf_source_uniks_predefined_font_for_test(
    document, "/SourceKSUCS2V", "/SourceUniKSUCS2VerticalTop", "/UniKS-UCS2-V",
  )
}

///|
fn fixture_acceptance_cpdf_source_hello_with_korea1_vertical_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let output = document.copy()
  let descendant_ksc_euc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceVerticalKSCEUCDescendant", "Korea1",
    ),
  )
  let descendant_kscpc_euc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceVerticalKSCpcEUCDescendant", "Korea1",
    ),
  )
  let descendant_uhc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceVerticalKSCmsUHCDescendant", "Korea1",
    ),
  )
  let descendant_uhc_hw = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceVerticalKSCmsUHCHWDescendant", "Korea1",
    ),
  )
  let font_ksc_euc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceVerticalKSCEUCTop", "/KSC-EUC-V", descendant_ksc_euc,
    ),
  )
  let font_kscpc_euc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceVerticalKSCpcEUCTop", "/KSCpc-EUC-V", descendant_kscpc_euc,
    ),
  )
  let font_uhc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceVerticalKSCmsUHCTop", "/KSCms-UHC-V", descendant_uhc,
    ),
  )
  let font_uhc_hw = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceVerticalKSCmsUHCHWTop", "/KSCms-UHC-HW-V", descendant_uhc_hw,
    ),
  )
  let pages = output.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font_resources = fixture_acceptance_cpdf_source_page_fonts_for_test(
      output,
      pages[0].resources,
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceKSCV"),
      PdfIndirect(font_ksc_euc),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceKSCpcV"),
      PdfIndirect(font_kscpc_euc),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceUHCV"),
      PdfIndirect(font_uhc),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceUHCHWV"),
      PdfIndirect(font_uhc_hw),
    )
  let resources = pages[0].resources.add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/Font"),
    font_resources,
  )
  let page = { ..pages[0], resources, }
  let vertical_text = @pdflite.pdf_bytes_of_int_array([0xA1, 0xA6])
  let updated_page = output.postpend_operators(
    page,
    [
      Op_BT,
      Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceKSCV"), 12.0),
      Op_Tj(vertical_text),
      Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceKSCpcV"), 12.0),
      Op_Tj(vertical_text),
      Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceUHCV"), 12.0),
      Op_Tj(vertical_text),
      Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceUHCHWV"), 12.0),
      Op_Tj(vertical_text),
      Op_ET,
    ],
    fast=true,
  )
  output.change_pages([updated_page], change_references=true)
}

///|
fn fixture_acceptance_assert_cpdf_source_korea1_vertical_font_for_test(
  document : @pdflite.PdfDocument,
  name : String,
  basefont : String,
  encoding : String,
) -> Unit raise {
  let source_font = fixture_acceptance_cpdf_source_font_entry_for_test(
    document.list_fonts([1]),
    name,
  )
  @test.assert_eq(source_font.subtype, "/Type0")
  @test.assert_eq(source_font.basefont, basefont)
  @test.assert_eq(source_font.encoding, encoding)
  let font = document.read_font(source_font.font)
  @test.assert_eq(font.uses_two_byte_codes(), false)
  guard font is PdfFontCIDKeyed(cid_font) else {
    fail("expected source Korea1 vertical predefined CID-keyed font")
  }
  @test.assert_eq(
    cid_font.encoding,
    PdfPredefinedCMap(fixture_acceptance_pdf_name_for_test(encoding)),
  )
  @test.assert_eq(
    cid_font.composite.cid_system_info.ordering,
    @ascii.encode("Korea1"),
  )
  let extractor = document.text_extractor_of_font(source_font.font)
  @test.assert_eq(
    extractor.codepoints_of_text(@pdflite.pdf_bytes_of_int_array([0xA1, 0xA6])),
    [0x22EF],
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x22EF), Some(0xA1A6))
  @test.assert_eq(extractor.charcode_of_codepoint(0x1F600), None)
}

///|
fn fixture_acceptance_assert_cpdf_source_korea1_vertical_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let expected_text = @utf8.decode_lossy(
    @pdflite.pdf_utf8_of_codepoints([0x22EF]),
  )
  let text = @utf8.decode_lossy(document.test_extract_text([1]))
  fixture_acceptance_assert_contains_for_test(text, expected_text)
  fixture_acceptance_assert_cpdf_source_korea1_vertical_font_for_test(
    document, "/SourceKSCV", "/SourceVerticalKSCEUCTop", "/KSC-EUC-V",
  )
  fixture_acceptance_assert_cpdf_source_korea1_vertical_font_for_test(
    document, "/SourceKSCpcV", "/SourceVerticalKSCpcEUCTop", "/KSCpc-EUC-V",
  )
  fixture_acceptance_assert_cpdf_source_korea1_vertical_font_for_test(
    document, "/SourceUHCV", "/SourceVerticalKSCmsUHCTop", "/KSCms-UHC-V",
  )
  fixture_acceptance_assert_cpdf_source_korea1_vertical_font_for_test(
    document, "/SourceUHCHWV", "/SourceVerticalKSCmsUHCHWTop", "/KSCms-UHC-HW-V",
  )
}

///|
fn fixture_acceptance_cpdf_source_hello_with_japan1_predefined_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let output = document.copy()
  let descendant_90msp_h = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/Source90mspDescendant", "Japan1",
    ),
  )
  let descendant_90msp_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/Source90mspVerticalDescendant", "Japan1",
    ),
  )
  let descendant_hojo_euc_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceHojoEUCVerticalDescendant", "Japan1",
    ),
  )
  let font_90msp_h = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/Source90mspTop", "/90msp-RKSJ-H", descendant_90msp_h,
    ),
  )
  let font_90msp_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/Source90mspVerticalTop", "/90msp-RKSJ-V", descendant_90msp_v,
    ),
  )
  let font_hojo_euc_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceHojoEUCVerticalTop", "/Hojo-EUC-V", descendant_hojo_euc_v,
    ),
  )
  let pages = output.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font_resources = fixture_acceptance_cpdf_source_page_fonts_for_test(
      output,
      pages[0].resources,
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceJ90mspH"),
      PdfIndirect(font_90msp_h),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceJ90mspV"),
      PdfIndirect(font_90msp_v),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceJHojoEUCV"),
      PdfIndirect(font_hojo_euc_v),
    )
  let resources = pages[0].resources.add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/Font"),
    font_resources,
  )
  let page = { ..pages[0], resources, }
  let updated_page = output.postpend_operators(
    page,
    [
      Op_BT,
      Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceJ90mspV"), 12.0),
      Op_Tj(@pdflite.pdf_bytes_of_int_array([0x82, 0x9F])),
      Op_ET,
    ],
    fast=true,
  )
  output.change_pages([updated_page], change_references=true)
}

///|
fn fixture_acceptance_assert_cpdf_source_japan1_predefined_font_for_test(
  document : @pdflite.PdfDocument,
  name : String,
  basefont : String,
  encoding : String,
  text : @pdflite.PdfBytes,
  expected_codepoints : Array[Int],
  reverse_codepoint : Int,
  reverse_charcode : Int,
  uses_two_byte_codes : Bool,
) -> Unit raise {
  let source_font = fixture_acceptance_cpdf_source_font_entry_for_test(
    document.list_fonts([1]),
    name,
  )
  @test.assert_eq(source_font.subtype, "/Type0")
  @test.assert_eq(source_font.basefont, basefont)
  @test.assert_eq(source_font.encoding, encoding)
  let font = document.read_font(source_font.font)
  @test.assert_eq(font.uses_two_byte_codes(), uses_two_byte_codes)
  guard font is PdfFontCIDKeyed(cid_font) else {
    fail("expected source Japan1 predefined CID-keyed font")
  }
  @test.assert_eq(
    cid_font.encoding,
    PdfPredefinedCMap(fixture_acceptance_pdf_name_for_test(encoding)),
  )
  @test.assert_eq(
    cid_font.composite.cid_system_info.ordering,
    @ascii.encode("Japan1"),
  )
  let extractor = document.text_extractor_of_font(source_font.font)
  @test.assert_eq(extractor.codepoints_of_text(text), expected_codepoints)
  @test.assert_eq(
    extractor.charcode_of_codepoint(reverse_codepoint),
    Some(reverse_charcode),
  )
  @test.assert_eq(extractor.charcode_of_codepoint(0x1F600), None)
}

///|
fn fixture_acceptance_assert_cpdf_source_japan1_predefined_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let expected_text = @utf8.decode_lossy(
    @pdflite.pdf_utf8_of_codepoints([0x3041]),
  )
  let text = @utf8.decode_lossy(document.test_extract_text([1]))
  fixture_acceptance_assert_contains_for_test(text, expected_text)
  fixture_acceptance_assert_cpdf_source_japan1_predefined_font_for_test(
    document,
    "/SourceJ90mspH",
    "/Source90mspTop",
    "/90msp-RKSJ-H",
    @pdflite.pdf_bytes_of_int_array([0x41, 0x5C, 0xA6, 0x81, 0x40, 0x93, 0xF1]),
    [0x41, 0x00A5, 0xFF66, 0x3000, 0x4E8C],
    0x00A5,
    0x5C,
    false,
  )
  fixture_acceptance_assert_cpdf_source_japan1_predefined_font_for_test(
    document,
    "/SourceJ90mspV",
    "/Source90mspVerticalTop",
    "/90msp-RKSJ-V",
    @pdflite.pdf_bytes_of_int_array([
      0x41, 0x5C, 0xA6, 0x81, 0x40, 0x82, 0x9F, 0x93, 0xF1,
    ]),
    [0x41, 0x00A5, 0xFF66, 0x3000, 0x3041, 0x4E8C],
    0x3041,
    0x829F,
    false,
  )
  fixture_acceptance_assert_cpdf_source_japan1_predefined_font_for_test(
    document,
    "/SourceJHojoEUCV",
    "/SourceHojoEUCVerticalTop",
    "/Hojo-EUC-V",
    @pdflite.pdf_bytes_of_int_array([0x8F, 0xB4, 0xAE]),
    [0x4EDD],
    0x4EDD,
    0x8FB4AE,
    false,
  )
}

///|
fn fixture_acceptance_cpdf_source_hello_with_japan1_base_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let output = document.copy()
  let descendant_90ms = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/Source90msDescendant", "Japan1",
    ),
  )
  let descendant_90pv = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/Source90pvDescendant", "Japan1",
    ),
  )
  let descendant_jis = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceJISDescendant", "Japan1",
    ),
  )
  let descendant_euc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceJapanEUCDescendant", "Japan1",
    ),
  )
  let descendant_hojo_euc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceHojoEUCHDescendant", "Japan1",
    ),
  )
  let font_90ms = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/Source90msTop", "/90ms-RKSJ-H", descendant_90ms,
    ),
  )
  let font_90pv = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/Source90pvTop", "/90pv-RKSJ-H", descendant_90pv,
    ),
  )
  let font_jis = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceJISTop", "/H", descendant_jis,
    ),
  )
  let font_euc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceJapanEUCTop", "/EUC-H", descendant_euc,
    ),
  )
  let font_hojo_euc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceHojoEUCHTop", "/Hojo-EUC-H", descendant_hojo_euc,
    ),
  )
  let pages = output.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font_resources = fixture_acceptance_cpdf_source_page_fonts_for_test(
      output,
      pages[0].resources,
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceJ90msH"),
      PdfIndirect(font_90ms),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceJ90pvH"),
      PdfIndirect(font_90pv),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceJH"),
      PdfIndirect(font_jis),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceJEUCH"),
      PdfIndirect(font_euc),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceJHojoEUCH"),
      PdfIndirect(font_hojo_euc),
    )
  let resources = pages[0].resources.add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/Font"),
    font_resources,
  )
  let page = { ..pages[0], resources, }
  let updated_page = output.postpend_operators(
    page,
    [
      Op_BT,
      Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceJ90msH"), 12.0),
      Op_Tj(
        @pdflite.pdf_bytes_of_int_array([0x41, 0xA6, 0x81, 0x40, 0x93, 0xF1]),
      ),
      Op_ET,
    ],
    fast=true,
  )
  output.change_pages([updated_page], change_references=true)
}

///|
fn fixture_acceptance_source_font_extractor_for_test(
  document : @pdflite.PdfDocument,
  name : String,
) -> @pdflite.PdfTextExtractor raise {
  let source_font = fixture_acceptance_cpdf_source_font_entry_for_test(
    document.list_fonts([1]),
    name,
  )
  document.text_extractor_of_font(source_font.font)
}

///|
fn fixture_acceptance_assert_cpdf_source_japan1_base_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let expected_text = @utf8.decode_lossy(
    @pdflite.pdf_utf8_of_codepoints([0x41, 0xFF66, 0x3000, 0x4E8C]),
  )
  let text = @utf8.decode_lossy(document.test_extract_text([1]))
  fixture_acceptance_assert_contains_for_test(text, expected_text)
  fixture_acceptance_assert_cpdf_source_japan1_predefined_font_for_test(
    document,
    "/SourceJ90msH",
    "/Source90msTop",
    "/90ms-RKSJ-H",
    @pdflite.pdf_bytes_of_int_array([0x41, 0xA6, 0x81, 0x40, 0x93, 0xF1]),
    [0x41, 0xFF66, 0x3000, 0x4E8C],
    0x4E8C,
    0x93F1,
    false,
  )
  let rksj = fixture_acceptance_source_font_extractor_for_test(
    document, "/SourceJ90msH",
  )
  @test.assert_eq(rksj.charcode_of_codepoint(0x20AC), Some(0x80))
  fixture_acceptance_assert_cpdf_source_japan1_predefined_font_for_test(
    document,
    "/SourceJ90pvH",
    "/Source90pvTop",
    "/90pv-RKSJ-H",
    @pdflite.pdf_bytes_of_int_array([0x5C, 0x80, 0xA0, 0x81, 0x7C, 0x85, 0x91]),
    [0x00A5, 0x005C, 0x00A0, 0x2212, 0xF860, 0x0030, 0x002E],
    0x2212,
    0x817C,
    false,
  )
  let rksj_90pv = fixture_acceptance_source_font_extractor_for_test(
    document, "/SourceJ90pvH",
  )
  @test.assert_eq(rksj_90pv.charcode_of_codepoint(0xF860), None)
  fixture_acceptance_assert_cpdf_source_japan1_predefined_font_for_test(
    document,
    "/SourceJH",
    "/SourceJISTop",
    "/H",
    @pdflite.pdf_bytes_of_int_array([0x21, 0x21, 0x24, 0x22]),
    [0x3000, 0x3042],
    0x3042,
    0x2422,
    true,
  )
  fixture_acceptance_assert_cpdf_source_japan1_predefined_font_for_test(
    document,
    "/SourceJEUCH",
    "/SourceJapanEUCTop",
    "/EUC-H",
    @pdflite.pdf_bytes_of_int_array([0xA1, 0xA1, 0xA4, 0xA2]),
    [0x3000, 0x3042],
    0x3042,
    0xA4A2,
    false,
  )
  fixture_acceptance_assert_cpdf_source_japan1_predefined_font_for_test(
    document,
    "/SourceJHojoEUCH",
    "/SourceHojoEUCHTop",
    "/Hojo-EUC-H",
    @pdflite.pdf_bytes_of_int_array([0x8F, 0xB4, 0xAE]),
    [0x4EDD],
    0x4EDD,
    0x8FB4AE,
    false,
  )
}

///|
fn fixture_acceptance_cpdf_source_hello_with_gb_cns_predefined_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let output = document.copy()
  let descendant_gb_utf16_h = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceUniGBUTF16Descendant", "GB1",
    ),
  )
  let descendant_gb_utf16_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceUniGBUTF16VerticalDescendant", "GB1",
    ),
  )
  let descendant_gb_ucs32_h = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceUniGBUCS32Descendant", "GB1",
    ),
  )
  let descendant_gb_ucs32_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceUniGBUCS32VerticalDescendant", "GB1",
    ),
  )
  let descendant_cns_ucs2_h = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceUniCNSUCS2Descendant", "CNS1",
    ),
  )
  let descendant_cns_ucs2_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceUniCNSUCS2VerticalDescendant", "CNS1",
    ),
  )
  let descendant_cns_utf16_h = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceUniCNSUTF16Descendant", "CNS1",
    ),
  )
  let descendant_cns_utf16_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceUniCNSUTF16VerticalDescendant", "CNS1",
    ),
  )
  let font_gb_utf16_h = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceUniGBUTF16Top", "/UniGB-UTF16-H", descendant_gb_utf16_h,
    ),
  )
  let font_gb_utf16_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceUniGBUTF16VerticalTop", "/UniGB-UTF16-V", descendant_gb_utf16_v,
    ),
  )
  let font_gb_ucs32_h = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceUniGBUCS32Top", "/UniGB-UCS32-H", descendant_gb_ucs32_h,
    ),
  )
  let font_gb_ucs32_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceUniGBUCS32VerticalTop", "/UniGB-UCS32-V", descendant_gb_ucs32_v,
    ),
  )
  let font_cns_ucs2_h = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceUniCNSUCS2Top", "/UniCNS-UCS2-H", descendant_cns_ucs2_h,
    ),
  )
  let font_cns_ucs2_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceUniCNSUCS2VerticalTop", "/UniCNS-UCS2-V", descendant_cns_ucs2_v,
    ),
  )
  let font_cns_utf16_h = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceUniCNSUTF16Top", "/UniCNS-UTF16-H", descendant_cns_utf16_h,
    ),
  )
  let font_cns_utf16_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceUniCNSUTF16VerticalTop", "/UniCNS-UTF16-V", descendant_cns_utf16_v,
    ),
  )
  let pages = output.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font_resources = fixture_acceptance_cpdf_source_page_fonts_for_test(
      output,
      pages[0].resources,
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceGB16H"),
      PdfIndirect(font_gb_utf16_h),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceGB16V"),
      PdfIndirect(font_gb_utf16_v),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceGB32H"),
      PdfIndirect(font_gb_ucs32_h),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceGB32V"),
      PdfIndirect(font_gb_ucs32_v),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceCNS2H"),
      PdfIndirect(font_cns_ucs2_h),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceCNS2V"),
      PdfIndirect(font_cns_ucs2_v),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceCNS16H"),
      PdfIndirect(font_cns_utf16_h),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceCNS16V"),
      PdfIndirect(font_cns_utf16_v),
    )
  let resources = pages[0].resources.add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/Font"),
    font_resources,
  )
  let page = { ..pages[0], resources, }
  let updated_page = output.postpend_operators(
    page,
    [
      Op_BT,
      Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceGB16H"), 12.0),
      Op_Tj(@pdflite.pdf_bytes_of_int_array([0x4E, 0x00, 0x56, 0xFD])),
      Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceCNS16H"), 12.0),
      Op_Tj(@pdflite.pdf_bytes_of_int_array([0x4E, 0x00, 0x4E, 0x8C])),
      Op_ET,
    ],
    fast=true,
  )
  output.change_pages([updated_page], change_references=true)
}

///|
fn fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
  document : @pdflite.PdfDocument,
  name : String,
  basefont : String,
  encoding : String,
  ordering : String,
  text : @pdflite.PdfBytes,
  expected_codepoints : Array[Int],
  reverse_codepoint : Int,
  reverse_charcode : Int,
  uses_two_byte_codes : Bool,
) -> Unit raise {
  let source_font = fixture_acceptance_cpdf_source_font_entry_for_test(
    document.list_fonts([1]),
    name,
  )
  @test.assert_eq(source_font.subtype, "/Type0")
  @test.assert_eq(source_font.basefont, basefont)
  @test.assert_eq(source_font.encoding, encoding)
  let font = document.read_font(source_font.font)
  @test.assert_eq(font.uses_two_byte_codes(), uses_two_byte_codes)
  guard font is PdfFontCIDKeyed(cid_font) else {
    fail("expected source GB/CNS predefined CID-keyed font")
  }
  @test.assert_eq(
    cid_font.encoding,
    PdfPredefinedCMap(fixture_acceptance_pdf_name_for_test(encoding)),
  )
  @test.assert_eq(
    cid_font.composite.cid_system_info.ordering,
    @ascii.encode(ordering),
  )
  let extractor = document.text_extractor_of_font(source_font.font)
  @test.assert_eq(extractor.codepoints_of_text(text), expected_codepoints)
  @test.assert_eq(
    extractor.charcode_of_codepoint(reverse_codepoint),
    Some(reverse_charcode),
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_gb_cns_predefined_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let extracted = @utf8.decode_lossy(document.test_extract_text([1]))
  fixture_acceptance_assert_contains_for_test(
    extracted,
    @utf8.decode_lossy(@pdflite.pdf_utf8_of_codepoints([0x4E00, 0x56FD])),
  )
  fixture_acceptance_assert_contains_for_test(
    extracted,
    @utf8.decode_lossy(@pdflite.pdf_utf8_of_codepoints([0x4E00, 0x4E8C])),
  )
  fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
    document,
    "/SourceGB16H",
    "/SourceUniGBUTF16Top",
    "/UniGB-UTF16-H",
    "GB1",
    @pdflite.pdf_bytes_of_int_array([0x4E, 0x00, 0x56, 0xFD]),
    [0x4E00, 0x56FD],
    0x56FD,
    0x56FD,
    true,
  )
  fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
    document,
    "/SourceGB16V",
    "/SourceUniGBUTF16VerticalTop",
    "/UniGB-UTF16-V",
    "GB1",
    @pdflite.pdf_bytes_of_int_array([0x4E, 0x00, 0x56, 0xFD]),
    [0x4E00, 0x56FD],
    0x4E00,
    0x4E00,
    true,
  )
  fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
    document,
    "/SourceGB32H",
    "/SourceUniGBUCS32Top",
    "/UniGB-UCS32-H",
    "GB1",
    @pdflite.pdf_bytes_of_int_array([
      0x00, 0x00, 0x4E, 0x00, 0x00, 0x00, 0x56, 0xFD,
    ]),
    [0x4E00, 0x56FD],
    0x4E00,
    0x4E00,
    false,
  )
  fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
    document,
    "/SourceGB32V",
    "/SourceUniGBUCS32VerticalTop",
    "/UniGB-UCS32-V",
    "GB1",
    @pdflite.pdf_bytes_of_int_array([
      0x00, 0x00, 0x4E, 0x00, 0x00, 0x00, 0x56, 0xFD,
    ]),
    [0x4E00, 0x56FD],
    0x56FD,
    0x56FD,
    false,
  )
  fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
    document,
    "/SourceCNS2H",
    "/SourceUniCNSUCS2Top",
    "/UniCNS-UCS2-H",
    "CNS1",
    @pdflite.pdf_bytes_of_int_array([0x4E, 0x00, 0x4E, 0x8C]),
    [0x4E00, 0x4E8C],
    0x4E00,
    0x4E00,
    true,
  )
  fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
    document,
    "/SourceCNS2V",
    "/SourceUniCNSUCS2VerticalTop",
    "/UniCNS-UCS2-V",
    "CNS1",
    @pdflite.pdf_bytes_of_int_array([0x00, 0x42, 0x4E, 0x8C]),
    [0x42, 0x4E8C],
    0x4E8C,
    0x4E8C,
    true,
  )
  fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
    document,
    "/SourceCNS16H",
    "/SourceUniCNSUTF16Top",
    "/UniCNS-UTF16-H",
    "CNS1",
    @pdflite.pdf_bytes_of_int_array([0x4E, 0x00, 0xD8, 0x34, 0xDD, 0x1E]),
    [0x4E00, 0x1D11E],
    0x1D11E,
    0xD834DD1E,
    true,
  )
  fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
    document,
    "/SourceCNS16V",
    "/SourceUniCNSUTF16VerticalTop",
    "/UniCNS-UTF16-V",
    "CNS1",
    @pdflite.pdf_bytes_of_int_array([0x4E, 0x00, 0x4E, 0x8C]),
    [0x4E00, 0x4E8C],
    0x4E8C,
    0x4E8C,
    true,
  )
}

///|
fn fixture_acceptance_cpdf_source_hello_with_gb1_legacy_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let output = document.copy()
  let descendant_gb_euc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceGBEUCDescendant", "GB1",
    ),
  )
  let descendant_gbpc_euc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceGBpcEUCDescendant", "GB1",
    ),
  )
  let descendant_gbk = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceGBKDescendant", "GB1",
    ),
  )
  let descendant_gbkp = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceGBKpDescendant", "GB1",
    ),
  )
  let descendant_gbk2k = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceGBK2KDescendant", "GB1",
    ),
  )
  let font_gb_euc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceGBEUCTop", "/GB-EUC-H", descendant_gb_euc,
    ),
  )
  let font_gbpc_euc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceGBpcEUCTop", "/GBpc-EUC-H", descendant_gbpc_euc,
    ),
  )
  let font_gbk = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceGBKTop", "/GBK-EUC-H", descendant_gbk,
    ),
  )
  let font_gbkp = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceGBKpTop", "/GBKp-EUC-H", descendant_gbkp,
    ),
  )
  let font_gbk2k = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceGBK2KTop", "/GBK2K-H", descendant_gbk2k,
    ),
  )
  let pages = output.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font_resources = fixture_acceptance_cpdf_source_page_fonts_for_test(
      output,
      pages[0].resources,
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceGBEUC"),
      PdfIndirect(font_gb_euc),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceGBpcEUC"),
      PdfIndirect(font_gbpc_euc),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceGBK"),
      PdfIndirect(font_gbk),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceGBKp"),
      PdfIndirect(font_gbkp),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceGBK2K"),
      PdfIndirect(font_gbk2k),
    )
  let resources = pages[0].resources.add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/Font"),
    font_resources,
  )
  let page = { ..pages[0], resources, }
  let updated_page = output.postpend_operators(
    page,
    [
      Op_BT,
      Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceGBEUC"), 12.0),
      Op_Tj(
        @pdflite.pdf_bytes_of_int_array([
          0x41, 0xC4, 0xE3, 0xBA, 0xC3, 0xA1, 0xA1, 0xA3, 0xC1,
        ]),
      ),
      Op_ET,
    ],
    fast=true,
  )
  output.change_pages([updated_page], change_references=true)
}

///|
fn fixture_acceptance_assert_cpdf_source_gb1_legacy_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let ops = fixture_acceptance_page_content_ops_for_test(document)
  fixture_acceptance_assert_content_op_for_test(
    ops,
    Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceGBEUC"), 12.0),
  )
  fixture_acceptance_assert_content_op_for_test(
    ops,
    Op_Tj(
      @pdflite.pdf_bytes_of_int_array([
        0x41, 0xC4, 0xE3, 0xBA, 0xC3, 0xA1, 0xA1, 0xA3, 0xC1,
      ]),
    ),
  )
  fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
    document,
    "/SourceGBEUC",
    "/SourceGBEUCTop",
    "/GB-EUC-H",
    "GB1",
    @pdflite.pdf_bytes_of_int_array([
      0x41, 0xC4, 0xE3, 0xBA, 0xC3, 0xA1, 0xA1, 0xA3, 0xC1,
    ]),
    [0x41, 0x4F60, 0x597D, 0x3000, 0xFF21],
    0x4F60,
    0xC4E3,
    false,
  )
  let gb_euc = fixture_acceptance_source_font_extractor_for_test(
    document, "/SourceGBEUC",
  )
  @test.assert_eq(gb_euc.charcode_of_codepoint(0x20AC), None)
  fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
    document,
    "/SourceGBpcEUC",
    "/SourceGBpcEUCTop",
    "/GBpc-EUC-H",
    "GB1",
    @pdflite.pdf_bytes_of_int_array([
      0x41, 0x80, 0x83, 0xA0, 0xFD, 0xFE, 0xFF, 0xA1, 0xA1, 0xA1, 0xAB, 0xA8, 0xBF,
      0xC4, 0xE3, 0xBA, 0xC3,
    ]),
    [
      0x41, 0x00FC, 0x83, 0x00A0, 0x00A9, 0x2122, 0x2026, 0x3000, 0x301C, 0x006E,
      0x0300, 0x4F60, 0x597D,
    ],
    0x301C,
    0xA1AB,
    false,
  )
  let gbpc_euc = fixture_acceptance_source_font_extractor_for_test(
    document, "/SourceGBpcEUC",
  )
  @test.assert_eq(gbpc_euc.charcode_of_codepoint(0x00FC), Some(0x80))
  @test.assert_eq(gbpc_euc.charcode_of_codepoint(0x0300), None)
  fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
    document,
    "/SourceGBK",
    "/SourceGBKTop",
    "/GBK-EUC-H",
    "GB1",
    @pdflite.pdf_bytes_of_int_array([
      0x41, 0x80, 0x81, 0x40, 0xC4, 0xE3, 0xBA, 0xC3, 0xA1, 0xA1, 0xA3, 0xC1, 0xA1,
      0x40, 0xA8, 0xBC, 0xFE, 0xFE, 0xFF, 0x81, 0x39,
    ]),
    [
      0x41, 0x80, 0x4E02, 0x4F60, 0x597D, 0x3000, 0xFF21, 0xE4C6, 0x1E3F, 0xE4C5,
      0xF8F5, 0x8139,
    ],
    0x4E02,
    0x8140,
    false,
  )
  let gbk = fixture_acceptance_source_font_extractor_for_test(
    document, "/SourceGBK",
  )
  @test.assert_eq(gbk.charcode_of_codepoint(0xF8F5), Some(0xFF))
  @test.assert_eq(gbk.charcode_of_codepoint(0x1F600), None)
  fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
    document,
    "/SourceGBKp",
    "/SourceGBKpTop",
    "/GBKp-EUC-H",
    "GB1",
    @pdflite.pdf_bytes_of_int_array([
      0x41, 0x80, 0x81, 0x40, 0xC4, 0xE3, 0xBA, 0xC3, 0xA1, 0xA1, 0xA3, 0xC1, 0xA1,
      0x40, 0xA8, 0xBC, 0xFE, 0xFE, 0xFF, 0x81, 0x39,
    ]),
    [
      0x41, 0x80, 0x4E02, 0x4F60, 0x597D, 0x3000, 0xFF21, 0xE4C6, 0x1E3F, 0xE4C5,
      0xF8F5, 0x8139,
    ],
    0x1E3F,
    0xA8BC,
    false,
  )
  let gbkp = fixture_acceptance_source_font_extractor_for_test(
    document, "/SourceGBKp",
  )
  @test.assert_eq(gbkp.charcode_of_codepoint(0xF8F5), Some(0xFF))
  @test.assert_eq(gbkp.charcode_of_codepoint(0x1F600), None)
  fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
    document,
    "/SourceGBK2K",
    "/SourceGBK2KTop",
    "/GBK2K-H",
    "GB1",
    @pdflite.pdf_bytes_of_int_array([
      0x41, 0x81, 0x40, 0xC4, 0xE3, 0xBA, 0xC3, 0xFE, 0x51, 0x81, 0x30, 0x84, 0x36,
      0x82, 0x36, 0x94, 0x35,
    ]),
    [0x41, 0x4E02, 0x4F60, 0x597D, 0x20087, 0x00A5, 0xA4C6],
    0x00A5,
    0x81308436,
    false,
  )
  let gbk2k = fixture_acceptance_source_font_extractor_for_test(
    document, "/SourceGBK2K",
  )
  @test.assert_eq(gbk2k.charcode_of_codepoint(0x20087), Some(0xFE51))
  @test.assert_eq(gbk2k.charcode_of_codepoint(0xA4C6), Some(0x82369435))
  @test.assert_eq(gbk2k.charcode_of_codepoint(0x1F600), None)
}

///|
fn fixture_acceptance_cpdf_source_hello_with_cns1_legacy_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let output = document.copy()
  let descendant_eten_b5 = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceETenB5Descendant", "CNS1",
    ),
  )
  let descendant_b5pc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceB5pcDescendant", "CNS1",
    ),
  )
  let descendant_hkscs = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceHKscsB5Descendant", "CNS1",
    ),
  )
  let descendant_etenms = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceETenmsB5Descendant", "CNS1",
    ),
  )
  let descendant_hkdla = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceHKdlaB5Descendant", "CNS1",
    ),
  )
  let descendant_hkdlb = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceHKdlbB5Descendant", "CNS1",
    ),
  )
  let descendant_hkgccs = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceHKgccsB5Descendant", "CNS1",
    ),
  )
  let descendant_hkm314 = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceHKm314B5Descendant", "CNS1",
    ),
  )
  let descendant_hkm471 = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceHKm471B5Descendant", "CNS1",
    ),
  )
  let descendant_cns_euc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceCNSEUCDescendant", "CNS1",
    ),
  )
  let descendant_cns_euc_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
      "/SourceCNSEUCVerticalDescendant", "CNS1",
    ),
  )
  let font_eten_b5 = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceETenB5Top", "/ETen-B5-H", descendant_eten_b5,
    ),
  )
  let font_b5pc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceB5pcTop", "/B5pc-H", descendant_b5pc,
    ),
  )
  let font_hkscs = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceHKscsB5Top", "/HKscs-B5-H", descendant_hkscs,
    ),
  )
  let font_etenms = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceETenmsB5Top", "/ETenms-B5-H", descendant_etenms,
    ),
  )
  let font_hkdla = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceHKdlaB5Top", "/HKdla-B5-H", descendant_hkdla,
    ),
  )
  let font_hkdlb = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceHKdlbB5Top", "/HKdlb-B5-H", descendant_hkdlb,
    ),
  )
  let font_hkgccs = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceHKgccsB5Top", "/HKgccs-B5-H", descendant_hkgccs,
    ),
  )
  let font_hkm314 = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceHKm314B5Top", "/HKm314-B5-H", descendant_hkm314,
    ),
  )
  let font_hkm471 = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceHKm471B5Top", "/HKm471-B5-H", descendant_hkm471,
    ),
  )
  let font_cns_euc = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceCNSEUCTop", "/CNS-EUC-H", descendant_cns_euc,
    ),
  )
  let font_cns_euc_v = output.add_object(
    fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
      "/SourceCNSEUCVerticalTop", "/CNS-EUC-V", descendant_cns_euc_v,
    ),
  )
  let pages = output.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let font_resources = fixture_acceptance_cpdf_source_page_fonts_for_test(
      output,
      pages[0].resources,
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceETenB5"),
      PdfIndirect(font_eten_b5),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceB5pc"),
      PdfIndirect(font_b5pc),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceHKscsB5"),
      PdfIndirect(font_hkscs),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceETenmsB5"),
      PdfIndirect(font_etenms),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceHKdlaB5"),
      PdfIndirect(font_hkdla),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceHKdlbB5"),
      PdfIndirect(font_hkdlb),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceHKgccsB5"),
      PdfIndirect(font_hkgccs),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceHKm314B5"),
      PdfIndirect(font_hkm314),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceHKm471B5"),
      PdfIndirect(font_hkm471),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceCNSEUC"),
      PdfIndirect(font_cns_euc),
    )
    .add_dict_entry(
      fixture_acceptance_pdf_name_for_test("/SourceCNSEUCV"),
      PdfIndirect(font_cns_euc_v),
    )
  let resources = pages[0].resources.add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/Font"),
    font_resources,
  )
  let page = { ..pages[0], resources, }
  let updated_page = output.postpend_operators(
    page,
    [
      Op_BT,
      Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceETenB5"), 12.0),
      Op_Tj(
        @pdflite.pdf_bytes_of_int_array([
          0x41, 0xA7, 0x41, 0xA6, 0x6E, 0xA4, 0x40, 0xA4, 0xA4, 0xA1, 0x40,
        ]),
      ),
      Op_ET,
    ],
    fast=true,
  )
  output.change_pages([updated_page], change_references=true)
}

///|
fn fixture_acceptance_assert_cpdf_source_cns1_legacy_font_for_test(
  document : @pdflite.PdfDocument,
  name : String,
  basefont : String,
  encoding : String,
  text : Array[Int],
  expected_codepoints : Array[Int],
  reverse_codepoint : Int,
  reverse_charcode : Int,
) -> @pdflite.PdfTextExtractor raise {
  fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
    document,
    name,
    basefont,
    encoding,
    "CNS1",
    @pdflite.pdf_bytes_of_int_array(text),
    expected_codepoints,
    reverse_codepoint,
    reverse_charcode,
    false,
  )
  fixture_acceptance_source_font_extractor_for_test(document, name)
}

///|
fn fixture_acceptance_assert_cpdf_source_cns1_legacy_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let ops = fixture_acceptance_page_content_ops_for_test(document)
  fixture_acceptance_assert_content_op_for_test(
    ops,
    Op_Tf(fixture_acceptance_pdf_name_for_test("/SourceETenB5"), 12.0),
  )
  fixture_acceptance_assert_content_op_for_test(
    ops,
    Op_Tj(
      @pdflite.pdf_bytes_of_int_array([
        0x41, 0xA7, 0x41, 0xA6, 0x6E, 0xA4, 0x40, 0xA4, 0xA4, 0xA1, 0x40,
      ]),
    ),
  )
  let eten_b5 = fixture_acceptance_assert_cpdf_source_cns1_legacy_font_for_test(
    document,
    "/SourceETenB5",
    "/SourceETenB5Top",
    "/ETen-B5-H",
    [0x41, 0xA7, 0x41, 0xA6, 0x6E, 0xA4, 0x40, 0xA4, 0xA4, 0xA1, 0x40],
    [0x41, 0x4F60, 0x597D, 0x4E00, 0x4E2D, 0x3000],
    0x4F60,
    0xA741,
  )
  @test.assert_eq(eten_b5.charcode_of_codepoint(0x4E00), Some(0xA440))
  @test.assert_eq(eten_b5.charcode_of_codepoint(0x4E2D), Some(0xA4A4))
  @test.assert_eq(eten_b5.charcode_of_codepoint(0x20AC), None)
  let b5pc = fixture_acceptance_assert_cpdf_source_cns1_legacy_font_for_test(
    document,
    "/SourceB5pc",
    "/SourceB5pcTop",
    "/B5pc-H",
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
  )
  @test.assert_eq(b5pc.charcode_of_codepoint(0x005C), Some(0x5C))
  @test.assert_eq(b5pc.charcode_of_codepoint(0x00A9), Some(0xFD))
  @test.assert_eq(b5pc.charcode_of_codepoint(0xFE54), Some(0xA151))
  @test.assert_eq(b5pc.charcode_of_codepoint(0x20AC), None)
  let hkscs = fixture_acceptance_assert_cpdf_source_cns1_legacy_font_for_test(
    document,
    "/SourceHKscsB5",
    "/SourceHKscsB5Top",
    "/HKscs-B5-H",
    [
      0x41, 0x87, 0x40, 0x87, 0x45, 0x89, 0x43, 0xA1, 0x40, 0xA7, 0x41, 0xA6, 0x6E,
      0xC6, 0xE4, 0xFE, 0xFE, 0x80,
    ],
    [
      0x41, 0x43F0, 0x27267, 0x650A, 0x3000, 0x4F60, 0x597D, 0xFF3B, 0x79D4, 0x80,
    ],
    0x27267,
    0x8745,
  )
  @test.assert_eq(hkscs.charcode_of_codepoint(0x43F0), Some(0x8740))
  @test.assert_eq(hkscs.charcode_of_codepoint(0x650A), Some(0x8943))
  @test.assert_eq(hkscs.charcode_of_codepoint(0x79D4), Some(0xFEFE))
  @test.assert_eq(hkscs.charcode_of_codepoint(0x1F600), None)
  let etenms = fixture_acceptance_assert_cpdf_source_cns1_legacy_font_for_test(
    document,
    "/SourceETenmsB5",
    "/SourceETenmsB5Top",
    "/ETenms-B5-H",
    [0x41, 0xA1, 0xC2, 0xA2, 0x41, 0xC7, 0xFD, 0x80],
    [0x41, 0x00AF, 0x2215, 0x0419, 0x80],
    0x0419,
    0xC7FD,
  )
  @test.assert_eq(etenms.charcode_of_codepoint(0x00AF), Some(0xA1C2))
  @test.assert_eq(etenms.charcode_of_codepoint(0x2215), Some(0xA241))
  @test.assert_eq(etenms.charcode_of_codepoint(0x1F600), None)
  let hkdla = fixture_acceptance_assert_cpdf_source_cns1_legacy_font_for_test(
    document,
    "/SourceHKdlaB5",
    "/SourceHKdlaB5Top",
    "/HKdla-B5-H",
    [0x41, 0xFA, 0x41, 0x80],
    [0x41, 0x5F0D, 0x80],
    0x5F0D,
    0xFA41,
  )
  @test.assert_eq(hkdla.charcode_of_codepoint(0x1F600), None)
  let hkdlb = fixture_acceptance_assert_cpdf_source_cns1_legacy_font_for_test(
    document,
    "/SourceHKdlbB5",
    "/SourceHKdlbB5Top",
    "/HKdlb-B5-H",
    [0x41, 0x8E, 0x40, 0x80],
    [0x41, 0x99C4, 0x80],
    0x99C4,
    0x8E40,
  )
  @test.assert_eq(hkdlb.charcode_of_codepoint(0x1F600), None)
  let hkgccs = fixture_acceptance_assert_cpdf_source_cns1_legacy_font_for_test(
    document,
    "/SourceHKgccsB5",
    "/SourceHKgccsB5Top",
    "/HKgccs-B5-H",
    [0x41, 0x8A, 0x43, 0x80],
    [0x41, 0x20C42, 0x80],
    0x20C42,
    0x8A43,
  )
  @test.assert_eq(hkgccs.charcode_of_codepoint(0x1F600), None)
  let hkm314 = fixture_acceptance_assert_cpdf_source_cns1_legacy_font_for_test(
    document,
    "/SourceHKm314B5",
    "/SourceHKm314B5Top",
    "/HKm314-B5-H",
    [0x41, 0xC7, 0x40, 0x80],
    [0x41, 0x4E21, 0x80],
    0x4E21,
    0xC740,
  )
  @test.assert_eq(hkm314.charcode_of_codepoint(0x1F600), None)
  let hkm471 = fixture_acceptance_assert_cpdf_source_cns1_legacy_font_for_test(
    document,
    "/SourceHKm471B5",
    "/SourceHKm471B5Top",
    "/HKm471-B5-H",
    [0x41, 0xFA, 0x40, 0x80],
    [0x41, 0x4E21, 0x80],
    0x4E21,
    0xFA40,
  )
  @test.assert_eq(hkm471.charcode_of_codepoint(0x1F600), None)
  let cns_euc = fixture_acceptance_assert_cpdf_source_cns1_legacy_font_for_test(
    document,
    "/SourceCNSEUC",
    "/SourceCNSEUCTop",
    "/CNS-EUC-H",
    [0x20, 0x80, 0xA1, 0xA1, 0xA1, 0xAC, 0x8E, 0xA2, 0xA1, 0xA1],
    [0x20, 0x80, 0x3000, 0x2026, 0x4E42],
    0x4E42,
    0x8EA2A1A1,
  )
  @test.assert_eq(cns_euc.charcode_of_codepoint(0x3000), Some(0xA1A1))
  @test.assert_eq(cns_euc.charcode_of_codepoint(0x2026), Some(0xA1AC))
  @test.assert_eq(cns_euc.charcode_of_codepoint(0x1F600), None)
  let cns_euc_v = fixture_acceptance_assert_cpdf_source_cns1_legacy_font_for_test(
    document,
    "/SourceCNSEUCV",
    "/SourceCNSEUCVerticalTop",
    "/CNS-EUC-V",
    [0xA1, 0xAC, 0x8E, 0xA1, 0xA1, 0xAC],
    [0xFE19, 0xFE19],
    0xFE19,
    0xA1AC,
  )
  @test.assert_eq(cns_euc_v.charcode_of_codepoint(0x1F600), None)
}

///|
fn fixture_acceptance_cpdf_source_vertical_cmap_cases_for_test() -> Array[
  (String, String, String, String, String, Array[Int], Array[Int], Int, Int),
] {
  [
    (
      "/SourceVGBEUC",
      "/SourceVerticalGBEUCTop",
      "/GB-EUC-V",
      "/SourceVerticalGBEUCDescendant",
      "GB1",
      [0xA1, 0xA2],
      [0x3001],
      0x3001,
      0xA1A2,
    ),
    (
      "/SourceVGBpcEUC",
      "/SourceVerticalGBpcEUCTop",
      "/GBpc-EUC-V",
      "/SourceVerticalGBpcEUCDescendant",
      "GB1",
      [0xA1, 0xA2],
      [0x3001],
      0x3001,
      0xA1A2,
    ),
    (
      "/SourceVGBK",
      "/SourceVerticalGBKTop",
      "/GBK-EUC-V",
      "/SourceVerticalGBKDescendant",
      "GB1",
      [0xA1, 0xA2],
      [0x3001],
      0x3001,
      0xA1A2,
    ),
    (
      "/SourceVGBKp",
      "/SourceVerticalGBKpTop",
      "/GBKp-EUC-V",
      "/SourceVerticalGBKpDescendant",
      "GB1",
      [0xA1, 0xA2],
      [0x3001],
      0x3001,
      0xA1A2,
    ),
    (
      "/SourceVGBK2K",
      "/SourceVerticalGBK2KTop",
      "/GBK2K-V",
      "/SourceVerticalGBK2KDescendant",
      "GB1",
      [0xA4, 0xC3],
      [0x3064],
      0x3064,
      0xA4C3,
    ),
    (
      "/SourceVB5",
      "/SourceVerticalB5Top",
      "/B5-V",
      "/SourceVerticalB5Descendant",
      "CNS1",
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/SourceVB5pc",
      "/SourceVerticalB5pcTop",
      "/B5pc-V",
      "/SourceVerticalB5pcDescendant",
      "CNS1",
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/SourceVETen",
      "/SourceVerticalETenTop",
      "/ETen-B5-V",
      "/SourceVerticalETenDescendant",
      "CNS1",
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/SourceVETenms",
      "/SourceVerticalETenmsTop",
      "/ETenms-B5-V",
      "/SourceVerticalETenmsDescendant",
      "CNS1",
      [0xA1, 0x4C],
      [0xFE30],
      0xFE30,
      0xA14C,
    ),
    (
      "/SourceVHKdla",
      "/SourceVerticalHKdlaTop",
      "/HKdla-B5-V",
      "/SourceVerticalHKdlaDescendant",
      "CNS1",
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/SourceVHKdlb",
      "/SourceVerticalHKdlbTop",
      "/HKdlb-B5-V",
      "/SourceVerticalHKdlbDescendant",
      "CNS1",
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/SourceVHKgccs",
      "/SourceVerticalHKgccsTop",
      "/HKgccs-B5-V",
      "/SourceVerticalHKgccsDescendant",
      "CNS1",
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/SourceVHKm314",
      "/SourceVerticalHKm314Top",
      "/HKm314-B5-V",
      "/SourceVerticalHKm314Descendant",
      "CNS1",
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/SourceVHKm471",
      "/SourceVerticalHKm471Top",
      "/HKm471-B5-V",
      "/SourceVerticalHKm471Descendant",
      "CNS1",
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
    (
      "/SourceVHKscs",
      "/SourceVerticalHKscsTop",
      "/HKscs-B5-V",
      "/SourceVerticalHKscsDescendant",
      "CNS1",
      [0xA1, 0x4B],
      [0xFE19],
      0xFE19,
      0xA14B,
    ),
  ]
}

///|
fn fixture_acceptance_cpdf_source_hello_with_vertical_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  let output = document.copy()
  let pages = output.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let cases = fixture_acceptance_cpdf_source_vertical_cmap_cases_for_test()
  let mut font_resources = fixture_acceptance_cpdf_source_page_fonts_for_test(
    output,
    pages[0].resources,
  )
  for case in cases {
    let descendant = output.add_object(
      fixture_acceptance_cpdf_source_predefined_descendant_font_for_test(
        case.3,
        case.4,
      ),
    )
    let font = output.add_object(
      fixture_acceptance_cpdf_source_predefined_type0_font_for_test(
        case.1,
        case.2,
        descendant,
      ),
    )
    font_resources = font_resources.add_dict_entry(
      fixture_acceptance_pdf_name_for_test(case.0),
      PdfIndirect(font),
    )
  }
  let resources = pages[0].resources.add_dict_entry(
    fixture_acceptance_pdf_name_for_test("/Font"),
    font_resources,
  )
  let page = { ..pages[0], resources, }
  let first = cases[0]
  let updated_page = output.postpend_operators(
    page,
    [
      Op_BT,
      Op_Tf(fixture_acceptance_pdf_name_for_test(first.0), 12.0),
      Op_Tj(@pdflite.pdf_bytes_of_int_array(first.5)),
      Op_ET,
    ],
    fast=true,
  )
  output.change_pages([updated_page], change_references=true)
}

///|
fn fixture_acceptance_assert_cpdf_source_vertical_cmaps_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let cases = fixture_acceptance_cpdf_source_vertical_cmap_cases_for_test()
  let first = cases[0]
  let ops = fixture_acceptance_page_content_ops_for_test(document)
  fixture_acceptance_assert_content_op_for_test(
    ops,
    Op_Tf(fixture_acceptance_pdf_name_for_test(first.0), 12.0),
  )
  fixture_acceptance_assert_content_op_for_test(
    ops,
    Op_Tj(@pdflite.pdf_bytes_of_int_array(first.5)),
  )
  for case in cases {
    fixture_acceptance_assert_cpdf_source_gb_cns_predefined_font_for_test(
      document,
      case.0,
      case.1,
      case.2,
      case.4,
      @pdflite.pdf_bytes_of_int_array(case.5),
      case.6,
      case.7,
      case.8,
      false,
    )
    let extractor = fixture_acceptance_source_font_extractor_for_test(
      document,
      case.0,
    )
    @test.assert_eq(extractor.charcode_of_codepoint(0x1F600), None)
  }
}

///|
fn fixture_acceptance_draft_substitute_ops_for_test() -> Array[
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
fn fixture_acceptance_content_ops_contain_sequence_for_test(
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
fn fixture_acceptance_content_ops_contain_do_for_test(
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
fn fixture_acceptance_assert_cpdf_png_draft_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let image_name = fixture_acceptance_pdf_name_for_test("/I1")
  let pages = document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  guard document.lookup_direct(
      fixture_acceptance_pdf_name_for_test("/XObject"),
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
    fixture_acceptance_content_ops_contain_do_for_test(ops, image_name),
    false,
  )
  @test.assert_eq(
    fixture_acceptance_content_ops_contain_sequence_for_test(
      ops,
      fixture_acceptance_draft_substitute_ops_for_test(),
    ),
    true,
  )
  let images_json = document.images_json([1]).stringify()
  @test.assert_eq(images_json.contains("\"Name\""), false)
  @test.assert_eq(images_json.contains("\"Width\""), false)
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
fn fixture_acceptance_cpdf_font_entry_for_test(
  entries : ArrayView[@pdflite.PdfFontListEntry],
  basefont_fragment : String,
) -> @pdflite.PdfFontListEntry raise {
  for entry in entries {
    if entry.basefont.contains(basefont_fragment) {
      break entry
    }
  } nobreak {
    fail("missing cpdf manual font " + basefont_fragment)
  }
}

///|
fn fixture_acceptance_assert_cpdf_font_table_has_unicode_for_test(
  document : @pdflite.PdfDocument,
  font : @pdflite.PdfFontListEntry,
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
fn fixture_acceptance_assert_cpdf_embedded_font_for_test(
  document : @pdflite.PdfDocument,
  fonts : ArrayView[@pdflite.PdfFontListEntry],
  basefont_fragment : String,
) -> Unit raise {
  let font = fixture_acceptance_cpdf_font_entry_for_test(
    fonts, basefont_fragment,
  )
  @test.assert_eq(font.subtype, "/Type1")
  @test.assert_eq(font.encoding, "")
  match document.extract_fontfile_bytes(font.page, font.name) {
    Some(bytes) => @test.assert_eq(bytes.length() > 1000, true)
    None => fail("missing embedded fontfile for " + font.basefont)
  }
}

///|
fn fixture_acceptance_cpdf_missing_font_entry_for_test(
  entries : ArrayView[@pdflite.PdfMissingFontEntry],
  basefont_fragment : String,
) -> @pdflite.PdfMissingFontEntry raise {
  for entry in entries {
    if entry.basefont.contains(basefont_fragment) {
      break entry
    }
  } nobreak {
    fail("missing cpdf manual missing-font row " + basefont_fragment)
  }
}

///|
fn fixture_acceptance_assert_cpdf_no_missing_font_for_test(
  entries : ArrayView[@pdflite.PdfMissingFontEntry],
  basefont_fragment : String,
) -> Unit raise {
  for entry in entries {
    if entry.basefont.contains(basefont_fragment) {
      fail("unexpected missing font row " + basefont_fragment)
    }
  }
}

///|
fn fixture_acceptance_assert_cpdf_removed_embedded_font_for_test(
  document : @pdflite.PdfDocument,
  fonts : ArrayView[@pdflite.PdfFontListEntry],
  missing : ArrayView[@pdflite.PdfMissingFontEntry],
  basefont_fragment : String,
) -> Unit raise {
  let font = fixture_acceptance_cpdf_font_entry_for_test(
    fonts, basefont_fragment,
  )
  @test.assert_eq(font.subtype, "/Type1")
  @test.assert_eq(document.extract_fontfile_bytes(font.page, font.name), None)
  let missing_entry = fixture_acceptance_cpdf_missing_font_entry_for_test(
    missing, basefont_fragment,
  )
  @test.assert_eq(missing_entry.subtype, "/Type1")
  @test.assert_eq(missing_entry.encoding, "Built-in")
}

///|
fn fixture_acceptance_assert_cpdf_manual_extracted_image_for_test(
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
fn fixture_acceptance_assert_cpdf_manual_images_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let all_pages = document.parse_pagespec("")
  let images = document.images_json(all_pages)
  @test.assert_eq(@pdflite.pdf_image_images(false, document, all_pages), images)
  let images_json = images.stringify()
  fixture_acceptance_assert_contains_for_test(images_json, "\"Object\":1477")
  fixture_acceptance_assert_contains_for_test(images_json, "\"Pages\":[128]")
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
  fixture_acceptance_assert_contains_for_test(resolution_json, "\"Page\":128")
  fixture_acceptance_assert_contains_for_test(resolution_json, "\"W\":400")
  fixture_acceptance_assert_contains_for_test(resolution_json, "\"H\":294")
  @test.assert_eq(
    @pdflite.pdf_image_resolution_json_blob(
      false, document, all_pages, 1000000.0,
    ),
    document.image_resolution_json_blob(all_pages, 1000000.0),
  )
  fixture_acceptance_assert_cpdf_manual_extracted_image_for_test(document)
}

///|
fn fixture_acceptance_assert_cpdf_manual_embedded_fonts_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let all_pages = document.parse_pagespec("")
  let fonts = document.list_fonts(all_pages)
  @test.assert_eq(fonts.length() > 20, true)
  fixture_acceptance_assert_cpdf_embedded_font_for_test(
    document, fonts, "NimbusSanL-Bold",
  )
  fixture_acceptance_assert_cpdf_embedded_font_for_test(
    document, fonts, "URWPalladioL-Roma",
  )
  fixture_acceptance_assert_cpdf_embedded_font_for_test(
    document, fonts, "NimbusMonL-Regu",
  )
  let helvetica = fixture_acceptance_cpdf_font_entry_for_test(
    fonts, "/Helvetica",
  )
  @test.assert_eq(
    document.extract_fontfile_bytes(helvetica.page, helvetica.name),
    None,
  )
  fixture_acceptance_assert_cpdf_font_table_has_unicode_for_test(
    document, helvetica,
  )
  let missing = document.missing_fonts(all_pages)
  @test.assert_eq(missing.length(), 0)
  let fonts_json = document.fonts_json(all_pages).stringify()
  fixture_acceptance_assert_contains_for_test(fonts_json, "NimbusSanL-Bold")
  fixture_acceptance_assert_contains_for_test(fonts_json, "URWPalladioL-Roma")
  fixture_acceptance_assert_contains_for_test(fonts_json, "NimbusMonL-Regu")
  let missing_text = @ascii.decode_lossy(document.missing_fonts_text(all_pages))
  @test.assert_eq(missing_text, "")
}

///|
fn fixture_acceptance_assert_cpdf_manual_removed_embedded_fonts_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let all_pages = document.parse_pagespec("")
  let fonts = document.list_fonts(all_pages)
  @test.assert_eq(fonts.length() > 20, true)
  let missing = document.missing_fonts(all_pages)
  @test.assert_eq(missing.length() > 20, true)
  fixture_acceptance_assert_cpdf_removed_embedded_font_for_test(
    document, fonts, missing, "NimbusSanL-Bold",
  )
  fixture_acceptance_assert_cpdf_removed_embedded_font_for_test(
    document, fonts, missing, "URWPalladioL-Roma",
  )
  fixture_acceptance_assert_cpdf_removed_embedded_font_for_test(
    document, fonts, missing, "NimbusMonL-Regu",
  )
  let fonts_json = document.fonts_json(all_pages).stringify()
  fixture_acceptance_assert_contains_for_test(fonts_json, "NimbusSanL-Bold")
  fixture_acceptance_assert_contains_for_test(fonts_json, "URWPalladioL-Roma")
  fixture_acceptance_assert_contains_for_test(fonts_json, "NimbusMonL-Regu")
  let missing_text = @ascii.decode_lossy(document.missing_fonts_text(all_pages))
  fixture_acceptance_assert_contains_for_test(missing_text, "NimbusSanL-Bold")
  fixture_acceptance_assert_contains_for_test(missing_text, "URWPalladioL-Roma")
  fixture_acceptance_assert_contains_for_test(missing_text, "NimbusMonL-Regu")
}

///|
fn fixture_acceptance_assert_cpdf_source_hello_copied_font_for_test(
  document : @pdflite.PdfDocument,
  basefont_fragment : String,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
  let fonts = document.list_fonts([1])
  let copied = fixture_acceptance_cpdf_font_entry_for_test(
    fonts, basefont_fragment,
  )
  @test.assert_eq(copied.page, 1)
  @test.assert_eq(copied.name.contains(basefont_fragment), true)
  @test.assert_eq(copied.subtype, "/Type1")
  match document.extract_fontfile_bytes(copied.page, copied.name) {
    Some(bytes) => @test.assert_eq(bytes.length() > 1000, true)
    None => fail("missing copied fontfile for " + copied.basefont)
  }
  fixture_acceptance_assert_cpdf_no_missing_font_for_test(
    document.missing_fonts([1]),
    basefont_fragment,
  )
  let fonts_json = document.fonts_json([1]).stringify()
  fixture_acceptance_assert_contains_for_test(fonts_json, basefont_fragment)
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
fn fixture_acceptance_assert_cpdf_source_remove_clipping_for_test(
  original : @pdflite.PdfDocument,
  unclipped : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(original.endpage(), 1)
  @test.assert_eq(unclipped.endpage(), 1)
  let original_pages = original.pages_of_pagetree()
  let unclipped_pages = unclipped.pages_of_pagetree()
  @test.assert_eq(unclipped_pages[0].mediabox, original_pages[0].mediabox)
  @test.assert_eq(unclipped_pages[0].rotate, original_pages[0].rotate)
  @test.assert_eq(unclipped_pages[0].resources, original_pages[0].resources)
  @test.assert_eq(unclipped_pages[0].rest, original_pages[0].rest)
  let original_ops = fixture_acceptance_page_content_ops_for_test(original)
  let unclipped_ops = fixture_acceptance_page_content_ops_for_test(unclipped)
  @test.assert_eq(
    fixture_acceptance_content_clip_setup_count_for_test(original_ops) > 0,
    true,
  )
  @test.assert_eq(
    fixture_acceptance_content_clip_setup_count_for_test(unclipped_ops),
    0,
  )
  @test.assert_eq(
    fixture_acceptance_content_clip_op_count_for_test(unclipped_ops) <
    fixture_acceptance_content_clip_op_count_for_test(original_ops),
    true,
  )
  fixture_acceptance_assert_content_op_for_test(unclipped_ops, Op_n)
  fixture_acceptance_assert_content_op_for_test(unclipped_ops, Op_f)
  let content_json = unclipped.page_content_json([1]).stringify()
  fixture_acceptance_assert_contains_for_test(content_json, "\"page\":1")
  fixture_acceptance_assert_contains_for_test(content_json, "\"obj\":\"path\"")
  fixture_acceptance_assert_contains_for_test(content_json, "\"bbox\"")
}

///|
fn fixture_acceptance_assert_cpdf_source_reveal_hidden_text_for_test(
  original : @pdflite.PdfDocument,
  revealed : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(original.endpage(), 1)
  @test.assert_eq(revealed.endpage(), 1)
  let original_pages = original.pages_of_pagetree()
  let revealed_pages = revealed.pages_of_pagetree()
  @test.assert_eq(revealed_pages[0].mediabox, original_pages[0].mediabox)
  @test.assert_eq(revealed_pages[0].rotate, original_pages[0].rotate)
  @test.assert_eq(revealed_pages[0].resources, original_pages[0].resources)
  @test.assert_eq(revealed_pages[0].rest, original_pages[0].rest)
  let original_ops = fixture_acceptance_page_content_ops_for_test(original)
  let revealed_ops = fixture_acceptance_page_content_ops_for_test(revealed)
  @test.assert_eq(
    fixture_acceptance_content_text_rendering_mode_count_for_test(original_ops) >
    0,
    true,
  )
  @test.assert_eq(
    fixture_acceptance_content_text_rendering_mode_count_for_test(revealed_ops),
    0,
  )
  fixture_acceptance_assert_content_op_for_test(
    revealed_ops,
    Op_Tj(@ascii.encode("This is")),
  )
  fixture_acceptance_assert_content_op_for_test(
    revealed_ops,
    Op_Tj(@ascii.encode("on multiple")),
  )
  fixture_acceptance_assert_content_op_for_test(
    revealed_ops,
    Op_Tj(@ascii.encode("lines")),
  )
  let (glyphs, _, paths) = fixture_acceptance_assert_cpdf_manual_image_content_corpus_for_test(
    revealed,
  )
  @test.assert_eq(glyphs > 0, true)
  @test.assert_eq(paths > 0, true)
}

///|
fn fixture_acceptance_assert_cpdf_source_same_page_shape_for_test(
  original : @pdflite.PdfDocument,
  updated : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(original.endpage(), 1)
  @test.assert_eq(updated.endpage(), 1)
  let original_pages = original.pages_of_pagetree()
  let updated_pages = updated.pages_of_pagetree()
  @test.assert_eq(updated_pages[0].mediabox, original_pages[0].mediabox)
  @test.assert_eq(updated_pages[0].rotate, original_pages[0].rotate)
  @test.assert_eq(updated_pages[0].resources, original_pages[0].resources)
  @test.assert_eq(updated_pages[0].rest, original_pages[0].rest)
}

///|
fn fixture_acceptance_assert_cpdf_source_black_lines_for_test(
  original : @pdflite.PdfDocument,
  rewritten : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_same_page_shape_for_test(
    original, rewritten,
  )
  let original_ops = fixture_acceptance_page_content_ops_for_test(original)
  let rewritten_ops = fixture_acceptance_page_content_ops_for_test(rewritten)
  fixture_acceptance_assert_content_op_for_test(original_ops, Op_G(0.5))
  fixture_acceptance_assert_content_op_for_test(
    original_ops,
    Op_rg(0.2, 0.7, 0.2),
  )
  fixture_acceptance_assert_content_op_for_test(
    rewritten_ops,
    Op_RG(0.1, 0.2, 0.3),
  )
  fixture_acceptance_assert_no_content_op_for_test(rewritten_ops, Op_G(0.5))
  fixture_acceptance_assert_content_op_for_test(
    rewritten_ops,
    Op_rg(0.2, 0.7, 0.2),
  )
  fixture_acceptance_assert_content_op_for_test(rewritten_ops, Op_B)
}

///|
fn fixture_acceptance_assert_cpdf_source_black_fills_for_test(
  original : @pdflite.PdfDocument,
  rewritten : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_same_page_shape_for_test(
    original, rewritten,
  )
  let original_ops = fixture_acceptance_page_content_ops_for_test(original)
  let rewritten_ops = fixture_acceptance_page_content_ops_for_test(rewritten)
  fixture_acceptance_assert_content_op_for_test(original_ops, Op_G(0.5))
  fixture_acceptance_assert_content_op_for_test(
    original_ops,
    Op_rg(0.2, 0.7, 0.2),
  )
  fixture_acceptance_assert_content_op_for_test(rewritten_ops, Op_G(0.5))
  fixture_acceptance_assert_content_op_for_test(
    rewritten_ops,
    Op_rg(0.4, 0.5, 0.6),
  )
  fixture_acceptance_assert_no_content_op_for_test(
    rewritten_ops,
    Op_rg(0.2, 0.7, 0.2),
  )
  fixture_acceptance_assert_content_op_for_test(rewritten_ops, Op_B)
}

///|
fn fixture_acceptance_assert_cpdf_source_black_text_for_test(
  original : @pdflite.PdfDocument,
  rewritten : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_same_page_shape_for_test(
    original, rewritten,
  )
  let original_ops = fixture_acceptance_page_content_ops_for_test(original)
  let rewritten_ops = fixture_acceptance_page_content_ops_for_test(rewritten)
  fixture_acceptance_assert_content_op_for_test(original_ops, Op_BT)
  fixture_acceptance_assert_content_op_for_test(original_ops, Op_ET)
  fixture_acceptance_assert_content_op_for_test(
    original_ops,
    Op_Tj(@ascii.encode("Different ")),
  )
  fixture_acceptance_assert_no_content_op_for_test(original_ops, Op_g(0.0))
  fixture_acceptance_assert_content_op_for_test(rewritten_ops, Op_g(0.0))
  fixture_acceptance_assert_content_op_for_test(
    rewritten_ops,
    Op_Tj(@ascii.encode("Different ")),
  )
  fixture_acceptance_assert_content_op_for_test(
    rewritten_ops,
    Op_Tj(@ascii.encode("fonts")),
  )
  fixture_acceptance_assert_content_op_for_test(
    rewritten_ops,
    Op_Tj(@ascii.encode(" and sizes")),
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_thin_lines_for_test(
  original : @pdflite.PdfDocument,
  rewritten : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_same_page_shape_for_test(
    original, rewritten,
  )
  let original_ops = fixture_acceptance_page_content_ops_for_test(original)
  let rewritten_ops = fixture_acceptance_page_content_ops_for_test(rewritten)
  fixture_acceptance_assert_content_op_for_test(original_ops, Op_w(40.0))
  fixture_acceptance_assert_no_content_op_for_test(rewritten_ops, Op_w(40.0))
  @test.assert_eq(
    fixture_acceptance_content_op_count_for_test(rewritten_ops, Op_w(30.0)),
    2,
  )
  @test.assert_eq(rewritten_ops[0], Op_w(30.0))
  fixture_acceptance_assert_content_op_for_test(rewritten_ops, Op_S)
}

///|
fn fixture_acceptance_assert_cpdf_source_appended_content_for_test(
  original : @pdflite.PdfDocument,
  appended : @pdflite.PdfDocument,
) -> Unit raise {
  fixture_acceptance_assert_cpdf_source_same_page_shape_for_test(
    original, appended,
  )
  let ops = fixture_acceptance_page_content_ops_for_test(appended)
  @test.assert_eq(ops[0], Op_g(0.25))
  @test.assert_eq(ops[1], Op_re(10.0, 10.0, 20.0, 20.0))
  @test.assert_eq(ops[2], Op_f)
  fixture_acceptance_assert_content_op_for_test(
    ops,
    Op_Tj(@ascii.encode("Hello, World!")),
  )
  let text = @ascii.decode_lossy(appended.test_extract_text([1]))
  fixture_acceptance_assert_contains_for_test(text, "Hello, World!")
}

///|
fn fixture_acceptance_assert_cpdf_source_decompressed_streams_for_test(
  original : @pdflite.PdfDocument,
  decompressed : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(decompressed.endpage(), original.endpage())
  @test.assert_eq(
    fixture_acceptance_stream_count_for_test(decompressed),
    fixture_acceptance_stream_count_for_test(original),
  )
  @test.assert_eq(
    fixture_acceptance_filtered_stream_count_for_test(original) > 0,
    true,
  )
  @test.assert_eq(
    fixture_acceptance_filtered_stream_count_for_test(decompressed),
    0,
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_recompressed_streams_for_test(
  original : @pdflite.PdfDocument,
  recompressed : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(recompressed.endpage(), original.endpage())
  @test.assert_eq(
    fixture_acceptance_stream_count_for_test(recompressed),
    fixture_acceptance_stream_count_for_test(original),
  )
  @test.assert_eq(
    fixture_acceptance_filtered_stream_count_for_test(recompressed) <=
    fixture_acceptance_filtered_stream_count_for_test(original),
    true,
  )
}

///|
fn fixture_acceptance_assert_cpdf_source_squeeze_text_for_test(
  original : @pdflite.PdfDocument,
  squeezed : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(squeezed.endpage(), original.endpage())
  @test.assert_eq(
    fixture_acceptance_stream_count_for_test(squeezed) >=
    fixture_acceptance_stream_count_for_test(original),
    true,
  )
  fixture_acceptance_assert_cpdf_text_content_for_test(squeezed)
}

///|
fn fixture_acceptance_assert_cpdf_source_squeeze_xobject_for_test(
  original : @pdflite.PdfDocument,
  squeezed : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(squeezed.endpage(), original.endpage())
  @test.assert_eq(
    fixture_acceptance_stream_count_for_test(squeezed) >=
    fixture_acceptance_stream_count_for_test(original),
    true,
  )
  fixture_acceptance_assert_cpdf_xobject_content_for_test(squeezed)
}

///|
fn fixture_acceptance_assert_cpdf_source_bounding_boxes_for_test(
  original : @pdflite.PdfDocument,
  boxed : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(original.endpage(), 1)
  @test.assert_eq(boxed.endpage(), 1)
  let original_pages = original.pages_of_pagetree()
  let boxed_pages = boxed.pages_of_pagetree()
  @test.assert_eq(boxed_pages[0].mediabox, original_pages[0].mediabox)
  @test.assert_eq(boxed_pages[0].rotate, original_pages[0].rotate)
  @test.assert_eq(boxed_pages[0].resources, original_pages[0].resources)
  @test.assert_eq(boxed_pages[0].rest, original_pages[0].rest)
  let original_entries = original.content_entries_of_page(original_pages[0])
  @test.assert_eq(original_entries.length() > 0, true)
  let boxed_entries = boxed.content_entries_of_page(boxed_pages[0])
  @test.assert_eq(boxed_entries.length() >= original_entries.length() * 2, true)
  let original_ops = fixture_acceptance_page_content_ops_for_test(original)
  let boxed_ops = fixture_acceptance_page_content_ops_for_test(boxed)
  @test.assert_eq(boxed_ops.length() > original_ops.length(), true)
  @test.assert_eq(
    fixture_acceptance_content_stroke_count_for_test(boxed_ops) >=
    fixture_acceptance_content_stroke_count_for_test(original_ops) +
    original_entries.length(),
    true,
  )
  @test.assert_eq(
    fixture_acceptance_content_save_count_for_test(boxed_ops) >
    fixture_acceptance_content_save_count_for_test(original_ops),
    true,
  )
  let content_json = boxed.page_content_json([1]).stringify()
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
  @test.assert_eq(
    @pdflite.pdf_content_entries_of_page(document, pages[0]),
    entries,
  )
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
  let page_json = document.content_json_of_page(pages[0])
  @test.assert_eq(
    @pdflite.pdf_content_json_of_page(document, pages[0]),
    page_json,
  )
  let content_json = document.page_content_json([1])
  @test.assert_eq(@pdflite.pdf_page_content_json(document, [1]), content_json)
  let content_json_text = content_json.stringify()
  fixture_acceptance_assert_contains_for_test(content_json_text, "\"page\":1")
  fixture_acceptance_assert_contains_for_test(content_json_text, "\"bbox\"")
  (glyphs, images, paths)
}

///|
fn fixture_acceptance_assert_cpdf_manual_image_text_for_test(
  path : String,
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 1)
  let pages = [1]
  let extracted = document.test_extract_text(pages)
  @test.assert_eq(@pdflite.pdf_test_extract_text(document, pages), extracted)
  let text = @utf8.decode_lossy(extracted)
  @test.assert_eq(
    text,
    fixture_acceptance_cpdf_manual_image_expected_text_for_test(path),
  )
  @test.assert_eq(fixture_acceptance_replacement_count_for_test(text), 0)
  @test.assert_eq(fixture_acceptance_raw_control_count_for_test(text), 0)
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
async test "optional cpdf source logo fixture draws page marks" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/logo.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_logo_boxes_and_transparency_for_test(
        document,
      )
      let shown = document.show_page_boxes([1])
      fixture_acceptance_assert_cpdf_source_show_page_boxes_for_test(
        document, shown,
      )
      let shown_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        shown,
      )
      fixture_acceptance_assert_cpdf_source_show_page_boxes_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(shown_compressed),
      )
      fixture_acceptance_assert_cpdf_source_show_page_boxes_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            shown_compressed,
          ),
        ),
      )
      let trimmed = @pdflite.pdf_trim_marks(document, [1])
      fixture_acceptance_assert_cpdf_source_trim_marks_for_test(
        document, trimmed,
      )
      let trimmed_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        trimmed,
      )
      fixture_acceptance_assert_cpdf_source_trim_marks_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(trimmed_compressed),
      )
      fixture_acceptance_assert_cpdf_source_trim_marks_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            trimmed_compressed,
          ),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source fixtures stamp and combine pages" {
  match
    (
      fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf"),
      fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/logo.pdf"),
    ) {
    (Some(hello_bytes), Some(logo_bytes)) => {
      let hello = @pdflite.pdf_read_document_from_bytes(hello_bytes)
      let logo = @pdflite.pdf_read_document_from_bytes(logo_bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(hello)
      fixture_acceptance_assert_cpdf_logo_boxes_and_transparency_for_test(logo)
      let stamped = hello.stamp_pages(
        [1],
        logo,
        position=PdfPositionBottomLeft(10.0, 20.0),
      )
      fixture_acceptance_assert_cpdf_source_stamp_for_test(hello, stamped)
      let stamped_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        stamped,
      )
      fixture_acceptance_assert_cpdf_source_stamp_for_test(
        hello,
        @pdflite.pdf_read_document_from_bytes(stamped_compressed),
      )
      fixture_acceptance_assert_cpdf_source_stamp_for_test(
        hello,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            stamped_compressed,
          ),
        ),
      )
      let combined = @pdflite.pdf_combine_pages(hello, logo, scale_to_fit=true)
      fixture_acceptance_assert_cpdf_source_combine_for_test(hello, combined)
      let combined_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        combined,
      )
      fixture_acceptance_assert_cpdf_source_combine_for_test(
        hello,
        @pdflite.pdf_read_document_from_bytes(combined_compressed),
      )
      fixture_acceptance_assert_cpdf_source_combine_for_test(
        hello,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            combined_compressed,
          ),
        ),
      )
    }
    _ => ()
  }
}

///|
async test "optional cpdf source drawing fixtures preserve operator parameters" {
  let mut checked = 0
  for path in fixture_acceptance_cpdf_draw_operator_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        let document = @pdflite.pdf_read_document_from_bytes(bytes)
        fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
          path, document,
        )
        fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
          path,
          fixture_acceptance_reparse_compressed_for_test(document),
        )
        fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
          path,
          @pdflite.pdf_read_document_from_bytes(
            fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
          ),
        )
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      fixture_acceptance_cpdf_draw_operator_paths_for_test.length(),
    )
  }
}

///|
async test "optional cpdf source tweak fixtures remove clipping and reveal text" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/clip.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
        ".repos/cpdf-source/manualimages/clip.pdf", document,
      )
      let unclipped = @pdflite.pdf_remove_clipping(document, [1])
      fixture_acceptance_assert_cpdf_source_remove_clipping_for_test(
        document, unclipped,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        unclipped,
      )
      fixture_acceptance_assert_cpdf_source_remove_clipping_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_remove_clipping_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/textclip.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
        ".repos/cpdf-source/manualimages/textclip.pdf", document,
      )
      let revealed = document.reveal_hidden_text([1])
      fixture_acceptance_assert_cpdf_source_reveal_hidden_text_for_test(
        document, revealed,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        revealed,
      )
      fixture_acceptance_assert_cpdf_source_reveal_hidden_text_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_reveal_hidden_text_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source tweak fixtures recolor thin and append content" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/colfill.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
        ".repos/cpdf-source/manualimages/colfill.pdf", document,
      )
      let black_lines = @pdflite.pdf_black_lines(
        document,
        [1],
        PdfContentRGB(0.1, 0.2, 0.3),
      )
      fixture_acceptance_assert_cpdf_source_black_lines_for_test(
        document, black_lines,
      )
      fixture_acceptance_assert_cpdf_source_black_lines_for_test(
        document,
        fixture_acceptance_reparse_compressed_for_test(black_lines),
      )
      let black_fills = document.black_fills([1], PdfContentRGB(0.4, 0.5, 0.6))
      fixture_acceptance_assert_cpdf_source_black_fills_for_test(
        document, black_fills,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        black_fills,
      )
      fixture_acceptance_assert_cpdf_source_black_fills_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_black_fills_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/fontparams.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
        ".repos/cpdf-source/manualimages/fontparams.pdf", document,
      )
      let rewritten = @pdflite.pdf_black_text(
        document,
        [1],
        @pdflite.pdf_content_black,
      )
      fixture_acceptance_assert_cpdf_source_black_text_for_test(
        document, rewritten,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        rewritten,
      )
      fixture_acceptance_assert_cpdf_source_black_text_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_black_text_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/capjoins.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_draw_operator_fixture_for_test(
        ".repos/cpdf-source/manualimages/capjoins.pdf", document,
      )
      let rewritten = document.thin_lines([1], -30.0)
      fixture_acceptance_assert_cpdf_source_thin_lines_for_test(
        document, rewritten,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        rewritten,
      )
      fixture_acceptance_assert_cpdf_source_thin_lines_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_thin_lines_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let appended = @pdflite.pdf_append_page_content(
        document,
        [1],
        @ascii.encode("0.25 g 10 10 20 20 re f"),
        before=true,
      )
      fixture_acceptance_assert_cpdf_source_appended_content_for_test(
        document, appended,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        appended,
      )
      fixture_acceptance_assert_cpdf_source_appended_content_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_appended_content_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source attachments preserve real source payloads" {
  match
    (
      fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf"),
      fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/README.md"),
      fixture_acceptance_optional_bytes_for_test(
        ".repos/cpdf-source/Changes.txt",
      ),
    ) {
    (Some(pdf_bytes), Some(readme_payload), Some(changes_payload)) => {
      let document = @pdflite.pdf_read_document_from_bytes(pdf_bytes)
      let attached = document
        .attach_file(
          ".repos/cpdf-source/README.md",
          readme_payload,
          relationship=Some("Source"),
          description=Some("cpdf source README"),
        )
        .attach_file(
          ".repos/cpdf-source/Changes.txt",
          changes_payload,
          page_number=Some(1),
          relationship=Some("/Supplement"),
          description=Some("cpdf source changes"),
        )
      fixture_acceptance_assert_cpdf_source_attachments_for_test(
        attached, readme_payload, changes_payload,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        attached,
      )
      let compressed_document = @pdflite.pdf_read_document_from_bytes(
        compressed,
      )
      fixture_acceptance_assert_cpdf_source_attachments_for_test(
        compressed_document, readme_payload, changes_payload,
      )
      let recovered = @pdflite.pdf_read_document_from_bytes(
        fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
      )
      fixture_acceptance_assert_cpdf_source_attachments_for_test(
        recovered, readme_payload, changes_payload,
      )
      let cleaned = recovered.remove_attached_files()
      fixture_acceptance_assert_cpdf_source_attachments_removed_for_test(
        cleaned,
      )
      fixture_acceptance_assert_cpdf_source_attachments_removed_for_test(
        fixture_acceptance_reparse_compressed_for_test(cleaned),
      )
    }
    _ => ()
  }
}

///|
async test "optional cpdf source hello fixture chops CropBox-backed page" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let chopped = fixture_acceptance_chop_source_hello_for_test(document)
      fixture_acceptance_assert_cpdf_source_chop_for_test(chopped)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        chopped,
      )
      fixture_acceptance_assert_cpdf_source_chop_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_chop_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture applies page geometry transforms" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let transformed = fixture_acceptance_page_transform_source_hello_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_page_transform_for_test(transformed)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        transformed,
      )
      fixture_acceptance_assert_cpdf_source_page_transform_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_page_transform_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture pads blank page after source" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let padded = fixture_acceptance_pad_source_hello_for_test(document)
      fixture_acceptance_assert_cpdf_source_pad_for_test(padded)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        padded,
      )
      fixture_acceptance_assert_cpdf_source_pad_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_pad_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture preserves path redaction stub" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let expected_ops = fixture_acceptance_cpdf_source_hello_ops_for_test(
        document,
      )
      let original_pages = document.pages_of_pagetree()
      let redacted = @pdflite.pdf_redact(
        document,
        fixture_acceptance_cpdf_source_redact_path_for_test(),
        [1],
      )
      let redacted_pages = redacted.pages_of_pagetree()
      @test.assert_eq(redacted_pages[0].mediabox, original_pages[0].mediabox)
      @test.assert_eq(redacted_pages[0].rotate, original_pages[0].rotate)
      @test.assert_eq(redacted_pages[0].resources, original_pages[0].resources)
      @test.assert_eq(redacted_pages[0].rest, original_pages[0].rest)
      fixture_acceptance_assert_cpdf_source_redact_stub_for_test(
        redacted, expected_ops,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        redacted,
      )
      fixture_acceptance_assert_cpdf_source_redact_stub_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
        expected_ops,
      )
      fixture_acceptance_assert_cpdf_source_redact_stub_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
        expected_ops,
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture removes all text" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let stripped = @pdflite.pdf_remove_all_text(document, [1])
      fixture_acceptance_assert_cpdf_source_hello_text_removed_for_test(
        stripped,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        stripped,
      )
      fixture_acceptance_assert_cpdf_source_hello_text_removed_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_hello_text_removed_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture builds portfolio from real payloads" {
  match
    (
      fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf"),
      fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/README.md"),
      fixture_acceptance_optional_bytes_for_test(
        ".repos/cpdf-source/Changes.txt",
      ),
    ) {
    (Some(pdf_bytes), Some(readme_payload), Some(changes_payload)) => {
      let mod_date = @ascii.encode("D:20240102030405")
      let document = @pdflite.pdf_read_document_from_bytes(pdf_bytes)
      let portfolio = document.portfolio(
        [
          @pdflite.pdf_portfolio_entry(
            ".repos/cpdf-source/README.md",
            readme_payload,
            relationship=Some("Source"),
            description=Some("cpdf source README"),
          ),
          @pdflite.pdf_portfolio_entry(
            ".repos/cpdf-source/Changes.txt", changes_payload,
          ),
        ],
        mod_date=Some(mod_date),
      )
      fixture_acceptance_assert_cpdf_source_portfolio_for_test(
        portfolio, readme_payload, changes_payload, mod_date,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        portfolio,
      )
      fixture_acceptance_assert_cpdf_source_portfolio_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
        readme_payload,
        changes_payload,
        mod_date,
      )
      fixture_acceptance_assert_cpdf_source_portfolio_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
        readme_payload,
        changes_payload,
        mod_date,
      )
    }
    _ => ()
  }
}

///|
async test "optional cpdf source hello fixture removes JavaScript markers" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let (action_number, uri_number, stream_number) = fixture_acceptance_add_cpdf_source_javascript_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_javascript_for_test(
        document, action_number, uri_number, stream_number,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        document,
      )
      fixture_acceptance_assert_cpdf_source_javascript_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
        action_number,
        uri_number,
        stream_number,
      )
      let recovered = @pdflite.pdf_read_document_from_bytes(
        fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
      )
      fixture_acceptance_assert_cpdf_source_javascript_for_test(
        recovered, action_number, uri_number, stream_number,
      )
      @pdflite.pdf_remove_javascript(recovered)
      fixture_acceptance_assert_cpdf_source_javascript_removed_for_test(
        recovered, action_number, uri_number, stream_number,
      )
      fixture_acceptance_assert_cpdf_source_javascript_removed_for_test(
        fixture_acceptance_reparse_compressed_for_test(recovered),
        action_number,
        uri_number,
        stream_number,
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture lists injected spot colours" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      @test.assert_eq(document.list_spot_colours(), [])
      let with_spots = fixture_acceptance_cpdf_source_hello_with_spot_colours_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_spot_colours_for_test(with_spots)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_spots,
      )
      fixture_acceptance_assert_cpdf_source_spot_colours_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_spot_colours_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture roundtrips optional content groups" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      @test.assert_eq(try! document.read_optional_content_groups(), None)
      @test.assert_eq(try! document.ocg_get_list(), [])
      let witness_number = fixture_acceptance_add_cpdf_source_ocg_witness_for_test(
        document,
      )
      let with_ocg = try! document.write_optional_content_groups(
        fixture_acceptance_cpdf_source_ocg_content_for_test(),
      )
      fixture_acceptance_assert_cpdf_source_ocg_for_test(with_ocg)
      fixture_acceptance_assert_cpdf_source_ocg_for_test(
        fixture_acceptance_reparse_compressed_for_test(with_ocg),
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_ocg,
      )
      fixture_acceptance_assert_cpdf_source_ocg_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
      let replaced = try! @pdflite.pdf_ocg_replace_json(
        try! with_ocg.ocg_list_json(),
        @pdflite.pdf_read_document_from_bytes(bytes),
      )
      fixture_acceptance_assert_cpdf_source_ocg_for_test(replaced)
      let renamed = with_ocg.ocg_rename(
        fixture_acceptance_cpdf_source_ocg_layer_for_test("Source Layer"),
        fixture_acceptance_cpdf_source_ocg_layer_for_test("Renamed Layer"),
      )
      fixture_acceptance_assert_cpdf_source_ocg_renamed_for_test(renamed)
      fixture_acceptance_assert_cpdf_source_ocg_renamed_for_test(
        fixture_acceptance_reparse_compressed_for_test(renamed),
      )
      let wrapper_renamed = @pdflite.pdf_ocg_rename(
        fixture_acceptance_cpdf_source_ocg_layer_for_test("Source Layer"),
        fixture_acceptance_cpdf_source_ocg_layer_for_test("Renamed Layer"),
        with_ocg,
      )
      fixture_acceptance_assert_cpdf_source_ocg_renamed_for_test(
        wrapper_renamed,
      )
      let ordered = try! with_ocg.ocg_order_all()
      fixture_acceptance_assert_cpdf_source_ocg_ordered_for_test(ordered)
      fixture_acceptance_assert_cpdf_source_ocg_ordered_for_test(
        try! @pdflite.pdf_ocg_order_all(with_ocg),
      )
      fixture_acceptance_assert_cpdf_source_ocg_ordered_for_test(
        fixture_acceptance_reparse_compressed_for_test(ordered),
      )
      let coalesced = try! with_ocg.ocg_coalesce()
      fixture_acceptance_assert_cpdf_source_ocg_coalesced_for_test(
        coalesced, witness_number,
      )
      fixture_acceptance_assert_cpdf_source_ocg_coalesced_for_test(
        try! @pdflite.pdf_ocg_coalesce(with_ocg),
        witness_number,
      )
      fixture_acceptance_assert_cpdf_source_ocg_coalesced_for_test(
        fixture_acceptance_reparse_compressed_for_test(coalesced),
        witness_number,
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture preserves presentation transitions" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let updated = document.presentation(
        [1],
        Some("Split"),
        Some(2.0),
        true,
        false,
        90,
        1.25,
      )
      fixture_acceptance_assert_cpdf_source_presentation_for_test(updated)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        updated,
      )
      fixture_acceptance_assert_cpdf_source_presentation_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_presentation_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
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
async test "optional cpdf source hello fixture reports inline images" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      @test.assert_eq(document.images_json([1], inline=true).stringify(), "[]")
      let with_inline = fixture_acceptance_cpdf_source_hello_with_inline_image_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_inline_image_for_test(with_inline)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_inline,
      )
      fixture_acceptance_assert_cpdf_source_inline_image_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_inline_image_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture reports nested form images" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      @test.assert_eq(document.images_json([1]).stringify(), "[]")
      @test.assert_eq(document.image_resolution([1], 1000000.0), [])
      let with_form_image = fixture_acceptance_cpdf_source_hello_with_form_image_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_form_image_for_test(with_form_image)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_form_image,
      )
      fixture_acceptance_assert_cpdf_source_form_image_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_form_image_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture reads injected Type3 glyph programs" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_type3 = fixture_acceptance_cpdf_source_hello_with_type3_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_type3_for_test(with_type3)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_type3,
      )
      fixture_acceptance_assert_cpdf_source_type3_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_type3_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts ToUnicode variation text" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_variation = fixture_acceptance_cpdf_source_hello_with_variation_tounicode_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_variation_tounicode_for_test(
        with_variation,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_variation,
      )
      fixture_acceptance_assert_cpdf_source_variation_tounicode_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_variation_tounicode_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts UniAKR predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_uniakr_predefined_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_uniakr_predefined_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_uniakr_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_uniakr_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts UniKS predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_uniks_predefined_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_uniks_predefined_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_uniks_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_uniks_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts Korea1 vertical CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_korea1_vertical_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_korea1_vertical_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_korea1_vertical_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_korea1_vertical_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts Japan1 predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_japan1_predefined_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_japan1_predefined_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_japan1_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_japan1_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts Japan1 base predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_japan1_base_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_japan1_base_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_japan1_base_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_japan1_base_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts GB CNS predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_gb_cns_predefined_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_gb_cns_predefined_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_gb_cns_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_gb_cns_predefined_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts GB1 legacy predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_gb1_legacy_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_gb1_legacy_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_gb1_legacy_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_gb1_legacy_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts CNS1 legacy predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_cns1_legacy_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_cns1_legacy_cmaps_for_test(
        with_cmaps,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_cns1_legacy_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_cns1_legacy_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source hello fixture extracts vertical GB CNS predefined CMaps" {
  match
    fixture_acceptance_optional_bytes_for_test(".repos/cpdf-source/hello.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_source_hello_text_for_test(document)
      let with_cmaps = fixture_acceptance_cpdf_source_hello_with_vertical_cmaps_for_test(
        document,
      )
      fixture_acceptance_assert_cpdf_source_vertical_cmaps_for_test(with_cmaps)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_cmaps,
      )
      fixture_acceptance_assert_cpdf_source_vertical_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_vertical_cmaps_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source PNG image fixture drafts replacement boxes" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/png.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_png_image_for_test(document)
      let drafted = @pdflite.pdf_draft(None, true, [1], document)
      fixture_acceptance_assert_cpdf_png_draft_for_test(drafted)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        drafted,
      )
      fixture_acceptance_assert_cpdf_png_draft_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_png_draft_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
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
async test "optional cpdf source manual fixture reports embedded fonts" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_manual_embedded_fonts_for_test(document)
      fixture_acceptance_assert_cpdf_manual_embedded_fonts_for_test(
        fixture_acceptance_reparse_compressed_for_test(document),
      )
      fixture_acceptance_assert_cpdf_manual_embedded_fonts_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source font mutations remove and copy embedded fonts" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(manual_bytes) =>
      match
        fixture_acceptance_optional_bytes_for_test(
          ".repos/cpdf-source/hello.pdf",
        ) {
        None => ()
        Some(hello_bytes) => {
          let manual = @pdflite.pdf_read_document_from_bytes(manual_bytes)
          let removed = manual.remove_embedded_fonts()
          fixture_acceptance_assert_cpdf_manual_removed_embedded_fonts_for_test(
            removed,
          )
          fixture_acceptance_assert_cpdf_manual_removed_embedded_fonts_for_test(
            @pdflite.pdf_remove_fonts(manual),
          )
          fixture_acceptance_assert_cpdf_manual_removed_embedded_fonts_for_test(
            fixture_acceptance_reparse_compressed_for_test(removed),
          )
          let removed_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
            removed,
          )
          fixture_acceptance_assert_cpdf_manual_removed_embedded_fonts_for_test(
            @pdflite.pdf_read_document_from_bytes(
              fixture_acceptance_corrupt_startxref_pointer_for_test(
                removed_compressed,
              ),
            ),
          )
          let hello = @pdflite.pdf_read_document_from_bytes(hello_bytes)
          let source_font = fixture_acceptance_cpdf_font_entry_for_test(
            manual.list_fonts(manual.parse_pagespec("")),
            "NimbusSanL-Bold",
          )
          let copied = hello.copy_font_from(
            manual,
            source_font.name,
            source_font.page,
            [1],
          )
          fixture_acceptance_assert_cpdf_source_hello_copied_font_for_test(
            copied, "NimbusSanL-Bold",
          )
          fixture_acceptance_assert_cpdf_source_hello_copied_font_for_test(
            @pdflite.pdf_copy_font(
              manual,
              source_font.name,
              source_font.page,
              [1],
              hello,
            ),
            "NimbusSanL-Bold",
          )
          fixture_acceptance_assert_cpdf_source_hello_copied_font_for_test(
            fixture_acceptance_reparse_compressed_for_test(copied),
            "NimbusSanL-Bold",
          )
          let copied_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
            copied,
          )
          fixture_acceptance_assert_cpdf_source_hello_copied_font_for_test(
            @pdflite.pdf_read_document_from_bytes(
              fixture_acceptance_corrupt_startxref_pointer_for_test(
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
async test "optional cpdf source squeeze fixtures transcode streams" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/text.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_text_content_for_test(document)
      let decompressed = @pdflite.decompress_pdf(document)
      fixture_acceptance_assert_cpdf_source_decompressed_streams_for_test(
        document, decompressed,
      )
      fixture_acceptance_assert_cpdf_text_content_for_test(decompressed)
      let recompressed = decompressed.recompress()
      fixture_acceptance_assert_cpdf_source_recompressed_streams_for_test(
        document, recompressed,
      )
      fixture_acceptance_assert_cpdf_text_content_for_test(recompressed)
      let squeezed = document.squeeze()
      fixture_acceptance_assert_cpdf_source_squeeze_text_for_test(
        document, squeezed,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        squeezed,
      )
      fixture_acceptance_assert_cpdf_source_squeeze_text_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_squeeze_text_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
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
      let decompressed = document.decompress()
      fixture_acceptance_assert_cpdf_source_decompressed_streams_for_test(
        document, decompressed,
      )
      fixture_acceptance_assert_cpdf_xobject_content_for_test(decompressed)
      let recompressed = @pdflite.recompress_pdf(decompressed)
      fixture_acceptance_assert_cpdf_source_recompressed_streams_for_test(
        document, recompressed,
      )
      fixture_acceptance_assert_cpdf_xobject_content_for_test(recompressed)
      let squeezed = @pdflite.squeeze(document)
      fixture_acceptance_assert_cpdf_source_squeeze_xobject_for_test(
        document, squeezed,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        squeezed,
      )
      fixture_acceptance_assert_cpdf_source_squeeze_xobject_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      fixture_acceptance_assert_cpdf_source_squeeze_xobject_for_test(
        document,
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
        ),
      )
    }
  }
}

///|
async test "optional cpdf source manual fixtures show bounding box overlays" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/manualimages/text.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      fixture_acceptance_assert_cpdf_text_content_for_test(document)
      let boxed = document.show_bounding_boxes([1])
      fixture_acceptance_assert_cpdf_text_content_for_test(boxed)
      fixture_acceptance_assert_cpdf_source_bounding_boxes_for_test(
        document, boxed,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        boxed,
      )
      let reparsed = @pdflite.pdf_read_document_from_bytes(compressed)
      fixture_acceptance_assert_cpdf_text_content_for_test(reparsed)
      fixture_acceptance_assert_cpdf_source_bounding_boxes_for_test(
        document, reparsed,
      )
      let recovered = @pdflite.pdf_read_document_from_bytes(
        fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
      )
      fixture_acceptance_assert_cpdf_text_content_for_test(recovered)
      fixture_acceptance_assert_cpdf_source_bounding_boxes_for_test(
        document, recovered,
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
      let boxed = @pdflite.pdf_show_bounding_boxes(
        document,
        [1],
        light=true,
        fast=true,
      )
      fixture_acceptance_assert_cpdf_xobject_content_for_test(boxed)
      fixture_acceptance_assert_cpdf_source_bounding_boxes_for_test(
        document, boxed,
      )
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        boxed,
      )
      let reparsed = @pdflite.pdf_read_document_from_bytes(compressed)
      fixture_acceptance_assert_cpdf_xobject_content_for_test(reparsed)
      fixture_acceptance_assert_cpdf_source_bounding_boxes_for_test(
        document, reparsed,
      )
      let recovered = @pdflite.pdf_read_document_from_bytes(
        fixture_acceptance_corrupt_startxref_pointer_for_test(compressed),
      )
      fixture_acceptance_assert_cpdf_xobject_content_for_test(recovered)
      fixture_acceptance_assert_cpdf_source_bounding_boxes_for_test(
        document, recovered,
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
        let (expected_glyphs, expected_images, expected_paths) = fixture_acceptance_cpdf_manual_image_expected_content_counts_for_test(
          path,
        )
        @test.assert_eq(doc_glyphs, expected_glyphs)
        @test.assert_eq(doc_images, expected_images)
        @test.assert_eq(doc_paths, expected_paths)
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
    @test.assert_eq(glyphs, 476)
    @test.assert_eq(images, 1)
    @test.assert_eq(paths, 18)
  }
}

///|
async test "optional cpdf source manual image text fixtures extract exact text" {
  let mut checked = 0
  for path in fixture_acceptance_cpdf_manual_image_text_paths_for_test {
    match fixture_acceptance_optional_bytes_for_test(path) {
      None => ()
      Some(bytes) => {
        checked += 1
        let document = @pdflite.pdf_read_document_from_bytes(bytes)
        fixture_acceptance_assert_cpdf_manual_image_text_for_test(
          path, document,
        )
        fixture_acceptance_assert_cpdf_manual_image_text_for_test(
          path,
          fixture_acceptance_reparse_compressed_for_test(document),
        )
        fixture_acceptance_assert_cpdf_manual_image_text_for_test(
          path,
          @pdflite.pdf_read_document_from_bytes(
            fixture_acceptance_corrupt_startxref_pointer_for_test(bytes),
          ),
        )
      }
    }
  }
  if checked > 0 {
    @test.assert_eq(
      checked,
      fixture_acceptance_cpdf_manual_image_text_paths_for_test.length(),
    )
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
async test "optional cpdf source manual fixture mutates metadata" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      @test.assert_eq(document.metadata(), None)
      let title = @pdflite.pdf_pdfdocstring_of_utf8(
        @utf8.encode("cpdf source & metadata"),
      )
      let author = @pdflite.pdf_pdfdocstring_of_utf8(
        @utf8.encode("MoonBit port"),
      )
      let updated = document
        .create_metadata()
        .set_language(@ascii.encode("en-GB"))
        .set_info_entry(
          fixture_acceptance_pdf_name_for_test("/Title"),
          PdfString(title),
          4,
          keep_version=true,
          xmp_also=true,
        )
        .set_info_entry(
          fixture_acceptance_pdf_name_for_test("/Author"),
          PdfString(author),
          4,
          keep_version=true,
          xmp_also=true,
        )
      fixture_acceptance_assert_cpdf_manual_metadata_for_test(updated)
      fixture_acceptance_assert_cpdf_manual_metadata_for_test(
        fixture_acceptance_reparse_compressed_for_test(updated),
      )
      let corrupt_startxref_bytes = fixture_acceptance_corrupt_startxref_pointer_for_test(
        @pdflite.pdf_write_document_with_compressed_xref_stream(updated),
      )
      fixture_acceptance_assert_cpdf_manual_metadata_for_test(
        @pdflite.pdf_read_document_from_bytes(corrupt_startxref_bytes),
      )
      let removed = updated.remove_all_metadata()
      fixture_acceptance_assert_cpdf_manual_metadata_removed_for_test(removed)
      fixture_acceptance_assert_cpdf_manual_metadata_removed_for_test(
        fixture_acceptance_reparse_compressed_for_test(removed),
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
async test "optional cpdf source manual fixture mutates bookmark open state and title" {
  match
    fixture_acceptance_optional_bytes_for_test(
      ".repos/cpdf-source/cpdfmanual.pdf",
    ) {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let opened = try! document.bookmarks_open_to_level(1)
      fixture_acceptance_assert_cpdf_manual_bookmarks_open_to_level_for_test(
        opened,
      )
      fixture_acceptance_assert_cpdf_manual_bookmarks_open_to_level_for_test(
        try! @pdflite.pdf_bookmarks_open_to_level(1, document),
      )
      fixture_acceptance_assert_cpdf_manual_bookmarks_open_to_level_for_test(
        fixture_acceptance_reparse_compressed_for_test(opened),
      )
      let opened_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        opened,
      )
      fixture_acceptance_assert_cpdf_manual_bookmarks_open_to_level_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            opened_compressed,
          ),
        ),
      )
      let titled = try! document.add_bookmark_title(
        "/tmp/cpdfmanual.pdf", false,
      )
      fixture_acceptance_assert_cpdf_manual_title_bookmark_for_test(titled)
      fixture_acceptance_assert_cpdf_manual_title_bookmark_for_test(
        try! @pdflite.pdf_add_bookmark_title(
          "/tmp/cpdfmanual.pdf", false, document,
        ),
      )
      fixture_acceptance_assert_cpdf_manual_title_bookmark_for_test(
        fixture_acceptance_reparse_compressed_for_test(titled),
      )
      let titled_compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        titled,
      )
      fixture_acceptance_assert_cpdf_manual_title_bookmark_for_test(
        @pdflite.pdf_read_document_from_bytes(
          fixture_acceptance_corrupt_startxref_pointer_for_test(
            titled_compressed,
          ),
        ),
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
