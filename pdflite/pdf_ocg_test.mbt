///|
fn ocg_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn ocg_bytes_for_test(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
fn ocg_json_int_for_test(value : Int) -> Json {
  Json::number(value.to_double(), repr=value.to_string())
}

///|
fn ocg_name_object_for_test(text : String) -> @pdflite.PdfObject {
  PdfNameObject(ocg_name_for_test(text))
}

///|
fn ocg_catalog_document_for_test() -> @pdflite.PdfDocument {
  let key_root = ocg_name_for_test("/Root")
  let key_type = ocg_name_for_test("/Type")
  let type_catalog = ocg_name_for_test("/Catalog")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(1))]))
  doc.add_object_given_number(
    1,
    PdfDictionary([(key_type, PdfNameObject(type_catalog))]),
  )
  doc
}

///|
fn ocg_conflicting_root_document_for_test(
  with_ocproperties : Bool,
) -> @pdflite.PdfDocument {
  let key_root = ocg_name_for_test("/Root")
  let key_type = ocg_name_for_test("/Type")
  let key_lang = ocg_name_for_test("/Lang")
  let key_page_mode = ocg_name_for_test("/PageMode")
  let key_ocproperties = ocg_name_for_test("/OCProperties")
  let key_d = ocg_name_for_test("/D")
  let type_catalog = ocg_name_for_test("/Catalog")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(10))]))
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(type_catalog)),
      (key_lang, PdfString(ocg_bytes_for_test("stale"))),
    ]),
  )
  let active_entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (key_type, PdfNameObject(type_catalog)),
    (key_page_mode, ocg_name_object_for_test("/UseOC")),
  ]
  if with_ocproperties {
    active_entries.push(
      (key_ocproperties, PdfDictionary([(key_d, PdfDictionary([]))])),
    )
  }
  doc.add_object_given_number(10, PdfDictionary(active_entries))
  doc
}

///|
fn ocg_merge_content_for_test(
  number : Int,
  layer_name : String,
  base_state : @pdflite.PdfOcgState,
  on_numbers : Array[Int],
  off_numbers : Array[Int],
) -> @pdflite.PdfOptionalContent {
  {
    ocgs: [
      (
        number,
        {
          name: ocg_bytes_for_test(layer_name),
          intent: [ocg_name_for_test("/View")],
          usage: None,
        },
      ),
    ],
    default_config: {
      ..@pdflite.pdf_ocg_default_config(),
      name: Some(ocg_bytes_for_test("Merged")),
      base_state,
      on: on_numbers,
      off: off_numbers,
      order: Some([(Some(ocg_bytes_for_test(layer_name)), [number])]),
      radio_button_groups: Some([[number]]),
    },
    configs: [{ ..@pdflite.pdf_ocg_default_config(), locked: [number] }],
  }
}

