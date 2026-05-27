///|
fn pdf_attach_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_attach_root_key_name : PdfName = pdf_attach_name("/Root")

///|
fn pdf_attach_root_key() -> PdfName {
  pdf_attach_root_key_name
}

///|
let pdf_attach_names_key_name : PdfName = pdf_attach_name("/Names")

///|
fn pdf_attach_names_key() -> PdfName {
  pdf_attach_names_key_name
}

///|
let pdf_attach_embedded_files_key_name : PdfName = pdf_attach_name(
  "/EmbeddedFiles",
)

///|
fn pdf_attach_embedded_files_key() -> PdfName {
  pdf_attach_embedded_files_key_name
}

///|
let pdf_attach_type_key_name : PdfName = pdf_attach_name("/Type")

///|
fn pdf_attach_type_key() -> PdfName {
  pdf_attach_type_key_name
}

///|
let pdf_attach_length_key_name : PdfName = pdf_attach_name("/Length")

///|
fn pdf_attach_length_key() -> PdfName {
  pdf_attach_length_key_name
}

///|
let pdf_attach_params_key_name : PdfName = pdf_attach_name("/Params")

///|
fn pdf_attach_params_key() -> PdfName {
  pdf_attach_params_key_name
}

///|
let pdf_attach_size_key_name : PdfName = pdf_attach_name("/Size")

///|
fn pdf_attach_size_key() -> PdfName {
  pdf_attach_size_key_name
}

///|
let pdf_attach_checksum_key_name : PdfName = pdf_attach_name("/CheckSum")

///|
fn pdf_attach_checksum_key() -> PdfName {
  pdf_attach_checksum_key_name
}

///|
let pdf_attach_embedded_file_name : PdfName = pdf_attach_name("/EmbeddedFile")

///|
fn pdf_attach_embedded_file() -> PdfName {
  pdf_attach_embedded_file_name
}

///|
let pdf_attach_filespec_name : PdfName = pdf_attach_name("/Filespec")

///|
fn pdf_attach_filespec() -> PdfName {
  pdf_attach_filespec_name
}

///|
let pdf_attach_ef_key_name : PdfName = pdf_attach_name("/EF")

///|
fn pdf_attach_ef_key() -> PdfName {
  pdf_attach_ef_key_name
}

///|
let pdf_attach_f_key_name : PdfName = pdf_attach_name("/F")

///|
fn pdf_attach_f_key() -> PdfName {
  pdf_attach_f_key_name
}

///|
let pdf_attach_uf_key_name : PdfName = pdf_attach_name("/UF")

///|
fn pdf_attach_uf_key() -> PdfName {
  pdf_attach_uf_key_name
}

///|
let pdf_attach_desc_key_name : PdfName = pdf_attach_name("/Desc")

///|
fn pdf_attach_desc_key() -> PdfName {
  pdf_attach_desc_key_name
}

///|
let pdf_attach_af_relationship_key_name : PdfName = pdf_attach_name(
  "/AFRelationship",
)

///|
fn pdf_attach_af_relationship_key() -> PdfName {
  pdf_attach_af_relationship_key_name
}

///|
let pdf_attach_annots_key_name : PdfName = pdf_attach_name("/Annots")

///|
fn pdf_attach_annots_key() -> PdfName {
  pdf_attach_annots_key_name
}

///|
let pdf_attach_subtype_key_name : PdfName = pdf_attach_name("/Subtype")

///|
fn pdf_attach_subtype_key() -> PdfName {
  pdf_attach_subtype_key_name
}

///|
let pdf_attach_file_attachment_name : PdfName = pdf_attach_name(
  "/FileAttachment",
)

///|
fn pdf_attach_file_attachment() -> PdfName {
  pdf_attach_file_attachment_name
}

///|
let pdf_attach_contents_key_name : PdfName = pdf_attach_name("/Contents")

///|
fn pdf_attach_contents_key() -> PdfName {
  pdf_attach_contents_key_name
}

///|
let pdf_attach_fs_key_name : PdfName = pdf_attach_name("/FS")

///|
fn pdf_attach_fs_key() -> PdfName {
  pdf_attach_fs_key_name
}

///|
let pdf_attach_rect_key_name : PdfName = pdf_attach_name("/Rect")

///|
fn pdf_attach_rect_key() -> PdfName {
  pdf_attach_rect_key_name
}

///|
/// One embedded file attachment.
///
/// `pagenumber == 0` represents a document-level attachment. Page attachments
/// use one-based page numbers. `data == None` represents a malformed page-level
/// attachment annotation with a file specification but no embedded-file stream.
pub(all) struct PdfAttachment {
  name : String
  pagenumber : Int
  data : PdfBytes?
  description : String?
  relationship : String?
} derive(Debug, Eq, ToJson)

