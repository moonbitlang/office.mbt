///|
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
pub let pdf_metadata_adobe_namespace : String = "http://ns.adobe.com/pdf/1.3/"

///|
pub let pdf_metadata_xmp_namespace : String = "http://ns.adobe.com/xap/1.0/"

///|
pub let pdf_metadata_dc_namespace : String = "http://purl.org/dc/elements/1.1/"

///|
pub let pdf_metadata_rdf_namespace : String = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"

///|
pub let pdf_metadata_pdfaid_namespace : String = "http://www.aiim.org/pdfa/ns/id/"

///|
let pdf_metadata_pdfaid_wrong_iso_namespace : String = "http://www.aiim.org/pdfa/ns/id"

///|
let pdf_metadata_pdfaid_wrong_acrobat_namespace : String = "http://www.aiim.org/pdfa/ns/id.html"

///|
pub let pdf_metadata_pdfxid_namespace : String = "http://www.npes.org/pdfx/ns/id/"

///|
pub let pdf_metadata_pdfe_namespace : String = "http://www.aiim.org/pdfe/ns/id/"

///|
pub let pdf_metadata_pdfuaid_namespace : String = "http://www.aiim.org/pdfua/ns/id/"

///|
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
pub(all) struct PdfMetadataXmlName {
  uri : String
  local_name : String
  prefix : String?
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfMetadataXmlAttribute {
  name : PdfMetadataXmlName
  value : String
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfMetadataXmlTag {
  name : PdfMetadataXmlName
  attributes : Array[PdfMetadataXmlAttribute]
} derive(Debug, Eq, ToJson)

///|
pub(all) enum PdfMetadataXmlTree {
  PdfMetadataXmlElement(PdfMetadataXmlTag, Array[PdfMetadataXmlTree])
  PdfMetadataXmlData(String)
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfMetadataXmlDocument {
  dtd : String?
  tree : PdfMetadataXmlTree
} derive(Debug, Eq, ToJson)

///|
let pdf_metadata_xml_uri : String = "http://www.w3.org/XML/1998/namespace"

///|
let pdf_metadata_xmlns_uri : String = "http://www.w3.org/2000/xmlns/"

///|
let pdf_metadata_xmp_template : String =
  #|<?xpacket begin='' id='W5M0MpCehiHzreSzNTczkc9d'?>
  #|<x:xmpmeta xmlns:x="adobe:ns:meta/">
  #|
  #|<rdf:RDF xmlns:rdf='http://www.w3.org/1999/02/22-rdf-syntax-ns#'
  #| xmlns:iX='http://ns.adobe.com/iX/1.0/'>
  #|
  #| <rdf:Description about=''
  #|  xmlns='http://ns.adobe.com/pdf/1.3/'
  #|  xmlns:pdf='http://ns.adobe.com/pdf/1.3/'>
  #|  <pdf:CreationDate>CREATEDATE</pdf:CreationDate>
  #|  <pdf:ModDate>MODDATE</pdf:ModDate>
  #|  <pdf:Producer>PRODUCER</pdf:Producer>
  #|  <pdf:Creator>CREATOR</pdf:Creator>
  #|  <pdf:Title>TITLE</pdf:Title>
  #|  <pdf:Subject>SUBJECT</pdf:Subject>
  #|  <pdf:Author>AUTHOR</pdf:Author>
  #|  <pdf:Keywords>KEYWORDS</pdf:Keywords>
  #|  <pdf:Trapped>TRAPPED</pdf:Trapped>
  #| </rdf:Description>
  #|
  #| <rdf:Description about=''
  #|  xmlns='http://ns.adobe.com/xap/1.0/'
  #|  xmlns:xap='http://ns.adobe.com/xap/1.0/'>
  #|   <xap:CreateDate>CREATEDATE</xap:CreateDate>
  #|   <xap:CreatorTool>CREATOR</xap:CreatorTool>
  #|   <xap:ModifyDate>MODDATE</xap:ModifyDate>
  #|   <xap:MetadataDate>METADATADATE</xap:MetadataDate>
  #| </rdf:Description>
  #|
  #| <rdf:Description about=''
  #|  xmlns='http://purl.org/dc/elements/1.1/'
  #|  xmlns:dc='http://purl.org/dc/elements/1.1/'>
  #|   <dc:title>
  #|   <rdf:Alt>
  #|     <rdf:li xml:lang='x-default'>TITLE</rdf:li>
  #|   </rdf:Alt>
  #|   </dc:title>
  #| </rdf:Description>
  #|
  #|</rdf:RDF>
  #|
  #|</x:xmpmeta>
  #|
  #|<?xpacket end='r'?>

///|
fn pdf_metadata_bool_string(value : Bool) -> String {
  if value {
    "True"
  } else {
    "False"
  }
}

///|
fn pdf_metadata_ascii_codepoints(bytes : BytesView) -> PdfBytes raise PdfError {
  let codepoints = pdf_codepoints_of_pdfdocstring(bytes)
  let mut output_length = 0
  for codepoint in codepoints {
    if codepoint <= 127 {
      output_length += 1
    }
  }
  let output = Array::make(output_length, b'\x00')
  let mut position = 0
  for codepoint in codepoints {
    if codepoint <= 127 {
      output[position] = pdf_byte_of_int(codepoint)
      position += 1
    }
  }
  Bytes::from_array(output)
}

///|
/// Encode a PDF string for metadata/reporting output.
pub fn pdf_metadata_encode_output(
  encoding : PdfMetadataEncoding,
  bytes : BytesView,
) -> PdfBytes raise PdfError {
  match encoding {
    PdfMetadataRaw => bytes.to_owned()
    PdfMetadataUTF8 => pdf_utf8_of_pdfdocstring(bytes)
    PdfMetadataStripped => pdf_metadata_ascii_codepoints(bytes)
  }
}

///|
/// Source-spelled compatibility alias for cpdfmetadata's `encode_output`.
pub fn pdf_encode_output(
  encoding : PdfMetadataEncoding,
  bytes : BytesView,
) -> PdfBytes raise PdfError {
  pdf_metadata_encode_output(encoding, bytes)
}

///|
fn PdfDocument::pdf_metadata_bump_minor(
  self : PdfDocument,
  version : Int,
  keep_version : Bool,
) -> Unit {
  if self.major == 1 && !keep_version && self.minor < version {
    self.minor = version
  }
}

///|
fn PdfDocument::pdf_metadata_replace_catalog(
  self : PdfDocument,
  catalog : PdfObject,
) -> Unit raise PdfError {
  let root_number = self.add_object(catalog)
  self.set_root(root_number)
  self.set_trailer_dict(
    self
    .trailer_dict()
    .add_dict_entry(pdf_metadata_root(), PdfIndirect(root_number)),
  )
}

///|
fn PdfDocument::pdf_metadata_update_catalog(
  self : PdfDocument,
  update : (PdfObject) -> PdfObject raise PdfError,
) -> Unit raise PdfError {
  let catalog = self.catalog()
  self.pdf_metadata_replace_catalog(update(catalog))
}

///|
fn pdf_metadata_name_string(name : PdfName) -> String raise PdfError {
  let bytes = name.bytes()
  let start = if bytes.length() > 0 && bytes[0].to_int() == 47 { 1 } else { 0 }
  @ascii.decode(bytes[start:]) catch {
    _ => raise InvalidUTF8
  }
}

///|
fn pdf_metadata_known_name(
  value : String,
  allowed : ArrayView[String],
  error_prefix : String,
) -> PdfName raise PdfError {
  for allowed_value in allowed {
    if value == allowed_value {
      break pdf_metadata_name("/" + value)
    }
  } nobreak {
    raise BadNumberArgument(error_prefix + value)
  }
}

///|
/// Copy the trailer `/ID` from `source` onto this document.
///
/// The original document is left unchanged. When `keep_version` is false, PDF
/// 1.x outputs are bumped to at least 1.1, matching cpdf.
pub fn PdfDocument::copy_id_from(
  self : PdfDocument,
  source : PdfDocument,
  keep_version? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  match source.lookup_direct(pdf_metadata_id(), source.trailer_dict()) {
    Some(id) => {
      document.set_trailer_dict(
        document.trailer_dict().add_dict_entry(pdf_metadata_id(), id),
      )
      document.pdf_metadata_bump_minor(1, keep_version)
      document
    }
    None => document
  }
}

///|
/// Set or replace one `/Info` dictionary entry.
pub fn PdfDocument::set_info_entry(
  self : PdfDocument,
  key : PdfName,
  value : PdfObject,
  version : Int,
  keep_version? : Bool = false,
  xmp_also? : Bool = false,
  xmp_just_set? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = if xmp_just_set {
    self
  } else {
    let document = self.copy()
    let info = match
      document.lookup_direct(pdf_metadata_info(), document.trailer_dict()) {
      Some(dictionary) => dictionary
      None => PdfDictionary([])
    }
    let info_number = document.add_object(info.add_dict_entry(key, value))
    document.set_trailer_dict(
      document
      .trailer_dict()
      .add_dict_entry(pdf_metadata_info(), PdfIndirect(info_number)),
    )
    document.pdf_metadata_bump_minor(version, keep_version)
    document
  }
  if !xmp_also {
    document
  } else {
    match document.metadata() {
      None => document
      Some(metadata) => {
        let (changes, replacement) = pdf_metadata_info_xmp_changes(key, value)
        let mut updated = metadata
        for change in changes {
          updated = pdf_metadata_rewrite_xmp_field(
            updated,
            change.0,
            pdf_metadata_namespace_fallback_prefix(change.0),
            change.1,
            replacement,
          )
        }
        document.set_metadata_from_bytes(updated, keep_version=true)
      }
    }
  }
}

///|
/// Set or replace one `/Info` entry from cpdf's string-key tuple form.
pub fn PdfDocument::set_info_entry_string(
  self : PdfDocument,
  entry : (String, PdfObject, Int),
  keep_version? : Bool = false,
  xmp_also? : Bool = false,
  xmp_just_set? : Bool = false,
) -> PdfDocument raise PdfError {
  self.set_info_entry(
    pdf_metadata_source_key_name(entry.0),
    entry.1,
    entry.2,
    keep_version~,
    xmp_also~,
    xmp_just_set~,
  )
}

///|
/// Return one `/Info` dictionary entry as a UTF-8 string.
pub fn PdfDocument::info_utf8(self : PdfDocument, key : PdfName) -> String {
  let info = match
    self.lookup_direct(pdf_metadata_info(), self.trailer_dict()) {
    Some(dictionary) => dictionary
    None => PdfDictionary([])
  }
  match self.lookup_direct(key, info) {
    Some(PdfString(bytes)) =>
      @utf8.decode(pdf_utf8_of_pdfdocstring(bytes)) catch {
        _ => ""
      }
    Some(PdfBoolean(value)) => pdf_metadata_bool_string(value)
    _ => if key == pdf_metadata_trapped() { "False" } else { "" }
  }
}

///|
/// Return one cpdf-style slash-prefixed string-key `/Info` entry as UTF-8.
pub fn PdfDocument::info_utf8_string(
  self : PdfDocument,
  key : String,
) -> String {
  self.info_utf8(pdf_metadata_source_key_name(key))
}

///|
/// Set or replace one `/ViewerPreferences` dictionary entry.
pub fn PdfDocument::set_viewer_preference(
  self : PdfDocument,
  key : PdfName,
  value : PdfObject,
  version : Int,
  keep_version? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise PdfError {
    let preferences = match
      document.lookup_direct(pdf_metadata_viewer_preferences(), catalog) {
      Some(dictionary) => dictionary
      None => PdfDictionary([])
    }
    catalog.add_dict_entry(
      pdf_metadata_viewer_preferences(),
      preferences.add_dict_entry(key, value),
    )
  })
  document.pdf_metadata_bump_minor(version, keep_version)
  document
}

///|
/// Set one `/ViewerPreferences` entry from cpdf's string-key tuple form.
pub fn PdfDocument::set_viewer_preference_string(
  self : PdfDocument,
  entry : (String, PdfObject, Int),
) -> PdfDocument raise PdfError {
  self.set_viewer_preference(
    pdf_metadata_source_key_name(entry.0),
    entry.1,
    entry.2,
  )
}

///|
/// Set the catalog `/PageLayout` value using a name without the leading slash.
pub fn PdfDocument::set_page_layout(
  self : PdfDocument,
  layout : String,
) -> PdfDocument raise PdfError {
  let name = pdf_metadata_known_name(
    layout,
    [
      "SinglePage", "OneColumn", "TwoColumnLeft", "TwoColumnRight", "TwoPageLeft",
      "TwoPageRight",
    ],
    "Unknown page layout: ",
  )
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise PdfError {
    catalog.add_dict_entry(pdf_metadata_page_layout(), PdfNameObject(name))
  })
  document
}

///|
/// Set the catalog `/PageMode` value using a name without the leading slash.
pub fn PdfDocument::set_page_mode(
  self : PdfDocument,
  mode : String,
) -> PdfDocument raise PdfError {
  let name = pdf_metadata_known_name(
    mode,
    [
      "UseNone", "UseOutlines", "UseThumbs", "FullScreen", "UseOC", "UseAttachments",
    ],
    "Unknown page mode: ",
  )
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise PdfError {
    catalog.add_dict_entry(pdf_metadata_page_mode(), PdfNameObject(name))
  })
  document
}

