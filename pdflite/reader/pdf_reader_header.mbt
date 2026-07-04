///|
/// Parsed PDF header version.
///
/// The fields correspond to the digits in a `%PDF-major.minor` header.
pub(all) struct PdfVersion {
  major : Int
  minor : Int
} derive(Debug, Eq, ToJson)

///|
/// Fallback version used when a PDF header cannot be found.
pub let pdf_default_version : PdfVersion = { major: 2, minor: 0 }

///|
fn pdf_header_at(cursor : @core.ByteCursor, position : Int) -> PdfVersion? {
  let header : Result[BytesView, Error] = try
    cursor.view_at_absolute(position, 8)
  catch {
    err => Err(err)
  } noraise {
    value => Ok(value)
  }
  match header {
    Ok(header) =>
      if header[0].to_int() == 37 &&
        header[1].to_int() == 80 &&
        header[2].to_int() == 68 &&
        header[3].to_int() == 70 &&
        header[4].to_int() == 45 &&
        header[6].to_int() == 46 {
        let major = header[5].to_int()
        let minor = header[7].to_int()
        if @core.pdf_is_digit_byte(major) && @core.pdf_is_digit_byte(minor) {
          Some({ major: major - 48, minor: minor - 48 })
        } else {
          None
        }
      } else {
        None
      }
    Err(_) => None
  }
}

///|
fn pdf_header_probe_length(length : Int) -> Int {
  if length < 1024 {
    length
  } else {
    1024
  }
}

///|
fn pdf_finish_header_at(
  cursor : @core.ByteCursor,
  position : Int,
  version : PdfVersion,
) -> PdfVersion raise @core.PdfError {
  cursor.set_offset(position)
  cursor.seek_absolute(position + 8)
  version
}

///|
/// Read the PDF header from the current cursor buffer.
///
/// The reader probes the first 1024 bytes for `%PDF-x.y`. When found, the cursor
/// offset is set to the header position and the cursor advances past the header.
/// If no header is found, `pdf_default_version` is returned.
pub fn pdf_read_header_from_cursor(
  cursor : @core.ByteCursor,
) -> PdfVersion raise @core.PdfError {
  let max_probe = pdf_header_probe_length(cursor.length())
  for position in 0..<=max_probe {
    match pdf_header_at(cursor, position) {
      Some(version) => break pdf_finish_header_at(cursor, position, version)
      None => ()
    }
  } nobreak {
    pdf_default_version
  }
}

///|
/// Read a PDF header version from a borrowed byte view.
pub fn pdf_read_header_from_view(
  data : BytesView,
) -> PdfVersion raise @core.PdfError {
  pdf_read_header_from_cursor(@core.byte_cursor_of_view(data))
}

///|
/// Read a PDF header version from owned PDF bytes.
pub fn pdf_read_header_from_bytes(
  data : @core.PdfBytes,
) -> PdfVersion raise @core.PdfError {
  pdf_read_header_from_view(data)
}
