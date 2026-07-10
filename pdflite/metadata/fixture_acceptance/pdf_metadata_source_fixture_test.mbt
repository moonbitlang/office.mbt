///|
fn metadata_fixture_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
async fn metadata_fixture_bytes_for_test(path : String) -> Bytes? {
  let read_result = try
    @fs.read_file(metadata_fixture_path_for_test(path))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match read_result {
    Ok(data) => Some(data.binary())
    Err(_) => None
  }
}

///|
fn metadata_fixture_bytes_start_with_at_for_test(
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
fn metadata_fixture_find_last_bytes_for_test(
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
      if metadata_fixture_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn metadata_fixture_push_ascii_for_test(
  output : Array[Byte],
  text : String,
) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn metadata_fixture_corrupt_startxref_pointer_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let marker = b"startxref"
  let marker_position = metadata_fixture_find_last_bytes_for_test(bytes, marker)
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
  metadata_fixture_push_ascii_for_test(
    output,
    (bytes.length() + 4096).to_string(),
  )
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn metadata_fixture_reparse_compressed_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  @pdflite.pdf_read_document_from_bytes(
    @pdflite.pdf_write_document_with_compressed_xref_stream(document),
  )
}

///|
fn metadata_fixture_assert_contains_for_test(
  text : String,
  fragment : String,
) -> Unit raise {
  @test.assert_eq(text.contains(fragment), true, msg="missing " + fragment)
}

///|
fn metadata_fixture_pdf_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn metadata_fixture_composition_entry_bytes_for_test(
  entries : ArrayView[@composition.PdfCompositionEntry],
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
fn metadata_fixture_assert_cpdf_manual_reports_for_test(
  document : @pdflite.PdfDocument,
  file_size : Int,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let info_json = document.info_json()
  @test.assert_eq(
    @pdflite.pdf_output_info_json_blob(document),
    @utf8.encode(info_json.stringify()),
  )
  let info_json_text = info_json.stringify()
  metadata_fixture_assert_contains_for_test(info_json_text, "\"Version\":[1,7]")
  metadata_fixture_assert_contains_for_test(info_json_text, "\"Pages\":175")
  metadata_fixture_assert_contains_for_test(
    info_json_text, "\"Creator\":\"LaTeX with hyperref\"",
  )
  metadata_fixture_assert_contains_for_test(
    info_json_text, "\"Producer\":\"pdfTeX-1.40.29\"",
  )
  let info_text_blob = document.info_blob()
  @test.assert_eq(@pdflite.pdf_output_info(document), info_text_blob)
  let info_text = @utf8.decode_lossy(info_text_blob)
  metadata_fixture_assert_contains_for_test(info_text, "Version: 1.7\n")
  metadata_fixture_assert_contains_for_test(info_text, "Pages: 175\n")
  metadata_fixture_assert_contains_for_test(
    info_text, "Creator: LaTeX with hyperref\n",
  )
  metadata_fixture_assert_contains_for_test(
    info_text, "Producer: pdfTeX-1.40.29\n",
  )
  let xmp_json = document.xmp_info_json()
  @test.assert_eq(
    @pdflite.pdf_output_xmp_info_json_blob(document),
    @utf8.encode(xmp_json.stringify()),
  )
  let xmp_json_text = xmp_json.stringify()
  metadata_fixture_assert_contains_for_test(xmp_json_text, "\"Subformats\":[]")
  metadata_fixture_assert_contains_for_test(xmp_json_text, "\"Language\":null")
  let xmp_text_blob = document.xmp_info_blob()
  @test.assert_eq(@pdflite.pdf_output_xmp_info(document), xmp_text_blob)
  let xmp_text = @utf8.decode_lossy(xmp_text_blob)
  metadata_fixture_assert_contains_for_test(
    xmp_text, "Subformats: \nLanguage: \n",
  )
  let page_info_json = document.page_info_json([1, 175])
  @test.assert_eq(
    @pdflite.pdf_page_info_json(document, [1, 175]),
    page_info_json,
  )
  let page_info_json_text = page_info_json.stringify()
  metadata_fixture_assert_contains_for_test(page_info_json_text, "\"Page\":1")
  metadata_fixture_assert_contains_for_test(page_info_json_text, "\"Page\":175")
  metadata_fixture_assert_contains_for_test(
    page_info_json_text, "\"Rotation\":0",
  )
  let page_info_text = document.page_info_text([1, 175])
  @test.assert_eq(
    @pdflite.pdf_output_page_info_text(document, [1, 175]),
    page_info_text,
  )
  let page_info_text = @ascii.decode_lossy(page_info_text)
  metadata_fixture_assert_contains_for_test(page_info_text, "Page 1:\n")
  metadata_fixture_assert_contains_for_test(page_info_text, "Page 175:\n")
  metadata_fixture_assert_contains_for_test(
    page_info_text, "MediaBox: 0.000000 0.000000 540.000000 666.000000\n",
  )
  metadata_fixture_assert_contains_for_test(page_info_text, "Rotation: 0\n")
  let composition = document.composition(file_size)
  @test.assert_eq(@pdflite.pdf_composition(document, file_size), composition)
  @test.assert_eq(composition.length(), 8)
  @test.assert_eq(composition[0].label, "Images")
  @test.assert_eq(composition[1].label, "Fonts")
  @test.assert_eq(composition[2].label, "Content streams")
  @test.assert_eq(composition[5].label, "XRef Table")
  @test.assert_eq(
    metadata_fixture_composition_entry_bytes_for_test(composition, "Fonts") > 0,
    true,
  )
  @test.assert_eq(
    metadata_fixture_composition_entry_bytes_for_test(
      composition, "Content streams",
    ) >
    0,
    true,
  )
  @test.assert_eq(
    metadata_fixture_composition_entry_bytes_for_test(composition, "XRef Table") >
    0,
    true,
  )
  let composition_json = document.composition_json(file_size)
  @test.assert_eq(
    @pdflite.pdf_show_composition_json_blob(file_size, document),
    @utf8.encode(composition_json.stringify()),
  )
  let composition_json_text = composition_json.stringify()
  metadata_fixture_assert_contains_for_test(
    composition_json_text, "[\"Fonts\",",
  )
  metadata_fixture_assert_contains_for_test(
    composition_json_text, "[\"Content streams\",",
  )
  metadata_fixture_assert_contains_for_test(
    composition_json_text, "[\"XRef Table\",",
  )
}

///|
fn metadata_fixture_assert_cpdf_manual_metadata_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  @test.assert_eq(document.language(), Some(b"en-GB"))
  @test.assert_eq(@pdflite.pdf_language(document), Some(b"en-GB"))
  @test.assert_eq(
    document.info_utf8(metadata_fixture_pdf_name_for_test("/Title")),
    "cpdf source & metadata",
  )
  @test.assert_eq(
    @pdflite.pdf_get_info_utf8(
      document,
      metadata_fixture_pdf_name_for_test("/Title"),
    ),
    "cpdf source & metadata",
  )
  @test.assert_eq(
    document.info_utf8(metadata_fixture_pdf_name_for_test("/Author")),
    "MoonBit port",
  )
  @test.assert_eq(
    document.info_utf8(metadata_fixture_pdf_name_for_test("/Creator")),
    "LaTeX with hyperref",
  )
  @test.assert_eq(
    document.info_utf8(metadata_fixture_pdf_name_for_test("/Producer")),
    "pdfTeX-1.40.29",
  )
  let metadata = match @pdflite.pdf_get_metadata(document) {
    Some(metadata) => metadata
    None => fail("missing cpdf manual metadata")
  }
  @test.assert_eq(document.metadata(), Some(metadata))
  let metadata_text = @utf8.decode_lossy(metadata)
  metadata_fixture_assert_contains_for_test(
    metadata_text, "<pdf:Producer>pdfTeX-1.40.29</pdf:Producer>",
  )
  metadata_fixture_assert_contains_for_test(
    metadata_text, "<pdf:Creator>LaTeX with hyperref</pdf:Creator>",
  )
  metadata_fixture_assert_contains_for_test(
    metadata_text, "<xap:CreatorTool>LaTeX with hyperref</xap:CreatorTool>",
  )
  metadata_fixture_assert_contains_for_test(
    metadata_text, "<pdf:Title>cpdf source &amp; metadata</pdf:Title>",
  )
  metadata_fixture_assert_contains_for_test(
    metadata_text, "<pdf:Author>MoonBit port</pdf:Author>",
  )
  metadata_fixture_assert_contains_for_test(
    metadata_text, "2026-05-08T20:26:06+01:00",
  )
  let info_json = document.info_json()
  @test.assert_eq(
    @pdflite.pdf_output_info_json_blob(document),
    @utf8.encode(info_json.stringify()),
  )
  let info_json_text = info_json.stringify()
  metadata_fixture_assert_contains_for_test(
    info_json_text, "\"Title\":\"cpdf source & metadata\"",
  )
  metadata_fixture_assert_contains_for_test(
    info_json_text, "\"Author\":\"MoonBit port\"",
  )
  metadata_fixture_assert_contains_for_test(
    info_json_text, "\"Creator\":\"LaTeX with hyperref\"",
  )
  metadata_fixture_assert_contains_for_test(
    info_json_text, "\"Producer\":\"pdfTeX-1.40.29\"",
  )
  let info_text_blob = document.info_blob()
  @test.assert_eq(@pdflite.pdf_output_info(document), info_text_blob)
  let info_text = @utf8.decode_lossy(info_text_blob)
  metadata_fixture_assert_contains_for_test(
    info_text, "Title: cpdf source & metadata\n",
  )
  metadata_fixture_assert_contains_for_test(info_text, "Author: MoonBit port\n")
  metadata_fixture_assert_contains_for_test(
    info_text, "Creator: LaTeX with hyperref\n",
  )
  metadata_fixture_assert_contains_for_test(
    info_text, "Producer: pdfTeX-1.40.29\n",
  )
  let xmp_json = document.xmp_info_json()
  @test.assert_eq(
    @pdflite.pdf_output_xmp_info_json_blob(document),
    @utf8.encode(xmp_json.stringify()),
  )
  let xmp_json_text = xmp_json.stringify()
  metadata_fixture_assert_contains_for_test(
    xmp_json_text, "\"Language\":\"en-GB\"",
  )
  metadata_fixture_assert_contains_for_test(
    xmp_json_text, "\"XMP pdf:Producer\":\"pdfTeX-1.40.29\"",
  )
  metadata_fixture_assert_contains_for_test(
    xmp_json_text, "\"XMP pdf:Creator\":\"LaTeX with hyperref\"",
  )
  metadata_fixture_assert_contains_for_test(
    xmp_json_text, "\"XMP xmp:CreatorTool\":\"LaTeX with hyperref\"",
  )
  metadata_fixture_assert_contains_for_test(
    xmp_json_text, "\"XMP pdf:Title\":\"cpdf source & metadata\"",
  )
  metadata_fixture_assert_contains_for_test(
    xmp_json_text, "\"XMP pdf:Author\":\"MoonBit port\"",
  )
  let xmp_text_blob = document.xmp_info_blob()
  @test.assert_eq(@pdflite.pdf_output_xmp_info(document), xmp_text_blob)
  let xmp_text = @utf8.decode_lossy(xmp_text_blob)
  metadata_fixture_assert_contains_for_test(xmp_text, "Language: \"en-GB\"\n")
  metadata_fixture_assert_contains_for_test(
    xmp_text, "XMP pdf:Producer: pdfTeX-1.40.29\n",
  )
  metadata_fixture_assert_contains_for_test(
    xmp_text, "XMP pdf:Creator: LaTeX with hyperref\n",
  )
  metadata_fixture_assert_contains_for_test(
    xmp_text, "XMP pdf:Title: cpdf source & metadata\n",
  )
  metadata_fixture_assert_contains_for_test(
    xmp_text, "XMP pdf:Author: MoonBit port\n",
  )
}

///|
fn metadata_fixture_assert_cpdf_manual_metadata_removed_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  @test.assert_eq(document.language(), Some(b"en-GB"))
  @test.assert_eq(@pdflite.pdf_language(document), Some(b"en-GB"))
  @test.assert_eq(document.metadata(), None)
  @test.assert_eq(@pdflite.pdf_get_metadata(document), None)
  let xmp_json = document.xmp_info_json()
  @test.assert_eq(
    @pdflite.pdf_output_xmp_info_json_blob(document),
    @utf8.encode(xmp_json.stringify()),
  )
  let xmp_json_text = xmp_json.stringify()
  metadata_fixture_assert_contains_for_test(
    xmp_json_text, "\"Language\":\"en-GB\"",
  )
  metadata_fixture_assert_contains_for_test(xmp_json_text, "\"Subformats\":[]")
  @test.assert_eq(xmp_json_text.contains("XMP pdf:Title"), false)
  @test.assert_eq(xmp_json_text.contains("XMP pdf:Author"), false)
  let xmp_text_blob = document.xmp_info_blob()
  @test.assert_eq(@pdflite.pdf_output_xmp_info(document), xmp_text_blob)
  let xmp_text = @utf8.decode_lossy(xmp_text_blob)
  metadata_fixture_assert_contains_for_test(
    xmp_text, "Subformats: \nLanguage: \"en-GB\"\n",
  )
  @test.assert_eq(xmp_text.contains("XMP pdf:Title"), false)
  @test.assert_eq(xmp_text.contains("XMP pdf:Author"), false)
}