///|
fn pdf_attach_is_path_separator(code_unit : UInt16) -> Bool {
  let value = code_unit.to_int()
  value == 47 || value == 92
}

///|
fn pdf_attach_basename(path : String) -> String {
  let mut start = 0
  for index in 0..<path.length() {
    if pdf_attach_is_path_separator(path.at(index)) {
      start = index + 1
    }
  }
  path[start:].to_owned()
}

///|
fn pdf_attach_pdfdoc_string(text : String) -> PdfBytes raise PdfError {
  pdf_pdfdocstring_of_utf8(@utf8.encode(text))
}

///|
fn pdf_attach_string_of_pdfdoc_string(
  bytes : BytesView,
) -> String raise PdfError {
  let utf8_bytes = pdf_utf8_of_pdfdocstring(bytes)
  @utf8.decode(utf8_bytes) catch {
    _ => raise InvalidUTF8
  }
}

///|
fn pdf_attach_relationship_name(relationship : String) -> PdfName {
  if relationship.has_prefix("/") {
    pdf_attach_name(relationship)
  } else {
    pdf_attach_name("/" + relationship)
  }
}

///|
fn pdf_attach_relationship_text(name : PdfName) -> String? {
  let decoded : Result[String, Error] = try? @ascii.decode(name.view())
  match decoded {
    Ok(text) => Some(text)
    Err(_) => None
  }
}

///|
fn pdf_attach_is_unsafe_filename_codepoint(codepoint : Int) -> Bool {
  codepoint == 47 ||
  codepoint == 63 ||
  codepoint == 60 ||
  codepoint == 62 ||
  codepoint == 92 ||
  codepoint == 58 ||
  codepoint == 42 ||
  codepoint == 124 ||
  codepoint == 34 ||
  codepoint == 94 ||
  codepoint == 43 ||
  codepoint == 61 ||
  codepoint < 32 ||
  codepoint == 127
}

///|
/// Remove characters which are unsafe in attachment dump filenames.
///
/// Input and output are Unicode text. This mirrors cpdf's filtering set and
/// intentionally preserves a leading dot, matching the source behavior.
pub fn pdf_attachment_remove_unsafe_characters(
  text : String,
) -> String raise PdfError {
  let output : Array[Int] = []
  for codepoint in pdf_codepoints_of_utf8(@utf8.encode(text)) {
    if !pdf_attach_is_unsafe_filename_codepoint(codepoint) {
      output.push(codepoint)
    }
  }
  pdf_attach_string_of_pdfdoc_string(
    pdf_pdfdocstring_of_utf8(pdf_utf8_of_codepoints(output)),
  )
}

///|
/// Source-spelled compatibility alias for cpdfattach's filename sanitizer.
pub fn pdf_remove_unsafe_characters(text : String) -> String raise PdfError {
  pdf_attachment_remove_unsafe_characters(text)
}

///|
fn pdf_attach_embedded_file_stream(data : PdfBytes) -> PdfObject {
  pdf_stream(
    PdfDictionary([
      (pdf_attach_length_key(), PdfInteger(data.length())),
      (pdf_attach_type_key(), PdfNameObject(pdf_attach_embedded_file())),
      (
        pdf_attach_params_key(),
        PdfDictionary([
          (pdf_attach_size_key(), PdfInteger(data.length())),
          (
            pdf_attach_checksum_key(),
            PdfString(@crypt_core.pdf_md5_digest(data)),
          ),
        ]),
      ),
    ]),
    StreamGot(data),
  )
}

///|
fn PdfDocument::pdf_attach_file_spec(
  self : PdfDocument,
  basename : String,
  data : BytesView,
  relationship : String?,
  description : String?,
) -> PdfObject raise PdfError {
  let payload = data.to_owned()
  let stream_number = self.add_object(pdf_attach_embedded_file_stream(payload))
  let basename_bytes = pdf_attach_pdfdoc_string(basename)
  let entries : Array[(PdfName, PdfObject)] = [
    (
      pdf_attach_ef_key(),
      PdfDictionary([(pdf_attach_f_key(), PdfIndirect(stream_number))]),
    ),
    (pdf_attach_f_key(), PdfString(basename_bytes)),
    (pdf_attach_type_key(), PdfNameObject(pdf_attach_filespec())),
    (pdf_attach_uf_key(), PdfString(basename_bytes)),
  ]
  match description {
    Some(text) =>
      entries.push(
        (pdf_attach_desc_key(), PdfString(pdf_attach_pdfdoc_string(text))),
      )
    None => ()
  }
  match relationship {
    Some(text) =>
      entries.push(
        (
          pdf_attach_af_relationship_key(),
          PdfNameObject(pdf_attach_relationship_name(text)),
        ),
      )
    None => ()
  }
  PdfDictionary(entries)
}

