///|
priv enum PdfUAMatterhornContext {
  PdfUAMatterhornArtifact
  PdfUAMatterhornContent
  PdfUAMatterhornOther
}

///|
priv struct PdfUAMatterhornTest {
  name : String
  error : String
  section : String
}

///|
priv struct PdfUAMatterhornFailure {
  name : String
  error : String
  section : String
  extra : Json
}

///|
let pdf_ua_matterhorn_artifact_name : PdfName = pdf_ua_name("/Artifact")

///|
fn pdf_ua_matterhorn_artifact() -> PdfName {
  pdf_ua_matterhorn_artifact_name
}

///|
let pdf_ua_matterhorn_span_name : PdfName = pdf_ua_name("/Span")

///|
fn pdf_ua_matterhorn_span() -> PdfName {
  pdf_ua_matterhorn_span_name
}

///|
let pdf_ua_matterhorn_annot_name : PdfName = pdf_ua_name("/Annot")

///|
fn pdf_ua_matterhorn_annot() -> PdfName {
  pdf_ua_matterhorn_annot_name
}

///|
let pdf_ua_matterhorn_form_name : PdfName = pdf_ua_name("/Form")

///|
fn pdf_ua_matterhorn_form() -> PdfName {
  pdf_ua_matterhorn_form_name
}

///|
let pdf_ua_matterhorn_type0_name : PdfName = pdf_ua_name("/Type0")

///|
fn pdf_ua_matterhorn_type0() -> PdfName {
  pdf_ua_matterhorn_type0_name
}

///|
let pdf_ua_matterhorn_cid_font_type2_name : PdfName = pdf_ua_name(
  "/CIDFontType2",
)

///|
fn pdf_ua_matterhorn_cid_font_type2() -> PdfName {
  pdf_ua_matterhorn_cid_font_type2_name
}

///|
let pdf_ua_matterhorn_cid_font_type0_name : PdfName = pdf_ua_name(
  "/CIDFontType0",
)

///|
fn pdf_ua_matterhorn_cid_font_type0() -> PdfName {
  pdf_ua_matterhorn_cid_font_type0_name
}

///|
let pdf_ua_matterhorn_identity_name : PdfName = pdf_ua_name("/Identity")

///|
fn pdf_ua_matterhorn_identity() -> PdfName {
  pdf_ua_matterhorn_identity_name
}

///|
let pdf_ua_matterhorn_identity_h_name : PdfName = pdf_ua_name("/Identity-H")

///|
fn pdf_ua_matterhorn_identity_h() -> PdfName {
  pdf_ua_matterhorn_identity_h_name
}

///|
let pdf_ua_matterhorn_identity_v_name : PdfName = pdf_ua_name("/Identity-V")

///|
fn pdf_ua_matterhorn_identity_v() -> PdfName {
  pdf_ua_matterhorn_identity_v_name
}

///|
let pdf_ua_matterhorn_tabs_key_name : PdfName = pdf_ua_name("/Tabs")

///|
fn pdf_ua_matterhorn_tabs_key() -> PdfName {
  pdf_ua_matterhorn_tabs_key_name
}

///|
let pdf_ua_matterhorn_adobe_name : PdfName = pdf_ua_name("/Adobe")

///|
fn pdf_ua_matterhorn_adobe() -> PdfName {
  pdf_ua_matterhorn_adobe_name
}

///|
let pdf_ua_matterhorn_gb1_name : PdfName = pdf_ua_name("/GB1")

///|
let pdf_ua_matterhorn_cns1_name : PdfName = pdf_ua_name("/CNS1")

///|
let pdf_ua_matterhorn_japan1_name : PdfName = pdf_ua_name("/Japan1")

///|
let pdf_ua_matterhorn_korea1_name : PdfName = pdf_ua_name("/Korea1")

///|
let pdf_ua_matterhorn_cmap_names : Array[PdfName] = [
  pdf_ua_name("/GB-EUC-H"),
  pdf_ua_name("/GB-EUC-V"),
  pdf_ua_name("/GBpc-EUC-H"),
  pdf_ua_name("/GBpc-EUC-V"),
  pdf_ua_name("/GBK-EUC-H"),
  pdf_ua_name("/GBK-EUC-V"),
  pdf_ua_name("/GBKp-EUC-H"),
  pdf_ua_name("/GBKp-EUC-V"),
  pdf_ua_name("/GBK2K-H"),
  pdf_ua_name("/GBK2K-V"),
  pdf_ua_name("/UniGB-UCS32-H"),
  pdf_ua_name("/UniGB-UCS32-V"),
  pdf_ua_name("/UniGB-UTF16-H"),
  pdf_ua_name("/UniGB-UTF16-V"),
  pdf_ua_name("/B5pc-H"),
  pdf_ua_name("/B5pc-V"),
  pdf_ua_name("/HKscs-B5-H"),
  pdf_ua_name("/HKscs-B5-V"),
  pdf_ua_name("/ETen-B5-H"),
  pdf_ua_name("/ETen-B5-V"),
  pdf_ua_name("/ETenms-B5-H"),
  pdf_ua_name("/ETenms-B5-V"),
  pdf_ua_name("/CNS-EUC-H"),
  pdf_ua_name("/CNS-EUC-V"),
  pdf_ua_name("/UniCNS-UCS2-H"),
  pdf_ua_name("/UniCNS-UCS2-V"),
  pdf_ua_name("/UniCNS-UTF16-H"),
  pdf_ua_name("/UniCNS-UTF16-V"),
  pdf_ua_name("/83pv-RKSJ-H"),
  pdf_ua_name("/90ms-RKSJ-H"),
  pdf_ua_name("/90ms-RKSJ-V"),
  pdf_ua_name("/90msp-RKSJ-H"),
  pdf_ua_name("/90msp-RKSJ-V"),
  pdf_ua_name("/90pv-RKSJ-H"),
  pdf_ua_name("/Add-RKSJ-H"),
  pdf_ua_name("/Add-RKSJ-V"),
  pdf_ua_name("/EUC-H"),
  pdf_ua_name("/EUC-V"),
  pdf_ua_name("/Ext-RKSJ-H"),
  pdf_ua_name("/Ext-RKSJ-V"),
  pdf_ua_name("/H"),
  pdf_ua_name("/V"),
  pdf_ua_name("/UniJIS-UCS2-H"),
  pdf_ua_name("/UniJIS-UCS2-V"),
  pdf_ua_name("/UniJIS-UCS2-HW-H"),
  pdf_ua_name("/UniJIS-UCS2-HW-V"),
  pdf_ua_name("/UniJIS-UTF16-H"),
  pdf_ua_name("/UniJIS-UTF16-V"),
  pdf_ua_name("/KSC-EUC-H"),
  pdf_ua_name("/KSC-EUC-V"),
  pdf_ua_name("/KSCms-UHC-H"),
  pdf_ua_name("/KSCms-UHC-V"),
  pdf_ua_name("/KSCms-UHC-HW-H"),
  pdf_ua_name("/KSCms-UHS-HW-V"),
  pdf_ua_name("/KSCpc-EUC-H"),
  pdf_ua_name("/UniKS-UCS2-H"),
  pdf_ua_name("/UniKS-UCS2-V"),
  pdf_ua_name("/Identity-H"),
  pdf_ua_name("/Identity-V"),
]

///|
fn pdf_ua_matterhorn_cmap_name_is_listed(name : PdfName) -> Bool {
  pdf_ua_matterhorn_cmap_names.contains(name)
}

///|
let pdf_ua_matterhorn_resources_key_name : PdfName = pdf_ua_name("/Resources")

///|
fn pdf_ua_matterhorn_resources_key() -> PdfName {
  pdf_ua_matterhorn_resources_key_name
}

///|
let pdf_ua_matterhorn_xobject_key_name : PdfName = pdf_ua_name("/XObject")

///|
fn pdf_ua_matterhorn_xobject_key() -> PdfName {
  pdf_ua_matterhorn_xobject_key_name
}

///|
let pdf_ua_matterhorn_ap_key_name : PdfName = pdf_ua_name("/AP")

///|
fn pdf_ua_matterhorn_ap_key() -> PdfName {
  pdf_ua_matterhorn_ap_key_name
}

///|
let pdf_ua_matterhorn_n_key_name : PdfName = pdf_ua_name("/N")

///|
fn pdf_ua_matterhorn_n_key() -> PdfName {
  pdf_ua_matterhorn_n_key_name
}

///|
let pdf_ua_matterhorn_mcid_key_name : PdfName = pdf_ua_name("/MCID")

///|
fn pdf_ua_matterhorn_mcid_key() -> PdfName {
  pdf_ua_matterhorn_mcid_key_name
}

///|
let pdf_ua_matterhorn_suspects_key_name : PdfName = pdf_ua_name("/Suspects")

///|
fn pdf_ua_matterhorn_suspects_key() -> PdfName {
  pdf_ua_matterhorn_suspects_key_name
}

///|
let pdf_ua_matterhorn_ref_key_name : PdfName = pdf_ua_name("/Ref")

///|
fn pdf_ua_matterhorn_ref_key() -> PdfName {
  pdf_ua_matterhorn_ref_key_name
}

///|
let pdf_ua_matterhorn_ct_key_name : PdfName = pdf_ua_name("/CT")

///|
fn pdf_ua_matterhorn_ct_key() -> PdfName {
  pdf_ua_matterhorn_ct_key_name
}

///|
let pdf_ua_matterhorn_alt_key_name : PdfName = pdf_ua_name("/Alt")

///|
fn pdf_ua_matterhorn_alt_key() -> PdfName {
  pdf_ua_matterhorn_alt_key_name
}

///|
let pdf_ua_matterhorn_encoding_key_name : PdfName = pdf_ua_name("/Encoding")

///|
fn pdf_ua_matterhorn_encoding_key() -> PdfName {
  pdf_ua_matterhorn_encoding_key_name
}

///|
let pdf_ua_matterhorn_cid_to_gid_map_key_name : PdfName = pdf_ua_name(
  "/CIDToGIDMap",
)

///|
fn pdf_ua_matterhorn_cid_to_gid_map_key() -> PdfName {
  pdf_ua_matterhorn_cid_to_gid_map_key_name
}

///|
let pdf_ua_matterhorn_usecmap_key_name : PdfName = pdf_ua_name("/UseCMap")

///|
fn pdf_ua_matterhorn_usecmap_key() -> PdfName {
  pdf_ua_matterhorn_usecmap_key_name
}

///|
let pdf_ua_matterhorn_wmode_key_name : PdfName = pdf_ua_name("/WMode")

///|
fn pdf_ua_matterhorn_wmode_key() -> PdfName {
  pdf_ua_matterhorn_wmode_key_name
}

///|
let pdf_ua_matterhorn_descendant_fonts_key_name : PdfName = pdf_ua_name(
  "/DescendantFonts",
)

///|
fn pdf_ua_matterhorn_descendant_fonts_key() -> PdfName {
  pdf_ua_matterhorn_descendant_fonts_key_name
}

///|
let pdf_ua_matterhorn_cid_system_info_key_name : PdfName = pdf_ua_name(
  "/CIDSystemInfo",
)

///|
fn pdf_ua_matterhorn_cid_system_info_key() -> PdfName {
  pdf_ua_matterhorn_cid_system_info_key_name
}

///|
let pdf_ua_matterhorn_registry_key_name : PdfName = pdf_ua_name("/Registry")

///|
fn pdf_ua_matterhorn_registry_key() -> PdfName {
  pdf_ua_matterhorn_registry_key_name
}

///|
let pdf_ua_matterhorn_ordering_key_name : PdfName = pdf_ua_name("/Ordering")

///|
fn pdf_ua_matterhorn_ordering_key() -> PdfName {
  pdf_ua_matterhorn_ordering_key_name
}

///|
let pdf_ua_matterhorn_struct_parent_key_name : PdfName = pdf_ua_name(
  "/StructParent",
)

///|
fn pdf_ua_matterhorn_struct_parent_key() -> PdfName {
  pdf_ua_matterhorn_struct_parent_key_name
}

///|
let pdf_ua_matterhorn_media_clip_name : PdfName = pdf_ua_name("/MediaClip")

///|
fn pdf_ua_matterhorn_media_clip() -> PdfName {
  pdf_ua_matterhorn_media_clip_name
}

///|
let pdf_ua_matterhorn_mcd_name : PdfName = pdf_ua_name("/MCD")

///|
fn pdf_ua_matterhorn_mcd() -> PdfName {
  pdf_ua_matterhorn_mcd_name
}