///|
fn metadata_fixture_assert_cpdf_manual_catalog_actions_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  @test.assert_eq(document.version(), (1, 7))
  @test.assert_eq(
    document.catalog_item(metadata_fixture_pdf_name_for_test("/PageLayout")),
    "TwoPageRight",
  )
  @test.assert_eq(
    @pdflite.pdf_get_catalog_item(
      metadata_fixture_pdf_name_for_test("/PageLayout"),
      document,
    ),
    "TwoPageRight",
  )
  @test.assert_eq(
    document.catalog_item(metadata_fixture_pdf_name_for_test("/PageMode")),
    "FullScreen",
  )
  @test.assert_eq(
    document.viewer_preference_item(
      metadata_fixture_pdf_name_for_test("/NonFullScreenPageMode"),
    ),
    "UseOutlines",
  )
  @test.assert_eq(
    @pdflite.pdf_get_viewer_pref_item(
      metadata_fixture_pdf_name_for_test("/DisplayDocTitle"),
      document,
    ),
    "true",
  )
  @test.assert_eq(
    document.open_action(),
    PdfArray([
      PdfInteger(175),
      PdfNameObject(metadata_fixture_pdf_name_for_test("/XYZ")),
      PdfNull,
      PdfNull,
      PdfNull,
    ]),
  )
  @test.assert_eq(document.open_action_string(), "[175 /XYZ null null null]")
  @test.assert_eq(
    @pdflite.pdf_get_open_action_string(document),
    "[175 /XYZ null null null]",
  )
  let open_action_json = @ascii.decode_lossy(document.open_action_json_blob())
  metadata_fixture_assert_contains_for_test(open_action_json, "\"I\":175")
  metadata_fixture_assert_contains_for_test(open_action_json, "\"N\":\"/XYZ\"")
  metadata_fixture_assert_contains_for_test(open_action_json, "null")
  let info_json_text = document.info_json().stringify()
  metadata_fixture_assert_contains_for_test(
    info_json_text, "\"PageLayout\":\"TwoPageRight\"",
  )
  metadata_fixture_assert_contains_for_test(
    info_json_text, "\"PageMode\":\"FullScreen\"",
  )
  metadata_fixture_assert_contains_for_test(
    info_json_text, "\"DisplayDocTitle\":true",
  )
  metadata_fixture_assert_contains_for_test(
    info_json_text, "\"NonFullPageScreenMode\":\"UseOutlines\"",
  )
  metadata_fixture_assert_contains_for_test(info_json_text, "\"I\":175")
  metadata_fixture_assert_contains_for_test(info_json_text, "\"N\":\"/XYZ\"")
  let info_text = @utf8.decode_lossy(document.info_blob())
  metadata_fixture_assert_contains_for_test(
    info_text, "PageLayout: TwoPageRight\n",
  )
  metadata_fixture_assert_contains_for_test(info_text, "PageMode: FullScreen\n")
  metadata_fixture_assert_contains_for_test(
    info_text, "DisplayDocTitle: true\n",
  )
  metadata_fixture_assert_contains_for_test(
    info_text, "NonFullScreenPageMode: UseOutlines\n",
  )
  metadata_fixture_assert_contains_for_test(
    info_text, "OpenAction: [175 /XYZ null null null]\n",
  )
}

