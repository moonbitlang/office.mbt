///|
fn bookmark_fixture_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
async fn bookmark_fixture_bytes_for_test(path : String) -> Bytes? {
  let read_result = try? @fs.read_file(bookmark_fixture_path_for_test(path))
  match read_result {
    Ok(data) => Some(data.binary())
    Err(_) => None
  }
}

///|
fn bookmark_fixture_bytes_start_with_at_for_test(
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
fn bookmark_fixture_find_last_bytes_for_test(
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
      if bookmark_fixture_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn bookmark_fixture_push_ascii_for_test(
  output : Array[Byte],
  text : String,
) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn bookmark_fixture_corrupt_startxref_pointer_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let marker = @ascii.encode("startxref")
  let marker_position = bookmark_fixture_find_last_bytes_for_test(bytes, marker)
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
  bookmark_fixture_push_ascii_for_test(
    output,
    (bytes.length() + 4096).to_string(),
  )
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn bookmark_fixture_reparse_compressed_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  @pdflite.pdf_read_document_from_bytes(
    @pdflite.pdf_write_document_with_compressed_xref_stream(document),
  )
}

///|
fn bookmark_fixture_reparse_bad_final_startxref_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  @pdflite.pdf_read_document_from_bytes(
    bookmark_fixture_corrupt_startxref_pointer_for_test(
      @pdflite.pdf_write_document_with_compressed_xref_stream(document),
    ),
  )
}

///|
fn bookmark_fixture_assert_contains_for_test(
  text : String,
  fragment : String,
) -> Unit raise {
  @test.assert_eq(text.contains(fragment), true, msg="missing " + fragment)
}

///|
fn bookmark_fixture_title_for_test(
  bookmark : @pdflite.PdfBookmark,
) -> String raise {
  @utf8.decode_lossy(@pdflite.pdf_utf8_of_pdfdocstring(bookmark.text))
}

///|
fn bookmark_fixture_assert_page_for_test(
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
fn bookmark_fixture_assert_cpdf_manual_bookmarks_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let bookmarks = document.read_bookmarks(preserve_actions=true)
  @test.assert_eq(
    @pdflite.pdf_read_bookmarks(document, preserve_actions=true),
    bookmarks,
  )
  @test.assert_eq(bookmarks.length(), 163)
  @test.assert_eq(bookmarks[0].level, 0)
  bookmark_fixture_assert_page_for_test(document, bookmarks[0], 19)
  @test.assert_eq(bookmarks[21].level, 0)
  bookmark_fixture_assert_page_for_test(document, bookmarks[21], 31)
  let bookmarks_json = document.bookmarks_json(json_preserve_actions=true)
  @test.assert_eq(
    @pdflite.pdf_get_bookmarks_json(true, document),
    document.bookmarks_json_blob(json_preserve_actions=true),
  )
  let bookmarks_json_text = bookmarks_json.stringify()
  bookmark_fixture_assert_contains_for_test(
    bookmarks_json_text, "\"text\":\"1 Basic Usage\"",
  )
  bookmark_fixture_assert_contains_for_test(
    bookmarks_json_text, "\"text\":\"2 Merging and Splitting\"",
  )
  bookmark_fixture_assert_contains_for_test(
    bookmarks_json_text, "\"text\":\"6 Bookmarks\"",
  )
  bookmark_fixture_assert_contains_for_test(bookmarks_json_text, "\"page\":19")
  let bookmarks_blob = @utf8.decode_lossy(
    document.bookmarks_json_blob(json_preserve_actions=true),
  )
  bookmark_fixture_assert_contains_for_test(
    bookmarks_blob, "\"text\":\"1 Basic Usage\"",
  )
  let listed_bytes = document.list_bookmarks(
    [19, 31, 33],
    encoding=PdfMetadataUTF8,
  )
  @test.assert_eq(
    @pdflite.pdf_list_bookmarks(
      false,
      false,
      PdfMetadataUTF8,
      [19, 31, 33],
      document,
    ),
    listed_bytes,
  )
  let listed = @utf8.decode_lossy(listed_bytes)
  bookmark_fixture_assert_contains_for_test(listed, "0 \"1 Basic Usage\" 19")
  bookmark_fixture_assert_contains_for_test(
    listed, "0 \"2 Merging and Splitting\" 31",
  )
  bookmark_fixture_assert_contains_for_test(
    listed, "1 \"2.4 Splitting on Bookmarks\" 33",
  )
}

///|
fn bookmark_fixture_assert_cpdf_manual_bookmarks_open_to_level_for_test(
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
  bookmark_fixture_assert_page_for_test(document, bookmarks[0], 19)
  @test.assert_eq(bookmarks[0].is_open, true)
  @test.assert_eq(bookmarks[21].level, 0)
  bookmark_fixture_assert_page_for_test(document, bookmarks[21], 31)
  @test.assert_eq(bookmarks[21].is_open, true)
  let bookmarks_json = document
    .bookmarks_json(json_preserve_actions=true)
    .stringify()
  bookmark_fixture_assert_contains_for_test(
    bookmarks_json, "\"text\":\"1 Basic Usage\"",
  )
  bookmark_fixture_assert_contains_for_test(bookmarks_json, "\"open\":true")
  bookmark_fixture_assert_contains_for_test(bookmarks_json, "\"open\":false")
  let listed = @utf8.decode_lossy(
    document.list_bookmarks([19, 31, 33], encoding=PdfMetadataUTF8),
  )
  bookmark_fixture_assert_contains_for_test(
    listed, "0 \"1 Basic Usage\" 19 open \"",
  )
  bookmark_fixture_assert_contains_for_test(
    listed, "0 \"2 Merging and Splitting\" 31 open \"",
  )
  bookmark_fixture_assert_contains_for_test(
    listed, "1 \"2.4 Splitting on Bookmarks\" 33 \"",
  )
}

