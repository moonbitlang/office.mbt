///|
/// Return cpdf-style XMP metadata report fields as JSON.
pub fn PdfDocument::xmp_info_json(
  self : PdfDocument,
) -> Json raise @core.PdfError {
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
) -> @core.PdfBytes raise @core.PdfError {
  @utf8.encode(self.xmp_info_json().stringify())
}

///|
/// Return cpdf-style XMP metadata report fields as stdout-style UTF-8 bytes.
pub fn PdfDocument::xmp_info_blob(
  self : PdfDocument,
) -> @core.PdfBytes raise @core.PdfError {
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
