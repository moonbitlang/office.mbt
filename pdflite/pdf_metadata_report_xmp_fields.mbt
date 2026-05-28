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
