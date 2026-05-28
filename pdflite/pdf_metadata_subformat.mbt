///|
fn pdf_metadata_decode_pdf_string(value : BytesView) -> String? {
  let text = @utf8.decode(value) catch { _ => return None }
  Some(text)
}

///|
fn PdfDocument::pdf_metadata_fallback_pdfx(self : PdfDocument) -> String? {
  match self.lookup_direct(pdf_metadata_info(), self.trailer_dict()) {
    Some(info) =>
      match self.lookup_direct(pdf_metadata_name("/GTS_PDFXVersion"), info) {
        Some(PdfString(value)) => pdf_metadata_decode_pdf_string(value)
        _ => None
      }
    None => None
  }
}

///|
fn pdf_metadata_reverse_strings(values : ArrayView[String]) -> Array[String] {
  let output : Array[String] = []
  for offset in 0..<values.length() {
    let index = values.length() - 1 - offset
    output.push(values[index])
  }
  output
}

///|
fn pdf_metadata_push_if_some(values : Array[String], value : String?) -> Unit {
  match value {
    Some(value) if value != "" => values.push(value)
    _ => ()
  }
}

///|
fn pdf_metadata_namespace_fallback_prefix(xml_uri : String) -> String {
  if xml_uri == pdf_metadata_adobe_namespace {
    "pdf"
  } else if xml_uri == pdf_metadata_xmp_namespace {
    "xmp"
  } else if xml_uri == pdf_metadata_dc_namespace {
    "dc"
  } else if xml_uri == pdf_metadata_pdfuaid_namespace {
    "pdfuaid"
  } else if xml_uri == pdf_metadata_pdfe_namespace {
    "pdfe"
  } else if xml_uri == pdf_metadata_pdfaid_namespace {
    "pdfaid"
  } else if xml_uri == pdf_metadata_pdfxid_namespace {
    "pdfxid"
  } else if xml_uri == pdf_metadata_pdfvtid_namespace {
    "pdfvtid"
  } else {
    ""
  }
}

///|
fn pdf_metadata_name_with_slash(name : PdfName) -> String? {
  let text = @ascii.decode(name.bytes()) catch { _ => return None }
  Some(text)
}

///|
fn pdf_metadata_xmp_info_fields(key : PdfName) -> Array[(String, String)]? {
  match pdf_metadata_name_with_slash(key) {
    Some("/Title") =>
      Some([
        (pdf_metadata_adobe_namespace, "Title"),
        (pdf_metadata_dc_namespace, "title"),
      ])
    Some("/Author") =>
      Some([
        (pdf_metadata_adobe_namespace, "Author"),
        (pdf_metadata_dc_namespace, "creator"),
      ])
    Some("/Subject") =>
      Some([
        (pdf_metadata_adobe_namespace, "Subject"),
        (pdf_metadata_dc_namespace, "subject"),
      ])
    Some("/Keywords") => Some([(pdf_metadata_adobe_namespace, "Keywords")])
    Some("/Creator") =>
      Some([
        (pdf_metadata_adobe_namespace, "Creator"),
        (pdf_metadata_xmp_namespace, "CreatorTool"),
      ])
    Some("/Producer") => Some([(pdf_metadata_adobe_namespace, "Producer")])
    Some("/CreationDate") =>
      Some([
        (pdf_metadata_adobe_namespace, "CreationDate"),
        (pdf_metadata_xmp_namespace, "CreateDate"),
      ])
    Some("/ModDate") =>
      Some([
        (pdf_metadata_adobe_namespace, "ModificationDate"),
        (pdf_metadata_xmp_namespace, "ModifyDate"),
      ])
    _ => None
  }
}

