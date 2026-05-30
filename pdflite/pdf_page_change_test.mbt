///|
fn page_change_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_change_assert_indirect_object_for_test(
  doc : @pdflite.PdfDocument,
  object : @syntax.PdfObject,
  expected : @syntax.PdfObject,
) -> Unit raise {
  match object {
    PdfIndirect(number) =>
      @test.assert_eq(doc.lookup_object_or_null(number), expected)
    _ => fail("expected indirect object")
  }
}

///|
fn page_change_hello_ops_for_test() -> Array[@content.PdfContentOp] {
  [
    Op_cm(@geometry.transform_translate(50.0, 770.0)),
    Op_BT,
    Op_Tf(page_change_name_for_test("/F0"), 36.0),
    Op_Tj(@ascii.encode("Hello, World!")),
    Op_ET,
  ]
}

///|
fn page_change_hello_resources_for_test() -> @syntax.PdfObject {
  let key_font = page_change_name_for_test("/Font")
  let key_type = page_change_name_for_test("/Type")
  let key_subtype = page_change_name_for_test("/Subtype")
  let key_basefont = page_change_name_for_test("/BaseFont")
  let font = @syntax.pdf_dictionary([
    (key_type, PdfNameObject(page_change_name_for_test("/Font"))),
    (key_subtype, PdfNameObject(page_change_name_for_test("/Type1"))),
    (key_basefont, PdfNameObject(page_change_name_for_test("/Times-Italic"))),
  ])
  @syntax.pdf_dictionary([
    (
      key_font,
      @syntax.pdf_dictionary([(page_change_name_for_test("/F0"), font)]),
    ),
  ])
}

///|
fn page_change_index_mediabox_for_test(index : Int) -> @syntax.PdfObject {
  PdfArray([
    PdfInteger(index),
    PdfInteger(0),
    PdfInteger(index + 100),
    PdfInteger(200),
  ])
}

///|
fn page_change_indexed_blank_for_test(index : Int) -> @page.PdfPage {
  {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    mediabox: page_change_index_mediabox_for_test(index),
  }
}

///|
fn page_change_xobject_resources_for_test(
  entries : ArrayView[(@pdflite.PdfName, @syntax.PdfObject)],
) -> @syntax.PdfObject {
  @syntax.pdf_dictionary([
    (page_change_name_for_test("/XObject"), @syntax.pdf_dictionary(entries)),
  ])
}

///|
fn page_change_draft_substitute_ops_for_test() -> Array[@content.PdfContentOp] {
  [
    Op_q,
    Op_w(0.0),
    Op_G(0.0),
    Op_re(0.0, 0.0, 1.0, 1.0),
    Op_m(0.0, 0.0),
    Op_l(1.0, 1.0),
    Op_m(0.0, 1.0),
    Op_l(1.0, 0.0),
    Op_S,
    Op_Q,
  ]
}

///|
fn page_change_draft_xobject_is_image_for_test(
  doc : @pdflite.PdfDocument,
  resources : @syntax.PdfObject,
  name : @pdflite.PdfName,
) -> Bool {
  match doc.lookup_direct(page_change_name_for_test("/XObject"), resources) {
    Some(xobjects) =>
      match doc.lookup_direct(name, xobjects) {
        Some(xobject) =>
          match
            doc.lookup_direct(page_change_name_for_test("/Subtype"), xobject) {
            Some(PdfNameObject(subtype)) =>
              subtype == page_change_name_for_test("/Image")
            _ => false
          }
        None => false
      }
    None => false
  }
}

///|
fn page_change_draft_remove_image_xobjects_for_test(
  doc : @pdflite.PdfDocument,
  resources : @syntax.PdfObject,
) -> @syntax.PdfObject {
  let key_xobject = page_change_name_for_test("/XObject")
  match resources {
    PdfDictionary(entries) => {
      let retained : Array[(@pdflite.PdfName, @syntax.PdfObject)] = []
      for entry in entries {
        let (key, value) = entry
        if key == key_xobject {
          match doc.direct(value) {
            PdfDictionary(xobjects) => {
              let kept : Array[(@pdflite.PdfName, @syntax.PdfObject)] = []
              for xobject_entry in xobjects {
                let (name, _) = xobject_entry
                if !page_change_draft_xobject_is_image_for_test(
                    doc, resources, name,
                  ) {
                  kept.push(xobject_entry)
                }
              }
              retained.push((key, PdfDictionary(kept)))
            }
            _ => retained.push(entry)
          }
        } else {
          retained.push(entry)
        }
      }
      PdfDictionary(retained)
    }
    _ => resources
  }
}

///|
fn page_change_draft_ops_for_test(
  doc : @pdflite.PdfDocument,
  resources : @syntax.PdfObject,
  ops : ArrayView[@content.PdfContentOp],
) -> Array[@content.PdfContentOp] {
  let output : Array[@content.PdfContentOp] = []
  for op in ops {
    match op {
      Op_Do(name) if page_change_draft_xobject_is_image_for_test(
          doc, resources, name,
        ) =>
        for replacement in page_change_draft_substitute_ops_for_test() {
          output.push(replacement)
        }
      Op_InlineImage(_, _, _) =>
        for replacement in page_change_draft_substitute_ops_for_test() {
          output.push(replacement)
        }
      _ => output.push(op)
    }
  }
  output
}

