///|
/// PDF/UA subformat selector used by CamlPDF-facing creation helpers.
pub(all) enum PdfUASubformat {
  PdfUA1
  PdfUA2
} derive(Debug, Eq, ToJson)

///|
/// Parse CamlPDF's PDF/UA subformat spelling.
pub fn pdf_ua_subformat_of_string(
  text : String,
) -> PdfUASubformat raise PdfError {
  match text {
    "PDF/UA-1" => PdfUA1
    "PDF/UA-2" => PdfUA2
    _ => raise BadText
  }
}

///|
fn pdf_ua_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_ua_root_key_name : PdfName = pdf_ua_name("/Root")

///|
fn pdf_ua_root_key() -> PdfName {
  pdf_ua_root_key_name
}

///|
let pdf_ua_info_key_name : PdfName = pdf_ua_name("/Info")

///|
fn pdf_ua_info_key() -> PdfName {
  pdf_ua_info_key_name
}

///|
let pdf_ua_title_key_name : PdfName = pdf_ua_name("/Title")

///|
fn pdf_ua_title_key() -> PdfName {
  pdf_ua_title_key_name
}

///|
let pdf_ua_type_key_name : PdfName = pdf_ua_name("/Type")

///|
fn pdf_ua_type_key() -> PdfName {
  pdf_ua_type_key_name
}

///|
let pdf_ua_metadata_key_name : PdfName = pdf_ua_name("/Metadata")

///|
fn pdf_ua_metadata_key() -> PdfName {
  pdf_ua_metadata_key_name
}

///|
let pdf_ua_metadata_name : PdfName = pdf_ua_name("/Metadata")

///|
fn pdf_ua_metadata() -> PdfName {
  pdf_ua_metadata_name
}

///|
let pdf_ua_subtype_key_name : PdfName = pdf_ua_name("/Subtype")

///|
fn pdf_ua_subtype_key() -> PdfName {
  pdf_ua_subtype_key_name
}

///|
let pdf_ua_xml_name : PdfName = pdf_ua_name("/XML")

///|
fn pdf_ua_xml() -> PdfName {
  pdf_ua_xml_name
}

///|
let pdf_ua_length_key_name : PdfName = pdf_ua_name("/Length")

///|
fn pdf_ua_length_key() -> PdfName {
  pdf_ua_length_key_name
}

///|
let pdf_ua_struct_tree_root_key_name : PdfName = pdf_ua_name("/StructTreeRoot")

///|
fn pdf_ua_struct_tree_root_key() -> PdfName {
  pdf_ua_struct_tree_root_key_name
}

///|
fn pdf_ua_struct_tree_root() -> PdfName {
  pdf_ua_struct_tree_root_key_name
}

///|
let pdf_ua_markinfo_key_name : PdfName = pdf_ua_name("/MarkInfo")

///|
fn pdf_ua_markinfo_key() -> PdfName {
  pdf_ua_markinfo_key_name
}

///|
let pdf_ua_marked_key_name : PdfName = pdf_ua_name("/Marked")

///|
fn pdf_ua_marked_key() -> PdfName {
  pdf_ua_marked_key_name
}

///|
let pdf_ua_lang_key_name : PdfName = pdf_ua_name("/Lang")

///|
fn pdf_ua_lang_key() -> PdfName {
  pdf_ua_lang_key_name
}

///|
let pdf_ua_viewer_preferences_key_name : PdfName = pdf_ua_name(
  "/ViewerPreferences",
)

///|
fn pdf_ua_viewer_preferences_key() -> PdfName {
  pdf_ua_viewer_preferences_key_name
}

///|
let pdf_ua_display_doc_title_key_name : PdfName = pdf_ua_name(
  "/DisplayDocTitle",
)

///|
fn pdf_ua_display_doc_title_key() -> PdfName {
  pdf_ua_display_doc_title_key_name
}

///|
fn pdf_ua_push_ascii(output : Array[Byte], text : String) -> Unit {
  for byte in @ascii.encode(text) {
    output.push(byte)
  }
}

///|
fn pdf_ua_push_xml_escaped_utf8(output : Array[Byte], text : String) -> Unit {
  for byte in @utf8.encode(text) {
    match byte.to_int() {
      34 => pdf_ua_push_ascii(output, "&quot;")
      38 => pdf_ua_push_ascii(output, "&amp;")
      39 => pdf_ua_push_ascii(output, "&apos;")
      60 => pdf_ua_push_ascii(output, "&lt;")
      62 => pdf_ua_push_ascii(output, "&gt;")
      _ => output.push(byte)
    }
  }
}

///|
fn pdf_ua_push_pdfua_marker(
  output : Array[Byte],
  subformat : PdfUASubformat,
) -> Unit {
  match subformat {
    PdfUA1 => pdf_ua_push_ascii(output, "<pdfuaid:part>1</pdfuaid:part>\n")
    PdfUA2 => {
      pdf_ua_push_ascii(output, "<pdfuaid:part>2</pdfuaid:part>\n")
      pdf_ua_push_ascii(output, "<pdfuaid:rev>2024</pdfuaid:rev>\n")
    }
  }
}

