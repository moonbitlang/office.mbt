///|
fn text_fixture_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
async fn text_fixture_bytes_for_test(path : String) -> Bytes? {
  let read_result = try? @fs.read_file(text_fixture_path_for_test(path))
  match read_result {
    Ok(data) => Some(data.binary())
    Err(_) => None
  }
}

///|
fn text_fixture_bytes_start_with_at_for_test(
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
fn text_fixture_find_last_bytes_for_test(
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
      if text_fixture_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn text_fixture_push_ascii_for_test(
  output : Array[Byte],
  text : String,
) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn text_fixture_corrupt_startxref_pointer_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let marker = @ascii.encode("startxref")
  let marker_position = text_fixture_find_last_bytes_for_test(bytes, marker)
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
  text_fixture_push_ascii_for_test(output, (bytes.length() + 4096).to_string())
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn text_fixture_reparse_compressed_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  @pdflite.pdf_read_document_from_bytes(
    @pdflite.pdf_write_document_with_compressed_xref_stream(document),
  )
}

///|
fn text_fixture_assert_contains_for_test(
  text : String,
  fragment : String,
) -> Unit raise {
  @test.assert_eq(text.contains(fragment), true, msg="missing " + fragment)
}

///|
fn text_fixture_replacement_count_for_test(text : String) -> Int {
  let mut count = 0
  for char in text {
    if char.to_int() == 0xFFFD {
      count += 1
    }
  }
  count
}

///|
fn text_fixture_raw_control_count_for_test(text : String) -> Int {
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
fn text_fixture_assert_cpdf_manual_text_extraction_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let selected_pages : ReadOnlyArray[Int] = [1, 2, 19, 31, 33]
  let extracted = document.test_extract_text(selected_pages)
  @test.assert_eq(
    @pdflite.pdf_test_extract_text(document, selected_pages),
    extracted,
  )
  let text = @utf8.decode_lossy(extracted)
  text_fixture_assert_contains_for_test(text, "CoherentPDF")
  text_fixture_assert_contains_for_test(text, "©CoherentGraphicsLimited")
  text_fixture_assert_contains_for_test(text, "PDFAssociation")
  text_fixture_assert_contains_for_test(text, "CommandLineTools")
  text_fixture_assert_contains_for_test(text, "Chapter1BasicUsage")
  text_fixture_assert_contains_for_test(text, "Chapter2MergingandSplitting")
  text_fixture_assert_contains_for_test(text, "SplittingonBookmarks")
  @test.assert_eq(text.length() > 2000, true)
  @test.assert_eq(text_fixture_replacement_count_for_test(text), 0)
  @test.assert_eq(text_fixture_raw_control_count_for_test(text), 0)
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
  text_fixture_assert_contains_for_test(glyph_text, "©CoherentGraphicsLimited")
  @test.assert_eq(text_fixture_replacement_count_for_test(glyph_text), 0)
  @test.assert_eq(text_fixture_raw_control_count_for_test(glyph_text), 0)
  let content_json = document.page_content_json([2])
  @test.assert_eq(@pdflite.pdf_page_content_json(document, [2]), content_json)
  let content_json_text = content_json.stringify()
  text_fixture_assert_contains_for_test(content_json_text, "\"page\":2")
  text_fixture_assert_contains_for_test(content_json_text, "\"obj\":\"glyph\"")
  text_fixture_assert_contains_for_test(content_json_text, "\"extracted text\"")
}

///|
async test "cpdf source manual fixture extracts selected text" {
  match text_fixture_bytes_for_test("fixtures/cpdf-source/cpdfmanual.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      text_fixture_assert_cpdf_manual_text_extraction_for_test(document)
      text_fixture_assert_cpdf_manual_text_extraction_for_test(
        text_fixture_reparse_compressed_for_test(document),
      )
      text_fixture_assert_cpdf_manual_text_extraction_for_test(
        @pdflite.pdf_read_document_from_bytes(
          text_fixture_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
  }
}