///|
/// Return XMP metadata corresponding to a legacy `/Info` key.
pub fn PdfDocument::xmp_info(self : PdfDocument, key : PdfName) -> String {
  let fields = match pdf_metadata_xmp_info_fields(key) {
    Some(fields) => fields
    None => return ""
  }
  let metadata = try self.metadata() catch {
    _ => return ""
  } noraise {
    Some(metadata) => metadata
    None => return ""
  }
  for field in fields {
    let value = pdf_metadata_get_xmp_data(
      metadata,
      field.0,
      pdf_metadata_namespace_fallback_prefix(field.0),
      field.1,
    )
    match value {
      Some(value) if value != "" => break value
      _ => ()
    }
  } nobreak {
    ""
  }
}

///|
/// Return XMP metadata corresponding to a cpdf-style slash-prefixed string key.
pub fn PdfDocument::xmp_info_string(self : PdfDocument, key : String) -> String {
  self.xmp_info(pdf_metadata_source_key_name(key))
}

///|
/// Determine PDF/A, PDF/E, PDF/UA, PDF/VT, and PDF/X subformat markers.
///
/// This ports cpdf's in-memory subformat detection. It recognizes simple XMP
/// element and attribute forms and falls back to `/Info /GTS_PDFXVersion`.
pub fn PdfDocument::determine_subformats(
  self : PdfDocument,
) -> Array[String] raise PdfError {
  let formats : Array[String] = []
  match self.metadata() {
    None =>
      pdf_metadata_push_if_some(formats, self.pdf_metadata_fallback_pdfx())
    Some(metadata) => {
      pdf_metadata_push_if_some(
        formats,
        pdf_metadata_get_xmp_data(
          metadata, pdf_metadata_pdfe_namespace, "pdfe", "ISO_PDFEVersion",
        ),
      )
      match
        pdf_metadata_get_xmp_data(
          metadata, pdf_metadata_pdfuaid_namespace, "pdfuaid", "part",
        ) {
        Some(part) if part != "" => formats.push("PDF/UA-" + part)
        _ => ()
      }
      let pdfa_part = match
        pdf_metadata_get_xmp_data(
          metadata, pdf_metadata_pdfaid_namespace, "pdfaid", "part",
        ) {
        Some(part) => Some(part)
        None =>
          match
            pdf_metadata_get_xmp_data(
              metadata, pdf_metadata_pdfaid_wrong_acrobat_namespace, "pdfaid", "part",
            ) {
            Some(part) => Some(part)
            None =>
              pdf_metadata_get_xmp_data(
                metadata, pdf_metadata_pdfaid_wrong_iso_namespace, "pdfaid", "part",
              )
          }
      }
      match pdfa_part {
        Some(part) if part != "" => {
          let conformance = match
            pdf_metadata_get_xmp_data(
              metadata, pdf_metadata_pdfaid_namespace, "pdfaid", "conformance",
            ) {
            Some(value) => value.to_lower()
            None =>
              match
                pdf_metadata_get_xmp_data(
                  metadata, pdf_metadata_pdfaid_wrong_acrobat_namespace, "pdfaid",
                  "conformance",
                ) {
                Some(value) => value.to_lower()
                None =>
                  match
                    pdf_metadata_get_xmp_data(
                      metadata, pdf_metadata_pdfaid_wrong_iso_namespace, "pdfaid",
                      "conformance",
                    ) {
                    Some(value) => value.to_lower()
                    None => ""
                  }
              }
          }
          formats.push("PDF/A-" + part + conformance)
        }
        _ => ()
      }
      match
        pdf_metadata_get_xmp_data(
          metadata, pdf_metadata_pdfxid_namespace, "pdfxid", "GTS_PDFXVersion",
        ) {
        Some(value) if value != "" => formats.push(value)
        _ =>
          pdf_metadata_push_if_some(formats, self.pdf_metadata_fallback_pdfx())
      }
      pdf_metadata_push_if_some(
        formats,
        pdf_metadata_get_xmp_data(
          metadata, pdf_metadata_pdfvtid_namespace, "pdfvtid", "GTS_PDFVTVersion",
        ),
      )
    }
  }
  pdf_metadata_reverse_strings(formats)
}
