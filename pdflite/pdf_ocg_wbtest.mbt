///|
fn ocg_wb_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn ocg_wb_text(text : String) -> @core.PdfBytes {
  @ascii.encode(text)
}

///|
fn ocg_wb_name_object(text : String) -> @syntax.PdfObject {
  PdfNameObject(ocg_wb_name(text))
}

///|
test "private OCG array readers tolerate malformed entries" {
  let doc = pdf_document_empty()
  let view = pdf_ocg_view_name()
  @test.assert_eq(
    doc.pdf_ocg_name_array(PdfArray([PdfNameObject(view), PdfInteger(1)])),
    [view],
  )
  @test.assert_eq(doc.pdf_ocg_name_array(PdfInteger(1)), [])
  @test.assert_eq(
    doc.pdf_ocg_indirect_numbers(PdfArray([PdfIndirect(7), PdfInteger(8)])),
    [7],
  )
  @test.assert_eq(doc.pdf_ocg_indirect_numbers(PdfInteger(1)), [])
  @test.assert_eq(doc.pdf_ocg_string_array(PdfString(ocg_wb_text("one"))), [
    ocg_wb_text("one"),
  ])
  @test.assert_eq(
    doc.pdf_ocg_string_array(
      PdfArray([PdfString(ocg_wb_text("two")), PdfInteger(1)]),
    ),
    [ocg_wb_text("two")],
  )
  @test.assert_eq(doc.pdf_ocg_string_array(PdfInteger(1)), [])
  @test.assert_eq(doc.pdf_ocg_optional_number(PdfNameObject(view)), None)
}

///|
test "private OCG appdict and order readers cover sparse forms" {
  let doc = pdf_document_empty()
  @test.assert_eq(
    doc.pdf_ocg_read_appdict(
      PdfDictionary([(pdf_ocg_event_key(), ocg_wb_name_object("/Export"))]),
    ),
    { event: OcgExport, ocgs: [], category: [] },
  )
  @test.assert_eq(
    doc.pdf_ocg_read_order(
      PdfArray([
        PdfIndirect(1),
        PdfArray([
          PdfString(ocg_wb_text("Group")),
          PdfIndirect(2),
          PdfInteger(3),
        ]),
        PdfArray([PdfIndirect(4), PdfInteger(5)]),
        PdfInteger(6),
      ]),
    ),
    [(None, [1]), (Some(ocg_wb_text("Group")), [2]), (None, [4]), (None, [])],
  )
  @test.assert_eq(doc.pdf_ocg_read_order(PdfInteger(1)), [])
}

///|
test "private OCG usage reader covers partial dictionaries" {
  let doc = pdf_document_empty()
  @test.assert_eq(
    doc.pdf_ocg_read_usage(
      PdfDictionary([
        (
          pdf_ocg_creatorinfo_key(),
          PdfDictionary([
            (pdf_ocg_creator_key(), PdfString(ocg_wb_text("tool"))),
          ]),
        ),
        (
          pdf_ocg_zoom_key(),
          PdfDictionary([(pdf_ocg_min_key(), ocg_wb_name_object("/Bad"))]),
        ),
        (
          pdf_ocg_user_key(),
          PdfDictionary([
            (pdf_ocg_type_key(), ocg_wb_name_object("/Ind")),
            (pdf_ocg_name_key(), PdfInteger(1)),
          ]),
        ),
      ]),
    ),
    {
      creator_info: Some((ocg_wb_text("tool"), @core.pdf_name_of_bytes([]))),
      language: None,
      export_state: None,
      zoom_min: None,
      zoom_max: None,
      print_subtype: None,
      print_state: None,
      view_state: None,
      user: None,
      page_element_subtype: None,
    },
  )
  @test.assert_eq(
    doc.pdf_ocg_read_usage(
      PdfDictionary([
        (
          pdf_ocg_creatorinfo_key(),
          PdfDictionary([
            (pdf_ocg_subtype_key(), ocg_wb_name_object("/Subtype")),
          ]),
        ),
      ]),
    ).creator_info,
    Some(([], ocg_wb_name("/Subtype"))),
  )
}