///|
let pdf_ua_matterhorn_printer_mark_name : PdfName = pdf_ua_name("/PrinterMark")

///|
fn pdf_ua_matterhorn_printer_mark() -> PdfName {
  pdf_ua_matterhorn_printer_mark_name
}

///|
fn pdf_ua_matterhorn_test_01_003() -> PdfUAMatterhornTest {
  {
    name: "01-003",
    error: "Content marked as Artifact is present inside tagged content.",
    section: "UA1:7.1-1",
  }
}

///|
fn pdf_ua_matterhorn_test_01_004() -> PdfUAMatterhornTest {
  {
    name: "01-004",
    error: "Tagged content is present inside content marked as Artifact.",
    section: "UA1:7.1-1",
  }
}

///|
fn pdf_ua_matterhorn_test_01_005() -> PdfUAMatterhornTest {
  {
    name: "01-005",
    error: "Content is neither marked as Artifact nor tagged as real content.",
    section: "UA1:7-1-2",
  }
}

///|
fn pdf_ua_matterhorn_test_01_007() -> PdfUAMatterhornTest {
  {
    name: "01-007",
    error: "Suspects entry has a value of true.",
    section: "UA1:7-1-11",
  }
}

///|
fn pdf_ua_matterhorn_test_02_001() -> PdfUAMatterhornTest {
  {
    name: "02-001",
    error: "One or more non-standard tag’s mapping does not terminate with a standard type.",
    section: "UA1:7.1-3",
  }
}

///|
fn pdf_ua_matterhorn_test_02_003() -> PdfUAMatterhornTest {
  { name: "02-003", error: "A circular mapping exists.", section: "UA1:7.1-3" }
}

///|
fn pdf_ua_matterhorn_test_02_004() -> PdfUAMatterhornTest {
  {
    name: "02-004",
    error: "One or more standard types are remapped.",
    section: "UA1:7.1-4",
  }
}

///|
fn pdf_ua_matterhorn_test_06_001() -> PdfUAMatterhornTest {
  {
    name: "06-001",
    error: "Document does not contain an XMP metadata stream",
    section: "UA1:7.1-8",
  }
}

///|
fn pdf_ua_matterhorn_test_06_002() -> PdfUAMatterhornTest {
  {
    name: "06-002",
    error: "The XMP metadata stream in the Catalog dictionary does not include the PDF/UA identifier.",
    section: "UA1:5",
  }
}

///|
fn pdf_ua_matterhorn_test_06_003() -> PdfUAMatterhornTest {
  {
    name: "06-003",
    error: "XMP metadata stream does not contain dc:title",
    section: "UA1:7.1-8",
  }
}

///|
fn pdf_ua_matterhorn_test_07_001() -> PdfUAMatterhornTest {
  {
    name: "07-001",
    error: "ViewerPreferences dictionary of the Catalog dictionary does not contain a DisplayDocTitle entry",
    section: "UA1:7.1-9",
  }
}

///|
fn pdf_ua_matterhorn_test_07_002() -> PdfUAMatterhornTest {
  {
    name: "07-002",
    error: "ViewerPreferences dictionary of the Catalog dictionary contains a DisplayDocTitle entry with a value of false",
    section: "UA1:7.1-9",
  }
}

///|
fn pdf_ua_matterhorn_test_11_001() -> PdfUAMatterhornTest {
  {
    name: "11-001",
    error: "Natural language for text in page content cannot be determined.",
    section: "UA1:7.2-3",
  }
}

///|
fn pdf_ua_matterhorn_test_11_002() -> PdfUAMatterhornTest {
  {
    name: "11-002",
    error: "Natural language for text in Alt, ActualText and E attributes cannot be determined.",
    section: "UA1:7.2-3",
  }
}

///|
fn pdf_ua_matterhorn_test_11_003() -> PdfUAMatterhornTest {
  {
    name: "11-003",
    error: "Natural language in the Outline entries cannot be determined.",
    section: "UA1:7.2-3",
  }
}

///|
fn pdf_ua_matterhorn_test_11_004() -> PdfUAMatterhornTest {
  {
    name: "11-004",
    error: "Natural language in the Contents entry for annotations cannot be determined.",
    section: "UA1:7.2-3",
  }
}

///|
fn pdf_ua_matterhorn_test_11_005() -> PdfUAMatterhornTest {
  {
    name: "11-005",
    error: "Natural language in the TU entry for form fields cannot be determined.",
    section: "UA1:7.2-3",
  }
}

///|
fn pdf_ua_matterhorn_test_11_006() -> PdfUAMatterhornTest {
  {
    name: "11-006",
    error: "Natural language for document metadata cannot be determined.",
    section: "UA1:7.2-3",
  }
}

///|
fn pdf_ua_matterhorn_test_20_001() -> PdfUAMatterhornTest {
  {
    name: "20-001",
    error: "Name entry is missing or has an empty string as its value in an Optional Content Configuration Dictionary in the Configs entry in the OCProperties entry in the Catalog dictionary.",
    section: "UA1:7.10-1",
  }
}

///|
fn pdf_ua_matterhorn_test_20_002() -> PdfUAMatterhornTest {
  {
    name: "20-002",
    error: "Name entry is missing or has an empty string as its value in an Optional Content Configuration Dictionary that is the value of the D entry in the OCProperties entry in the Catalog dictionary.",
    section: "UA1:7.10-1",
  }
}

///|
fn pdf_ua_matterhorn_test_20_003() -> PdfUAMatterhornTest {
  {
    name: "20-003",
    error: "An AS entry appears in an Optional Content Configuration Dictionary.",
    section: "UA1:7.10-2",
  }
}

///|
fn pdf_ua_matterhorn_test_21_001() -> PdfUAMatterhornTest {
  {
    name: "21-001",
    error: "The file specification dictionary for an embedded file does not contain F and UF entries.",
    section: "UA1:7.11-1",
  }
}

///|
fn pdf_ua_matterhorn_test_25_001() -> PdfUAMatterhornTest {
  {
    name: "25-001",
    error: "File contains the dynamicRender element with value “required”.",
    section: "UA1:7.15-1",
  }
}

///|
fn pdf_ua_matterhorn_test_26_001() -> PdfUAMatterhornTest {
  {
    name: "26-001",
    error: "The file is encrypted but does not contain a P entry in its encryption dictionary.",
    section: "UA1:7.16-1",
  }
}