///|
fn ocg_document_with_content_for_test() -> @pdflite.PdfDocument {
  let doc = ocg_catalog_document_for_test()
  let key_type = ocg_name_for_test("/Type")
  let key_name = ocg_name_for_test("/Name")
  let key_intent = ocg_name_for_test("/Intent")
  let key_usage = ocg_name_for_test("/Usage")
  let key_creator_info = ocg_name_for_test("/CreatorInfo")
  let key_creator = ocg_name_for_test("/Creator")
  let key_subtype = ocg_name_for_test("/Subtype")
  let key_language = ocg_name_for_test("/Language")
  let key_lang = ocg_name_for_test("/Lang")
  let key_preferred = ocg_name_for_test("/Preferred")
  let key_export = ocg_name_for_test("/Export")
  let key_export_state = ocg_name_for_test("/ExportState")
  let key_zoom = ocg_name_for_test("/Zoom")
  let key_min = ocg_name_for_test("/min")
  let key_max = ocg_name_for_test("/max")
  let key_print = ocg_name_for_test("/Print")
  let key_print_state = ocg_name_for_test("/PrintState")
  let key_view = ocg_name_for_test("/View")
  let key_view_state = ocg_name_for_test("/ViewState")
  let key_user = ocg_name_for_test("/User")
  let key_page_element = ocg_name_for_test("/PageElement")
  let key_ocproperties = ocg_name_for_test("/OCProperties")
  let key_ocgs = ocg_name_for_test("/OCGs")
  let key_d = ocg_name_for_test("/D")
  let key_configs = ocg_name_for_test("/Configs")
  let key_base_state = ocg_name_for_test("/BaseState")
  let key_on = ocg_name_for_test("/ON")
  let key_off = ocg_name_for_test("/OFF")
  let key_as = ocg_name_for_test("/AS")
  let key_event = ocg_name_for_test("/Event")
  let key_category = ocg_name_for_test("/Category")
  let key_order = ocg_name_for_test("/Order")
  let key_list_mode = ocg_name_for_test("/ListMode")
  let key_rb_groups = ocg_name_for_test("/RBGroups")
  let key_locked = ocg_name_for_test("/Locked")
  let usage : @pdflite.PdfObject = PdfDictionary([
    (
      key_creator_info,
      PdfDictionary([
        (key_creator, PdfString(ocg_bytes_for_test("tool"))),
        (key_subtype, ocg_name_object_for_test("/Artwork")),
      ]),
    ),
    (
      key_language,
      PdfDictionary([
        (key_lang, PdfString(ocg_bytes_for_test("en-US"))),
        (key_preferred, ocg_name_object_for_test("/ON")),
      ]),
    ),
    (
      key_export,
      PdfDictionary([(key_export_state, ocg_name_object_for_test("/ON"))]),
    ),
    (
      key_zoom,
      PdfDictionary([(key_min, PdfReal(0.5)), (key_max, PdfReal(2.0))]),
    ),
    (
      key_print,
      PdfDictionary([
        (key_subtype, ocg_name_object_for_test("/Watermark")),
        (key_print_state, ocg_name_object_for_test("/OFF")),
      ]),
    ),
    (
      key_view,
      PdfDictionary([(key_view_state, ocg_name_object_for_test("/ON"))]),
    ),
    (
      key_user,
      PdfDictionary([
        (key_type, ocg_name_object_for_test("/Ind")),
        (
          key_name,
          PdfArray([
            PdfString(ocg_bytes_for_test("Alice")),
            PdfString(ocg_bytes_for_test("Bob")),
          ]),
        ),
      ]),
    ),
    (
      key_page_element,
      PdfDictionary([(key_subtype, ocg_name_object_for_test("/FG"))]),
    ),
  ])
  doc.add_object_given_number(
    10,
    PdfDictionary([
      (key_type, ocg_name_object_for_test("/OCG")),
      (key_name, PdfString(ocg_bytes_for_test("Layer 1"))),
      (
        key_intent,
        PdfArray([
          ocg_name_object_for_test("/View"),
          ocg_name_object_for_test("/Print"),
        ]),
      ),
      (key_usage, usage),
    ]),
  )
  let appdict : @pdflite.PdfObject = PdfDictionary([
    (key_event, ocg_name_object_for_test("/Print")),
    (key_ocgs, PdfArray([PdfIndirect(10)])),
    (key_category, PdfArray([ocg_name_object_for_test("/Print")])),
  ])
  let config : @pdflite.PdfObject = PdfDictionary([
    (key_name, PdfString(ocg_bytes_for_test("Default"))),
    (key_creator, PdfString(ocg_bytes_for_test("Author"))),
    (key_base_state, ocg_name_object_for_test("/OFF")),
    (key_on, PdfArray([PdfIndirect(10)])),
    (key_off, PdfArray([PdfIndirect(11)])),
    (key_intent, ocg_name_object_for_test("/View")),
    (key_as, PdfArray([appdict])),
    (
      key_order,
      PdfArray([
        PdfArray([PdfString(ocg_bytes_for_test("Layers")), PdfIndirect(10)]),
      ]),
    ),
    (key_list_mode, ocg_name_object_for_test("/VisiblePages")),
    (key_rb_groups, PdfArray([PdfArray([PdfIndirect(10), PdfIndirect(11)])])),
    (key_locked, PdfArray([PdfIndirect(10)])),
  ])
  let ocproperties : @pdflite.PdfObject = PdfDictionary([
    (key_ocgs, PdfArray([PdfIndirect(10)])),
    (key_d, config),
    (
      key_configs,
      PdfArray([
        PdfDictionary([(key_base_state, ocg_name_object_for_test("/Unchanged"))]),
      ]),
    ),
  ])
  doc.add_object_given_number(
    1,
    try! doc
    .lookup_object_or_null(1)
    .add_dict_entry(key_ocproperties, ocproperties),
  )
  doc
}

