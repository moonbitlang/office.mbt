///|
fn attach_name_for_test(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn attach_string_for_test(text : String) -> @syntax.PdfObject {
  PdfString(@ascii.encode(text))
}

///|
fn attach_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @syntax.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn attach_page_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @page.PdfPage {
  @page.pdf_page_custom(attach_rect_for_test(min_x, min_y, max_x, max_y))
}

///|
fn attach_document_for_test(
  pages : ArrayView[@page.PdfPage],
) -> @pdflite.PdfDocument {
  let document = @pdflite.pdf_document_empty()
  let page_root = try! document.add_pagetree(pages)
  ignore(try! document.add_root(page_root, []))
  document
}

///|
fn attach_blank_document_for_test() -> @pdflite.PdfDocument {
  attach_document_for_test([attach_page_for_test(0.0, 0.0, 100.0, 100.0)])
}

///|
fn attach_lookup_for_test(
  document : @pdflite.PdfDocument,
  key : String,
  object : @syntax.PdfObject,
) -> @syntax.PdfObject raise {
  match document.lookup_direct(attach_name_for_test(key), object) {
    Some(value) => value
    None => fail("missing key " + key)
  }
}

///|
fn attach_catalog_for_test(
  document : @pdflite.PdfDocument,
) -> @syntax.PdfObject {
  try! document.catalog()
}

///|
fn attach_embedded_tree_for_test(
  document : @pdflite.PdfDocument,
) -> @syntax.PdfObject raise {
  let catalog = attach_catalog_for_test(document)
  let names = attach_lookup_for_test(document, "/Names", catalog)
  attach_lookup_for_test(document, "/EmbeddedFiles", names)
}

///|
fn attach_payload_stream_for_test(
  document : @pdflite.PdfDocument,
  file_spec : @syntax.PdfObject,
) -> @syntax.PdfObject raise {
  let ef = attach_lookup_for_test(document, "/EF", file_spec)
  attach_lookup_for_test(document, "/F", ef)
}

///|
fn attach_md5_abc_for_test() -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array([
    0x90, 0x01, 0x50, 0x98, 0x3C, 0xD2, 0x4F, 0xB0, 0xD6, 0x96, 0x3F, 0x7D, 0x28,
    0xE1, 0x7F, 0x72,
  ])
}

///|
test "PdfDocument attach_file creates document-level embedded file metadata" {
  let payload = @ascii.encode("abc")
  let original = attach_blank_document_for_test()
  let document = try! original.attach_file(
    "fixtures/report.txt",
    payload,
    relationship=Some("Data"),
    description=Some("Annual report"),
  )
  @test.assert_eq(original.version(), (1, 0))
  @test.assert_eq(document.version(), (1, 4))
  @test.assert_eq(try! original.list_attached_files(), [])
  let entries = document.read_name_tree(attach_embedded_tree_for_test(document))
  @test.assert_eq(entries.length(), 1)
  @test.assert_eq(entries[0].0, @ascii.encode("report.txt"))
  let file_spec = document.direct(entries[0].1)
  @test.assert_eq(
    attach_lookup_for_test(document, "/Type", file_spec),
    PdfNameObject(attach_name_for_test("/Filespec")),
  )
  @test.assert_eq(
    attach_lookup_for_test(document, "/F", file_spec),
    attach_string_for_test("report.txt"),
  )
  @test.assert_eq(
    attach_lookup_for_test(document, "/UF", file_spec),
    attach_string_for_test("report.txt"),
  )
  @test.assert_eq(
    attach_lookup_for_test(document, "/Desc", file_spec),
    attach_string_for_test("Annual report"),
  )
  @test.assert_eq(
    attach_lookup_for_test(document, "/AFRelationship", file_spec),
    PdfNameObject(attach_name_for_test("/Data")),
  )
  let stream = attach_payload_stream_for_test(document, file_spec)
  @test.assert_eq(try! stream.stream_bytes(), payload)
  guard stream is PdfStreamObject(stream_object) else {
    fail("expected embedded file stream")
  }
  @test.assert_eq(
    attach_lookup_for_test(document, "/Length", stream_object.dictionary),
    PdfInteger(payload.length()),
  )
  @test.assert_eq(
    attach_lookup_for_test(document, "/Type", stream_object.dictionary),
    PdfNameObject(attach_name_for_test("/EmbeddedFile")),
  )
  let params = attach_lookup_for_test(
    document,
    "/Params",
    stream_object.dictionary,
  )
  @test.assert_eq(
    attach_lookup_for_test(document, "/Size", params),
    PdfInteger(payload.length()),
  )
  @test.assert_eq(
    attach_lookup_for_test(document, "/CheckSum", params),
    PdfString(attach_md5_abc_for_test()),
  )
  let attachments = try! document.list_attached_files()
  @test.assert_eq(attachments, [
    {
      name: "report.txt",
      pagenumber: 0,
      data: Some(payload),
      description: Some("Annual report"),
      relationship: Some("/Data"),
    },
  ])
  @test.assert_eq(try! document.size_attached_files(), payload.length())
}

