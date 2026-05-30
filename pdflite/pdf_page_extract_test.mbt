///|
fn page_extract_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn page_extract_index_mediabox_for_test(index : Int) -> @pdflite.PdfObject {
  PdfArray([
    PdfInteger(index),
    PdfInteger(0),
    PdfInteger(index + 100),
    PdfInteger(200),
  ])
}

///|
fn page_extract_indexed_blank_for_test(index : Int) -> @page.PdfPage {
  {
    ..@page.pdf_page_blank(@geometry.paper_a4),
    mediabox: page_extract_index_mediabox_for_test(index),
  }
}

///|
fn page_extract_annotation_numbers_for_test(
  page_object : @pdflite.PdfObject,
) -> Array[Int] {
  let numbers : Array[Int] = []
  match page_object.lookup_immediate(page_extract_name_for_test("/Annots")) {
    Some(PdfArray(items)) =>
      for item in items {
        match item {
          PdfIndirect(number) => numbers.push(number)
          _ => ()
        }
      }
    _ => ()
  }
  numbers
}

///|
fn page_extract_destination_entries_for_test(
  doc : @pdflite.PdfDocument,
) -> Array[(@pdflite.PdfBytes, @pdflite.PdfObject)] {
  match
    doc.lookup_chain(doc.lookup_object_or_null(doc.root()), [
      page_extract_name_for_test("/Names"),
      page_extract_name_for_test("/Dests"),
    ]) {
    Some(tree) => doc.read_name_tree(tree)
    None => []
  }
}

///|
fn page_extract_catalog_destination_for_test(
  doc : @pdflite.PdfDocument,
  name : String,
) -> @pdflite.PdfObject? {
  match
    doc
    .lookup_object_or_null(doc.root())
    .lookup_immediate(page_extract_name_for_test("/Dests")) {
    Some(PdfDictionary(entries)) =>
      for entry in entries {
        let (key, value) = entry
        if key == page_extract_name_for_test(name) {
          break Some(value)
        }
      } nobreak {
        None
      }
    _ => None
  }
}

///|
test "PdfDocument pdf_of_pages extracts pages in requested order" {
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_extract_indexed_blank_for_test(0),
    page_extract_indexed_blank_for_test(1),
    page_extract_indexed_blank_for_test(2),
  ])
  ignore(try! doc.add_root(page_root, []))
  let extracted = try! doc.pdf_of_pages([3, 1])
  @test.assert_eq(try! extracted.endpage(), 2)
  let pages = try! extracted.pages_of_pagetree()
  @test.assert_eq(pages.length(), 2)
  @test.assert_eq(pages[0].mediabox, page_extract_index_mediabox_for_test(2))
  @test.assert_eq(pages[1].mediabox, page_extract_index_mediabox_for_test(0))
  let reparsed = try! @pdflite.pdf_read_document_from_bytes(
    try! @pdflite.pdf_write_document(extracted),
  )
  let reparsed_pages = try! reparsed.pages_of_pagetree()
  @test.assert_eq(reparsed_pages.length(), 2)
  @test.assert_eq(
    reparsed_pages[0].mediabox,
    page_extract_index_mediabox_for_test(2),
  )
  @test.assert_eq(
    reparsed_pages[1].mediabox,
    page_extract_index_mediabox_for_test(0),
  )
}