///|
fn page_change_draft_page_for_test(
  doc : @pdflite.PdfDocument,
  page : @page.PdfPage,
) -> @page.PdfPage {
  let ops = try! doc.parse_content_ops(page.content)
  let stream = try! @pdflite.pdf_content_stream_of_ops(
    page_change_draft_ops_for_test(doc, page.resources, ops),
  )
  let encoded = try! @pdflite.pdf_encode_stream_with_filter(
    page_change_name_for_test("/FlateDecode"),
    stream,
  )
  {
    ..page,
    content: [encoded],
    resources: page_change_draft_remove_image_xobjects_for_test(
      doc,
      page.resources,
    ),
  }
}

///|
fn page_change_draft_document_for_test(
  doc : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument {
  let pages = try! doc.pages_of_pagetree()
  let rewritten : Array[@page.PdfPage] = []
  for page in pages {
    rewritten.push(page_change_draft_page_for_test(doc, page))
  }
  let page_root = try! doc.add_pagetree(rewritten)
  ignore(try! doc.add_root(page_root, []))
  try! doc.remove_unreferenced()
  doc
}

///|
fn page_change_destination_entries_for_test(
  doc : @pdflite.PdfDocument,
) -> Array[(@pdflite.PdfBytes, @syntax.PdfObject)] {
  match
    doc.lookup_chain(doc.lookup_object_or_null(doc.root()), [
      page_change_name_for_test("/Names"),
      page_change_name_for_test("/Dests"),
    ]) {
    Some(tree) => doc.read_name_tree(tree)
    None => []
  }
}

///|
fn page_change_catalog_destination_for_test(
  doc : @pdflite.PdfDocument,
  name : String,
) -> @syntax.PdfObject? {
  match
    doc
    .lookup_object_or_null(doc.root())
    .lookup_immediate(page_change_name_for_test("/Dests")) {
    Some(PdfDictionary(entries)) =>
      for entry in entries {
        let (key, value) = entry
        if key == page_change_name_for_test(name) {
          break Some(value)
        }
      } nobreak {
        None
      }
    _ => None
  }
}

///|
test "PdfDocument change_pages writes modified content into a replacement page tree" {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      try! @pdflite.pdf_content_stream_of_ops(page_change_hello_ops_for_test()),
    ],
    resources: page_change_hello_resources_for_test(),
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  let original_pages = try! doc.pages_of_pagetree()
  let changed_page = try! doc.postpend_operators(original_pages[0], [Op_g(0.25)])
  let changed = try! doc.change_pages([changed_page])
  @test.assert_eq(
    try! doc.parse_content_ops(original_pages[0].content),
    page_change_hello_ops_for_test(),
  )
  let changed_pages = try! changed.pages_of_pagetree()
  let expected_ops : Array[@content.PdfContentOp] = [
    Op_q,
    ..page_change_hello_ops_for_test(),
    Op_Q,
    Op_g(0.25),
  ]
  @test.assert_eq(
    try! changed.parse_content_ops(changed_pages[0].content),
    expected_ops,
  )
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(
    try! @pdflite.pdf_write_document(changed),
  )
  @test.assert_eq(
    try! reparsed.parse_content_ops(
      (try! reparsed.pages_of_pagetree())[0].content,
    ),
    expected_ops,
  )
}

///|
test "PdfDocument change_pages preserves document metadata and trailer entries" {
  let key_id = page_change_name_for_test("/ID")
  let key_lang = page_change_name_for_test("/Lang")
  let doc = @pdflite.pdf_document_empty()
  doc.set_version(1, 7)
  doc.set_first_xref(4096)
  let page_root = try! doc.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(
    try! doc.add_root(page_root, [(key_lang, PdfString(@ascii.encode("en-US")))]),
  )
  let document_id : @syntax.PdfObject = PdfArray([
    PdfString(@ascii.encode("first-id")),
    PdfString(@ascii.encode("second-id")),
  ])
  doc.set_trailer_dict(doc.trailer_dict().add_dict_entry(key_id, document_id))

  let changed = try! doc.change_pages([
    { ..@page.pdf_page_blank(@geometry.paper_a4), rotate: Rotate90 },
  ])
  @test.assert_eq(changed.version(), (1, 7))
  @test.assert_eq(changed.first_xref(), 4096)
  @test.assert_eq(
    changed.trailer_dict().lookup_immediate(key_id),
    Some(document_id),
  )
  let root_number = match
    changed.trailer_dict().lookup_immediate(page_change_name_for_test("/Root")) {
    Some(PdfIndirect(root_number)) => root_number
    _ => fail("expected trailer root")
  }
  @test.assert_eq(
    changed.lookup_object_or_null(root_number).lookup_immediate(key_lang),
    Some(PdfString(@ascii.encode("en-US"))),
  )
  @test.assert_eq((try! changed.pages_of_pagetree())[0].rotate, Rotate90)
}

