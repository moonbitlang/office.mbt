///|
/// Build a document from already parsed indirect objects.
///
/// Objects are loaded at their existing object numbers and generations without
/// recording mutation events. The document version defaults to
/// `@reader.pdf_default_version`.
pub fn pdf_document_of_parsed_indirect_objects(
  objects : ArrayView[PdfParsedIndirectObject],
  version? : @reader.PdfVersion = @reader.pdf_default_version,
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
  let version = @reader.pdf_read_header_from_cursor(cursor)
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  let mut done = false
  while !done {
    let (objects, prefix) = @syntax.pdf_parse_indirect_object_segments(
      pdf_cursor_lex_tokens(cursor),
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
        if pdf_cursor_stopped_at_stream_candidate(cursor) {
          let stream = pdf_cursor_finish_stream_object(cursor, prefix)
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
