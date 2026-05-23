///|
fn metadata_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn metadata_lookup_for_test(
  doc : @pdflite.PdfDocument,
  object : @pdflite.PdfObject,
  key : String,
) -> @pdflite.PdfObject? {
  doc.lookup_direct(metadata_name_for_test(key), object)
}

///|
fn metadata_catalog_for_test(doc : @pdflite.PdfDocument) -> @pdflite.PdfObject {
  try! doc.catalog()
}

///|
fn metadata_replace_catalog_for_test(
  doc : @pdflite.PdfDocument,
  catalog : @pdflite.PdfObject,
) -> @pdflite.PdfDocument {
  let updated = doc.copy()
  let catalog_number = updated.add_object(catalog)
  updated.set_root(catalog_number)
  updated.set_trailer_dict(
    try! updated
    .trailer_dict()
    .add_dict_entry(
      metadata_name_for_test("/Root"),
      PdfIndirect(catalog_number),
    ),
  )
  updated
}

///|
fn metadata_rect_for_test(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @pdflite.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn metadata_document_with_pages_for_test(
  pages : ArrayView[@pdflite.PdfPage],
) -> @pdflite.PdfDocument {
  let document = @pdflite.pdf_document_empty()
  let page_root = try! document.add_pagetree(pages)
  ignore(try! document.add_root(page_root, []))
  document
}

///|
test "pdf_metadata_encode_output preserves raw utf8 and stripped forms" {
  let snowman = try! @pdflite.pdf_pdfdocstring_of_utf8(@utf8.encode("A ☃ B"))
  @test.assert_eq(
    try! @pdflite.pdf_metadata_encode_output(PdfMetadataRaw, snowman),
    snowman,
  )
  @test.assert_eq(
    try! @pdflite.pdf_metadata_encode_output(PdfMetadataUTF8, snowman),
    @utf8.encode("A ☃ B"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_encode_output(PdfMetadataUTF8, snowman),
    @utf8.encode("A ☃ B"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_metadata_encode_output(PdfMetadataStripped, snowman),
    @ascii.encode("A  B"),
  )
  @test.assert_eq(
    try! @pdflite.pdf_encode_output(PdfMetadataStripped, snowman),
    @ascii.encode("A  B"),
  )
}

///|
test "PdfDocument copy_id_from copies trailer ID and bumps version" {
  let key_id = metadata_name_for_test("/ID")
  let source = try! @pdflite.pdf_minimum_valid_pdf()
  let id : @pdflite.PdfObject = PdfArray([
    PdfString(@ascii.encode("first-id")),
    PdfString(@ascii.encode("second-id")),
  ])
  source.set_trailer_dict(source.trailer_dict().add_dict_entry(key_id, id))
  let target = try! @pdflite.pdf_minimum_valid_pdf()
  let copied = try! target.copy_id_from(source)
  @test.assert_eq(
    metadata_lookup_for_test(copied, copied.trailer_dict(), "/ID"),
    Some(id),
  )
  @test.assert_eq(copied.version(), (1, 1))
  let kept = try! target.copy_id_from(source, keep_version=true)
  @test.assert_eq(kept.version(), (1, 0))
}

///|
test "PdfDocument set_info_entry stores PDF info and decodes UTF8" {
  let key_title = metadata_name_for_test("/Title")
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let title = try! @pdflite.pdf_pdfdocstring_of_utf8(@utf8.encode("Résumé"))
  let updated = try! doc.set_info_entry(key_title, PdfString(title), 4)
  @test.assert_eq(updated.version(), (1, 4))
  @test.assert_eq(updated.info_utf8(key_title), "Résumé")
  @test.assert_eq(updated.info_utf8_string("/Title"), "Résumé")
  @test.assert_eq(@pdflite.pdf_get_info_utf8(updated, key_title), "Résumé")
  @test.assert_eq(
    @pdflite.pdf_get_info_utf8_string(updated, "/Title"),
    "Résumé",
  )
  @test.assert_eq(
    updated.info_utf8(metadata_name_for_test("/Trapped")),
    "False",
  )
  @test.assert_eq(doc.info_utf8(key_title), "")
}

///|
test "PdfDocument viewer preferences and catalog items use cpdf strings" {
  let key_hide_toolbar = metadata_name_for_test("/HideToolbar")
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let updated = try! doc
    .set_page_layout("TwoColumnLeft")
    .set_page_mode("FullScreen")
    .set_non_full_screen_page_mode("UseThumbs")
    .set_viewer_preference(key_hide_toolbar, PdfBoolean(true), 4)
  @test.assert_eq(
    updated.catalog_item(metadata_name_for_test("/PageLayout")),
    "TwoColumnLeft",
  )
  @test.assert_eq(
    updated.catalog_item(metadata_name_for_test("/PageMode")),
    "FullScreen",
  )
  @test.assert_eq(
    updated.viewer_preference_item(
      metadata_name_for_test("/NonFullScreenPageMode"),
    ),
    "UseThumbs",
  )
  @test.assert_eq(updated.viewer_preference_item(key_hide_toolbar), "true")
  let wrapped = try! @pdflite.pdf_set_viewer_preference(
    key_hide_toolbar,
    PdfBoolean(false),
    4,
    try! @pdflite.pdf_set_non_full_screen_page_mode(
      try! @pdflite.pdf_set_page_mode(
        try! @pdflite.pdf_set_page_layout(doc, "OneColumn"),
        "UseThumbs",
      ),
      "UseOC",
    ),
  )
  @test.assert_eq(
    @pdflite.pdf_get_catalog_item(
      metadata_name_for_test("/PageLayout"),
      wrapped,
    ),
    "OneColumn",
  )
  @test.assert_eq(
    @pdflite.pdf_get_catalog_item_string("/PageLayout", wrapped),
    "OneColumn",
  )
  @test.assert_eq(
    @pdflite.pdf_get_catalog_item_cpdf_order("/PageLayout", wrapped),
    "OneColumn",
  )
  @test.assert_eq(
    @pdflite.pdf_get_viewer_pref_item(key_hide_toolbar, wrapped),
    "false",
  )
  @test.assert_eq(
    @pdflite.pdf_get_viewer_pref_item_string("/HideToolbar", wrapped),
    "false",
  )
  @test.assert_eq(
    @pdflite.pdf_get_viewer_pref_item_cpdf_order("/HideToolbar", wrapped),
    "false",
  )
  let tuple_wrapped = try! @pdflite.pdf_set_viewer_preference_cpdf_order(
    ("/HideToolbar", PdfBoolean(true), 4),
    doc,
  )
  @test.assert_eq(
    tuple_wrapped.viewer_preference_item_string("/HideToolbar"),
    "true",
  )
  let tuple_alias = try! @pdflite.pdf_set_viewer_preference_string(
    ("/HideMenubar", PdfBoolean(true), 4),
    tuple_wrapped,
  )
  @test.assert_eq(
    tuple_alias.viewer_preference_item_string("/HideMenubar"),
    "true",
  )
  let invalid : Result[@pdflite.PdfDocument, Error] = try? doc.set_page_layout(
    "Rows",
  )
  guard invalid is Err(@pdflite.PdfError::BadNumberArgument(_)) else {
    fail("expected bad page layout")
  }
}

///|
test "PdfDocument set_open_action writes fit xyz and custom destinations" {
  let doc = try! @pdflite.pdf_blank_document_paper(@pdflite.paper_a4, 2)
  let page_refs = try! doc.page_reference_numbers()
  let fit_doc = try! doc.set_open_action(2)
  guard metadata_lookup_for_test(
      fit_doc,
      metadata_catalog_for_test(fit_doc),
      "/OpenAction",
    )
    is Some(PdfDictionary(fit_entries)) else {
    fail("expected OpenAction dictionary")
  }
  let fit_action : @pdflite.PdfObject = PdfDictionary(fit_entries)
  @test.assert_eq(
    metadata_lookup_for_test(fit_doc, fit_action, "/D"),
    Some(
      PdfArray([
        PdfIndirect(page_refs[1]),
        PdfNameObject(metadata_name_for_test("/Fit")),
      ]),
    ),
  )
  let xyz_doc = try! doc.set_open_action(1, fit=false)
  guard metadata_lookup_for_test(
      xyz_doc,
      metadata_catalog_for_test(xyz_doc),
      "/OpenAction",
    )
    is Some(PdfDictionary(xyz_entries)) else {
    fail("expected XYZ OpenAction dictionary")
  }
  @test.assert_eq(
    metadata_lookup_for_test(xyz_doc, PdfDictionary(xyz_entries), "/D"),
    Some(
      PdfArray([
        PdfIndirect(page_refs[0]),
        PdfNameObject(metadata_name_for_test("/XYZ")),
        PdfNull,
        PdfNull,
        PdfNull,
      ]),
    ),
  )
  let custom = try! doc.set_open_action(
    1,
    destination=Some(
      PdfArray([
        PdfInteger(2),
        PdfNameObject(metadata_name_for_test("/FitH")),
        PdfInteger(12),
      ]),
    ),
  )
  guard metadata_lookup_for_test(
      custom,
      metadata_catalog_for_test(custom),
      "/OpenAction",
    )
    is Some(PdfDictionary(custom_entries)) else {
    fail("expected custom OpenAction dictionary")
  }
  @test.assert_eq(
    metadata_lookup_for_test(custom, PdfDictionary(custom_entries), "/D"),
    Some(
      PdfArray([
        PdfIndirect(page_refs[1]),
        PdfNameObject(metadata_name_for_test("/FitH")),
        PdfInteger(12),
      ]),
    ),
  )
  let string_custom = try! doc.set_open_action_string_destination(
    1,
    destination=Some("[2 /FitH 12]"),
  )
  guard metadata_lookup_for_test(
      string_custom,
      metadata_catalog_for_test(string_custom),
      "/OpenAction",
    )
    is Some(PdfDictionary(string_entries)) else {
    fail("expected string custom OpenAction dictionary")
  }
  @test.assert_eq(
    metadata_lookup_for_test(string_custom, PdfDictionary(string_entries), "/D"),
    Some(
      PdfArray([
        PdfIndirect(page_refs[1]),
        PdfNameObject(metadata_name_for_test("/FitH")),
        PdfInteger(12),
      ]),
    ),
  )
  let string_wrapped = try! @pdflite.pdf_set_open_action_string_destination(
    doc,
    true,
    1,
    destination=Some("[2 /FitH 12]"),
  )
  @test.assert_eq(
    try! string_wrapped.open_action(),
    PdfArray([
      PdfInteger(2),
      PdfNameObject(metadata_name_for_test("/FitH")),
      PdfInteger(12),
    ]),
  )
  let cpdf_order_wrapped = try! @pdflite.pdf_set_open_action_cpdf_order(
    doc,
    true,
    1,
    destination=Some("[2 /FitH 12]"),
  )
  @test.assert_eq(
    try! cpdf_order_wrapped.open_action(),
    PdfArray([
      PdfInteger(2),
      PdfNameObject(metadata_name_for_test("/FitH")),
      PdfInteger(12),
    ]),
  )
  let bad_destination : Result[@pdflite.PdfDocument, Error] = try? doc.set_open_action_string_destination(
    1,
    destination=Some("/Fit"),
  )
  guard bad_destination is Err(@pdflite.PdfError::BadNumberArgument(_)) else {
    fail("expected bad open-action destination syntax")
  }
  let invalid : Result[@pdflite.PdfDocument, Error] = try? doc.set_open_action(
    3,
  )
  guard invalid is Err(@pdflite.PdfError::BadPageSpecification(_)) else {
    fail("expected bad open-action page")
  }
}

///|
test "PdfDocument metadata report helpers rewrite open action and JSON" {
  let doc = try! @pdflite.pdf_blank_document_paper(@pdflite.paper_a4, 2)
  let open_doc = try! doc.set_open_action(2, fit=false)
  let expected_object : @pdflite.PdfObject = PdfArray([
    PdfInteger(2),
    PdfNameObject(metadata_name_for_test("/XYZ")),
    PdfNull,
    PdfNull,
    PdfNull,
  ])
  let expected_json : Json = [{ "I": 2.0 }, { "N": "/XYZ" }, null, null, null]
  @test.assert_eq(try! open_doc.open_action(), expected_object)
  @test.assert_eq(
    try! open_doc.open_action_json_blob(),
    @utf8.encode(expected_json.stringify()),
  )
  @test.assert_eq(
    try! @pdflite.pdf_get_open_action_json_blob(open_doc),
    @utf8.encode(expected_json.stringify()),
  )
  @test.assert_eq(
    try! open_doc.open_action_string(),
    try! @ascii.decode(try! @pdflite.pdf_write_object(expected_object)),
  )
  @test.assert_eq(
    try! @pdflite.pdf_get_open_action_string(open_doc),
    try! open_doc.open_action_string(),
  )
  @test.assert_eq(
    try! @pdflite.pdf_set_open_action(doc, true, 1).open_action(),
    PdfArray([PdfInteger(1), PdfNameObject(metadata_name_for_test("/Fit"))]),
  )
  @test.assert_eq(try! doc.open_action(), PdfNull)
  @test.assert_eq(try! doc.open_action_string(), "")
}

///|
test "PdfDocument metadata report helpers cover mark info XFA version language" {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let catalog_with_mark = try! metadata_catalog_for_test(doc).add_dict_entry(
    metadata_name_for_test("/MarkInfo"),
    @pdflite.pdf_dictionary([
      (metadata_name_for_test("/Marked"), PdfBoolean(true)),
      (metadata_name_for_test("/Suspects"), PdfBoolean(false)),
    ]),
  )
  let catalog_with_xfa = try! catalog_with_mark.add_dict_entry(
    metadata_name_for_test("/AcroForm"),
    @pdflite.pdf_dictionary([
      (metadata_name_for_test("/XFA"), PdfString(@ascii.encode("xfa"))),
    ]),
  )
  let reported = metadata_replace_catalog_for_test(doc, catalog_with_xfa)
  @test.assert_eq(
    reported.mark_info_item(metadata_name_for_test("/Marked")),
    true,
  )
  @test.assert_eq(
    @pdflite.pdf_get_mark_info_item(metadata_name_for_test("/Marked"), reported),
    true,
  )
  @test.assert_eq(
    reported.mark_info_item(metadata_name_for_test("/Suspects")),
    false,
  )
  @test.assert_eq(reported.is_xfa(), true)
  @test.assert_eq(@pdflite.pdf_is_xfa(reported), true)
  let version_doc = try! @pdflite.pdf_minimum_valid_pdf()
  @pdflite.pdf_set_version(7, version_doc)
  @test.assert_eq(version_doc.version(), (1, 7))
  let language_doc = try! @pdflite.pdf_set_language(doc, @ascii.encode("fr-FR"))
  @test.assert_eq(
    @pdflite.pdf_language(language_doc),
    Some(@ascii.encode("fr-FR")),
  )
}

///|
test "PdfDocument info_json reports document fields and page boxes" {
  let media = metadata_rect_for_test(0.0, 0.0, 72.0, 144.0)
  let trim = metadata_rect_for_test(0.0, 0.0, 36.0, 72.0)
  let page1 = {
    ..@pdflite.pdf_page_custom(media),
    rest: PdfDictionary([
      (
        metadata_name_for_test("/CropBox"),
        metadata_rect_for_test(0.0, 0.0, 36.0, 36.0),
      ),
      (metadata_name_for_test("/TrimBox"), trim),
      (
        metadata_name_for_test("/ArtBox"),
        PdfNameObject(metadata_name_for_test("/Malformed")),
      ),
    ]),
  }
  let page2 = {
    ..@pdflite.pdf_page_custom(media),
    rest: PdfDictionary([
      (
        metadata_name_for_test("/CropBox"),
        metadata_rect_for_test(0.0, 0.0, 72.0, 72.0),
      ),
      (metadata_name_for_test("/TrimBox"), trim),
      (
        metadata_name_for_test("/ArtBox"),
        PdfNameObject(metadata_name_for_test("/Malformed")),
      ),
    ]),
  }
  let base = metadata_document_with_pages_for_test([page1, page2])
  let title = try! @pdflite.pdf_pdfdocstring_of_utf8(
    @utf8.encode("Résumé ☃"),
  )
  let with_info = try! base
    .set_info_entry(
      metadata_name_for_test("/Title"),
      PdfString(title),
      4,
      keep_version=true,
    )
    .set_info_entry(
      metadata_name_for_test("/Author"),
      PdfString(@ascii.encode("Ada")),
      4,
      keep_version=true,
    )
    .set_info_entry(
      metadata_name_for_test("/Subject"),
      PdfString(@ascii.encode("Metadata")),
      4,
      keep_version=true,
    )
    .set_info_entry(
      metadata_name_for_test("/Keywords"),
      PdfString(@ascii.encode("pdf,test")),
      4,
      keep_version=true,
    )
    .set_info_entry(
      metadata_name_for_test("/Creator"),
      PdfString(@ascii.encode("pdflite-test")),
      4,
      keep_version=true,
    )
    .set_info_entry(
      metadata_name_for_test("/Producer"),
      PdfString(@ascii.encode("pdflite")),
      4,
      keep_version=true,
    )
    .set_info_entry(
      metadata_name_for_test("/CreationDate"),
      PdfString(@ascii.encode("D:20260517010203Z")),
      4,
      keep_version=true,
    )
    .set_info_entry(
      metadata_name_for_test("/ModDate"),
      PdfString(@ascii.encode("D:20260518040506Z")),
      4,
      keep_version=true,
    )
    .set_info_entry(
      metadata_name_for_test("/Trapped"),
      PdfBoolean(true),
      4,
      keep_version=true,
    )
  let with_preferences = try! with_info
    .set_page_layout("SinglePage")
    .set_page_mode("UseOutlines")
    .set_non_full_screen_page_mode("UseThumbs")
    .set_viewer_preference(
      metadata_name_for_test("/HideToolbar"),
      PdfBoolean(true),
      4,
      keep_version=true,
    )
    .set_viewer_preference(
      metadata_name_for_test("/DisplayDocTitle"),
      PdfBoolean(false),
      4,
      keep_version=true,
    )
    .set_open_action(2, fit=false)
  let catalog_with_mark = try! metadata_catalog_for_test(with_preferences).add_dict_entry(
    metadata_name_for_test("/MarkInfo"),
    @pdflite.pdf_dictionary([
      (metadata_name_for_test("/Marked"), PdfBoolean(true)),
      (metadata_name_for_test("/UserProperties"), PdfBoolean(true)),
      (metadata_name_for_test("/Suspects"), PdfBoolean(false)),
    ]),
  )
  let catalog_with_acroform = try! catalog_with_mark.add_dict_entry(
    metadata_name_for_test("/AcroForm"),
    @pdflite.pdf_dictionary([
      (metadata_name_for_test("/XFA"), PdfString(@ascii.encode("xfa"))),
    ]),
  )
  let reported = metadata_replace_catalog_for_test(
    with_preferences, catalog_with_acroform,
  )
  @pdflite.pdf_set_version(7, reported)
  let expected : Json = {
    "AcroForm": true,
    "ArtBox": null,
    "Author": "Ada",
    "BleedBox": null,
    "CenterWindow": null,
    "Created": "D:20260517010203Z",
    "Creator": "pdflite-test",
    "CropBox": "various",
    "DisplayDocTitle": false,
    "FitWindow": null,
    "HideMenubar": null,
    "HideToolbar": true,
    "HideWindowUI": null,
    "Keywords": "pdf,test",
    "Marked": true,
    "MediaBox": [0.0, 0.0, 1.0, 2.0],
    "Modified": "D:20260518040506Z",
    "NonFullPageScreenMode": "UseThumbs",
    "OpenAction": [{ "I": 2.0 }, { "N": "/XYZ" }, null, null, null],
    "PageLayout": "SinglePage",
    "PageMode": "UseOutlines",
    "Pages": 2.0,
    "Producer": "pdflite",
    "Subject": "Metadata",
    "Suspects": false,
    "Title": "Résumé ☃",
    "Trapped": true,
    "TrimBox": [0.0, 0.0, 0.5, 1.0],
    "UserProperties": true,
    "Version": [1.0, 7.0],
    "XFA": true,
  }
  @test.assert_eq(try! reported.info_json(unit=Inch), expected)
  @test.assert_eq(
    try! @pdflite.pdf_output_info_json_blob(reported, unit=Inch),
    @utf8.encode((try! reported.info_json(unit=Inch)).stringify()),
  )
  let stripped_report = try! reported.info_json(
    encoding=PdfMetadataStripped,
    unit=Inch,
  )
  match stripped_report {
    Object(entries) =>
      @test.assert_eq(entries.get("Title"), Some(Json::string("Rsum ")))
    _ => fail("expected JSON object")
  }
}

///|
test "PdfDocument language getter and setter preserve original document" {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  @test.assert_eq(doc.language(), None)
  @test.assert_eq(doc.language_string(), None)
  let updated = try! doc.set_language(@ascii.encode("en-US"))
  @test.assert_eq(updated.language(), Some(@ascii.encode("en-US")))
  @test.assert_eq(updated.language_string(), Some("en-US"))
  @test.assert_eq(doc.language(), None)
  let wrapped = try! @pdflite.pdf_set_language_string(doc, "fr-FR")
  @test.assert_eq(@pdflite.pdf_language_string(wrapped), Some("fr-FR"))
}

///|
test "PdfDocument metadata stream set get remove and remove_all" {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let data = @ascii.encode("<xmp>metadata</xmp>")
  let no_metadata = try! doc.remove_metadata()
  @test.assert_eq(try! no_metadata.metadata(), None)
  let updated = try! doc.set_metadata_from_bytes(data)
  @test.assert_eq(updated.version(), (1, 4))
  @test.assert_eq(try! updated.metadata(), Some(data))
  guard metadata_lookup_for_test(
      updated,
      metadata_catalog_for_test(updated),
      "/Metadata",
    )
    is Some(PdfStreamObject(_) | PdfIndirect(_)) else {
    fail("expected metadata catalog entry")
  }
  let removed = try! updated.remove_metadata()
  @test.assert_eq(try! removed.metadata(), None)
  @test.assert_eq(try! updated.metadata(), Some(data))
  let compressed = doc.copy()
  let encoded = @pdflite.pdf_flate_encode(data)
  let metadata_number = compressed.add_object(
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (metadata_name_for_test("/Length"), PdfInteger(encoded.length())),
        (
          metadata_name_for_test("/Type"),
          PdfNameObject(metadata_name_for_test("/Metadata")),
        ),
        (
          metadata_name_for_test("/Subtype"),
          PdfNameObject(metadata_name_for_test("/XML")),
        ),
        (
          metadata_name_for_test("/Filter"),
          PdfNameObject(metadata_name_for_test("/FlateDecode")),
        ),
      ]),
      StreamGot(encoded),
    ),
  )
  let catalog_number = compressed.add_object(
    try! metadata_catalog_for_test(compressed).add_dict_entry(
      metadata_name_for_test("/Metadata"),
      PdfIndirect(metadata_number),
    ),
  )
  compressed.set_root(catalog_number)
  compressed.set_trailer_dict(
    try! compressed
    .trailer_dict()
    .add_dict_entry(
      metadata_name_for_test("/Root"),
      PdfIndirect(catalog_number),
    ),
  )
  @test.assert_eq(try! compressed.metadata(), Some(data))
  let stray = updated.copy()
  let stray_number = stray.add_object(
    @pdflite.pdf_stream(
      @pdflite.pdf_dictionary([
        (
          metadata_name_for_test("/Type"),
          PdfNameObject(metadata_name_for_test("/Metadata")),
        ),
      ]),
      StreamGot(@ascii.encode("stray")),
    ),
  )
  let cleaned = try! stray.remove_all_metadata()
  @test.assert_eq(try! cleaned.metadata(), None)
  @test.assert_eq(cleaned.lookup_object_or_null(stray_number), PdfNull)
}