///|
test "pdftest-style content parse rewrite change_pages round trip" {
  let doc = @pdflite.pdf_document_empty()
  let ops = page_change_hello_ops_for_test()
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    content: [
      try! @pdflite.pdf_content_stream_of_ops(ops[0:3]),
      try! @pdflite.pdf_content_stream_of_ops(ops[3:ops.length()]),
    ],
    resources: page_change_hello_resources_for_test(),
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    try! @pdflite.pdf_write_document(doc),
  )
  let parsed_pages = try! parsed.pages_of_pagetree()
  let rewritten_pages : Array[@page.PdfPage] = []
  for parsed_page in parsed_pages {
    let parsed_ops = try! parsed.parse_content_ops(parsed_page.content)
    rewritten_pages.push({
      ..parsed_page,
      content: [try! @pdflite.pdf_content_stream_of_ops(parsed_ops)],
    })
  }
  let changed = try! parsed.change_pages(rewritten_pages)
  try! changed.remove_unreferenced()
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(
    try! @pdflite.pdf_write_document(changed),
  )
  let output_pages = try! reparsed.pages_of_pagetree()
  @test.assert_eq(output_pages.length(), 1)
  @test.assert_eq(output_pages[0].content.length(), 1)
  @test.assert_eq(
    try! reparsed.parse_content_ops(output_pages[0].content),
    page_change_hello_ops_for_test(),
  )
}

///|
test "pdfdraft-style image replacement removes image xobjects and roundtrips" {
  let key_length = page_change_name_for_test("/Length")
  let key_subtype = page_change_name_for_test("/Subtype")
  let image_name = page_change_name_for_test("/Im1")
  let form_name = page_change_name_for_test("/Fm1")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    7,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (key_subtype, PdfNameObject(page_change_name_for_test("/Image"))),
        (key_length, PdfInteger(0)),
      ]),
      StreamGot([]),
    ),
  )
  doc.add_object_given_number(
    8,
    @syntax.pdf_stream(
      @syntax.pdf_dictionary([
        (key_subtype, PdfNameObject(page_change_name_for_test("/Form"))),
        (key_length, PdfInteger(3)),
      ]),
      StreamGot(@ascii.encode("q Q")),
    ),
  )
  let page = {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    resources: page_change_xobject_resources_for_test([
      (image_name, PdfIndirect(7)),
      (form_name, PdfIndirect(8)),
    ]),
    content: [
      try! @pdflite.pdf_content_stream_of_ops([
        Op_Do(image_name),
        Op_Do(form_name),
        Op_InlineImage(
          PdfDictionary([
            (page_change_name_for_test("/W"), PdfInteger(1)),
            (page_change_name_for_test("/H"), PdfInteger(1)),
            (
              page_change_name_for_test("/CS"),
              PdfNameObject(page_change_name_for_test("/DeviceGray")),
            ),
            (page_change_name_for_test("/BPC"), PdfInteger(1)),
          ]),
          None,
          Bytes::from_array([0]),
        ),
      ]),
    ],
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, []))
  let drafted = page_change_draft_document_for_test(doc)
  let drafted_pages = try! drafted.pages_of_pagetree()
  @test.assert_eq(drafted_pages.length(), 1)
  @test.assert_eq(
    try! drafted.parse_content_ops(drafted_pages[0].content),
    [
      ..page_change_draft_substitute_ops_for_test(),
      Op_Do(form_name),
      ..page_change_draft_substitute_ops_for_test(),
    ],
  )
  @test.assert_eq(drafted.lookup_object_or_null(7), PdfNull)
  guard drafted.lookup_object_or_null(8) is PdfStreamObject(_) else {
    fail("expected form xobject to remain")
  }
  guard drafted.lookup_direct(
      page_change_name_for_test("/XObject"),
      drafted_pages[0].resources,
    )
    is Some(PdfDictionary(xobjects)) else {
    fail("expected retained XObject dictionary")
  }
  @test.assert_eq(xobjects, [(form_name, PdfIndirect(8))])
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(
    try! @pdflite.pdf_write_document(drafted),
  )
  let reparsed_pages = try! reparsed.pages_of_pagetree()
  @test.assert_eq(
    try! reparsed.parse_content_ops(reparsed_pages[0].content),
    [
      ..page_change_draft_substitute_ops_for_test(),
      Op_Do(form_name),
      ..page_change_draft_substitute_ops_for_test(),
    ],
  )
}

