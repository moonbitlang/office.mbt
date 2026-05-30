///|
fn page_fixture_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
async fn page_fixture_bytes_for_test(path : String) -> Bytes? {
  let read_result = try? @fs.read_file(page_fixture_path_for_test(path))
  match read_result {
    Ok(data) => Some(data.binary())
    Err(_) => None
  }
}

///|
fn page_fixture_bytes_start_with_at_for_test(
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
fn page_fixture_find_last_bytes_for_test(
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
      if page_fixture_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn page_fixture_push_ascii_for_test(
  output : Array[Byte],
  text : String,
) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn page_fixture_corrupt_startxref_pointer_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let marker = @ascii.encode("startxref")
  let marker_position = page_fixture_find_last_bytes_for_test(bytes, marker)
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
  page_fixture_push_ascii_for_test(output, (bytes.length() + 4096).to_string())
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn page_fixture_reparse_compressed_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  @pdflite.pdf_read_document_from_bytes(
    @pdflite.pdf_write_document_with_compressed_xref_stream(document),
  )
}

///|
fn page_fixture_assert_contains_for_test(
  text : String,
  fragment : String,
) -> Unit raise {
  @test.assert_eq(text.contains(fragment), true, msg="missing " + fragment)
}

///|
fn page_fixture_assert_cpdf_manual_pagespec_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let all = document.parse_pagespec("")
  @test.assert_eq(@pdflite.pdf_parse_pagespec(document, ""), all)
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
  let normalized = document.string_of_pagespec(
    document.parse_pagespec("1,3-5,end,~2"),
  )
  @test.assert_eq(normalized, "1,3-5,174-175")
  @test.assert_eq(
    @pdflite.pdf_string_of_pagespec(
      document,
      document.parse_pagespec("1,3-5,end,~2"),
    ),
    normalized,
  )
}

///|
fn page_fixture_assert_cpdf_manual_page_labels_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let expected_labels : Array[@label.PdfPageLabel] = [
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
  @test.assert_eq(@pdflite.pdf_read_page_labels(document), expected_labels)
  let page_info_json = document.page_info_json([1, 19, 175])
  @test.assert_eq(
    @pdflite.pdf_page_info_json(document, [1, 19, 175]),
    page_info_json,
  )
  let page_info_json_text = page_info_json.stringify()
  page_fixture_assert_contains_for_test(page_info_json_text, "\"Page\":1")
  page_fixture_assert_contains_for_test(page_info_json_text, "\"Page\":19")
  page_fixture_assert_contains_for_test(page_info_json_text, "\"Page\":175")
  page_fixture_assert_contains_for_test(page_info_json_text, "\"Label\":\"i\"")
  page_fixture_assert_contains_for_test(page_info_json_text, "\"Label\":\"1\"")
  page_fixture_assert_contains_for_test(
    page_info_json_text, "\"Label\":\"157\"",
  )
  let page_info_text = document.page_info_text([1, 19, 175])
  @test.assert_eq(
    @pdflite.pdf_output_page_info_text(document, [1, 19, 175]),
    page_info_text,
  )
  let page_info_text = @ascii.decode_lossy(page_info_text)
  page_fixture_assert_contains_for_test(page_info_text, "Page 1:\nLabel: i\n")
  page_fixture_assert_contains_for_test(page_info_text, "Page 19:\nLabel: 1\n")
  page_fixture_assert_contains_for_test(
    page_info_text, "Page 175:\nLabel: 157\n",
  )
  @test.assert_eq(document.addtext_page_label(1), "i")
  @test.assert_eq(@pdflite.pdf_addtext_page_label(document, 19), "1")
  @test.assert_eq(document.addtext_page_label(175), "157")
  let bookmarks = document.read_bookmarks(preserve_actions=true)
  let replacement_values = document.addtext_replacement_values(
    bookmarks,
    19,
    175,
    "cpdfmanual.pdf",
    42,
    Some(5),
  )
  @test.assert_eq(
    @pdflite.pdf_addtext_replacement_values(
      document,
      bookmarks,
      19,
      175,
      "cpdfmanual.pdf",
      42,
      Some(5),
    ),
    replacement_values,
  )
  @test.assert_eq(replacement_values.page_label, "1")
  @test.assert_eq(replacement_values.end_label, "157")
  @test.assert_eq(
    @pdflite.pdf_addtext_process_text_with_time(
      @date.pdf_strftime_dummy_time(),
      "%Label|%EndLabel|%Page|%EndPage|%filename|%Bates",
      @pdflite.pdf_addtext_replacement_pairs(replacement_values),
    ),
    "1|157|19|175|cpdfmanual.pdf|00060",
  )
}

///|
async test "cpdf source manual fixture parses page specifications" {
  match page_fixture_bytes_for_test(".repos/cpdf-source/cpdfmanual.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      page_fixture_assert_cpdf_manual_pagespec_for_test(document)
      page_fixture_assert_cpdf_manual_pagespec_for_test(
        page_fixture_reparse_compressed_for_test(document),
      )
    }
  }
}

///|
async test "cpdf source manual fixture reports page label fallbacks" {
  match page_fixture_bytes_for_test(".repos/cpdf-source/cpdfmanual.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      page_fixture_assert_cpdf_manual_page_labels_for_test(document)
      page_fixture_assert_cpdf_manual_page_labels_for_test(
        page_fixture_reparse_compressed_for_test(document),
      )
      page_fixture_assert_cpdf_manual_page_labels_for_test(
        @pdflite.pdf_read_document_from_bytes(
          page_fixture_corrupt_startxref_pointer_for_test(bytes),
        ),
      )
    }
  }
}
