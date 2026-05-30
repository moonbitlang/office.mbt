///|
fn pdf_read_classic_document_from_view_at_revision(
  data : BytesView,
  revision? : Int? = None,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDocument raise PdfError {
  let revision = pdf_read_reader_revision_target(revision)
  let was_linearized = pdf_read_was_linearized(data)
  let cursor = byte_cursor_of_view(data)
  let version = @reader.pdf_read_header_from_cursor(cursor)
  let xref_position = @reader.pdf_read_startxref_position(cursor.view())
  let plan = pdf_reader_classic_read_plan(cursor, xref_position, revision)
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  document.set_first_xref(xref_position)
  document.set_was_linearized(was_linearized)
  match revision {
    Some(value) => document.set_revision_read(value)
    None => ()
  }
  document.set_trailer_and_root(plan.trailer)
  document.load_classic_xrefs(
    cursor,
    plan.xrefs,
    plan.xref_stream_refs,
    user_password,
    owner_password,
  )
  document
}

///|
/// Read a PDF using classic xref metadata.
///
/// This strict reader follows `startxref`, xref tables/streams, and trailer
/// `/Prev` links, loads referenced objects, resolves object streams, and records
/// document metadata. It does not use reconstruction fallback.
pub fn pdf_read_classic_document_from_view(
  data : BytesView,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_from_view_at_revision(data)
}

///|
/// Read a classic-xref PDF from owned bytes.
pub fn pdf_read_classic_document_from_bytes(
  data : PdfBytes,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_from_view(data)
}

///|
/// Read one classic-xref document revision.
///
/// Revision `1` is the newest revision; larger revision numbers select older
/// revisions by following trailer `/Prev` links. Invalid or unavailable
/// revisions raise `PdfError::BadRevision`.
pub fn pdf_read_classic_document_revision_from_view(
  data : BytesView,
  revision : Int,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_from_view_at_revision(data, revision=Some(revision))
}

///|
/// Read one classic-xref document revision from owned bytes.
pub fn pdf_read_classic_document_revision_from_bytes(
  data : PdfBytes,
  revision : Int,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_revision_from_view(data, revision)
}