///|
test "PdfDocument change_pages renumbers same-count page references" {
  let key_open_action = page_change_name_for_test("/OpenAction")
  let type_fit = page_change_name_for_test("/Fit")
  let doc = @pdflite.pdf_document_empty()
  let first = @page.pdf_page_blank(@geometry.paper_a4)
  let second = { ..@page.pdf_page_blank(@geometry.paper_a4), rotate: Rotate90 }
  let page_root = try! doc.add_pagetree([first, second])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([PdfIndirect(old_numbers[0]), PdfNameObject(type_fit)]),
    ),
  )
  let changed = try! doc.change_pages(
    try! doc.pages_of_pagetree(),
    change_references=true,
  )
  let new_numbers = try! changed.page_reference_numbers()
  @test.assert_eq(old_numbers.length(), 2)
  @test.assert_eq(new_numbers.length(), 2)
  @test.assert_eq(
    changed
    .lookup_object_or_null(changed.root())
    .lookup_immediate(key_open_action),
    Some(PdfArray([PdfIndirect(new_numbers[0]), PdfNameObject(type_fit)])),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(doc.root()).lookup_immediate(key_open_action),
    Some(PdfArray([PdfIndirect(old_numbers[0]), PdfNameObject(type_fit)])),
  )
}

///|
test "PdfDocument change_pages transforms bookmark destinations with matrices" {
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: @ascii.encode("Top"),
      target: DestXYZ(
        TargetPageObject(old_numbers[0]),
        Some(1.0),
        Some(2.0),
        None,
      ),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let changed = try! bookmarked.change_pages(
    try! bookmarked.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @geometry.transform_translate(10.0, 20.0))],
  )
  let new_numbers = try! changed.page_reference_numbers()
  @test.assert_eq(try! changed.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: @ascii.encode("Top"),
      target: DestXYZ(
        TargetPageObject(new_numbers[0]),
        Some(11.0),
        Some(22.0),
        None,
      ),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
test "PdfDocument change_pages transforms link annotations and open action" {
  let key_annots = page_change_name_for_test("/Annots")
  let key_subtype = page_change_name_for_test("/Subtype")
  let key_dest = page_change_name_for_test("/Dest")
  let key_action = page_change_name_for_test("/A")
  let key_open_action = page_change_name_for_test("/OpenAction")
  let key_s = page_change_name_for_test("/S")
  let key_d = page_change_name_for_test("/D")
  let type_link = page_change_name_for_test("/Link")
  let type_goto = page_change_name_for_test("/GoTo")
  let type_xyz = page_change_name_for_test("/XYZ")
  let direct_annotation_number = 20
  let action_annotation_number = 21
  let annotation_array_number = 22
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    old_numbers[0],
    try! doc
    .lookup_object_or_null(old_numbers[0])
    .add_dict_entry(key_annots, PdfIndirect(annotation_array_number)),
  )
  doc.add_object_given_number(
    annotation_array_number,
    PdfArray([
      PdfIndirect(direct_annotation_number),
      PdfIndirect(action_annotation_number),
      @syntax.pdf_dictionary([
        (key_subtype, PdfNameObject(type_link)),
        (
          key_dest,
          PdfArray([
            PdfIndirect(old_numbers[0]),
            PdfNameObject(type_xyz),
            PdfInteger(7),
            PdfInteger(8),
            PdfNull,
          ]),
        ),
      ]),
      @syntax.pdf_dictionary([
        (key_subtype, PdfNameObject(type_link)),
        (
          key_action,
          @syntax.pdf_dictionary([
            (key_s, PdfNameObject(type_goto)),
            (
              key_d,
              PdfArray([
                PdfIndirect(old_numbers[0]),
                PdfNameObject(type_xyz),
                PdfInteger(9),
                PdfInteger(10),
                PdfNull,
              ]),
            ),
          ]),
        ),
      ]),
    ]),
  )
  doc.add_object_given_number(
    direct_annotation_number,
    @syntax.pdf_dictionary([
      (key_subtype, PdfNameObject(type_link)),
      (
        key_dest,
        PdfArray([
          PdfIndirect(old_numbers[0]),
          PdfNameObject(type_xyz),
          PdfInteger(3),
          PdfInteger(4),
          PdfNull,
        ]),
      ),
    ]),
  )
  doc.add_object_given_number(
    action_annotation_number,
    @syntax.pdf_dictionary([
      (key_subtype, PdfNameObject(type_link)),
      (
        key_action,
        @syntax.pdf_dictionary([
          (key_s, PdfNameObject(type_goto)),
          (
            key_d,
            PdfArray([
              PdfIndirect(old_numbers[0]),
              PdfNameObject(type_xyz),
              PdfInteger(5),
              PdfInteger(6),
              PdfNull,
            ]),
          ),
        ]),
      ),
    ]),
  )
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([
        PdfIndirect(old_numbers[0]),
        PdfNameObject(type_xyz),
        PdfInteger(1),
        PdfInteger(2),
        PdfNull,
      ]),
    ),
  )
  let changed = try! doc.change_pages(
    try! doc.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @geometry.transform_translate(10.0, 20.0))],
  )
  let new_numbers = try! changed.page_reference_numbers()
  match
    changed
    .lookup_object_or_null(direct_annotation_number)
    .lookup_immediate(key_dest) {
    Some(destination) =>
      page_change_assert_indirect_object_for_test(
        changed,
        destination,
        PdfArray([
          PdfIndirect(new_numbers[0]),
          PdfNameObject(type_xyz),
          PdfReal(13.0),
          PdfReal(24.0),
          PdfNull,
        ]),
      )
    _ => fail("expected transformed indirect destination")
  }
  match
    changed
    .lookup_object_or_null(action_annotation_number)
    .lookup_immediate(key_action) {
    Some(PdfDictionary(_) as action) =>
      match action.lookup_immediate(key_d) {
        Some(destination) =>
          page_change_assert_indirect_object_for_test(
            changed,
            destination,
            PdfArray([
              PdfIndirect(new_numbers[0]),
              PdfNameObject(type_xyz),
              PdfReal(15.0),
              PdfReal(26.0),
              PdfNull,
            ]),
          )
        _ => fail("expected transformed indirect action destination")
      }
    _ => fail("expected transformed link action")
  }
  @test.assert_eq(
    changed.lookup_object_or_null(new_numbers[0]).lookup_immediate(key_annots),
    Some(PdfIndirect(annotation_array_number)),
  )
  match changed.lookup_object_or_null(annotation_array_number) {
    PdfArray(
      [
        PdfIndirect(_),
        PdfIndirect(_),
        PdfDictionary(_) as direct_dest_annotation,
        PdfDictionary(_) as direct_action_annotation,
      ]
    ) => {
      match direct_dest_annotation.lookup_immediate(key_dest) {
        Some(destination) =>
          page_change_assert_indirect_object_for_test(
            changed,
            destination,
            PdfArray([
              PdfIndirect(new_numbers[0]),
              PdfNameObject(type_xyz),
              PdfReal(17.0),
              PdfReal(28.0),
              PdfNull,
            ]),
          )
        _ => fail("expected transformed direct annotation destination")
      }
      match direct_action_annotation.lookup_immediate(key_action) {
        Some(PdfDictionary(_) as action) =>
          match action.lookup_immediate(key_d) {
            Some(destination) =>
              page_change_assert_indirect_object_for_test(
                changed,
                destination,
                PdfArray([
                  PdfIndirect(new_numbers[0]),
                  PdfNameObject(type_xyz),
                  PdfReal(19.0),
                  PdfReal(30.0),
                  PdfNull,
                ]),
              )
            _ => fail("expected transformed direct action destination")
          }
        _ => fail("expected transformed direct link action")
      }
    }
    _ => fail("expected direct link annotations in indirect annotation array")
  }
  match
    changed
    .lookup_object_or_null(changed.root())
    .lookup_immediate(key_open_action) {
    Some(destination) =>
      page_change_assert_indirect_object_for_test(
        changed,
        destination,
        PdfArray([
          PdfIndirect(new_numbers[0]),
          PdfNameObject(type_xyz),
          PdfReal(11.0),
          PdfReal(22.0),
          PdfNull,
        ]),
      )
    _ => fail("expected transformed indirect open action")
  }
}