///|
fn PdfDocument::pdf_attach_existing_document_entries(
  self : PdfDocument,
) -> Array[(PdfBytes, PdfObject)] raise PdfError {
  let catalog = self.catalog()
  match self.lookup_direct(pdf_attach_names_key(), catalog) {
    Some(names) =>
      match self.lookup_direct(pdf_attach_embedded_files_key(), names) {
        Some(tree) => self.read_name_tree(tree)
        None => []
      }
    None => []
  }
}

///|
fn PdfDocument::pdf_attach_add_document_file(
  self : PdfDocument,
  basename_bytes : PdfBytes,
  file_spec_number : Int,
) -> Unit raise PdfError {
  let entries = self.pdf_attach_existing_document_entries()
  entries.push((basename_bytes, PdfIndirect(file_spec_number)))
  let tree_number = self.add_object(self.build_name_tree(entries))
  self.replace_chain(
    [
      pdf_attach_root_key(),
      pdf_attach_names_key(),
      pdf_attach_embedded_files_key(),
    ],
    PdfIndirect(tree_number),
  )
}

///|
fn pdf_attach_annotation_rect(bounds : PdfRectangle) -> PdfObject {
  PdfArray([
    PdfReal(18.0),
    PdfReal(bounds.max_y - 45.0),
    PdfReal(45.0),
    PdfReal(bounds.max_y - 18.0),
  ])
}

///|
fn PdfDocument::pdf_attach_add_page_file(
  self : PdfDocument,
  page_number : Int,
  basename_bytes : PdfBytes,
  file_spec_number : Int,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  if page_number < 1 || page_number > pages.length() {
    raise BadPageSpecification("attach_file: Page not found")
  }
  let index = page_number - 1
  let page = pages[index]
  let annots = match self.lookup_direct(pdf_attach_annots_key(), page.rest) {
    Some(PdfArray(existing)) => existing
    Some(_) => raise DictionaryExpected
    None => []
  }
  let bounds = self.parse_rectangle(page.mediabox)
  let annotation = PdfDictionary([
    (pdf_attach_fs_key(), PdfIndirect(file_spec_number)),
    (pdf_attach_subtype_key(), PdfNameObject(pdf_attach_file_attachment())),
    (pdf_attach_contents_key(), PdfString(basename_bytes)),
    (pdf_attach_rect_key(), pdf_attach_annotation_rect(bounds)),
  ])
  pages[index] = {
    ..page,
    rest: page.rest.add_dict_entry(
      pdf_attach_annots_key(),
      PdfArray([annotation, ..annots]),
    ),
  }
  self.change_pages(pages, change_references=true)
}

///|
fn PdfDocument::pdf_attach_bump_version(
  self : PdfDocument,
  keep_version : Bool,
) -> Unit {
  let (major, minor) = self.version()
  if !keep_version && major <= 1 && minor < 4 {
    self.set_version(major, 4)
  }
}

///|
/// Attach an in-memory file payload to the document or to a one-based page.
///
/// The original document is left unchanged. `filename` supplies the attachment
/// basename; the payload bytes are copied. When `keep_version` is false, PDF
/// versions below 1.4 are bumped to 1.4 as in cpdf.
pub fn PdfDocument::attach_file(
  self : PdfDocument,
  filename : String,
  data : BytesView,
  keep_version? : Bool = false,
  page_number? : Int? = None,
  relationship? : String? = None,
  description? : String? = None,
) -> PdfDocument raise PdfError {
  ignore(self.catalog())
  let document = self.copy()
  let basename = pdf_attach_basename(filename)
  let basename_bytes = pdf_attach_pdfdoc_string(basename)
  let file_spec_number = document.add_object(
    document.pdf_attach_file_spec(basename, data, relationship, description),
  )
  let attached = match page_number {
    Some(number) =>
      document.pdf_attach_add_page_file(
        number, basename_bytes, file_spec_number,
      )
    None => {
      document.pdf_attach_add_document_file(basename_bytes, file_spec_number)
      document
    }
  }
  attached.pdf_attach_bump_version(keep_version)
  attached
}