///|
fn pdf_ua_metadata_bytes(
  subformat : PdfUASubformat,
  title : String,
) -> PdfBytes {
  let output : Array[Byte] = []
  pdf_ua_push_ascii(
    output, "<?xpacket begin=\"\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?>\n",
  )
  pdf_ua_push_ascii(output, "<x:xmpmeta xmlns:x=\"adobe:ns:meta/\">\n")
  pdf_ua_push_ascii(
    output, "<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">\n",
  )
  pdf_ua_push_ascii(
    output, "<rdf:Description rdf:about=\"\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\">\n",
  )
  pdf_ua_push_ascii(
    output, "<dc:title><rdf:Alt><rdf:li xml:lang=\"x-default\">",
  )
  pdf_ua_push_xml_escaped_utf8(output, title)
  pdf_ua_push_ascii(
    output, "</rdf:li></rdf:Alt></dc:title>\n</rdf:Description>\n",
  )
  pdf_ua_push_ascii(
    output, "<rdf:Description rdf:about=\"\" xmlns:pdfuaid=\"http://www.aiim.org/pdfua/ns/id/\">\n",
  )
  pdf_ua_push_pdfua_marker(output, subformat)
  pdf_ua_push_ascii(
    output, "</rdf:Description>\n</rdf:RDF>\n</x:xmpmeta>\n<?xpacket end=\"w\"?>",
  )
  Bytes::from_array(output)
}

///|
fn pdf_ua_metadata_stream(
  subformat : PdfUASubformat,
  title : String,
) -> PdfObject {
  let metadata = pdf_ua_metadata_bytes(subformat, title)
  pdf_stream(
    PdfDictionary([
      (pdf_ua_length_key(), PdfInteger(metadata.length())),
      (pdf_ua_type_key(), PdfNameObject(pdf_ua_metadata())),
      (pdf_ua_subtype_key(), PdfNameObject(pdf_ua_xml())),
    ]),
    StreamGot(metadata),
  )
}

///|
fn PdfDocument::pdf_ua_apply_subformat_metadata(
  self : PdfDocument,
  subformat : PdfUASubformat,
  title : String,
) -> Unit raise PdfError {
  match subformat {
    PdfUA1 => self.set_version(1, 7)
    PdfUA2 => self.set_version(2, 0)
  }
  let info_number = self.add_object(
    PdfDictionary([(pdf_ua_title_key(), PdfString(@utf8.encode(title)))]),
  )
  let metadata_number = self.add_object(
    pdf_ua_metadata_stream(subformat, title),
  )
  self.set_trailer_dict(
    self
    .trailer_dict()
    .add_dict_entry(pdf_ua_info_key(), PdfIndirect(info_number)),
  )
  self.replace_chain(
    [pdf_ua_root_key(), pdf_ua_markinfo_key(), pdf_ua_marked_key()],
    PdfBoolean(true),
  )
  self.replace_chain(
    [pdf_ua_root_key(), pdf_ua_lang_key()],
    PdfString(@ascii.encode("en-US")),
  )
  self.replace_chain(
    [
      pdf_ua_root_key(),
      pdf_ua_viewer_preferences_key(),
      pdf_ua_display_doc_title_key(),
    ],
    PdfBoolean(true),
  )
  self.replace_chain(
    [pdf_ua_root_key(), pdf_ua_metadata_key()],
    PdfIndirect(metadata_number),
  )
  self.replace_chain(
    [pdf_ua_root_key(), pdf_ua_struct_tree_root_key(), pdf_ua_type_key()],
    PdfNameObject(pdf_ua_struct_tree_root()),
  )
}

///|
fn pdf_ua_create_pdfua(
  subformat : PdfUASubformat,
  title : String,
  paper : PaperSize,
  page_count : Int,
) -> PdfDocument raise PdfError {
  let document = pdf_create_blank_document_with_id_time(
    paper, page_count, pdf_create_now_as_double,
  )
  document.pdf_ua_apply_subformat_metadata(subformat, title)
  document
}

///|
/// Create a blank PDF/UA-1 document with the given title and page size.
pub fn pdf_ua_create_pdfua1(
  title : String,
  paper : PaperSize,
  page_count : Int,
) -> PdfDocument raise PdfError {
  pdf_ua_create_pdfua(PdfUA1, title, paper, page_count)
}

///|
/// Create a blank PDF/UA-2 document with the given title and page size.
pub fn pdf_ua_create_pdfua2(
  title : String,
  paper : PaperSize,
  page_count : Int,
) -> PdfDocument raise PdfError {
  pdf_ua_create_pdfua(PdfUA2, title, paper, page_count)
}