///|
async test "cpdf source manual fixture reports info page details and composition" {
  match metadata_fixture_bytes_for_test("fixtures/cpdf-source/cpdfmanual.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      metadata_fixture_assert_cpdf_manual_reports_for_test(
        document,
        bytes.length(),
      )
      let rewritten = @pdflite.pdf_write_document_with_compressed_xref_stream(
        document,
      )
      metadata_fixture_assert_cpdf_manual_reports_for_test(
        @pdflite.pdf_read_document_from_bytes(rewritten),
        rewritten.length(),
      )
    }
  }
}

///|
async test "cpdf source manual fixture mutates catalog view and open action" {
  match metadata_fixture_bytes_for_test("fixtures/cpdf-source/cpdfmanual.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      @test.assert_eq(document.endpage(), 175)
      let with_view = try! @pdflite.pdf_set_open_action(
        try! @pdflite.pdf_set_viewer_preference(
          metadata_fixture_pdf_name_for_test("/DisplayDocTitle"),
          PdfBoolean(true),
          4,
          try! @pdflite.pdf_set_non_full_screen_page_mode(
            try! @pdflite.pdf_set_page_mode(
              try! @pdflite.pdf_set_page_layout(document, "TwoPageRight"),
              "FullScreen",
            ),
            "UseOutlines",
          ),
        ),
        false,
        175,
      )
      metadata_fixture_assert_cpdf_manual_catalog_actions_for_test(with_view)
      let compressed = @pdflite.pdf_write_document_with_compressed_xref_stream(
        with_view,
      )
      metadata_fixture_assert_cpdf_manual_catalog_actions_for_test(
        @pdflite.pdf_read_document_from_bytes(compressed),
      )
      let corrupted = metadata_fixture_corrupt_startxref_pointer_for_test(
        compressed,
      )
      let strict : Result[@pdflite.PdfDocument, Error] = try
        @pdflite.pdf_read_classic_document_from_bytes(corrupted)
      catch {
        err => Err(err)
      } noraise {
        value => Ok(value)
      }
      guard strict is Err(_) else {
        fail(
          "expected cpdf manual catalog view recovery to require reconstruction",
        )
      }
      let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(recovered.first_xref(), 0)
      metadata_fixture_assert_cpdf_manual_catalog_actions_for_test(recovered)
    }
  }
}