///|
test "PdfDocument pdf_of_pages materializes inherited crop boxes" {
  let key_type = page_extract_name_for_test("/Type")
  let key_parent = page_extract_name_for_test("/Parent")
  let key_kids = page_extract_name_for_test("/Kids")
  let key_count = page_extract_name_for_test("/Count")
  let key_mediabox = page_extract_name_for_test("/MediaBox")
  let key_cropbox = page_extract_name_for_test("/CropBox")
  let pages_type = page_extract_name_for_test("/Pages")
  let page_type = page_extract_name_for_test("/Page")
  let inherited_mediabox : @pdflite.PdfObject = PdfArray([
    PdfInteger(0),
    PdfInteger(0),
    PdfInteger(600),
    PdfInteger(800),
  ])
  let inherited_cropbox : @pdflite.PdfObject = PdfArray([
    PdfInteger(20),
    PdfInteger(30),
    PdfInteger(560),
    PdfInteger(760),
  ])
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(pages_type)),
      (key_kids, PdfArray([PdfIndirect(3)])),
      (key_count, PdfInteger(1)),
      (key_mediabox, inherited_mediabox),
      (key_cropbox, inherited_cropbox),
    ]),
  )
  doc.add_object_given_number(
    3,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_type)),
      (key_parent, PdfIndirect(2)),
    ]),
  )
  ignore(try! doc.add_root(2, []))
  @test.assert_eq(
    doc.lookup_object_or_null(3).lookup_immediate(key_cropbox),
    None,
  )
  let extracted = try! doc.pdf_of_pages([1])
  let extracted_page_numbers = try! extracted.page_reference_numbers()
  @test.assert_eq(extracted_page_numbers.length(), 1)
  @test.assert_eq(
    extracted
    .lookup_object_or_null(extracted_page_numbers[0])
    .lookup_immediate(key_cropbox),
    Some(inherited_cropbox),
  )
  @test.assert_eq(
    doc.lookup_object_or_null(3).lookup_immediate(key_cropbox),
    None,
  )
}

///|
test "PdfDocument pdf_of_pages preserves inherited indirect page attributes" {
  let key_type = page_extract_name_for_test("/Type")
  let key_parent = page_extract_name_for_test("/Parent")
  let key_kids = page_extract_name_for_test("/Kids")
  let key_count = page_extract_name_for_test("/Count")
  let key_resources = page_extract_name_for_test("/Resources")
  let key_mediabox = page_extract_name_for_test("/MediaBox")
  let key_rotate = page_extract_name_for_test("/Rotate")
  let key_font = page_extract_name_for_test("/Font")
  let pages_type = page_extract_name_for_test("/Pages")
  let page_type = page_extract_name_for_test("/Page")
  let font_name = page_extract_name_for_test("/F0")
  let resource_object : @pdflite.PdfObject = @pdflite.pdf_dictionary([
    (key_font, PdfDictionary([(font_name, PdfIndirect(10))])),
  ])
  let media_object : @pdflite.PdfObject = PdfArray([
    PdfInteger(0),
    PdfInteger(0),
    PdfInteger(600),
    PdfInteger(800),
  ])
  let font_object : @pdflite.PdfObject = @pdflite.pdf_dictionary([
    (key_type, PdfNameObject(page_extract_name_for_test("/Font"))),
  ])
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(8, resource_object)
  doc.add_object_given_number(9, media_object)
  doc.add_object_given_number(10, font_object)
  doc.add_object_given_number(11, PdfInteger(90))
  doc.add_object_given_number(
    2,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(pages_type)),
      (key_kids, PdfArray([PdfIndirect(3)])),
      (key_count, PdfInteger(1)),
      (key_resources, PdfIndirect(8)),
      (key_mediabox, PdfIndirect(9)),
      (key_rotate, PdfIndirect(11)),
    ]),
  )
  doc.add_object_given_number(
    3,
    @pdflite.pdf_dictionary([
      (key_type, PdfNameObject(page_type)),
      (key_parent, PdfIndirect(2)),
    ]),
  )
  ignore(try! doc.add_root(2, []))
  let extracted = try! doc.pdf_of_pages([1])
  let extracted_page_numbers = try! extracted.page_reference_numbers()
  @test.assert_eq(extracted_page_numbers.length(), 1)
  let extracted_page = extracted.lookup_object_or_null(
    extracted_page_numbers[0],
  )
  @test.assert_eq(
    extracted_page.lookup_immediate(key_resources),
    Some(PdfIndirect(8)),
  )
  @test.assert_eq(
    extracted_page.lookup_immediate(key_mediabox),
    Some(PdfIndirect(9)),
  )
  @test.assert_eq(
    extracted_page.lookup_immediate(key_rotate),
    Some(PdfIndirect(11)),
  )
  @test.assert_eq(extracted.lookup_object_or_null(8), resource_object)
  @test.assert_eq(extracted.lookup_object_or_null(9), media_object)
  @test.assert_eq(extracted.lookup_object_or_null(10), font_object)
  @test.assert_eq(extracted.lookup_object_or_null(11), PdfInteger(90))
}

