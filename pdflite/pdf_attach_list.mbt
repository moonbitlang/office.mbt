///|
fn PdfDocument::pdf_attach_stream_data(
  self : PdfDocument,
  stream : @syntax.PdfObject,
) -> PdfBytes raise PdfError {
  self.pdf_decode_stream(stream).stream_bytes()
}

///|
fn PdfDocument::pdf_attach_raw_stream_size(
  self : PdfDocument,
  stream : @syntax.PdfObject,
) -> Int raise PdfError {
  self.direct(stream).stream_bytes().length()
}

///|
fn PdfDocument::pdf_attach_file_spec_data(
  self : PdfDocument,
  file_spec : @syntax.PdfObject,
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
  file_spec : @syntax.PdfObject,
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
  file_spec : @syntax.PdfObject,
) -> String? raise PdfError {
  match self.lookup_direct(pdf_attach_desc_key(), file_spec) {
    Some(PdfString(bytes)) => Some(pdf_attach_string_of_pdfdoc_string(bytes))
    _ => None
  }
}

///|
fn PdfDocument::pdf_attach_file_spec_relationship(
  self : PdfDocument,
  file_spec : @syntax.PdfObject,
) -> String? {
  match self.lookup_direct(pdf_attach_af_relationship_key(), file_spec) {
    Some(PdfNameObject(name)) => pdf_attach_relationship_text(name)
    _ => None
  }
}

///|
fn PdfDocument::pdf_attach_document_attachments(
  self : PdfDocument,
) -> Array[@attachment.PdfAttachment] raise PdfError {
  let catalog = self.catalog()
  match self.lookup_direct(pdf_attach_names_key(), catalog) {
    Some(names) =>
      match self.lookup_direct(pdf_attach_embedded_files_key(), names) {
        Some(tree) => {
          let entries = self.read_name_tree(tree)
          let output : Array[@attachment.PdfAttachment] = Array::new(
            capacity=entries.length(),
          )
          for entry in entries {
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
          output
        }
        None => []
      }
    None => []
  }
}

///|
fn PdfDocument::pdf_attach_is_file_attachment_annotation(
  self : PdfDocument,
  annotation : @syntax.PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_attach_subtype_key(), annotation) {
    Some(PdfNameObject(name)) => name == pdf_attach_file_attachment()
    _ => false
  }
}

///|
fn PdfDocument::pdf_attach_page_attachments(
  self : PdfDocument,
) -> Array[@attachment.PdfAttachment] raise PdfError {
  let pages = self.pages_of_pagetree()
  let output : Array[@attachment.PdfAttachment] = Array::new(
    capacity=pages.length(),
  )
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
) -> Array[@attachment.PdfAttachment] raise PdfError {
  [
    ..self.pdf_attach_document_attachments(),
    ..self.pdf_attach_page_attachments(),
  ]
}

///|
/// Compatibility wrapper for `PdfDocument::list_attached_files`.
pub fn pdf_list_attached_files(
  document : PdfDocument,
) -> Array[@attachment.PdfAttachment] raise PdfError {
  document.list_attached_files()
}