///|
test "PdfDocument set_metadata_date rewrites XMP metadata date fields" {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let xmp_text =
    #|<x:xmpmeta xmlns:x="adobe:ns:meta/"
    #| xmlns:xmp="http://ns.adobe.com/xap/1.0/"
    #| xmlns:m="http://ns.adobe.com/xap/1.0/">
    #| <xmp:MetadataDate>old</xmp:MetadataDate>
    #| <m:MetadataDate custom="1"/>
    #|</x:xmpmeta>
  let with_metadata = try! doc.set_metadata_from_bytes(@ascii.encode(xmp_text))
  let updated = try! @pdflite.pdf_set_metadata_date(
    with_metadata, "2026-05-17T00:00:00Z",
  )
  guard (try! updated.metadata()) is Some(updated_metadata) else {
    fail("expected updated metadata")
  }
  let updated_text = try! @ascii.decode(updated_metadata)
  let self_closing_rewrite =
    #|<m:MetadataDate custom="1">2026-05-17T00:00:00Z</m:MetadataDate>
  @test.assert_eq(
    updated_text.contains(
      "<xmp:MetadataDate>2026-05-17T00:00:00Z</xmp:MetadataDate>",
    ),
    true,
  )
  @test.assert_eq(updated_text.contains(self_closing_rewrite), true)
  @test.assert_eq(updated.version(), (1, 4))
  let escaped = try! with_metadata.set_metadata_date("A&B<C>")
  guard (try! escaped.metadata()) is Some(escaped_metadata) else {
    fail("expected escaped metadata")
  }
  @test.assert_eq(
    (try! @ascii.decode(escaped_metadata)).contains(
      "<xmp:MetadataDate>A&amp;B&lt;C&gt;</xmp:MetadataDate>",
    ),
    true,
  )
  @test.assert_eq(try! doc.set_metadata_date("2026").metadata(), None)
}