///|
test "PdfDocument pdf_of_pages repeats selected pages with distinct objects" {
  let key_parent = page_extract_name_for_test("/Parent")
  let key_kids = page_extract_name_for_test("/Kids")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_extract_indexed_blank_for_test(0),
    page_extract_indexed_blank_for_test(1),
  ])
  ignore(try! doc.add_root(page_root, []))
  let extracted = try! doc.pdf_of_pages([1, 1])
  let page_refs = try! extracted.page_reference_numbers()
  @test.assert_eq(page_refs.length(), 2)
  @test.assert_eq(page_refs[0] == page_refs[1], false)
  let pages = try! extracted.pages_of_pagetree()
  @test.assert_eq(pages[0].mediabox, page_extract_index_mediabox_for_test(0))
  @test.assert_eq(pages[1].mediabox, page_extract_index_mediabox_for_test(0))
  guard extracted
    .lookup_object_or_null(page_refs[0])
    .lookup_immediate(key_parent)
    is Some(PdfIndirect(parent_number)) else {
    fail("expected first page parent")
  }
  @test.assert_eq(
    extracted.lookup_object_or_null(page_refs[1]).lookup_immediate(key_parent),
    Some(PdfIndirect(parent_number)),
  )
  @test.assert_eq(
    extracted.lookup_object_or_null(parent_number).lookup_immediate(key_kids),
    Some(PdfArray([PdfIndirect(page_refs[0]), PdfIndirect(page_refs[1])])),
  )
}

///|
test "PdfDocument pdf_of_pages handles page labels" {
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_extract_indexed_blank_for_test(0),
    page_extract_indexed_blank_for_test(1),
    page_extract_indexed_blank_for_test(2),
  ])
  ignore(try! doc.add_root(page_root, []))
  let labelled = try! doc.write_page_labels([
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: Some(@ascii.encode("intro-")),
      start_page: 1,
      start_value: 1,
    },
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: None,
      start_page: 3,
      start_value: 1,
    },
  ])
  let extracted = try! labelled.pdf_of_pages([3, 1])
  @test.assert_eq(try! extracted.read_page_labels(), [])
  let retained = try! labelled.pdf_of_pages([3, 1], retain_numbering=true)
  @test.assert_eq(try! retained.read_page_labels(), [
    {
      label_style: PageLabelDecimalArabic,
      label_prefix: None,
      start_page: 1,
      start_value: 1,
    },
    {
      label_style: PageLabelLowercaseRoman,
      label_prefix: Some(@ascii.encode("intro-")),
      start_page: 2,
      start_value: 1,
    },
  ])
  @test.assert_eq(
    @label.pdf_page_label_text_of_page_number(
      2,
      try! retained.read_page_labels(),
    ),
    Some(@ascii.encode("intro-i")),
  )
}

