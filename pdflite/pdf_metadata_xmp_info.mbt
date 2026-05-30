///|
fn pdf_metadata_xml_value_of_object(
  value : @syntax.PdfObject,
) -> String raise PdfError {
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
fn pdf_metadata_xmp_date_of_object(
  value : @syntax.PdfObject,
) -> String raise PdfError {
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
  value : @syntax.PdfObject,
) -> (Array[(String, String)], String) raise PdfError {
  match pdf_metadata_name_with_slash(key) {
    Some("/Producer") =>
      (
        [(@metadata.pdf_metadata_adobe_namespace, "Producer")],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/Creator") =>
      (
        [
          (@metadata.pdf_metadata_adobe_namespace, "Creator"),
          (@metadata.pdf_metadata_xmp_namespace, "CreatorTool"),
          (@metadata.pdf_metadata_dc_namespace, "creator"),
        ],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/Author") =>
      (
        [(@metadata.pdf_metadata_adobe_namespace, "Author")],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/Title") =>
      (
        [
          (@metadata.pdf_metadata_adobe_namespace, "Title"),
          (@metadata.pdf_metadata_dc_namespace, "title"),
        ],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/Subject") =>
      (
        [
          (@metadata.pdf_metadata_adobe_namespace, "Subject"),
          (@metadata.pdf_metadata_dc_namespace, "subject"),
        ],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/Keywords") =>
      (
        [(@metadata.pdf_metadata_adobe_namespace, "Keywords")],
        pdf_metadata_xml_value_of_object(value),
      )
    Some("/CreationDate") =>
      (
        [
          (@metadata.pdf_metadata_adobe_namespace, "CreationDate"),
          (@metadata.pdf_metadata_xmp_namespace, "CreateDate"),
        ],
        pdf_metadata_xmp_date_of_object(value),
      )
    Some("/ModDate") =>
      (
        [
          (@metadata.pdf_metadata_adobe_namespace, "ModDate"),
          (@metadata.pdf_metadata_xmp_namespace, "ModifyDate"),
        ],
        pdf_metadata_xmp_date_of_object(value),
      )
    Some("/Trapped") =>
      (
        [(@metadata.pdf_metadata_adobe_namespace, "Trapped")],
        pdf_metadata_xml_value_of_object(value),
      )
    _ => raise BadNumberArgument("Unknown call to set_pdf_info")
  }
}