///|
test "PdfDocument read_optional_content_groups decodes OCG dictionaries" {
  let doc = ocg_document_with_content_for_test()
  guard (try! doc.read_optional_content_groups()) is Some(content) else {
    fail("expected optional content")
  }
  @test.assert_eq(try! @pdflite.pdf_read_ocg(doc), Some(content))
  @test.assert_eq(content.ocgs.length(), 1)
  let (number, ocg) = content.ocgs[0]
  @test.assert_eq(number, 10)
  @test.assert_eq(ocg.name, ocg_bytes_for_test("Layer 1"))
  @test.assert_eq(ocg.intent, [
    ocg_name_for_test("/View"),
    ocg_name_for_test("/Print"),
  ])
  guard ocg.usage is Some(usage) else { fail("expected usage") }
  @test.assert_eq(
    usage.creator_info,
    Some((ocg_bytes_for_test("tool"), ocg_name_for_test("/Artwork"))),
  )
  @test.assert_eq(
    usage.language,
    Some((ocg_bytes_for_test("en-US"), Some(ocg_name_for_test("/ON")))),
  )
  @test.assert_eq(usage.export_state, Some(ocg_name_for_test("/ON")))
  @test.assert_eq(usage.zoom_min, Some(0.5))
  @test.assert_eq(usage.zoom_max, Some(2.0))
  @test.assert_eq(usage.print_subtype, Some(ocg_name_for_test("/Watermark")))
  @test.assert_eq(usage.print_state, Some(ocg_name_for_test("/OFF")))
  @test.assert_eq(usage.view_state, Some(ocg_name_for_test("/ON")))
  @test.assert_eq(
    usage.user,
    Some(
      (
        ocg_name_for_test("/Ind"),
        [ocg_bytes_for_test("Alice"), ocg_bytes_for_test("Bob")],
      ),
    ),
  )
  @test.assert_eq(usage.page_element_subtype, Some(ocg_name_for_test("/FG")))
  @test.assert_eq(
    content.default_config.name,
    Some(ocg_bytes_for_test("Default")),
  )
  @test.assert_eq(
    content.default_config.creator,
    Some(ocg_bytes_for_test("Author")),
  )
  @test.assert_eq(content.default_config.base_state, OcgOff)
  @test.assert_eq(content.default_config.on, [10])
  @test.assert_eq(content.default_config.off, [11])
  @test.assert_eq(content.default_config.intent, [ocg_name_for_test("/View")])
  let expected_apps : Array[@pdflite.PdfOcgAppDict] = [
    { event: OcgPrint, ocgs: [10], category: [ocg_name_for_test("/Print")] },
  ]
  @test.assert_eq(content.default_config.usage_applications, expected_apps)
  @test.assert_eq(
    content.default_config.order,
    Some([(Some(ocg_bytes_for_test("Layers")), [10])]),
  )
  @test.assert_eq(content.default_config.list_mode, OcgVisiblePages)
  @test.assert_eq(content.default_config.radio_button_groups, Some([[10, 11]]))
  @test.assert_eq(content.default_config.locked, [10])
  @test.assert_eq(content.configs.length(), 1)
  @test.assert_eq(content.configs[0].base_state, OcgUnchanged)
}