///|
test "PdfDocument set_metadata_date expands reproducible now" {
  let previous = @env.get_env_var("CPDF_REPRODUCIBLE_DATES")
  @env.set_env_var("CPDF_REPRODUCIBLE_DATES", "true")
  @test.assert_eq(@pdflite.pdf_expand_date("now"), "D:39000101000000")
  @test.assert_eq(
    @pdflite.pdf_expand_date("D:20260522112233"),
    "D:20260522112233",
  )
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let xmp_text =
    #|<x:xmpmeta xmlns:xmp="http://ns.adobe.com/xap/1.0/">
    #| <xmp:MetadataDate>old</xmp:MetadataDate>
    #|</x:xmpmeta>
  let with_metadata = try! doc.set_metadata_from_bytes(@ascii.encode(xmp_text))
  let updated = try! with_metadata.set_metadata_date("now")
  match previous {
    Some(value) => @env.set_env_var("CPDF_REPRODUCIBLE_DATES", value)
    None => @env.unset_env_var("CPDF_REPRODUCIBLE_DATES")
  }
  guard (try! updated.metadata()) is Some(updated_metadata) else {
    fail("expected updated metadata")
  }
  @test.assert_eq(
    (try! @ascii.decode(updated_metadata)).contains(
      "<xmp:MetadataDate>3900-01-01T00:00:00Z</xmp:MetadataDate>",
    ),
    true,
  )
}