///|
/// Compatibility wrapper for `PdfDocument::attach_file`.
pub fn pdf_attach_file(
  document : PdfDocument,
  filename : String,
  data : BytesView,
  keep_version? : Bool = false,
  page_number? : Int? = None,
  relationship? : String? = None,
  description? : String? = None,
) -> PdfDocument raise PdfError {
  document.attach_file(
    filename,
    data,
    keep_version~,
    page_number~,
    relationship~,
    description~,
  )
}

///|
/// Source-order compatibility wrapper for cpdfattach's in-memory attach path.
///
/// The OCaml source also has a filesystem path branch; native filesystem reads
/// live in `async_io/pdf_attach_file_from_path`.
pub fn pdf_attach_file_cpdf_order(
  keep_version : Bool,
  page_number : Int?,
  document : PdfDocument,
  relationship : String?,
  description : String?,
  filename : String,
  data : BytesView,
) -> PdfDocument raise PdfError {
  document.attach_file(
    filename,
    data,
    keep_version~,
    page_number~,
    relationship~,
    description~,
  )
}

///|
fn PdfDocument::pdf_attach_stream_data(
  self : PdfDocument,
  stream : PdfObject,
) -> PdfBytes raise PdfError {
  self.pdf_decode_stream(stream).stream_bytes()
}

///|
fn PdfDocument::pdf_attach_raw_stream_size(
  self : PdfDocument,
  stream : PdfObject,
) -> Int raise PdfError {
  self.direct(stream).stream_bytes().length()
}

///|
fn PdfDocument::pdf_attach_file_spec_data(
  self : PdfDocument,
  file_spec : PdfObject,
) -> PdfBytes? raise PdfError {
  match self.lookup_direct(pdf_attach_ef_key(), file_spec) {
    Some(ef) =>
      match self.lookup_direct(pdf_attach_f_key(), ef) {
        Some(stream) => Some(self.pdf_attach_stream_data(stream))
        None => raise DictionaryKeyNotFound(pdf_attach_f_key())
      }
    None => None
  }
}

///|
fn PdfDocument::pdf_attach_file_spec_raw_size(
  self : PdfDocument,
  file_spec : PdfObject,
) -> Int raise PdfError {
  match self.lookup_direct(pdf_attach_ef_key(), file_spec) {
    Some(ef) =>
      match self.lookup_direct(pdf_attach_f_key(), ef) {
        Some(stream) => self.pdf_attach_raw_stream_size(stream)
        None => raise DictionaryKeyNotFound(pdf_attach_f_key())
      }
    None => raise DictionaryKeyNotFound(pdf_attach_ef_key())
  }
}

///|
fn PdfDocument::pdf_attach_file_spec_description(
  self : PdfDocument,
  file_spec : PdfObject,
) -> String? raise PdfError {
  match self.lookup_direct(pdf_attach_desc_key(), file_spec) {
    Some(PdfString(bytes)) => Some(pdf_attach_string_of_pdfdoc_string(bytes))
    _ => None
  }
}

///|
fn PdfDocument::pdf_attach_file_spec_relationship(
  self : PdfDocument,
  file_spec : PdfObject,
) -> String? {
  match self.lookup_direct(pdf_attach_af_relationship_key(), file_spec) {
    Some(PdfNameObject(name)) => pdf_attach_relationship_text(name)
    _ => None
  }
}

///|
fn PdfDocument::pdf_attach_document_attachments(
  self : PdfDocument,
) -> Array[PdfAttachment] raise PdfError {
  let output : Array[PdfAttachment] = []
  let catalog = self.catalog()
  match self.lookup_direct(pdf_attach_names_key(), catalog) {
    Some(names) =>
      match self.lookup_direct(pdf_attach_embedded_files_key(), names) {
        Some(tree) =>
          for entry in self.read_name_tree(tree) {
            let file_spec = self.direct(entry.1)
            let data = match self.pdf_attach_file_spec_data(file_spec) {
              Some(bytes) => Some(bytes)
              None => raise DictionaryKeyNotFound(pdf_attach_ef_key())
            }
            output.push({
              name: pdf_attach_string_of_pdfdoc_string(entry.0),
              pagenumber: 0,
              data,
              description: self.pdf_attach_file_spec_description(file_spec),
              relationship: self.pdf_attach_file_spec_relationship(file_spec),
            })
          }
        None => ()
      }
    None => ()
  }
  output
}

///|
fn PdfDocument::pdf_attach_is_file_attachment_annotation(
  self : PdfDocument,
  annotation : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_attach_subtype_key(), annotation) {
    Some(PdfNameObject(name)) => name == pdf_attach_file_attachment()
    _ => false
  }
}