///|
test "PdfDocument ocg_get_list returns raw layer names" {
  let doc = ocg_document_with_content_for_test()
  @test.assert_eq(try! doc.ocg_get_list(), [ocg_bytes_for_test("Layer 1")])
  @test.assert_eq(try! @pdflite.pdf_ocg_get_list(doc), [
    ocg_bytes_for_test("Layer 1"),
  ])
  @test.assert_eq(try! ocg_catalog_document_for_test().ocg_get_list(), [])
}

///|
test "PdfDocument ocg_list_json exports cpdf optional content shape" {
  let doc = ocg_document_with_content_for_test()
  let usage_json = Json::object(
    Map::of([
      ("CreatorInfo-Creator", Json::string("tool")),
      ("CreatorInfo-Subtype", Json::string("/Artwork")),
      ("Language-Language", Json::string("en-US")),
      ("Language-Preferred", Json::string("/ON")),
      ("Export", Json::string("/ON")),
      ("Zoom-Min", Json::number(0.5)),
      ("Zoom-Max", Json::number(2.0)),
      ("Print-Subtype", Json::string("/Watermark")),
      ("Print-PrintState", Json::string("/OFF")),
      ("ViewState", Json::string("/ON")),
      ("User-Type", Json::string("/Ind")),
      ("User-Name", Json::array([Json::string("Alice"), Json::string("Bob")])),
      ("PageElement-Subtype", Json::string("/FG")),
    ]),
  )
  let appdict_json = Json::object(
    Map::of([
      ("Event", Json::string("/Print")),
      ("OCGs", Json::array([ocg_json_int_for_test(10)])),
      ("Category", Json::array([Json::string("/Print")])),
    ]),
  )
  let default_json = Json::object(
    Map::of([
      ("Name", Json::string("Default")),
      ("Creator", Json::string("Author")),
      ("BaseState", Json::string("/OFF")),
      ("ON", Json::array([ocg_json_int_for_test(10)])),
      ("OFF", Json::array([ocg_json_int_for_test(11)])),
      ("Intent", Json::array([Json::string("/View")])),
      ("AS", Json::array([appdict_json])),
      (
        "Order",
        Json::array([
          Json::object(
            Map::of([
              ("Name", Json::string("Layers")),
              ("OCGs", Json::array([ocg_json_int_for_test(10)])),
            ]),
          ),
        ]),
      ),
      ("ListMode", Json::string("/VisiblePages")),
      (
        "RBGroups",
        Json::array([
          Json::array([ocg_json_int_for_test(10), ocg_json_int_for_test(11)]),
        ]),
      ),
      ("Locked", Json::array([ocg_json_int_for_test(10)])),
    ]),
  )
  let config_json = Json::object(
    Map::of([
      ("Name", Json::null()),
      ("Creator", Json::null()),
      ("BaseState", Json::string("/Unchanged")),
      ("ON", Json::array([])),
      ("OFF", Json::array([])),
      ("Intent", Json::array([Json::string("/View")])),
      ("AS", Json::array([])),
      ("Order", Json::null()),
      ("ListMode", Json::string("/AllPages")),
      ("RBGroups", Json::null()),
      ("Locked", Json::array([])),
    ]),
  )
  let expected = Json::object(
    Map::of([
      (
        "OCGs",
        Json::object(
          Map::of([
            (
              "10",
              Json::object(
                Map::of([
                  ("Name", Json::string("Layer 1")),
                  (
                    "Intent",
                    Json::array([Json::string("/View"), Json::string("/Print")]),
                  ),
                  ("Usage", usage_json),
                ]),
              ),
            ),
          ]),
        ),
      ),
      ("Default", default_json),
      ("Configs", Json::array([config_json])),
    ]),
  )
  @test.assert_eq(try! doc.ocg_list_json(), expected)
  @test.assert_eq(try! @pdflite.pdf_ocg_list_json(doc), expected)
  @test.assert_eq(
    try! @pdflite.pdf_ocg_list_json_blob(doc),
    @utf8.encode(expected.stringify()),
  )
  @test.assert_eq(
    try! ocg_catalog_document_for_test().ocg_list_json(),
    Json::null(),
  )
}