///|
fn bookmark_fixture_assert_cpdf_manual_title_bookmark_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let bookmarks = document.read_bookmarks(preserve_actions=true)
  @test.assert_eq(bookmarks.length(), 164)
  @test.assert_eq(bookmarks[0].level, 0)
  @test.assert_eq(
    bookmark_fixture_title_for_test(bookmarks[0]),
    "cpdfmanual.pdf",
  )
  bookmark_fixture_assert_page_for_test(document, bookmarks[0], 1)
  @test.assert_eq(bookmarks[0].is_open, false)
  @test.assert_eq(bookmarks[0].colour, @pdflite.pdf_bookmark_black)
  @test.assert_eq(bookmarks[0].flags, 0)
  @test.assert_eq(bookmarks[1].level, 1)
  @test.assert_eq(
    bookmark_fixture_title_for_test(bookmarks[1]),
    "1 Basic Usage",
  )
  bookmark_fixture_assert_page_for_test(document, bookmarks[1], 19)
  @test.assert_eq(bookmarks[22].level, 1)
  bookmark_fixture_assert_page_for_test(document, bookmarks[22], 31)
  for index in 1..<bookmarks.length() {
    @test.assert_eq(bookmarks[index].level >= 1, true)
  }
  let bookmarks_json = document
    .bookmarks_json(json_preserve_actions=true)
    .stringify()
  bookmark_fixture_assert_contains_for_test(
    bookmarks_json, "\"text\":\"cpdfmanual.pdf\"",
  )
  bookmark_fixture_assert_contains_for_test(bookmarks_json, "\"page\":1")
  bookmark_fixture_assert_contains_for_test(
    bookmarks_json, "\"text\":\"1 Basic Usage\"",
  )
  let listed = @utf8.decode_lossy(
    document.list_bookmarks([1, 19, 31, 33], encoding=PdfMetadataUTF8),
  )
  bookmark_fixture_assert_contains_for_test(listed, "0 \"cpdfmanual.pdf\" 1 \"")
  bookmark_fixture_assert_contains_for_test(listed, "1 \"1 Basic Usage\" 19")
  bookmark_fixture_assert_contains_for_test(
    listed, "1 \"2 Merging and Splitting\" 31",
  )
}

///|
async test "cpdf source manual fixture lists and rebuilds bookmarks" {
  match bookmark_fixture_bytes_for_test(".repos/cpdf-source/cpdfmanual.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      bookmark_fixture_assert_cpdf_manual_bookmarks_for_test(document)
      bookmark_fixture_assert_cpdf_manual_bookmarks_for_test(
        bookmark_fixture_reparse_compressed_for_test(document),
      )
      let rebuilt = @pdflite.pdf_add_bookmarks(
        document.read_bookmarks(preserve_actions=true),
        @pdflite.pdf_remove_bookmarks(document),
      )
      bookmark_fixture_assert_cpdf_manual_bookmarks_for_test(rebuilt)
      bookmark_fixture_assert_cpdf_manual_bookmarks_for_test(
        bookmark_fixture_reparse_compressed_for_test(rebuilt),
      )
    }
  }
}

///|
async test "cpdf source manual fixture mutates bookmark open state and title" {
  match bookmark_fixture_bytes_for_test(".repos/cpdf-source/cpdfmanual.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let opened = document.bookmarks_open_to_level(1)
      bookmark_fixture_assert_cpdf_manual_bookmarks_open_to_level_for_test(
        opened,
      )
      bookmark_fixture_assert_cpdf_manual_bookmarks_open_to_level_for_test(
        @pdflite.pdf_bookmarks_open_to_level(1, document),
      )
      bookmark_fixture_assert_cpdf_manual_bookmarks_open_to_level_for_test(
        bookmark_fixture_reparse_compressed_for_test(opened),
      )
      bookmark_fixture_assert_cpdf_manual_bookmarks_open_to_level_for_test(
        bookmark_fixture_reparse_bad_final_startxref_for_test(opened),
      )
      let titled = document.add_bookmark_title("/tmp/cpdfmanual.pdf", false)
      bookmark_fixture_assert_cpdf_manual_title_bookmark_for_test(titled)
      bookmark_fixture_assert_cpdf_manual_title_bookmark_for_test(
        @pdflite.pdf_add_bookmark_title("/tmp/cpdfmanual.pdf", false, document),
      )
      bookmark_fixture_assert_cpdf_manual_title_bookmark_for_test(
        bookmark_fixture_reparse_compressed_for_test(titled),
      )
      bookmark_fixture_assert_cpdf_manual_title_bookmark_for_test(
        bookmark_fixture_reparse_bad_final_startxref_for_test(titled),
      )
    }
  }
}
