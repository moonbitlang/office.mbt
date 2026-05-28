///|
/// Encoding policy used when reading PDF information dictionary metadata.
pub(all) enum PdfMetadataEncoding {
  PdfMetadataRaw
  PdfMetadataUTF8
  PdfMetadataStripped
} derive(Debug, Eq, ToJson)

///|
fn pdf_metadata_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_metadata_source_key_name(key : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(key))
}

///|
let pdf_metadata_root_name : PdfName = pdf_metadata_name("/Root")

///|
fn pdf_metadata_root() -> PdfName {
  pdf_metadata_root_name
}

///|
let pdf_metadata_info_name : PdfName = pdf_metadata_name("/Info")

///|
fn pdf_metadata_info() -> PdfName {
  pdf_metadata_info_name
}

///|
let pdf_metadata_id_name : PdfName = pdf_metadata_name("/ID")

///|
fn pdf_metadata_id() -> PdfName {
  pdf_metadata_id_name
}

///|
let pdf_metadata_metadata_name : PdfName = pdf_metadata_name("/Metadata")

///|
fn pdf_metadata_metadata() -> PdfName {
  pdf_metadata_metadata_name
}

///|
let pdf_metadata_type_name : PdfName = pdf_metadata_name("/Type")

///|
fn pdf_metadata_type() -> PdfName {
  pdf_metadata_type_name
}

///|
let pdf_metadata_subtype_name : PdfName = pdf_metadata_name("/Subtype")

///|
fn pdf_metadata_subtype() -> PdfName {
  pdf_metadata_subtype_name
}

///|
let pdf_metadata_xml_name : PdfName = pdf_metadata_name("/XML")

///|
fn pdf_metadata_xml() -> PdfName {
  pdf_metadata_xml_name
}

///|
let pdf_metadata_length_name : PdfName = pdf_metadata_name("/Length")

///|
fn pdf_metadata_length() -> PdfName {
  pdf_metadata_length_name
}

///|
let pdf_metadata_viewer_preferences_name : PdfName = pdf_metadata_name(
  "/ViewerPreferences",
)

///|
fn pdf_metadata_viewer_preferences() -> PdfName {
  pdf_metadata_viewer_preferences_name
}

///|
let pdf_metadata_page_layout_name : PdfName = pdf_metadata_name("/PageLayout")

///|
fn pdf_metadata_page_layout() -> PdfName {
  pdf_metadata_page_layout_name
}

///|
let pdf_metadata_page_mode_name : PdfName = pdf_metadata_name("/PageMode")

///|
fn pdf_metadata_page_mode() -> PdfName {
  pdf_metadata_page_mode_name
}

///|
let pdf_metadata_non_full_screen_page_mode_name : PdfName = pdf_metadata_name(
  "/NonFullScreenPageMode",
)

///|
fn pdf_metadata_non_full_screen_page_mode() -> PdfName {
  pdf_metadata_non_full_screen_page_mode_name
}

///|
let pdf_metadata_open_action_name : PdfName = pdf_metadata_name("/OpenAction")

///|
fn pdf_metadata_open_action() -> PdfName {
  pdf_metadata_open_action_name
}

///|
let pdf_metadata_d_name : PdfName = pdf_metadata_name("/D")

///|
fn pdf_metadata_d() -> PdfName {
  pdf_metadata_d_name
}

///|
let pdf_metadata_s_name : PdfName = pdf_metadata_name("/S")

///|
fn pdf_metadata_s() -> PdfName {
  pdf_metadata_s_name
}

///|
let pdf_metadata_goto_name : PdfName = pdf_metadata_name("/GoTo")

///|
fn pdf_metadata_goto() -> PdfName {
  pdf_metadata_goto_name
}

///|
let pdf_metadata_fit_name : PdfName = pdf_metadata_name("/Fit")

///|
fn pdf_metadata_fit() -> PdfName {
  pdf_metadata_fit_name
}

///|
let pdf_metadata_xyz_name : PdfName = pdf_metadata_name("/XYZ")

