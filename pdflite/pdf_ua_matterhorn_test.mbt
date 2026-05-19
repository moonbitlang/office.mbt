///|
fn ua_matterhorn_name_for_test(text : String) -> @pdflite.PdfName {
  @pdflite.pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn ua_matterhorn_failure_for_test(
  name : String,
  section : String,
  error : String,
  extra : Json,
) -> Json {
  Json::object(
    Map::of([
      ("name", Json::string(name)),
      ("section", Json::string(section)),
      ("error", Json::string(error)),
      ("extra", extra),
    ]),
  )
}

///|
fn ua_matterhorn_01_003_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "01-003",
    "UA1:7.1-1",
    "Content marked as Artifact is present inside tagged content.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_01_004_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "01-004",
    "UA1:7.1-1",
    "Tagged content is present inside content marked as Artifact.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_01_005_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "01-005", "UA1:7-1-2", "Content is neither marked as Artifact nor tagged as real content.",
    extra,
  )
}

///|
fn ua_matterhorn_01_007_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "01-007",
    "UA1:7-1-11",
    "Suspects entry has a value of true.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_02_001_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "02-001", "UA1:7.1-3", "One or more non-standard tag’s mapping does not terminate with a standard type.",
    extra,
  )
}

///|
fn ua_matterhorn_02_003_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "02-003",
    "UA1:7.1-3",
    "A circular mapping exists.",
    Json::string("STOP. If rolemap circular, cannot proceed with other checks."),
  )
}

///|
fn ua_matterhorn_02_004_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "02-004", "UA1:7.1-4", "One or more standard types are remapped.", extra,
  )
}

///|
fn ua_matterhorn_06_001_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "06-001",
    "UA1:7.1-8",
    "Document does not contain an XMP metadata stream",
    Json::null(),
  )
}

///|
fn ua_matterhorn_06_002_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "06-002",
    "UA1:5",
    "The XMP metadata stream in the Catalog dictionary does not include the PDF/UA identifier.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_06_003_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "06-003",
    "UA1:7.1-8",
    "XMP metadata stream does not contain dc:title",
    Json::null(),
  )
}

///|
fn ua_matterhorn_07_001_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "07-001",
    "UA1:7.1-9",
    "ViewerPreferences dictionary of the Catalog dictionary does not contain a DisplayDocTitle entry",
    Json::null(),
  )
}

///|
fn ua_matterhorn_07_002_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "07-002",
    "UA1:7.1-9",
    "ViewerPreferences dictionary of the Catalog dictionary contains a DisplayDocTitle entry with a value of false",
    Json::null(),
  )
}

///|
fn ua_matterhorn_20_001_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "20-001",
    "UA1:7.10-1",
    "Name entry is missing or has an empty string as its value in an Optional Content Configuration Dictionary in the Configs entry in the OCProperties entry in the Catalog dictionary.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_20_002_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "20-002", "UA1:7.10-1", "Name entry is missing or has an empty string as its value in an Optional Content Configuration Dictionary that is the value of the D entry in the OCProperties entry in the Catalog dictionary.",
    extra,
  )
}

///|
fn ua_matterhorn_20_003_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "20-003",
    "UA1:7.10-2",
    "An AS entry appears in an Optional Content Configuration Dictionary.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_21_001_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "21-001",
    "UA1:7.11-1",
    "The file specification dictionary for an embedded file does not contain F and UF entries.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_25_001_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "25-001",
    "UA1:7.15-1",
    "File contains the dynamicRender element with value “required”.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_26_002_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "26-002",
    "UA1:7.16-1",
    "The file is encrypted and does contain a P entry but the 10th bit position of the P entry is false.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_28_006_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "28-006",
    "UA1:7.18.2-1",
    "An annotation with subtype undefined in ISO 32000 does not meet 7.18.1.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_28_007_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "28-007",
    "UA1:7.18.2-2",
    "An annotation of subtype TrapNet exists.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_28_008_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "28-008",
    "UA1:7.18.3-1",
    "A page containing an annotation does not contain a Tabs entry",
    Json::null(),
  )
}

///|
fn ua_matterhorn_28_009_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "28-009",
    "UA1:7.18.3-1",
    "A page containing an annotation has a Tabs entry with a value other than S.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_28_010_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "28-010", "UA1:7.18.4-1", "A widget annotation is not nested within a <Form> tag.",
    extra,
  )
}

///|
fn ua_matterhorn_28_011_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "28-011", "UA1:7.18.5-1", "A link annotation is not nested within a <Link> tag.",
    extra,
  )
}

///|
fn ua_matterhorn_28_012_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "28-012",
    "UA1:7.18.5-2",
    "A link annotation does not include an alternate description in its Contents entry.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_28_014_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "28-014",
    "",
    "CT entry is missing from the media clip data dictionary.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_28_015_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "28-015",
    "UA1:7.18.6.2-1",
    "Alt entry is missing from the media clip data dictionary.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_28_017_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "28-017",
    "UA1:7.18.8-1",
    "A PrinterMark annotation is included in the logical structure.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_28_018_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "28-018",
    "UA1:7.18.8-2",
    "The appearance stream of a PrinterMark annotation is not marked as Artifact.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_30_001_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "30-001",
    "UA1:7.2",
    "A reference XObject is present.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_30_002_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "30-002",
    "UA1:7.21.3.1-1",
    "Form XObject contains MCIDs and is referenced more than once.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_31_001_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "31-001",
    "UA1:7.21.3-1",
    "A Type 0 font dictionary with encoding other than Identity-H and Identity-V has values for Registry in both CIDSystemInfo dictionaries that are not identical.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_31_002_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "31-002",
    "UA1:7.21.3.1-1",
    "A Type 0 font dictionary with encoding other than Identity-H and Identity-V has values for Ordering in both CIDSystemInfo dictionaries that are not identical.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_31_003_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "31-003",
    "UA1:7.21.3.1-1",
    "A Type 0 font dictionary with encoding other than Identity-H and Identity-V has a value for Supplement in the CIDSystemInfo dictionary of the CID font that is less than the value for Supplement in the CIDSystemInfo dictionary of the CMap.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_31_004_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "31-004", "UA1:7.21.3.2-1", "A Type 2 CID font contains neither a stream nor the name Identity as the value of the CIDToGIDMap entry.",
    extra,
  )
}

///|
fn ua_matterhorn_31_005_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "31-005",
    "UA1:7.21.3.2-1",
    "A Type 2 CID font does not contain a CIDToGIDMap entry.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_31_006_failure_for_test(name : String) -> Json {
  ua_matterhorn_failure_for_test(
    "31-006",
    "UA1:7.21.3.3-1",
    "A CMap is neither listed as described in ISO 32000- 1:2008, 9.7.5.2, Table 118 nor is it embedded.",
    Json::string(name),
  )
}

///|
fn ua_matterhorn_31_007_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "31-007",
    "UA1:7.21.3.3-1",
    "The WMode entry in a CMap dictionary is not identical to the WMode value in the CMap stream.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_31_008_failure_for_test(name : String) -> Json {
  ua_matterhorn_failure_for_test(
    "31-008",
    "UA1:7.21.3.3-2",
    "A CMap references another CMap which is not listed in ISO 32000-1:2008, 9.7.5.2, Table 118.",
    Json::string(name),
  )
}

///|
fn ua_matterhorn_31_009_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "31-009", "UA1:7.21.4.1-1", "For a font used by text intended to be rendered the font program is not embedded.",
    extra,
  )
}

///|
fn ua_matterhorn_31_017_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "31-017", "UA1:7.21.6-1", "A non-symbolic TrueType font is used for rendering, but none of the cmap entries in the embedded font program is a non-symbolic cmap.",
    extra,
  )
}

///|
fn ua_matterhorn_31_019_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "31-019",
    "UA1:7.21.6-3",
    "The font dictionary for a non-symbolic TrueType font does not contain an Encoding entry.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_31_020_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "31-020",
    "UA1:7.21.6-4",
    "The font dictionary for a non-symbolic TrueType font contains an Encoding dictionary which does not contain a BaseEncoding entry.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_31_021_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "31-021", "UA1:7.21.6-5", "The value for either the Encoding entry or the BaseEncoding entry in the Encoding dictionary in a non-symbolic TrueType font dictionary is neither MacRomanEncoding nor WinAnsiEncoding.",
    extra,
  )
}

///|
fn ua_matterhorn_31_022_failure_for_test(name : String) -> Json {
  ua_matterhorn_failure_for_test(
    "31-022",
    "UA1:7.21.6-6",
    "The Differences array in the Encoding entry in a non-symbolic TrueType font dictionary contains one or more glyph names which are not listed in the Adobe Glyph List.",
    Json::string(name),
  )
}

///|
fn ua_matterhorn_31_023_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "31-023",
    "UA1:7.21.6-7",
    "The Differences array is present in the Encoding entry in a non-symbolic TrueType font dictionary but the embedded font program does not contain a (3,1) Microsoft Unicode cmap.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_31_024_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "31-024",
    "UA1:7.21.6-8",
    "The Encoding entry is present in the font dictionary for a symbolic TrueType font.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_31_025_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "31-025",
    "UA1:7.21.6-9",
    "The embedded font program for a symbolic TrueType font contains no cmap.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_31_026_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "31-026",
    "UA1:7.21.6-10",
    "The embedded font program for a symbolic TrueType font contains more than one cmap, but none of the cmap entries is a (3,0) Microsoft Symbol cmap.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_31_027_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "31-027", "UA1:7.21.7-1", "A font dictionary does not contain the ToUnicode entry and none of the following is true: the font uses MacRomanEncoding, MacExpertEncoding or WinAnsiEncoding; the font is a Type 1 or Type 3 font and the glyph names of the glyphs referenced are all contained in the Adobe Glyph List or the set of named characters in the Symbol font, as defined in ISO 32000-1:2008, Annex D; the font is a Type 0 font, and its descendant CIDFont uses Adobe-GB1, Adobe-CNS1, Adobe-Japan1 or Adobe-Korea1 character collections; the font is a non-symbolic TrueType font.",
    extra,
  )
}

///|
fn ua_matterhorn_31_028_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "31-028",
    "UA1:7.21.7-2",
    "One or more Unicode values specified in the ToUnicode CMap are zero (0).",
    Json::null(),
  )
}

///|
fn ua_matterhorn_31_029_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "31-029",
    "UA1:7.21.7-3",
    "One or more Unicode values specified in the ToUnicode CMap are equal to either U+FEFF or U+FFFE.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_serialized_object_extra_for_test(
  object : @pdflite.PdfObject,
) -> Json {
  Json::string(@ascii.decode_lossy(try! @pdflite.pdf_write_object(object)))
}

///|
fn ua_matterhorn_document_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  resources? : @pdflite.PdfObject = PdfDictionary([]),
  root_extras? : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)] = [],
  rest? : @pdflite.PdfObject = PdfDictionary([]),
) -> @pdflite.PdfDocument {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@pdflite.pdf_page_blank(@pdflite.paper_a4),
    content: [try! @pdflite.pdf_content_stream_of_ops(ops)],
    resources,
    rest,
  }
  let page_root = try! doc.add_pagetree([page])
  ignore(try! doc.add_root(page_root, root_extras))
  doc
}