///|
/// Set `/ViewerPreferences /NonFullScreenPageMode`.
pub fn PdfDocument::set_non_full_screen_page_mode(
  self : PdfDocument,
  mode : String,
) -> PdfDocument raise PdfError {
  let name = pdf_metadata_known_name(
    mode,
    ["UseNone", "UseOutlines", "UseThumbs", "UseOC", "UseAttachments"],
    "Unknown non full screen page mode: ",
  )
  self.set_viewer_preference(
    pdf_metadata_non_full_screen_page_mode(),
    PdfNameObject(name),
    2,
  )
}

///|
fn PdfDocument::pdf_metadata_rewrite_destination_page(
  self : PdfDocument,
  destination : PdfObject,
) -> PdfObject raise PdfError {
  match destination {
    PdfArray(values) =>
      match values {
        [PdfInteger(page_number), .. rest] => {
          let page_numbers = self.page_reference_numbers()
          if page_number < 1 || page_number > page_numbers.length() {
            raise BadPageSpecification(page_number.to_string())
          }
          PdfArray([PdfIndirect(page_numbers[page_number - 1]), ..rest])
        }
        _ => destination
      }
    _ => destination
  }
}

///|
fn pdf_metadata_parse_open_action_destination(
  destination : String,
) -> PdfObject raise PdfError {
  let parsed : Result[PdfObject, Error] = try? pdf_parse_object_from_bytes(
    @ascii.encode(destination),
  )
  match parsed {
    Ok(object) =>
      match object {
        PdfArray([PdfInteger(_), ..]) => object
        _ => raise BadNumberArgument("Bad destination syntax")
      }
    Err(_) => raise BadNumberArgument("Bad destination syntax")
  }
}

///|
/// Set the catalog `/OpenAction` to a GoTo action.
///
/// `page_number` is one-based. When `destination` is supplied and starts with a
/// page number integer, that integer is rewritten to the corresponding page
/// indirect reference.
pub fn PdfDocument::set_open_action(
  self : PdfDocument,
  page_number : Int,
  fit? : Bool = true,
  destination? : PdfObject? = None,
) -> PdfDocument raise PdfError {
  let page_numbers = self.page_reference_numbers()
  if page_number < 1 || page_number > page_numbers.length() {
    raise BadPageSpecification(page_number.to_string())
  }
  let destination = match destination {
    Some(value) => self.pdf_metadata_rewrite_destination_page(value)
    None =>
      if fit {
        PdfArray([
          PdfIndirect(page_numbers[page_number - 1]),
          PdfNameObject(pdf_metadata_fit()),
        ])
      } else {
        PdfArray([
          PdfIndirect(page_numbers[page_number - 1]),
          PdfNameObject(pdf_metadata_xyz()),
          PdfNull,
          PdfNull,
          PdfNull,
        ])
      }
  }
  let open_action = PdfDictionary([
    (pdf_metadata_d(), destination),
    (pdf_metadata_s(), PdfNameObject(pdf_metadata_goto())),
  ])
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise PdfError {
    catalog.add_dict_entry(pdf_metadata_open_action(), open_action)
  })
  document
}

///|
/// Set the catalog `/OpenAction` from cpdf-style PDF destination syntax.
pub fn PdfDocument::set_open_action_string_destination(
  self : PdfDocument,
  page_number : Int,
  fit? : Bool = true,
  destination? : String? = None,
) -> PdfDocument raise PdfError {
  let destination_object = match destination {
    Some(value) => Some(pdf_metadata_parse_open_action_destination(value))
    None => None
  }
  self.set_open_action(page_number, fit~, destination=destination_object)
}

///|
/// Return a catalog item in cpdf's text-reporting form.
pub fn PdfDocument::catalog_item(self : PdfDocument, key : PdfName) -> String {
  try self.catalog() catch {
    _ => ""
  } noraise {
    catalog =>
      match self.lookup_direct(key, catalog) {
        Some(PdfNameObject(name)) =>
          pdf_metadata_name_string(name) catch {
            _ => ""
          }
        Some(PdfDictionary(_)) => "True"
        _ => ""
      }
  }
}

///|
/// Return a catalog item for a cpdf-style slash-prefixed string key.
pub fn PdfDocument::catalog_item_string(
  self : PdfDocument,
  key : String,
) -> String {
  self.catalog_item(pdf_metadata_source_key_name(key))
}

///|
/// Return a viewer-preference item in cpdf's text-reporting form.
pub fn PdfDocument::viewer_preference_item(
  self : PdfDocument,
  key : PdfName,
) -> String {
  try self.catalog() catch {
    _ => ""
  } noraise {
    catalog =>
      match self.lookup_direct(pdf_metadata_viewer_preferences(), catalog) {
        Some(preferences) =>
          match self.lookup_direct(key, preferences) {
            Some(PdfNameObject(name)) =>
              pdf_metadata_name_string(name) catch {
                _ => ""
              }
            Some(PdfBoolean(value)) => if value { "true" } else { "false" }
            _ => ""
          }
        None => ""
      }
  }
}

///|
/// Return a viewer-preference item for a cpdf-style slash-prefixed string key.
pub fn PdfDocument::viewer_preference_item_string(
  self : PdfDocument,
  key : String,
) -> String {
  self.viewer_preference_item(pdf_metadata_source_key_name(key))
}

///|
/// Return a `/MarkInfo` boolean item, or false when absent/malformed.
pub fn PdfDocument::mark_info_item(self : PdfDocument, key : PdfName) -> Bool {
  try self.catalog() catch {
    _ => false
  } noraise {
    catalog =>
      match self.lookup_direct(pdf_metadata_mark_info(), catalog) {
        Some(mark_info) =>
          match self.lookup_direct(key, mark_info) {
            Some(PdfBoolean(value)) => value
            _ => false
          }
        None => false
      }
  }
}

///|
/// Return true when the catalog contains an AcroForm XFA entry.
pub fn PdfDocument::is_xfa(self : PdfDocument) -> Bool {
  self.lookup_chain(self.trailer_dict(), [
    pdf_metadata_root(),
    pdf_metadata_acroform(),
    pdf_metadata_xfa(),
  ]) !=
  None
}

///|
fn PdfDocument::pdf_metadata_page_number_for_reference(
  self : PdfDocument,
  reference : Int,
) -> Int? raise PdfError {
  let page_numbers = self.page_reference_numbers()
  for index in 0..<page_numbers.length() {
    if page_numbers[index] == reference {
      break Some(index + 1)
    }
  } nobreak {
    None
  }
}

///|
fn PdfDocument::pdf_metadata_rewrite_open_action_page(
  self : PdfDocument,
  action : PdfObject,
) -> PdfObject raise PdfError {
  match action {
    PdfArray([PdfIndirect(reference), .. rest]) =>
      match self.pdf_metadata_page_number_for_reference(reference) {
        Some(page_number) => PdfArray([PdfInteger(page_number), ..rest])
        None => action
      }
    _ => action
  }
}

///|
/// Return the catalog `/OpenAction` in cpdf's reporting form.
///
/// Destination arrays beginning with a page indirect reference are rewritten
/// to one-based page numbers. For GoTo action dictionaries with `/D`, the
/// destination is returned; other action objects are returned unchanged.
pub fn PdfDocument::open_action(self : PdfDocument) -> PdfObject raise PdfError {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_metadata_root(),
      pdf_metadata_open_action(),
    ]) {
    Some(PdfArray(_) as action) =>
      self.pdf_metadata_rewrite_open_action_page(action)
    Some(PdfDictionary(_) as action) =>
      match self.lookup_direct(pdf_metadata_d(), action) {
        Some(PdfArray(_) as destination) =>
          self.pdf_metadata_rewrite_open_action_page(destination)
        _ => action
      }
    Some(action) => action
    None => PdfNull
  }
}

///|
/// Return the catalog `/OpenAction` as cpdf-style JSON bytes.
pub fn PdfDocument::open_action_json_blob(
  self : PdfDocument,
) -> PdfBytes raise PdfError {
  @utf8.encode(
    self
    .pdf_util_json_of_object(
      self.open_action(),
      true,
      false,
      false,
      false,
      false,
    )
    .stringify(),
  )
}

///|
/// Return the catalog `/OpenAction` as cpdf-style PDF syntax.
pub fn PdfDocument::open_action_string(
  self : PdfDocument,
) -> String raise PdfError {
  match self.open_action() {
    PdfNull => ""
    action =>
      @ascii.decode(pdf_write_object(action)) catch {
        _ => raise InvalidUTF8
      }
  }
}

///|
fn pdf_metadata_is_xml_separator(byte : Byte) -> Bool {
  match byte.to_int() {
    9 | 10 | 13 | 32 | 60 => true
    _ => false
  }
}

///|
fn pdf_metadata_is_xml_space(byte : Byte) -> Bool {
  match byte.to_int() {
    9 | 10 | 13 | 32 => true
    _ => false
  }
}

///|
fn pdf_metadata_trim_xml_text(value : BytesView) -> BytesView {
  let mut start = 0
  let mut end = value.length()
  while start < end && pdf_metadata_is_xml_space(value[start]) {
    start += 1
  }
  while end > start && pdf_metadata_is_xml_space(value[end - 1]) {
    end -= 1
  }
  value[start:end]
}

///|
fn pdf_metadata_xml_entity_digit(byte : Byte, base : Int) -> Int? {
  let value = byte.to_int()
  if value >= 48 && value <= 57 {
    let digit = value - 48
    if digit < base {
      Some(digit)
    } else {
      None
    }
  } else if base == 16 && value >= 65 && value <= 70 {
    Some(value - 55)
  } else if base == 16 && value >= 97 && value <= 102 {
    Some(value - 87)
  } else {
    None
  }
}

///|
fn pdf_metadata_xml_entity_codepoint(entity : BytesView) -> Int? {
  if entity.length() == 3 && pdf_metadata_view_matches_at(entity, 0, b"amp") {
    Some(38)
  } else if entity.length() == 2 &&
    pdf_metadata_view_matches_at(entity, 0, b"lt") {
    Some(60)
  } else if entity.length() == 2 &&
    pdf_metadata_view_matches_at(entity, 0, b"gt") {
    Some(62)
  } else if entity.length() == 4 &&
    pdf_metadata_view_matches_at(entity, 0, b"quot") {
    Some(34)
  } else if entity.length() == 4 &&
    pdf_metadata_view_matches_at(entity, 0, b"apos") {
    Some(39)
  } else if entity.length() >= 2 && entity[0].to_int() == 35 {
    let mut index = 1
    let mut base = 10
    if index < entity.length() &&
      (entity[index].to_int() == 120 || entity[index].to_int() == 88) {
      base = 16
      index += 1
    }
    if index >= entity.length() {
      return None
    }
    let mut codepoint = 0
    while index < entity.length() {
      match pdf_metadata_xml_entity_digit(entity[index], base) {
        Some(digit) => codepoint = codepoint * base + digit
        None => return None
      }
      if codepoint > 0x10FFFF {
        return None
      }
      index += 1
    }
    if codepoint >= 0xD800 && codepoint <= 0xDFFF {
      None
    } else {
      Some(codepoint)
    }
  } else {
    None
  }
}

///|
fn pdf_metadata_push_xml_codepoint(
  output : Array[Byte],
  codepoint : Int,
) -> Bool {
  let encoded = pdf_utf8_of_codepoints([codepoint]) catch { _ => return false }
  for byte in encoded {
    output.push(byte)
  }
  true
}

///|
fn pdf_metadata_xml_codepoint_is_space(codepoint : Int) -> Bool {
  codepoint == 9 || codepoint == 10 || codepoint == 13 || codepoint == 32
}

///|
fn pdf_metadata_decode_xml_text(value : BytesView) -> String? {
  let trimmed = pdf_metadata_trim_xml_text(value)
  let output : Array[Byte] = []
  let mut pending_space = false
  let mut index = 0
  while index < trimmed.length() {
    if trimmed[index].to_int() == 38 {
      let semicolon = pdf_metadata_find_byte(trimmed, index + 1, 59)
      if semicolon > index {
        match pdf_metadata_xml_entity_codepoint(trimmed[index + 1:semicolon]) {
          Some(codepoint) =>
            if pdf_metadata_xml_codepoint_is_space(codepoint) {
              if output.length() > 0 {
                pending_space = true
              }
              index = semicolon + 1
            } else {
              if pending_space {
                output.push(32)
                pending_space = false
              }
              if pdf_metadata_push_xml_codepoint(output, codepoint) {
                index = semicolon + 1
              } else {
                output.push(trimmed[index])
                index += 1
              }
            }
          _ => {
            if pending_space {
              output.push(32)
              pending_space = false
            }
            output.push(trimmed[index])
            index += 1
          }
        }
      } else {
        if pending_space {
          output.push(32)
          pending_space = false
        }
        output.push(trimmed[index])
        index += 1
      }
    } else if pdf_metadata_is_xml_space(trimmed[index]) {
      if output.length() > 0 {
        pending_space = true
      }
      index += 1
    } else {
      if pending_space {
        output.push(32)
        pending_space = false
      }
      output.push(trimmed[index])
      index += 1
    }
  }
  let text = @utf8.decode(Bytes::from_array(output)) catch { _ => return None }
  Some(text)
}

///|
fn pdf_metadata_xml_decode_name(value : BytesView) -> String raise PdfError {
  @utf8.decode(value) catch {
    _ => raise InvalidUTF8
  }
}

///|
fn pdf_metadata_xml_is_name_boundary(byte : Byte) -> Bool {
  let value = byte.to_int()
  value == 9 ||
  value == 10 ||
  value == 13 ||
  value == 32 ||
  value == 47 ||
  value == 61 ||
  value == 62
}