///|
fn pdf_metadata_xyz() -> PdfName {
  pdf_metadata_xyz_name
}

///|
let pdf_metadata_lang_name : PdfName = pdf_metadata_name("/Lang")

///|
fn pdf_metadata_lang() -> PdfName {
  pdf_metadata_lang_name
}

///|
let pdf_metadata_mark_info_name : PdfName = pdf_metadata_name("/MarkInfo")

///|
fn pdf_metadata_mark_info() -> PdfName {
  pdf_metadata_mark_info_name
}

///|
let pdf_metadata_acroform_name : PdfName = pdf_metadata_name("/AcroForm")

///|
fn pdf_metadata_acroform() -> PdfName {
  pdf_metadata_acroform_name
}

///|
let pdf_metadata_xfa_name : PdfName = pdf_metadata_name("/XFA")

///|
fn pdf_metadata_xfa() -> PdfName {
  pdf_metadata_xfa_name
}

///|
let pdf_metadata_trapped_name : PdfName = pdf_metadata_name("/Trapped")

///|
fn pdf_metadata_trapped() -> PdfName {
  pdf_metadata_trapped_name
}

///|
let pdf_metadata_cropbox_name : PdfName = pdf_metadata_name("/CropBox")

///|
fn pdf_metadata_cropbox() -> PdfName {
  pdf_metadata_cropbox_name
}

///|
let pdf_metadata_bleedbox_name : PdfName = pdf_metadata_name("/BleedBox")

///|
fn pdf_metadata_bleedbox() -> PdfName {
  pdf_metadata_bleedbox_name
}

///|
let pdf_metadata_trimbox_name : PdfName = pdf_metadata_name("/TrimBox")

///|
fn pdf_metadata_trimbox() -> PdfName {
  pdf_metadata_trimbox_name
}

///|
let pdf_metadata_artbox_name : PdfName = pdf_metadata_name("/ArtBox")

///|
fn pdf_metadata_artbox() -> PdfName {
  pdf_metadata_artbox_name
}

///|
/// Adobe PDF XMP namespace URI.
pub let pdf_metadata_adobe_namespace : String = "http://ns.adobe.com/pdf/1.3/"

///|
/// Adobe XMP namespace URI.
pub let pdf_metadata_xmp_namespace : String = "http://ns.adobe.com/xap/1.0/"

///|
/// Dublin Core metadata namespace URI.
pub let pdf_metadata_dc_namespace : String = "http://purl.org/dc/elements/1.1/"

///|
/// RDF syntax namespace URI used by XMP metadata.
pub let pdf_metadata_rdf_namespace : String = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"

///|
/// PDF/A identification namespace URI.
pub let pdf_metadata_pdfaid_namespace : String = "http://www.aiim.org/pdfa/ns/id/"

///|
let pdf_metadata_pdfaid_wrong_iso_namespace : String = "http://www.aiim.org/pdfa/ns/id"

///|
let pdf_metadata_pdfaid_wrong_acrobat_namespace : String = "http://www.aiim.org/pdfa/ns/id.html"

///|
/// PDF/X identification namespace URI.
pub let pdf_metadata_pdfxid_namespace : String = "http://www.npes.org/pdfx/ns/id/"

///|
/// PDF/E identification namespace URI.
pub let pdf_metadata_pdfe_namespace : String = "http://www.aiim.org/pdfe/ns/id/"

///|
/// PDF/UA identification namespace URI.
pub let pdf_metadata_pdfuaid_namespace : String = "http://www.aiim.org/pdfua/ns/id/"

///|
/// PDF/VT identification namespace URI.
pub let pdf_metadata_pdfvtid_namespace : String = "http://www.npes.org/pdfvt/ns/id/"

///|
/// Alias matching cpdfmetadata's `adobe` namespace constant.
pub let pdf_metadata_adobe : String = pdf_metadata_adobe_namespace

///|
/// Source-spelled compatibility alias for cpdfmetadata's `adobe`.
pub let pdf_adobe : String = pdf_metadata_adobe_namespace

///|
/// Alias matching cpdfmetadata's `xmp` namespace constant.
pub let pdf_metadata_xmp : String = pdf_metadata_xmp_namespace