///|
fn ua_matterhorn_document_with_metadata_for_test(
  metadata : BytesView,
  root_extras? : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)] = [],
) -> @pdflite.PdfDocument {
  let document = ua_matterhorn_document_for_test([], root_extras~)
  try! document.set_metadata_from_bytes(metadata)
}

///|
fn ua_matterhorn_decryption_result_for_test(
  result : @pdflite.PdfDecryptionResult?,
) -> @pdflite.PdfDecryptionResult raise {
  match result {
    Some(value) => value
    None => fail("expected decryption result")
  }
}

///|
fn ua_matterhorn_rolemap_for_test(
  entries : ArrayView[(String, String)],
) -> (@pdflite.PdfName, @pdflite.PdfObject) {
  (
    ua_matterhorn_name_for_test("/StructTreeRoot"),
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/RoleMap"),
        PdfDictionary(
          [
            for entry in entries => {
              (
                ua_matterhorn_name_for_test(entry.0),
                PdfNameObject(ua_matterhorn_name_for_test(entry.1)),
              )
            }
          ],
        ),
      ),
    ]),
  )
}

///|
fn ua_matterhorn_ocproperties_for_test(
  entries : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
) -> (@pdflite.PdfName, @pdflite.PdfObject) {
  (
    ua_matterhorn_name_for_test("/OCProperties"),
    PdfDictionary([ for entry in entries => entry ]),
  )
}

///|
fn ua_matterhorn_display_doc_title_for_test(
  value : Bool,
) -> (@pdflite.PdfName, @pdflite.PdfObject) {
  (
    ua_matterhorn_name_for_test("/ViewerPreferences"),
    PdfDictionary([
      (ua_matterhorn_name_for_test("/DisplayDocTitle"), PdfBoolean(value)),
    ]),
  )
}

///|
fn ua_matterhorn_file_spec_for_test(
  f : String?,
  uf : String?,
) -> @pdflite.PdfObject {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      ua_matterhorn_name_for_test("/Type"),
      PdfNameObject(ua_matterhorn_name_for_test("/Filespec")),
    ),
  ]
  match f {
    Some(value) =>
      entries.push(
        (ua_matterhorn_name_for_test("/F"), PdfString(@ascii.encode(value))),
      )
    None => ()
  }
  match uf {
    Some(value) =>
      entries.push(
        (ua_matterhorn_name_for_test("/UF"), PdfString(@ascii.encode(value))),
      )
    None => ()
  }
  PdfDictionary(entries)
}

///|
fn ua_matterhorn_embedded_files_root_for_test(
  file_spec : @pdflite.PdfObject,
) -> Array[(@pdflite.PdfName, @pdflite.PdfObject)] {
  [
    (
      ua_matterhorn_name_for_test("/Names"),
      PdfDictionary([
        (
          ua_matterhorn_name_for_test("/EmbeddedFiles"),
          PdfDictionary([
            (
              ua_matterhorn_name_for_test("/Names"),
              PdfArray([PdfString(@ascii.encode("attachment.bin")), file_spec]),
            ),
          ]),
        ),
      ]),
    ),
  ]
}

///|
fn ua_matterhorn_file_attachment_annotation_for_test(
  file_spec : @pdflite.PdfObject?,
) -> @pdflite.PdfObject {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      ua_matterhorn_name_for_test("/Subtype"),
      PdfNameObject(ua_matterhorn_name_for_test("/FileAttachment")),
    ),
  ]
  match file_spec {
    Some(value) => entries.push((ua_matterhorn_name_for_test("/FS"), value))
    None => ()
  }
  PdfDictionary(entries)
}

///|
fn ua_matterhorn_annotation_for_test(
  subtype : String,
  extras? : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)] = [],
) -> @pdflite.PdfObject {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      ua_matterhorn_name_for_test("/Subtype"),
      PdfNameObject(ua_matterhorn_name_for_test(subtype)),
    ),
    (
      ua_matterhorn_name_for_test("/Rect"),
      PdfArray([PdfInteger(0), PdfInteger(0), PdfInteger(1), PdfInteger(1)]),
    ),
  ]
  for extra in extras {
    entries.push(extra)
  }
  PdfDictionary(entries)
}

///|
fn ua_matterhorn_structure_element_for_test(
  kind : String,
) -> @pdflite.PdfObject {
  PdfDictionary([
    (
      ua_matterhorn_name_for_test("/S"),
      PdfNameObject(ua_matterhorn_name_for_test(kind)),
    ),
  ])
}

///|
fn ua_matterhorn_struct_parent_tree_root_for_test(
  entries : ArrayView[(Int, @pdflite.PdfObject)],
) -> Array[(@pdflite.PdfName, @pdflite.PdfObject)] {
  let tree_doc = @pdflite.pdf_document_empty()
  [
    (
      ua_matterhorn_name_for_test("/StructTreeRoot"),
      PdfDictionary([
        (
          ua_matterhorn_name_for_test("/ParentTree"),
          tree_doc.build_number_tree(entries),
        ),
      ]),
    ),
  ]
}

///|
fn ua_matterhorn_page_rest_with_annots_for_test(
  annotations : ArrayView[@pdflite.PdfObject],
  tabs? : @pdflite.PdfObject? = None,
) -> @pdflite.PdfObject {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      ua_matterhorn_name_for_test("/Annots"),
      PdfArray([ for annotation in annotations => annotation ]),
    ),
  ]
  match tabs {
    Some(value) => entries.push((ua_matterhorn_name_for_test("/Tabs"), value))
    None => ()
  }
  PdfDictionary(entries)
}

///|
fn ua_matterhorn_xfa_config_stream_for_test(
  data : BytesView,
) -> @pdflite.PdfObject {
  @pdflite.pdf_stream(PdfDictionary([]), StreamGot(data.to_owned()))
}

///|
fn ua_matterhorn_xfa_root_for_test(
  xfa : @pdflite.PdfObject,
) -> Array[(@pdflite.PdfName, @pdflite.PdfObject)] {
  [
    (
      ua_matterhorn_name_for_test("/AcroForm"),
      PdfDictionary([(ua_matterhorn_name_for_test("/XFA"), xfa)]),
    ),
  ]
}

///|
fn ua_matterhorn_xfa_config_root_for_test(
  config : @pdflite.PdfObject,
) -> Array[(@pdflite.PdfName, @pdflite.PdfObject)] {
  ua_matterhorn_xfa_root_for_test(
    PdfArray([PdfString(@ascii.encode("config")), config]),
  )
}

///|
fn ua_matterhorn_form_stream_for_test(
  ops : ArrayView[@pdflite.PdfContentOp],
  resources? : @pdflite.PdfObject = PdfDictionary([]),
) -> @pdflite.PdfObject {
  let stream = try! @pdflite.pdf_content_stream_of_ops(ops)
  try! (try! stream.add_dict_entry(
    ua_matterhorn_name_for_test("/Subtype"),
    PdfNameObject(ua_matterhorn_name_for_test("/Form")),
  )).add_dict_entry(ua_matterhorn_name_for_test("/Resources"), resources)
}

///|
fn ua_matterhorn_xobject_resources_for_test(
  entries : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
) -> @pdflite.PdfObject {
  PdfDictionary([
    (
      ua_matterhorn_name_for_test("/XObject"),
      PdfDictionary([ for entry in entries => entry ]),
    ),
  ])
}

///|
fn ua_matterhorn_font_resources_for_test(
  entries : ArrayView[(String, @pdflite.PdfObject)],
) -> @pdflite.PdfObject {
  PdfDictionary([
    (
      ua_matterhorn_name_for_test("/Font"),
      PdfDictionary(
        [
          for entry in entries => {
            (ua_matterhorn_name_for_test(entry.0), entry.1)
          }
        ],
      ),
    ),
  ])
}

///|
fn ua_matterhorn_cid_system_info_for_test(
  registry : String,
  ordering : String,
) -> @pdflite.PdfObject {
  PdfDictionary([
    (
      ua_matterhorn_name_for_test("/Registry"),
      PdfString(@ascii.encode(registry)),
    ),
    (
      ua_matterhorn_name_for_test("/Ordering"),
      PdfString(@ascii.encode(ordering)),
    ),
    (ua_matterhorn_name_for_test("/Supplement"), PdfInteger(0)),
  ])
}

///|
fn ua_matterhorn_cmap_for_test(
  registry : String,
  ordering : String,
) -> @pdflite.PdfObject {
  PdfDictionary([
    (
      ua_matterhorn_name_for_test("/CIDSystemInfo"),
      ua_matterhorn_cid_system_info_for_test(registry, ordering),
    ),
  ])
}

///|
fn ua_matterhorn_cmap_stream_for_test(
  dictionary_wmode : Int?,
  stream_wmode : Int?,
) -> @pdflite.PdfObject {
  let dictionary_entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = []
  match dictionary_wmode {
    Some(wmode) =>
      dictionary_entries.push(
        (ua_matterhorn_name_for_test("/WMode"), PdfInteger(wmode)),
      )
    None => ()
  }
  let stream_text = match stream_wmode {
    Some(wmode) => "/WMode " + wmode.to_string() + " def\n"
    None => ""
  }
  @pdflite.pdf_stream(
    PdfDictionary(dictionary_entries),
    StreamGot(@ascii.encode(stream_text)),
  )
}

///|
fn ua_matterhorn_cid_font_for_test(
  registry : String,
  ordering : String,
) -> @pdflite.PdfObject {
  PdfDictionary([
    (
      ua_matterhorn_name_for_test("/Subtype"),
      PdfNameObject(ua_matterhorn_name_for_test("/CIDFontType2")),
    ),
    (
      ua_matterhorn_name_for_test("/CIDSystemInfo"),
      ua_matterhorn_cid_system_info_for_test(registry, ordering),
    ),
  ])
}

///|
fn ua_matterhorn_cid_font_type2_for_test(
  cid_to_gid_map : @pdflite.PdfObject?,
) -> @pdflite.PdfObject {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      ua_matterhorn_name_for_test("/Subtype"),
      PdfNameObject(ua_matterhorn_name_for_test("/CIDFontType2")),
    ),
  ]
  match cid_to_gid_map {
    Some(map) =>
      entries.push((ua_matterhorn_name_for_test("/CIDToGIDMap"), map))
    None => ()
  }
  PdfDictionary(entries)
}