///|
test "PdfDocument create_metadata builds cpdf XMP template from Info" {
  let previous = @env.get_env_var("CPDF_REPRODUCIBLE_DATES")
  @env.set_env_var("CPDF_REPRODUCIBLE_DATES", "true")
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let title = try! @pdflite.pdf_pdfdocstring_of_utf8(
    @utf8.encode("Résumé Title"),
  )
  let with_title = try! doc.set_info_entry(
    metadata_name_for_test("/Title"),
    PdfString(title),
    4,
    keep_version=true,
  )
  let with_creator = try! with_title.set_info_entry(
    metadata_name_for_test("/Creator"),
    PdfString(@ascii.encode("pdflite-test")),
    4,
    keep_version=true,
  )
  let with_created = try! with_creator.set_info_entry(
    metadata_name_for_test("/CreationDate"),
    PdfString(@ascii.encode("D:20260517010203+08'30'")),
    4,
    keep_version=true,
  )
  let with_metadata = try! @pdflite.pdf_create_metadata(with_created)
  match previous {
    Some(value) => @env.set_env_var("CPDF_REPRODUCIBLE_DATES", value)
    None => @env.unset_env_var("CPDF_REPRODUCIBLE_DATES")
  }
  guard (try! with_metadata.metadata()) is Some(metadata) else {
    fail("expected created metadata")
  }
  let metadata_text = try! @utf8.decode(metadata)
  @test.assert_eq(
    metadata_text.contains(
      "<pdf:CreationDate>2026-05-17T01:02:03+08:30</pdf:CreationDate>",
    ),
    true,
  )
  @test.assert_eq(
    metadata_text.contains(
      "<xap:CreateDate>2026-05-17T01:02:03+08:30</xap:CreateDate>",
    ),
    true,
  )
  @test.assert_eq(
    metadata_text.contains(
      "<xap:ModifyDate>3900-01-01T00:00:00Z</xap:ModifyDate>",
    ),
    true,
  )
  @test.assert_eq(
    metadata_text.contains(
      "<xap:MetadataDate>3900-01-01T00:00:00Z</xap:MetadataDate>",
    ),
    true,
  )
  @test.assert_eq(
    metadata_text.contains("<pdf:Creator>pdflite-test</pdf:Creator>"),
    true,
  )
  @test.assert_eq(
    metadata_text.contains(
      "<rdf:li xml:lang='x-default'>Résumé Title</rdf:li>",
    ),
    true,
  )
  @test.assert_eq(
    metadata_text.contains("<pdf:Trapped>False</pdf:Trapped>"),
    true,
  )
  @test.assert_eq(with_metadata.version(), (1, 4))
}