///|
/// Source-spelled compatibility alias for cpdfmetadata's `xmp`.
pub let pdf_xmp : String = pdf_metadata_xmp_namespace

///|
/// Alias matching cpdfmetadata's `dc` namespace constant.
pub let pdf_metadata_dc : String = pdf_metadata_dc_namespace

///|
/// Source-spelled compatibility alias for cpdfmetadata's `dc`.
pub let pdf_dc : String = pdf_metadata_dc_namespace

///|
/// Alias matching cpdfmetadata's `rdf` namespace constant.
pub let pdf_metadata_rdf : String = pdf_metadata_rdf_namespace

///|
/// Source-spelled compatibility alias for cpdfmetadata's `rdf`.
pub let pdf_rdf : String = pdf_metadata_rdf_namespace

///|
/// Alias matching cpdfmetadata's `pdfaid` namespace constant.
pub let pdf_metadata_pdfaid : String = pdf_metadata_pdfaid_namespace

///|
/// Source-spelled compatibility alias for cpdfmetadata's `pdfaid`.
pub let pdf_pdfaid : String = pdf_metadata_pdfaid_namespace

///|
/// Alias matching cpdfmetadata's `pdfxid` namespace constant.
pub let pdf_metadata_pdfxid : String = pdf_metadata_pdfxid_namespace

///|
/// Source-spelled compatibility alias for cpdfmetadata's `pdfxid`.
pub let pdf_pdfxid : String = pdf_metadata_pdfxid_namespace

///|
/// Alias matching cpdfmetadata's `pdfe` namespace constant.
pub let pdf_metadata_pdfe : String = pdf_metadata_pdfe_namespace

///|
/// Source-spelled compatibility alias for cpdfmetadata's `pdfe`.
pub let pdf_pdfe : String = pdf_metadata_pdfe_namespace

///|
/// Alias matching cpdfmetadata's `pdfuaid` namespace constant.
pub let pdf_metadata_pdfuaid : String = pdf_metadata_pdfuaid_namespace

///|
/// Source-spelled compatibility alias for cpdfmetadata's `pdfuaid`.
pub let pdf_pdfuaid : String = pdf_metadata_pdfuaid_namespace

///|
/// Alias matching cpdfmetadata's `pdfvtid` namespace constant.
pub let pdf_metadata_pdfvtid : String = pdf_metadata_pdfvtid_namespace

///|
/// Source-spelled compatibility alias for cpdfmetadata's `pdfvtid`.
pub let pdf_pdfvtid : String = pdf_metadata_pdfvtid_namespace

///|
/// Qualified XML name used by the metadata XML tree parser.
pub(all) struct PdfMetadataXmlName {
  uri : String
  local_name : String
  prefix : String?
} derive(Debug, Eq, ToJson)

///|
/// XML attribute used by the metadata XML tree parser.
pub(all) struct PdfMetadataXmlAttribute {
  name : PdfMetadataXmlName
  value : String
} derive(Debug, Eq, ToJson)

///|
/// XML element tag name and attributes used by metadata trees.
pub(all) struct PdfMetadataXmlTag {
  name : PdfMetadataXmlName
  attributes : Array[PdfMetadataXmlAttribute]
} derive(Debug, Eq, ToJson)

///|
/// Minimal XML tree representation used for XMP metadata.
pub(all) enum PdfMetadataXmlTree {
  PdfMetadataXmlElement(PdfMetadataXmlTag, Array[PdfMetadataXmlTree])
  PdfMetadataXmlData(String)
} derive(Debug, Eq, ToJson)

///|
/// Parsed XML metadata document with an optional DTD fragment.
pub(all) struct PdfMetadataXmlDocument {
  dtd : String?
  tree : PdfMetadataXmlTree
} derive(Debug, Eq, ToJson)

///|
let pdf_metadata_xml_uri : String = "http://www.w3.org/XML/1998/namespace"

///|
let pdf_metadata_xmlns_uri : String = "http://www.w3.org/2000/xmlns/"
