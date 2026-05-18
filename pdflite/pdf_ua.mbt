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
fn pdf_ua_push_pdfua_marker_part(
  output : Array[Byte],
  part : String,
  revision : Int?,
) -> Unit {
  pdf_ua_push_ascii(output, "<pdfuaid:part>")
  pdf_ua_push_ascii(output, part)
  pdf_ua_push_ascii(output, "</pdfuaid:part>\n")
  match revision {
    Some(year) => {
      pdf_ua_push_ascii(output, "<pdfuaid:rev>")
      pdf_ua_push_ascii(output, year.to_string())
      pdf_ua_push_ascii(output, "</pdfuaid:rev>\n")
    }
    None => ()
  }
}

///|
fn pdf_ua_qualified_name(prefix : String, name : String) -> String {
  if prefix == "" {
    name
  } else {
    prefix + ":" + name
  }
}

///|
fn pdf_ua_marker_description_bytes(
  rdf_prefix : String,
  part : String,
  revision : Int?,
) -> PdfBytes {
  let rdf_description = pdf_ua_qualified_name(rdf_prefix, "Description")
  let rdf_about = pdf_ua_qualified_name(rdf_prefix, "about")
  let output : Array[Byte] = []
  pdf_ua_push_ascii(output, "<" + rdf_description + " " + rdf_about + "=\"\" ")
  pdf_ua_push_ascii(output, "xmlns:pdfuaid=\"")
  pdf_ua_push_ascii(output, pdf_metadata_pdfuaid_namespace)
  pdf_ua_push_ascii(output, "\">\n")
  pdf_ua_push_pdfua_marker_part(output, part, revision)
  pdf_ua_push_ascii(output, "</" + rdf_description + ">\n")
  Bytes::from_array(output)
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
fn pdf_ua_xml_tag_is_self_closing(
  data : BytesView,
  tag_start : Int,
  tag_end : Int,
) -> Bool {
  let mut position = tag_end - 1
  while position > tag_start && pdf_metadata_is_xml_space(data[position]) {
    position -= 1
  }
  position > tag_start && data[position].to_int() == 47
}

///|
fn pdf_ua_remove_xml_element_prefix(
  data : BytesView,
  prefix : String,
  field : String,
) -> (PdfBytes, Bool) {
  let open_pattern = @ascii.encode("<" + prefix + ":" + field)
  let close_pattern = @ascii.encode("</" + prefix + ":" + field + ">")
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
        } else if pdf_ua_xml_tag_is_self_closing(data, tag_start, tag_end) {
          pdf_metadata_push_view(output, data[search_start:tag_start])
          search_start = tag_end + 1
          changed = true
        } else {
          let value_end = pdf_metadata_find_bytes_from(
            data,
            tag_end + 1,
            close_pattern,
          )
          if value_end < 0 {
            pdf_metadata_push_view(output, data[search_start:])
            search_start = data.length()
          } else {
            pdf_metadata_push_view(output, data[search_start:tag_start])
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
fn pdf_ua_remove_marker_elements(data : BytesView) -> PdfBytes {
  let prefixes = pdf_metadata_namespace_prefixes(
    data, pdf_metadata_pdfuaid_namespace, "pdfuaid",
  )
  let mut output = data.to_owned()
  for prefix in prefixes {
    for field in ["part", "rev", "amd", "corr"] {
      let (rewritten, _) = pdf_ua_remove_xml_element_prefix(
        output, prefix, field,
      )
      output = rewritten
    }
  }
  output
}

///|
fn pdf_ua_find_rdf_open_tag(data : BytesView) -> (Int, String)? {
  let prefixes = pdf_metadata_namespace_prefixes(
    data, pdf_metadata_rdf_namespace, "rdf",
  )
  for prefix in prefixes {
    let pattern = @ascii.encode("<" + prefix + ":RDF")
    let mut search_start = 0
    while search_start < data.length() {
      let tag_start = pdf_metadata_find_bytes_from(data, search_start, pattern)
      if tag_start < 0 {
        search_start = data.length()
      } else {
        let name_end = tag_start + pattern.length()
        if name_end < data.length() &&
          pdf_metadata_xml_tag_boundary(data[name_end]) {
          let tag_end = pdf_metadata_find_byte(data, name_end, 62)
          if tag_end >= 0 {
            return Some((tag_end + 1, prefix))
          }
        }
        search_start = name_end
      }
    }
  }
  None
}

///|
fn pdf_ua_insert_marker_description(
  data : BytesView,
  part : String,
  revision : Int?,
) -> PdfBytes raise PdfError {
  match pdf_ua_find_rdf_open_tag(data) {
    Some((insert_at, rdf_prefix)) => {
      let marker = pdf_ua_marker_description_bytes(rdf_prefix, part, revision)
      let output : Array[Byte] = []
      pdf_metadata_push_view(output, data[:insert_at])
      pdf_metadata_push_view(output, marker)
      pdf_metadata_push_view(output, data[insert_at:])
      Bytes::from_array(output)
    }
    None =>
      raise SoftError(
        "insert_as_rdf_description: could not find insertion point.",
      )
  }
}

///|
fn PdfDocument::pdf_ua_mark_inner(
  self : PdfDocument,
  part : String,
  revision : Int?,
) -> PdfDocument raise PdfError {
  let document = match self.metadata() {
    Some(_) => self
    None => self.create_metadata()
  }
  match document.metadata() {
    Some(metadata) => {
      let without_marker = pdf_ua_remove_marker_elements(metadata)
      let marked = pdf_ua_insert_marker_description(
        without_marker, part, revision,
      )
      document.set_metadata_from_bytes(marked, keep_version=true)
    }
    None => raise SoftError("mark_pdfua: could not create metadata")
  }
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

///|
/// Return a copy of the document marked as PDF/UA-1 in its XMP metadata.
pub fn PdfDocument::mark_pdfua1(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  self.pdf_ua_mark_inner("1", None)
}

///|
/// Return a copy of the document marked as PDF/UA-2 for the given revision year.
pub fn PdfDocument::mark_pdfua2(
  self : PdfDocument,
  year : Int,
) -> PdfDocument raise PdfError {
  self.pdf_ua_mark_inner("2", Some(year))
}

///|
/// Return a copy of the document with PDF/UA XMP marker fields removed.
pub fn PdfDocument::remove_pdfua_mark(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  match self.metadata() {
    None => self
    Some(metadata) => {
      let without_marker = pdf_ua_remove_marker_elements(metadata)
      self.set_metadata_from_bytes(without_marker, keep_version=true)
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::mark_pdfua1`.
pub fn pdf_ua_mark(document : PdfDocument) -> PdfDocument raise PdfError {
  document.mark_pdfua1()
}

///|
/// Compatibility wrapper for `PdfDocument::mark_pdfua2`.
pub fn pdf_ua_mark2(
  year : Int,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.mark_pdfua2(year)
}

///|
/// Compatibility wrapper for `PdfDocument::remove_pdfua_mark`.
pub fn pdf_ua_remove_mark(document : PdfDocument) -> PdfDocument raise PdfError {
  document.remove_pdfua_mark()
}