///|
test "PdfDocument determine_subformats reads XMP markers in cpdf order" {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let metadata_text =
    #|<x:xmpmeta xmlns:x="adobe:ns:meta/"
    #| xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    #| xmlns:e="http://www.aiim.org/pdfe/ns/id/"
    #| xmlns:ua="http://www.aiim.org/pdfua/ns/id/"
    #| xmlns:aid="http://www.aiim.org/pdfa/ns/id/"
    #| xmlns:px="http://www.npes.org/pdfx/ns/id/"
    #| xmlns:vt="http://www.npes.org/pdfvt/ns/id/">
    #| <rdf:RDF>
    #|  <rdf:Description aid:part="2" aid:conformance="B"/>
    #|  <e:ISO_PDFEVersion>PDF/E-1</e:ISO_PDFEVersion>
    #|  <ua:part>2</ua:part>
    #|  <px:GTS_PDFXVersion>PDF/X-4</px:GTS_PDFXVersion>
    #|  <vt:GTS_PDFVTVersion>PDF/VT-1</vt:GTS_PDFVTVersion>
    #| </rdf:RDF>
    #|</x:xmpmeta>
  let metadata = @ascii.encode(metadata_text)
  let with_metadata = try! doc.set_metadata_from_bytes(metadata)
  let expected = ["PDF/VT-1", "PDF/X-4", "PDF/A-2b", "PDF/UA-2", "PDF/E-1"]
  @test.assert_eq(try! with_metadata.determine_subformats(), expected)
  @test.assert_eq(
    try! @pdflite.pdf_determine_subformats(with_metadata),
    expected,
  )
}

