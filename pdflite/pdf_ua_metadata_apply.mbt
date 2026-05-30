///|
fn pdf_ua_metadata_stream(
  subformat : PdfUASubformat,
  title : String,
) -> @syntax.PdfObject {
  let metadata = pdf_ua_metadata_bytes(subformat, title)
  @syntax.pdf_stream(
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
) -> Unit raise @core.PdfError {
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
