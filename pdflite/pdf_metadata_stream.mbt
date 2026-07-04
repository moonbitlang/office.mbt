///|
fn pdf_metadata_stream(data : BytesView) -> @syntax.PdfObject {
  @syntax.pdf_stream(
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
) -> PdfDocument raise @core.PdfError {
  let document = self.copy()
  let metadata_number = document.add_object(pdf_metadata_stream(data))
  document.pdf_metadata_update_catalog(fn(catalog) raise @core.PdfError {
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
) -> PdfDocument raise @core.PdfError {
  match self.metadata() {
    None => self
    Some(metadata) => {
      let value = if date == "now" {
        pdf_metadata_xmp_date(pdf_metadata_expand_date(date))
      } else {
        date
      }
      let updated = pdf_metadata_rewrite_xmp_field(
        metadata, @metadata.pdf_metadata_xmp_namespace, "xmp", "MetadataDate", value,
      )
      self.set_metadata_from_bytes(updated, keep_version=true)
    }
  }
}

///|
/// Create a fresh XMP metadata stream from the document `/Info` dictionary.
pub fn PdfDocument::create_metadata(
  self : PdfDocument,
) -> PdfDocument raise @core.PdfError {
  let mut xmp = pdf_metadata_xmp_template
  for replacement in self.pdf_metadata_template_replacements() {
    xmp = pdf_metadata_replace_all(xmp, replacement.0, replacement.1)
  }
  self.set_metadata_from_bytes(@utf8.encode(xmp))
}

///|
/// Extract the catalog metadata XML stream, decoding supported stream filters.
pub fn PdfDocument::metadata(
  self : PdfDocument,
) -> @core.PdfBytes? raise @core.PdfError {
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
) -> PdfDocument raise @core.PdfError {
  let document = self.copy()
  document.pdf_metadata_update_catalog(fn(catalog) raise @core.PdfError {
    catalog.remove_dict_entry(pdf_metadata_metadata())
  })
  document
}

///|
/// Remove the catalog metadata entry and every parsed object whose `/Type` is
/// `/Metadata`.
pub fn PdfDocument::remove_all_metadata(
  self : PdfDocument,
) -> PdfDocument raise @core.PdfError {
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