///|
fn metadata_without_pdfx_text_for_test() -> String {
  let text =
    #|<x:xmpmeta xmlns:x="adobe:ns:meta/"
    #| xmlns:pdfuaid="http://www.aiim.org/pdfua/ns/id/">
    #| <pdfuaid:part>1</pdfuaid:part>
    #|</x:xmpmeta>
  text
}

///|
test "PdfDocument determine_subformats falls back to Info PDFX marker" {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let key_pdfx = metadata_name_for_test("/GTS_PDFXVersion")
  let with_info = try! doc.set_info_entry(
    key_pdfx,
    PdfString(@ascii.encode("PDF/X-1a:2003")),
    3,
  )
  @test.assert_eq(try! with_info.determine_subformats(), ["PDF/X-1a:2003"])
  let metadata_without_pdfx = try! with_info.set_metadata_from_bytes(
    @ascii.encode(metadata_without_pdfx_text_for_test()),
  )
  @test.assert_eq(try! metadata_without_pdfx.determine_subformats(), [
    "PDF/X-1a:2003", "PDF/UA-1",
  ])
}

///|
test "PdfDocument xmp_info returns legacy Info-key equivalents" {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  @test.assert_eq(doc.xmp_info(metadata_name_for_test("/Title")), "")
  let xmp_text =
    #|<x:xmpmeta xmlns:x="adobe:ns:meta/"
    #| xmlns:pdf="http://ns.adobe.com/pdf/1.3/"
    #| xmlns:xmp="http://ns.adobe.com/xap/1.0/">
    #| <pdf:Title>Adobe Title</pdf:Title>
    #| <pdf:Producer>pdflite</pdf:Producer>
    #| <xmp:CreatorTool>fallback tool</xmp:CreatorTool>
    #| <xmp:ModifyDate>2026-05-17T00:00:00Z</xmp:ModifyDate>
    #|</x:xmpmeta>
  let with_metadata = try! doc.set_metadata_from_bytes(@ascii.encode(xmp_text))
  @test.assert_eq(
    with_metadata.xmp_info(metadata_name_for_test("/Title")),
    "Adobe Title",
  )
  @test.assert_eq(with_metadata.xmp_info_string("/Title"), "Adobe Title")
  @test.assert_eq(
    with_metadata.xmp_info(metadata_name_for_test("/Creator")),
    "fallback tool",
  )
  @test.assert_eq(
    @pdflite.pdf_get_xmp_info(with_metadata, metadata_name_for_test("/ModDate")),
    "2026-05-17T00:00:00Z",
  )
  @test.assert_eq(
    @pdflite.pdf_get_xmp_info_string(with_metadata, "/ModDate"),
    "2026-05-17T00:00:00Z",
  )
  @test.assert_eq(
    @pdflite.pdf_get_xmp_info(
      with_metadata,
      metadata_name_for_test("/Producer"),
    ),
    "pdflite",
  )
  @test.assert_eq(with_metadata.xmp_info(metadata_name_for_test("/Custom")), "")
  let dc_list_text =
    #|<x:xmpmeta xmlns:dc="http://purl.org/dc/elements/1.1/"
    #| xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    #| <dc:title><rdf:Alt>
    #|  <rdf:li/>
    #|  <rdf:li xml:lang="x-default">First</rdf:li>
    #|  <rdf:li xml:lang="fr-FR">Second</rdf:li>
    #| </rdf:Alt></dc:title>
    #|</x:xmpmeta>
  let dc_list_doc = try! doc.set_metadata_from_bytes(
    @ascii.encode(dc_list_text),
  )
  @test.assert_eq(
    dc_list_doc.xmp_info(metadata_name_for_test("/Title")),
    "First, Second",
  )
}

///|
test "pdf_metadata_get_data_for_bytes mirrors cpdfmetadata lookup" {
  @test.assert_eq(
    @pdflite.pdf_metadata_adobe, @pdflite.pdf_metadata_adobe_namespace,
  )
  @test.assert_eq(@pdflite.pdf_adobe, @pdflite.pdf_metadata_adobe_namespace)
  @test.assert_eq(
    @pdflite.pdf_metadata_xmp, @pdflite.pdf_metadata_xmp_namespace,
  )
  @test.assert_eq(@pdflite.pdf_xmp, @pdflite.pdf_metadata_xmp_namespace)
  @test.assert_eq(@pdflite.pdf_metadata_dc, @pdflite.pdf_metadata_dc_namespace)
  @test.assert_eq(@pdflite.pdf_dc, @pdflite.pdf_metadata_dc_namespace)
  @test.assert_eq(
    @pdflite.pdf_metadata_rdf, @pdflite.pdf_metadata_rdf_namespace,
  )
  @test.assert_eq(@pdflite.pdf_rdf, @pdflite.pdf_metadata_rdf_namespace)
  @test.assert_eq(
    @pdflite.pdf_metadata_pdfaid, @pdflite.pdf_metadata_pdfaid_namespace,
  )
  @test.assert_eq(@pdflite.pdf_pdfaid, @pdflite.pdf_metadata_pdfaid_namespace)
  @test.assert_eq(
    @pdflite.pdf_metadata_pdfxid, @pdflite.pdf_metadata_pdfxid_namespace,
  )
  @test.assert_eq(@pdflite.pdf_pdfxid, @pdflite.pdf_metadata_pdfxid_namespace)
  @test.assert_eq(
    @pdflite.pdf_metadata_pdfe, @pdflite.pdf_metadata_pdfe_namespace,
  )
  @test.assert_eq(@pdflite.pdf_pdfe, @pdflite.pdf_metadata_pdfe_namespace)
  @test.assert_eq(
    @pdflite.pdf_metadata_pdfuaid, @pdflite.pdf_metadata_pdfuaid_namespace,
  )
  @test.assert_eq(@pdflite.pdf_pdfuaid, @pdflite.pdf_metadata_pdfuaid_namespace)
  @test.assert_eq(
    @pdflite.pdf_metadata_pdfvtid, @pdflite.pdf_metadata_pdfvtid_namespace,
  )
  @test.assert_eq(@pdflite.pdf_pdfvtid, @pdflite.pdf_metadata_pdfvtid_namespace)
  let xmp_text =
    #|<x:xmpmeta xmlns:x="adobe:ns:meta/"
    #| xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    #| xmlns:altpdf="http://ns.adobe.com/pdf/1.3/"
    #| xmlns:altxmp="http://ns.adobe.com/xap/1.0/"
    #| xmlns:dc="http://purl.org/dc/elements/1.1/"
    #| xmlns:pdfaid="http://www.aiim.org/pdfa/ns/id/">
    #| <rdf:Description pdfaid:part='2' altxmp:CreatorTool="MoonBit &amp; cpdf &#x2B; XML &#43;">
    #|  <altpdf:Producer>pdflite</altpdf:Producer>
    #|  <dc:subject><rdf:Bag>
    #|    <rdf:li>alpha &lt;one&gt;</rdf:li>
    #|    <rdf:li>beta &#x32;</rdf:li>
    #|  </rdf:Bag></dc:subject>
    #| </rdf:Description>
    #|</x:xmpmeta>
  let metadata = @ascii.encode(xmp_text)
  @test.assert_eq(
    @pdflite.pdf_metadata_get_data_for_bytes(
      @pdflite.pdf_metadata_xmp, "CreatorTool", metadata,
    ),
    Some("MoonBit & cpdf + XML +"),
  )
  @test.assert_eq(
    @pdflite.pdf_metadata_get_data_for_bytes(
      @pdflite.pdf_metadata_adobe, "Producer", metadata,
    ),
    Some("pdflite"),
  )
  @test.assert_eq(
    @pdflite.pdf_metadata_get_data_for_bytes(
      @pdflite.pdf_metadata_pdfaid, "part", metadata,
    ),
    Some("2"),
  )
  @test.assert_eq(
    @pdflite.pdf_metadata_get_data_for_bytes(
      @pdflite.pdf_metadata_dc, "subject", metadata,
    ),
    Some("alpha <one>, beta 2"),
  )
  @test.assert_eq(
    @pdflite.pdf_metadata_get_data_for_bytes(
      @pdflite.pdf_metadata_pdfuaid, "part", metadata,
    ),
    None,
  )
}

