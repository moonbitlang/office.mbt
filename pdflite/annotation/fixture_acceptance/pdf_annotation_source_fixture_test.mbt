///|
fn annotation_fixture_path_for_test(path : String) -> String {
  match @env.current_dir() {
    Some(current_dir) => current_dir + "/" + path
    None => path
  }
}

///|
async fn annotation_fixture_bytes_for_test(path : String) -> Bytes? {
  let read_result = try
    @fs.read_file(annotation_fixture_path_for_test(path))
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
fn annotation_fixture_bytes_start_with_at_for_test(
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
fn annotation_fixture_find_last_bytes_for_test(
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
      if annotation_fixture_bytes_start_with_at_for_test(
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
fn annotation_fixture_push_ascii_for_test(
  output : Array[Byte],
  text : String,
) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn annotation_fixture_corrupt_startxref_pointer_for_test(
  bytes : Bytes,
) -> Bytes raise {
  let marker = b"startxref"
  let marker_position = annotation_fixture_find_last_bytes_for_test(
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
  annotation_fixture_push_ascii_for_test(
    output,
    (bytes.length() + 4096).to_string(),
  )
  for index in number_end..<bytes.length() {
    output.push(bytes[index])
  }
  Bytes::from_array(output)
}

///|
fn annotation_fixture_reparse_compressed_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument raise {
  @pdflite.pdf_read_document_from_bytes(
    @pdflite.pdf_write_document_with_compressed_xref_stream(document),
  )
}

///|
fn annotation_fixture_assert_contains_for_test(
  text : String,
  fragment : String,
) -> Unit raise {
  @test.assert_eq(text.contains(fragment), true, msg="missing " + fragment)
}

///|
fn annotation_fixture_assert_not_contains_for_test(
  text : String,
  fragment : String,
) -> Unit raise {
  @test.assert_eq(text.contains(fragment), false, msg="unexpected " + fragment)
}

///|
fn annotation_fixture_assert_json_entry_count_for_test(
  json : Json,
  expected : Int,
) -> Unit raise {
  guard json is Array(entries) else { fail("expected annotation JSON array") }
  @test.assert_eq(entries.length(), expected)
}

///|
fn annotation_fixture_assert_json_entry_count_at_least_for_test(
  json : Json,
  minimum : Int,
) -> Unit raise {
  guard json is Array(entries) else { fail("expected annotation JSON array") }
  @test.assert_eq(entries.length() >= minimum, true)
}

///|
fn annotation_fixture_assert_cpdf_manual_annotations_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  @test.assert_eq(document.endpage(), 175)
  let annotated = document.parse_pagespec("annotated")
  @test.assert_eq(@pdflite.pdf_parse_pagespec(document, "annotated"), annotated)
  @test.assert_eq(annotated.length() > 0, true)
  let page = annotated[0]
  let annotation_json = document.annotations_json([page])
  let annotation_blob = document.annotations_json_blob([page])
  @test.assert_eq(annotation_blob, @utf8.encode(annotation_json.stringify()))
  @test.assert_eq(
    @pdflite.pdf_get_annotations_json([page], document),
    annotation_blob,
  )
  let annotation_json_text = annotation_json.stringify()
  annotation_fixture_assert_contains_for_test(
    annotation_json_text, "\"/CPDFJSONannotformatversion\"",
  )
  annotation_fixture_assert_contains_for_test(
    annotation_json_text, "\"/Subtype\"",
  )
  annotation_fixture_assert_contains_for_test(annotation_json_text, "\"/Link\"")
  annotation_fixture_assert_contains_for_test(annotation_json_text, "\"/Rect\"")
  annotation_fixture_assert_contains_for_test(annotation_json_text, "\"/A\"")
  let annotation_blob_text = @utf8.decode_lossy(annotation_blob)
  annotation_fixture_assert_contains_for_test(annotation_blob_text, "\"/Link\"")
  annotation_fixture_assert_contains_for_test(annotation_blob_text, "\"/Rect\"")
}

///|
fn annotation_fixture_assert_cpdf_manual_annotation_import_for_test(
  document : @pdflite.PdfDocument,
) -> Unit raise {
  annotation_fixture_assert_cpdf_manual_annotations_for_test(document)
  annotation_fixture_assert_cpdf_manual_annotations_for_test(
    annotation_fixture_reparse_compressed_for_test(document),
  )
}

///|
async test "cpdf source manual fixture exports annotation JSON" {
  match
    annotation_fixture_bytes_for_test("fixtures/cpdf-source/cpdfmanual.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      annotation_fixture_assert_cpdf_manual_annotations_for_test(document)
      annotation_fixture_assert_cpdf_manual_annotations_for_test(
        annotation_fixture_reparse_compressed_for_test(document),
      )
      let corrupted = annotation_fixture_corrupt_startxref_pointer_for_test(
        bytes,
      )
      let strict : Result[@pdflite.PdfDocument, Error] = try
        @pdflite.pdf_read_classic_document_from_bytes(corrupted)
      catch {
        err => Err(err)
      } noraise {
        value => Ok(value)
      }
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(recovered.first_xref(), 0)
      annotation_fixture_assert_cpdf_manual_annotations_for_test(recovered)
      annotation_fixture_assert_cpdf_manual_annotations_for_test(
        annotation_fixture_reparse_compressed_for_test(recovered),
      )
    }
  }
}

///|
async test "cpdf source manual fixture imports annotation JSON" {
  match
    annotation_fixture_bytes_for_test("fixtures/cpdf-source/cpdfmanual.pdf") {
    None => ()
    Some(bytes) => {
      let document = @pdflite.pdf_read_document_from_bytes(bytes)
      let annotated = document.parse_pagespec("annotated")
      @test.assert_eq(annotated.length() > 0, true)
      let page = annotated[0]
      let annotation_json = document.annotations_json([page])
      annotation_fixture_assert_json_entry_count_at_least_for_test(
        annotation_json, 2,
      )
      let removed = document.remove_annotations([page])
      let removed_json = removed.annotations_json([page])
      annotation_fixture_assert_json_entry_count_for_test(removed_json, 1)
      let removed_json_text = removed_json.stringify()
      annotation_fixture_assert_not_contains_for_test(
        removed_json_text, "\"/Link\"",
      )
      annotation_fixture_assert_not_contains_for_test(
        removed_json_text, "\"/Rect\"",
      )

      let imported = removed.set_annotations_json(annotation_json)
      let imported_wrapper = @pdflite.pdf_set_annotations_json(
        annotation_json, removed,
      )
      let copied = removed.copy_annotations_from(document, [page])
      let copied_wrapper = @pdflite.pdf_copy_annotations(
        [page],
        document,
        removed,
      )
      annotation_fixture_assert_cpdf_manual_annotation_import_for_test(imported)
      annotation_fixture_assert_cpdf_manual_annotation_import_for_test(
        imported_wrapper,
      )
      annotation_fixture_assert_cpdf_manual_annotation_import_for_test(copied)
      annotation_fixture_assert_cpdf_manual_annotation_import_for_test(
        copied_wrapper,
      )

      let imported_bytes = @pdflite.pdf_write_document_with_compressed_xref_stream(
        imported,
      )
      let corrupted = annotation_fixture_corrupt_startxref_pointer_for_test(
        imported_bytes,
      )
      let strict : Result[@pdflite.PdfDocument, Error] = try
        @pdflite.pdf_read_classic_document_from_bytes(corrupted)
      catch {
        err => Err(err)
      } noraise {
        value => Ok(value)
      }
      guard strict is Err(_) else {
        fail("expected bad startxref to require malformed reconstruction")
      }
      let recovered = @pdflite.pdf_read_document_from_bytes(corrupted)
      @test.assert_eq(recovered.first_xref(), 0)
      annotation_fixture_assert_cpdf_manual_annotation_import_for_test(
        recovered,
      )
    }
  }
}