///|
fn ua_matterhorn_font_for_test(
  subtype : String,
  basefont : String,
  encoding : String?,
  descriptor : @pdflite.PdfObject?,
  extras? : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)] = [],
) -> @pdflite.PdfObject {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      ua_matterhorn_name_for_test("/Type"),
      PdfNameObject(ua_matterhorn_name_for_test("/Font")),
    ),
    (
      ua_matterhorn_name_for_test("/Subtype"),
      PdfNameObject(ua_matterhorn_name_for_test(subtype)),
    ),
    (
      ua_matterhorn_name_for_test("/BaseFont"),
      PdfNameObject(ua_matterhorn_name_for_test(basefont)),
    ),
  ]
  match encoding {
    Some(value) =>
      entries.push(
        (
          ua_matterhorn_name_for_test("/Encoding"),
          PdfNameObject(ua_matterhorn_name_for_test(value)),
        ),
      )
    None => ()
  }
  match descriptor {
    Some(value) =>
      entries.push((ua_matterhorn_name_for_test("/FontDescriptor"), value))
    None => ()
  }
  for extra in extras {
    entries.push(extra)
  }
  PdfDictionary(entries)
}

///|
fn ua_matterhorn_type0_font_for_test(
  encoding : @pdflite.PdfObject,
  descendant_number : Int,
) -> @pdflite.PdfObject {
  PdfDictionary([
    (
      ua_matterhorn_name_for_test("/Subtype"),
      PdfNameObject(ua_matterhorn_name_for_test("/Type0")),
    ),
    (ua_matterhorn_name_for_test("/Encoding"), encoding),
    (
      ua_matterhorn_name_for_test("/DescendantFonts"),
      PdfArray([PdfIndirect(descendant_number)]),
    ),
  ])
}

///|
fn ua_matterhorn_font_descriptor_for_test(flags : Int?) -> @pdflite.PdfObject {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = []
  match flags {
    Some(value) =>
      entries.push((ua_matterhorn_name_for_test("/Flags"), PdfInteger(value)))
    None => ()
  }
  PdfDictionary(entries)
}

///|
fn ua_matterhorn_font_descriptor_with_file_for_test(
  flags : Int?,
  fontfile : @pdflite.PdfBytes,
) -> @pdflite.PdfObject {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      ua_matterhorn_name_for_test("/FontFile2"),
      @pdflite.pdf_stream(PdfDictionary([]), StreamGot(fontfile)),
    ),
  ]
  match flags {
    Some(value) =>
      entries.push((ua_matterhorn_name_for_test("/Flags"), PdfInteger(value)))
    None => ()
  }
  PdfDictionary(entries)
}

///|
fn ua_matterhorn_truetype_font_for_test(
  flags : Int?,
  encoding : @pdflite.PdfObject?,
) -> @pdflite.PdfObject {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      ua_matterhorn_name_for_test("/Subtype"),
      PdfNameObject(ua_matterhorn_name_for_test("/TrueType")),
    ),
    (
      ua_matterhorn_name_for_test("/FontDescriptor"),
      ua_matterhorn_font_descriptor_for_test(flags),
    ),
  ]
  match encoding {
    Some(value) =>
      entries.push((ua_matterhorn_name_for_test("/Encoding"), value))
    None => ()
  }
  PdfDictionary(entries)
}

///|
fn ua_matterhorn_truetype_font_with_file_for_test(
  flags : Int?,
  encoding : @pdflite.PdfObject?,
  fontfile : @pdflite.PdfBytes,
) -> @pdflite.PdfObject {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      ua_matterhorn_name_for_test("/Subtype"),
      PdfNameObject(ua_matterhorn_name_for_test("/TrueType")),
    ),
    (
      ua_matterhorn_name_for_test("/FontDescriptor"),
      ua_matterhorn_font_descriptor_with_file_for_test(flags, fontfile),
    ),
  ]
  match encoding {
    Some(value) =>
      entries.push((ua_matterhorn_name_for_test("/Encoding"), value))
    None => ()
  }
  PdfDictionary(entries)
}

///|
fn ua_matterhorn_encoding_dictionary_for_test(
  entries : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
) -> @pdflite.PdfObject {
  PdfDictionary([ for entry in entries => entry ])
}

///|
fn ua_matterhorn_push_u16_for_test(output : Array[Byte], value : Int) -> Unit {
  output.push((value / 256).to_byte())
  output.push((value % 256).to_byte())
}

///|
fn ua_matterhorn_push_u32_for_test(output : Array[Byte], value : Int) -> Unit {
  output.push((value / 16777216).to_byte())
  output.push((value / 65536 % 256).to_byte())
  output.push((value / 256 % 256).to_byte())
  output.push((value % 256).to_byte())
}

///|
fn ua_matterhorn_truetype_cmap_font_for_test(
  records : ArrayView[(Int, Int)],
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  ua_matterhorn_push_u32_for_test(output, 0x00010000)
  ua_matterhorn_push_u16_for_test(output, 1)
  ua_matterhorn_push_u16_for_test(output, 0)
  ua_matterhorn_push_u16_for_test(output, 0)
  ua_matterhorn_push_u16_for_test(output, 0)
  output.append([0x63, 0x6D, 0x61, 0x70])
  ua_matterhorn_push_u32_for_test(output, 0)
  ua_matterhorn_push_u32_for_test(output, 28)
  ua_matterhorn_push_u32_for_test(output, 4 + records.length() * 8)
  ua_matterhorn_push_u16_for_test(output, 0)
  ua_matterhorn_push_u16_for_test(output, records.length())
  for record in records {
    ua_matterhorn_push_u16_for_test(output, record.0)
    ua_matterhorn_push_u16_for_test(output, record.1)
    ua_matterhorn_push_u32_for_test(output, 12)
  }
  Bytes::from_array(output)
}

///|
fn ua_matterhorn_tounicode_stream_for_test(hex : String) -> @pdflite.PdfObject {
  let cmap = "1 beginbfchar\n<41><" + hex + ">\nendbfchar\n"
  @pdflite.pdf_stream(PdfDictionary([]), StreamGot(@ascii.encode(cmap)))
}

///|
fn ua_matterhorn_font_with_tounicode_for_test(
  tounicode : @pdflite.PdfObject,
) -> @pdflite.PdfObject {
  PdfDictionary([(ua_matterhorn_name_for_test("/ToUnicode"), tounicode)])
}

///|
fn ua_matterhorn_printer_mark_for_test(
  normal_appearance : @pdflite.PdfObject,
) -> @pdflite.PdfObject {
  PdfDictionary([
    (
      ua_matterhorn_name_for_test("/Subtype"),
      PdfNameObject(ua_matterhorn_name_for_test("/PrinterMark")),
    ),
    (
      ua_matterhorn_name_for_test("/AP"),
      PdfDictionary([(ua_matterhorn_name_for_test("/N"), normal_appearance)]),
    ),
  ])
}