///|
fn pdf_metadata_xml_skip_space(data : BytesView, start : Int) -> Int {
  let mut index = start
  while index < data.length() && pdf_metadata_is_xml_space(data[index]) {
    index += 1
  }
  index
}

///|
fn pdf_metadata_xml_read_name(
  data : BytesView,
  start : Int,
) -> (Bytes, Int) raise PdfError {
  let mut index = start
  while index < data.length() && !pdf_metadata_xml_is_name_boundary(data[index]) {
    index += 1
  }
  guard index > start else { raise BadText }
  (data[start:index].to_owned(), index)
}

///|
fn pdf_metadata_xml_uri_lookup(
  context : ArrayView[(String, String)],
  prefix : String,
) -> String? {
  for index = context.length() - 1; index >= 0; index = index - 1 {
    if context[index].0 == prefix {
      break Some(context[index].1)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_metadata_xml_resolve_name(
  qname : BytesView,
  is_attribute : Bool,
  context : ArrayView[(String, String)],
) -> PdfMetadataXmlName raise PdfError {
  let colon = pdf_metadata_find_byte(qname, 0, 58)
  if colon >= 0 {
    let prefix = pdf_metadata_xml_decode_name(qname[:colon])
    let local_name = pdf_metadata_xml_decode_name(qname[colon + 1:])
    let uri = if prefix == "xml" {
      pdf_metadata_xml_uri
    } else if prefix == "xmlns" {
      pdf_metadata_xmlns_uri
    } else {
      match pdf_metadata_xml_uri_lookup(context, prefix) {
        Some(uri) => uri
        None => raise BadText
      }
    }
    { uri, local_name, prefix: Some(prefix) }
  } else {
    let local_name = pdf_metadata_xml_decode_name(qname)
    let uri = if is_attribute {
      if local_name == "xmlns" {
        pdf_metadata_xmlns_uri
      } else {
        ""
      }
    } else {
      match pdf_metadata_xml_uri_lookup(context, "") {
        Some(uri) => uri
        None => ""
      }
    }
    { uri, local_name, prefix: None }
  }
}

///|
fn pdf_metadata_xml_parse_raw_attributes(
  data : BytesView,
  start : Int,
) -> Array[(Bytes, String)] raise PdfError {
  let attributes : Array[(Bytes, String)] = []
  let mut index = start
  while index < data.length() {
    index = pdf_metadata_xml_skip_space(data, index)
    if index >= data.length() {
      break
    }
    let (name, after_name) = pdf_metadata_xml_read_name(data, index)
    index = pdf_metadata_xml_skip_space(data, after_name)
    guard index < data.length() && data[index].to_int() == 61 else {
      raise BadText
    }
    index = pdf_metadata_xml_skip_space(data, index + 1)
    guard index < data.length() &&
      (data[index].to_int() == 34 || data[index].to_int() == 39) else {
      raise BadText
    }
    let quote = data[index].to_int()
    let value_start = index + 1
    let value_end = pdf_metadata_find_byte(data, value_start, quote)
    guard value_end >= 0 else { raise BadText }
    let value = match
      pdf_metadata_decode_xml_text(data[value_start:value_end]) {
      Some(value) => value
      None => raise InvalidUTF8
    }
    attributes.push((name, value))
    index = value_end + 1
  }
  attributes
}

///|
fn pdf_metadata_xml_context_with_attributes(
  context : ArrayView[(String, String)],
  attributes : ArrayView[(Bytes, String)],
) -> Array[(String, String)] raise PdfError {
  let output = context.to_owned()
  for attribute in attributes {
    let name = attribute.0[:]
    if name.length() == 5 && pdf_metadata_view_matches_at(name, 0, b"xmlns") {
      output.push(("", attribute.1))
    } else if name.length() > 6 &&
      pdf_metadata_view_matches_at(name, 0, b"xmlns:") {
      output.push((pdf_metadata_xml_decode_name(name[6:]), attribute.1))
    }
  }
  output
}

///|
fn pdf_metadata_xml_tag_from_raw(
  name : BytesView,
  attributes : ArrayView[(Bytes, String)],
  context : ArrayView[(String, String)],
) -> PdfMetadataXmlTag raise PdfError {
  let resolved_attributes : Array[PdfMetadataXmlAttribute] = []
  for attribute in attributes {
    resolved_attributes.push({
      name: pdf_metadata_xml_resolve_name(attribute.0[:], true, context),
      value: attribute.1,
    })
  }
  {
    name: pdf_metadata_xml_resolve_name(name, false, context),
    attributes: resolved_attributes,
  }
}

///|
fn pdf_metadata_xml_find_tag_end(
  data : BytesView,
  start : Int,
) -> Int raise PdfError {
  let mut index = start
  let mut quote = 0
  while index < data.length() {
    let value = data[index].to_int()
    if quote != 0 {
      if value == quote {
        quote = 0
      }
    } else if value == 34 || value == 39 {
      quote = value
    } else if value == 62 {
      return index
    }
    index += 1
  }
  raise BadText
}

///|
fn pdf_metadata_xml_is_self_closing_tag(data : BytesView, end : Int) -> Bool {
  let mut index = end - 1
  while index >= 0 && pdf_metadata_is_xml_space(data[index]) {
    index -= 1
  }
  index >= 0 && data[index].to_int() == 47
}

///|
fn pdf_metadata_xml_parse_start_tag(
  data : BytesView,
  start : Int,
  context : ArrayView[(String, String)],
) -> (String, PdfMetadataXmlTag, Array[(String, String)], Bool, Int) raise PdfError {
  guard start < data.length() && data[start].to_int() == 60 else {
    raise BadText
  }
  let tag_end = pdf_metadata_xml_find_tag_end(data, start + 1)
  let self_closing = pdf_metadata_xml_is_self_closing_tag(data, tag_end)
  let body_end = if self_closing {
    let mut index = tag_end - 1
    while index >= start + 1 && pdf_metadata_is_xml_space(data[index]) {
      index -= 1
    }
    index
  } else {
    tag_end
  }
  guard body_end > start else { raise BadText }
  let body = data[start + 1:body_end]
  let body_start = pdf_metadata_xml_skip_space(body, 0)
  let (qname, after_name) = pdf_metadata_xml_read_name(body, body_start)
  let raw_attributes = pdf_metadata_xml_parse_raw_attributes(body, after_name)
  let next_context = pdf_metadata_xml_context_with_attributes(
    context, raw_attributes,
  )
  let tag = pdf_metadata_xml_tag_from_raw(
    qname[:],
    raw_attributes,
    next_context,
  )
  (
    pdf_metadata_xml_decode_name(qname[:]),
    tag,
    next_context,
    self_closing,
    tag_end + 1,
  )
}

///|
fn pdf_metadata_xml_parse_close_tag(
  data : BytesView,
  start : Int,
) -> (String, Int) raise PdfError {
  guard start + 1 < data.length() &&
    data[start].to_int() == 60 &&
    data[start + 1].to_int() == 47 else {
    raise BadText
  }
  let end = pdf_metadata_find_byte(data, start + 2, 62)
  guard end >= 0 else { raise BadText }
  let name = match pdf_metadata_decode_xml_text(data[start + 2:end]) {
    Some(name) => name
    None => raise InvalidUTF8
  }
  (name, end + 1)
}

///|
fn pdf_metadata_xml_skip_processing_instruction(
  data : BytesView,
  start : Int,
) -> Int raise PdfError {
  let end = pdf_metadata_find_bytes_from(data, start + 2, b"?>")
  guard end >= 0 else { raise BadText }
  end + 2
}

///|
fn pdf_metadata_xml_skip_comment(
  data : BytesView,
  start : Int,
) -> Int raise PdfError {
  let end = pdf_metadata_find_bytes_from(data, start + 4, b"-->")
  guard end >= 0 else { raise BadText }
  end + 3
}

///|
fn pdf_metadata_xml_skip_misc(
  data : BytesView,
  start : Int,
) -> Int raise PdfError {
  let mut index = start
  let mut done = false
  while !done {
    index = pdf_metadata_xml_skip_space(data, index)
    if index + 1 < data.length() &&
      pdf_metadata_view_matches_at(data, index, b"<?") {
      index = pdf_metadata_xml_skip_processing_instruction(data, index)
    } else if index + 3 < data.length() &&
      pdf_metadata_view_matches_at(data, index, b"<!--") {
      index = pdf_metadata_xml_skip_comment(data, index)
    } else {
      done = true
    }
  }
  index
}

///|
fn pdf_metadata_xml_parse_dtd(
  data : BytesView,
  start : Int,
) -> (String?, Int) raise PdfError {
  let index = pdf_metadata_xml_skip_misc(data, start)
  if index + 8 < data.length() &&
    pdf_metadata_view_matches_at(data, index, b"<!DOCTYPE") {
    let end = pdf_metadata_xml_find_tag_end(data, index + 2)
    let text = @utf8.decode(data[index:end + 1]) catch {
      _ => raise InvalidUTF8
    }
    (Some(text), end + 1)
  } else {
    (None, index)
  }
}

///|
fn pdf_metadata_xml_parse_element(
  data : BytesView,
  start : Int,
  context : ArrayView[(String, String)],
) -> (PdfMetadataXmlTree, Int) raise PdfError {
  let (qualified_name, tag, child_context, self_closing, after_tag) = pdf_metadata_xml_parse_start_tag(
    data, start, context,
  )
  if self_closing {
    (PdfMetadataXmlElement(tag, []), after_tag)
  } else {
    let children : Array[PdfMetadataXmlTree] = []
    let mut index = after_tag
    let mut closed = false
    while !closed {
      guard index < data.length() else { raise BadText }
      if pdf_metadata_view_matches_at(data, index, b"</") {
        let (close_name, after_close) = pdf_metadata_xml_parse_close_tag(
          data, index,
        )
        guard close_name == qualified_name else { raise BadText }
        index = after_close
        closed = true
      } else if pdf_metadata_view_matches_at(data, index, b"<!--") {
        index = pdf_metadata_xml_skip_comment(data, index)
      } else if pdf_metadata_view_matches_at(data, index, b"<?") {
        index = pdf_metadata_xml_skip_processing_instruction(data, index)
      } else if data[index].to_int() == 60 {
        let (child, after_child) = pdf_metadata_xml_parse_element(
          data, index, child_context,
        )
        children.push(child)
        index = after_child
      } else {
        let next_tag = pdf_metadata_find_byte(data, index, 60)
        let data_end = if next_tag >= 0 { next_tag } else { data.length() }
        match pdf_metadata_decode_xml_text(data[index:data_end]) {
          Some(text) if text != "" => children.push(PdfMetadataXmlData(text))
          Some(_) => ()
          None => raise InvalidUTF8
        }
        index = data_end
      }
    }
    (PdfMetadataXmlElement(tag, children), index)
  }
}

///|
/// Parse metadata XML bytes into a cpdfmetadata-style XML tree.
///
/// This parser is intentionally scoped to the XML/XMP subset used by PDF
/// metadata: elements, attributes, namespaces, comments, processing
/// instructions, optional DTD text, text data, and predefined or numeric XML
/// entities.
pub fn pdf_metadata_xmltree_of_bytes(
  metadata : BytesView,
) -> PdfMetadataXmlDocument raise PdfError {
  let (dtd, after_dtd) = pdf_metadata_xml_parse_dtd(metadata, 0)
  let root_start = pdf_metadata_xml_skip_misc(metadata, after_dtd)
  guard root_start < metadata.length() && metadata[root_start].to_int() == 60 else {
    raise BadText
  }
  let (tree, after_tree) = pdf_metadata_xml_parse_element(
    metadata,
    root_start,
    [],
  )
  let end = pdf_metadata_xml_skip_misc(metadata, after_tree)
  guard end == metadata.length() else { raise BadText }
  { dtd, tree }
}

///|
/// Source-spelled compatibility alias for cpdfmetadata's `xmltree_of_bytes`.
pub fn pdf_xmltree_of_bytes(
  metadata : BytesView,
) -> PdfMetadataXmlDocument raise PdfError {
  pdf_metadata_xmltree_of_bytes(metadata)
}

///|
fn pdf_metadata_find_byte(data : BytesView, start : Int, byte : Int) -> Int {
  for position = start; position < data.length(); position = position + 1 {
    if data[position].to_int() == byte {
      break position
    }
  } nobreak {
    -1
  }
}

///|
fn pdf_metadata_view_matches_at(
  data : BytesView,
  position : Int,
  pattern : BytesView,
) -> Bool {
  if position < 0 || position + pattern.length() > data.length() {
    false
  } else {
    for index = 0; index < pattern.length(); index = index + 1 {
      if data[position + index] != pattern[index] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn pdf_metadata_find_bytes_from(
  data : BytesView,
  start : Int,
  pattern : BytesView,
) -> Int {
  if pattern.length() == 0 {
    start
  } else if data.length() < pattern.length() ||
    start > data.length() - pattern.length() {
    -1
  } else {
    for position = start
        position <= data.length() - pattern.length()
        position = position + 1 {
      if pdf_metadata_view_matches_at(data, position, pattern) {
        break position
      }
    } nobreak {
      -1
    }
  }
}

///|
fn pdf_metadata_add_unique(values : Array[String], value : String) -> Unit {
  if value != "" && !values.contains(value) {
    values.push(value)
  }
}

///|
fn pdf_metadata_namespace_prefixes(
  data : BytesView,
  xml_uri : String,
  fallback : String,
) -> Array[String] {
  let prefixes : Array[String] = []
  pdf_metadata_add_unique(prefixes, fallback)
  let namespace_bytes = @ascii.encode(xml_uri)
  let xmlns = [120, 109, 108, 110, 115, 58]
  let mut search_start = 0
  while search_start < data.length() {
    let namespace_start = pdf_metadata_find_bytes_from(
      data, search_start, namespace_bytes,
    )
    if namespace_start < 0 {
      search_start = data.length()
    } else {
      let mut attribute_start = namespace_start
      while attribute_start > 0 &&
            !pdf_metadata_is_xml_separator(data[attribute_start - 1]) {
        attribute_start -= 1
      }
      if pdf_view_matches_ascii_at(data, attribute_start, xmlns) {
        let prefix_start = attribute_start + xmlns.length()
        let mut prefix_end = prefix_start
        while prefix_end < namespace_start &&
              data[prefix_end].to_int() != 61 &&
              data[prefix_end].to_int() != 34 &&
              data[prefix_end].to_int() != 39 {
          prefix_end += 1
        }
        match pdf_metadata_decode_xml_text(data[prefix_start:prefix_end]) {
          Some(prefix) => pdf_metadata_add_unique(prefixes, prefix)
          None => ()
        }
      }
      search_start = namespace_start + namespace_bytes.length()
    }
  }
  prefixes
}

///|
fn pdf_metadata_extract_quoted_xml_value(
  data : BytesView,
  start : Int,
  quote : Int,
) -> String? {
  let end = pdf_metadata_find_byte(data, start, quote)
  if end < 0 {
    None
  } else {
    pdf_metadata_decode_xml_text(data[start:end])
  }
}

///|
fn pdf_metadata_extract_xmp_attribute(
  data : BytesView,
  prefix : String,
  name : String,
) -> String? {
  let double_pattern = @ascii.encode(prefix + ":" + name + "=\"")
  let double_start = pdf_metadata_find_bytes_from(data, 0, double_pattern)
  if double_start >= 0 {
    pdf_metadata_extract_quoted_xml_value(
      data,
      double_start + double_pattern.length(),
      34,
    )
  } else {
    let single_pattern = @ascii.encode(prefix + ":" + name + "='")
    let single_start = pdf_metadata_find_bytes_from(data, 0, single_pattern)
    if single_start >= 0 {
      pdf_metadata_extract_quoted_xml_value(
        data,
        single_start + single_pattern.length(),
        39,
      )
    } else {
      None
    }
  }
}

///|
fn pdf_metadata_combine_list_items(values : ArrayView[String]) -> String {
  let mut output = ""
  for value in values {
    if output == "" {
      output = value
    } else {
      output = output + ", " + value
    }
  }
  output
}

///|
fn pdf_metadata_extract_rdf_list_items_for_prefix(
  value : BytesView,
  prefix : String,
) -> Array[String] {
  let items : Array[String] = []
  let open_pattern = @ascii.encode("<" + prefix + ":li")
  let close_pattern = @ascii.encode("</" + prefix + ":li>")
  let mut search_start = 0
  while search_start < value.length() {
    let item_start = pdf_metadata_find_bytes_from(
      value, search_start, open_pattern,
    )
    if item_start < 0 {
      search_start = value.length()
    } else {
      let name_end = item_start + open_pattern.length()
      if name_end >= value.length() ||
        !pdf_metadata_xml_tag_boundary(value[name_end]) {
        search_start = name_end
      } else {
        let item_tag_end = pdf_metadata_find_byte(value, name_end, 62)
        if item_tag_end < 0 {
          search_start = value.length()
        } else if value[item_tag_end - 1].to_int() == 47 {
          search_start = item_tag_end + 1
        } else {
          let item_value_start = item_tag_end + 1
          let item_value_end = pdf_metadata_find_bytes_from(
            value, item_value_start, close_pattern,
          )
          if item_value_end < 0 {
            search_start = value.length()
          } else {
            match
              pdf_metadata_decode_xml_text(
                value[item_value_start:item_value_end],
              ) {
              Some(item) => items.push(item)
              None => ()
            }
            search_start = item_value_end + close_pattern.length()
          }
        }
      }
    }
  }
  items
}

///|
fn pdf_metadata_extract_rdf_list_items(
  data : BytesView,
  value : BytesView,
) -> String? {
  let items : Array[String] = []
  let prefixes = pdf_metadata_namespace_prefixes(
    data, pdf_metadata_rdf_namespace, "rdf",
  )
  for prefix in prefixes {
    for item in pdf_metadata_extract_rdf_list_items_for_prefix(value, prefix) {
      items.push(item)
    }
  }
  if items.length() == 0 {
    None
  } else {
    Some(pdf_metadata_combine_list_items(items))
  }
}

///|
fn pdf_metadata_extract_xmp_element(
  data : BytesView,
  prefix : String,
  name : String,
) -> String? {
  let open_pattern = @ascii.encode("<" + prefix + ":" + name)
  let tag_start = pdf_metadata_find_bytes_from(data, 0, open_pattern)
  if tag_start < 0 {
    None
  } else {
    let tag_end = pdf_metadata_find_byte(
      data,
      tag_start + open_pattern.length(),
      62,
    )
    if tag_end < 0 || data[tag_end - 1].to_int() == 47 {
      None
    } else {
      let close_pattern = @ascii.encode("</" + prefix + ":" + name + ">")
      let value_start = tag_end + 1
      let value_end = pdf_metadata_find_bytes_from(
        data, value_start, close_pattern,
      )
      if value_end < 0 {
        None
      } else {
        let value = data[value_start:value_end]
        match pdf_metadata_extract_rdf_list_items(data, value) {
          Some(items) => Some(items)
          None => pdf_metadata_decode_xml_text(value)
        }
      }
    }
  }
}

///|
fn pdf_metadata_get_xmp_data(
  data : BytesView,
  xml_uri : String,
  fallback_prefix : String,
  name : String,
) -> String? {
  let prefixes = pdf_metadata_namespace_prefixes(data, xml_uri, fallback_prefix)
  for prefix in prefixes {
    match pdf_metadata_extract_xmp_attribute(data, prefix, name) {
      Some(value) => break Some(value)
      None =>
        match pdf_metadata_extract_xmp_element(data, prefix, name) {
          Some(value) => break Some(value)
          None => ()
        }
    }
  } nobreak {
    None
  }
}

///|
/// Return the first XMP metadata value matching an XML namespace URI and local
/// name. This is the tree-free counterpart of cpdfmetadata's `get_data_for`,
/// covering namespace aliases, attributes, simple element text, and RDF lists.
pub fn pdf_metadata_get_data_for_bytes(
  xml_uri : String,
  name : String,
  metadata : BytesView,
) -> String? {
  pdf_metadata_get_xmp_data(
    metadata,
    xml_uri,
    pdf_metadata_namespace_fallback_prefix(xml_uri),
    name,
  )
}

///|
fn pdf_metadata_xml_string_of_name(name : PdfMetadataXmlName) -> String {
  "NAME |" + name.uri + "| |" + name.local_name + "|"
}

///|
fn pdf_metadata_xml_string_of_attribute(
  attribute : PdfMetadataXmlAttribute,
) -> String {
  "ATTRNAME |" +
  attribute.name.uri +
  "| |" +
  attribute.name.local_name +
  "|, STR {" +
  attribute.value +
  "}"
}

///|
fn pdf_metadata_xml_string_of_attributes(
  attributes : ArrayView[PdfMetadataXmlAttribute],
) -> String {
  let mut output = ""
  for attribute in attributes {
    output = output + " " + pdf_metadata_xml_string_of_attribute(attribute)
  }
  output
}

///|
fn pdf_metadata_xml_string_of_trees(
  trees : ArrayView[PdfMetadataXmlTree],
) -> String {
  let mut output = ""
  for tree in trees {
    output = output + " " + pdf_metadata_string_of_xmltree(tree)
  }
  output
}

///|
/// Return cpdfmetadata's debug string representation for an XML tree.
pub fn pdf_metadata_string_of_xmltree(tree : PdfMetadataXmlTree) -> String {
  match tree {
    PdfMetadataXmlData(data) => "D {" + data + "}"
    PdfMetadataXmlElement(tag, children) =>
      "E (" +
      pdf_metadata_xml_string_of_name(tag.name) +
      ", ATTRIBUTES {" +
      pdf_metadata_xml_string_of_attributes(tag.attributes) +
      "}, " +
      pdf_metadata_xml_string_of_trees(children) +
      ")"
  }
}

///|
/// Source-spelled compatibility alias for cpdfmetadata's `string_of_xmltree`.
pub fn pdf_string_of_xmltree(tree : PdfMetadataXmlTree) -> String {
  pdf_metadata_string_of_xmltree(tree)
}

///|
fn pdf_metadata_xml_collect_list_items(tree : PdfMetadataXmlTree) -> String {
  match tree {
    PdfMetadataXmlElement(tag, children) =>
      if tag.name.uri == pdf_metadata_rdf_namespace &&
        (
          tag.name.local_name == "Alt" ||
          tag.name.local_name == "Seq" ||
          tag.name.local_name == "Bag"
        ) {
        let values : Array[String] = []
        for child in children {
          match child {
            PdfMetadataXmlElement(li_tag, [PdfMetadataXmlData(data)]) =>
              if li_tag.name.uri == pdf_metadata_rdf_namespace &&
                li_tag.name.local_name == "li" {
                values.push(data)
              }
            _ => ()
          }
        }
        pdf_metadata_combine_list_items(values)
      } else {
        ""
      }
    _ => ""
  }
}

///|
fn pdf_metadata_xml_collect_list_items_all(
  trees : ArrayView[PdfMetadataXmlTree],
) -> String? {
  for tree in trees {
    match tree {
      PdfMetadataXmlElement(_, _) =>
        break Some(pdf_metadata_xml_collect_list_items(tree))
      _ => ()
    }
  } nobreak {
    None
  }
}

///|
fn pdf_metadata_xmltree_attribute_data_for(
  uri : String,
  name : String,
  attributes : ArrayView[PdfMetadataXmlAttribute],
) -> String? {
  for attribute in attributes {
    if attribute.name.uri == uri && attribute.name.local_name == name {
      break Some(attribute.value)
    }
  } nobreak {
    None
  }
}

///|
/// Return the first XML-tree value matching a namespace URI and local name,
/// following cpdfmetadata's `get_data_for` tree traversal.
pub fn pdf_metadata_xmltree_get_data_for(
  xml_uri : String,
  name : String,
  tree : PdfMetadataXmlTree,
) -> String? {
  match tree {
    PdfMetadataXmlData(_) => None
    PdfMetadataXmlElement(tag, children) =>
      if children.length() == 0 {
        pdf_metadata_xmltree_attribute_data_for(xml_uri, name, tag.attributes)
      } else if tag.name.uri == xml_uri && tag.name.local_name == name {
        match children {
          [PdfMetadataXmlData(data)] => Some(data)
          _ => pdf_metadata_xml_collect_list_items_all(children)
        }
      } else {
        for child in children {
          match pdf_metadata_xmltree_get_data_for(xml_uri, name, child) {
            Some(value) => break Some(value)
            None => ()
          }
        } nobreak {
          None
        }
      }
  }
}

///|
/// Source-spelled compatibility alias for cpdfmetadata's `get_data_for`.
pub fn pdf_get_data_for(
  xml_uri : String,
  name : String,
  tree : PdfMetadataXmlTree,
) -> String? {
  pdf_metadata_xmltree_get_data_for(xml_uri, name, tree)
}

///|
fn pdf_metadata_xml_escaped_text(text : String) -> String {
  text
  .replace(old="&", new="&amp;")
  .replace(old="<", new="&lt;")
  .replace(old=">", new="&gt;")
}

///|
fn pdf_metadata_xml_escaped_attribute(text : String) -> String {
  pdf_metadata_xml_escaped_text(text)
  .replace(old="\"", new="&quot;")
  .replace(old="'", new="&apos;")
}

///|
fn pdf_metadata_xml_qualified_name(name : PdfMetadataXmlName) -> String {
  match name.prefix {
    Some(prefix) if prefix != "" => prefix + ":" + name.local_name
    _ => name.local_name
  }
}

///|
fn pdf_metadata_xmltree_push_bytes(
  output : Array[String],
  tree : PdfMetadataXmlTree,
) -> Unit {
  match tree {
    PdfMetadataXmlData(data) => output.push(pdf_metadata_xml_escaped_text(data))
    PdfMetadataXmlElement(tag, children) => {
      output.push("<")
      output.push(pdf_metadata_xml_qualified_name(tag.name))
      for attribute in tag.attributes {
        output.push(" ")
        output.push(pdf_metadata_xml_qualified_name(attribute.name))
        output.push("=\"")
        output.push(pdf_metadata_xml_escaped_attribute(attribute.value))
        output.push("\"")
      }
      if children.length() == 0 {
        output.push("/>")
      } else {
        output.push(">")
        for child in children {
          pdf_metadata_xmltree_push_bytes(output, child)
        }
        output.push("</")
        output.push(pdf_metadata_xml_qualified_name(tag.name))
        output.push(">")
      }
    }
  }
}

///|
/// Serialize a metadata XML-tree document to UTF-8 XML bytes.
///
/// Like cpdfmetadata's `bytes_of_xmltree`, this omits an XML declaration.
pub fn pdf_metadata_bytes_of_xmltree(
  document : PdfMetadataXmlDocument,
) -> PdfBytes {
  let output : Array[String] = []
  match document.dtd {
    Some(dtd) if dtd != "" => output.push(dtd)
    _ => ()
  }
  pdf_metadata_xmltree_push_bytes(output, document.tree)
  @utf8.encode(output.join(""))
}

///|
/// Source-spelled compatibility alias for cpdfmetadata's `bytes_of_xmltree`.
pub fn pdf_bytes_of_xmltree(document : PdfMetadataXmlDocument) -> PdfBytes {
  pdf_metadata_bytes_of_xmltree(document)
}

///|
fn pdf_metadata_decode_pdf_string(value : BytesView) -> String? {
  let text = @utf8.decode(value) catch { _ => return None }
  Some(text)
}

///|
fn pdf_metadata_json_string_array(values : ArrayView[String]) -> Json {
  let items : Array[Json] = []
  for value in values {
    items.push(Json::string(value))
  }
  Json::array(items)
}

///|
fn pdf_metadata_combine_with_commas(values : ArrayView[String]) -> String {
  let mut output = ""
  for value in values {
    if output == "" {
      output = value
    } else {
      output = output + ", " + value
    }
  }
  output.trim().to_owned()
}

///|
fn pdf_metadata_unit_number(value : Double, unit : PdfUnit) -> Double {
  match unit {
    PdfPoint => value
    Inch => unit_inches(value, PdfPoint)
    Centimetre => unit_centimetres(value, PdfPoint)
    Millimetre => unit_millimetres(value, PdfPoint)
  }
}

///|
fn pdf_metadata_string_json(value : String) -> Json {
  if value == "" {
    Json::null()
  } else {
    Json::string(value)
  }
}

///|
fn pdf_metadata_bool_json(value : String) -> Json {
  if value == "" {
    Json::null()
  } else {
    Json::boolean(value.to_lower() == "true")
  }
}

///|
fn PdfDocument::pdf_metadata_info_encoded(
  self : PdfDocument,
  key : PdfName,
  encoding : PdfMetadataEncoding,
) -> String {
  let info = match
    self.lookup_direct(pdf_metadata_info(), self.trailer_dict()) {
    Some(dictionary) => dictionary
    None => PdfDictionary([])
  }
  match self.lookup_direct(key, info) {
    Some(PdfString(bytes)) =>
      @utf8.decode_lossy(
        pdf_metadata_encode_output(encoding, bytes) catch {
          _ => return ""
        },
      )
    Some(PdfBoolean(value)) => pdf_metadata_bool_string(value)
    _ => if key == pdf_metadata_trapped() { "False" } else { "" }
  }
}

///|
fn PdfDocument::pdf_metadata_box_array_json(
  self : PdfDocument,
  box : PdfObject,
  unit : PdfUnit,
) -> Json? {
  match self.direct(box) {
    PdfArray(values) if values.length() == 4 => {
      let output : Array[Json] = []
      for value in values {
        let number = self.get_number(value) catch { _ => return None }
        output.push(Json::number(pdf_metadata_unit_number(number, unit)))
      }
      Some(Json::array(output))
    }
    _ => None
  }
}

///|
fn PdfDocument::pdf_metadata_page_box_json(
  self : PdfDocument,
  boxes : ArrayView[PdfObject?],
  unit : PdfUnit,
) -> Json {
  if boxes.length() == 0 {
    return Json::null()
  }
  let first = boxes[0]
  for index in 1..<boxes.length() {
    if boxes[index] != first {
      return Json::string("various")
    }
  }
  match first {
    Some(box) =>
      match self.pdf_metadata_box_array_json(box, unit) {
        Some(json) => json
        None => Json::null()
      }
    None => Json::null()
  }
}

///|
fn pdf_metadata_set_json_string(
  output : Map[String, Json],
  key : String,
  value : String,
) -> Unit {
  output.set(key, pdf_metadata_string_json(value))
}

///|
fn pdf_metadata_push_text_line(
  output : Array[String],
  key : String,
  value : String,
) -> Unit {
  output.push(key)
  output.push(": ")
  output.push(value)
  output.push("\n")
}

///|
fn PdfDocument::pdf_metadata_box_text(
  self : PdfDocument,
  box : PdfObject,
  unit : PdfUnit,
) -> String {
  match self.direct(box) {
    PdfArray(values) if values.length() == 4 => {
      let a = self.get_number(values[0]) catch { _ => return "" }
      let b = self.get_number(values[1]) catch { _ => return "" }
      let c = self.get_number(values[2]) catch { _ => return "" }
      let d = self.get_number(values[3]) catch { _ => return "" }
      pdf_position_fixed_six(pdf_metadata_unit_number(a, unit)) +
      " " +
      pdf_position_fixed_six(pdf_metadata_unit_number(b, unit)) +
      " " +
      pdf_position_fixed_six(pdf_metadata_unit_number(c, unit)) +
      " " +
      pdf_position_fixed_six(pdf_metadata_unit_number(d, unit))
    }
    _ => ""
  }
}

///|
fn PdfDocument::pdf_metadata_info_box_text(
  self : PdfDocument,
  boxes : ArrayView[PdfObject?],
  unit : PdfUnit,
) -> String {
  if boxes.length() == 0 {
    return ""
  }
  let first = boxes[0]
  for index in 1..<boxes.length() {
    if boxes[index] != first {
      return "various"
    }
  }
  match first {
    Some(box) => self.pdf_metadata_box_text(box, unit)
    None => ""
  }
}

///|
fn PdfDocument::pdf_metadata_info_json_boxes(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
  unit : PdfUnit,
  output : Map[String, Json],
) -> Unit {
  let mediaboxes : Array[PdfObject?] = []
  let cropboxes : Array[PdfObject?] = []
  let bleedboxes : Array[PdfObject?] = []
  let trimboxes : Array[PdfObject?] = []
  let artboxes : Array[PdfObject?] = []
  for page in pages {
    mediaboxes.push(Some(page.mediabox))
    cropboxes.push(self.lookup_direct(pdf_metadata_cropbox(), page.rest))
    bleedboxes.push(self.lookup_direct(pdf_metadata_bleedbox(), page.rest))
    trimboxes.push(self.lookup_direct(pdf_metadata_trimbox(), page.rest))
    artboxes.push(self.lookup_direct(pdf_metadata_artbox(), page.rest))
  }
  output.set("MediaBox", self.pdf_metadata_page_box_json(mediaboxes, unit))
  output.set("CropBox", self.pdf_metadata_page_box_json(cropboxes, unit))
  output.set("BleedBox", self.pdf_metadata_page_box_json(bleedboxes, unit))
  output.set("TrimBox", self.pdf_metadata_page_box_json(trimboxes, unit))
  output.set("ArtBox", self.pdf_metadata_page_box_json(artboxes, unit))
}

///|
let pdf_metadata_xmp_report_fields : Array[(String, String, String)] = [
  ("XMP pdf:Keywords", pdf_metadata_adobe_namespace, "Keywords"),
  ("XMP pdf:Producer", pdf_metadata_adobe_namespace, "Producer"),
  ("XMP pdf:Trapped", pdf_metadata_adobe_namespace, "Trapped"),
  ("XMP pdf:Title", pdf_metadata_adobe_namespace, "Title"),
  ("XMP pdf:Creator", pdf_metadata_adobe_namespace, "Creator"),
  ("XMP pdf:Subject", pdf_metadata_adobe_namespace, "Subject"),
  ("XMP pdf:Author", pdf_metadata_adobe_namespace, "Author"),
  ("XMP pdf:CreationDate", pdf_metadata_adobe_namespace, "CreationDate"),
  ("XMP pdf:ModDate", pdf_metadata_adobe_namespace, "ModDate"),
  ("XMP xmp:CreateDate", pdf_metadata_xmp_namespace, "CreateDate"),
  ("XMP xmp:CreatorTool", pdf_metadata_xmp_namespace, "CreatorTool"),
  ("XMP xmp:MetadataDate", pdf_metadata_xmp_namespace, "MetadataDate"),
  ("XMP xmp:ModifyDate", pdf_metadata_xmp_namespace, "ModifyDate"),
  ("XMP dc:title", pdf_metadata_dc_namespace, "title"),
  ("XMP dc:creator", pdf_metadata_dc_namespace, "creator"),
  ("XMP dc:subject", pdf_metadata_dc_namespace, "subject"),
  ("XMP dc:description", pdf_metadata_dc_namespace, "description"),
  ("PDF/UA pdfuaid:amd", pdf_metadata_pdfuaid_namespace, "amd"),
  ("PDF/UA pdfuaid:corr", pdf_metadata_pdfuaid_namespace, "corr"),
]

///|
fn pdf_metadata_add_xmp_report_field(
  output : Map[String, Json],
  metadata : BytesView,
  field : (String, String, String),
) -> Unit {
  match
    pdf_metadata_get_xmp_data(
      metadata,
      field.1,
      pdf_metadata_namespace_fallback_prefix(field.1),
      field.2,
    ) {
    Some(value) => output.set(field.0, Json::string(value))
    None => ()
  }
}

///|
fn pdf_metadata_add_xmp_report_line(
  output : Array[String],
  tree : PdfMetadataXmlTree,
  field : (String, String, String),
) -> Unit {
  match pdf_metadata_xmltree_get_data_for(field.1, field.2, tree) {
    Some(value) => {
      output.push(field.0)
      output.push(": ")
      output.push(value)
      output.push("\n")
    }
    None => ()
  }
}

///|
fn pdf_metadata_push_view(output : Array[Byte], bytes : BytesView) -> Unit {
  for byte in bytes {
    output.push(byte)
  }
}

///|
fn pdf_metadata_xml_text(value : String) -> PdfBytes {
  @utf8.encode(
    value
    .replace(old="&", new="&amp;")
    .replace(old="<", new="&lt;")
    .replace(old=">", new="&gt;"),
  )
}

///|
fn pdf_metadata_xml_tag_boundary(byte : Byte) -> Bool {
  match byte.to_int() {
    9 | 10 | 13 | 32 | 47 | 62 => true
    _ => false
  }
}

///|
fn pdf_metadata_rewrite_xmp_element_prefix(
  data : BytesView,
  prefix : String,
  field : String,
  replacement : String,
) -> (PdfBytes, Bool) {
  let open_pattern = @ascii.encode("<" + prefix + ":" + field)
  let close_pattern = @ascii.encode("</" + prefix + ":" + field + ">")
  let replacement_bytes = pdf_metadata_xml_text(replacement)
  let output : Array[Byte] = []
  let mut changed = false
  let mut search_start = 0
  while search_start < data.length() {
    let tag_start = pdf_metadata_find_bytes_from(
      data, search_start, open_pattern,
    )
    if tag_start < 0 {
      pdf_metadata_push_view(output, data[search_start:])
      search_start = data.length()
    } else {
      let name_end = tag_start + open_pattern.length()
      if name_end >= data.length() ||
        !pdf_metadata_xml_tag_boundary(data[name_end]) {
        pdf_metadata_push_view(output, data[search_start:name_end])
        search_start = name_end
      } else {
        let tag_end = pdf_metadata_find_byte(data, name_end, 62)
        if tag_end < 0 {
          pdf_metadata_push_view(output, data[search_start:])
          search_start = data.length()
        } else if tag_end > tag_start && data[tag_end - 1].to_int() == 47 {
          pdf_metadata_push_view(output, data[search_start:tag_end - 1])
          output.push((62).to_byte())
          pdf_metadata_push_view(output, replacement_bytes)
          pdf_metadata_push_view(output, close_pattern)
          search_start = tag_end + 1
          changed = true
        } else {
          let value_start = tag_end + 1
          let value_end = pdf_metadata_find_bytes_from(
            data, value_start, close_pattern,
          )
          if value_end < 0 {
            pdf_metadata_push_view(output, data[search_start:])
            search_start = data.length()
          } else {
            pdf_metadata_push_view(output, data[search_start:value_start])
            pdf_metadata_push_view(output, replacement_bytes)
            pdf_metadata_push_view(
              output,
              data[value_end:value_end + close_pattern.length()],
            )
            search_start = value_end + close_pattern.length()
            changed = true
          }
        }
      }
    }
  }
  if changed {
    (Bytes::from_array(output), true)
  } else {
    (data.to_owned(), false)
  }
}

///|
fn pdf_metadata_rewrite_xmp_field(
  data : BytesView,
  xml_uri : String,
  fallback_prefix : String,
  field : String,
  replacement : String,
) -> PdfBytes {
  let mut output = data.to_owned()
  let prefixes = pdf_metadata_namespace_prefixes(data, xml_uri, fallback_prefix)
  for prefix in prefixes {
    let (rewritten, _) = pdf_metadata_rewrite_xmp_element_prefix(
      output, prefix, field, replacement,
    )
    output = rewritten
  }
  output
}

///|
fn pdf_metadata_pad2(value : Int) -> String {
  let absolute = if value < 0 { -value } else { value }
  if absolute < 10 {
    "0" + absolute.to_string()
  } else {
    absolute.to_string()
  }
}

///|
fn pdf_metadata_pad4(value : Int) -> String {
  if value < 10 {
    "000" + value.to_string()
  } else if value < 100 {
    "00" + value.to_string()
  } else if value < 1000 {
    "0" + value.to_string()
  } else {
    value.to_string()
  }
}

///|
fn pdf_metadata_xmp_date(date : String) -> String raise PdfError {
  if !date.has_prefix("D:") {
    "0000-01-01T00:00:00Z"
  } else {
    let parsed = pdf_date_of_string(date)
    let tzd = if parsed.hour_offset == 0 && parsed.minute_offset == 0 {
      "Z"
    } else {
      let sign = if parsed.hour_offset < 0 || parsed.minute_offset < 0 {
        "-"
      } else {
        "+"
      }
      sign +
      pdf_metadata_pad2(parsed.hour_offset) +
      ":" +
      pdf_metadata_pad2(parsed.minute_offset)
    }
    pdf_metadata_pad4(parsed.year) +
    "-" +
    pdf_metadata_pad2(parsed.month) +
    "-" +
    pdf_metadata_pad2(parsed.day) +
    "T" +
    pdf_metadata_pad2(parsed.hour) +
    ":" +
    pdf_metadata_pad2(parsed.minute) +
    ":" +
    pdf_metadata_pad2(parsed.second) +
    tzd
  }
}

///|
fn pdf_metadata_is_leap_year(year : Int) -> Bool {
  (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

///|
fn pdf_metadata_days_in_month(year : Int, month : Int) -> Int {
  match month {
    1 | 3 | 5 | 7 | 8 | 10 | 12 => 31
    4 | 6 | 9 | 11 => 30
    2 => if pdf_metadata_is_leap_year(year) { 29 } else { 28 }
    _ => 30
  }
}

///|
fn pdf_metadata_pdf_date_from_unix_millis(milliseconds : UInt64) -> String {
  let total_seconds = (milliseconds / (1000 : UInt64)).reinterpret_as_int64()
  let mut days = (total_seconds / 86400L).to_int()
  let seconds_of_day = (total_seconds % 86400L).to_int()
  let hour = seconds_of_day / 3600
  let minute = seconds_of_day % 3600 / 60
  let second = seconds_of_day % 60
  let mut year = 1970
  let mut year_days = if pdf_metadata_is_leap_year(year) { 366 } else { 365 }
  while days >= year_days {
    days -= year_days
    year += 1
    year_days = if pdf_metadata_is_leap_year(year) { 366 } else { 365 }
  }
  let mut month = 1
  while days >= pdf_metadata_days_in_month(year, month) {
    days -= pdf_metadata_days_in_month(year, month)
    month += 1
  }
  let day = days + 1
  "D:" +
  pdf_metadata_pad4(year) +
  pdf_metadata_pad2(month) +
  pdf_metadata_pad2(day) +
  pdf_metadata_pad2(hour) +
  pdf_metadata_pad2(minute) +
  pdf_metadata_pad2(second)
}

///|
fn pdf_metadata_expand_date(date : String) -> String {
  if date == "now" {
    match @env.get_env_var("CPDF_REPRODUCIBLE_DATES") {
      Some("true") =>
        pdf_strftime_with_time(pdf_strftime_dummy_time(), "D:%Y%m%d%H%M%S")
      _ => pdf_metadata_pdf_date_from_unix_millis(@env.now())
    }
  } else {
    date
  }
}

///|
/// Expand cpdf's metadata date alias.
///
/// This mirrors `Cpdfmetadata.expand_date`: `"now"` becomes a PDF date string
/// and all other inputs are returned unchanged. Setting
/// `CPDF_REPRODUCIBLE_DATES=true` uses the deterministic dummy timestamp.
pub fn pdf_expand_date(date : String) -> String {
  pdf_metadata_expand_date(date)
}

///|
fn pdf_metadata_replace_all(
  text : String,
  old : String,
  new : String,
) -> String {
  let mut output = text
  if old == "" {
    output
  } else {
    while output.contains(old) {
      output = output.replace(old~, new~)
    }
    output
  }
}

///|
fn PdfDocument::pdf_metadata_template_replacements(
  self : PdfDocument,
) -> Array[(String, String)] raise PdfError {
  let info = fn(name : String) -> String {
    self.info_utf8(pdf_metadata_name(name))
  }
  let creation_date = match info("/CreationDate") {
    "" => pdf_metadata_expand_date("now")
    value => value
  }
  let mod_date = match info("/ModDate") {
    "" => pdf_metadata_expand_date("now")
    value => value
  }
  [
    ("CREATEDATE", pdf_metadata_xmp_date(creation_date)),
    ("MODDATE", pdf_metadata_xmp_date(mod_date)),
    ("PRODUCER", info("/Producer")),
    ("CREATOR", info("/Creator")),
    ("TITLE", info("/Title")),
    ("SUBJECT", info("/Subject")),
    ("AUTHOR", info("/Author")),
    ("KEYWORDS", info("/Keywords")),
    ("TRAPPED", info("/Trapped")),
    ("METADATADATE", pdf_metadata_xmp_date(pdf_metadata_expand_date("now"))),
  ]
}

///|
fn pdf_metadata_xml_value_of_object(value : PdfObject) -> String raise PdfError {
  match value {
    PdfString(bytes) =>
      @utf8.decode(pdf_utf8_of_pdfdocstring(bytes)) catch {
        _ => raise InvalidUTF8
      }
    PdfBoolean(true) => "True"
    PdfBoolean(false) => "False"
    _ => raise BadNumberArgument("set_pdf_info_xml: not a string")
  }
}

///|
fn pdf_metadata_xmp_date_of_object(value : PdfObject) -> String raise PdfError {
  match value {
    PdfString(bytes) =>
      pdf_metadata_xmp_date(
        @ascii.decode(bytes) catch {
          _ => raise InvalidUTF8
        },
      )
    _ => raise BadNumberArgument("xmp_date not a string")
  }
}

///|
fn pdf_metadata_info_xmp_changes(
  key : PdfName,
  value : PdfObject,
) -> (Array[(String, String)], String) raise PdfError {
  match pdf_metadata_name_with_slash(key) {
    Some("/Producer") =>
      (
        [(pdf_metadata_adobe_namespace, "Producer")],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/Creator") =>
      (
        [
          (pdf_metadata_adobe_namespace, "Creator"),
          (pdf_metadata_xmp_namespace, "CreatorTool"),
          (pdf_metadata_dc_namespace, "creator"),
        ],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/Author") =>
      (
        [(pdf_metadata_adobe_namespace, "Author")],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/Title") =>
      (
        [
          (pdf_metadata_adobe_namespace, "Title"),
          (pdf_metadata_dc_namespace, "title"),
        ],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/Subject") =>
      (
        [
          (pdf_metadata_adobe_namespace, "Subject"),
          (pdf_metadata_dc_namespace, "subject"),
        ],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/Keywords") =>
      (
        [(pdf_metadata_adobe_namespace, "Keywords")],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/CreationDate") =>
      (
        [
          (pdf_metadata_adobe_namespace, "CreationDate"),
          (pdf_metadata_xmp_namespace, "CreateDate"),
        ],
        pdf_metadata_xmp_date_of_object(value),
      )
    Some("/ModDate") =>
      (
        [
          (pdf_metadata_adobe_namespace, "ModDate"),
          (pdf_metadata_xmp_namespace, "ModifyDate"),
        ],
        pdf_metadata_xmp_date_of_object(value),
      )
    Some("/Trapped") =>
      (
        [(pdf_metadata_adobe_namespace, "Trapped")],
        pdf_metadata_xml_value_of_object(value),
      )
    _ => raise BadNumberArgument("Unknown call to set_pdf_info")
  }
}

///|
fn PdfDocument::pdf_metadata_fallback_pdfx(self : PdfDocument) -> String? {
  match self.lookup_direct(pdf_metadata_info(), self.trailer_dict()) {
    Some(info) =>
      match self.lookup_direct(pdf_metadata_name("/GTS_PDFXVersion"), info) {
        Some(PdfString(value)) => pdf_metadata_decode_pdf_string(value)
        _ => None
      }
    None => None
  }
}

///|
fn pdf_metadata_reverse_strings(values : ArrayView[String]) -> Array[String] {
  let output : Array[String] = []
  for index = values.length() - 1; index >= 0; index = index - 1 {
    output.push(values[index])
  }
  output
}

///|
fn pdf_metadata_push_if_some(values : Array[String], value : String?) -> Unit {
  match value {
    Some(value) if value != "" => values.push(value)
    _ => ()
  }
}

///|
fn pdf_metadata_namespace_fallback_prefix(xml_uri : String) -> String {
  if xml_uri == pdf_metadata_adobe_namespace {
    "pdf"
  } else if xml_uri == pdf_metadata_xmp_namespace {
    "xmp"
  } else if xml_uri == pdf_metadata_dc_namespace {
    "dc"
  } else if xml_uri == pdf_metadata_pdfuaid_namespace {
    "pdfuaid"
  } else if xml_uri == pdf_metadata_pdfe_namespace {
    "pdfe"
  } else if xml_uri == pdf_metadata_pdfaid_namespace {
    "pdfaid"
  } else if xml_uri == pdf_metadata_pdfxid_namespace {
    "pdfxid"
  } else if xml_uri == pdf_metadata_pdfvtid_namespace {
    "pdfvtid"
  } else {
    ""
  }
}

///|
fn pdf_metadata_name_with_slash(name : PdfName) -> String? {
  let text = @ascii.decode(name.bytes()) catch { _ => return None }
  Some(text)
}

///|
fn pdf_metadata_xmp_info_fields(key : PdfName) -> Array[(String, String)]? {
  match pdf_metadata_name_with_slash(key) {
    Some("/Title") =>
      Some([
        (pdf_metadata_adobe_namespace, "Title"),
        (pdf_metadata_dc_namespace, "title"),
      ])
    Some("/Author") =>
      Some([
        (pdf_metadata_adobe_namespace, "Author"),
        (pdf_metadata_dc_namespace, "creator"),
      ])
    Some("/Subject") =>
      Some([
        (pdf_metadata_adobe_namespace, "Subject"),
        (pdf_metadata_dc_namespace, "subject"),
      ])
    Some("/Keywords") => Some([(pdf_metadata_adobe_namespace, "Keywords")])
    Some("/Creator") =>
      Some([
        (pdf_metadata_adobe_namespace, "Creator"),
        (pdf_metadata_xmp_namespace, "CreatorTool"),
      ])
    Some("/Producer") => Some([(pdf_metadata_adobe_namespace, "Producer")])
    Some("/CreationDate") =>
      Some([
        (pdf_metadata_adobe_namespace, "CreationDate"),
        (pdf_metadata_xmp_namespace, "CreateDate"),
      ])
    Some("/ModDate") =>
      Some([
        (pdf_metadata_adobe_namespace, "ModificationDate"),
        (pdf_metadata_xmp_namespace, "ModifyDate"),
      ])
    _ => None
  }
}

///|
/// Return XMP metadata corresponding to a legacy `/Info` key.
pub fn PdfDocument::xmp_info(self : PdfDocument, key : PdfName) -> String {
  let fields = match pdf_metadata_xmp_info_fields(key) {
    Some(fields) => fields
    None => return ""
  }
  let metadata = try self.metadata() catch {
    _ => return ""
  } noraise {
    Some(metadata) => metadata
    None => return ""
  }
  for field in fields {
    let value = pdf_metadata_get_xmp_data(
      metadata,
      field.0,
      pdf_metadata_namespace_fallback_prefix(field.0),
      field.1,
    )
    match value {
      Some(value) if value != "" => break value
      _ => ()
    }
  } nobreak {
    ""
  }
}

///|
/// Return XMP metadata corresponding to a cpdf-style slash-prefixed string key.
pub fn PdfDocument::xmp_info_string(self : PdfDocument, key : String) -> String {
  self.xmp_info(pdf_metadata_source_key_name(key))
}

///|
/// Determine PDF/A, PDF/E, PDF/UA, PDF/VT, and PDF/X subformat markers.
///
/// This ports cpdf's in-memory subformat detection. It recognizes simple XMP
/// element and attribute forms and falls back to `/Info /GTS_PDFXVersion`.
pub fn PdfDocument::determine_subformats(
  self : PdfDocument,
) -> Array[String] raise PdfError {
  let formats : Array[String] = []
  match self.metadata() {
    None =>
      pdf_metadata_push_if_some(formats, self.pdf_metadata_fallback_pdfx())
    Some(metadata) => {
      pdf_metadata_push_if_some(
        formats,
        pdf_metadata_get_xmp_data(
          metadata, pdf_metadata_pdfe_namespace, "pdfe", "ISO_PDFEVersion",
        ),
      )
      match
        pdf_metadata_get_xmp_data(
          metadata, pdf_metadata_pdfuaid_namespace, "pdfuaid", "part",
        ) {
        Some(part) if part != "" => formats.push("PDF/UA-" + part)
        _ => ()
      }
      let pdfa_part = match
        pdf_metadata_get_xmp_data(
          metadata, pdf_metadata_pdfaid_namespace, "pdfaid", "part",
        ) {
        Some(part) => Some(part)
        None =>
          match
            pdf_metadata_get_xmp_data(
              metadata, pdf_metadata_pdfaid_wrong_acrobat_namespace, "pdfaid", "part",
            ) {
            Some(part) => Some(part)
            None =>
              pdf_metadata_get_xmp_data(
                metadata, pdf_metadata_pdfaid_wrong_iso_namespace, "pdfaid", "part",
              )
          }
      }
      match pdfa_part {
        Some(part) if part != "" => {
          let conformance = match
            pdf_metadata_get_xmp_data(
              metadata, pdf_metadata_pdfaid_namespace, "pdfaid", "conformance",
            ) {
            Some(value) => value.to_lower()
            None =>
              match
                pdf_metadata_get_xmp_data(
                  metadata, pdf_metadata_pdfaid_wrong_acrobat_namespace, "pdfaid",
                  "conformance",
                ) {
                Some(value) => value.to_lower()
                None =>
                  match
                    pdf_metadata_get_xmp_data(
                      metadata, pdf_metadata_pdfaid_wrong_iso_namespace, "pdfaid",
                      "conformance",
                    ) {
                    Some(value) => value.to_lower()
                    None => ""
                  }
              }
          }
          formats.push("PDF/A-" + part + conformance)
        }
        _ => ()
      }
      match
        pdf_metadata_get_xmp_data(
          metadata, pdf_metadata_pdfxid_namespace, "pdfxid", "GTS_PDFXVersion",
        ) {
        Some(value) if value != "" => formats.push(value)
        _ =>
          pdf_metadata_push_if_some(formats, self.pdf_metadata_fallback_pdfx())
      }
      pdf_metadata_push_if_some(
        formats,
        pdf_metadata_get_xmp_data(
          metadata, pdf_metadata_pdfvtid_namespace, "pdfvtid", "GTS_PDFVTVersion",
        ),
      )
    }
  }
  pdf_metadata_reverse_strings(formats)
}

///|
/// Return cpdf-style document information report fields as JSON.
pub fn PdfDocument::info_json(
  self : PdfDocument,
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
  unit? : PdfUnit = PdfPoint,
) -> Json raise PdfError {
  let output : Map[String, Json] = Map([])
  let (major, minor) = self.version()
  let pages = self.pages_of_pagetree()
  output.set(
    "Version",
    Json::array([pdf_util_json_number(major), pdf_util_json_number(minor)]),
  )
  output.set("Pages", pdf_util_json_number(pages.length()))
  let info_fields : Array[(String, PdfName)] = [
    ("Title", pdf_metadata_name("/Title")),
    ("Author", pdf_metadata_name("/Author")),
    ("Subject", pdf_metadata_name("/Subject")),
    ("Keywords", pdf_metadata_name("/Keywords")),
    ("Creator", pdf_metadata_name("/Creator")),
    ("Producer", pdf_metadata_name("/Producer")),
    ("Created", pdf_metadata_name("/CreationDate")),
    ("Modified", pdf_metadata_name("/ModDate")),
  ]
  for field in info_fields {
    pdf_metadata_set_json_string(
      output,
      field.0,
      self.pdf_metadata_info_encoded(field.1, encoding),
    )
  }
  output.set(
    "Trapped",
    pdf_metadata_bool_json(
      self.pdf_metadata_info_encoded(pdf_metadata_trapped(), encoding),
    ),
  )
  pdf_metadata_set_json_string(
    output,
    "PageMode",
    self.catalog_item(pdf_metadata_page_mode()),
  )
  pdf_metadata_set_json_string(
    output,
    "PageLayout",
    self.catalog_item(pdf_metadata_page_layout()),
  )
  output.set(
    "OpenAction",
    self.pdf_util_json_of_object(
      self.open_action(),
      true,
      false,
      false,
      false,
      false,
    ),
  )
  let viewer_bool_fields : Array[(String, PdfName)] = [
    ("HideToolbar", pdf_metadata_name("/HideToolbar")),
    ("HideMenubar", pdf_metadata_name("/HideMenubar")),
    ("HideWindowUI", pdf_metadata_name("/HideWindowUI")),
    ("FitWindow", pdf_metadata_name("/FitWindow")),
    ("CenterWindow", pdf_metadata_name("/CenterWindow")),
    ("DisplayDocTitle", pdf_metadata_name("/DisplayDocTitle")),
  ]
  for field in viewer_bool_fields {
    output.set(
      field.0,
      pdf_metadata_bool_json(self.viewer_preference_item(field.1)),
    )
  }
  pdf_metadata_set_json_string(
    output,
    "NonFullPageScreenMode",
    self.viewer_preference_item(pdf_metadata_non_full_screen_page_mode()),
  )
  output.set(
    "AcroForm",
    Json::boolean(self.catalog_item(pdf_metadata_acroform()) != ""),
  )
  output.set("XFA", Json::boolean(self.is_xfa()))
  output.set(
    "Marked",
    Json::boolean(self.mark_info_item(pdf_metadata_name("/Marked"))),
  )
  output.set(
    "UserProperties",
    Json::boolean(self.mark_info_item(pdf_metadata_name("/UserProperties"))),
  )
  output.set(
    "Suspects",
    Json::boolean(self.mark_info_item(pdf_metadata_name("/Suspects"))),
  )
  self.pdf_metadata_info_json_boxes(pages, unit, output)
  Json::object(output)
}

///|
/// Return cpdf-style document information report fields as UTF-8 JSON bytes.
pub fn PdfDocument::info_json_blob(
  self : PdfDocument,
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
  unit? : PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  @utf8.encode(self.info_json(encoding~, unit~).stringify())
}

///|
/// Return cpdf-style document information report fields as stdout-style UTF-8 bytes.
pub fn PdfDocument::info_blob(
  self : PdfDocument,
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
  unit? : PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  let output : Array[String] = []
  let (major, minor) = self.version()
  let pages = self.pages_of_pagetree()
  pdf_metadata_push_text_line(
    output,
    "Version",
    major.to_string() + "." + minor.to_string(),
  )
  pdf_metadata_push_text_line(output, "Pages", pages.length().to_string())
  let info_fields : Array[(String, PdfName)] = [
    ("Title", pdf_metadata_name("/Title")),
    ("Author", pdf_metadata_name("/Author")),
    ("Subject", pdf_metadata_name("/Subject")),
    ("Keywords", pdf_metadata_name("/Keywords")),
    ("Creator", pdf_metadata_name("/Creator")),
    ("Producer", pdf_metadata_name("/Producer")),
    ("Created", pdf_metadata_name("/CreationDate")),
    ("Modified", pdf_metadata_name("/ModDate")),
    ("Trapped", pdf_metadata_trapped()),
  ]
  for field in info_fields {
    pdf_metadata_push_text_line(
      output,
      field.0,
      self.pdf_metadata_info_encoded(field.1, encoding),
    )
  }
  pdf_metadata_push_text_line(
    output,
    "PageMode",
    self.catalog_item(pdf_metadata_page_mode()),
  )
  pdf_metadata_push_text_line(
    output,
    "PageLayout",
    self.catalog_item(pdf_metadata_page_layout()),
  )
  pdf_metadata_push_text_line(output, "OpenAction", self.open_action_string())
  let viewer_fields : Array[(String, PdfName)] = [
    ("HideToolbar", pdf_metadata_name("/HideToolbar")),
    ("HideMenubar", pdf_metadata_name("/HideMenubar")),
    ("HideWindowUI", pdf_metadata_name("/HideWindowUI")),
    ("FitWindow", pdf_metadata_name("/FitWindow")),
    ("CenterWindow", pdf_metadata_name("/CenterWindow")),
    ("DisplayDocTitle", pdf_metadata_name("/DisplayDocTitle")),
    ("NonFullScreenPageMode", pdf_metadata_non_full_screen_page_mode()),
  ]
  for field in viewer_fields {
    pdf_metadata_push_text_line(
      output,
      field.0,
      self.viewer_preference_item(field.1),
    )
  }
  let acroform = match self.catalog_item(pdf_metadata_acroform()) {
    "" => "False"
    value => value
  }
  pdf_metadata_push_text_line(output, "AcroForm", acroform)
  pdf_metadata_push_text_line(
    output,
    "XFA",
    if self.is_xfa() {
      "True"
    } else {
      "False"
    },
  )
  pdf_metadata_push_text_line(
    output,
    "Marked",
    if self.mark_info_item(pdf_metadata_name("/Marked")) {
      "True"
    } else {
      "False"
    },
  )
  pdf_metadata_push_text_line(
    output,
    "UserProperties",
    if self.mark_info_item(pdf_metadata_name("/UserProperties")) {
      "True"
    } else {
      "False"
    },
  )
  pdf_metadata_push_text_line(
    output,
    "Suspects",
    if self.mark_info_item(pdf_metadata_name("/Suspects")) {
      "True"
    } else {
      "False"
    },
  )
  let mediaboxes : Array[PdfObject?] = []
  let cropboxes : Array[PdfObject?] = []
  let bleedboxes : Array[PdfObject?] = []
  let trimboxes : Array[PdfObject?] = []
  let artboxes : Array[PdfObject?] = []
  for page in pages {
    mediaboxes.push(Some(page.mediabox))
    cropboxes.push(self.lookup_direct(pdf_metadata_cropbox(), page.rest))
    bleedboxes.push(self.lookup_direct(pdf_metadata_bleedbox(), page.rest))
    trimboxes.push(self.lookup_direct(pdf_metadata_trimbox(), page.rest))
    artboxes.push(self.lookup_direct(pdf_metadata_artbox(), page.rest))
  }
  pdf_metadata_push_text_line(
    output,
    "MediaBox",
    self.pdf_metadata_info_box_text(mediaboxes, unit),
  )
  pdf_metadata_push_text_line(
    output,
    "CropBox",
    self.pdf_metadata_info_box_text(cropboxes, unit),
  )
  pdf_metadata_push_text_line(
    output,
    "BleedBox",
    self.pdf_metadata_info_box_text(bleedboxes, unit),
  )
  pdf_metadata_push_text_line(
    output,
    "TrimBox",
    self.pdf_metadata_info_box_text(trimboxes, unit),
  )
  pdf_metadata_push_text_line(
    output,
    "ArtBox",
    self.pdf_metadata_info_box_text(artboxes, unit),
  )
  @utf8.encode(output.join(""))
}

///|
/// Return cpdf-style XMP metadata report fields as JSON.
pub fn PdfDocument::xmp_info_json(self : PdfDocument) -> Json raise PdfError {
  let output : Map[String, Json] = Map([])
  output.set(
    "Subformats",
    pdf_metadata_json_string_array(self.determine_subformats()),
  )
  match self.language() {
    Some(language) =>
      output.set("Language", Json::string(@utf8.decode_lossy(language)))
    None => output.set("Language", Json::null())
  }
  match self.metadata() {
    Some(metadata) =>
      for field in pdf_metadata_xmp_report_fields {
        pdf_metadata_add_xmp_report_field(output, metadata, field)
      }
    None => ()
  }
  Json::object(output)
}

///|
/// Return cpdf-style XMP metadata report fields as UTF-8 JSON bytes.
pub fn PdfDocument::xmp_info_json_blob(
  self : PdfDocument,
) -> PdfBytes raise PdfError {
  @utf8.encode(self.xmp_info_json().stringify())
}

///|
/// Return cpdf-style XMP metadata report fields as stdout-style UTF-8 bytes.
pub fn PdfDocument::xmp_info_blob(
  self : PdfDocument,
) -> PdfBytes raise PdfError {
  let output : Array[String] = []
  output.push("Subformats: ")
  output.push(pdf_metadata_combine_with_commas(self.determine_subformats()))
  output.push("\nLanguage: ")
  match self.language() {
    Some(language) => {
      output.push("\"")
      output.push(@utf8.decode_lossy(language))
      output.push("\"")
    }
    None => ()
  }
  output.push("\n")
  match self.metadata() {
    Some(metadata) => {
      let document = pdf_metadata_xmltree_of_bytes(metadata) catch {
        _ => return @utf8.encode(output.join(""))
      }
      for field in pdf_metadata_xmp_report_fields {
        pdf_metadata_add_xmp_report_line(output, document.tree, field)
      }
    }
    None => ()
  }
  @utf8.encode(output.join(""))
}

///|
/// Return the catalog `/Lang` value, if present.
pub fn PdfDocument::language(self : PdfDocument) -> PdfBytes? {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_metadata_root(),
      pdf_metadata_lang(),
    ]) {
    Some(PdfString(value)) => Some(value)
    _ => None
  }
}

///|
/// Return the catalog `/Lang` value as text for cpdf-style string APIs.
pub fn PdfDocument::language_string(self : PdfDocument) -> String? {
  match self.language() {
    Some(value) => Some(@utf8.decode_lossy(value))
    None => None
  }
}

///|
/// Set the catalog `/Lang` value.
pub fn PdfDocument::set_language(
  self : PdfDocument,
  language : BytesView,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise PdfError {
    catalog.add_dict_entry(pdf_metadata_lang(), PdfString(language.to_owned()))
  })
  document
}

///|
/// Set the catalog `/Lang` value from a cpdf-style string.
pub fn PdfDocument::set_language_string(
  self : PdfDocument,
  language : String,
) -> PdfDocument raise PdfError {
  self.set_language(@utf8.encode(language))
}

///|
fn pdf_metadata_stream(data : BytesView) -> PdfObject {
  pdf_stream(
    PdfDictionary([
      (pdf_metadata_length(), PdfInteger(data.length())),
      (pdf_metadata_type(), PdfNameObject(pdf_metadata_metadata())),
      (pdf_metadata_subtype(), PdfNameObject(pdf_metadata_xml())),
    ]),
    StreamGot(data.to_owned()),
  )
}

///|
/// Set the catalog metadata XML stream from in-memory bytes.
pub fn PdfDocument::set_metadata_from_bytes(
  self : PdfDocument,
  data : BytesView,
  keep_version? : Bool = false,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let metadata_number = document.add_object(pdf_metadata_stream(data))
  document.pdf_metadata_update_catalog(fn(catalog) raise PdfError {
    catalog.add_dict_entry(
      pdf_metadata_metadata(),
      PdfIndirect(metadata_number),
    )
  })
  document.pdf_metadata_bump_minor(4, keep_version)
  document
}

///|
/// Set the XMP `/Metadata` stream's `xmp:MetadataDate` field.
pub fn PdfDocument::set_metadata_date(
  self : PdfDocument,
  date : String,
) -> PdfDocument raise PdfError {
  match self.metadata() {
    None => self
    Some(metadata) => {
      let value = if date == "now" {
        pdf_metadata_xmp_date(pdf_metadata_expand_date(date))
      } else {
        date
      }
      let updated = pdf_metadata_rewrite_xmp_field(
        metadata, pdf_metadata_xmp_namespace, "xmp", "MetadataDate", value,
      )
      self.set_metadata_from_bytes(updated, keep_version=true)
    }
  }
}

///|
/// Create a fresh XMP metadata stream from the document `/Info` dictionary.
pub fn PdfDocument::create_metadata(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let mut xmp = pdf_metadata_xmp_template
  for replacement in self.pdf_metadata_template_replacements() {
    xmp = pdf_metadata_replace_all(xmp, replacement.0, replacement.1)
  }
  self.set_metadata_from_bytes(@utf8.encode(xmp))
}

///|
/// Extract the catalog metadata XML stream, decoding supported stream filters.
pub fn PdfDocument::metadata(self : PdfDocument) -> PdfBytes? raise PdfError {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_metadata_root(),
      pdf_metadata_metadata(),
    ]) {
    Some(PdfStreamObject(_) as stream) => {
      let decoded = self.pdf_decode_stream(stream)
      Some(decoded.stream_bytes())
    }
    _ => None
  }
}

///|
/// Remove the catalog `/Metadata` entry.
pub fn PdfDocument::remove_metadata(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise PdfError {
    catalog.remove_dict_entry(pdf_metadata_metadata())
  })
  document
}

///|
/// Remove the catalog metadata entry and every parsed object whose `/Type` is
/// `/Metadata`.
pub fn PdfDocument::remove_all_metadata(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let document = self.remove_metadata()
  let to_remove : Array[Int] = []
  for entry in document.parsed_object_entries() {
    match document.lookup_direct(pdf_metadata_type(), entry.2) {
      Some(PdfNameObject(name)) if name == pdf_metadata_metadata() =>
        to_remove.push(entry.0)
      _ => ()
    }
  }
  for number in to_remove {
    document.remove_object(number)
  }
  document
}

///|
/// Compatibility wrapper for `PdfDocument::copy_id_from`.
pub fn pdf_copy_id(
  keep_version : Bool,
  copy_from : PdfDocument,
  copy_to : PdfDocument,
) -> PdfDocument raise PdfError {
  copy_to.copy_id_from(copy_from, keep_version~)
}

///|
/// Compatibility wrapper for `PdfDocument::set_info_entry`.
pub fn pdf_set_pdf_info(
  key : PdfName,
  value : PdfObject,
  version : Int,
  document : PdfDocument,
  keep_version? : Bool = false,
  xmp_also? : Bool = false,
  xmp_just_set? : Bool = false,
) -> PdfDocument raise PdfError {
  document.set_info_entry(
    key,
    value,
    version,
    keep_version~,
    xmp_also~,
    xmp_just_set~,
  )
}

///|
/// Compatibility wrapper matching cpdfmetadata's string-key tuple form.
pub fn pdf_set_pdf_info_cpdf_order(
  entry : (String, PdfObject, Int),
  document : PdfDocument,
  xmp_also? : Bool = false,
  xmp_just_set? : Bool = false,
) -> PdfDocument raise PdfError {
  document.set_info_entry_string(entry, xmp_also~, xmp_just_set~)
}

///|
/// Compatibility wrapper matching cpdfmetadata's string-key tuple form.
pub fn pdf_set_pdf_info_string(
  entry : (String, PdfObject, Int),
  document : PdfDocument,
  xmp_also? : Bool = false,
  xmp_just_set? : Bool = false,
) -> PdfDocument raise PdfError {
  pdf_set_pdf_info_cpdf_order(entry, document, xmp_also~, xmp_just_set~)
}

///|
/// Compatibility wrapper for `PdfDocument::info_utf8`.
pub fn pdf_get_info_utf8(document : PdfDocument, key : PdfName) -> String {
  document.info_utf8(key)
}

///|
/// Compatibility wrapper matching cpdfmetadata's string-key `get_info_utf8`.
pub fn pdf_get_info_utf8_string(document : PdfDocument, key : String) -> String {
  document.info_utf8_string(key)
}

///|
/// Compatibility wrapper for `PdfDocument::xmp_info`.
pub fn pdf_get_xmp_info(document : PdfDocument, key : PdfName) -> String {
  document.xmp_info(key)
}

///|
/// Compatibility wrapper matching cpdfmetadata's string-key `get_xmp_info`.
pub fn pdf_get_xmp_info_string(document : PdfDocument, key : String) -> String {
  document.xmp_info_string(key)
}

///|
/// Compatibility wrapper for `PdfDocument::set_viewer_preference`.
pub fn pdf_set_viewer_preference(
  key : PdfName,
  value : PdfObject,
  version : Int,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.set_viewer_preference(key, value, version)
}

///|
/// Compatibility wrapper matching cpdfmetadata's string-key tuple form.
pub fn pdf_set_viewer_preference_cpdf_order(
  entry : (String, PdfObject, Int),
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.set_viewer_preference_string(entry)
}

///|
/// Compatibility wrapper matching cpdfmetadata's string-key tuple form.
pub fn pdf_set_viewer_preference_string(
  entry : (String, PdfObject, Int),
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  pdf_set_viewer_preference_cpdf_order(entry, document)
}

///|
/// Compatibility wrapper for `PdfDocument::set_page_layout`.
pub fn pdf_set_page_layout(
  document : PdfDocument,
  layout : String,
) -> PdfDocument raise PdfError {
  document.set_page_layout(layout)
}

///|
/// Compatibility wrapper for `PdfDocument::set_page_mode`.
pub fn pdf_set_page_mode(
  document : PdfDocument,
  mode : String,
) -> PdfDocument raise PdfError {
  document.set_page_mode(mode)
}

///|
/// Compatibility wrapper for `PdfDocument::set_non_full_screen_page_mode`.
pub fn pdf_set_non_full_screen_page_mode(
  document : PdfDocument,
  mode : String,
) -> PdfDocument raise PdfError {
  document.set_non_full_screen_page_mode(mode)
}

///|
/// Compatibility wrapper for `PdfDocument::set_open_action`.
pub fn pdf_set_open_action(
  document : PdfDocument,
  fit : Bool,
  page_number : Int,
  destination? : PdfObject? = None,
) -> PdfDocument raise PdfError {
  document.set_open_action(page_number, fit~, destination~)
}

///|
/// Compatibility wrapper for cpdfmetadata's string destination syntax.
pub fn pdf_set_open_action_string_destination(
  document : PdfDocument,
  fit : Bool,
  page_number : Int,
  destination? : String? = None,
) -> PdfDocument raise PdfError {
  document.set_open_action_string_destination(page_number, fit~, destination~)
}

///|
/// Compatibility wrapper matching cpdfmetadata's string destination API.
pub fn pdf_set_open_action_cpdf_order(
  document : PdfDocument,
  fit : Bool,
  page_number : Int,
  destination? : String? = None,
) -> PdfDocument raise PdfError {
  pdf_set_open_action_string_destination(
    document,
    fit,
    page_number,
    destination~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::catalog_item`.
pub fn pdf_get_catalog_item(key : PdfName, document : PdfDocument) -> String {
  document.catalog_item(key)
}

///|
/// Compatibility wrapper matching cpdfmetadata's string-key `get_catalog_item`.
pub fn pdf_get_catalog_item_string(
  key : String,
  document : PdfDocument,
) -> String {
  document.catalog_item_string(key)
}

///|
/// Compatibility wrapper matching cpdfmetadata's `get_catalog_item`.
pub fn pdf_get_catalog_item_cpdf_order(
  key : String,
  document : PdfDocument,
) -> String {
  document.catalog_item_string(key)
}

///|
/// Compatibility wrapper for `PdfDocument::viewer_preference_item`.
pub fn pdf_get_viewer_pref_item(
  key : PdfName,
  document : PdfDocument,
) -> String {
  document.viewer_preference_item(key)
}

///|
/// Compatibility wrapper matching cpdfmetadata's string-key `get_viewer_pref_item`.
pub fn pdf_get_viewer_pref_item_string(
  key : String,
  document : PdfDocument,
) -> String {
  document.viewer_preference_item_string(key)
}

///|
/// Compatibility wrapper matching cpdfmetadata's `get_viewer_pref_item`.
pub fn pdf_get_viewer_pref_item_cpdf_order(
  key : String,
  document : PdfDocument,
) -> String {
  document.viewer_preference_item_string(key)
}

///|
/// Compatibility wrapper for `PdfDocument::mark_info_item`.
pub fn pdf_get_mark_info_item(key : PdfName, document : PdfDocument) -> Bool {
  document.mark_info_item(key)
}

///|
/// Compatibility wrapper for `PdfDocument::is_xfa`.
pub fn pdf_is_xfa(document : PdfDocument) -> Bool {
  document.is_xfa()
}

///|
/// Compatibility wrapper for `PdfDocument::open_action`.
pub fn pdf_get_open_action(document : PdfDocument) -> PdfObject raise PdfError {
  document.open_action()
}

///|
/// Compatibility wrapper for `PdfDocument::open_action_json_blob`.
pub fn pdf_get_open_action_json_blob(
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.open_action_json_blob()
}

///|
/// Compatibility wrapper for `PdfDocument::open_action_string`.
pub fn pdf_get_open_action_string(
  document : PdfDocument,
) -> String raise PdfError {
  document.open_action_string()
}

///|
/// Compatibility wrapper for cpdf's minor-version setter.
pub fn pdf_set_version(minor : Int, document : PdfDocument) -> Unit {
  let (major, _) = document.version()
  document.set_version(major, minor)
}

///|
/// Compatibility wrapper for `PdfDocument::determine_subformats`.
pub fn pdf_determine_subformats(
  document : PdfDocument,
) -> Array[String] raise PdfError {
  document.determine_subformats()
}

///|
/// Compatibility wrapper for `PdfDocument::info_json_blob`.
pub fn pdf_output_info_json_blob(
  document : PdfDocument,
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
  unit? : PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  document.info_json_blob(encoding~, unit~)
}

///|
/// Compatibility wrapper for `PdfDocument::info_blob`.
pub fn pdf_output_info(
  document : PdfDocument,
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
  unit? : PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  document.info_blob(encoding~, unit~)
}

///|
/// Compatibility wrapper for `PdfDocument::xmp_info_json_blob`.
pub fn pdf_output_xmp_info_json_blob(
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.xmp_info_json_blob()
}

///|
/// Compatibility wrapper for `PdfDocument::xmp_info_blob`.
pub fn pdf_output_xmp_info(
  document : PdfDocument,
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
  unit? : PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  ignore(encoding)
  ignore(unit)
  document.xmp_info_blob()
}

///|
/// Compatibility wrapper for `PdfDocument::language`.
pub fn pdf_language(document : PdfDocument) -> PdfBytes? {
  document.language()
}

///|
/// Compatibility wrapper returning `/Lang` as cpdf-style text.
pub fn pdf_language_string(document : PdfDocument) -> String? {
  document.language_string()
}

///|
/// Compatibility wrapper for `PdfDocument::set_language`.
pub fn pdf_set_language(
  document : PdfDocument,
  language : BytesView,
) -> PdfDocument raise PdfError {
  document.set_language(language)
}

///|
/// Compatibility wrapper setting `/Lang` from cpdf-style text.
pub fn pdf_set_language_string(
  document : PdfDocument,
  language : String,
) -> PdfDocument raise PdfError {
  document.set_language_string(language)
}

///|
/// Compatibility wrapper for `PdfDocument::set_metadata_from_bytes`.
pub fn pdf_set_metadata_from_bytes(
  keep_version : Bool,
  data : BytesView,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.set_metadata_from_bytes(data, keep_version~)
}

///|
/// Compatibility wrapper for `PdfDocument::metadata`.
pub fn pdf_get_metadata(document : PdfDocument) -> PdfBytes? raise PdfError {
  document.metadata()
}

///|
/// Return the bytes cpdfmetadata's `print_metadata` would write to stdout.
pub fn pdf_print_metadata(document : PdfDocument) -> PdfBytes raise PdfError {
  match document.metadata() {
    Some(data) => data
    None => Bytes::new(0)
  }
}

///|
/// Compatibility wrapper for `PdfDocument::set_metadata_date`.
pub fn pdf_set_metadata_date(
  document : PdfDocument,
  date : String,
) -> PdfDocument raise PdfError {
  document.set_metadata_date(date)
}

///|
/// Compatibility wrapper for `PdfDocument::create_metadata`.
pub fn pdf_create_metadata(
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.create_metadata()
}

///|
/// Compatibility wrapper for `PdfDocument::remove_metadata`.
pub fn pdf_remove_metadata(
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.remove_metadata()
}

///|
/// Compatibility wrapper for `PdfDocument::remove_all_metadata`.
pub fn pdf_remove_all_metadata(
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.remove_all_metadata()
}
