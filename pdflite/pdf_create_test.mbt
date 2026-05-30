///|
fn create_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn create_lookup_for_test(
  object : @pdflite.PdfObject,
  key : @pdflite.PdfName,
) -> @pdflite.PdfObject? {
  object.lookup_immediate(key)
}

///|
fn create_lookup_required_for_test(
  object : @pdflite.PdfObject,
  key : String,
) -> @pdflite.PdfObject raise {
  match create_lookup_for_test(object, create_name_for_test(key)) {
    Some(value) => value
    None => {
      fail("missing dictionary key " + key)
      PdfNull
    }
  }
}

///|
fn create_lookup_indirect_object_for_test(
  document : @pdflite.PdfDocument,
  object : @pdflite.PdfObject,
  key : String,
) -> @pdflite.PdfObject raise {
  let reference = try! create_lookup_required_for_test(object, key)
  guard reference is PdfIndirect(number) else {
    fail("expected dictionary key " + key + " to be indirect")
    PdfNull
  }
  document.lookup_object_or_null(number)
}

///|
fn create_stream_bytes_for_test(object : @pdflite.PdfObject) -> Bytes raise {
  guard object is PdfStreamObject(stream) else {
    fail("expected stream object")
    []
  }
  guard stream.data is StreamGot(bytes) else {
    fail("expected materialized stream bytes")
    []
  }
  bytes
}

///|
fn create_bytes_start_with_at_for_test(
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
fn create_find_bytes_for_test(haystack : BytesView, needle : BytesView) -> Int {
  if needle.length() == 0 {
    0
  } else if haystack.length() < needle.length() {
    -1
  } else {
    let max_start = haystack.length() - needle.length()
    for start in 0..<=max_start {
      if create_bytes_start_with_at_for_test(haystack, needle, start) {
        break start
      }
    } nobreak {
      -1
    }
  }
}

///|
fn create_assert_metadata_contains_for_test(
  metadata : BytesView,
  text : String,
) -> Unit raise {
  @test.assert_eq(
    create_find_bytes_for_test(metadata, @ascii.encode(text)) >= 0,
    true,
  )
}

///|
fn create_assert_metadata_not_contains_for_test(
  metadata : BytesView,
  text : String,
) -> Unit raise {
  @test.assert_eq(create_find_bytes_for_test(metadata, @ascii.encode(text)), -1)
}

///|
fn create_assert_pdfua_common_for_test(
  document : @pdflite.PdfDocument,
  version : (Int, Int),
  info_title : String,
) -> Bytes raise {
  @test.assert_eq(document.version(), version)
  let catalog = try! document.catalog()
  let info = try! create_lookup_indirect_object_for_test(
    document,
    document.trailer_dict(),
    "/Info",
  )
  @test.assert_eq(
    try! create_lookup_required_for_test(info, "/Title"),
    PdfString(@utf8.encode(info_title)),
  )
  let mark_info = try! create_lookup_required_for_test(catalog, "/MarkInfo")
  @test.assert_eq(
    try! create_lookup_required_for_test(mark_info, "/Marked"),
    PdfBoolean(true),
  )
  @test.assert_eq(
    try! create_lookup_required_for_test(catalog, "/Lang"),
    PdfString(@ascii.encode("en-US")),
  )
  let viewer_preferences = try! create_lookup_required_for_test(
    catalog, "/ViewerPreferences",
  )
  @test.assert_eq(
    try! create_lookup_required_for_test(viewer_preferences, "/DisplayDocTitle"),
    PdfBoolean(true),
  )
  let struct_root = try! create_lookup_required_for_test(
    catalog, "/StructTreeRoot",
  )
  @test.assert_eq(
    try! create_lookup_required_for_test(struct_root, "/Type"),
    PdfNameObject(create_name_for_test("/StructTreeRoot")),
  )
  let metadata = try! create_lookup_indirect_object_for_test(
    document, catalog, "/Metadata",
  )
  @test.assert_eq(
    try! create_lookup_required_for_test(metadata, "/Type"),
    PdfNameObject(create_name_for_test("/Metadata")),
  )
  @test.assert_eq(
    try! create_lookup_required_for_test(metadata, "/Subtype"),
    PdfNameObject(create_name_for_test("/XML")),
  )
  try! create_stream_bytes_for_test(metadata)
}

///|
fn create_trailer_id_for_test(
  document : @pdflite.PdfDocument,
) -> (Bytes, Bytes)? {
  match
    create_lookup_for_test(document.trailer_dict(), create_name_for_test("/ID")) {
    Some(PdfArray([PdfString(first), PdfString(second)])) =>
      Some((first, second))
    _ => None
  }
}

///|
test "pdf_blank_document creates requested point-sized pages" {
  let document = try! @pdflite.pdf_blank_document(200.0, 100.0, 2)
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 2)
  @test.assert_eq(
    pages[0].mediabox,
    PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(200.0), PdfReal(100.0)]),
  )
  @test.assert_eq(pages[0].mediabox, pages[1].mediabox)
  guard create_trailer_id_for_test(document) is Some((first_id, second_id)) else {
    fail("expected trailer /ID array")
  }
  @test.assert_eq(first_id.length(), 16)
  @test.assert_eq(first_id, second_id)
}