///|
test "PdfDocument pdf_of_pages filters bookmarks with ancestor context" {
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_extract_indexed_blank_for_test(0),
    page_extract_indexed_blank_for_test(1),
    page_extract_indexed_blank_for_test(2),
  ])
  ignore(try! doc.add_root(page_root, []))
  let page_refs = try! doc.page_reference_numbers()
  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: @ascii.encode("Parent"),
      target: DestFit(TargetPageObject(page_refs[0])),
      is_open: true,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 1,
      text: @ascii.encode("Dropped"),
      target: DestFit(TargetPageObject(page_refs[1])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 1,
      text: @ascii.encode("Kept"),
      target: DestFit(TargetPageObject(page_refs[2])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let extracted = try! bookmarked.pdf_of_pages([3])
  let extracted_page_refs = try! extracted.page_reference_numbers()
  @test.assert_eq(try! extracted.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: @ascii.encode("Parent"),
      target: DestNull,
      is_open: true,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 1,
      text: @ascii.encode("Kept"),
      target: DestFit(TargetPageObject(extracted_page_refs[0])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
test "PdfDocument pdf_of_pages retains bookmarks with named destinations" {
  let key_dests = page_extract_name_for_test("/Dests")
  let key_names = page_extract_name_for_test("/Names")
  let type_fit = page_extract_name_for_test("/Fit")
  let catalog_name = page_extract_name_for_test("/CatalogKeep")
  let string_name = @ascii.encode("string-keep")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_extract_indexed_blank_for_test(0),
    page_extract_indexed_blank_for_test(1),
  ])
  ignore(try! doc.add_root(page_root, []))
  let page_refs = try! doc.page_reference_numbers()
  let kept_dest : @pdflite.PdfObject = PdfArray([
    PdfIndirect(page_refs[1]),
    PdfNameObject(type_fit),
  ])
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_names,
      PdfDictionary([
        (key_dests, doc.build_name_tree([(string_name, kept_dest)])),
      ]),
    ),
  )
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_dests, PdfDictionary([(catalog_name, kept_dest)])),
  )
  let bookmarked = try! doc.add_bookmarks([
    {
      level: 0,
      text: @ascii.encode("String"),
      target: DestString(string_name),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: @ascii.encode("Named"),
      target: DestNamed(catalog_name),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
  let extracted = try! bookmarked.pdf_of_pages([2])
  let extracted_page_refs = try! extracted.page_reference_numbers()
  @test.assert_eq(try! extracted.read_bookmarks(preserve_actions=true), [
    {
      level: 0,
      text: @ascii.encode("String"),
      target: DestString(string_name),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: @ascii.encode("Named"),
      target: DestNamed(catalog_name),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
  @test.assert_eq(try! extracted.read_bookmarks(), [
    {
      level: 0,
      text: @ascii.encode("String"),
      target: DestFit(TargetPageObject(extracted_page_refs[0])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
    {
      level: 0,
      text: @ascii.encode("Named"),
      target: DestFit(TargetPageObject(extracted_page_refs[0])),
      is_open: false,
      colour: @bookmark.pdf_bookmark_black,
      flags: 0,
    },
  ])
}

///|
test "PdfDocument pdf_of_pages can trim structure tree" {
  let key_struct_tree_root = page_extract_name_for_test("/StructTreeRoot")
  let key_k = page_extract_name_for_test("/K")
  let key_pg = page_extract_name_for_test("/Pg")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_extract_indexed_blank_for_test(0),
    page_extract_indexed_blank_for_test(1),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_page_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    30,
    @pdflite.pdf_dictionary([
      (key_k, PdfArray([PdfIndirect(31), PdfIndirect(32)])),
    ]),
  )
  doc.add_object_given_number(
    31,
    @pdflite.pdf_dictionary([
      (key_pg, PdfIndirect(old_page_numbers[0])),
      (key_k, PdfInteger(0)),
    ]),
  )
  doc.add_object_given_number(
    32,
    @pdflite.pdf_dictionary([
      (key_pg, PdfIndirect(old_page_numbers[1])),
      (key_k, PdfInteger(0)),
    ]),
  )
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_struct_tree_root, PdfIndirect(30)),
  )
  let extracted = try! doc.pdf_of_pages([1], process_struct_tree=true)
  let new_page_numbers = try! extracted.page_reference_numbers()
  @test.assert_eq(
    extracted
    .lookup_object_or_null(extracted.root())
    .lookup_immediate(key_struct_tree_root),
    Some(PdfIndirect(30)),
  )
  @test.assert_eq(
    extracted.lookup_object_or_null(30).lookup_immediate(key_k),
    Some(PdfIndirect(31)),
  )
  @test.assert_eq(
    extracted.lookup_object_or_null(31).lookup_immediate(key_pg),
    Some(PdfIndirect(new_page_numbers[0])),
  )
  @test.assert_eq(extracted.lookup_object_or_null(32), PdfNull)
}

///|
test "PdfDocument trim_structure_tree prunes deleted page kids" {
  let key_k = page_extract_name_for_test("/K")
  let key_pg = page_extract_name_for_test("/Pg")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_extract_indexed_blank_for_test(0),
    page_extract_indexed_blank_for_test(1),
  ])
  ignore(try! doc.add_root(page_root, []))
  let page_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    30,
    @pdflite.pdf_dictionary([
      (key_k, PdfArray([PdfIndirect(31), PdfIndirect(32)])),
    ]),
  )
  doc.add_object_given_number(
    31,
    @pdflite.pdf_dictionary([
      (key_pg, PdfIndirect(page_numbers[0])),
      (key_k, PdfInteger(0)),
    ]),
  )
  doc.add_object_given_number(
    32,
    @pdflite.pdf_dictionary([
      (key_pg, PdfIndirect(page_numbers[1])),
      (key_k, PdfInteger(0)),
    ]),
  )
  try! doc.trim_structure_tree([1])
  @test.assert_eq(
    doc.lookup_object_or_null(30).lookup_immediate(key_k),
    Some(PdfIndirect(31)),
  )
  @test.assert_eq(doc.lookup_object_or_null(32), PdfNull)
}

///|
test "PdfDocument pdf_of_pages duplicates reused annotations" {
  let key_annots = page_extract_name_for_test("/Annots")
  let key_subtype = page_extract_name_for_test("/Subtype")
  let key_popup = page_extract_name_for_test("/Popup")
  let key_parent = page_extract_name_for_test("/Parent")
  let doc = @pdflite.pdf_document_empty()
  doc.add_object_given_number(
    10,
    @pdflite.pdf_dictionary([
      (key_subtype, PdfNameObject(page_extract_name_for_test("/Text"))),
      (key_popup, PdfIndirect(11)),
    ]),
  )
  doc.add_object_given_number(
    11,
    @pdflite.pdf_dictionary([
      (key_subtype, PdfNameObject(page_extract_name_for_test("/Popup"))),
      (key_parent, PdfIndirect(10)),
    ]),
  )
  let page = {
    ..page_extract_indexed_blank_for_test(0),
    rest: @pdflite.pdf_dictionary([
      (key_annots, PdfArray([PdfIndirect(10), PdfIndirect(11)])),
    ]),
  }
  let page_root = try! doc.add_pagetree([page, page])
  ignore(try! doc.add_root(page_root, []))
  let extracted = try! doc.pdf_of_pages([1, 2])
  let page_numbers = try! extracted.page_reference_numbers()
  let first_annots = page_extract_annotation_numbers_for_test(
    extracted.lookup_object_or_null(page_numbers[0]),
  )
  let second_annots = page_extract_annotation_numbers_for_test(
    extracted.lookup_object_or_null(page_numbers[1]),
  )
  @test.assert_eq(first_annots.length(), 2)
  @test.assert_eq(second_annots.length(), 2)
  @test.assert_eq(first_annots, [10, 11])
  @test.assert_eq(first_annots[0] == second_annots[0], false)
  @test.assert_eq(first_annots[1] == second_annots[1], false)
  @test.assert_eq(
    extracted
    .lookup_object_or_null(second_annots[0])
    .lookup_immediate(key_popup),
    Some(PdfIndirect(second_annots[1])),
  )
  @test.assert_eq(
    extracted
    .lookup_object_or_null(second_annots[1])
    .lookup_immediate(key_parent),
    Some(PdfIndirect(second_annots[0])),
  )
}

///|
test "PdfDocument pdf_of_pages rewrites and prunes named destinations" {
  let key_names = page_extract_name_for_test("/Names")
  let key_dests = page_extract_name_for_test("/Dests")
  let type_fit = page_extract_name_for_test("/Fit")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_extract_indexed_blank_for_test(0),
    page_extract_indexed_blank_for_test(1),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_page_numbers = try! doc.page_reference_numbers()
  let dest_tree = doc.build_name_tree([
    (
      @ascii.encode("drop"),
      PdfArray([PdfIndirect(old_page_numbers[1]), PdfNameObject(type_fit)]),
    ),
    (
      @ascii.encode("keep"),
      PdfArray([PdfIndirect(old_page_numbers[0]), PdfNameObject(type_fit)]),
    ),
  ])
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_names, PdfDictionary([(key_dests, dest_tree)])),
  )
  let extracted = try! doc.pdf_of_pages([1])
  let new_page_numbers = try! extracted.page_reference_numbers()
  @test.assert_eq(page_extract_destination_entries_for_test(extracted), [
    (
      @ascii.encode("keep"),
      PdfArray([PdfIndirect(new_page_numbers[0]), PdfNameObject(type_fit)]),
    ),
  ])
}