///|
fn pdf_ua_matterhorn_test_26_002() -> PdfUAMatterhornTest {
  {
    name: "26-002",
    error: "The file is encrypted and does contain a P entry but the 10th bit position of the P entry is false.",
    section: "UA1:7.16-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_002() -> PdfUAMatterhornTest {
  {
    name: "28-002",
    error: "An annotation, other than of subtype Widget, Link and PrinterMark, is not a direct child of an <Annot> structure element.",
    section: "UA1:7.18.1-2",
  }
}

///|
fn pdf_ua_matterhorn_test_28_004() -> PdfUAMatterhornTest {
  {
    name: "28-004",
    error: "An annotation, other than of subtype Widget, does not have a Contents entry and does not have an alternative description (in the form of an Alt entry in the enclosing structure element).",
    section: "UA1:7.18.1-4",
  }
}

///|
fn pdf_ua_matterhorn_test_28_005() -> PdfUAMatterhornTest {
  {
    name: "28-005",
    error: "A form field does not have a TU entry and does not have an alternative description (in the form of an Alt entry in the enclosing structure element).",
    section: "UA1:7.18.1-4",
  }
}

///|
fn pdf_ua_matterhorn_test_28_006() -> PdfUAMatterhornTest {
  {
    name: "28-006",
    error: "An annotation with subtype undefined in ISO 32000 does not meet 7.18.1.",
    section: "UA1:7.18.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_007() -> PdfUAMatterhornTest {
  {
    name: "28-007",
    error: "An annotation of subtype TrapNet exists.",
    section: "UA1:7.18.2-2",
  }
}

///|
fn pdf_ua_matterhorn_test_28_008() -> PdfUAMatterhornTest {
  {
    name: "28-008",
    error: "A page containing an annotation does not contain a Tabs entry",
    section: "UA1:7.18.3-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_009() -> PdfUAMatterhornTest {
  {
    name: "28-009",
    error: "A page containing an annotation has a Tabs entry with a value other than S.",
    section: "UA1:7.18.3-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_010() -> PdfUAMatterhornTest {
  {
    name: "28-010",
    error: "A widget annotation is not nested within a <Form> tag.",
    section: "UA1:7.18.4-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_011() -> PdfUAMatterhornTest {
  {
    name: "28-011",
    error: "A link annotation is not nested within a <Link> tag.",
    section: "UA1:7.18.5-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_012() -> PdfUAMatterhornTest {
  {
    name: "28-012",
    error: "A link annotation does not include an alternate description in its Contents entry.",
    section: "UA1:7.18.5-2",
  }
}

///|
fn pdf_ua_matterhorn_test_28_014() -> PdfUAMatterhornTest {
  {
    name: "28-014",
    error: "CT entry is missing from the media clip data dictionary.",
    section: "",
  }
}

///|
fn pdf_ua_matterhorn_test_28_015() -> PdfUAMatterhornTest {
  {
    name: "28-015",
    error: "Alt entry is missing from the media clip data dictionary.",
    section: "UA1:7.18.6.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_016() -> PdfUAMatterhornTest {
  {
    name: "28-016",
    error: "File attachment annotations do not conform to 7.11.",
    section: "UA1:7.18.7-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_017() -> PdfUAMatterhornTest {
  {
    name: "28-017",
    error: "A PrinterMark annotation is included in the logical structure.",
    section: "UA1:7.18.8-1",
  }
}

///|
fn pdf_ua_matterhorn_test_28_018() -> PdfUAMatterhornTest {
  {
    name: "28-018",
    error: "The appearance stream of a PrinterMark annotation is not marked as Artifact.",
    section: "UA1:7.18.8-2",
  }
}

///|
fn pdf_ua_matterhorn_test_30_001() -> PdfUAMatterhornTest {
  {
    name: "30-001",
    error: "A reference XObject is present.",
    section: "UA1:7.2",
  }
}

///|
fn pdf_ua_matterhorn_test_30_002() -> PdfUAMatterhornTest {
  {
    name: "30-002",
    error: "Form XObject contains MCIDs and is referenced more than once.",
    section: "UA1:7.21.3.1-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_001() -> PdfUAMatterhornTest {
  {
    name: "31-001",
    error: "A Type 0 font dictionary with encoding other than Identity-H and Identity-V has values for Registry in both CIDSystemInfo dictionaries that are not identical.",
    section: "UA1:7.21.3-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_002() -> PdfUAMatterhornTest {
  {
    name: "31-002",
    error: "A Type 0 font dictionary with encoding other than Identity-H and Identity-V has values for Ordering in both CIDSystemInfo dictionaries that are not identical.",
    section: "UA1:7.21.3.1-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_003() -> PdfUAMatterhornTest {
  {
    name: "31-003",
    error: "A Type 0 font dictionary with encoding other than Identity-H and Identity-V has a value for Supplement in the CIDSystemInfo dictionary of the CID font that is less than the value for Supplement in the CIDSystemInfo dictionary of the CMap.",
    section: "UA1:7.21.3.1-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_004() -> PdfUAMatterhornTest {
  {
    name: "31-004",
    error: "A Type 2 CID font contains neither a stream nor the name Identity as the value of the CIDToGIDMap entry.",
    section: "UA1:7.21.3.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_005() -> PdfUAMatterhornTest {
  {
    name: "31-005",
    error: "A Type 2 CID font does not contain a CIDToGIDMap entry.",
    section: "UA1:7.21.3.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_006() -> PdfUAMatterhornTest {
  {
    name: "31-006",
    error: "A CMap is neither listed as described in ISO 32000- 1:2008, 9.7.5.2, Table 118 nor is it embedded.",
    section: "UA1:7.21.3.3-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_007() -> PdfUAMatterhornTest {
  {
    name: "31-007",
    error: "The WMode entry in a CMap dictionary is not identical to the WMode value in the CMap stream.",
    section: "UA1:7.21.3.3-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_008() -> PdfUAMatterhornTest {
  {
    name: "31-008",
    error: "A CMap references another CMap which is not listed in ISO 32000-1:2008, 9.7.5.2, Table 118.",
    section: "UA1:7.21.3.3-2",
  }
}

///|
fn pdf_ua_matterhorn_test_31_009() -> PdfUAMatterhornTest {
  {
    name: "31-009",
    error: "For a font used by text intended to be rendered the font program is not embedded.",
    section: "UA1:7.21.4.1-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_011() -> PdfUAMatterhornTest {
  {
    name: "31-011",
    error: "For a font used by text the font program is embedded but it does not contain glyphs for all of the glyphs referenced by the text used for rendering.",
    section: "UA1:7.21.4.1-3",
  }
}

///|
fn pdf_ua_matterhorn_test_31_012() -> PdfUAMatterhornTest {
  {
    name: "31-012",
    error: "The FontDescriptor dictionary of an embedded Type 1 font contains a CharSet string, but at least one of the glyphs present in the font program is not listed in the CharSet string.",
    section: "UA1:7.21.4.2-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_013() -> PdfUAMatterhornTest {
  {
    name: "31-013",
    error: "The FontDescriptor dictionary of an embedded Type 1 font contains a CharSet string, but at least one of the glyphs listed in the CharSet string is not present in the font program.",
    section: "UA1:7.21.4.2-2",
  }
}

///|
fn pdf_ua_matterhorn_test_31_014() -> PdfUAMatterhornTest {
  {
    name: "31-014",
    error: "The FontDescriptor dictionary of an embedded CID font contains a CIDSet string, but at least one of the glyphs present in the font program is not listed in the CIDSet string.",
    section: "UA1:7.21.4.2-3",
  }
}

///|
fn pdf_ua_matterhorn_test_31_015() -> PdfUAMatterhornTest {
  {
    name: "31-015",
    error: "The FontDescriptor dictionary of an embedded CID font contains a CIDSet string, but at least one of the glyphs listed in the CIDSet string is not present in the font program.",
    section: "UA1:7.21.4.2-4",
  }
}

///|
fn pdf_ua_matterhorn_test_31_016() -> PdfUAMatterhornTest {
  {
    name: "31-016",
    error: "For one or more glyphs, the glyph width information in the font dictionary and in the embedded font program differ by more than 1/1000 unit.",
    section: "UA1:7.21.5-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_017() -> PdfUAMatterhornTest {
  {
    name: "31-017",
    error: "A non-symbolic TrueType font is used for rendering, but none of the cmap entries in the embedded font program is a non-symbolic cmap.",
    section: "UA1:7.21.6-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_018() -> PdfUAMatterhornTest {
  {
    name: "31-018",
    error: "A non-symbolic TrueType font is used for rendering, but for at least one glyph to be rendered the glyph cannot be looked up by any of the non-symbolic cmap entries in the embedded font program.",
    section: "UA1:7.21.6-2",
  }
}

///|
fn pdf_ua_matterhorn_test_31_019() -> PdfUAMatterhornTest {
  {
    name: "31-019",
    error: "The font dictionary for a non-symbolic TrueType font does not contain an Encoding entry.",
    section: "UA1:7.21.6-3",
  }
}

///|
fn pdf_ua_matterhorn_test_31_020() -> PdfUAMatterhornTest {
  {
    name: "31-020",
    error: "The font dictionary for a non-symbolic TrueType font contains an Encoding dictionary which does not contain a BaseEncoding entry.",
    section: "UA1:7.21.6-4",
  }
}

///|
fn pdf_ua_matterhorn_test_31_021() -> PdfUAMatterhornTest {
  {
    name: "31-021",
    error: "The value for either the Encoding entry or the BaseEncoding entry in the Encoding dictionary in a non-symbolic TrueType font dictionary is neither MacRomanEncoding nor WinAnsiEncoding.",
    section: "UA1:7.21.6-5",
  }
}

///|
fn pdf_ua_matterhorn_test_31_022() -> PdfUAMatterhornTest {
  {
    name: "31-022",
    error: "The Differences array in the Encoding entry in a non-symbolic TrueType font dictionary contains one or more glyph names which are not listed in the Adobe Glyph List.",
    section: "UA1:7.21.6-6",
  }
}

///|
fn pdf_ua_matterhorn_test_31_023() -> PdfUAMatterhornTest {
  {
    name: "31-023",
    error: "The Differences array is present in the Encoding entry in a non-symbolic TrueType font dictionary but the embedded font program does not contain a (3,1) Microsoft Unicode cmap.",
    section: "UA1:7.21.6-7",
  }
}

///|
fn pdf_ua_matterhorn_test_31_024() -> PdfUAMatterhornTest {
  {
    name: "31-024",
    error: "The Encoding entry is present in the font dictionary for a symbolic TrueType font.",
    section: "UA1:7.21.6-8",
  }
}

///|
fn pdf_ua_matterhorn_test_31_025() -> PdfUAMatterhornTest {
  {
    name: "31-025",
    error: "The embedded font program for a symbolic TrueType font contains no cmap.",
    section: "UA1:7.21.6-9",
  }
}

///|
fn pdf_ua_matterhorn_test_31_026() -> PdfUAMatterhornTest {
  {
    name: "31-026",
    error: "The embedded font program for a symbolic TrueType font contains more than one cmap, but none of the cmap entries is a (3,0) Microsoft Symbol cmap.",
    section: "UA1:7.21.6-10",
  }
}

///|
fn pdf_ua_matterhorn_test_31_027() -> PdfUAMatterhornTest {
  {
    name: "31-027",
    error: "A font dictionary does not contain the ToUnicode entry and none of the following is true: the font uses MacRomanEncoding, MacExpertEncoding or WinAnsiEncoding; the font is a Type 1 or Type 3 font and the glyph names of the glyphs referenced are all contained in the Adobe Glyph List or the set of named characters in the Symbol font, as defined in ISO 32000-1:2008, Annex D; the font is a Type 0 font, and its descendant CIDFont uses Adobe-GB1, Adobe-CNS1, Adobe-Japan1 or Adobe-Korea1 character collections; the font is a non-symbolic TrueType font.",
    section: "UA1:7.21.7-1",
  }
}

///|
fn pdf_ua_matterhorn_test_31_028() -> PdfUAMatterhornTest {
  {
    name: "31-028",
    error: "One or more Unicode values specified in the ToUnicode CMap are zero (0).",
    section: "UA1:7.21.7-2",
  }
}

///|
fn pdf_ua_matterhorn_test_31_029() -> PdfUAMatterhornTest {
  {
    name: "31-029",
    error: "One or more Unicode values specified in the ToUnicode CMap are equal to either U+FEFF or U+FFFE.",
    section: "UA1:7.21.7-3",
  }
}

///|
fn pdf_ua_matterhorn_test_31_030() -> PdfUAMatterhornTest {
  {
    name: "31-030",
    error: "One or more characters used in text showing operators reference the .notdef glyph.",
    section: "UA1:7.21.8-1",
  }
}

///|
fn pdf_ua_matterhorn_implemented_tests() -> Array[PdfUAMatterhornTest] {
  [
    pdf_ua_matterhorn_test_01_003(),
    pdf_ua_matterhorn_test_01_004(),
    pdf_ua_matterhorn_test_01_005(),
    pdf_ua_matterhorn_test_01_007(),
    pdf_ua_matterhorn_test_02_001(),
    pdf_ua_matterhorn_test_02_003(),
    pdf_ua_matterhorn_test_02_004(),
    pdf_ua_matterhorn_test_06_001(),
    pdf_ua_matterhorn_test_06_002(),
    pdf_ua_matterhorn_test_06_003(),
    pdf_ua_matterhorn_test_07_001(),
    pdf_ua_matterhorn_test_07_002(),
    pdf_ua_matterhorn_test_11_001(),
    pdf_ua_matterhorn_test_11_002(),
    pdf_ua_matterhorn_test_11_003(),
    pdf_ua_matterhorn_test_11_004(),
    pdf_ua_matterhorn_test_11_005(),
    pdf_ua_matterhorn_test_11_006(),
    pdf_ua_matterhorn_test_20_001(),
    pdf_ua_matterhorn_test_20_002(),
    pdf_ua_matterhorn_test_20_003(),
    pdf_ua_matterhorn_test_21_001(),
    pdf_ua_matterhorn_test_25_001(),
    pdf_ua_matterhorn_test_26_001(),
    pdf_ua_matterhorn_test_26_002(),
    pdf_ua_matterhorn_test_28_002(),
    pdf_ua_matterhorn_test_28_004(),
    pdf_ua_matterhorn_test_28_005(),
    pdf_ua_matterhorn_test_28_006(),
    pdf_ua_matterhorn_test_28_007(),
    pdf_ua_matterhorn_test_28_008(),
    pdf_ua_matterhorn_test_28_009(),
    pdf_ua_matterhorn_test_28_010(),
    pdf_ua_matterhorn_test_28_011(),
    pdf_ua_matterhorn_test_28_012(),
    pdf_ua_matterhorn_test_28_014(),
    pdf_ua_matterhorn_test_28_015(),
    pdf_ua_matterhorn_test_28_016(),
    pdf_ua_matterhorn_test_28_017(),
    pdf_ua_matterhorn_test_28_018(),
    pdf_ua_matterhorn_test_30_001(),
    pdf_ua_matterhorn_test_30_002(),
    pdf_ua_matterhorn_test_31_001(),
    pdf_ua_matterhorn_test_31_002(),
    pdf_ua_matterhorn_test_31_003(),
    pdf_ua_matterhorn_test_31_004(),
    pdf_ua_matterhorn_test_31_005(),
    pdf_ua_matterhorn_test_31_006(),
    pdf_ua_matterhorn_test_31_007(),
    pdf_ua_matterhorn_test_31_008(),
    pdf_ua_matterhorn_test_31_009(),
    pdf_ua_matterhorn_test_31_011(),
    pdf_ua_matterhorn_test_31_012(),
    pdf_ua_matterhorn_test_31_013(),
    pdf_ua_matterhorn_test_31_014(),
    pdf_ua_matterhorn_test_31_015(),
    pdf_ua_matterhorn_test_31_016(),
    pdf_ua_matterhorn_test_31_017(),
    pdf_ua_matterhorn_test_31_018(),
    pdf_ua_matterhorn_test_31_019(),
    pdf_ua_matterhorn_test_31_020(),
    pdf_ua_matterhorn_test_31_021(),
    pdf_ua_matterhorn_test_31_022(),
    pdf_ua_matterhorn_test_31_023(),
    pdf_ua_matterhorn_test_31_024(),
    pdf_ua_matterhorn_test_31_025(),
    pdf_ua_matterhorn_test_31_026(),
    pdf_ua_matterhorn_test_31_027(),
    pdf_ua_matterhorn_test_31_028(),
    pdf_ua_matterhorn_test_31_029(),
    pdf_ua_matterhorn_test_31_030(),
  ]
}

///|
fn pdf_ua_matterhorn_failure(
  check : PdfUAMatterhornTest,
  extra? : Json = Json::null(),
) -> PdfUAMatterhornFailure {
  { name: check.name, error: check.error, section: check.section, extra }
}

///|
fn PdfUAMatterhornFailure::to_json(self : PdfUAMatterhornFailure) -> Json {
  Json::object(
    Map::of([
      ("name", Json::string(self.name)),
      ("section", Json::string(self.section)),
      ("error", Json::string(self.error)),
      ("extra", self.extra),
    ]),
  )
}

///|
fn pdf_ua_matterhorn_is_form_stream(
  document : PdfDocument,
  object : PdfObject,
) -> Bool {
  match document.lookup_direct(pdf_ua_subtype_key(), object) {
    Some(PdfNameObject(subtype)) => subtype == pdf_ua_matterhorn_form()
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_stream_resources(
  self : PdfDocument,
  stream : PdfObject,
) -> PdfObject {
  match self.lookup_direct(pdf_ua_matterhorn_resources_key(), stream) {
    Some(resources) => resources
    None => PdfDictionary([])
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_all_ops(
  self : PdfDocument,
  xobjects? : Bool = true,
) -> Array[Array[PdfContentOp]] raise PdfError {
  let output : Array[Array[PdfContentOp]] = []
  if xobjects {
    for entry in self.stream_object_entries() {
      let stream = PdfStreamObject(entry.2)
      if pdf_ua_matterhorn_is_form_stream(self, stream) {
        let resources = self.pdf_ua_matterhorn_stream_resources(stream)
        output.push(self.parse_content_ops_with_resources(resources, [stream]))
      }
    }
  }
  for page in self.pages_of_pagetree() {
    output.push(
      self.parse_content_ops_with_resources(page.resources, page.content),
    )
  }
  output
}

///|
fn pdf_ua_matterhorn_artifact_in_content_ops(
  ops : ArrayView[PdfContentOp],
) -> Bool {
  let mut in_content = false
  let mut in_artifact = false
  for op in ops {
    match op {
      Op_BDC(_, _) => in_content = true
      Op_BMC(name) if name == pdf_ua_matterhorn_artifact() =>
        if in_content {
          return true
        } else {
          in_artifact = true
        }
      Op_EMC =>
        if in_content && in_artifact {
          return true
        } else if in_content {
          in_content = false
        } else {
          in_artifact = false
        }
      _ => ()
    }
  }
  false
}

///|
fn pdf_ua_matterhorn_content_in_artifact_ops(
  ops : ArrayView[PdfContentOp],
) -> Bool {
  let mut in_content = false
  let mut in_artifact = false
  for op in ops {
    match op {
      Op_BDC(_, _) => if in_artifact { return true } else { in_content = true }
      Op_BMC(name) if name == pdf_ua_matterhorn_artifact() => in_artifact = true
      Op_EMC =>
        if in_content && in_artifact {
          return true
        } else if in_content {
          in_content = false
        } else {
          in_artifact = false
        }
      _ => ()
    }
  }
  false
}

///|
fn pdf_ua_matterhorn_real_op(op : PdfContentOp) -> Bool {
  match op {
    Op_m(_, _)
    | Op_l(_, _)
    | Op_c(_, _, _, _, _, _)
    | Op_v(_, _, _, _)
    | Op_y(_, _, _, _)
    | Op_h
    | Op_re(_, _, _, _)
    | Op_S
    | Op_s
    | Op_f
    | Op_F
    | Op_fstar
    | Op_B
    | Op_Bstar
    | Op_b
    | Op_bstar
    | Op_W
    | Op_Wstar
    | Op_Tj(_)
    | Op_TJ(_)
    | Op_quote(_)
    | Op_double_quote(_, _, _)
    | Op_sh(_)
    | Op_InlineImage(_, _, _)
    | Op_Do(_) => true
    _ => false
  }
}

///|
fn pdf_ua_matterhorn_path_construction_op(op : PdfContentOp) -> Bool {
  match op {
    Op_m(_, _)
    | Op_l(_, _)
    | Op_c(_, _, _, _, _, _)
    | Op_v(_, _, _, _)
    | Op_y(_, _, _, _)
    | Op_h
    | Op_re(_, _, _, _) => true
    _ => false
  }
}

///|
fn pdf_ua_matterhorn_bdc_context(
  tag : PdfName,
  properties : PdfObject,
) -> PdfUAMatterhornContext {
  match properties {
    PdfDictionary(_) if properties.lookup_immediate(
        pdf_ua_matterhorn_mcid_key(),
      )
      is Some(_) => PdfUAMatterhornContent
    _ =>
      if tag == pdf_ua_matterhorn_artifact() {
        PdfUAMatterhornArtifact
      } else {
        PdfUAMatterhornOther
      }
  }
}

///|
fn pdf_ua_matterhorn_bmc_context(tag : PdfName) -> PdfUAMatterhornContext {
  if tag == pdf_ua_matterhorn_span() || tag == pdf_ua_matterhorn_artifact() {
    PdfUAMatterhornArtifact
  } else {
    PdfUAMatterhornOther
  }
}

///|
fn pdf_ua_matterhorn_stack_has_marking(
  stack : ArrayView[PdfUAMatterhornContext],
) -> Bool {
  for context in stack {
    match context {
      PdfUAMatterhornArtifact | PdfUAMatterhornContent => return true
      PdfUAMatterhornOther => ()
    }
  }
  false
}

///|
fn pdf_ua_matterhorn_naked_ops(
  ops : ArrayView[PdfContentOp],
) -> (Array[PdfContentOp], Json?) {
  let naked : Array[PdfContentOp] = []
  let stack : Array[PdfUAMatterhornContext] = []
  for op in ops {
    match op {
      Op_BDC(tag, properties) =>
        stack.push(pdf_ua_matterhorn_bdc_context(tag, properties))
      Op_BMC(tag) => stack.push(pdf_ua_matterhorn_bmc_context(tag))
      Op_EMC =>
        if stack.length() == 0 {
          return ([], Some(Json::string("empty stack")))
        } else {
          ignore(stack.pop())
        }
      _ =>
        if !pdf_ua_matterhorn_stack_has_marking(stack) &&
          pdf_ua_matterhorn_real_op(op) {
          naked.push(op)
        }
    }
  }
  (naked, None)
}

///|
fn pdf_ua_matterhorn_unfiltered_real_op(
  naked : ArrayView[PdfContentOp],
) -> Bool {
  let reversed = naked.rev()
  let mut index = 0
  while index < reversed.length() {
    match reversed[index] {
      Op_W | Op_Wstar => {
        index += 1
        while index < reversed.length() &&
              pdf_ua_matterhorn_path_construction_op(reversed[index]) {
          index += 1
        }
      }
      op => {
        if pdf_ua_matterhorn_real_op(op) {
          return true
        }
        index += 1
      }
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_01_003(
  self : PdfDocument,
) -> Json? raise PdfError {
  for ops in self.pdf_ua_matterhorn_all_ops() {
    if pdf_ua_matterhorn_artifact_in_content_ops(ops) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_01_004(
  self : PdfDocument,
) -> Json? raise PdfError {
  for ops in self.pdf_ua_matterhorn_all_ops() {
    if pdf_ua_matterhorn_content_in_artifact_ops(ops) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_01_005(
  self : PdfDocument,
) -> Json? raise PdfError {
  for ops in self.pdf_ua_matterhorn_all_ops(xobjects=false) {
    let (naked, error) = pdf_ua_matterhorn_naked_ops(ops)
    match error {
      Some(extra) => return Some(extra)
      None =>
        if pdf_ua_matterhorn_unfiltered_real_op(naked) {
          return Some(Json::null())
        }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_01_007(self : PdfDocument) -> Json? {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_ua_root_key(),
      pdf_ua_markinfo_key(),
      pdf_ua_matterhorn_suspects_key(),
    ]) {
    Some(PdfBoolean(true)) => Some(Json::null())
    _ => None
  }
}

///|
fn pdf_ua_matterhorn_name_text(name : PdfName) -> String {
  @ascii.decode_lossy(name.bytes())
}

///|
fn pdf_ua_matterhorn_standard_structure_types_2008() -> Array[PdfName] {
  [
    pdf_ua_name("/Document"),
    pdf_ua_name("/Part"),
    pdf_ua_name("/Sect"),
    pdf_ua_name("/Div"),
    pdf_ua_name("/NonStruct"),
    pdf_ua_name("/P"),
    pdf_ua_name("/H1"),
    pdf_ua_name("/H2"),
    pdf_ua_name("/H3"),
    pdf_ua_name("/H4"),
    pdf_ua_name("/H5"),
    pdf_ua_name("/H6"),
    pdf_ua_name("/H"),
    pdf_ua_name("/Lbl"),
    pdf_ua_name("/Span"),
    pdf_ua_name("/Link"),
    pdf_ua_name("/Annot"),
    pdf_ua_name("/Form"),
    pdf_ua_name("/Ruby"),
    pdf_ua_name("/RB"),
    pdf_ua_name("/RT"),
    pdf_ua_name("/RP"),
    pdf_ua_name("/Warichu"),
    pdf_ua_name("/WT"),
    pdf_ua_name("/WP"),
    pdf_ua_name("/L"),
    pdf_ua_name("/LI"),
    pdf_ua_name("/LBody"),
    pdf_ua_name("/Table"),
    pdf_ua_name("/TR"),
    pdf_ua_name("/TH"),
    pdf_ua_name("/TD"),
    pdf_ua_name("/THead"),
    pdf_ua_name("/TBody"),
    pdf_ua_name("/TFoot"),
    pdf_ua_name("/Caption"),
    pdf_ua_name("/Figure"),
    pdf_ua_name("/Formula"),
    pdf_ua_name("/Art"),
    pdf_ua_name("/BlockQuote"),
    pdf_ua_name("/TOC"),
    pdf_ua_name("/TOCI"),
    pdf_ua_name("/Index"),
    pdf_ua_name("/Private"),
    pdf_ua_name("/Quote"),
    pdf_ua_name("/Note"),
    pdf_ua_name("/Reference"),
    pdf_ua_name("/Code"),
    pdf_ua_name("/BibEntry"),
  ]
}

///|
fn pdf_ua_matterhorn_standard_structure_type(name : PdfName) -> Bool {
  pdf_ua_matterhorn_standard_structure_types_2008().contains(name)
}

///|
fn PdfUAStructTreeRoleMap::pdf_ua_matterhorn_role_is_circular(
  self : PdfUAStructTreeRoleMap,
  name : PdfName,
) -> Bool {
  let mut current = name
  let mut remaining = self.entries.length()
  while true {
    if remaining < 0 {
      return true
    }
    match self.mapped(current) {
      Some(next) => {
        current = next
        remaining -= 1
      }
      None => return false
    }
  }
  false
}

///|
fn PdfUAStructTreeRoleMap::pdf_ua_matterhorn_has_circular_mapping(
  self : PdfUAStructTreeRoleMap,
) -> Bool {
  for entry in self.entries {
    if self.pdf_ua_matterhorn_role_is_circular(entry.0) {
      return true
    }
  }
  false
}

///|
fn PdfUAStructTreeRoleMap::pdf_ua_matterhorn_role_terminates_at_standard(
  self : PdfUAStructTreeRoleMap,
  name : PdfName,
) -> Bool {
  let mut current = name
  let mut remaining = self.entries.length()
  while remaining >= 0 {
    match self.mapped(current) {
      Some(next) =>
        if pdf_ua_matterhorn_standard_structure_type(next) {
          return true
        } else {
          current = next
          remaining -= 1
        }
      None => return false
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_rolemap(
  self : PdfDocument,
) -> PdfUAStructTreeRoleMap {
  self.pdf_ua_struct_tree_rolemap()
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_02_001(self : PdfDocument) -> Json? {
  let rolemap = self.pdf_ua_matterhorn_rolemap()
  if rolemap.pdf_ua_matterhorn_has_circular_mapping() {
    None
  } else {
    for entry in rolemap.entries {
      if !rolemap.pdf_ua_matterhorn_role_terminates_at_standard(entry.0) {
        return Some(Json::string(pdf_ua_matterhorn_name_text(entry.0)))
      }
    }
    None
  }
}

///|
fn pdf_ua_matterhorn_circular_rolemap_extra() -> Json {
  Json::string("STOP. If rolemap circular, cannot proceed with other checks.")
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_02_003(self : PdfDocument) -> Json? {
  if self.pdf_ua_matterhorn_rolemap().pdf_ua_matterhorn_has_circular_mapping() {
    Some(pdf_ua_matterhorn_circular_rolemap_extra())
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_02_004(self : PdfDocument) -> Json? {
  let rolemap = self.pdf_ua_matterhorn_rolemap()
  for entry in rolemap.entries {
    if pdf_ua_matterhorn_standard_structure_type(entry.0) {
      return Some(Json::string(pdf_ua_matterhorn_name_text(entry.0)))
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_xmp_field_exists(
  metadata : BytesView,
  xml_namespace : String,
  fallback_prefix : String,
  name : String,
) -> Bool {
  pdf_metadata_get_xmp_data(metadata, xml_namespace, fallback_prefix, name)
  is Some(_)
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_06_001(
  self : PdfDocument,
) -> Json? raise PdfError {
  match self.metadata() {
    Some(_) => None
    None => Some(Json::null())
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_06_002(
  self : PdfDocument,
) -> Json? raise PdfError {
  match self.metadata() {
    Some(metadata) =>
      if pdf_ua_matterhorn_xmp_field_exists(
          metadata, pdf_metadata_pdfuaid_namespace, "pdfuaid", "part",
        ) {
        None
      } else {
        Some(Json::null())
      }
    None => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_06_003(
  self : PdfDocument,
) -> Json? raise PdfError {
  match self.metadata() {
    Some(metadata) =>
      if pdf_ua_matterhorn_xmp_field_exists(
          metadata, pdf_metadata_dc_namespace, "dc", "title",
        ) {
        None
      } else {
        Some(Json::null())
      }
    None => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_display_doc_title(
  self : PdfDocument,
) -> PdfObject? {
  self.lookup_chain(self.trailer_dict(), [
    pdf_ua_root_key(),
    pdf_ua_viewer_preferences_key(),
    pdf_ua_display_doc_title_key(),
  ])
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_07_001(self : PdfDocument) -> Json? {
  match self.pdf_ua_matterhorn_display_doc_title() {
    None => Some(Json::null())
    Some(_) => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_07_002(self : PdfDocument) -> Json? {
  match self.pdf_ua_matterhorn_display_doc_title() {
    Some(PdfBoolean(false)) => Some(Json::null())
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_11_001(self : PdfDocument) -> Json? {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_ua_root_key(),
      pdf_ua_lang_key(),
    ]) {
    Some(PdfString(value)) if value.length() == 0 =>
      Some(Json::string("Top-level /Lang is empty"))
    None => Some(Json::string("No top-level /Lang"))
    Some(_) => None
  }
}

///|
fn pdf_ua_matterhorn_check_source_unimplemented_language() -> Json? {
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_ocproperties_d(
  self : PdfDocument,
) -> PdfObject? {
  self.lookup_chain(self.trailer_dict(), [
    pdf_ua_root_key(),
    pdf_ocg_ocproperties_key(),
    pdf_ocg_d_key(),
  ])
}

///|
fn PdfDocument::pdf_ua_matterhorn_ocproperties_configs(
  self : PdfDocument,
) -> PdfObject? {
  self.lookup_chain(self.trailer_dict(), [
    pdf_ua_root_key(),
    pdf_ocg_ocproperties_key(),
    pdf_ocg_configs_key(),
  ])
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_20_001(self : PdfDocument) -> Json? {
  match self.pdf_ua_matterhorn_ocproperties_configs() {
    Some(PdfArray(configs)) =>
      for config in configs {
        match self.lookup_direct(pdf_ocg_name_key(), config) {
          None => return Some(Json::null())
          Some(PdfNameObject(name)) if name == pdf_ua_empty_name() =>
            return Some(Json::null())
          _ => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_20_002(self : PdfDocument) -> Json? {
  match
    (
      self.pdf_ua_matterhorn_ocproperties_d(),
      self.lookup_chain(self.trailer_dict(), [
        pdf_ua_root_key(),
        pdf_ocg_ocproperties_key(),
        pdf_ocg_d_key(),
        pdf_ocg_name_key(),
      ]),
    ) {
    (Some(_), Some(PdfString(value))) if value.length() == 0 =>
      Some(Json::string("empty string"))
    (Some(_), None) => Some(Json::string("not present"))
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_20_003(self : PdfDocument) -> Json? {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_ua_root_key(),
      pdf_ocg_ocproperties_key(),
      pdf_ocg_d_key(),
      pdf_ocg_as_key(),
    ]) {
    Some(_) => return Some(Json::null())
    None => ()
  }
  match self.pdf_ua_matterhorn_ocproperties_configs() {
    Some(PdfArray(configs)) =>
      for config in configs {
        match self.lookup_direct(pdf_ocg_as_key(), config) {
          Some(_) => return Some(Json::null())
          None => ()
        }
      }
    _ => ()
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_file_spec_has_f_and_uf(
  self : PdfDocument,
  file_spec : PdfObject,
) -> Bool {
  self.lookup_direct(pdf_attach_f_key(), file_spec) is Some(_) &&
  self.lookup_direct(pdf_attach_uf_key(), file_spec) is Some(_)
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_21_001(
  self : PdfDocument,
) -> Json? raise PdfError {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_ua_root_key(),
      pdf_attach_names_key(),
      pdf_attach_embedded_files_key(),
    ]) {
    Some(tree) =>
      for entry in self.read_name_tree(tree) {
        if !self.pdf_ua_matterhorn_file_spec_has_f_and_uf(entry.1) {
          return Some(Json::null())
        }
      }
    None => ()
  }
  for page in self.pages_of_pagetree() {
    match self.lookup_direct(pdf_attach_annots_key(), page.rest) {
      Some(PdfArray(annotations)) =>
        for annotation in annotations {
          if self.pdf_attach_is_file_attachment_annotation(annotation) {
            match self.lookup_direct(pdf_attach_fs_key(), annotation) {
              Some(file_spec) =>
                if !self.pdf_ua_matterhorn_file_spec_has_f_and_uf(file_spec) {
                  return Some(Json::null())
                }
              None => ()
            }
          }
        }
      _ => ()
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_xfa_config_key(object : PdfObject) -> Bool {
  match object {
    PdfString(value) =>
      pdf_view_equals_ascii(value, [99, 111, 110, 102, 105, 103])
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_xfa_config_stream_data(
  self : PdfDocument,
  config : PdfObject,
) -> PdfBytes? raise PdfError {
  match self.direct(config) {
    PdfStreamObject(stream) => {
      let decoded = match
        self.pdf_stream_first_filter_direct(stream.dictionary) {
        None => stream
        Some(_) => self.pdf_decode_stream_until_unknown_value_direct(stream)
      }
      Some(pdf_stream_data_bytes(decoded.data))
    }
    _ => None
  }
}

///|
fn pdf_ua_matterhorn_xml_tag_local_name(
  data : BytesView,
  tag_start : Int,
  tag_end : Int,
  closing : Bool,
) -> BytesView? {
  let mut name_start = tag_start + 1
  if closing {
    guard name_start < tag_end && data[name_start].to_int() == 47 else {
      return None
    }
    name_start += 1
  }
  while name_start < tag_end && pdf_metadata_is_xml_space(data[name_start]) {
    name_start += 1
  }
  guard name_start < tag_end else { return None }
  match data[name_start].to_int() {
    33 | 47 | 63 => None
    _ => {
      let mut name_end = name_start
      while name_end < tag_end && !pdf_metadata_xml_tag_boundary(data[name_end]) {
        name_end += 1
      }
      guard name_end > name_start else { return None }
      let mut local_start = name_start
      for position = name_start; position < name_end; position = position + 1 {
        if data[position].to_int() == 58 {
          local_start = position + 1
        }
      }
      Some(data[local_start:name_end])
    }
  }
}

///|
fn pdf_ua_matterhorn_xml_dynamic_render_tag(
  data : BytesView,
  tag_start : Int,
  tag_end : Int,
  closing : Bool,
) -> Bool {
  match
    pdf_ua_matterhorn_xml_tag_local_name(data, tag_start, tag_end, closing) {
    Some(local_name) =>
      pdf_view_equals_ascii(local_name, [
        100, 121, 110, 97, 109, 105, 99, 82, 101, 110, 100, 101, 114,
      ])
    None => false
  }
}

///|
fn pdf_ua_matterhorn_find_dynamic_render_close(
  data : BytesView,
  start : Int,
) -> Int {
  let mut search_start = start
  let mut result = -1
  while search_start < data.length() && result < 0 {
    let tag_start = pdf_metadata_find_byte(data, search_start, 60)
    if tag_start < 0 {
      search_start = data.length()
    } else {
      let tag_end = pdf_metadata_find_byte(data, tag_start + 1, 62)
      if tag_end < 0 {
        search_start = data.length()
      } else if pdf_ua_matterhorn_xml_dynamic_render_tag(
          data, tag_start, tag_end, true,
        ) {
        result = tag_start
      } else {
        search_start = tag_end + 1
      }
    }
  }
  result
}

///|
fn pdf_ua_matterhorn_has_required_dynamic_render(data : BytesView) -> Bool {
  let mut search_start = 0
  while search_start < data.length() {
    let tag_start = pdf_metadata_find_byte(data, search_start, 60)
    if tag_start < 0 {
      search_start = data.length()
    } else {
      let tag_end = pdf_metadata_find_byte(data, tag_start + 1, 62)
      if tag_end < 0 {
        search_start = data.length()
      } else {
        if pdf_ua_matterhorn_xml_dynamic_render_tag(
            data, tag_start, tag_end, false,
          ) &&
          !pdf_ua_xml_tag_is_self_closing(data, tag_start, tag_end) {
          let value_start = tag_end + 1
          let value_end = pdf_ua_matterhorn_find_dynamic_render_close(
            data, value_start,
          )
          if value_end >= 0 &&
            pdf_view_equals_ascii(data[value_start:value_end], [
              114, 101, 113, 117, 105, 114, 101, 100,
            ]) {
            return true
          }
        }
        search_start = tag_end + 1
      }
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_25_001(
  self : PdfDocument,
) -> Json? raise PdfError {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_ua_root_key(),
      pdf_metadata_acroform(),
      pdf_metadata_xfa(),
    ]) {
    Some(PdfArray(xfa)) => {
      let configs : Array[PdfObject] = []
      for index = 0; index + 1 < xfa.length(); index = index + 2 {
        if pdf_ua_matterhorn_xfa_config_key(xfa[index]) {
          configs.push(xfa[index + 1])
        }
      }
      if configs.length() == 1 {
        match self.pdf_ua_matterhorn_xfa_config_stream_data(configs[0]) {
          Some(data) if pdf_ua_matterhorn_has_required_dynamic_render(data) =>
            Some(Json::null())
          _ => None
        }
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_26_001(_self : PdfDocument) -> Json? {
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_26_002(self : PdfDocument) -> Json? {
  match self.saved_encryption() {
    Some(saved) if pdf_permissions_of_p(saved.values.permissions).contains(
        PdfNoExtract,
      ) => Some(Json::null())
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_006(
  self : PdfDocument,
) -> Json? raise PdfError {
  for page in self.pages_of_pagetree() {
    for annotation in self.annotations_of_page(page) {
      if annotation.subtype is AnnotationUnknown(_) {
        return Some(Json::null())
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_007(
  self : PdfDocument,
) -> Json? raise PdfError {
  for page in self.pages_of_pagetree() {
    for annotation in self.annotations_of_page(page) {
      if annotation.subtype is AnnotationTrapNet {
        return Some(Json::null())
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_page_annotation_count(
  self : PdfDocument,
  page : PdfPage,
) -> Int raise PdfError {
  self.annotations_of_page(page).length()
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_008(
  self : PdfDocument,
) -> Json? raise PdfError {
  for page in self.pages_of_pagetree() {
    if self.pdf_ua_matterhorn_page_annotation_count(page) > 0 &&
      self.lookup_direct(pdf_ua_matterhorn_tabs_key(), page.rest) is None {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_009(
  self : PdfDocument,
) -> Json? raise PdfError {
  for page in self.pages_of_pagetree() {
    if self.pdf_ua_matterhorn_page_annotation_count(page) > 0 {
      match self.lookup_direct(pdf_ua_matterhorn_tabs_key(), page.rest) {
        Some(PdfNameObject(name)) if name == pdf_ua_s_key() => ()
        Some(_) => return Some(Json::null())
        None => ()
      }
    }
  }
  None
}

///|
let pdf_ua_matterhorn_28_002_subtypes : Array[PdfName] = [
  pdf_annotation_stamp_name,
  pdf_annotation_line_name,
  pdf_ua_name("Square"),
  pdf_annotation_circle_name,
  pdf_annotation_polygon_name,
  pdf_annotation_polyline_name,
  pdf_annotation_highlight_name,
  pdf_annotation_underline_name,
  pdf_annotation_squiggly_name,
  pdf_annotation_strikeout_name,
  pdf_annotation_caret_name,
  pdf_annotation_ink_name,
  pdf_annotation_file_attachment_name,
  pdf_annotation_sound_name,
  pdf_annotation_movie_name,
  pdf_annotation_screen_name,
  pdf_annotation_trap_net_name,
  pdf_annotation_watermark_name,
  pdf_annotation_three_dee_name,
]

///|
fn pdf_ua_matterhorn_28_002_subtype_requires_annot(subtype : PdfName) -> Bool {
  pdf_ua_matterhorn_28_002_subtypes.contains(subtype)
}

///|
fn pdf_ua_matterhorn_28_004_subtype_requires_contents_or_alt(
  subtype : PdfName,
) -> Bool {
  pdf_ua_matterhorn_28_002_subtype_requires_annot(subtype) ||
  subtype == pdf_annotation_link_name ||
  subtype == pdf_annotation_printer_mark_name
}

///|
fn PdfDocument::pdf_ua_matterhorn_parent_tree_entries(
  self : PdfDocument,
) -> Array[(Int, PdfObject)] {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_ua_root_key(),
      pdf_ua_struct_tree_root_key(),
      pdf_structure_parent_tree_key(),
    ]) {
    Some(parent_tree) => self.read_number_tree(parent_tree)
    None => []
  }
}

///|
fn pdf_ua_matterhorn_parent_tree_lookup(
  parent_tree : ArrayView[(Int, PdfObject)],
  key : Int,
) -> PdfObject? {
  for entry in parent_tree {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_002(self : PdfDocument) -> Json? {
  let parent_tree = self.pdf_ua_matterhorn_parent_tree_entries()
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_subtype_key(), entry.2) {
      Some(PdfNameObject(subtype)) =>
        if pdf_ua_matterhorn_28_002_subtype_requires_annot(subtype) {
          match
            self.lookup_direct(pdf_ua_matterhorn_struct_parent_key(), entry.2) {
            Some(PdfInteger(key)) =>
              match pdf_ua_matterhorn_parent_tree_lookup(parent_tree, key) {
                Some(structure) =>
                  match self.lookup_direct(pdf_ua_s_key(), structure) {
                    Some(PdfNameObject(kind)) =>
                      if kind != pdf_ua_matterhorn_annot() {
                        return Some(Json::null())
                      }
                    _ => return Some(Json::null())
                  }
                None => return Some(Json::null())
              }
            _ => return Some(Json::null())
          }
        }
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_004(self : PdfDocument) -> Json? {
  let parent_tree = self.pdf_ua_matterhorn_parent_tree_entries()
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_subtype_key(), entry.2) {
      Some(PdfNameObject(subtype)) =>
        if pdf_ua_matterhorn_28_004_subtype_requires_contents_or_alt(subtype) &&
          self.lookup_direct(pdf_annotation_contents_key(), entry.2) is None {
          match
            self.lookup_direct(pdf_ua_matterhorn_struct_parent_key(), entry.2) {
            Some(PdfInteger(key)) =>
              match pdf_ua_matterhorn_parent_tree_lookup(parent_tree, key) {
                Some(structure) =>
                  if self.lookup_direct(pdf_ua_matterhorn_alt_key(), structure)
                    is None {
                    return Some(Json::null())
                  }
                None => return Some(Json::null())
              }
            _ => ()
          }
        }
      _ => ()
    }
  }
  None
}

///|
// Preserve cpdf source behavior: get_field_object_numbers only returns fields
// with /T, then 28-005 checks the returned fields for missing /T.
fn PdfDocument::pdf_ua_matterhorn_check_28_005(_self : PdfDocument) -> Json? {
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_struct_parent_check(
  self : PdfDocument,
  object : PdfObject,
  parent_tree : ArrayView[(Int, PdfObject)],
  expected_type : PdfName,
  wrong_type_extra : String,
  missing_struct_parent_extra : String?,
) -> Json? {
  match self.lookup_direct(pdf_ua_matterhorn_struct_parent_key(), object) {
    Some(PdfInteger(key)) =>
      match pdf_ua_matterhorn_parent_tree_lookup(parent_tree, key) {
        Some(structure) =>
          match self.lookup_direct(pdf_ua_s_key(), structure) {
            Some(PdfNameObject(kind)) if kind == expected_type => None
            _ => Some(Json::string(wrong_type_extra))
          }
        None => Some(Json::string("not found in parent tree"))
      }
    _ =>
      match missing_struct_parent_extra {
        Some(extra) => Some(Json::string(extra))
        None => None
      }
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_010(self : PdfDocument) -> Json? {
  let parent_tree = self.pdf_ua_matterhorn_parent_tree_entries()
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_subtype_key(), entry.2) {
      Some(PdfNameObject(subtype)) if subtype == pdf_annotation_widget_name =>
        match
          self.pdf_ua_matterhorn_struct_parent_check(
            entry.2,
            parent_tree,
            pdf_ua_matterhorn_form(),
            "type is not form",
            Some("not in structure tree"),
          ) {
          Some(extra) => return Some(extra)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_011(self : PdfDocument) -> Json? {
  let parent_tree = self.pdf_ua_matterhorn_parent_tree_entries()
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_subtype_key(), entry.2) {
      Some(PdfNameObject(subtype)) if subtype == pdf_annotation_link_name =>
        match
          self.pdf_ua_matterhorn_struct_parent_check(
            entry.2,
            parent_tree,
            pdf_annotation_link_name,
            "type is not link",
            None,
          ) {
          Some(extra) => return Some(extra)
          None => ()
        }
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_012(
  self : PdfDocument,
) -> Json? raise PdfError {
  for page in self.pages_of_pagetree() {
    for annotation in self.annotations_of_page(page) {
      if annotation.subtype is AnnotationLink && annotation.contents is None {
        return Some(Json::null())
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_media_clip_mcd_without_ct(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match
    (
      self.lookup_direct(pdf_ua_type_key(), object),
      self.lookup_direct(pdf_ua_s_key(), object),
      self.lookup_direct(pdf_ua_matterhorn_ct_key(), object),
    ) {
    (Some(PdfNameObject(kind)), Some(PdfNameObject(subtype)), None) =>
      kind == pdf_ua_matterhorn_media_clip() &&
      subtype == pdf_ua_matterhorn_mcd()
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_014(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_media_clip_mcd_without_ct(entry.2) {
      return Some(Json::null())
    }
  }
  None
}

///|
// Preserve cpdf source behavior: 28-015 reports missing /Alt but checks the
// same missing /CT condition as 28-014.
fn PdfDocument::pdf_ua_matterhorn_check_28_015(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_media_clip_mcd_without_ct(entry.2) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_016(_self : PdfDocument) -> Json? {
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_is_printer_mark(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_ua_subtype_key(), object) {
    Some(PdfNameObject(subtype)) => subtype == pdf_ua_matterhorn_printer_mark()
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_017(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_printer_mark(entry.2) &&
      self.lookup_direct(pdf_ua_matterhorn_struct_parent_key(), entry.2)
      is Some(_) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_normal_appearance_streams(
  self : PdfDocument,
  annotation : PdfObject,
) -> Array[PdfObject] {
  let output : Array[PdfObject] = []
  match self.lookup_direct(pdf_ua_matterhorn_ap_key(), annotation) {
    Some(appearance_dictionary) =>
      match
        self.lookup_direct(pdf_ua_matterhorn_n_key(), appearance_dictionary) {
        Some(PdfDictionary(entries)) =>
          for entry in entries {
            output.push(self.direct(entry.1))
          }
        Some(appearance) => output.push(appearance)
        None => ()
      }
    None => ()
  }
  output
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_28_018(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_printer_mark(entry.2) {
      for stream in self.pdf_ua_matterhorn_normal_appearance_streams(entry.2) {
        let resources = self.pdf_ua_matterhorn_stream_resources(stream)
        let ops = self.parse_content_ops_with_resources(resources, [stream])
        if pdf_content_add_artifacts(ops) != ops {
          return Some(Json::null())
        }
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_30_001(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match
      (
        self.lookup_direct(pdf_ua_subtype_key(), entry.2),
        self.lookup_direct(pdf_ua_matterhorn_ref_key(), entry.2),
      ) {
      (Some(PdfNameObject(subtype)), Some(_)) if subtype ==
        pdf_ua_matterhorn_form() => return Some(Json::null())
      _ => ()
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_int_array_contains(
  values : ArrayView[Int],
  target : Int,
) -> Bool {
  for value in values {
    if value == target {
      return true
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_ops_contain_mcid(
  self : PdfDocument,
  ops : ArrayView[PdfContentOp],
) -> Bool {
  for op in ops {
    match op {
      Op_BDC(_, properties) =>
        if self.lookup_direct(pdf_ua_matterhorn_mcid_key(), properties)
          is Some(_) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_form_xobject_contains_mcid(
  self : PdfDocument,
  object_number : Int,
) -> Bool raise PdfError {
  let object = self.lookup_object_or_null(object_number)
  let resources = self.pdf_ua_matterhorn_stream_resources(object)
  let ops = self.parse_content_ops_with_resources(resources, [object])
  self.pdf_ua_matterhorn_ops_contain_mcid(ops)
}

///|
fn PdfDocument::pdf_ua_matterhorn_form_xobject_numbers(
  self : PdfDocument,
) -> Array[Int] {
  self.select_object_numbers(fn(object) {
    pdf_ua_matterhorn_is_form_stream(self, object)
  })
}

///|
fn PdfDocument::pdf_ua_matterhorn_referenced_mcid_xobjects(
  self : PdfDocument,
  object_number : Int,
  containing_mcids : ArrayView[Int],
) -> Array[Int] {
  let references : Array[Int] = []
  match
    self.lookup_direct(
      pdf_ua_matterhorn_resources_key(),
      PdfIndirect(object_number),
    ) {
    Some(resources) =>
      match self.lookup_direct(pdf_ua_matterhorn_xobject_key(), resources) {
        Some(PdfDictionary(entries)) =>
          for entry in entries {
            match entry.1 {
              PdfIndirect(target) =>
                if pdf_ua_matterhorn_int_array_contains(
                    containing_mcids, target,
                  ) {
                  references.push(target)
                }
              _ => ()
            }
          }
        _ => ()
      }
    None => ()
  }
  references
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_30_002(
  self : PdfDocument,
) -> Json? raise PdfError {
  let page_numbers = self.page_reference_numbers()
  self.replace_inherit(page_numbers)
  let form_xobject_numbers = self.pdf_ua_matterhorn_form_xobject_numbers()
  let containing_mcids : Array[Int] = []
  for number in form_xobject_numbers {
    if self.pdf_ua_matterhorn_form_xobject_contains_mcid(number) {
      containing_mcids.push(number)
    }
  }
  let seen : Array[Int] = []
  for number in form_xobject_numbers {
    for
      target in self.pdf_ua_matterhorn_referenced_mcid_xobjects(
        number, containing_mcids,
      ) {
      if pdf_ua_matterhorn_int_array_contains(seen, target) {
        return Some(Json::null())
      }
      seen.push(target)
    }
  }
  for number in page_numbers {
    for
      target in self.pdf_ua_matterhorn_referenced_mcid_xobjects(
        number, containing_mcids,
      ) {
      if pdf_ua_matterhorn_int_array_contains(seen, target) {
        return Some(Json::null())
      }
      seen.push(target)
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_type0_indirect_encoding(
  self : PdfDocument,
  object : PdfObject,
) -> Int? {
  let direct_object = self.direct(object)
  match
    (
      self.lookup_direct(pdf_ua_subtype_key(), direct_object),
      direct_object.lookup_immediate(pdf_ua_matterhorn_encoding_key()),
    ) {
    (Some(PdfNameObject(subtype)), Some(PdfNameObject(encoding))) if subtype ==
      pdf_ua_matterhorn_type0() &&
      (
        encoding == pdf_ua_matterhorn_identity_h() ||
        encoding == pdf_ua_matterhorn_identity_v()
      ) => None
    (Some(PdfNameObject(subtype)), Some(PdfIndirect(encoding_number))) if subtype ==
      pdf_ua_matterhorn_type0() => Some(encoding_number)
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_cid_system_entry(
  self : PdfDocument,
  object : PdfObject,
  key : PdfName,
) -> PdfObject? {
  match self.lookup_direct(pdf_ua_matterhorn_cid_system_info_key(), object) {
    Some(info) => self.lookup_direct(key, info)
    None => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_descendant_cid_system_entry(
  self : PdfDocument,
  type0_font : PdfObject,
  key : PdfName,
) -> PdfObject? {
  match
    self.lookup_direct(pdf_ua_matterhorn_descendant_fonts_key(), type0_font) {
    Some(PdfArray([descendant, ..])) =>
      self.pdf_ua_matterhorn_cid_system_entry(descendant, key)
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_type0_cid_system_entry(
  self : PdfDocument,
  key : PdfName,
) -> Json? {
  for entry in self.parsed_object_entries() {
    match self.pdf_ua_matterhorn_type0_indirect_encoding(entry.2) {
      Some(encoding_number) =>
        if self.pdf_ua_matterhorn_cid_system_entry(
            PdfIndirect(encoding_number),
            key,
          ) !=
          self.pdf_ua_matterhorn_descendant_cid_system_entry(entry.2, key) {
          return Some(Json::null())
        }
      None => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_001(self : PdfDocument) -> Json? {
  self.pdf_ua_matterhorn_check_type0_cid_system_entry(
    pdf_ua_matterhorn_registry_key(),
  )
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_002(self : PdfDocument) -> Json? {
  self.pdf_ua_matterhorn_check_type0_cid_system_entry(
    pdf_ua_matterhorn_ordering_key(),
  )
}

///|
// Preserve cpdf source behavior: 31-003 reports a Supplement comparison, but
// checks the CMap /Registry against the descendant CIDFont /Ordering.
fn PdfDocument::pdf_ua_matterhorn_check_31_003(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match self.pdf_ua_matterhorn_type0_indirect_encoding(entry.2) {
      Some(encoding_number) =>
        if self.pdf_ua_matterhorn_cid_system_entry(
            PdfIndirect(encoding_number),
            pdf_ua_matterhorn_registry_key(),
          ) !=
          self.pdf_ua_matterhorn_descendant_cid_system_entry(
            entry.2,
            pdf_ua_matterhorn_ordering_key(),
          ) {
          return Some(Json::null())
        }
      None => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_is_cid_font_type2(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_ua_subtype_key(), object) {
    Some(PdfNameObject(subtype)) =>
      subtype == pdf_ua_matterhorn_cid_font_type2()
    _ => false
  }
}

///|
fn pdf_ua_matterhorn_object_string_extra(object : PdfObject) -> Json {
  let bytes = pdf_write_object(object) catch { _ => b"" }
  Json::string(@ascii.decode_lossy(bytes))
}

///|
fn pdf_ua_matterhorn_name_extra(name : PdfName) -> Json {
  Json::string(@ascii.decode_lossy(name.bytes()))
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_004(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_cid_font_type2(entry.2) {
      match
        self.lookup_direct(pdf_ua_matterhorn_cid_to_gid_map_key(), entry.2) {
        Some(PdfNameObject(name)) if name == pdf_ua_matterhorn_identity() => ()
        Some(PdfStreamObject(_)) => ()
        _ => return Some(pdf_ua_matterhorn_object_string_extra(entry.2))
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_005(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_cid_font_type2(entry.2) &&
      self.lookup_direct(pdf_ua_matterhorn_cid_to_gid_map_key(), entry.2)
      is None {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_006(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match
      (
        self.lookup_direct(pdf_ua_subtype_key(), entry.2),
        self.lookup_direct(pdf_ua_matterhorn_encoding_key(), entry.2),
      ) {
      (Some(PdfNameObject(subtype)), Some(PdfNameObject(encoding))) if subtype ==
        pdf_ua_matterhorn_type0() &&
        !pdf_ua_matterhorn_cmap_name_is_listed(encoding) =>
        return Some(pdf_ua_matterhorn_name_extra(encoding))
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_007(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_matterhorn_wmode_key(), entry.2) {
      Some(PdfInteger(from_dictionary)) => {
        let bytes = self.pdf_text_decoded_cmap_stream_data_direct(entry.2)
        let from_stream = match pdf_parse_cmap_data(bytes).wmode {
          Some(value) => value
          None => 0
        }
        if from_stream != from_dictionary {
          return Some(Json::null())
        }
      }
      _ => ()
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_008(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match self.lookup_direct(pdf_ua_matterhorn_usecmap_key(), entry.2) {
      Some(PdfNameObject(name)) if !pdf_ua_matterhorn_cmap_name_is_listed(name) =>
        return Some(pdf_ua_matterhorn_name_extra(name))
      _ => ()
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_missing_font_extra(entry : PdfMissingFontEntry) -> Json {
  Json::string(
    entry.page.to_string() +
    " " +
    entry.name +
    " " +
    entry.subtype +
    " " +
    entry.basefont +
    " " +
    entry.encoding,
  )
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_009(
  self : PdfDocument,
) -> Json? raise PdfError {
  let page_count = self.pages_of_pagetree().length()
  let missing = self.missing_fonts(
    [
      for page_number in 1..<=page_count => page_number
    ],
  )
  if missing.length() == 0 {
    None
  } else {
    Some(
      Json::array(
        [
          for entry in missing => pdf_ua_matterhorn_missing_font_extra(entry)
        ],
      ),
    )
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_is_non_symbolic(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_text_font_descriptor_key_name, object) {
    Some(descriptor) =>
      match self.lookup_direct(pdf_text_flags_key_name, descriptor) {
        Some(PdfInteger(flags)) => !((flags & 4) > 0)
        _ => true
      }
    None => true
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_is_truetype(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_ua_subtype_key(), object) {
    Some(PdfNameObject(subtype)) => subtype == pdf_text_true_type_name_value
    _ => false
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_is_non_symbolic_truetype(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  self.pdf_ua_matterhorn_is_truetype(object) &&
  self.pdf_ua_matterhorn_is_non_symbolic(object)
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_019(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_non_symbolic_truetype(entry.2) &&
      self.lookup_direct(pdf_text_encoding_key_name, entry.2) is None {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_020(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    match
      (
        self.pdf_ua_matterhorn_is_non_symbolic_truetype(entry.2),
        self.lookup_direct(pdf_text_encoding_key_name, entry.2),
      ) {
      (true, Some(PdfDictionary(_) as encoding)) =>
        if self.lookup_direct(pdf_text_base_encoding_key_name, encoding) is None {
          return Some(Json::null())
        }
      _ => ()
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_is_mac_roman_or_win_ansi(name : PdfName) -> Bool {
  name == pdf_text_mac_roman_encoding_name ||
  name == pdf_text_win_ansi_encoding_name
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_021(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_non_symbolic_truetype(entry.2) {
      match self.lookup_direct(pdf_text_encoding_key_name, entry.2) {
        Some(PdfNameObject(name)) =>
          if !pdf_ua_matterhorn_is_mac_roman_or_win_ansi(name) {
            return Some(Json::null())
          }
        Some(PdfDictionary(_) as encoding) =>
          match self.lookup_direct(pdf_text_base_encoding_key_name, encoding) {
            Some(PdfNameObject(name)) if pdf_ua_matterhorn_is_mac_roman_or_win_ansi(
                name,
              ) => ()
            Some(base_encoding) =>
              return Some(pdf_ua_matterhorn_object_string_extra(base_encoding))
            None => ()
          }
        _ => ()
      }
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_agl_glyph_name(name : PdfName) -> Bool {
  match pdf_text_codepoints_of_agl_sequence_glyphname(name) {
    Some(_) => true
    None => pdf_text_codepoint_of_agl_base_glyphname(name) is Some(_)
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_022(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_non_symbolic_truetype(entry.2) {
      match self.lookup_direct(pdf_text_encoding_key_name, entry.2) {
        Some(encoding) =>
          match self.lookup_direct(pdf_text_differences_key_name, encoding) {
            Some(PdfArray(differences)) =>
              for difference in differences {
                match difference {
                  PdfNameObject(name) if !pdf_ua_matterhorn_agl_glyph_name(name) =>
                    return Some(pdf_ua_matterhorn_name_extra(name))
                  _ => ()
                }
              }
            _ => ()
          }
        None => ()
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_truetype_fontfile(
  self : PdfDocument,
  object : PdfObject,
) -> PdfBytes? raise PdfError {
  match
    self.lookup_chain(object, [
      pdf_text_font_descriptor_key_name, pdf_text_font_file2_key_name,
    ]) {
    Some(PdfStreamObject(stream)) => {
      let decoded = match
        self.pdf_stream_first_filter_direct(stream.dictionary) {
        None => stream
        Some(_) => self.pdf_decode_stream_until_unknown_value_direct(stream)
      }
      Some(pdf_stream_data_bytes(decoded.data))
    }
    _ => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_truetype_cmaps(
  self : PdfDocument,
  object : PdfObject,
) -> Array[(Int, Int)]? raise PdfError {
  match self.pdf_ua_matterhorn_truetype_fontfile(object) {
    Some(fontfile) => Some(pdf_truetype_cmaps(fontfile))
    None => None
  }
}

///|
fn pdf_ua_matterhorn_cmaps_contain(
  cmaps : ArrayView[(Int, Int)],
  platform_id : Int,
  encoding_id : Int,
) -> Bool {
  for cmap in cmaps {
    if cmap.0 == platform_id && cmap.1 == encoding_id {
      return true
    }
  }
  false
}

///|
fn pdf_ua_matterhorn_symbolic_cmap(cmap : (Int, Int)) -> Bool {
  (cmap.0 == 1 && cmap.1 == 8) || (cmap.0 == 3 && cmap.1 == 0)
}

///|
fn pdf_ua_matterhorn_cmap_extra(cmap : (Int, Int)) -> Json {
  Json::string("(" + cmap.0.to_string() + ", " + cmap.1.to_string() + ") cmap")
}

///|
// Preserve cpdf source behavior: despite the 31-017 diagnostic saying
// "non-symbolic", the source checks symbolic TrueType fonts and reports any
// non-symbolic cmap entry.
fn PdfDocument::pdf_ua_matterhorn_check_31_017(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_truetype(entry.2) &&
      !self.pdf_ua_matterhorn_is_non_symbolic(entry.2) {
      match self.pdf_ua_matterhorn_truetype_cmaps(entry.2) {
        Some(cmaps) =>
          for cmap in cmaps {
            if !pdf_ua_matterhorn_symbolic_cmap(cmap) {
              return Some(pdf_ua_matterhorn_cmap_extra(cmap))
            }
          }
        None => ()
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_023(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_non_symbolic_truetype(entry.2) &&
      self.lookup_chain(entry.2, [
        pdf_text_encoding_key_name, pdf_text_differences_key_name,
      ])
      is Some(_) {
      match self.pdf_ua_matterhorn_truetype_cmaps(entry.2) {
        Some(cmaps) if !pdf_ua_matterhorn_cmaps_contain(cmaps, 3, 1) =>
          return Some(Json::null())
        _ => ()
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_024(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_truetype(entry.2) &&
      !self.pdf_ua_matterhorn_is_non_symbolic(entry.2) &&
      self.lookup_direct(pdf_text_encoding_key_name, entry.2) is Some(_) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_025(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_truetype(entry.2) &&
      !self.pdf_ua_matterhorn_is_non_symbolic(entry.2) {
      match self.pdf_ua_matterhorn_truetype_cmaps(entry.2) {
        Some(cmaps) if cmaps.length() == 0 => return Some(Json::null())
        _ => ()
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_026(
  self : PdfDocument,
) -> Json? raise PdfError {
  for entry in self.parsed_object_entries() {
    if self.pdf_ua_matterhorn_is_truetype(entry.2) &&
      !self.pdf_ua_matterhorn_is_non_symbolic(entry.2) {
      match self.pdf_ua_matterhorn_truetype_cmaps(entry.2) {
        Some(cmaps) if cmaps.length() > 1 &&
          !pdf_ua_matterhorn_cmaps_contain(cmaps, 3, 0) =>
          return Some(Json::null())
        _ => ()
      }
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_font_uses_known_encoding(
  document : PdfDocument,
  object : PdfObject,
) -> Bool {
  match document.lookup_direct(pdf_text_encoding_key_name, object) {
    Some(PdfNameObject(name)) =>
      name == pdf_text_mac_roman_encoding_name ||
      name == pdf_text_mac_expert_encoding_name ||
      name == pdf_text_win_ansi_encoding_name
    _ => false
  }
}

///|
fn pdf_ua_matterhorn_supported_cid_ordering(name : PdfName) -> Bool {
  name == pdf_ua_matterhorn_gb1_name ||
  name == pdf_ua_matterhorn_cns1_name ||
  name == pdf_ua_matterhorn_japan1_name ||
  name == pdf_ua_matterhorn_korea1_name
}

///|
fn PdfDocument::pdf_ua_matterhorn_type0_uses_supported_cid_collection(
  self : PdfDocument,
  object : PdfObject,
) -> Bool {
  match
    (
      self.lookup_direct(pdf_text_subtype_key_name, object),
      self.lookup_direct(pdf_text_descendant_fonts_key_name, object),
    ) {
    (Some(PdfNameObject(subtype)), Some(PdfArray([descendant]))) if subtype ==
      pdf_text_type0_name =>
      match self.lookup_direct(pdf_text_cid_system_info_key_name, descendant) {
        Some(info) =>
          match
            (
              self.lookup_direct(pdf_text_registry_key_name, info),
              self.lookup_direct(pdf_text_ordering_key_name, info),
            ) {
            (Some(PdfNameObject(registry)), Some(PdfNameObject(ordering))) =>
              registry == pdf_ua_matterhorn_adobe() &&
              pdf_ua_matterhorn_supported_cid_ordering(ordering)
            _ => false
          }
        None => false
      }
    _ => false
  }
}

///|
fn pdf_ua_matterhorn_source_silences_missing_tounicode(
  subtype : PdfName,
) -> Bool {
  subtype == pdf_text_type0_name ||
  subtype == pdf_ua_matterhorn_cid_font_type0() ||
  subtype == pdf_ua_matterhorn_cid_font_type2()
}

///|
fn pdf_ua_matterhorn_missing_tounicode_source_unimplemented(
  subtype : PdfName,
) -> Bool {
  subtype == pdf_text_type1_name ||
  subtype == pdf_text_mmtype1_name ||
  subtype == pdf_text_type3_name
}

///|
/// Preserve cpdf source behavior: the Type1/Type3 referenced-glyph branch raises
/// MatterhornUnimplemented and is caught by the source runner as no failure.
fn PdfDocument::pdf_ua_matterhorn_check_31_027(self : PdfDocument) -> Json? {
  for entry in self.parsed_object_entries() {
    if self.lookup_direct(pdf_text_tounicode_key_name, entry.2) is None {
      match self.lookup_direct(pdf_text_type_key_name, entry.2) {
        Some(PdfNameObject(type_name)) if type_name == pdf_text_font_name =>
          if !pdf_ua_matterhorn_font_uses_known_encoding(self, entry.2) &&
            !self.pdf_ua_matterhorn_type0_uses_supported_cid_collection(entry.2) &&
            !self.pdf_ua_matterhorn_is_non_symbolic(entry.2) {
            match self.lookup_direct(pdf_text_subtype_key_name, entry.2) {
              Some(PdfNameObject(subtype)) if pdf_ua_matterhorn_source_silences_missing_tounicode(
                  subtype,
                ) => ()
              Some(PdfNameObject(subtype)) if pdf_ua_matterhorn_missing_tounicode_source_unimplemented(
                  subtype,
                ) => return None
              _ => return Some(pdf_ua_matterhorn_object_string_extra(entry.2))
            }
          }
        _ => ()
      }
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_tounicode_numbers(
  self : PdfDocument,
) -> Array[Int] {
  let numbers : Array[Int] = []
  for entry in self.parsed_object_entries() {
    match self.indirect_number(pdf_text_tounicode_key_name, entry.2) {
      Some(number) if !pdf_ua_matterhorn_int_array_contains(numbers, number) =>
        numbers.push(number)
      _ => ()
    }
  }
  numbers
}

///|
fn pdf_ua_matterhorn_tounicode_has_codepoint(
  map : ArrayView[(Int, PdfBytes)],
  codepoint : Int,
) -> Bool raise PdfError {
  for entry in map {
    for parsed_codepoint in pdf_codepoints_of_utf16be(entry.1) {
      if parsed_codepoint == codepoint {
        return true
      }
    }
  }
  false
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_028(
  self : PdfDocument,
) -> Json? raise PdfError {
  for number in self.pdf_ua_matterhorn_tounicode_numbers() {
    let parsed = self.parse_cmap(PdfIndirect(number))
    if pdf_ua_matterhorn_tounicode_has_codepoint(parsed.map, 0) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_check_31_029(
  self : PdfDocument,
) -> Json? raise PdfError {
  for number in self.pdf_ua_matterhorn_tounicode_numbers() {
    let parsed = self.parse_cmap(PdfIndirect(number))
    if pdf_ua_matterhorn_tounicode_has_codepoint(parsed.map, 0xFEFF) ||
      pdf_ua_matterhorn_tounicode_has_codepoint(parsed.map, 0xFFFE) {
      return Some(Json::null())
    }
  }
  None
}

///|
fn pdf_ua_matterhorn_check_source_unimplemented_font_file() -> Json? {
  None
}

///|
fn PdfDocument::pdf_ua_matterhorn_run_test(
  self : PdfDocument,
  check : PdfUAMatterhornTest,
) -> PdfUAMatterhornFailure? raise PdfError {
  let result = match check.name {
    "01-003" => self.pdf_ua_matterhorn_check_01_003()
    "01-004" => self.pdf_ua_matterhorn_check_01_004()
    "01-005" => self.pdf_ua_matterhorn_check_01_005()
    "01-007" => self.pdf_ua_matterhorn_check_01_007()
    "02-001" => self.pdf_ua_matterhorn_check_02_001()
    "02-003" => self.pdf_ua_matterhorn_check_02_003()
    "02-004" => self.pdf_ua_matterhorn_check_02_004()
    "06-001" => self.pdf_ua_matterhorn_check_06_001()
    "06-002" => self.pdf_ua_matterhorn_check_06_002()
    "06-003" => self.pdf_ua_matterhorn_check_06_003()
    "07-001" => self.pdf_ua_matterhorn_check_07_001()
    "07-002" => self.pdf_ua_matterhorn_check_07_002()
    "11-001" => self.pdf_ua_matterhorn_check_11_001()
    "11-002" | "11-003" | "11-004" | "11-005" | "11-006" =>
      pdf_ua_matterhorn_check_source_unimplemented_language()
    "20-001" => self.pdf_ua_matterhorn_check_20_001()
    "20-002" => self.pdf_ua_matterhorn_check_20_002()
    "20-003" => self.pdf_ua_matterhorn_check_20_003()
    "21-001" => self.pdf_ua_matterhorn_check_21_001()
    "25-001" => self.pdf_ua_matterhorn_check_25_001()
    "26-001" => self.pdf_ua_matterhorn_check_26_001()
    "26-002" => self.pdf_ua_matterhorn_check_26_002()
    "28-002" => self.pdf_ua_matterhorn_check_28_002()
    "28-004" => self.pdf_ua_matterhorn_check_28_004()
    "28-005" => self.pdf_ua_matterhorn_check_28_005()
    "28-006" => self.pdf_ua_matterhorn_check_28_006()
    "28-007" => self.pdf_ua_matterhorn_check_28_007()
    "28-008" => self.pdf_ua_matterhorn_check_28_008()
    "28-009" => self.pdf_ua_matterhorn_check_28_009()
    "28-010" => self.pdf_ua_matterhorn_check_28_010()
    "28-011" => self.pdf_ua_matterhorn_check_28_011()
    "28-012" => self.pdf_ua_matterhorn_check_28_012()
    "28-014" => self.pdf_ua_matterhorn_check_28_014()
    "28-015" => self.pdf_ua_matterhorn_check_28_015()
    "28-016" => self.pdf_ua_matterhorn_check_28_016()
    "28-017" => self.pdf_ua_matterhorn_check_28_017()
    "28-018" => self.pdf_ua_matterhorn_check_28_018()
    "30-001" => self.pdf_ua_matterhorn_check_30_001()
    "30-002" => self.pdf_ua_matterhorn_check_30_002()
    "31-001" => self.pdf_ua_matterhorn_check_31_001()
    "31-002" => self.pdf_ua_matterhorn_check_31_002()
    "31-003" => self.pdf_ua_matterhorn_check_31_003()
    "31-004" => self.pdf_ua_matterhorn_check_31_004()
    "31-005" => self.pdf_ua_matterhorn_check_31_005()
    "31-006" => self.pdf_ua_matterhorn_check_31_006()
    "31-007" => self.pdf_ua_matterhorn_check_31_007()
    "31-008" => self.pdf_ua_matterhorn_check_31_008()
    "31-009" => self.pdf_ua_matterhorn_check_31_009()
    "31-017" => self.pdf_ua_matterhorn_check_31_017()
    "31-019" => self.pdf_ua_matterhorn_check_31_019()
    "31-020" => self.pdf_ua_matterhorn_check_31_020()
    "31-021" => self.pdf_ua_matterhorn_check_31_021()
    "31-022" => self.pdf_ua_matterhorn_check_31_022()
    "31-023" => self.pdf_ua_matterhorn_check_31_023()
    "31-024" => self.pdf_ua_matterhorn_check_31_024()
    "31-025" => self.pdf_ua_matterhorn_check_31_025()
    "31-026" => self.pdf_ua_matterhorn_check_31_026()
    "31-027" => self.pdf_ua_matterhorn_check_31_027()
    "31-028" => self.pdf_ua_matterhorn_check_31_028()
    "31-029" => self.pdf_ua_matterhorn_check_31_029()
    "31-011"
    | "31-012"
    | "31-013"
    | "31-014"
    | "31-015"
    | "31-016"
    | "31-018"
    | "31-030" => pdf_ua_matterhorn_check_source_unimplemented_font_file()
    _ => None
  }
  match result {
    Some(extra) => Some(pdf_ua_matterhorn_failure(check, extra~))
    None => None
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_circular_rolemap_failure(
  self : PdfDocument,
) -> PdfUAMatterhornFailure? {
  match self.pdf_ua_matterhorn_check_02_003() {
    Some(extra) =>
      Some(pdf_ua_matterhorn_failure(pdf_ua_matterhorn_test_02_003(), extra~))
    None => None
  }
}

///|
fn pdf_ua_matterhorn_tests_for_name(
  test_name : String,
) -> Array[PdfUAMatterhornTest] raise PdfError {
  let tests = pdf_ua_matterhorn_implemented_tests()
  if test_name == "" {
    tests
  } else {
    for check in tests {
      if check.name == test_name {
        return [check]
      }
    }
    raise SoftError("Matterhorn test not yet implemented: " + test_name)
  }
}

///|
fn PdfDocument::pdf_ua_matterhorn_failures(
  self : PdfDocument,
  test_name : String,
) -> Array[PdfUAMatterhornFailure] raise PdfError {
  let checks = pdf_ua_matterhorn_tests_for_name(test_name)
  match self.pdf_ua_matterhorn_circular_rolemap_failure() {
    Some(failure) => return [failure]
    None => ()
  }
  let failures : Array[PdfUAMatterhornFailure] = []
  for check in checks {
    match self.pdf_ua_matterhorn_run_test(check) {
      Some(failure) => failures.push(failure)
      None => ()
    }
  }
  failures
}

///|
/// Return cpdf-style PDF/UA Matterhorn failures as JSON.
///
/// The current migration covers content-marking checks `01-003`, `01-004`,
/// `01-005`, and `01-007`, role-map checks `02-001`, `02-003`, and `02-004`,
/// XMP metadata and DisplayDocTitle checks `06-001` through `07-002`, and
/// natural-language top-level `/Lang` check `11-001` plus source-unimplemented
/// language checks `11-002` through `11-006`,
/// optional-content configuration checks `20-001` through `20-003`, embedded
/// file-spec check `21-001`, XFA dynamicRender check `25-001`,
/// encryption checks `26-001` and `26-002`,
/// annotation parent structure check `28-002`,
/// annotation contents-or-Alt check `28-004`,
/// source-compatible form-field no-op check `28-005`,
/// annotation subtype and tab-order checks `28-006` through `28-009`,
/// annotation structure-parent checks `28-010` and `28-011`,
/// link annotation contents check `28-012`,
/// media-clip checks `28-014` and `28-015`, file-attachment no-op `28-016`,
/// PrinterMark object and appearance checks `28-017` and `28-018`, plus
/// reference-XObject checks `30-001` and `30-002`, plus font
/// CIDSystemInfo/CIDToGIDMap/CMap
/// checks `31-001` through `31-009`, and source-unimplemented font-file checks
/// `31-011` through `31-016`, `31-018`, and `31-030`, plus TrueType encoding
/// dictionary and cmap checks `31-017` and `31-019` through `31-026`, and
/// ToUnicode presence/value checks `31-027` through `31-029`. Passing `""` runs the covered
/// subset; unsupported individual test names raise a soft error until their
/// source checks are ported.
pub fn PdfDocument::test_matterhorn_json(
  self : PdfDocument,
  test_name : String,
) -> Json raise PdfError {
  Json::array(
    [
      for failure in self.pdf_ua_matterhorn_failures(test_name) => {
        failure.to_json()
      }
    ],
  )
}

///|
fn pdf_ua_matterhorn_push_text_failure(
  output : Array[Byte],
  failure : PdfUAMatterhornFailure,
) -> Unit {
  pdf_ua_push_ascii(output, failure.name)
  output.push(32)
  pdf_ua_push_ascii(output, failure.section)
  output.push(32)
  pdf_ua_push_utf8(output, failure.error)
  output.push(32)
  if failure.extra != Json::null() {
    output.push(40)
    pdf_ua_push_utf8(output, failure.extra.stringify())
    output.push(41)
  }
  output.push(10)
}

///|
/// Return cpdf-style text lines for the covered Matterhorn failures.
pub fn PdfDocument::test_matterhorn_text(
  self : PdfDocument,
  test_name : String,
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  for failure in self.pdf_ua_matterhorn_failures(test_name) {
    pdf_ua_matterhorn_push_text_failure(output, failure)
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::test_matterhorn_json`.
pub fn pdf_ua_test_matterhorn_json(
  document : PdfDocument,
  test_name : String,
) -> Json raise PdfError {
  document.test_matterhorn_json(test_name)
}

///|
/// Compatibility wrapper for `PdfDocument::test_matterhorn_text`.
pub fn pdf_ua_test_matterhorn_print(
  document : PdfDocument,
  test_name : String,
) -> PdfBytes raise PdfError {
  document.test_matterhorn_text(test_name)
}