///|
test "pdf_ua_create_pdfua1 creates blank document metadata and marker" {
  let document = try! @pdflite.pdf_ua_create_pdfua1(
    "Accessible title", @pdflite.paper_a4, 2,
  )
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 2)
  let metadata = try! create_assert_pdfua_common_for_test(
    document,
    (1, 7),
    "Accessible title",
  )
  try! create_assert_metadata_contains_for_test(
    metadata, "<pdfuaid:part>1</pdfuaid:part>",
  )
  try! create_assert_metadata_contains_for_test(metadata, "Accessible title")
  @test.assert_eq(
    create_find_bytes_for_test(metadata, @ascii.encode("<pdfuaid:rev>")),
    -1,
  )
}

///|
test "pdf_ua_create_pdfua2 creates PDF 2.0 marker and escapes title XML" {
  let document = try! @pdflite.pdf_ua_create_pdfua2(
    "A&B <C>", @pdflite.paper_a4, 1,
  )
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  let metadata = try! create_assert_pdfua_common_for_test(
    document,
    (2, 0),
    "A&B <C>",
  )
  try! create_assert_metadata_contains_for_test(
    metadata, "<pdfuaid:part>2</pdfuaid:part>",
  )
  try! create_assert_metadata_contains_for_test(
    metadata, "<pdfuaid:rev>2024</pdfuaid:rev>",
  )
  try! create_assert_metadata_contains_for_test(metadata, "A&amp;B &lt;C&gt;")
}

///|
test "PdfDocument mark_pdfua1 creates metadata without mutating original" {
  let document = try! @pdflite.pdf_blank_document(200.0, 100.0, 1)
  @test.assert_eq(try! document.metadata(), None)
  let marked = try! document.mark_pdfua1()
  guard (try! marked.metadata()) is Some(metadata) else {
    fail("expected PDF/UA marker metadata")
  }
  try! create_assert_metadata_contains_for_test(
    metadata, "<pdfuaid:part>1</pdfuaid:part>",
  )
  try! create_assert_metadata_not_contains_for_test(metadata, "<pdfuaid:rev>")
  @test.assert_eq(try! marked.determine_subformats(), ["PDF/UA-1"])
  @test.assert_eq(try! document.metadata(), None)
  let wrapped = try! @pdflite.pdf_ua_mark(document)
  @test.assert_eq(try! wrapped.determine_subformats(), ["PDF/UA-1"])
}

///|
test "PdfDocument mark_pdfua2 replaces and remove_pdfua_mark deletes marker" {
  let document = try! @pdflite.pdf_ua_create_pdfua1(
    "Accessible title", @pdflite.paper_a4, 1,
  )
  let marked = try! @pdflite.pdf_ua_mark2(2026, document)
  guard (try! marked.metadata()) is Some(marked_metadata) else {
    fail("expected PDF/UA-2 marker metadata")
  }
  try! create_assert_metadata_contains_for_test(
    marked_metadata, "<pdfuaid:part>2</pdfuaid:part>",
  )
  try! create_assert_metadata_contains_for_test(
    marked_metadata, "<pdfuaid:rev>2026</pdfuaid:rev>",
  )
  try! create_assert_metadata_not_contains_for_test(
    marked_metadata, "<pdfuaid:part>1</pdfuaid:part>",
  )
  @test.assert_eq(try! marked.determine_subformats(), ["PDF/UA-2"])
  @test.assert_eq(try! document.determine_subformats(), ["PDF/UA-1"])

  let removed = try! @pdflite.pdf_ua_remove_mark(marked)
  guard (try! removed.metadata()) is Some(removed_metadata) else {
    fail("expected metadata to remain after removing PDF/UA marker")
  }
  try! create_assert_metadata_not_contains_for_test(
    removed_metadata, "<pdfuaid:part>",
  )
  try! create_assert_metadata_not_contains_for_test(
    removed_metadata, "<pdfuaid:rev>",
  )
  @test.assert_eq(try! removed.determine_subformats(), [])

  let no_metadata = try! document.remove_metadata()
  @test.assert_eq(try! no_metadata.remove_pdfua_mark().metadata(), None)
}

///|
test "pdf_blank_document_paper creates pages from named paper size" {
  let document = try! @pdflite.pdf_blank_document_paper(@pdflite.paper_a4, 1)
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 1)
  @test.assert_eq(
    pages[0].mediabox,
    @page.pdf_page_blank(@pdflite.paper_a4).mediabox,
  )
  guard create_trailer_id_for_test(document) is Some((first_id, second_id)) else {
    fail("expected trailer /ID array")
  }
  @test.assert_eq(first_id.length(), 16)
  @test.assert_eq(first_id, second_id)
}

///|
test "pdf_blank_document accepts zero pages" {
  let document = try! @pdflite.pdf_blank_document(10.0, 20.0, 0)
  let pages = try! document.pages_of_pagetree()
  @test.assert_eq(pages.length(), 0)
  guard create_trailer_id_for_test(document) is Some((first_id, second_id)) else {
    fail("expected trailer /ID array")
  }
  @test.assert_eq(first_id.length(), 16)
  @test.assert_eq(first_id, second_id)
}