///|
test "pdf_metadata XML tree helpers mirror cpdfmetadata lookup" {
  let xmp_text =
    #|<?xml version="1.0"?>
    #|<!-- ignored by the tree parser -->
    #|<x:xmpmeta xmlns:x="adobe:ns:meta/"
    #| xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    #| xmlns:dc="http://purl.org/dc/elements/1.1/"
    #| xmlns:pdfaid="http://www.aiim.org/pdfa/ns/id/">
    #| <rdf:Description pdfaid:part='  2  '/>
    #| <dc:subject><rdf:Bag>
    #|  <rdf:li>alpha &lt;one&gt;</rdf:li>
    #|  <rdf:li>beta   &#50;</rdf:li>
    #| </rdf:Bag></dc:subject>
    #|</x:xmpmeta>
  let document = try! @pdflite.pdf_metadata_xmltree_of_bytes(
    @ascii.encode(xmp_text),
  )
  let source_document = try! @pdflite.pdf_xmltree_of_bytes(
    @ascii.encode(xmp_text),
  )
  guard document.tree is PdfMetadataXmlElement(root_tag, children) else {
    fail("expected XML element root")
  }
  @test.assert_eq(root_tag.name.uri, "adobe:ns:meta/")
  @test.assert_eq(root_tag.name.local_name, "xmpmeta")
  @test.assert_eq(root_tag.name.prefix, Some("x"))
  @test.assert_eq(children.length(), 2)
  @test.assert_eq(
    @pdflite.pdf_metadata_xmltree_get_data_for(
      @pdflite.pdf_metadata_pdfaid,
      "part",
      document.tree,
    ),
    Some("2"),
  )
  @test.assert_eq(
    @pdflite.pdf_get_data_for(@pdflite.pdf_pdfaid, "part", source_document.tree),
    Some("2"),
  )
  @test.assert_eq(
    @pdflite.pdf_metadata_xmltree_get_data_for(
      @pdflite.pdf_metadata_dc,
      "subject",
      document.tree,
    ),
    Some("alpha <one>, beta 2"),
  )
  @test.assert_eq(
    @pdflite.pdf_metadata_xmltree_get_data_for(
      @pdflite.pdf_metadata_pdfuaid,
      "part",
      document.tree,
    ),
    None,
  )
  let debug = @pdflite.pdf_metadata_string_of_xmltree(document.tree)
  @test.assert_eq(@pdflite.pdf_string_of_xmltree(source_document.tree), debug)
  @test.assert_eq(debug.contains("NAME |adobe:ns:meta/| |xmpmeta|"), true)
  @test.assert_eq(
    debug.contains("ATTRNAME |http://www.aiim.org/pdfa/ns/id/| |part|, STR {2}"),
    true,
  )
  let serialized = try! @utf8.decode(
    @pdflite.pdf_metadata_bytes_of_xmltree(document),
  )
  @test.assert_eq(
    @pdflite.pdf_bytes_of_xmltree(source_document),
    @pdflite.pdf_metadata_bytes_of_xmltree(document),
  )
  @test.assert_eq(serialized.contains("<x:xmpmeta"), true)
  @test.assert_eq(serialized.contains("xmlns:pdfaid="), true)
  @test.assert_eq(serialized.contains("pdfaid:part=\"2\""), true)
  @test.assert_eq(serialized.contains("alpha &lt;one&gt;"), true)
}

///|
test "PdfDocument xmp_info_json reports cpdf XMP fields" {
  let empty = try! @pdflite.pdf_minimum_valid_pdf()
  let empty_expected : Json = { "Language": null, "Subformats": [] }
  @test.assert_eq(try! empty.xmp_info_json(), empty_expected)
  let metadata_text =
    #|<x:xmpmeta xmlns:pdf="http://ns.adobe.com/pdf/1.3/"
    #| xmlns:xmp="http://ns.adobe.com/xap/1.0/"
    #| xmlns:dc="http://purl.org/dc/elements/1.1/"
    #| xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    #| xmlns:pdfuaid="http://www.aiim.org/pdfua/ns/id/">
    #| <pdf:Title>PDF Title</pdf:Title>
    #| <xmp:MetadataDate>2026-05-17T00:00:00Z</xmp:MetadataDate>
    #| <dc:title><rdf:Alt>
    #|  <rdf:li>First</rdf:li>
    #|  <rdf:li>Second</rdf:li>
    #| </rdf:Alt></dc:title>
    #| <pdfuaid:part>1</pdfuaid:part>
    #| <pdfuaid:amd>1</pdfuaid:amd>
    #|</x:xmpmeta>
  let with_metadata = try! empty
    .set_language(@ascii.encode("en-US"))
    .set_metadata_from_bytes(@ascii.encode(metadata_text))
  let expected : Json = {
    "Language": "en-US",
    "PDF/UA pdfuaid:amd": "1",
    "Subformats": ["PDF/UA-1"],
    "XMP dc:title": "First, Second",
    "XMP pdf:Title": "PDF Title",
    "XMP xmp:MetadataDate": "2026-05-17T00:00:00Z",
  }
  @test.assert_eq(try! with_metadata.xmp_info_json(), expected)
  @test.assert_eq(
    try! @pdflite.pdf_output_xmp_info_json_blob(with_metadata),
    @utf8.encode((try! with_metadata.xmp_info_json()).stringify()),
  )
}

