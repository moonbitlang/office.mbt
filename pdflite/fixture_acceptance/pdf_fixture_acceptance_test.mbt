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
fn fixture_acceptance_reparse_compressed_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  @pdflite.pdf_read_document_from_bytes(
    @pdflite.pdf_write_document_with_compressed_xref_stream(document),
  )
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
async test "checked-in CamlPDF introduction fixture reconstructs xref stream bad startxref" {
  fixture_acceptance_assert_reconstructs_for_test(
    fixture_acceptance_bytes_for_test(
      "fixtures/camlpdf/introduction_to_camlpdf.pdf",
    ),
    10,
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