///|
test "PdfDocument test_matterhorn_json detects content artifact nesting" {
  let span = ua_matterhorn_name_for_test("/Span")
  let artifact = ua_matterhorn_name_for_test("/Artifact")
  let document = ua_matterhorn_document_for_test([
    Op_BDC(span, PdfDictionary([])),
    Op_BMC(artifact),
    Op_EMC,
    Op_EMC,
  ])
  @test.assert_eq(
    try! document.test_matterhorn_json("01-003"),
    Json::array([ua_matterhorn_01_003_failure_for_test()]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_ua_test_matterhorn_json(document, "01-004"),
    Json::array([ua_matterhorn_01_004_failure_for_test()]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json(""),
    Json::array([
      ua_matterhorn_01_003_failure_for_test(),
      ua_matterhorn_01_004_failure_for_test(),
      ua_matterhorn_06_001_failure_for_test(),
      ua_matterhorn_07_001_failure_for_test(),
    ]),
  )
}

///|
test "PdfDocument test_matterhorn_json scans Form XObject content markers" {
  let span = ua_matterhorn_name_for_test("/Span")
  let artifact = ua_matterhorn_name_for_test("/Artifact")
  let document = ua_matterhorn_document_for_test([])
  document.add_object_given_number(
    20,
    ua_matterhorn_form_stream_for_test([
      Op_BDC(span, PdfDictionary([])),
      Op_BMC(artifact),
      Op_EMC,
      Op_EMC,
    ]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("01-003"),
    Json::array([ua_matterhorn_01_003_failure_for_test()]),
  )
  @test.assert_eq(try! document.test_matterhorn_json("01-005"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects unmarked real content" {
  let span = ua_matterhorn_name_for_test("/Span")
  let mcid = ua_matterhorn_name_for_test("/MCID")
  let unmarked = ua_matterhorn_document_for_test([Op_Tj(b"A")])
  @test.assert_eq(
    try! unmarked.test_matterhorn_json("01-005"),
    Json::array([ua_matterhorn_01_005_failure_for_test(Json::null())]),
  )

  let tagged = ua_matterhorn_document_for_test([
    Op_BDC(span, PdfDictionary([(mcid, PdfInteger(0))])),
    Op_Tj(b"A"),
    Op_EMC,
  ])
  @test.assert_eq(try! tagged.test_matterhorn_json("01-005"), Json::array([]))

  let clipping_only = ua_matterhorn_document_for_test([
    Op_m(0.0, 0.0),
    Op_l(1.0, 1.0),
    Op_W,
  ])
  @test.assert_eq(
    try! clipping_only.test_matterhorn_json("01-005"),
    Json::array([]),
  )

  let malformed = ua_matterhorn_document_for_test([Op_EMC])
  @test.assert_eq(
    try! malformed.test_matterhorn_json("01-005"),
    Json::array([
      ua_matterhorn_01_005_failure_for_test(Json::string("empty stack")),
    ]),
  )
}

///|
test "PdfDocument test_matterhorn_json detects MarkInfo suspects" {
  let document = ua_matterhorn_document_for_test([], root_extras=[
    (
      ua_matterhorn_name_for_test("/MarkInfo"),
      PdfDictionary([
        (ua_matterhorn_name_for_test("/Suspects"), PdfBoolean(true)),
      ]),
    ),
  ])
  @test.assert_eq(
    try! document.test_matterhorn_json("01-007"),
    Json::array([ua_matterhorn_01_007_failure_for_test()]),
  )
  @test.assert_eq(
    try! @pdflite.pdf_ua_test_matterhorn_print(document, "01-007"),
    @utf8.encode("01-007 UA1:7-1-11 Suspects entry has a value of true. \n"),
  )
}

///|
test "PdfDocument test_matterhorn_json rejects unsupported individual checks" {
  let document = ua_matterhorn_document_for_test([])
  let result : Result[Json, Error] = try? document.test_matterhorn_json(
    "09-004",
  )
  guard result is Err(@pdflite.PdfError::SoftError(_)) else {
    fail("expected unsupported Matterhorn test to raise SoftError")
  }
}

///|
test "PdfDocument test_matterhorn_json detects role map target chains" {
  let bad = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_rolemap_for_test([("/Custom", "/StillCustom")]),
  ])
  @test.assert_eq(
    try! bad.test_matterhorn_json("02-001"),
    Json::array([ua_matterhorn_02_001_failure_for_test(Json::string("/Custom"))]),
  )
  @test.assert_eq(
    try! bad.test_matterhorn_text("02-001"),
    @utf8.encode(
      "02-001 UA1:7.1-3 One or more non-standard tag’s mapping does not terminate with a standard type. (\"/Custom\")\n",
    ),
  )
  @test.assert_eq(try! bad.test_matterhorn_json("02-003"), Json::array([]))
  @test.assert_eq(try! bad.test_matterhorn_json("02-004"), Json::array([]))

  let good = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_rolemap_for_test([
      ("/Custom", "/Intermediate"),
      ("/Intermediate", "/P"),
    ]),
  ])
  @test.assert_eq(try! good.test_matterhorn_json("02-001"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json prechecks circular role maps" {
  let document = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_rolemap_for_test([
      ("/Custom", "/Other"),
      ("/Other", "/Custom"),
    ]),
  ])
  @test.assert_eq(
    try! document.test_matterhorn_json("02-003"),
    Json::array([ua_matterhorn_02_003_failure_for_test()]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("02-001"),
    Json::array([ua_matterhorn_02_003_failure_for_test()]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("06-001"),
    Json::array([ua_matterhorn_02_003_failure_for_test()]),
  )
}

///|
test "PdfDocument test_matterhorn_json detects standard type remapping" {
  let document = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_rolemap_for_test([("/P", "/Span")]),
  ])
  @test.assert_eq(try! document.test_matterhorn_json("02-001"), Json::array([]))
  @test.assert_eq(
    try! document.test_matterhorn_json("02-004"),
    Json::array([ua_matterhorn_02_004_failure_for_test(Json::string("/P"))]),
  )
}

///|
test "PdfDocument test_matterhorn_json detects missing metadata and viewer preferences" {
  let document = ua_matterhorn_document_for_test([])
  @test.assert_eq(
    try! document.test_matterhorn_json("06-001"),
    Json::array([ua_matterhorn_06_001_failure_for_test()]),
  )
  @test.assert_eq(try! document.test_matterhorn_json("06-002"), Json::array([]))
  @test.assert_eq(try! document.test_matterhorn_json("06-003"), Json::array([]))
  @test.assert_eq(
    try! document.test_matterhorn_json("07-001"),
    Json::array([ua_matterhorn_07_001_failure_for_test()]),
  )
}

///|
test "PdfDocument test_matterhorn_json detects missing XMP fields" {
  let metadata =
    #|<x:xmpmeta xmlns:x="adobe:ns:meta/"
    #| xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    #| <rdf:RDF><rdf:Description/></rdf:RDF>
    #|</x:xmpmeta>
  let document = ua_matterhorn_document_with_metadata_for_test(
    @ascii.encode(metadata),
    root_extras=[ua_matterhorn_display_doc_title_for_test(true)],
  )
  @test.assert_eq(try! document.test_matterhorn_json("06-001"), Json::array([]))
  @test.assert_eq(
    try! document.test_matterhorn_json("06-002"),
    Json::array([ua_matterhorn_06_002_failure_for_test()]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("06-003"),
    Json::array([ua_matterhorn_06_003_failure_for_test()]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json(""),
    Json::array([
      ua_matterhorn_06_002_failure_for_test(),
      ua_matterhorn_06_003_failure_for_test(),
    ]),
  )
}

///|
test "PdfDocument test_matterhorn_json accepts PDF/UA metadata" {
  let document = try! @pdflite.pdf_ua_create_pdfua1(
    "Accessible Title", @pdflite.paper_a4, 1,
  )
  @test.assert_eq(try! document.test_matterhorn_json("06-001"), Json::array([]))
  @test.assert_eq(try! document.test_matterhorn_json("06-002"), Json::array([]))
  @test.assert_eq(try! document.test_matterhorn_json("06-003"), Json::array([]))
  @test.assert_eq(try! document.test_matterhorn_json("07-001"), Json::array([]))
  @test.assert_eq(try! document.test_matterhorn_json("07-002"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects false DisplayDocTitle" {
  let document = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_display_doc_title_for_test(false),
  ])
  @test.assert_eq(try! document.test_matterhorn_json("07-001"), Json::array([]))
  @test.assert_eq(
    try! document.test_matterhorn_json("07-002"),
    Json::array([ua_matterhorn_07_002_failure_for_test()]),
  )
}

///|
test "PdfDocument test_matterhorn_json detects optional content config names" {
  let key_configs = ua_matterhorn_name_for_test("/Configs")
  let key_name = ua_matterhorn_name_for_test("/Name")
  let missing_name = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (key_configs, PdfArray([PdfDictionary([])])),
    ]),
  ])
  @test.assert_eq(
    try! missing_name.test_matterhorn_json("20-001"),
    Json::array([ua_matterhorn_20_001_failure_for_test()]),
  )

  let empty_name = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (
        key_configs,
        PdfArray([
          PdfDictionary([
            (key_name, PdfNameObject(ua_matterhorn_name_for_test(""))),
          ]),
        ]),
      ),
    ]),
  ])
  @test.assert_eq(
    try! empty_name.test_matterhorn_json("20-001"),
    Json::array([ua_matterhorn_20_001_failure_for_test()]),
  )

  let valid = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (
        key_configs,
        PdfArray([
          PdfDictionary([
            (key_name, PdfNameObject(ua_matterhorn_name_for_test("/Layer"))),
          ]),
        ]),
      ),
    ]),
  ])
  @test.assert_eq(try! valid.test_matterhorn_json("20-001"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects default optional content names" {
  let key_d = ua_matterhorn_name_for_test("/D")
  let key_name = ua_matterhorn_name_for_test("/Name")
  let missing_name = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([(key_d, PdfDictionary([]))]),
  ])
  @test.assert_eq(
    try! missing_name.test_matterhorn_json("20-002"),
    Json::array([
      ua_matterhorn_20_002_failure_for_test(Json::string("not present")),
    ]),
  )

  let empty_name = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (key_d, PdfDictionary([(key_name, PdfString(@ascii.encode("")))])),
    ]),
  ])
  @test.assert_eq(
    try! empty_name.test_matterhorn_json("20-002"),
    Json::array([
      ua_matterhorn_20_002_failure_for_test(Json::string("empty string")),
    ]),
  )

  let valid = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (key_d, PdfDictionary([(key_name, PdfString(@ascii.encode("Default")))])),
    ]),
  ])
  @test.assert_eq(try! valid.test_matterhorn_json("20-002"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects optional content AS entries" {
  let key_as = ua_matterhorn_name_for_test("/AS")
  let key_configs = ua_matterhorn_name_for_test("/Configs")
  let key_d = ua_matterhorn_name_for_test("/D")
  let default_as = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (key_d, PdfDictionary([(key_as, PdfArray([]))])),
    ]),
  ])
  @test.assert_eq(
    try! default_as.test_matterhorn_json("20-003"),
    Json::array([ua_matterhorn_20_003_failure_for_test()]),
  )

  let config_as = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (key_configs, PdfArray([PdfDictionary([(key_as, PdfArray([]))])])),
    ]),
  ])
  @test.assert_eq(
    try! config_as.test_matterhorn_json("20-003"),
    Json::array([ua_matterhorn_20_003_failure_for_test()]),
  )

  let valid = ua_matterhorn_document_for_test([], root_extras=[
    ua_matterhorn_ocproperties_for_test([
      (key_d, PdfDictionary([])),
      (key_configs, PdfArray([PdfDictionary([])])),
    ]),
  ])
  @test.assert_eq(try! valid.test_matterhorn_json("20-003"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json checks embedded file specs" {
  let missing_uf = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_embedded_files_root_for_test(
      ua_matterhorn_file_spec_for_test(Some("attachment.bin"), None),
    ),
  )
  @test.assert_eq(
    try! missing_uf.test_matterhorn_json("21-001"),
    Json::array([ua_matterhorn_21_001_failure_for_test()]),
  )

  let valid_named = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_embedded_files_root_for_test(
      ua_matterhorn_file_spec_for_test(
        Some("attachment.bin"),
        Some("attachment.bin"),
      ),
    ),
  )
  @test.assert_eq(
    try! valid_named.test_matterhorn_json("21-001"),
    Json::array([]),
  )

  let missing_annotation_uf = ua_matterhorn_document_for_test(
    [],
    rest=PdfDictionary([
      (
        ua_matterhorn_name_for_test("/Annots"),
        PdfArray([
          ua_matterhorn_file_attachment_annotation_for_test(
            Some(ua_matterhorn_file_spec_for_test(Some("page.bin"), None)),
          ),
        ]),
      ),
    ]),
  )
  @test.assert_eq(
    try! missing_annotation_uf.test_matterhorn_json("21-001"),
    Json::array([ua_matterhorn_21_001_failure_for_test()]),
  )

  let no_fs_annotation = ua_matterhorn_document_for_test(
    [],
    rest=PdfDictionary([
      (
        ua_matterhorn_name_for_test("/Annots"),
        PdfArray([ua_matterhorn_file_attachment_annotation_for_test(None)]),
      ),
    ]),
  )
  @test.assert_eq(
    try! no_fs_annotation.test_matterhorn_json("21-001"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json detects required XFA dynamicRender" {
  let required = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_xfa_config_root_for_test(
      ua_matterhorn_xfa_config_stream_for_test(
        b"<template><dynamicRender>required</dynamicRender></template>",
      ),
    ),
  )
  @test.assert_eq(
    try! required.test_matterhorn_json("25-001"),
    Json::array([ua_matterhorn_25_001_failure_for_test()]),
  )

  let prefixed = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_xfa_config_root_for_test(
      ua_matterhorn_xfa_config_stream_for_test(
        b"<template><xfa:dynamicRender>required</xfa:dynamicRender></template>",
      ),
    ),
  )
  @test.assert_eq(
    try! prefixed.test_matterhorn_json("25-001"),
    Json::array([ua_matterhorn_25_001_failure_for_test()]),
  )

  let optional = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_xfa_config_root_for_test(
      ua_matterhorn_xfa_config_stream_for_test(
        b"<template><dynamicRender>optional</dynamicRender></template>",
      ),
    ),
  )
  @test.assert_eq(try! optional.test_matterhorn_json("25-001"), Json::array([]))

  let spaced = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_xfa_config_root_for_test(
      ua_matterhorn_xfa_config_stream_for_test(
        b"<template><dynamicRender> required </dynamicRender></template>",
      ),
    ),
  )
  @test.assert_eq(try! spaced.test_matterhorn_json("25-001"), Json::array([]))

  let duplicate_config = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_xfa_root_for_test(
      PdfArray([
        PdfString(@ascii.encode("config")),
        ua_matterhorn_xfa_config_stream_for_test(
          b"<dynamicRender>required</dynamicRender>",
        ),
        PdfString(@ascii.encode("config")),
        ua_matterhorn_xfa_config_stream_for_test(
          b"<dynamicRender>required</dynamicRender>",
        ),
      ]),
    ),
  )
  @test.assert_eq(
    try! duplicate_config.test_matterhorn_json("25-001"),
    Json::array([]),
  )

  let non_array_xfa = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_xfa_root_for_test(
      ua_matterhorn_xfa_config_stream_for_test(
        b"<dynamicRender>required</dynamicRender>",
      ),
    ),
  )
  @test.assert_eq(
    try! non_array_xfa.test_matterhorn_json("25-001"),
    Json::array([]),
  )

  let non_stream_config = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_xfa_config_root_for_test(
      PdfString(@ascii.encode("required")),
    ),
  )
  @test.assert_eq(
    try! non_stream_config.test_matterhorn_json("25-001"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks encryption permissions" {
  let plain = ua_matterhorn_document_for_test([])
  @test.assert_eq(try! plain.test_matterhorn_json("26-001"), Json::array([]))
  @test.assert_eq(try! plain.test_matterhorn_json("26-002"), Json::array([]))

  let no_extract_encrypted = try! ua_matterhorn_document_for_test([]).encrypt_40bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoExtract],
    file_id=@ascii.encode("ua-no-extract"),
  )
  let no_extract = ua_matterhorn_decryption_result_for_test(
      try! no_extract_encrypted.decrypt_with_user_password(
        @ascii.encode("user"),
      ),
    ).document
  @test.assert_eq(
    try! no_extract.test_matterhorn_json("26-001"),
    Json::array([]),
  )
  @test.assert_eq(
    try! no_extract.test_matterhorn_json("26-002"),
    Json::array([ua_matterhorn_26_002_failure_for_test()]),
  )

  let print_denied_encrypted = try! ua_matterhorn_document_for_test([]).encrypt_40bit(
    @ascii.encode("user"),
    @ascii.encode("owner"),
    [PdfNoPrint],
    file_id=@ascii.encode("ua-print-denied"),
  )
  let print_denied = ua_matterhorn_decryption_result_for_test(
      try! print_denied_encrypted.decrypt_with_user_password(
        @ascii.encode("user"),
      ),
    ).document
  @test.assert_eq(
    try! print_denied.test_matterhorn_json("26-002"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks annotation subtype and tabs" {
  let unknown = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test(
      [ua_matterhorn_annotation_for_test("/Custom")],
      tabs=Some(PdfNameObject(ua_matterhorn_name_for_test("/S"))),
    ),
  )
  @test.assert_eq(
    try! unknown.test_matterhorn_json("28-006"),
    Json::array([ua_matterhorn_28_006_failure_for_test()]),
  )

  let link = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test(
      [ua_matterhorn_annotation_for_test("/Link")],
      tabs=Some(PdfNameObject(ua_matterhorn_name_for_test("/S"))),
    ),
  )
  @test.assert_eq(try! link.test_matterhorn_json("28-006"), Json::array([]))

  let trap_net = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test(
      [ua_matterhorn_annotation_for_test("/TrapNet")],
      tabs=Some(PdfNameObject(ua_matterhorn_name_for_test("/S"))),
    ),
  )
  @test.assert_eq(
    try! trap_net.test_matterhorn_json("28-007"),
    Json::array([ua_matterhorn_28_007_failure_for_test()]),
  )
  @test.assert_eq(try! link.test_matterhorn_json("28-007"), Json::array([]))

  let no_tabs = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test([
      ua_matterhorn_annotation_for_test("/Link"),
    ]),
  )
  @test.assert_eq(
    try! no_tabs.test_matterhorn_json("28-008"),
    Json::array([ua_matterhorn_28_008_failure_for_test()]),
  )
  @test.assert_eq(try! link.test_matterhorn_json("28-008"), Json::array([]))

  let no_annotations = ua_matterhorn_document_for_test([])
  @test.assert_eq(
    try! no_annotations.test_matterhorn_json("28-008"),
    Json::array([]),
  )

  let row_tabs = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test(
      [ua_matterhorn_annotation_for_test("/Link")],
      tabs=Some(PdfNameObject(ua_matterhorn_name_for_test("/R"))),
    ),
  )
  @test.assert_eq(
    try! row_tabs.test_matterhorn_json("28-009"),
    Json::array([ua_matterhorn_28_009_failure_for_test()]),
  )
  @test.assert_eq(try! link.test_matterhorn_json("28-009"), Json::array([]))
  @test.assert_eq(try! no_tabs.test_matterhorn_json("28-009"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json checks annotation structure parents" {
  let key_struct_parent = ua_matterhorn_name_for_test("/StructParent")

  let widget_unstructured = ua_matterhorn_document_for_test([])
  widget_unstructured.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Widget"),
  )
  @test.assert_eq(
    try! widget_unstructured.test_matterhorn_json("28-010"),
    Json::array([
      ua_matterhorn_28_010_failure_for_test(
        Json::string("not in structure tree"),
      ),
    ]),
  )

  let widget_wrong_type = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (7, ua_matterhorn_structure_element_for_test("/Link")),
    ]),
  )
  widget_wrong_type.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Widget", extras=[
      (key_struct_parent, PdfInteger(7)),
    ]),
  )
  @test.assert_eq(
    try! widget_wrong_type.test_matterhorn_json("28-010"),
    Json::array([
      ua_matterhorn_28_010_failure_for_test(Json::string("type is not form")),
    ]),
  )

  let widget_valid = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (7, ua_matterhorn_structure_element_for_test("/Form")),
    ]),
  )
  widget_valid.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Widget", extras=[
      (key_struct_parent, PdfInteger(7)),
    ]),
  )
  @test.assert_eq(
    try! widget_valid.test_matterhorn_json("28-010"),
    Json::array([]),
  )

  let widget_missing_parent = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (7, ua_matterhorn_structure_element_for_test("/Form")),
    ]),
  )
  widget_missing_parent.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Widget", extras=[
      (key_struct_parent, PdfInteger(99)),
    ]),
  )
  @test.assert_eq(
    try! widget_missing_parent.test_matterhorn_json("28-010"),
    Json::array([
      ua_matterhorn_28_010_failure_for_test(
        Json::string("not found in parent tree"),
      ),
    ]),
  )

  let link_unstructured = ua_matterhorn_document_for_test([])
  link_unstructured.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Link"),
  )
  @test.assert_eq(
    try! link_unstructured.test_matterhorn_json("28-011"),
    Json::array([]),
  )

  let link_wrong_type = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (8, ua_matterhorn_structure_element_for_test("/Form")),
    ]),
  )
  link_wrong_type.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Link", extras=[
      (key_struct_parent, PdfInteger(8)),
    ]),
  )
  @test.assert_eq(
    try! link_wrong_type.test_matterhorn_json("28-011"),
    Json::array([
      ua_matterhorn_28_011_failure_for_test(Json::string("type is not link")),
    ]),
  )

  let link_valid = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (8, ua_matterhorn_structure_element_for_test("/Link")),
    ]),
  )
  link_valid.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Link", extras=[
      (key_struct_parent, PdfInteger(8)),
    ]),
  )
  @test.assert_eq(
    try! link_valid.test_matterhorn_json("28-011"),
    Json::array([]),
  )

  let link_missing_parent = ua_matterhorn_document_for_test(
    [],
    root_extras=ua_matterhorn_struct_parent_tree_root_for_test([
      (8, ua_matterhorn_structure_element_for_test("/Link")),
    ]),
  )
  link_missing_parent.add_object_given_number(
    40,
    ua_matterhorn_annotation_for_test("/Link", extras=[
      (key_struct_parent, PdfInteger(99)),
    ]),
  )
  @test.assert_eq(
    try! link_missing_parent.test_matterhorn_json("28-011"),
    Json::array([
      ua_matterhorn_28_011_failure_for_test(
        Json::string("not found in parent tree"),
      ),
    ]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks link annotation contents" {
  let missing_contents = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test(
      [ua_matterhorn_annotation_for_test("/Link")],
      tabs=Some(PdfNameObject(ua_matterhorn_name_for_test("/S"))),
    ),
  )
  @test.assert_eq(
    try! missing_contents.test_matterhorn_json("28-012"),
    Json::array([ua_matterhorn_28_012_failure_for_test()]),
  )

  let with_contents = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test(
      [
        ua_matterhorn_annotation_for_test("/Link", extras=[
          (
            ua_matterhorn_name_for_test("/Contents"),
            PdfString(@ascii.encode("Open related section")),
          ),
        ]),
      ],
      tabs=Some(PdfNameObject(ua_matterhorn_name_for_test("/S"))),
    ),
  )
  @test.assert_eq(
    try! with_contents.test_matterhorn_json("28-012"),
    Json::array([]),
  )

  let non_link = ua_matterhorn_document_for_test(
    [],
    rest=ua_matterhorn_page_rest_with_annots_for_test(
      [ua_matterhorn_annotation_for_test("/Text")],
      tabs=Some(PdfNameObject(ua_matterhorn_name_for_test("/S"))),
    ),
  )
  @test.assert_eq(try! non_link.test_matterhorn_json("28-012"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects media clip dictionaries" {
  let key_type = ua_matterhorn_name_for_test("/Type")
  let key_s = ua_matterhorn_name_for_test("/S")
  let key_ct = ua_matterhorn_name_for_test("/CT")
  let media_clip : @pdflite.PdfObject = PdfDictionary([
    (key_type, PdfNameObject(ua_matterhorn_name_for_test("/MediaClip"))),
    (key_s, PdfNameObject(ua_matterhorn_name_for_test("/MCD"))),
  ])
  let document = ua_matterhorn_document_for_test([])
  document.add_object_given_number(40, media_clip)
  @test.assert_eq(
    try! document.test_matterhorn_json("28-014"),
    Json::array([ua_matterhorn_28_014_failure_for_test()]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("28-015"),
    Json::array([ua_matterhorn_28_015_failure_for_test()]),
  )

  let with_ct = ua_matterhorn_document_for_test([])
  with_ct.add_object_given_number(
    40,
    try! media_clip.add_dict_entry(
      key_ct,
      PdfString(@ascii.encode("video/mp4")),
    ),
  )
  @test.assert_eq(try! with_ct.test_matterhorn_json("28-014"), Json::array([]))
  @test.assert_eq(try! with_ct.test_matterhorn_json("28-015"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json handles file attachment conformance no-op" {
  let document = ua_matterhorn_document_for_test([])
  @test.assert_eq(try! document.test_matterhorn_json("28-016"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects PrinterMark structure entries" {
  let key_subtype = ua_matterhorn_name_for_test("/Subtype")
  let key_struct_parent = ua_matterhorn_name_for_test("/StructParent")
  let document = ua_matterhorn_document_for_test([])
  document.add_object_given_number(
    40,
    PdfDictionary([
      (key_subtype, PdfNameObject(ua_matterhorn_name_for_test("/PrinterMark"))),
      (key_struct_parent, PdfInteger(0)),
    ]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("28-017"),
    Json::array([ua_matterhorn_28_017_failure_for_test()]),
  )

  let unstructured = ua_matterhorn_document_for_test([])
  unstructured.add_object_given_number(
    40,
    PdfDictionary([
      (key_subtype, PdfNameObject(ua_matterhorn_name_for_test("/PrinterMark"))),
    ]),
  )
  @test.assert_eq(
    try! unstructured.test_matterhorn_json("28-017"),
    Json::array([]),
  )

  let other_subtype = ua_matterhorn_document_for_test([])
  other_subtype.add_object_given_number(
    40,
    PdfDictionary([
      (key_subtype, PdfNameObject(ua_matterhorn_name_for_test("/Text"))),
      (key_struct_parent, PdfInteger(0)),
    ]),
  )
  @test.assert_eq(
    try! other_subtype.test_matterhorn_json("28-017"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks PrinterMark appearance marking" {
  let span = ua_matterhorn_name_for_test("/Span")
  let document = ua_matterhorn_document_for_test([])
  document.add_object_given_number(
    40,
    ua_matterhorn_printer_mark_for_test(PdfIndirect(41)),
  )
  document.add_object_given_number(
    41,
    ua_matterhorn_form_stream_for_test([Op_Tj(b"mark")]),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("28-018"),
    Json::array([ua_matterhorn_28_018_failure_for_test()]),
  )

  let dictionary_appearance = ua_matterhorn_document_for_test([])
  dictionary_appearance.add_object_given_number(
    40,
    ua_matterhorn_printer_mark_for_test(
      PdfDictionary([(ua_matterhorn_name_for_test("/On"), PdfIndirect(41))]),
    ),
  )
  dictionary_appearance.add_object_given_number(
    41,
    ua_matterhorn_form_stream_for_test([Op_Tj(b"mark")]),
  )
  @test.assert_eq(
    try! dictionary_appearance.test_matterhorn_json("28-018"),
    Json::array([ua_matterhorn_28_018_failure_for_test()]),
  )

  let marked = ua_matterhorn_document_for_test([])
  marked.add_object_given_number(
    40,
    ua_matterhorn_printer_mark_for_test(PdfIndirect(41)),
  )
  marked.add_object_given_number(
    41,
    ua_matterhorn_form_stream_for_test([
      Op_BDC(span, PdfDictionary([])),
      Op_Tj(b"mark"),
      Op_EMC,
    ]),
  )
  @test.assert_eq(try! marked.test_matterhorn_json("28-018"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects reference XObjects" {
  let key_ref = ua_matterhorn_name_for_test("/Ref")
  let document = ua_matterhorn_document_for_test([])
  document.add_object_given_number(
    40,
    try! ua_matterhorn_form_stream_for_test([]).add_dict_entry(
      key_ref,
      PdfDictionary([]),
    ),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("30-001"),
    Json::array([ua_matterhorn_30_001_failure_for_test()]),
  )

  let no_ref = ua_matterhorn_document_for_test([])
  no_ref.add_object_given_number(40, ua_matterhorn_form_stream_for_test([]))
  @test.assert_eq(try! no_ref.test_matterhorn_json("30-001"), Json::array([]))

  let non_form = ua_matterhorn_document_for_test([])
  non_form.add_object_given_number(
    40,
    PdfDictionary([(key_ref, PdfDictionary([]))]),
  )
  @test.assert_eq(try! non_form.test_matterhorn_json("30-001"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects multiply referenced MCID Form XObjects" {
  let span = ua_matterhorn_name_for_test("/Span")
  let mcid = ua_matterhorn_name_for_test("/MCID")
  let form_name = ua_matterhorn_name_for_test("/Fm1")
  let wrapper_name = ua_matterhorn_name_for_test("/Fm2")
  let target = ua_matterhorn_form_stream_for_test([
    Op_BDC(span, PdfDictionary([(mcid, PdfInteger(0))])),
    Op_Tj(b"content"),
    Op_EMC,
  ])
  let document = ua_matterhorn_document_for_test(
    [],
    resources=ua_matterhorn_xobject_resources_for_test([
      (form_name, PdfIndirect(40)),
    ]),
  )
  document.add_object_given_number(40, target)
  document.add_object_given_number(
    41,
    ua_matterhorn_form_stream_for_test(
      [],
      resources=ua_matterhorn_xobject_resources_for_test([
        (wrapper_name, PdfIndirect(40)),
      ]),
    ),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("30-002"),
    Json::array([ua_matterhorn_30_002_failure_for_test()]),
  )

  let single = ua_matterhorn_document_for_test(
    [],
    resources=ua_matterhorn_xobject_resources_for_test([
      (form_name, PdfIndirect(40)),
    ]),
  )
  single.add_object_given_number(40, target)
  @test.assert_eq(try! single.test_matterhorn_json("30-002"), Json::array([]))

  let no_mcid = ua_matterhorn_document_for_test(
    [],
    resources=ua_matterhorn_xobject_resources_for_test([
      (form_name, PdfIndirect(40)),
    ]),
  )
  no_mcid.add_object_given_number(
    40,
    ua_matterhorn_form_stream_for_test([Op_Tj(b"content")]),
  )
  no_mcid.add_object_given_number(
    41,
    ua_matterhorn_form_stream_for_test(
      [],
      resources=ua_matterhorn_xobject_resources_for_test([
        (wrapper_name, PdfIndirect(40)),
      ]),
    ),
  )
  @test.assert_eq(try! no_mcid.test_matterhorn_json("30-002"), Json::array([]))
}

///|
test "PdfDocument test_matterhorn_json detects Type0 CIDSystemInfo mismatches" {
  let registry_mismatch = ua_matterhorn_document_for_test([])
  registry_mismatch.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(PdfIndirect(42), 41),
  )
  registry_mismatch.add_object_given_number(
    41,
    ua_matterhorn_cid_font_for_test("Other", "UCS"),
  )
  registry_mismatch.add_object_given_number(
    42,
    ua_matterhorn_cmap_for_test("Adobe", "UCS"),
  )
  @test.assert_eq(
    try! registry_mismatch.test_matterhorn_json("31-001"),
    Json::array([ua_matterhorn_31_001_failure_for_test()]),
  )

  let ordering_mismatch = ua_matterhorn_document_for_test([])
  ordering_mismatch.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(PdfIndirect(42), 41),
  )
  ordering_mismatch.add_object_given_number(
    41,
    ua_matterhorn_cid_font_for_test("Adobe", "Japan1"),
  )
  ordering_mismatch.add_object_given_number(
    42,
    ua_matterhorn_cmap_for_test("Adobe", "UCS"),
  )
  @test.assert_eq(
    try! ordering_mismatch.test_matterhorn_json("31-002"),
    Json::array([ua_matterhorn_31_002_failure_for_test()]),
  )

  let identity_encoding = ua_matterhorn_document_for_test([])
  identity_encoding.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(
      PdfNameObject(ua_matterhorn_name_for_test("/Identity-H")),
      41,
    ),
  )
  identity_encoding.add_object_given_number(
    41,
    ua_matterhorn_cid_font_for_test("Other", "Japan1"),
  )
  @test.assert_eq(
    try! identity_encoding.test_matterhorn_json("31-001"),
    Json::array([]),
  )
  @test.assert_eq(
    try! identity_encoding.test_matterhorn_json("31-002"),
    Json::array([]),
  )
  @test.assert_eq(
    try! identity_encoding.test_matterhorn_json("31-003"),
    Json::array([]),
  )

  let matching = ua_matterhorn_document_for_test([])
  matching.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(PdfIndirect(42), 41),
  )
  matching.add_object_given_number(
    41,
    ua_matterhorn_cid_font_for_test("Adobe", "UCS"),
  )
  matching.add_object_given_number(
    42,
    ua_matterhorn_cmap_for_test("Adobe", "UCS"),
  )
  @test.assert_eq(try! matching.test_matterhorn_json("31-001"), Json::array([]))
  @test.assert_eq(try! matching.test_matterhorn_json("31-002"), Json::array([]))

  let source_supplement_comparison = ua_matterhorn_document_for_test([])
  source_supplement_comparison.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(PdfIndirect(42), 41),
  )
  source_supplement_comparison.add_object_given_number(
    41,
    ua_matterhorn_cid_font_for_test("Adobe", "UCS"),
  )
  source_supplement_comparison.add_object_given_number(
    42,
    ua_matterhorn_cmap_for_test("Adobe", "UCS"),
  )
  @test.assert_eq(
    try! source_supplement_comparison.test_matterhorn_json("31-003"),
    Json::array([ua_matterhorn_31_003_failure_for_test()]),
  )

  let source_supplement_match = ua_matterhorn_document_for_test([])
  source_supplement_match.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(PdfIndirect(42), 41),
  )
  source_supplement_match.add_object_given_number(
    41,
    ua_matterhorn_cid_font_for_test("Other", "Adobe"),
  )
  source_supplement_match.add_object_given_number(
    42,
    ua_matterhorn_cmap_for_test("Adobe", "UCS"),
  )
  @test.assert_eq(
    try! source_supplement_match.test_matterhorn_json("31-003"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks Type2 CIDToGIDMap" {
  let missing_map = ua_matterhorn_document_for_test([])
  let missing_font = ua_matterhorn_cid_font_type2_for_test(None)
  missing_map.add_object_given_number(40, missing_font)
  @test.assert_eq(
    try! missing_map.test_matterhorn_json("31-004"),
    Json::array([
      ua_matterhorn_31_004_failure_for_test(
        ua_matterhorn_serialized_object_extra_for_test(missing_font),
      ),
    ]),
  )
  @test.assert_eq(
    try! missing_map.test_matterhorn_json("31-005"),
    Json::array([ua_matterhorn_31_005_failure_for_test()]),
  )

  let invalid_map = ua_matterhorn_document_for_test([])
  let invalid_font = ua_matterhorn_cid_font_type2_for_test(Some(PdfInteger(7)))
  invalid_map.add_object_given_number(40, invalid_font)
  @test.assert_eq(
    try! invalid_map.test_matterhorn_json("31-004"),
    Json::array([
      ua_matterhorn_31_004_failure_for_test(
        ua_matterhorn_serialized_object_extra_for_test(invalid_font),
      ),
    ]),
  )
  @test.assert_eq(
    try! invalid_map.test_matterhorn_json("31-005"),
    Json::array([]),
  )

  let identity_map = ua_matterhorn_document_for_test([])
  identity_map.add_object_given_number(
    40,
    ua_matterhorn_cid_font_type2_for_test(
      Some(PdfNameObject(ua_matterhorn_name_for_test("/Identity"))),
    ),
  )
  @test.assert_eq(
    try! identity_map.test_matterhorn_json("31-004"),
    Json::array([]),
  )
  @test.assert_eq(
    try! identity_map.test_matterhorn_json("31-005"),
    Json::array([]),
  )

  let stream_map = ua_matterhorn_document_for_test([])
  stream_map.add_object_given_number(
    40,
    ua_matterhorn_cid_font_type2_for_test(
      Some(@pdflite.pdf_stream(PdfDictionary([]), StreamGot(b"\x00\x01"))),
    ),
  )
  @test.assert_eq(
    try! stream_map.test_matterhorn_json("31-004"),
    Json::array([]),
  )
  @test.assert_eq(
    try! stream_map.test_matterhorn_json("31-005"),
    Json::array([]),
  )

  let non_cid_type2 = ua_matterhorn_document_for_test([])
  non_cid_type2.add_object_given_number(
    40,
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/Subtype"),
        PdfNameObject(ua_matterhorn_name_for_test("/CIDFontType0")),
      ),
    ]),
  )
  @test.assert_eq(
    try! non_cid_type2.test_matterhorn_json("31-004"),
    Json::array([]),
  )
  @test.assert_eq(
    try! non_cid_type2.test_matterhorn_json("31-005"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks CMap names" {
  let unlisted_encoding = ua_matterhorn_document_for_test([])
  unlisted_encoding.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(
      PdfNameObject(ua_matterhorn_name_for_test("/Private-H")),
      41,
    ),
  )
  @test.assert_eq(
    try! unlisted_encoding.test_matterhorn_json("31-006"),
    Json::array([ua_matterhorn_31_006_failure_for_test("/Private-H")]),
  )

  let listed_encoding = ua_matterhorn_document_for_test([])
  listed_encoding.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(
      PdfNameObject(ua_matterhorn_name_for_test("/GB-EUC-H")),
      41,
    ),
  )
  @test.assert_eq(
    try! listed_encoding.test_matterhorn_json("31-006"),
    Json::array([]),
  )

  let embedded_encoding = ua_matterhorn_document_for_test([])
  embedded_encoding.add_object_given_number(
    40,
    ua_matterhorn_type0_font_for_test(PdfIndirect(42), 41),
  )
  @test.assert_eq(
    try! embedded_encoding.test_matterhorn_json("31-006"),
    Json::array([]),
  )

  let non_type0 = ua_matterhorn_document_for_test([])
  non_type0.add_object_given_number(
    40,
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/Subtype"),
        PdfNameObject(ua_matterhorn_name_for_test("/Type1")),
      ),
      (
        ua_matterhorn_name_for_test("/Encoding"),
        PdfNameObject(ua_matterhorn_name_for_test("/Private-H")),
      ),
    ]),
  )
  @test.assert_eq(
    try! non_type0.test_matterhorn_json("31-006"),
    Json::array([]),
  )

  let unlisted_base = ua_matterhorn_document_for_test([])
  unlisted_base.add_object_given_number(
    42,
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/UseCMap"),
        PdfNameObject(ua_matterhorn_name_for_test("/PrivateBase-H")),
      ),
    ]),
  )
  @test.assert_eq(
    try! unlisted_base.test_matterhorn_json("31-008"),
    Json::array([ua_matterhorn_31_008_failure_for_test("/PrivateBase-H")]),
  )

  let listed_base = ua_matterhorn_document_for_test([])
  listed_base.add_object_given_number(
    42,
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/UseCMap"),
        PdfNameObject(ua_matterhorn_name_for_test("/Identity-H")),
      ),
    ]),
  )
  @test.assert_eq(
    try! listed_base.test_matterhorn_json("31-008"),
    Json::array([]),
  )

  let embedded_base = ua_matterhorn_document_for_test([])
  embedded_base.add_object_given_number(
    42,
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/UseCMap"),
        @pdflite.pdf_stream(PdfDictionary([]), StreamGot(b"")),
      ),
    ]),
  )
  @test.assert_eq(
    try! embedded_base.test_matterhorn_json("31-008"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json compares CMap WMode values" {
  let mismatch = ua_matterhorn_document_for_test([])
  mismatch.add_object_given_number(
    42,
    ua_matterhorn_cmap_stream_for_test(Some(0), Some(1)),
  )
  @test.assert_eq(
    try! mismatch.test_matterhorn_json("31-007"),
    Json::array([ua_matterhorn_31_007_failure_for_test()]),
  )

  let matching = ua_matterhorn_document_for_test([])
  matching.add_object_given_number(
    42,
    ua_matterhorn_cmap_stream_for_test(Some(1), Some(1)),
  )
  @test.assert_eq(try! matching.test_matterhorn_json("31-007"), Json::array([]))

  let default_stream_wmode = ua_matterhorn_document_for_test([])
  default_stream_wmode.add_object_given_number(
    42,
    ua_matterhorn_cmap_stream_for_test(Some(0), None),
  )
  @test.assert_eq(
    try! default_stream_wmode.test_matterhorn_json("31-007"),
    Json::array([]),
  )

  let no_dictionary_wmode = ua_matterhorn_document_for_test([])
  no_dictionary_wmode.add_object_given_number(
    42,
    ua_matterhorn_cmap_stream_for_test(None, Some(1)),
  )
  @test.assert_eq(
    try! no_dictionary_wmode.test_matterhorn_json("31-007"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks missing fonts" {
  let document = ua_matterhorn_document_for_test(
    [],
    resources=ua_matterhorn_font_resources_for_test([
      ("/F1", PdfIndirect(40)),
      ("/F2", PdfIndirect(41)),
      ("/F3", PdfIndirect(42)),
      ("/F4", PdfIndirect(43)),
    ]),
  )
  document.add_object_given_number(
    40,
    ua_matterhorn_font_for_test("/Type1", "/MissingOne", None, None),
  )
  document.add_object_given_number(
    41,
    ua_matterhorn_font_for_test("/Type3", "/InlineType3", None, None),
  )
  document.add_object_given_number(
    42,
    ua_matterhorn_font_for_test(
      "/Type1",
      "/EmbeddedOne",
      None,
      Some(ua_matterhorn_font_descriptor_with_file_for_test(None, b"font")),
    ),
  )
  document.add_object_given_number(
    43,
    ua_matterhorn_font_for_test(
      "/Type1",
      "/DescriptorMissing",
      Some("/MacRomanEncoding"),
      Some(ua_matterhorn_font_descriptor_for_test(Some(32))),
    ),
  )
  @test.assert_eq(
    try! document.test_matterhorn_json("31-009"),
    Json::array([
      ua_matterhorn_31_009_failure_for_test(
        Json::array([
          Json::string("1 /F1 /Type1 /MissingOne Built-in"),
          Json::string("1 /F4 /Type1 /DescriptorMissing /MacRomanEncoding"),
        ]),
      ),
    ]),
  )
}

///|
test "PdfDocument test_matterhorn_json preserves source no-op font-file checks" {
  let document = ua_matterhorn_document_for_test([])
  for
    name in [
      "31-011", "31-012", "31-013", "31-014", "31-015", "31-016", "31-018", "31-030",
    ] {
    @test.assert_eq(try! document.test_matterhorn_json(name), Json::array([]))
  }
}

///|
test "PdfDocument test_matterhorn_json checks TrueType encoding Matterhorn checks" {
  let missing_encoding = ua_matterhorn_document_for_test([])
  missing_encoding.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(Some(32), None),
  )
  @test.assert_eq(
    try! missing_encoding.test_matterhorn_json("31-019"),
    Json::array([ua_matterhorn_31_019_failure_for_test()]),
  )

  let symbolic_missing_encoding = ua_matterhorn_document_for_test([])
  symbolic_missing_encoding.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(Some(4), None),
  )
  @test.assert_eq(
    try! symbolic_missing_encoding.test_matterhorn_json("31-019"),
    Json::array([]),
  )

  let missing_base = ua_matterhorn_document_for_test([])
  missing_base.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(ua_matterhorn_encoding_dictionary_for_test([])),
    ),
  )
  @test.assert_eq(
    try! missing_base.test_matterhorn_json("31-020"),
    Json::array([ua_matterhorn_31_020_failure_for_test()]),
  )

  let valid_base = ua_matterhorn_document_for_test([])
  valid_base.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(
        ua_matterhorn_encoding_dictionary_for_test([
          (
            ua_matterhorn_name_for_test("/BaseEncoding"),
            PdfNameObject(ua_matterhorn_name_for_test("/WinAnsiEncoding")),
          ),
        ]),
      ),
    ),
  )
  @test.assert_eq(
    try! valid_base.test_matterhorn_json("31-020"),
    Json::array([]),
  )
  @test.assert_eq(
    try! valid_base.test_matterhorn_json("31-021"),
    Json::array([]),
  )

  let invalid_encoding_name = ua_matterhorn_document_for_test([])
  invalid_encoding_name.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(PdfNameObject(ua_matterhorn_name_for_test("/MacExpertEncoding"))),
    ),
  )
  @test.assert_eq(
    try! invalid_encoding_name.test_matterhorn_json("31-021"),
    Json::array([ua_matterhorn_31_021_failure_for_test(Json::null())]),
  )

  let invalid_base = ua_matterhorn_document_for_test([])
  invalid_base.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(
        ua_matterhorn_encoding_dictionary_for_test([
          (ua_matterhorn_name_for_test("/BaseEncoding"), PdfInteger(7)),
        ]),
      ),
    ),
  )
  @test.assert_eq(
    try! invalid_base.test_matterhorn_json("31-021"),
    Json::array([ua_matterhorn_31_021_failure_for_test(Json::string("7"))]),
  )

  let invalid_difference = ua_matterhorn_document_for_test([])
  invalid_difference.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(
        ua_matterhorn_encoding_dictionary_for_test([
          (
            ua_matterhorn_name_for_test("/BaseEncoding"),
            PdfNameObject(ua_matterhorn_name_for_test("/WinAnsiEncoding")),
          ),
          (
            ua_matterhorn_name_for_test("/Differences"),
            PdfArray([
              PdfInteger(65),
              PdfNameObject(ua_matterhorn_name_for_test("/A")),
              PdfNameObject(ua_matterhorn_name_for_test("/DefinitelyNotAGlyph")),
            ]),
          ),
        ]),
      ),
    ),
  )
  @test.assert_eq(
    try! invalid_difference.test_matterhorn_json("31-022"),
    Json::array([ua_matterhorn_31_022_failure_for_test("/DefinitelyNotAGlyph")]),
  )

  let generated_difference_name = ua_matterhorn_document_for_test([])
  generated_difference_name.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(
        ua_matterhorn_encoding_dictionary_for_test([
          (
            ua_matterhorn_name_for_test("/Differences"),
            PdfArray([
              PdfInteger(65),
              PdfNameObject(ua_matterhorn_name_for_test("/uni0041")),
            ]),
          ),
        ]),
      ),
    ),
  )
  @test.assert_eq(
    try! generated_difference_name.test_matterhorn_json("31-022"),
    Json::array([ua_matterhorn_31_022_failure_for_test("/uni0041")]),
  )

  let valid_difference = ua_matterhorn_document_for_test([])
  valid_difference.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(
        ua_matterhorn_encoding_dictionary_for_test([
          (
            ua_matterhorn_name_for_test("/Differences"),
            PdfArray([
              PdfInteger(65),
              PdfNameObject(ua_matterhorn_name_for_test("/A")),
            ]),
          ),
        ]),
      ),
    ),
  )
  @test.assert_eq(
    try! valid_difference.test_matterhorn_json("31-022"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks TrueType cmap Matterhorn checks" {
  let encoding_with_differences = ua_matterhorn_encoding_dictionary_for_test([
    (
      ua_matterhorn_name_for_test("/Differences"),
      PdfArray([
        PdfInteger(65),
        PdfNameObject(ua_matterhorn_name_for_test("/A")),
      ]),
    ),
  ])

  let missing_unicode_cmap = ua_matterhorn_document_for_test([])
  missing_unicode_cmap.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_with_file_for_test(
      Some(32),
      Some(encoding_with_differences),
      ua_matterhorn_truetype_cmap_font_for_test([(1, 0)]),
    ),
  )
  @test.assert_eq(
    try! missing_unicode_cmap.test_matterhorn_json("31-023"),
    Json::array([ua_matterhorn_31_023_failure_for_test()]),
  )

  let unicode_cmap = ua_matterhorn_document_for_test([])
  unicode_cmap.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_with_file_for_test(
      Some(32),
      Some(encoding_with_differences),
      ua_matterhorn_truetype_cmap_font_for_test([(3, 1)]),
    ),
  )
  @test.assert_eq(
    try! unicode_cmap.test_matterhorn_json("31-023"),
    Json::array([]),
  )

  let no_fontfile = ua_matterhorn_document_for_test([])
  no_fontfile.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(encoding_with_differences),
    ),
  )
  @test.assert_eq(
    try! no_fontfile.test_matterhorn_json("31-023"),
    Json::array([]),
  )

  let symbolic_encoding = ua_matterhorn_document_for_test([])
  symbolic_encoding.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(4),
      Some(PdfNameObject(ua_matterhorn_name_for_test("/WinAnsiEncoding"))),
    ),
  )
  @test.assert_eq(
    try! symbolic_encoding.test_matterhorn_json("31-024"),
    Json::array([ua_matterhorn_31_024_failure_for_test()]),
  )

  let non_symbolic_encoding = ua_matterhorn_document_for_test([])
  non_symbolic_encoding.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(
      Some(32),
      Some(PdfNameObject(ua_matterhorn_name_for_test("/WinAnsiEncoding"))),
    ),
  )
  @test.assert_eq(
    try! non_symbolic_encoding.test_matterhorn_json("31-024"),
    Json::array([]),
  )

  let symbolic_non_symbolic_cmap = ua_matterhorn_document_for_test([])
  symbolic_non_symbolic_cmap.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_with_file_for_test(
      Some(4),
      None,
      ua_matterhorn_truetype_cmap_font_for_test([(3, 1)]),
    ),
  )
  @test.assert_eq(
    try! symbolic_non_symbolic_cmap.test_matterhorn_json("31-017"),
    Json::array([
      ua_matterhorn_31_017_failure_for_test(Json::string("(3, 1) cmap")),
    ]),
  )
  @test.assert_eq(
    try! symbolic_non_symbolic_cmap.test_matterhorn_json("31-026"),
    Json::array([]),
  )

  let symbolic_cmaps = ua_matterhorn_document_for_test([])
  symbolic_cmaps.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_with_file_for_test(
      Some(4),
      None,
      ua_matterhorn_truetype_cmap_font_for_test([(1, 8), (3, 0)]),
    ),
  )
  @test.assert_eq(
    try! symbolic_cmaps.test_matterhorn_json("31-017"),
    Json::array([]),
  )
  @test.assert_eq(
    try! symbolic_cmaps.test_matterhorn_json("31-026"),
    Json::array([]),
  )

  let symbolic_no_cmap = ua_matterhorn_document_for_test([])
  symbolic_no_cmap.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_with_file_for_test(Some(4), None, b"\x00"),
  )
  @test.assert_eq(
    try! symbolic_no_cmap.test_matterhorn_json("31-025"),
    Json::array([ua_matterhorn_31_025_failure_for_test()]),
  )

  let symbolic_missing_fontfile = ua_matterhorn_document_for_test([])
  symbolic_missing_fontfile.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_for_test(Some(4), None),
  )
  @test.assert_eq(
    try! symbolic_missing_fontfile.test_matterhorn_json("31-025"),
    Json::array([]),
  )

  let multiple_without_symbol_cmap = ua_matterhorn_document_for_test([])
  multiple_without_symbol_cmap.add_object_given_number(
    40,
    ua_matterhorn_truetype_font_with_file_for_test(
      Some(4),
      None,
      ua_matterhorn_truetype_cmap_font_for_test([(1, 0), (3, 1)]),
    ),
  )
  @test.assert_eq(
    try! multiple_without_symbol_cmap.test_matterhorn_json("31-026"),
    Json::array([ua_matterhorn_31_026_failure_for_test()]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks missing ToUnicode exemptions" {
  let symbolic_descriptor = ua_matterhorn_font_descriptor_for_test(Some(4))
  let symbolic_truetype = ua_matterhorn_font_for_test(
    "/TrueType",
    "/SymbolicTrueType",
    None,
    Some(symbolic_descriptor),
  )
  let missing_tounicode = ua_matterhorn_document_for_test([])
  missing_tounicode.add_object_given_number(40, symbolic_truetype)
  @test.assert_eq(
    try! missing_tounicode.test_matterhorn_json("31-027"),
    Json::array([
      ua_matterhorn_31_027_failure_for_test(
        ua_matterhorn_serialized_object_extra_for_test(symbolic_truetype),
      ),
    ]),
  )

  let with_tounicode = ua_matterhorn_document_for_test([])
  with_tounicode.add_object_given_number(
    40,
    ua_matterhorn_font_for_test(
      "/TrueType",
      "/SymbolicTrueType",
      None,
      Some(symbolic_descriptor),
      extras=[
        (
          ua_matterhorn_name_for_test("/ToUnicode"),
          @pdflite.pdf_stream(PdfDictionary([]), StreamGot(b"")),
        ),
      ],
    ),
  )
  @test.assert_eq(
    try! with_tounicode.test_matterhorn_json("31-027"),
    Json::array([]),
  )

  let winansi = ua_matterhorn_document_for_test([])
  winansi.add_object_given_number(
    40,
    ua_matterhorn_font_for_test(
      "/TrueType",
      "/SymbolicTrueType",
      Some("/WinAnsiEncoding"),
      Some(symbolic_descriptor),
    ),
  )
  @test.assert_eq(try! winansi.test_matterhorn_json("31-027"), Json::array([]))

  let type0_collection = ua_matterhorn_document_for_test([])
  type0_collection.add_object_given_number(
    41,
    PdfDictionary([
      (
        ua_matterhorn_name_for_test("/CIDSystemInfo"),
        PdfDictionary([
          (
            ua_matterhorn_name_for_test("/Registry"),
            PdfNameObject(ua_matterhorn_name_for_test("/Adobe")),
          ),
          (
            ua_matterhorn_name_for_test("/Ordering"),
            PdfNameObject(ua_matterhorn_name_for_test("/GB1")),
          ),
        ]),
      ),
    ]),
  )
  type0_collection.add_object_given_number(
    40,
    ua_matterhorn_font_for_test(
      "/Type0",
      "/Composite",
      None,
      Some(symbolic_descriptor),
      extras=[
        (
          ua_matterhorn_name_for_test("/DescendantFonts"),
          PdfArray([PdfIndirect(41)]),
        ),
      ],
    ),
  )
  @test.assert_eq(
    try! type0_collection.test_matterhorn_json("31-027"),
    Json::array([]),
  )

  let cid_font_silent = ua_matterhorn_document_for_test([])
  cid_font_silent.add_object_given_number(
    40,
    ua_matterhorn_font_for_test(
      "/CIDFontType2",
      "/CID",
      None,
      Some(symbolic_descriptor),
    ),
  )
  @test.assert_eq(
    try! cid_font_silent.test_matterhorn_json("31-027"),
    Json::array([]),
  )

  let type1_unimplemented = ua_matterhorn_document_for_test([])
  type1_unimplemented.add_object_given_number(
    40,
    ua_matterhorn_font_for_test(
      "/Type1",
      "/SymbolicType1",
      None,
      Some(symbolic_descriptor),
    ),
  )
  @test.assert_eq(
    try! type1_unimplemented.test_matterhorn_json("31-027"),
    Json::array([]),
  )
}

///|
test "PdfDocument test_matterhorn_json checks ToUnicode value Matterhorn checks" {
  let zero_value = ua_matterhorn_document_for_test([])
  zero_value.add_object_given_number(
    40,
    ua_matterhorn_font_with_tounicode_for_test(PdfIndirect(41)),
  )
  zero_value.add_object_given_number(
    41,
    ua_matterhorn_tounicode_stream_for_test("0000"),
  )
  @test.assert_eq(
    try! zero_value.test_matterhorn_json("31-028"),
    Json::array([ua_matterhorn_31_028_failure_for_test()]),
  )
  @test.assert_eq(
    try! zero_value.test_matterhorn_json("31-029"),
    Json::array([]),
  )

  let byte_order_mark = ua_matterhorn_document_for_test([])
  byte_order_mark.add_object_given_number(
    40,
    ua_matterhorn_font_with_tounicode_for_test(PdfIndirect(41)),
  )
  byte_order_mark.add_object_given_number(
    41,
    ua_matterhorn_tounicode_stream_for_test("FEFF"),
  )
  @test.assert_eq(
    try! byte_order_mark.test_matterhorn_json("31-028"),
    Json::array([]),
  )
  @test.assert_eq(
    try! byte_order_mark.test_matterhorn_json("31-029"),
    Json::array([ua_matterhorn_31_029_failure_for_test()]),
  )

  let reverse_bom = ua_matterhorn_document_for_test([])
  reverse_bom.add_object_given_number(
    40,
    ua_matterhorn_font_with_tounicode_for_test(PdfIndirect(41)),
  )
  reverse_bom.add_object_given_number(
    41,
    ua_matterhorn_tounicode_stream_for_test("FFFE"),
  )
  @test.assert_eq(
    try! reverse_bom.test_matterhorn_json("31-029"),
    Json::array([ua_matterhorn_31_029_failure_for_test()]),
  )

  let normal_value = ua_matterhorn_document_for_test([])
  normal_value.add_object_given_number(
    40,
    ua_matterhorn_font_with_tounicode_for_test(PdfIndirect(41)),
  )
  normal_value.add_object_given_number(
    41,
    ua_matterhorn_tounicode_stream_for_test("0041"),
  )
  @test.assert_eq(
    try! normal_value.test_matterhorn_json("31-028"),
    Json::array([]),
  )
  @test.assert_eq(
    try! normal_value.test_matterhorn_json("31-029"),
    Json::array([]),
  )

  let direct_tounicode = ua_matterhorn_document_for_test([])
  direct_tounicode.add_object_given_number(
    40,
    ua_matterhorn_font_with_tounicode_for_test(
      ua_matterhorn_tounicode_stream_for_test("0000"),
    ),
  )
  @test.assert_eq(
    try! direct_tounicode.test_matterhorn_json("31-028"),
    Json::array([]),
  )
}
