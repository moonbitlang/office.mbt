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
fn pdf_attach_annotation_rect(bounds : @geometry.PdfRectangle) -> PdfObject {
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
  let annotation = @syntax.PdfDictionary([
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