///|
test "PdfDocument change_pages leaves full-page fit destinations untransformed" {
  let key_annots = page_change_name_for_test("/Annots")
  let key_subtype = page_change_name_for_test("/Subtype")
  let key_dest = page_change_name_for_test("/Dest")
  let key_action = page_change_name_for_test("/A")
  let key_open_action = page_change_name_for_test("/OpenAction")
  let key_s = page_change_name_for_test("/S")
  let key_d = page_change_name_for_test("/D")
  let type_link = page_change_name_for_test("/Link")
  let type_goto = page_change_name_for_test("/GoTo")
  let type_fit = page_change_name_for_test("/Fit")
  let type_fitb = page_change_name_for_test("/FitB")
  let direct_annotation_number = 20
  let action_annotation_number = 21
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    old_numbers[0],
    try! doc
    .lookup_object_or_null(old_numbers[0])
    .add_dict_entry(
      key_annots,
      PdfArray([
        PdfIndirect(direct_annotation_number),
        PdfIndirect(action_annotation_number),
      ]),
    ),
  )
  doc.add_object_given_number(
    direct_annotation_number,
    @syntax.pdf_dictionary([
      (key_subtype, PdfNameObject(type_link)),
      (
        key_dest,
        PdfArray([PdfIndirect(old_numbers[0]), PdfNameObject(type_fit)]),
      ),
    ]),
  )
  doc.add_object_given_number(
    action_annotation_number,
    @syntax.pdf_dictionary([
      (key_subtype, PdfNameObject(type_link)),
      (
        key_action,
        @syntax.pdf_dictionary([
          (key_s, PdfNameObject(type_goto)),
          (
            key_d,
            PdfArray([PdfIndirect(old_numbers[0]), PdfNameObject(type_fitb)]),
          ),
        ]),
      ),
    ]),
  )
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([PdfIndirect(old_numbers[0]), PdfNameObject(type_fitb)]),
    ),
  )
  let changed = try! doc.change_pages(
    try! doc.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @geometry.transform_translate(10.0, 20.0))],
  )
  let new_numbers = try! changed.page_reference_numbers()
  @test.assert_eq(
    changed
    .lookup_object_or_null(direct_annotation_number)
    .lookup_immediate(key_dest),
    Some(PdfArray([PdfIndirect(new_numbers[0]), PdfNameObject(type_fit)])),
  )
  match
    changed
    .lookup_object_or_null(action_annotation_number)
    .lookup_immediate(key_action) {
    Some(PdfDictionary(_) as action) =>
      @test.assert_eq(
        action.lookup_immediate(key_d),
        Some(PdfArray([PdfIndirect(new_numbers[0]), PdfNameObject(type_fitb)])),
      )
    _ => fail("expected direct link action")
  }
  @test.assert_eq(
    changed
    .lookup_object_or_null(changed.root())
    .lookup_immediate(key_open_action),
    Some(PdfArray([PdfIndirect(new_numbers[0]), PdfNameObject(type_fitb)])),
  )
}