///|
fn PdfDocument::pdf_attach_page_attachments(
  self : PdfDocument,
) -> Array[PdfAttachment] raise PdfError {
  let output : Array[PdfAttachment] = []
  let pages = self.pages_of_pagetree()
  for index, page in pages {
    match self.lookup_direct(pdf_attach_annots_key(), page.rest) {
      Some(PdfArray(annotations)) =>
        for annotation in annotations {
          if self.pdf_attach_is_file_attachment_annotation(annotation) {
            match self.lookup_direct(pdf_attach_contents_key(), annotation) {
              Some(PdfString(name_bytes)) =>
                match self.lookup_direct(pdf_attach_fs_key(), annotation) {
                  Some(file_spec) =>
                    output.push({
                      name: pdf_attach_string_of_pdfdoc_string(name_bytes),
                      pagenumber: index + 1,
                      data: self.pdf_attach_file_spec_data(file_spec),
                      description: self.pdf_attach_file_spec_description(
                        file_spec,
                      ),
                      relationship: self.pdf_attach_file_spec_relationship(
                        file_spec,
                      ),
                    })
                  None => ()
                }
              _ => ()
            }
          }
        }
      _ => ()
    }
  }
  output
}

///|
/// List document-level and page-level file attachments.
pub fn PdfDocument::list_attached_files(
  self : PdfDocument,
) -> Array[PdfAttachment] raise PdfError {
  [
    ..self.pdf_attach_document_attachments(),
    ..self.pdf_attach_page_attachments(),
  ]
}

///|
/// Compatibility wrapper for `PdfDocument::list_attached_files`.
pub fn pdf_list_attached_files(
  document : PdfDocument,
) -> Array[PdfAttachment] raise PdfError {
  document.list_attached_files()
}

///|
fn PdfDocument::pdf_attach_remove_from_page(
  self : PdfDocument,
  page : PdfPage,
) -> PdfPage raise PdfError {
  let kept : Array[PdfObject] = []
  match self.lookup_direct(pdf_attach_annots_key(), page.rest) {
    Some(PdfArray(annotations)) =>
      for annotation in annotations {
        if !self.pdf_attach_is_file_attachment_annotation(annotation) {
          kept.push(annotation)
        }
      }
    _ => ()
  }
  {
    ..page,
    rest: page.rest.add_dict_entry(pdf_attach_annots_key(), PdfArray(kept)),
  }
}

///|
/// Remove document-level embedded files and page-level file attachment annotations.
///
/// The original document is left unchanged. Non-file-attachment annotations are
/// preserved.
pub fn PdfDocument::remove_attached_files(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for page in pages {
    rewritten.push(document.pdf_attach_remove_from_page(page))
  }
  let cleaned = document.change_pages(rewritten, change_references=true)
  ignore(
    cleaned.remove_chain([
      pdf_attach_root_key(),
      pdf_attach_names_key(),
      pdf_attach_embedded_files_key(),
    ]),
  )
  cleaned
}

///|
/// Compatibility wrapper for `PdfDocument::remove_attached_files`.
pub fn pdf_remove_attached_files(
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.remove_attached_files()
}

///|
fn PdfDocument::pdf_attach_document_size(
  self : PdfDocument,
) -> Int raise PdfError {
  let mut total = 0
  let catalog = self.catalog()
  match self.lookup_direct(pdf_attach_names_key(), catalog) {
    Some(names) =>
      match self.lookup_direct(pdf_attach_embedded_files_key(), names) {
        Some(tree) =>
          for entry in self.read_name_tree(tree) {
            total += self.pdf_attach_file_spec_raw_size(entry.1)
          }
        None => ()
      }
    None => ()
  }
  total
}

///|
fn PdfDocument::pdf_attach_page_size(self : PdfDocument) -> Int raise PdfError {
  let mut total = 0
  for page in self.pages_of_pagetree() {
    match self.lookup_direct(pdf_attach_annots_key(), page.rest) {
      Some(PdfArray(annotations)) =>
        for annotation in annotations {
          if self.pdf_attach_is_file_attachment_annotation(annotation) {
            match self.lookup_direct(pdf_attach_fs_key(), annotation) {
              Some(file_spec) =>
                total += self.pdf_attach_file_spec_raw_size(file_spec)
              None => ()
            }
          }
        }
      _ => ()
    }
  }
  total
}

///|
/// Return the total raw byte size of all embedded file attachment streams.
pub fn PdfDocument::size_attached_files(
  self : PdfDocument,
) -> Int raise PdfError {
  self.pdf_attach_document_size() + self.pdf_attach_page_size()
}

///|
/// Compatibility wrapper for `PdfDocument::size_attached_files`.
pub fn pdf_size_attached_files(document : PdfDocument) -> Int raise PdfError {
  document.size_attached_files()
}