///|
test "PdfDocument set_info_entry can synchronize XMP metadata" {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let xmp_text =
    #|<x:xmpmeta xmlns:pdf="http://ns.adobe.com/pdf/1.3/"
    #| xmlns:xmp="http://ns.adobe.com/xap/1.0/"
    #| xmlns:dc="http://purl.org/dc/elements/1.1/">
    #| <pdf:Title/>
    #| <dc:title/>
    #| <pdf:Creator/>
    #| <xmp:CreatorTool/>
    #| <dc:creator/>
    #| <pdf:CreationDate/>
    #| <xmp:CreateDate/>
    #| <pdf:Trapped/>
    #|</x:xmpmeta>
  let with_metadata = try! doc.set_metadata_from_bytes(@ascii.encode(xmp_text))
  let key_title = metadata_name_for_test("/Title")
  let title = try! @pdflite.pdf_pdfdocstring_of_utf8(
    @utf8.encode("Résumé & Review"),
  )
  let title_doc = try! with_metadata.set_info_entry(
    key_title,
    PdfString(title),
    4,
    xmp_also=true,
  )
  guard (try! title_doc.metadata()) is Some(title_metadata) else {
    fail("expected title metadata")
  }
  let title_text = try! @utf8.decode(title_metadata)
  @test.assert_eq(
    title_text.contains("<pdf:Title>Résumé &amp; Review</pdf:Title>"),
    true,
  )
  @test.assert_eq(
    title_text.contains("<dc:title>Résumé &amp; Review</dc:title>"),
    true,
  )
  @test.assert_eq(title_doc.info_utf8(key_title), "Résumé & Review")
  let key_creator = metadata_name_for_test("/Creator")
  let creator_doc = try! @pdflite.pdf_set_pdf_info(
    key_creator,
    PdfString(@ascii.encode("tool")),
    4,
    with_metadata,
    xmp_also=true,
  )
  guard (try! creator_doc.metadata()) is Some(creator_metadata) else {
    fail("expected creator metadata")
  }
  let creator_text = try! @ascii.decode(creator_metadata)
  @test.assert_eq(
    creator_text.contains("<pdf:Creator>tool</pdf:Creator>"),
    true,
  )
  @test.assert_eq(
    creator_text.contains("<xmp:CreatorTool>tool</xmp:CreatorTool>"),
    true,
  )
  @test.assert_eq(creator_text.contains("<dc:creator>tool</dc:creator>"), true)
  @test.assert_eq(creator_doc.info_utf8(key_creator), "tool")
  let key_creation = metadata_name_for_test("/CreationDate")
  let date_doc = try! with_metadata.set_info_entry(
    key_creation,
    PdfString(@ascii.encode("D:20260517010203+08'30'")),
    4,
    xmp_also=true,
    xmp_just_set=true,
  )
  guard (try! date_doc.metadata()) is Some(date_metadata) else {
    fail("expected date metadata")
  }
  let date_text = try! @ascii.decode(date_metadata)
  @test.assert_eq(
    date_text.contains(
      "<xmp:CreateDate>2026-05-17T01:02:03+08:30</xmp:CreateDate>",
    ),
    true,
  )
  @test.assert_eq(date_doc.info_utf8(key_creation), "")
  let trapped_doc = try! with_metadata.set_info_entry(
    metadata_name_for_test("/Trapped"),
    PdfBoolean(true),
    4,
    xmp_also=true,
    xmp_just_set=true,
  )
  guard (try! trapped_doc.metadata()) is Some(trapped_metadata) else {
    fail("expected trapped metadata")
  }
  @test.assert_eq(
    (try! @ascii.decode(trapped_metadata)).contains(
      "<pdf:Trapped>True</pdf:Trapped>",
    ),
    true,
  )
  let bad : Result[@pdflite.PdfDocument, Error] = try? with_metadata.set_info_entry(
    key_title,
    PdfInteger(1),
    4,
    xmp_also=true,
  )
  guard bad is Err(@pdflite.PdfError::BadNumberArgument(_)) else {
    fail("expected bad XMP info value")
  }
}

///|
test "pdf metadata compatibility wrappers keep cpdf argument order" {
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let key_producer = metadata_name_for_test("/Producer")
  let with_info = try! @pdflite.pdf_set_pdf_info(
    key_producer,
    PdfString(@ascii.encode("pdflite")),
    3,
    doc,
  )
  @test.assert_eq(
    @pdflite.pdf_get_info_utf8(with_info, key_producer),
    "pdflite",
  )
  let with_title = try! @pdflite.pdf_set_pdf_info_cpdf_order(
    ("/Title", PdfString(@ascii.encode("Tuple title")), 4),
    with_info,
  )
  @test.assert_eq(
    @pdflite.pdf_get_info_utf8_string(with_title, "/Title"),
    "Tuple title",
  )
  let with_author = try! @pdflite.pdf_set_pdf_info_string(
    ("/Author", PdfString(@ascii.encode("Tuple author")), 4),
    with_title,
  )
  @test.assert_eq(with_author.info_utf8_string("/Author"), "Tuple author")
  let with_metadata = try! @pdflite.pdf_set_metadata_from_bytes(
    false,
    @ascii.encode("<m/>"),
    with_author,
  )
  @test.assert_eq(
    try! @pdflite.pdf_get_metadata(with_metadata),
    Some(@ascii.encode("<m/>")),
  )
  @test.assert_eq(
    try! @pdflite.pdf_get_metadata(
      try! @pdflite.pdf_remove_metadata(with_metadata),
    ),
    None,
  )
  let all_removed = try! @pdflite.pdf_remove_all_metadata(with_metadata)
  @test.assert_eq(try! all_removed.metadata(), None)
}