///|
test "PdfDocument change_pages leaves integer page destinations untransformed" {
  let key_open_action = page_change_name_for_test("/OpenAction")
  let type_xyz = page_change_name_for_test("/XYZ")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([
        PdfInteger(0),
        PdfNameObject(type_xyz),
        PdfInteger(1),
        PdfInteger(2),
        PdfNull,
      ]),
    ),
  )
  let changed = try! doc.change_pages(
    try! doc.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @geometry.transform_translate(10.0, 20.0))],
  )
  @test.assert_eq(
    changed
    .lookup_object_or_null(changed.root())
    .lookup_immediate(key_open_action),
    Some(
      PdfArray([
        PdfInteger(0),
        PdfNameObject(type_xyz),
        PdfInteger(1),
        PdfInteger(2),
        PdfNull,
      ]),
    ),
  )
}

///|
test "PdfDocument change_pages tolerates malformed matrix destinations" {
  let key_annots = page_change_name_for_test("/Annots")
  let key_subtype = page_change_name_for_test("/Subtype")
  let key_dest = page_change_name_for_test("/Dest")
  let key_open_action = page_change_name_for_test("/OpenAction")
  let type_link = page_change_name_for_test("/Link")
  let type_fitr = page_change_name_for_test("/FitR")
  let bad_coordinate = page_change_name_for_test("/Bad")
  let annotation_number = 20
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  let bad_destination : @syntax.PdfObject = PdfArray([
    PdfIndirect(old_numbers[0]),
    PdfNameObject(type_fitr),
    PdfNameObject(bad_coordinate),
    PdfInteger(2),
    PdfInteger(3),
    PdfInteger(4),
  ])
  doc.add_object_given_number(
    old_numbers[0],
    try! doc
    .lookup_object_or_null(old_numbers[0])
    .add_dict_entry(key_annots, PdfArray([PdfIndirect(annotation_number)])),
  )
  doc.add_object_given_number(
    annotation_number,
    @syntax.pdf_dictionary([
      (key_subtype, PdfNameObject(type_link)),
      (key_dest, bad_destination),
    ]),
  )
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_open_action, bad_destination),
  )
  let changed = try! doc.change_pages(
    try! doc.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @geometry.transform_translate(10.0, 20.0))],
  )
  let new_numbers = try! changed.page_reference_numbers()
  let renumbered_bad_destination : @syntax.PdfObject = PdfArray([
    PdfIndirect(new_numbers[0]),
    PdfNameObject(type_fitr),
    PdfNameObject(bad_coordinate),
    PdfInteger(2),
    PdfInteger(3),
    PdfInteger(4),
  ])
  @test.assert_eq(
    changed.lookup_object_or_null(annotation_number).lookup_immediate(key_dest),
    Some(renumbered_bad_destination),
  )
  @test.assert_eq(
    changed
    .lookup_object_or_null(changed.root())
    .lookup_immediate(key_open_action),
    Some(renumbered_bad_destination),
  )
}