///|
test "PdfDocument pdf_of_pages rewrites and prunes catalog destinations" {
  let key_dests = page_extract_name_for_test("/Dests")
  let type_fit = page_extract_name_for_test("/Fit")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    page_extract_indexed_blank_for_test(0),
    page_extract_indexed_blank_for_test(1),
  ])
  ignore(try! doc.add_root(page_root, []))
  let old_page_numbers = try! doc.page_reference_numbers()
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(
      key_dests,
      PdfDictionary([
        (
          page_extract_name_for_test("/Drop"),
          PdfArray([PdfIndirect(old_page_numbers[1]), PdfNameObject(type_fit)]),
        ),
        (
          page_extract_name_for_test("/Keep"),
          PdfArray([PdfIndirect(old_page_numbers[0]), PdfNameObject(type_fit)]),
        ),
      ]),
    ),
  )
  let extracted = try! doc.pdf_of_pages([1])
  let new_page_numbers = try! extracted.page_reference_numbers()
  @test.assert_eq(
    page_extract_catalog_destination_for_test(extracted, "/Keep"),
    Some(PdfArray([PdfIndirect(new_page_numbers[0]), PdfNameObject(type_fit)])),
  )
  @test.assert_eq(
    page_extract_catalog_destination_for_test(extracted, "/Drop"),
    None,
  )
}

