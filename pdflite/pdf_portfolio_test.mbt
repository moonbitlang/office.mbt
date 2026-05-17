///|
fn portfolio_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn portfolio_string_for_test(text : String) -> @pdflite.PdfObject {
  PdfString(@utf8.encode(text))
}

///|
fn portfolio_blank_doc_for_test() -> @pdflite.PdfDocument {
  try! @pdflite.pdf_minimum_valid_pdf()
}

///|
fn portfolio_lookup_for_test(
  document : @pdflite.PdfDocument,
  key : String,
  object : @pdflite.PdfObject,
) -> @pdflite.PdfObject raise {
  match document.lookup_direct(portfolio_name_for_test(key), object) {
    Some(value) => value
    None => fail("missing key " + key)
  }
}

///|
fn portfolio_catalog_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfObject {
  try! document.catalog()
}

///|
fn portfolio_embedded_tree_for_test(
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfObject raise {
  let catalog = portfolio_catalog_for_test(document)
  let names = portfolio_lookup_for_test(document, "/Names", catalog)
  portfolio_lookup_for_test(document, "/EmbeddedFiles", names)
}

///|
fn portfolio_stream_for_test(
  document : @pdflite.PdfDocument,
  file_spec : @pdflite.PdfObject,
) -> @pdflite.PdfObject raise {
  let ef = portfolio_lookup_for_test(document, "/EF", file_spec)
  let stream = portfolio_lookup_for_test(document, "/F", ef)
  @test.assert_eq(portfolio_lookup_for_test(document, "/UF", ef), stream)
  stream
}

///|
fn portfolio_assert_file_spec_for_test(
  document : @pdflite.PdfDocument,
  object : @pdflite.PdfObject,
  basename : String,
  description : String,
  relationship : String,
  payload : @pdflite.PdfBytes,
  mod_date : @pdflite.PdfBytes,
) -> Unit raise {
  let file_spec = document.direct(object)
  @test.assert_eq(
    portfolio_lookup_for_test(document, "/Type", file_spec),
    PdfNameObject(portfolio_name_for_test("/FileSpec")),
  )
  @test.assert_eq(
    portfolio_lookup_for_test(document, "/Desc", file_spec),
    portfolio_string_for_test(description),
  )
  @test.assert_eq(
    portfolio_lookup_for_test(document, "/F", file_spec),
    portfolio_string_for_test(basename),
  )
  @test.assert_eq(
    portfolio_lookup_for_test(document, "/UF", file_spec),
    portfolio_string_for_test(basename),
  )
  @test.assert_eq(
    portfolio_lookup_for_test(document, "/AFRelationship", file_spec),
    PdfNameObject(portfolio_name_for_test(relationship)),
  )
  let stream = portfolio_stream_for_test(document, file_spec)
  @test.assert_eq(try! stream.stream_bytes(), payload)
  guard stream is PdfStreamObject(stream_object) else {
    fail("expected embedded file stream")
  }
  @test.assert_eq(
    portfolio_lookup_for_test(document, "/Length", stream_object.dictionary),
    PdfInteger(payload.length()),
  )
  let params = portfolio_lookup_for_test(
    document,
    "/Params",
    stream_object.dictionary,
  )
  @test.assert_eq(
    portfolio_lookup_for_test(document, "/ModDate", params),
    PdfString(mod_date),
  )
  @test.assert_eq(
    portfolio_lookup_for_test(document, "/Size", params),
    PdfInteger(payload.length()),
  )
}

///|
test "PdfDocument portfolio builds embedded files name tree" {
  let mod_date = @ascii.encode("D:20240102030405")
  let first_payload = @ascii.encode("first payload")
  let second_payload = @ascii.encode("second payload")
  let document = try! portfolio_blank_doc_for_test().portfolio(
    [
      @pdflite.pdf_portfolio_entry(
        "fixtures/report.txt",
        first_payload,
        relationship=Some("Data"),
        description=Some("Annual report"),
      ),
      @pdflite.pdf_portfolio_entry("more/report.txt", second_payload),
    ],
    mod_date=Some(mod_date),
  )
  let tree = portfolio_embedded_tree_for_test(document)
  let entries = document.read_name_tree(tree)
  @test.assert_eq(entries.length(), 2)
  @test.assert_eq(entries[0].0, @utf8.encode("0/fixtures/report.txt"))
  @test.assert_eq(entries[1].0, @utf8.encode("1/more/report.txt"))
  portfolio_assert_file_spec_for_test(
    document,
    entries[0].1,
    "report.txt",
    "Annual report",
    "/Data",
    first_payload,
    mod_date,
  )
  portfolio_assert_file_spec_for_test(
    document,
    entries[1].1,
    "report.txt",
    "report.txt",
    "/Unspecified",
    second_payload,
    mod_date,
  )
  let catalog = portfolio_catalog_for_test(document)
  let collection = portfolio_lookup_for_test(document, "/Collection", catalog)
  @test.assert_eq(
    portfolio_lookup_for_test(document, "/View", collection),
    PdfNameObject(portfolio_name_for_test("/T")),
  )
}

///|
test "PdfDocument portfolio preserves other root name trees" {
  let original = portfolio_blank_doc_for_test()
  let javascript_tree = original.build_name_tree([
    (@ascii.encode("script"), PdfString(@ascii.encode("payload"))),
  ])
  original.replace_chain(
    [
      portfolio_name_for_test("/Root"),
      portfolio_name_for_test("/Names"),
      portfolio_name_for_test("/JavaScript"),
    ],
    javascript_tree,
  )
  let document = try! original.portfolio(
    [@pdflite.pdf_portfolio_entry("attached.txt", @ascii.encode("attached"))],
    mod_date=Some(@ascii.encode("D:20240102030405")),
  )
  let catalog = portfolio_catalog_for_test(document)
  let names = portfolio_lookup_for_test(document, "/Names", catalog)
  guard document.lookup_direct(portfolio_name_for_test("/EmbeddedFiles"), names)
    is Some(_) else {
    fail("expected EmbeddedFiles name tree")
  }
  let retained = portfolio_lookup_for_test(document, "/JavaScript", names)
  @test.assert_eq(document.read_name_tree(retained), [
    (@ascii.encode("script"), PdfString(@ascii.encode("payload"))),
  ])
}

///|
test "PdfDocument portfolio handles empty entries" {
  let document = try! portfolio_blank_doc_for_test().portfolio(
    [],
    mod_date=Some(@ascii.encode("D:20240102030405")),
  )
  @test.assert_eq(
    document.read_name_tree(portfolio_embedded_tree_for_test(document)),
    [],
  )
  let catalog = portfolio_catalog_for_test(document)
  guard document.lookup_direct(portfolio_name_for_test("/Collection"), catalog)
    is Some(_) else {
    fail("expected collection dictionary")
  }
}

///|
test "PdfDocument portfolio rejects documents without a catalog" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_document_empty().portfolio(
    [@pdflite.pdf_portfolio_entry("file.txt", @ascii.encode("payload"))],
    mod_date=Some(@ascii.encode("D:20240102030405")),
  )
  guard result is Err(_) else {
    fail("expected portfolio on malformed document to fail")
  }
}