///|
test "PdfDocument change_pages tolerates malformed action matrix destinations" {
  let key_annots = page_change_name_for_test("/Annots")
  let key_subtype = page_change_name_for_test("/Subtype")
  let key_action = page_change_name_for_test("/A")
  let key_open_action = page_change_name_for_test("/OpenAction")
  let key_s = page_change_name_for_test("/S")
  let key_d = page_change_name_for_test("/D")
  let type_link = page_change_name_for_test("/Link")
  let type_goto = page_change_name_for_test("/GoTo")
  let type_fitr = page_change_name_for_test("/FitR")
  let bad_coordinate = page_change_name_for_test("/Bad")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  let bad_destination : @syntax.PdfObject = PdfArray([
    PdfIndirect(old_numbers[0]),
    PdfNameObject(type_fitr),
    PdfNameObject(bad_coordinate),
    PdfInteger(2),
    PdfInteger(3),
    PdfInteger(4),
  ])
  let bad_action : @syntax.PdfObject = @syntax.pdf_dictionary([
    (key_s, PdfNameObject(type_goto)),
    (key_d, bad_destination),
  ])
  let bad_annotation : @syntax.PdfObject = @syntax.pdf_dictionary([
    (key_subtype, PdfNameObject(type_link)),
    (key_action, bad_action),
  ])
  doc.add_object_given_number(
    old_numbers[0],
    try! doc
    .lookup_object_or_null(old_numbers[0])
    .add_dict_entry(key_annots, PdfArray([bad_annotation])),
  )
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_open_action, bad_action),
  )
  let changed = try! doc.change_pages(
    try! doc.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @geometry.transform_translate(10.0, 20.0))],
  )
  let new_numbers = try! changed.page_reference_numbers()
  let renumbered_bad_destination : @syntax.PdfObject = PdfArray([
    PdfIndirect(new_numbers[0]),
    PdfNameObject(type_fitr),
    PdfNameObject(bad_coordinate),
    PdfInteger(2),
    PdfInteger(3),
    PdfInteger(4),
  ])
  let renumbered_bad_action : @syntax.PdfObject = @syntax.pdf_dictionary([
    (key_s, PdfNameObject(type_goto)),
    (key_d, renumbered_bad_destination),
  ])
  let renumbered_bad_annotation : @syntax.PdfObject = @syntax.pdf_dictionary([
    (key_subtype, PdfNameObject(type_link)),
    (key_action, renumbered_bad_action),
  ])
  @test.assert_eq(
    changed.lookup_object_or_null(new_numbers[0]).lookup_immediate(key_annots),
    Some(PdfArray([renumbered_bad_annotation])),
  )
  @test.assert_eq(
    changed
    .lookup_object_or_null(changed.root())
    .lookup_immediate(key_open_action),
    Some(renumbered_bad_action),
  )
}

///|
test "PdfDocument change_pages tolerates malformed catalog matrix destinations" {
  let key_names = page_change_name_for_test("/Names")
  let key_dests = page_change_name_for_test("/Dests")
  let type_fitr = page_change_name_for_test("/FitR")
  let bad_coordinate = page_change_name_for_test("/Bad")
  let named_destination = page_change_name_for_test("/BadChapter")
  let string_destination = @ascii.encode("bad-chapter")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  let bad_destination : @syntax.PdfObject = PdfArray([
    PdfIndirect(old_numbers[0]),
    PdfNameObject(type_fitr),
    PdfNameObject(bad_coordinate),
    PdfInteger(2),
    PdfInteger(3),
    PdfInteger(4),
  ])
  let dest_tree = doc.build_name_tree([(string_destination, bad_destination)])
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_names, PdfDictionary([(key_dests, dest_tree)])),
  )
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_dests,
      PdfDictionary([(named_destination, bad_destination)]),
    ),
  )
  let changed = try! doc.change_pages(
    try! doc.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @geometry.transform_translate(10.0, 20.0))],
  )
  let new_numbers = try! changed.page_reference_numbers()
  let renumbered_bad_destination : @syntax.PdfObject = PdfArray([
    PdfIndirect(new_numbers[0]),
    PdfNameObject(type_fitr),
    PdfNameObject(bad_coordinate),
    PdfInteger(2),
    PdfInteger(3),
    PdfInteger(4),
  ])
  @test.assert_eq(page_change_destination_entries_for_test(changed), [
    (string_destination, renumbered_bad_destination),
  ])
  @test.assert_eq(
    page_change_catalog_destination_for_test(changed, "/BadChapter"),
    Some(renumbered_bad_destination),
  )
}

