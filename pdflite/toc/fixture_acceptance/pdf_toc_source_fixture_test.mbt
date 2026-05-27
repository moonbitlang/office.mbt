///|
fn toc_fixture_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
async fn toc_fixture_bytes_for_test(path : String) -> Bytes? {
  let read_result = try? @fs.read_file(toc_fixture_path_for_test(path))
  match read_result {
    Ok(data) => Some(data.binary())
    Err(_) => None
  }
}

///|
fn toc_fixture_bytes_start_with_at_for_test(
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
fn toc_fixture_find_last_bytes_for_test(
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
      if toc_fixture_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn toc_fixture_push_ascii_for_test(output : Array[Byte], text : String) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn toc_fixture_corrupt_startxref_pointer_for_test(bytes : Bytes) -> Bytes raise {
  let marker = @ascii.encode("startxref")
  let marker_position = toc_fixture_find_last_bytes_for_test(bytes, marker)
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
  toc_fixture_push_ascii_for_test(output, (bytes.length() + 4096).to_string())
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn toc_fixture_reparse_compressed_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  @pdflite.pdf_read_document_from_bytes(
    @pdflite.pdf_write_document_with_compressed_xref_stream(document),
  )
}

///|
fn toc_fixture_reparse_bad_final_startxref_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  @pdflite.pdf_read_document_from_bytes(
    toc_fixture_corrupt_startxref_pointer_for_test(
      @pdflite.pdf_write_document_with_compressed_xref_stream(document),
    ),
  )
}

///|
fn toc_fixture_fontpack_for_test() -> @pdflite.PdfFontPack raise {
  @pdflite.pdf_fontpack_of_standard_font(
    PdfFontStandard({ font: PdfHelvetica, encoding: PdfWinAnsiEncoding }),
  )
}

///|
fn toc_fixture_type_text_contains_for_test(
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
fn toc_fixture_type_dest_contains_for_test(
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
fn toc_fixture_assert_page_for_test(
  document : @pdflite.PdfDocument,
  bookmark : @pdflite.PdfBookmark,
  page_number : Int,
) -> Unit raise {
  @test.assert_eq(document.page_number_of_target(bookmark.target), page_number)
  @test.assert_eq(
    @pdflite.pdf_pagenumber_of_target(document, bookmark.target),
    page_number,
  )
}

///|
fn toc_fixture_assert_cpdf_manual_toc_bookmark_for_test(
  document : @pdflite.PdfDocument,
  expected_original_first_page : Int,
) -> Unit raise {
  let bookmarks = document.read_bookmarks(preserve_actions=true)
  @test.assert_eq(
    @pdflite.pdf_read_bookmarks(document, preserve_actions=true),
    bookmarks,
  )
  @test.assert_eq(bookmarks.length(), 164)
  @test.assert_eq(
    bookmarks[0].text,
    @pdflite.pdf_toc_bookmark_text(@ascii.encode("Contents\\nGenerated")),
  )
  toc_fixture_assert_page_for_test(document, bookmarks[0], 1)
  @test.assert_eq(bookmarks[1].text.length() > 0, true)
  toc_fixture_assert_page_for_test(
    document,
    bookmarks[1],
    expected_original_first_page,
  )
}

///|
fn toc_fixture_assert_cpdf_manual_toc_elements_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let original_bookmarks = document.read_bookmarks(preserve_actions=true)
  @test.assert_eq(
    @pdflite.pdf_read_bookmarks(document, preserve_actions=true),
    original_bookmarks,
  )
  @test.assert_eq(original_bookmarks.length(), 163)
  let title = @ascii.encode("Contents\\nGenerated")
  let pack = toc_fixture_fontpack_for_test()
  let toc_bookmarks : ReadOnlyArray[@pdflite.PdfBookmark] = [
    original_bookmarks[0],
    original_bookmarks[21],
    original_bookmarks[25],
  ]
  let used = document.toc_used_codepoints([], title, toc_bookmarks)
  @test.assert_eq(
    @pdflite.pdf_toc_used_codepoints(document, [], title, toc_bookmarks),
    used,
  )
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
    @pdflite.pdf_toc_type_elements(
      document,
      pack,
      9.0,
      title,
      true,
      false,
      [],
      toc_bookmarks,
      540.0,
      54.0,
    ),
    elements,
  )
  @test.assert_eq(
    toc_fixture_type_text_contains_for_test(elements, "Contents"),
    true,
  )
  @test.assert_eq(
    toc_fixture_type_text_contains_for_test(elements, "Basic"),
    true,
  )
  @test.assert_eq(
    toc_fixture_type_text_contains_for_test(elements, "Usage"),
    true,
  )
  @test.assert_eq(toc_fixture_type_text_contains_for_test(elements, "31"), true)
  @test.assert_eq(toc_fixture_type_text_contains_for_test(elements, "."), true)
  @test.assert_eq(
    toc_fixture_type_dest_contains_for_test(elements, "Basic"),
    true,
  )
  @test.assert_eq(
    toc_fixture_type_dest_contains_for_test(elements, "Merging"),
    true,
  )

  let updated = document.toc_add_bookmark(title)
  toc_fixture_assert_cpdf_manual_toc_bookmark_for_test(updated, 19)
  toc_fixture_assert_cpdf_manual_toc_bookmark_for_test(
    @pdflite.pdf_toc_add_bookmark(document, title),
    19,
  )
}

///|
async test "cpdf source manual fixture builds table of contents" {
  match toc_fixture_bytes_for_test(".repos/cpdf-source/cpdfmanual.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      toc_fixture_assert_cpdf_manual_toc_elements_for_test(document)
      toc_fixture_assert_cpdf_manual_toc_elements_for_test(
        toc_fixture_reparse_compressed_for_test(document),
      )
      let bookmarked = document.toc_add_bookmark(
        @ascii.encode("Contents\\nGenerated"),
      )
      toc_fixture_assert_cpdf_manual_toc_bookmark_for_test(bookmarked, 19)
      toc_fixture_assert_cpdf_manual_toc_bookmark_for_test(
        toc_fixture_reparse_compressed_for_test(bookmarked),
        19,
      )
      toc_fixture_assert_cpdf_manual_toc_bookmark_for_test(
        toc_fixture_reparse_bad_final_startxref_for_test(bookmarked),
        19,
      )
    }
  }
}
