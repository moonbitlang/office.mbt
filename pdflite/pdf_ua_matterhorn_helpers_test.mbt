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
    Map([
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
fn ua_matterhorn_09_004_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "09-004", "UA1-7.2-1", "A table-related structure element is used in a way that does not conform to the syntax defined in ISO 32000-1, Table 337.",
    extra,
  )
}

///|
fn ua_matterhorn_09_005_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "09-005", "UA1-7.2-1", "A list-related structure element is used in a way that does not conform to Table 336 in ISO 32000-1.",
    extra,
  )
}

///|
fn ua_matterhorn_09_006_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "09-006", "UA1-7.2-1", "A TOC-related structure element is used in a way that does not conform to Table 333 in ISO 32000-1.",
    extra,
  )
}

///|
fn ua_matterhorn_09_007_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "09-007",
    "UA1-7.2-1",
    "A Ruby-related structure element is used in a way that does not conform to Table 338 in ISO 32000-1.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_09_008_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "09-008",
    "UA1-7.2-1",
    "A Warichu-related structure element is used in a way that does not conform to Table 338 in ISO 32000-1.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_10_001_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "10-001", "UA1:7.2-2", "Character code cannot be mapped to Unicode.", extra,
  )
}

///|
fn ua_matterhorn_11_001_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "11-001", "UA1:7.2-3", "Natural language for text in page content cannot be determined.",
    extra,
  )
}

///|
fn ua_matterhorn_13_004_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "13-004",
    "UA1:7.3-3",
    "<Figure> tag alternative or replacement text missing.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_14_002_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "14-002", "UA1:7.4.2-1", "Does use numbered headings, but the first heading tag is not <H1>.",
    extra,
  )
}

///|
fn ua_matterhorn_14_003_failure_for_test(extra : Json) -> Json {
  ua_matterhorn_failure_for_test(
    "14-003", "UA1:7.4-1", "Numbered heading levels in descending sequence are skipped (Example: <H3> follows directly after <H1>).",
    extra,
  )
}

///|
fn ua_matterhorn_14_006_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "14-006",
    "UA1:7.4.4-1",
    "A node contains more than one <H> tag.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_14_007_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "14-007",
    "UA1:7.4.4-3",
    "Document uses both <H> and <H#> tags.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_15_003_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "15-003",
    "UA1:7.5-2",
    "In a table not organized with Headers attributes and IDs, a <TH> cell does not contain a Scope attribute.",
    Json::string("No scope, table organization not checked."),
  )
}

///|
fn ua_matterhorn_17_002_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "17-002",
    "UA1:7.7-1",
    "<Formula> tag is missing an Alt attribute.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_19_003_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "19-003",
    "UA1:7.9-2",
    "ID entry of the <Note> tag is not present.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_19_004_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "19-004",
    "UA1:7.9-2",
    "ID entry of the <Note> tag is non-unique.",
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
fn ua_matterhorn_28_002_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "28-002",
    "UA1:7.18.1-2",
    "An annotation, other than of subtype Widget, Link and PrinterMark, is not a direct child of an <Annot> structure element.",
    Json::null(),
  )
}

///|
fn ua_matterhorn_28_004_failure_for_test() -> Json {
  ua_matterhorn_failure_for_test(
    "28-004",
    "UA1:7.18.1-4",
    "An annotation, other than of subtype Widget, does not have a Contents entry and does not have an alternative description (in the form of an Alt entry in the enclosing structure element).",
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
  ops : ArrayView[@content.PdfContentOp],
  resources? : @pdflite.PdfObject = PdfDictionary([]),
  root_extras? : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)] = [],
  rest? : @pdflite.PdfObject = PdfDictionary([]),
) -> @pdflite.PdfDocument {
  let doc = @pdflite.pdf_document_empty()
  let page = {
    ..@page.pdf_page_blank(@pdflite.paper_a4),
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
  root_extras : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)],
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
  extras? : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)] = [],
) -> @pdflite.PdfObject {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      ua_matterhorn_name_for_test("/S"),
      PdfNameObject(ua_matterhorn_name_for_test(kind)),
    ),
  ]
  for extra in extras {
    entries.push(extra)
  }
  PdfDictionary(entries)
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
fn ua_matterhorn_struct_tree_root_for_test(
  children : ArrayView[@pdflite.PdfObject],
  extras? : ArrayView[(@pdflite.PdfName, @pdflite.PdfObject)] = [],
) -> Array[(@pdflite.PdfName, @pdflite.PdfObject)] {
  let entries : Array[(@pdflite.PdfName, @pdflite.PdfObject)] = [
    (
      ua_matterhorn_name_for_test("/K"),
      PdfArray([ for child in children => child ]),
    ),
  ]
  for extra in extras {
    entries.push(extra)
  }
  [(ua_matterhorn_name_for_test("/StructTreeRoot"), PdfDictionary(entries))]
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
  ops : ArrayView[@content.PdfContentOp],
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
fn ua_matterhorn_font_resource_document_for_test(
  font : @pdflite.PdfObject,
) -> @pdflite.PdfDocument {
  ua_matterhorn_document_for_test(
    [],
    resources=PdfDictionary([
      (
        ua_matterhorn_name_for_test("/Font"),
        PdfDictionary([(ua_matterhorn_name_for_test("/F1"), font)]),
      ),
    ]),
  )
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