///|
test "PdfDocument change_pages transforms named destination definitions" {
  let key_names = page_change_name_for_test("/Names")
  let key_dests = page_change_name_for_test("/Dests")
  let type_xyz = page_change_name_for_test("/XYZ")
  let type_fith = page_change_name_for_test("/FitH")
  let named_destination = page_change_name_for_test("/Chapter")
  let string_destination = @ascii.encode("chapter")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  let dest_tree = doc.build_name_tree([
    (
      string_destination,
      PdfArray([
        PdfIndirect(old_numbers[0]),
        PdfNameObject(type_xyz),
        PdfInteger(1),
        PdfInteger(2),
        PdfNull,
      ]),
    ),
  ])
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_names, PdfDictionary([(key_dests, dest_tree)])),
  )
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_dests,
      PdfDictionary([
        (
          named_destination,
          PdfArray([
            PdfIndirect(old_numbers[0]),
            PdfNameObject(type_fith),
            PdfInteger(5),
          ]),
        ),
      ]),
    ),
  )
  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: @ascii.encode("Named"),
      target: DestNamed(named_destination),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: @ascii.encode("String"),
      target: DestString(string_destination),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let changed = try! bookmarked.change_pages(
    try! bookmarked.pages_of_pagetree(),
    change_references=true,
    matrices=[(1, @geometry.transform_translate(10.0, 20.0))],
  )
  let new_numbers = try! changed.page_reference_numbers()
  @test.assert_eq(page_change_destination_entries_for_test(changed), [
    (
      string_destination,
      PdfArray([
        PdfIndirect(new_numbers[0]),
        PdfNameObject(type_xyz),
        PdfReal(11.0),
        PdfReal(22.0),
        PdfNull,
      ]),
    ),
  ])
  @test.assert_eq(
    page_change_catalog_destination_for_test(changed, "/Chapter"),
    Some(
      PdfArray([
        PdfIndirect(new_numbers[0]),
        PdfNameObject(type_fith),
        PdfReal(25.0),
      ]),
    ),
  )
  @test.assert_eq(try! changed.read_bookmarks(), [
    {
      level: 0,
      text: @ascii.encode("Named"),
      target: DestFitH(TargetPageObject(new_numbers[0]), Some(25.0)),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: @ascii.encode("String"),
      target: DestXYZ(
        TargetPageObject(new_numbers[0]),
        Some(11.0),
        Some(22.0),
        None,
      ),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
test "PdfDocument change_pages leaves references when count differs without mapping" {
  let key_open_action = page_change_name_for_test("/OpenAction")
  let type_xyz = page_change_name_for_test("/XYZ")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
    @page.pdf_page_blank(@geometry.paper_a4),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([
        PdfIndirect(old_numbers[1]),
        PdfNameObject(type_xyz),
        PdfInteger(1),
        PdfInteger(2),
        PdfNull,
      ]),
    ),
  )
  let changed = try! doc.change_pages(
    [@page.pdf_page_blank(@geometry.paper_a4)],
    change_references=true,
    matrices=[(1, @geometry.transform_translate(10.0, 20.0))],
  )
  @test.assert_eq((try! changed.page_reference_numbers()).length(), 1)
  @test.assert_eq(
    changed
    .lookup_object_or_null(changed.root())
    .lookup_immediate(key_open_action),
    Some(
      PdfArray([
        PdfIndirect(old_numbers[1]),
        PdfNameObject(type_xyz),
        PdfInteger(1),
        PdfInteger(2),
        PdfNull,
      ]),
    ),
  )
}

///|
test "PdfDocument change_pages accepts explicit serial reference changes" {
  let key_open_action = page_change_name_for_test("/OpenAction")
  let type_fit = page_change_name_for_test("/Fit")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_change_indexed_blank_for_test(0),
    page_change_indexed_blank_for_test(1),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([PdfIndirect(old_numbers[1]), PdfNameObject(type_fit)]),
    ),
  )
  let changed = try! doc.change_pages(
    [page_change_indexed_blank_for_test(9)],
    change_references=true,
    changes=[(2, 1)],
  )
  let new_numbers = try! changed.page_reference_numbers()
  @test.assert_eq(new_numbers.length(), 1)
  @test.assert_eq(
    changed
    .lookup_object_or_null(changed.root())
    .lookup_immediate(key_open_action),
    Some(PdfArray([PdfIndirect(new_numbers[0]), PdfNameObject(type_fit)])),
  )

  let bad_old : Result[@pdflite.PdfDocument, Error] = try? doc.change_pages(
    [page_change_indexed_blank_for_test(9)],
    change_references=true,
    changes=[(3, 1)],
  )
  guard bad_old is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected @pdflite.PdfError::PageTreeExpected for bad old serial")
  }
  let bad_new : Result[@pdflite.PdfDocument, Error] = try? doc.change_pages(
    [page_change_indexed_blank_for_test(9)],
    change_references=true,
    changes=[(1, 2)],
  )
  guard bad_new is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected @pdflite.PdfError::PageTreeExpected for bad new serial")
  }
}

///|
test "PdfDocument change_pages skips bookmark matrices when page count changes" {
  let key_open_action = page_change_name_for_test("/OpenAction")
  let type_xyz = page_change_name_for_test("/XYZ")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_change_indexed_blank_for_test(0),
    page_change_indexed_blank_for_test(1),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_open_action,
      PdfArray([
        PdfIndirect(old_numbers[1]),
        PdfNameObject(type_xyz),
        PdfInteger(1),
        PdfInteger(2),
        PdfNull,
      ]),
    ),
  )
  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: @ascii.encode("Second"),
      target: DestXYZ(
        TargetPageObject(old_numbers[1]),
        Some(5.0),
        Some(6.0),
        None,
      ),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let changed = try! bookmarked.change_pages(
    [page_change_indexed_blank_for_test(9)],
    change_references=true,
    changes=[(2, 1)],
    matrices=[(1, @geometry.transform_translate(10.0, 20.0))],
  )
  let new_numbers = try! changed.page_reference_numbers()
  @test.assert_eq(new_numbers.length(), 1)
  @test.assert_eq(try! changed.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: @ascii.encode("Second"),
      target: DestXYZ(
        TargetPageObject(new_numbers[0]),
        Some(5.0),
        Some(6.0),
        None,
      ),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
  match
    changed
    .lookup_object_or_null(changed.root())
    .lookup_immediate(key_open_action) {
    Some(destination) =>
      page_change_assert_indirect_object_for_test(
        changed,
        destination,
        PdfArray([
          PdfIndirect(new_numbers[0]),
          PdfNameObject(type_xyz),
          PdfReal(11.0),
          PdfReal(22.0),
          PdfNull,
        ]),
      )
    _ => fail("expected transformed indirect open action")
  }
}