///|
test "PdfDocument pdf_of_pages rejects empty and invalid ranges" {
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([page_extract_indexed_blank_for_test(0)])
  ignore(try! doc.add_root(page_root, []))
  let empty_page_numbers : Array[Int] = []
  let empty_result : Result[@pdflite.PdfDocument, Error] = try? doc.pdf_of_pages(
    empty_page_numbers,
  )
  guard empty_result is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected @pdflite.PdfError::PageTreeExpected for empty range")
  }
  let invalid_result : Result[@pdflite.PdfDocument, Error] = try? doc.pdf_of_pages([
      2,
    ],
  )
  guard invalid_result is Err(@pdflite.PdfError::PageTreeExpected) else {
    fail("expected @pdflite.PdfError::PageTreeExpected for invalid range")
  }
}

///|
test "PdfDocument remove_unreferenced drops detached objects" {
  let key_metadata = page_extract_name_for_test("/Metadata")
  let doc = try! @pdflite.pdf_minimum_valid_pdf()
  let kept = doc.add_object(PdfString(@ascii.encode("kept")))
  let removed = doc.add_object(PdfString(@ascii.encode("removed")))
  doc.add_object_given_number(
    doc.root(),
    try! doc
    .lookup_object_or_null(doc.root())
    .add_dict_entry(key_metadata, PdfIndirect(kept)),
  )
  try! doc.remove_unreferenced()
  @test.assert_eq(
    doc.lookup_object_or_null(kept),
    PdfString(@ascii.encode("kept")),
  )
  @test.assert_eq(doc.lookup_object_or_null(removed), PdfNull)
  @test.assert_eq(try! doc.endpage(), 1)

  let fallback = @pdflite.pdf_document_empty()
  fallback.set_root(1)
  fallback.add_object_given_number(
    1,
    PdfDictionary([
      (
        page_extract_name_for_test("/Type"),
        PdfNameObject(page_extract_name_for_test("/Catalog")),
      ),
      (page_extract_name_for_test("/Pages"), PdfIndirect(2)),
      (key_metadata, PdfIndirect(4)),
    ]),
  )
  fallback.add_object_given_number(
    2,
    PdfDictionary([
      (
        page_extract_name_for_test("/Type"),
        PdfNameObject(page_extract_name_for_test("/Pages")),
      ),
      (page_extract_name_for_test("/Kids"), PdfArray([])),
      (page_extract_name_for_test("/Count"), PdfInteger(0)),
    ]),
  )
  fallback.add_object_given_number(4, PdfString(@ascii.encode("fallback-kept")))
  fallback.add_object_given_number(
    5,
    PdfString(@ascii.encode("fallback-removed")),
  )
  try! fallback.remove_unreferenced()
  @test.assert_eq(
    fallback.lookup_object_or_null(4),
    PdfString(@ascii.encode("fallback-kept")),
  )
  @test.assert_eq(fallback.lookup_object_or_null(5), PdfNull)
}