///|
test "pdf_attach_file wrapper can keep the original PDF version" {
  let document = try! @pdflite.pdf_attach_file(
    attach_blank_document_for_test(),
    "note.bin",
    @ascii.encode("payload"),
    keep_version=true,
  )
  @test.assert_eq(document.version(), (1, 0))
  @test.assert_eq((try! document.list_attached_files()).length(), 1)
}

///|
test "pdf_attach_file_cpdf_order preserves source argument order" {
  let payload = @ascii.encode("payload")
  let document = try! @pdflite.pdf_attach_file_cpdf_order(
    false,
    Some(1),
    attach_blank_document_for_test(),
    Some("Data"),
    Some("Page note"),
    "folder/page-note.bin",
    payload,
  )
  @test.assert_eq(try! document.list_attached_files(), [
    {
      name: "page-note.bin",
      pagenumber: 1,
      data: Some(payload),
      description: Some("Page note"),
      relationship: Some("/Data"),
    },
  ])
}

///|
test "PdfDocument attach_file preserves other name trees and accepts slash relationships" {
  let original = attach_blank_document_for_test()
  let javascript_tree = original.build_name_tree([
    (@ascii.encode("script"), PdfString(@ascii.encode("payload"))),
  ])
  original.replace_chain(
    [
      attach_name_for_test("/Root"),
      attach_name_for_test("/Names"),
      attach_name_for_test("/JavaScript"),
    ],
    javascript_tree,
  )
  @test.assert_eq(try! original.size_attached_files(), 0)
  let document = try! original.attach_file(
    "source.txt",
    @ascii.encode("x"),
    relationship=Some("/Source"),
  )
  let with_two = try! document.attach_file("second.txt", @ascii.encode("y"))
  let catalog = attach_catalog_for_test(document)
  let names = attach_lookup_for_test(document, "/Names", catalog)
  let retained = attach_lookup_for_test(document, "/JavaScript", names)
  @test.assert_eq(document.read_name_tree(retained), [
    (@ascii.encode("script"), PdfString(@ascii.encode("payload"))),
  ])
  @test.assert_eq(
    document.read_name_tree(attach_embedded_tree_for_test(with_two)).length(),
    2,
  )
  @test.assert_eq(
    (try! @pdflite.pdf_list_attached_files(document))[0].relationship,
    Some("/Source"),
  )
}