///|
test "pdf_ocg_read_json parses exported optional content JSON" {
  let source = ocg_document_with_content_for_test()
  let json = try! source.ocg_list_json()
  guard (try! source.read_optional_content_groups()) is Some(expected) else {
    fail("expected source optional content")
  }
  @test.assert_eq(try! @pdflite.pdf_ocg_read_json(json), Some(expected))
  guard (try! @pdflite.pdf_ocg_read_json(json)) is Some(parsed) else {
    fail("expected parsed optional content")
  }
  guard parsed.ocgs[0].1.usage is Some(usage) else {
    fail("expected OCG usage")
  }
  @test.assert_eq(usage.view_state, Some(ocg_name_for_test("/ON")))
  @test.assert_eq(usage.page_element_subtype, Some(ocg_name_for_test("/FG")))
}

///|
test "PdfDocument ocg_replace_json writes parsed optional content" {
  let source = ocg_document_with_content_for_test()
  let json = try! source.ocg_list_json()
  guard (try! source.read_optional_content_groups()) is Some(expected) else {
    fail("expected source optional content")
  }
  let replaced = try! ocg_catalog_document_for_test().ocg_replace_json(json)
  let replaced_from_function = try! @pdflite.pdf_ocg_replace_json(
    json,
    ocg_catalog_document_for_test(),
  )
  @test.assert_eq(try! replaced.read_optional_content_groups(), Some(expected))
  @test.assert_eq(
    try! replaced_from_function.read_optional_content_groups(),
    Some(expected),
  )
  let unchanged = try! source.ocg_replace_json(Json::null())
  @test.assert_eq(try! unchanged.read_optional_content_groups(), Some(expected))
  @test.assert_eq(try! @pdflite.pdf_ocg_read_json(Json::null()), None)
}

///|
test "pdf_ocg_read_json rejects malformed optional content JSON" {
  let top_level : Result[@pdflite.PdfOptionalContent?, Error] = try? @pdflite.pdf_ocg_read_json(
    Json::array([]),
  )
  guard top_level is Err(@pdflite.PdfError::SoftError(_)) else {
    fail("expected @pdflite.PdfError::SoftError for top-level array")
  }
  let bad_default : Result[@pdflite.PdfOptionalContent?, Error] = try? @pdflite.pdf_ocg_read_json(
    Json::object(
      Map::of([
        ("OCGs", Json::object(Map([]))),
        ("Default", Json::object(Map([]))),
        ("Configs", Json::array([])),
      ]),
    ),
  )
  guard bad_default is Err(@pdflite.PdfError::SoftError(_)) else {
    fail("expected @pdflite.PdfError::SoftError for malformed config")
  }
}

///|
test "PdfDocument ocg_rename rewrites OCG dictionaries" {
  let doc = ocg_document_with_content_for_test()
  let renamed = doc.ocg_rename(
    ocg_bytes_for_test("Layer 1"),
    ocg_bytes_for_test("Renamed"),
  )
  let wrapper = @pdflite.pdf_ocg_rename(
    ocg_bytes_for_test("Layer 1"),
    ocg_bytes_for_test("Renamed"),
    doc,
  )
  @test.assert_eq(try! doc.ocg_get_list(), [ocg_bytes_for_test("Layer 1")])
  @test.assert_eq(try! renamed.ocg_get_list(), [ocg_bytes_for_test("Renamed")])
  @test.assert_eq(try! wrapper.ocg_get_list(), [ocg_bytes_for_test("Renamed")])
}