///|
test "private OCG individual and public reader guard malformed roots" {
  let doc = pdf_document_empty()
  let missing_name : Result[@ocg.PdfOcg, Error] = try
    doc.pdf_ocg_read_individual(PdfDictionary([]))
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_name is Err(@core.PdfError::DictionaryKeyNotFound(_)) else {
    fail("expected missing name")
  }
  @test.assert_eq(
    try! doc.pdf_ocg_read_individual(
      PdfDictionary([(pdf_ocg_name_key(), PdfString(ocg_wb_text("Layer")))]),
    ),
    { name: ocg_wb_text("Layer"), intent: [pdf_ocg_view_name()], usage: None },
  )

  let root_doc = pdf_document_empty()
  root_doc.set_root(1)
  root_doc.add_object_given_number(
    1,
    PdfDictionary([
      (
        pdf_ocg_ocproperties_key(),
        PdfDictionary([(pdf_ocg_ocgs_key(), PdfInteger(1))]),
      ),
    ]),
  )
  let missing_default : Result[@ocg.PdfOptionalContent?, Error] = try
    root_doc.read_optional_content_groups()
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  guard missing_default is Err(@core.PdfError::DictionaryKeyNotFound(_)) else {
    fail("expected missing default config")
  }
}

///|
test "private OCG copy and merge helpers cover optional fields" {
  let usage : @ocg.PdfOcgUsage = {
    creator_info: Some((ocg_wb_text("creator"), ocg_wb_name("/Subtype"))),
    language: Some((ocg_wb_text("en"), None)),
    export_state: Some(pdf_ocg_off_name()),
    zoom_min: Some(0.5),
    zoom_max: Some(2.0),
    print_subtype: Some(ocg_wb_name("/PrintSubtype")),
    print_state: None,
    view_state: Some(pdf_ocg_view_name()),
    user: Some((ocg_wb_name("/Ind"), [ocg_wb_text("Alice")])),
    page_element_subtype: Some(ocg_wb_name("/FG")),
  }
  @test.assert_eq(pdf_ocg_copy_usage(usage), usage)
  @test.assert_eq(
    pdf_ocg_copy_ocg({
      name: ocg_wb_text("Layer"),
      intent: [pdf_ocg_view_name()],
      usage: Some(usage),
    }),
    {
      name: ocg_wb_text("Layer"),
      intent: [pdf_ocg_view_name()],
      usage: Some(usage),
    },
  )
  let config : @ocg.PdfOcgConfig = {
    ..@ocg.pdf_ocg_default_config(),
    creator: Some(ocg_wb_text("creator")),
    usage_applications: [
      { event: OcgView, ocgs: [1], category: [pdf_ocg_view_name()] },
    ],
    order: Some([(None, [1])]),
    radio_button_groups: Some([[1]]),
    locked: [1],
  }
  @test.assert_eq(pdf_ocg_copy_config(config), config)

  let doc = pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(1, PdfDictionary([]))
  let content : @ocg.PdfOptionalContent = {
    ocgs: [
      (
        1,
        {
          name: ocg_wb_text("Layer"),
          intent: [pdf_ocg_view_name()],
          usage: Some(usage),
        },
      ),
    ],
    default_config: { ..config, base_state: OcgOff, list_mode: OcgVisiblePages },
    configs: [config],
  }
  let written = try! doc.write_optional_content_groups(content)
  let merged = try! pdf_optional_content_merge([written])
  guard merged is Some(value) else { fail("expected merged content") }
  @test.assert_eq(
    value.default_config.usage_applications,
    config.usage_applications,
  )
  @test.assert_eq(value.default_config.list_mode, OcgVisiblePages)
  @test.assert_eq(value.default_config.locked, [1])
}