///|
test "PdfDocument attach_file adds page attachment annotation and preserves existing annots" {
  let key_annots = attach_name_for_test("/Annots")
  let key_subtype = attach_name_for_test("/Subtype")
  let key_rect = attach_name_for_test("/Rect")
  let non_file : @syntax.PdfObject = PdfDictionary([
    (key_subtype, PdfNameObject(attach_name_for_test("/Text"))),
    (attach_name_for_test("/Contents"), PdfString(@ascii.encode("kept"))),
  ])
  let second = {
    ..attach_page_for_test(0.0, 0.0, 50.0, 120.0),
    rest: PdfDictionary([(key_annots, PdfArray([non_file]))]),
  }
  let document = attach_document_for_test([
    attach_page_for_test(0.0, 0.0, 100.0, 100.0),
    second,
  ])
  let payload = @ascii.encode("page payload")
  let attached = try! document.attach_file(
    "pages/note.bin",
    payload,
    page_number=Some(2),
  )
  let pages = try! attached.pages_of_pagetree()
  guard pages[1].rest.lookup_immediate(key_annots)
    is Some(
      PdfArray([PdfDictionary(_) as annotation, PdfDictionary(_) as kept])
    ) else {
    fail("expected new file annotation before existing annotation")
  }
  @test.assert_eq(kept, non_file)
  @test.assert_eq(
    annotation.lookup_immediate(key_subtype),
    Some(PdfNameObject(attach_name_for_test("/FileAttachment"))),
  )
  @test.assert_eq(
    annotation.lookup_immediate(attach_name_for_test("/Contents")),
    Some(attach_string_for_test("note.bin")),
  )
  @test.assert_eq(
    annotation.lookup_immediate(key_rect),
    Some(
      PdfArray([PdfReal(18.0), PdfReal(75.0), PdfReal(45.0), PdfReal(102.0)]),
    ),
  )
  let attachments = try! attached.list_attached_files()
  @test.assert_eq(attachments, [
    {
      name: "note.bin",
      pagenumber: 2,
      data: Some(payload),
      description: None,
      relationship: None,
    },
  ])
  @test.assert_eq(try! attached.size_attached_files(), payload.length())
}

///|
test "PdfDocument attach_file can add the first page annotation" {
  let payload = @ascii.encode("first")
  let attached = try! attach_blank_document_for_test().attach_file(
    "first.bin",
    payload,
    page_number=Some(1),
  )
  let pages = try! attached.pages_of_pagetree()
  guard pages[0].rest.lookup_immediate(attach_name_for_test("/Annots"))
    is Some(PdfArray([PdfDictionary(_)])) else {
    fail("expected first annotation array")
  }
  @test.assert_eq(
    try! @pdflite.pdf_size_attached_files(attached),
    payload.length(),
  )
}

///|
test "PdfDocument remove_attached_files removes document and page attachments only" {
  let key_annots = attach_name_for_test("/Annots")
  let key_subtype = attach_name_for_test("/Subtype")
  let non_file : @syntax.PdfObject = PdfDictionary([
    (key_subtype, PdfNameObject(attach_name_for_test("/Text"))),
  ])
  let page = {
    ..attach_page_for_test(0.0, 0.0, 100.0, 100.0),
    rest: PdfDictionary([(key_annots, PdfArray([non_file]))]),
  }
  let document = attach_document_for_test([page])
  let with_document_file = try! document.attach_file(
    "doc.txt",
    @ascii.encode("doc"),
  )
  let with_both = try! with_document_file.attach_file(
    "page.txt",
    @ascii.encode("page"),
    page_number=Some(1),
  )
  @test.assert_eq((try! with_both.list_attached_files()).length(), 2)
  let cleaned = try! @pdflite.pdf_remove_attached_files(with_both)
  @test.assert_eq(try! cleaned.list_attached_files(), [])
  let catalog = attach_catalog_for_test(cleaned)
  let names = attach_lookup_for_test(cleaned, "/Names", catalog)
  @test.assert_eq(
    cleaned.lookup_direct(attach_name_for_test("/EmbeddedFiles"), names),
    None,
  )
  let pages = try! cleaned.pages_of_pagetree()
  @test.assert_eq(
    pages[0].rest.lookup_immediate(key_annots),
    Some(PdfArray([non_file])),
  )
  let no_annots_cleaned = try! attach_blank_document_for_test().remove_attached_files()
  let no_annots_pages = try! no_annots_cleaned.pages_of_pagetree()
  @test.assert_eq(
    no_annots_pages[0].rest.lookup_immediate(key_annots),
    Some(PdfArray([])),
  )
}