///|
async test "cpdf source manual fixture mutates metadata" {
  match metadata_fixture_bytes_for_test("fixtures/cpdf-source/cpdfmanual.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      @test.assert_eq(document.metadata(), None)
      @test.assert_eq(@pdflite.pdf_get_metadata(document), None)
      let title = @pdflite.pdf_pdfdocstring_of_utf8(
        @utf8.encode("cpdf source & metadata"),
      )
      let author = @pdflite.pdf_pdfdocstring_of_utf8(
        @utf8.encode("MoonBit port"),
      )
      let with_metadata = @pdflite.pdf_create_metadata(document)
      let with_language = @pdflite.pdf_set_language(with_metadata, b"en-GB")
      let with_title = @pdflite.pdf_set_pdf_info(
        metadata_fixture_pdf_name_for_test("/Title"),
        PdfString(title),
        4,
        with_language,
        keep_version=true,
        xmp_also=true,
      )
      let updated = @pdflite.pdf_set_pdf_info(
        metadata_fixture_pdf_name_for_test("/Author"),
        PdfString(author),
        4,
        with_title,
        keep_version=true,
        xmp_also=true,
      )
      metadata_fixture_assert_cpdf_manual_metadata_for_test(updated)
      metadata_fixture_assert_cpdf_manual_metadata_for_test(
        metadata_fixture_reparse_compressed_for_test(updated),
      )
      let corrupt_startxref_bytes = metadata_fixture_corrupt_startxref_pointer_for_test(
        @pdflite.pdf_write_document_with_compressed_xref_stream(updated),
      )
      metadata_fixture_assert_cpdf_manual_metadata_for_test(
        @pdflite.pdf_read_document_from_bytes(corrupt_startxref_bytes),
      )
      let removed = @pdflite.pdf_remove_all_metadata(updated)
      metadata_fixture_assert_cpdf_manual_metadata_removed_for_test(removed)
      metadata_fixture_assert_cpdf_manual_metadata_removed_for_test(
        metadata_fixture_reparse_compressed_for_test(removed),
      )
    }
  }
}