///|
test "PdfDocument remove_unreferenced uses trailer root as reachability root" {
  let key_root = page_extract_name_for_test("/Root")
  let key_type = page_extract_name_for_test("/Type")
  let key_pages = page_extract_name_for_test("/Pages")
  let key_kids = page_extract_name_for_test("/Kids")
  let key_count = page_extract_name_for_test("/Count")
  let key_parent = page_extract_name_for_test("/Parent")
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(1)
  doc.add_object_given_number(
    1,
    PdfDictionary([
      (key_type, PdfNameObject(page_extract_name_for_test("/Catalog"))),
      (key_pages, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    2,
    PdfDictionary([
      (key_type, PdfNameObject(page_extract_name_for_test("/Pages"))),
      (key_kids, PdfArray([PdfIndirect(3)])),
      (key_count, PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    3,
    PdfDictionary([
      (key_type, PdfNameObject(page_extract_name_for_test("/Page"))),
      (key_parent, PdfIndirect(2)),
    ]),
  )
  doc.add_object_given_number(
    10,
    PdfDictionary([
      (key_type, PdfNameObject(page_extract_name_for_test("/Catalog"))),
      (key_pages, PdfIndirect(20)),
    ]),
  )
  doc.add_object_given_number(
    20,
    PdfDictionary([
      (key_type, PdfNameObject(page_extract_name_for_test("/Pages"))),
      (key_kids, PdfArray([PdfIndirect(21)])),
      (key_count, PdfInteger(1)),
    ]),
  )
  doc.add_object_given_number(
    21,
    PdfDictionary([
      (key_type, PdfNameObject(page_extract_name_for_test("/Page"))),
      (key_parent, PdfIndirect(20)),
    ]),
  )
  doc.set_trailer_dict(PdfDictionary([(key_root, PdfIndirect(10))]))

  try! doc.remove_unreferenced()

  @test.assert_eq(doc.lookup_object_or_null(1), PdfNull)
  @test.assert_eq(doc.lookup_object_or_null(2), PdfNull)
  @test.assert_eq(doc.lookup_object_or_null(3), PdfNull)
  @test.assert_eq(try! doc.page_reference_numbers(), [21])
}

///|
test "PdfDocument remove_unreferenced nullifies deleted page references" {
  let key_open_action = page_extract_name_for_test("/OpenAction")
  let type_fit = page_extract_name_for_test("/Fit")
  let doc = @pdflite.pdf_document_empty()
  let page_root = try! doc.add_pagetree([
    @page.pdf_page_blank(@geometry.paper_a4),
    { ..@page.pdf_page_blank(@geometry.paper_a4), rotate: Rotate90 },
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
  let pages = try! doc.pages_of_pagetree()
  let changed = try! doc.change_pages([pages[0]])
  try! changed.remove_unreferenced()
  @test.assert_eq(try! changed.endpage(), 1)
  @test.assert_eq(changed.lookup_object_or_null(old_numbers[1]), PdfNull)
  @test.assert_eq(
    changed
    .lookup_object_or_null(changed.root())
    .lookup_immediate(key_open_action),
    Some(PdfArray([PdfNull, PdfNameObject(type_fit)])),
  )
}

///|
test "PdfDocument page_reference_numbers reports missing catalog object" {
  let doc = @pdflite.pdf_document_empty()
  doc.set_root(99)
  let result : Result[Array[Int], Error] = try? doc.page_reference_numbers()
  guard result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected @pdflite.PdfError::RootExpected")
  }
}