///|
test "PdfDocument ocg_order_all writes every group to default order" {
  let content = ocg_merge_content_for_test(7, "Layer A", OcgOn, [7], [])
  let content = {
    ..content,
    ocgs: [
      ..content.ocgs,
      (
        12,
        {
          name: ocg_bytes_for_test("Layer B"),
          intent: [ocg_name_for_test("/View")],
          usage: None,
        },
      ),
    ],
    default_config: { ..content.default_config, order: None },
  }
  let doc = try! ocg_catalog_document_for_test().write_optional_content_groups(
    content,
  )
  let ordered = try! doc.ocg_order_all()
  let wrapper = try! @pdflite.pdf_ocg_order_all(doc)
  guard (try! ordered.read_optional_content_groups()) is Some(read_back) else {
    fail("expected optional content")
  }
  @test.assert_eq(
    read_back.default_config.order,
    Some([(None, [7]), (None, [12])]),
  )
  @test.assert_eq(try! wrapper.read_optional_content_groups(), Some(read_back))
}

///|
test "PdfDocument ocg_coalesce removes duplicate names and rewrites references" {
  let key_custom = ocg_name_for_test("/Custom")
  let doc = ocg_catalog_document_for_test()
  doc.add_object_given_number(
    20,
    PdfDictionary([(key_custom, PdfIndirect(11))]),
  )
  let duplicate_content : @pdflite.PdfOptionalContent = {
    ocgs: [
      (
        10,
        {
          name: ocg_bytes_for_test("Layer"),
          intent: [ocg_name_for_test("/View")],
          usage: None,
        },
      ),
      (
        11,
        {
          name: ocg_bytes_for_test("Layer"),
          intent: [ocg_name_for_test("/Print")],
          usage: None,
        },
      ),
    ],
    default_config: {
      ..@pdflite.pdf_ocg_default_config(),
      on: [10, 11],
      off: [11],
      usage_applications: [
        { event: OcgView, ocgs: [11], category: [ocg_name_for_test("/View")] },
      ],
      order: Some([(None, [10]), (None, [11])]),
      radio_button_groups: Some([[10, 11]]),
      locked: [11],
    },
    configs: [{ ..@pdflite.pdf_ocg_default_config(), locked: [11] }],
  }
  let with_duplicates = try! doc.write_optional_content_groups(
    duplicate_content,
  )
  let coalesced = try! with_duplicates.ocg_coalesce()
  let wrapper = try! @pdflite.pdf_ocg_coalesce(with_duplicates)
  guard (try! coalesced.read_optional_content_groups()) is Some(content) else {
    fail("expected optional content")
  }
  @test.assert_eq(content.ocgs.length(), 1)
  @test.assert_eq(content.ocgs[0].0, 10)
  @test.assert_eq(content.ocgs[0].1.name, ocg_bytes_for_test("Layer"))
  @test.assert_eq(content.default_config.on, [10])
  @test.assert_eq(content.default_config.off, [10])
  @test.assert_eq(content.default_config.usage_applications[0].ocgs, [10])
  @test.assert_eq(content.default_config.order, Some([(None, [10])]))
  @test.assert_eq(content.default_config.radio_button_groups, Some([[10]]))
  @test.assert_eq(content.default_config.locked, [10])
  @test.assert_eq(content.configs[0].locked, [10])
  @test.assert_eq(
    coalesced.lookup_object_or_null(20).lookup_immediate(key_custom),
    Some(PdfIndirect(10)),
  )
  @test.assert_eq(coalesced.lookup_object_or_null(11), PdfNull)
  @test.assert_eq(try! wrapper.read_optional_content_groups(), Some(content))
}

///|
test "PdfDocument read_optional_content_groups prefers trailer root" {
  let doc = ocg_conflicting_root_document_for_test(true)
  @test.assert_eq(
    try! doc.read_optional_content_groups(),
    Some({
      ocgs: [],
      default_config: @pdflite.pdf_ocg_default_config(),
      configs: [],
    }),
  )
}

