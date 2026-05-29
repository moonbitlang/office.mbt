///|
fn pdf_read_reader_revision_target(revision : Int?) -> Int? raise PdfError {
  match revision {
    Some(value) if value < 1 => raise BadRevision
    _ => revision
  }
}

///|
fn pdf_reader_revision_reads_section(
  revision : Int?,
  current_revision : Int,
) -> Bool {
  match revision {
    Some(target) => target <= current_revision
    None => true
  }
}

///|
fn pdf_reader_revision_selects_trailer(
  revision : Int?,
  current_revision : Int,
  depth : Int,
) -> Bool {
  match revision {
    Some(target) => target == current_revision
    None => depth == 0
  }
}

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
  let version = pdf_read_header_from_cursor(cursor)
  let xref_position = pdf_read_startxref_position(cursor.view())
  let xrefs : Array[PdfClassicXRefEntry] = []
  let xref_seen = @number_set.pdf_number_set([])
  let mut trailer = PdfDictionary([])
  let xref_stream_refs : Array[(Int, Int)] = []
  let mut current_xref = xref_position
  let mut done = false
  let mut depth = 0
  while !done {
    if depth >= 1024 {
      raise XRefExpected
    }
    cursor.seek_absolute(current_xref)
    let section = pdf_cursor_read_xref_section(cursor)
    let current_revision = depth + 1
    let read_section = pdf_reader_revision_reads_section(
      revision, current_revision,
    )
    if read_section {
      pdf_classic_xrefs_add_newer_first_with_seen(
        xrefs,
        xref_seen,
        section.entries,
      )
      match section.stream_object_number {
        Some(number) => xref_stream_refs.push((number, current_xref))
        None => ()
      }
    }
    let current_trailer = section.trailer
    if pdf_reader_revision_selects_trailer(revision, current_revision, depth) {
      trailer = current_trailer
    }
    if read_section {
      match pdf_trailer_xref_stream_position(current_trailer) {
        Some(xref_stream_position) => {
          cursor.seek_absolute(xref_stream_position)
          let stream_section = cursor.read_pdf_xref_stream_section()
          pdf_classic_xrefs_add_newer_first_with_seen(
            xrefs,
            xref_seen,
            stream_section.entries,
          )
          xref_stream_refs.push(
            (stream_section.stream_object_number.unwrap(), xref_stream_position),
          )
        }
        None => ()
      }
    }
    match pdf_trailer_prev_position(current_trailer) {
      Some(previous) => current_xref = previous
      None => if read_section { done = true } else { raise BadRevision }
    }
    depth += 1
  }
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  document.set_first_xref(xref_position)
  document.set_was_linearized(was_linearized)
  match revision {
    Some(value) => document.set_revision_read(value)
    None => ()
  }
  document.set_trailer_and_root(trailer)
  let xref_stream_ref_set = pdf_reader_xref_stream_ref_set(xref_stream_refs)
  let xref_index = pdf_classic_xref_index(xrefs)
  for xref in xrefs {
    match xref.object_stream {
      Some(_) => ()
      None =>
        if xref.in_use &&
          xref.object_number != 0 &&
          !xref_stream_ref_set.contains(xref.object_number, xref.offset) {
          cursor.seek_absolute(xref.offset)
          let parsed = cursor.read_first_indirect_object_at_current(
            xrefs,
            xref_index=Some(xref_index),
          )
          if parsed.number != xref.object_number ||
            parsed.generation != xref.generation {
            raise XRefEntryExpected
          }
          document.load_object_given_number(
            parsed.number,
            parsed.object,
            generation=parsed.generation,
          )
        }
    }
  }
  for group in pdf_reader_object_stream_groups(xrefs) {
    let object_stream_number = group.0
    let (context, already_decrypted) = document.read_object_stream_context_with_passwords(
      object_stream_number, user_password, owner_password,
    )
    document.load_embedded_objects_from_context(
      group.1,
      object_stream_number,
      context,
      already_decrypted,
    )
  }
  document.set_trailer_dict(
    pdf_reader_sanitize_trailer(
      document.trailer_dict(),
      document.objects.max_object_number() + 1,
    ),
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
