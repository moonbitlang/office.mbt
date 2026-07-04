///|
fn pdf_ua_pdfua_marker_length(subformat : PdfUASubformat) -> Int {
  match subformat {
    PdfUA1 => pdf_ua_ascii_length("<pdfuaid:part>1</pdfuaid:part>\n")
    PdfUA2 =>
      pdf_ua_ascii_length("<pdfuaid:part>2</pdfuaid:part>\n") +
      pdf_ua_ascii_length("<pdfuaid:rev>2024</pdfuaid:rev>\n")
  }
}

///|
fn pdf_ua_write_pdfua_marker(
  output : Array[Byte],
  position : Int,
  subformat : PdfUASubformat,
) -> Int {
  match subformat {
    PdfUA1 =>
      pdf_ua_write_ascii(output, position, "<pdfuaid:part>1</pdfuaid:part>\n")
    PdfUA2 => {
      let mut current = pdf_ua_write_ascii(
        output, position, "<pdfuaid:part>2</pdfuaid:part>\n",
      )
      current = pdf_ua_write_ascii(
        output, current, "<pdfuaid:rev>2024</pdfuaid:rev>\n",
      )
      current
    }
  }
}

///|
fn pdf_ua_pdfua_marker_part_length(part : String, revision : Int?) -> Int {
  let mut length = pdf_ua_ascii_length("<pdfuaid:part>") +
    pdf_ua_ascii_length(part) +
    pdf_ua_ascii_length("</pdfuaid:part>\n")
  match revision {
    Some(year) =>
      length += pdf_ua_ascii_length("<pdfuaid:rev>") +
        pdf_ua_ascii_length(year.to_string()) +
        pdf_ua_ascii_length("</pdfuaid:rev>\n")
    None => ()
  }
  length
}

///|
fn pdf_ua_write_pdfua_marker_part(
  output : Array[Byte],
  position : Int,
  part : String,
  revision : Int?,
) -> Int {
  let mut current = pdf_ua_write_ascii(output, position, "<pdfuaid:part>")
  current = pdf_ua_write_ascii(output, current, part)
  current = pdf_ua_write_ascii(output, current, "</pdfuaid:part>\n")
  match revision {
    Some(year) => {
      current = pdf_ua_write_ascii(output, current, "<pdfuaid:rev>")
      current = pdf_ua_write_ascii(output, current, year.to_string())
      current = pdf_ua_write_ascii(output, current, "</pdfuaid:rev>\n")
      current
    }
    None => current
  }
}