///|
test "PdfDocument read_optional_content_groups rejects unresolved trailer root" {
  let key_root = ocg_name_for_test("/Root")
  let key_type = ocg_name_for_test("/Type")
  let type_catalog = ocg_name_for_test("/Catalog")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(99))]))
  doc.add_object_given_number(
    1,
    PdfDictionary([(key_type, PdfNameObject(type_catalog))]),
  )
  let result : Result[@pdflite.PdfOptionalContent?, Error] = try? doc.read_optional_content_groups()
  guard result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected @pdflite.PdfError::RootExpected")
  }
}

///|
test "PdfDocument write_optional_content_groups builds readable OCG data" {
  let doc = ocg_catalog_document_for_test()
  let usage : @pdflite.PdfOcgUsage = {
    creator_info: Some(
      (ocg_bytes_for_test("tool"), ocg_name_for_test("/Artwork")),
    ),
    language: None,
    export_state: Some(ocg_name_for_test("/ON")),
    zoom_min: None,
    zoom_max: Some(3.0),
    print_subtype: None,
    print_state: Some(ocg_name_for_test("/OFF")),
    view_state: Some(ocg_name_for_test("/ON")),
    user: Some((ocg_name_for_test("/Ind"), [ocg_bytes_for_test("Alice")])),
    page_element_subtype: None,
  }
  let default_config = {
    ..@pdflite.pdf_ocg_default_config(),
    name: Some(ocg_bytes_for_test("Default")),
    base_state: OcgOff,
    on: [7],
    usage_applications: [
      { event: OcgPrint, ocgs: [7], category: [ocg_name_for_test("/Print")] },
    ],
    order: Some([(Some(ocg_bytes_for_test("Layers")), [7])]),
    list_mode: OcgVisiblePages,
    radio_button_groups: Some([[7]]),
    locked: [7],
  }
  let extra_config = {
    ..@pdflite.pdf_ocg_default_config(),
    base_state: OcgUnchanged,
  }
  let content : @pdflite.PdfOptionalContent = {
    ocgs: [
      (
        7,
        {
          name: ocg_bytes_for_test("Layer 7"),
          intent: [ocg_name_for_test("/View"), ocg_name_for_test("/Print")],
          usage: Some(usage),
        },
      ),
    ],
    default_config,
    configs: [extra_config],
  }
  let updated = try! doc.write_optional_content_groups(content)
  let updated_from_function = try! @pdflite.pdf_write_ocg(doc, content)
  @test.assert_eq(try! doc.read_optional_content_groups(), None)
  guard (try! updated.read_optional_content_groups()) is Some(read_back) else {
    fail("expected written optional content")
  }
  @test.assert_eq(read_back, content)
  @test.assert_eq(
    try! @pdflite.pdf_read_ocg(updated_from_function),
    Some(content),
  )
}

///|
test "PdfDocument write_optional_content_groups preserves trailer-root catalog entries" {
  let key_lang = ocg_name_for_test("/Lang")
  let key_page_mode = ocg_name_for_test("/PageMode")
  let key_ocproperties = ocg_name_for_test("/OCProperties")
  let doc = ocg_conflicting_root_document_for_test(false)
  let content : @pdflite.PdfOptionalContent = {
    ocgs: [],
    default_config: {
      ..@pdflite.pdf_ocg_default_config(),
      name: Some(ocg_bytes_for_test("Default")),
    },
    configs: [],
  }
  let updated = try! doc.write_optional_content_groups(content)
  @test.assert_eq(try! updated.read_optional_content_groups(), Some(content))
  let catalog = updated.lookup_object_or_null(updated.root())
  @test.assert_eq(catalog.lookup_immediate(key_lang), None)
  @test.assert_eq(
    catalog.lookup_immediate(key_page_mode),
    Some(ocg_name_object_for_test("/UseOC")),
  )
  guard catalog.lookup_immediate(key_ocproperties) is Some(_) else {
    fail("expected OCProperties")
  }
}

