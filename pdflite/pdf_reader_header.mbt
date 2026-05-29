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
fn pdf_is_digit_byte(value : Int) -> Bool {
  value >= 48 && value <= 57
}

///|
fn ByteCursor::pdf_header_at(self : ByteCursor, position : Int) -> PdfVersion? {
  let header : Result[BytesView, Error] = try? self.view_at_absolute(
    position, 8,
  )
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
        if pdf_is_digit_byte(major) && pdf_is_digit_byte(minor) {
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
fn ByteCursor::finish_pdf_header_at(
  self : ByteCursor,
  position : Int,
  version : PdfVersion,
) -> PdfVersion raise PdfError {
  self.set_offset(position)
  self.seek_absolute(position + 8)
  version
}

///|
/// Read the PDF header from the current cursor buffer.
///
/// The reader probes the first 1024 bytes for `%PDF-x.y`. When found, the cursor
/// offset is set to the header position and the cursor advances past the header.
/// If no header is found, `pdf_default_version` is returned.
pub fn ByteCursor::read_pdf_header(
  self : ByteCursor,
) -> PdfVersion raise PdfError {
  let max_probe = pdf_header_probe_length(self.length())
  for position in 0..<=max_probe {
    match self.pdf_header_at(position) {
      Some(version) => break self.finish_pdf_header_at(position, version)
      None => ()
    }
  } nobreak {
    pdf_default_version
  }
}

///|
/// Read a PDF header version from a borrowed byte view.
pub fn pdf_read_header_from_view(data : BytesView) -> PdfVersion raise PdfError {
  byte_cursor_of_view(data).read_pdf_header()
}

///|
/// Read a PDF header version from owned PDF bytes.
pub fn pdf_read_header_from_bytes(data : PdfBytes) -> PdfVersion raise PdfError {
  pdf_read_header_from_view(data)
}

///|
/// Build a document from already parsed indirect objects.
///
/// Objects are loaded at their existing object numbers and generations without
/// recording mutation events. The document version defaults to
/// `pdf_default_version`.
pub fn pdf_document_of_parsed_indirect_objects(
  objects : ArrayView[PdfParsedIndirectObject],
  version? : PdfVersion = pdf_default_version,
) -> PdfDocument {
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  for parsed in objects {
    document.load_object_given_number(
      parsed.number,
      parsed.object,
      generation=parsed.generation,
    )
  }
  document
}

///|
/// Parse indirect objects by scanning the byte stream without xref tables.
///
/// This primitive reader is useful for fixtures and damaged files. It reads the
/// header, then scans indirect object syntax and stream bodies in sequence; it
/// does not interpret trailer/xref metadata or decrypt the document.
pub fn pdf_read_primitive_document_from_view(
  data : BytesView,
) -> PdfDocument raise PdfError {
  let cursor = byte_cursor_of_view(data)
  let version = cursor.read_pdf_header()
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  let mut done = false
  while !done {
    let (objects, prefix) = pdf_parse_indirect_object_segments(
      cursor.lex_pdf_tokens(),
    )
    for parsed in objects {
      document.load_object_given_number(
        parsed.number,
        parsed.object,
        generation=parsed.generation,
      )
    }
    match prefix {
      Some(prefix) =>
        if cursor.stopped_at_pdf_stream_candidate() {
          let stream = cursor.finish_pdf_stream_object(prefix)
          document.load_object_given_number(
            stream.number,
            stream.object,
            generation=stream.generation,
          )
        } else {
          document.load_object_given_number(
            prefix.number,
            prefix.object,
            generation=prefix.generation,
          )
          done = true
        }
      None => done = true
    }
  }
  document
}

///|
/// Parse a primitive document from owned PDF bytes.
pub fn pdf_read_primitive_document_from_bytes(
  data : PdfBytes,
) -> PdfDocument raise PdfError {
  pdf_read_primitive_document_from_view(data)
}