///|
test "PdfDocument attach_file rejects non-array page Annots" {
  let page = {
    ..attach_page_for_test(0.0, 0.0, 100.0, 100.0),
    rest: PdfDictionary([(attach_name_for_test("/Annots"), PdfInteger(1))]),
  }
  let document = attach_document_for_test([page])
  let result : Result[@pdflite.PdfDocument, Error] = try
    document.attach_file("bad.txt", @ascii.encode("bad"), page_number=Some(1))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::DictionaryExpected) else {
    fail("expected non-array annots to fail")
  }
}

///|
test "pdf_attachment_remove_unsafe_characters mirrors cpdf filtering" {
  let e_acute = try! @utf8.decode(
    try! @core.pdf_bytes_of_int_array([0xC3, 0xA9]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_attachment_remove_unsafe_characters(
      ".a/b?c<d>e\\f:g*h|i\"j^k+l=m" + e_acute,
    ),
    ".abcdefghijklm" + e_acute,
  )
  @test.assert_eq(
    try! @pdflite.pdf_remove_unsafe_characters("a/b?c"),
    try! @pdflite.pdf_attachment_remove_unsafe_characters("a/b?c"),
  )
}

///|
test "PdfDocument attach_file rejects missing page numbers" {
  let document = attach_blank_document_for_test()
  let low : Result[@pdflite.PdfDocument, Error] = try
    document.attach_file("bad.txt", @ascii.encode("bad"), page_number=Some(0))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard low
    is Err(@core.PdfError::BadPageSpecification("attach_file: Page not found")) else {
    fail("expected low page error")
  }
  let high : Result[@pdflite.PdfDocument, Error] = try
    document.attach_file("bad.txt", @ascii.encode("bad"), page_number=Some(2))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard high
    is Err(@core.PdfError::BadPageSpecification("attach_file: Page not found")) else {
    fail("expected high page error")
  }
}

///|
test "PdfDocument list_attached_files keeps malformed page attachment without data" {
  let key_annots = attach_name_for_test("/Annots")
  let no_subtype : @syntax.PdfObject = PdfDictionary([])
  let no_contents : @syntax.PdfObject = PdfDictionary([
    (
      attach_name_for_test("/Subtype"),
      PdfNameObject(attach_name_for_test("/FileAttachment")),
    ),
  ])
  let no_fs : @syntax.PdfObject = PdfDictionary([
    (
      attach_name_for_test("/Subtype"),
      PdfNameObject(attach_name_for_test("/FileAttachment")),
    ),
    (attach_name_for_test("/Contents"), PdfString(@ascii.encode("no-fs.bin"))),
  ])
  let file_spec : @syntax.PdfObject = PdfDictionary([
    (
      attach_name_for_test("/Type"),
      PdfNameObject(attach_name_for_test("/Filespec")),
    ),
    (attach_name_for_test("/F"), PdfString(@ascii.encode("missing.bin"))),
  ])
  let annotation : @syntax.PdfObject = PdfDictionary([
    (
      attach_name_for_test("/Subtype"),
      PdfNameObject(attach_name_for_test("/FileAttachment")),
    ),
    (attach_name_for_test("/Contents"), PdfString(@ascii.encode("missing.bin"))),
    (attach_name_for_test("/FS"), file_spec),
  ])
  let page = {
    ..attach_page_for_test(0.0, 0.0, 100.0, 100.0),
    rest: PdfDictionary([
      (key_annots, PdfArray([no_subtype, no_contents, no_fs, annotation])),
    ]),
  }
  let document = attach_document_for_test([page])
  @test.assert_eq(try! @pdflite.pdf_list_attached_files(document), [
    {
      name: "missing.bin",
      pagenumber: 1,
      data: None,
      description: None,
      relationship: None,
    },
  ])
  let size_result : Result[Int, Error] = try
    document.size_attached_files()
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard size_result is Err(_) else {
    fail("expected missing attachment stream to fail size calculation")
  }
}

///|
test "PdfDocument list_attached_files ignores non-ASCII relationship names" {
  let payload = @ascii.encode("ok")
  let stream = @syntax.pdf_stream(
    PdfDictionary([
      (attach_name_for_test("/Length"), PdfInteger(payload.length())),
    ]),
    StreamGot(payload),
  )
  let bad_relationship = @core.pdf_name_of_bytes(
    try! @core.pdf_bytes_of_int_array([0xFF]),
  )
  let file_spec : @syntax.PdfObject = PdfDictionary([
    (
      attach_name_for_test("/EF"),
      PdfDictionary([(attach_name_for_test("/F"), stream)]),
    ),
    (attach_name_for_test("/AFRelationship"), PdfNameObject(bad_relationship)),
  ])
  let annotation : @syntax.PdfObject = PdfDictionary([
    (
      attach_name_for_test("/Subtype"),
      PdfNameObject(attach_name_for_test("/FileAttachment")),
    ),
    (attach_name_for_test("/Contents"), PdfString(@ascii.encode("bad-rel.bin"))),
    (attach_name_for_test("/FS"), file_spec),
  ])
  let page = {
    ..attach_page_for_test(0.0, 0.0, 100.0, 100.0),
    rest: PdfDictionary([
      (attach_name_for_test("/Annots"), PdfArray([annotation])),
    ]),
  }
  let attachments = try! attach_document_for_test([page]).list_attached_files()
  @test.assert_eq(attachments.length(), 1)
  @test.assert_eq(attachments[0].data, Some(payload))
  @test.assert_eq(attachments[0].relationship, None)
}

///|
test "PdfDocument list_attached_files rejects malformed document attachment data" {
  let document = attach_blank_document_for_test()
  let file_spec_number = document.add_object(
    PdfDictionary([
      (
        attach_name_for_test("/Type"),
        PdfNameObject(attach_name_for_test("/Filespec")),
      ),
      (attach_name_for_test("/F"), PdfString(@ascii.encode("broken.bin"))),
    ]),
  )
  let tree_number = document.add_object(
    document.build_name_tree([
      (@ascii.encode("broken.bin"), PdfIndirect(file_spec_number)),
    ]),
  )
  document.replace_chain(
    [
      attach_name_for_test("/Root"),
      attach_name_for_test("/Names"),
      attach_name_for_test("/EmbeddedFiles"),
    ],
    PdfIndirect(tree_number),
  )
  let result : Result[Array[@attachment.PdfAttachment], Error] = try
    document.list_attached_files()
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard result is Err(@core.PdfError::DictionaryKeyNotFound(_)) else {
    fail("expected malformed document attachment to fail")
  }
}

///|
test "PdfDocument list and size reject file specs with EF but no F stream" {
  let key_annots = attach_name_for_test("/Annots")
  let file_spec : @syntax.PdfObject = PdfDictionary([
    (attach_name_for_test("/EF"), PdfDictionary([])),
  ])
  let annotation : @syntax.PdfObject = PdfDictionary([
    (
      attach_name_for_test("/Subtype"),
      PdfNameObject(attach_name_for_test("/FileAttachment")),
    ),
    (attach_name_for_test("/Contents"), PdfString(@ascii.encode("bad.bin"))),
    (attach_name_for_test("/FS"), file_spec),
  ])
  let page = {
    ..attach_page_for_test(0.0, 0.0, 100.0, 100.0),
    rest: PdfDictionary([(key_annots, PdfArray([annotation]))]),
  }
  let document = attach_document_for_test([page])
  let list_result : Result[Array[@attachment.PdfAttachment], Error] = try
    document.list_attached_files()
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard list_result is Err(@core.PdfError::DictionaryKeyNotFound(_)) else {
    fail("expected missing /F to fail listing")
  }
  let size_result : Result[Int, Error] = try
    document.size_attached_files()
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard size_result is Err(@core.PdfError::DictionaryKeyNotFound(_)) else {
    fail("expected missing /F to fail sizing")
  }
}