///|
test "private OCG writers cover event and optional usage/config forms" {
  let doc = pdf_document_empty()
  @test.assert_eq(
    pdf_ocg_write_appdict({
      event: OcgView,
      ocgs: [1],
      category: [pdf_ocg_view_name()],
    }).lookup_immediate(pdf_ocg_event_key()),
    Some(PdfNameObject(pdf_ocg_view_name())),
  )
  @test.assert_eq(
    pdf_ocg_write_appdict({
      event: OcgExport,
      ocgs: [1],
      category: [pdf_ocg_export_name()],
    }).lookup_immediate(pdf_ocg_event_key()),
    Some(PdfNameObject(pdf_ocg_export_name())),
  )

  let usage_number = doc.pdf_ocg_write_usage({
    creator_info: None,
    language: Some((ocg_wb_text("en"), Some(pdf_ocg_on_key()))),
    export_state: None,
    zoom_min: Some(0.5),
    zoom_max: Some(2.0),
    print_subtype: Some(ocg_wb_name("/Watermark")),
    print_state: Some(pdf_ocg_off_name()),
    view_state: None,
    user: None,
    page_element_subtype: Some(ocg_wb_name("/FG")),
  })
  let usage_object = doc.lookup_object_or_null(usage_number)
  @test.assert_eq(
    usage_object.lookup_immediate(pdf_ocg_language_key()) is Some(_),
    true,
  )
  @test.assert_eq(
    usage_object.lookup_immediate(pdf_ocg_zoom_key()) is Some(_),
    true,
  )
  @test.assert_eq(
    usage_object.lookup_immediate(pdf_ocg_print_key()) is Some(_),
    true,
  )
  @test.assert_eq(
    usage_object.lookup_immediate(pdf_ocg_page_element_key()) is Some(_),
    true,
  )

  let min_only = doc.pdf_ocg_write_usage({
    creator_info: None,
    language: Some((ocg_wb_text("en"), None)),
    export_state: None,
    zoom_min: Some(0.25),
    zoom_max: None,
    print_subtype: Some(ocg_wb_name("/Subtype")),
    print_state: None,
    view_state: None,
    user: None,
    page_element_subtype: None,
  })
  @test.assert_eq(
    doc.lookup_object_or_null(min_only).lookup_immediate(pdf_ocg_zoom_key())
    is Some(_),
    true,
  )

  let config_number = doc.pdf_ocg_write_config({
    ..@ocg.pdf_ocg_default_config(),
    creator: Some(ocg_wb_text("creator")),
    usage_applications: [
      { event: OcgExport, ocgs: [1], category: [pdf_ocg_export_name()] },
    ],
    order: Some([(None, [1]), (None, [1, 2])]),
  })
  let config_object = doc.lookup_object_or_null(config_number)
  @test.assert_eq(
    config_object.lookup_immediate(pdf_ocg_creator_key()),
    Some(PdfString(ocg_wb_text("creator"))),
  )
  @test.assert_eq(
    config_object.lookup_immediate(pdf_ocg_order_key()) is Some(_),
    true,
  )
}

///|
test "private OCG empty optional paths stay stable" {
  let doc = pdf_document_empty()
  let empty_usage = doc.pdf_ocg_read_usage(PdfDictionary([]))
  let expected_usage : @ocg.PdfOcgUsage = {
    creator_info: None,
    language: None,
    export_state: None,
    zoom_min: None,
    zoom_max: None,
    print_subtype: None,
    print_state: None,
    view_state: None,
    user: None,
    page_element_subtype: None,
  }
  @test.assert_eq(empty_usage, expected_usage)
  @test.assert_eq(pdf_ocg_copy_usage(empty_usage), expected_usage)
  let empty_usage_number = doc.pdf_ocg_write_usage(empty_usage)
  @test.assert_eq(
    doc.lookup_object_or_null(empty_usage_number),
    PdfDictionary([]),
  )

  let root_doc = pdf_document_empty()
  root_doc.set_root(1)
  root_doc.add_object_given_number(
    1,
    PdfDictionary([
      (
        pdf_ocg_ocproperties_key(),
        PdfDictionary([
          (pdf_ocg_ocgs_key(), PdfArray([PdfInteger(99)])),
          (pdf_ocg_d_key(), PdfDictionary([])),
        ]),
      ),
    ]),
  )
  let content = try! root_doc.read_optional_content_groups()
  guard content is Some(content) else { fail("expected optional content") }
  @test.assert_eq(content.ocgs, [])

  let merge_doc = pdf_document_empty()
  merge_doc.set_root(1)
  merge_doc.add_object_given_number(1, PdfDictionary([]))
  let written = try! merge_doc.write_optional_content_groups({
    ocgs: [],
    default_config: @ocg.pdf_ocg_default_config(),
    configs: [],
  })
  let merged = try! pdf_optional_content_merge([written])
  guard merged is Some(merged) else { fail("expected merged content") }
  @test.assert_eq(merged.default_config.order, None)
}