///|
test "pdf_optional_content_merge combines already-renumbered OCG metadata" {
  let first = try! ocg_catalog_document_for_test().write_optional_content_groups(
    ocg_merge_content_for_test(7, "Layer A", OcgOn, [7], []),
  )
  let second = try! ocg_catalog_document_for_test().write_optional_content_groups(
    ocg_merge_content_for_test(12, "Layer B", OcgOff, [], [12]),
  )
  guard (try! @pdflite.pdf_optional_content_merge([first, second]))
    is Some(merged) else {
    fail("expected merged optional content")
  }
  @test.assert_eq(merged.ocgs.length(), 2)
  @test.assert_eq(merged.ocgs[0].0, 7)
  @test.assert_eq(merged.ocgs[1].0, 12)
  @test.assert_eq(merged.default_config.base_state, OcgOff)
  @test.assert_eq(merged.default_config.on, [7])
  @test.assert_eq(merged.default_config.off, [12])
  @test.assert_eq(
    merged.default_config.order,
    Some([
      (Some(ocg_bytes_for_test("Layer A")), [7]),
      (Some(ocg_bytes_for_test("Layer B")), [12]),
    ]),
  )
  @test.assert_eq(merged.default_config.radio_button_groups, Some([[7], [12]]))
  @test.assert_eq(merged.configs.length(), 2)
  let written = try! ocg_catalog_document_for_test().write_optional_content_groups(
    merged,
  )
  @test.assert_eq(try! written.read_optional_content_groups(), Some(merged))
  @test.assert_eq(
    try! @pdflite.pdf_optional_content_merge([ocg_catalog_document_for_test()]),
    None,
  )
}

///|
test "PdfDocument remove_optional_content_groups removes catalog entry" {
  let doc = ocg_document_with_content_for_test()
  let key_ocproperties = ocg_name_for_test("/OCProperties")
  let updated = try! doc.remove_optional_content_groups()
  let updated_from_function = try! @pdflite.pdf_remove_ocg(doc)
  @test.assert_eq(try! (doc.read_optional_content_groups() is Some(_)), true)
  @test.assert_eq(try! updated.read_optional_content_groups(), None)
  @test.assert_eq(try! @pdflite.pdf_read_ocg(updated_from_function), None)
  @test.assert_eq(
    updated
    .lookup_object_or_null(updated.root())
    .lookup_immediate(key_ocproperties),
    None,
  )
}

///|
test "PdfDocument remove_optional_content_groups preserves trailer-root catalog entries" {
  let key_lang = ocg_name_for_test("/Lang")
  let key_page_mode = ocg_name_for_test("/PageMode")
  let key_ocproperties = ocg_name_for_test("/OCProperties")
  let doc = ocg_conflicting_root_document_for_test(true)
  let updated = try! doc.remove_optional_content_groups()
  @test.assert_eq(try! updated.read_optional_content_groups(), None)
  let catalog = updated.lookup_object_or_null(updated.root())
  @test.assert_eq(catalog.lookup_immediate(key_lang), None)
  @test.assert_eq(catalog.lookup_immediate(key_ocproperties), None)
  @test.assert_eq(
    catalog.lookup_immediate(key_page_mode),
    Some(ocg_name_object_for_test("/UseOC")),
  )
}

///|
test "PdfDocument optional content helpers require a root catalog" {
  let doc = @pdflite.pdf_document_empty()
  let content : @pdflite.PdfOptionalContent = {
    ocgs: [],
    default_config: @pdflite.pdf_ocg_default_config(),
    configs: [],
  }
  let read_result : Result[@pdflite.PdfOptionalContent?, Error] = try? doc.read_optional_content_groups()
  guard read_result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected @pdflite.PdfError::RootExpected")
  }
  let write_result : Result[@pdflite.PdfDocument, Error] = try? doc.write_optional_content_groups(
    content,
  )
  guard write_result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected @pdflite.PdfError::RootExpected")
  }
  let remove_result : Result[@pdflite.PdfDocument, Error] = try? doc.remove_optional_content_groups()
  guard remove_result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected @pdflite.PdfError::RootExpected")
  }
}
