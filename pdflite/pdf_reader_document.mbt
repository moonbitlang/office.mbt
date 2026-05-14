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
  let version = cursor.read_pdf_header()
  let xref_position = pdf_read_startxref_position(cursor.data)
  let xrefs : Array[PdfClassicXRefEntry] = []
  let mut trailer = PdfDictionary([])
  let xref_stream_refs : Array[(Int, Int)] = []
  let mut current_xref = xref_position
  let mut done = false
  let mut depth = 0
  while !done {
    if depth >= 1024 {
      raise XRefExpected
    }
    cursor.seek_pdf_absolute(current_xref)
    let section = cursor.read_pdf_xref_section()
    let current_revision = depth + 1
    let read_section = pdf_reader_revision_reads_section(
      revision, current_revision,
    )
    if read_section {
      pdf_classic_xrefs_add_newer_first(xrefs, section.entries)
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
          cursor.seek_pdf_absolute(xref_stream_position)
          let stream_section = cursor.read_pdf_xref_stream_section()
          pdf_classic_xrefs_add_newer_first(xrefs, stream_section.entries)
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
          cursor.seek_pdf_absolute(xref.offset)
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
/// revisions raise `BadRevision`.
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

///|
/// Read a PDF document from a borrowed byte view.
///
/// This is the high-level non-password reader. It first tries the strict classic
/// xref reader and probes the page tree; for selected structural errors it falls
/// back to reconstruction by scanning indirect objects.
pub fn pdf_read_document_from_view(
  data : BytesView,
) -> PdfDocument raise PdfError {
  pdf_read_probe_page_tree_or_reconstruct(
    data,
    pdf_read_classic_document_from_view(data),
  ) catch {
    StartXRefExpected => pdf_read_reconstructed_document_from_view(data)
    XRefExpected =>
      pdf_read_reconstructed_or_raise(
        data,
        XRefExpected,
        include_xref_stream_trailers=true,
      )
    XRefEntryExpected =>
      if pdf_reader_startxref_root_uses_object_stream_or_false(data) {
        raise XRefEntryExpected
      } else {
        pdf_read_reconstructed_or_raise(data, XRefEntryExpected)
      }
    TrailerExpected => pdf_read_reconstructed_or_raise(data, TrailerExpected)
    RootExpected => pdf_read_reconstructed_or_raise(data, RootExpected)
    NumberExpected => pdf_read_reconstructed_or_raise(data, NumberExpected)
    ParseIndirectObjectExpected =>
      pdf_read_reconstructed_or_raise(data, ParseIndirectObjectExpected)
    ParseStreamExpected =>
      pdf_read_reconstructed_or_raise(data, ParseStreamExpected)
    ParseEndStreamExpected =>
      pdf_read_reconstructed_or_raise(data, ParseEndStreamExpected)
    ParseEndObjectExpected =>
      pdf_read_reconstructed_or_raise(data, ParseEndObjectExpected)
    EndOfInput => pdf_read_reconstructed_or_raise(data, EndOfInput)
    ParseObjectExpected =>
      pdf_read_reconstructed_or_raise(data, ParseObjectExpected)
    InvalidHexEscape => pdf_read_reconstructed_or_raise(data, InvalidHexEscape)
    StreamDataExpected =>
      if pdf_reader_startxref_root_uses_object_stream_or_false(data) {
        pdf_read_reconstructed_or_raise(
          data,
          StreamDataExpected,
          include_xref_stream_trailers=true,
        )
      } else {
        raise StreamDataExpected
      }
    InvalidCursorPosition(position) =>
      pdf_read_reconstructed_or_raise(
        data,
        InvalidCursorPosition(position),
        include_xref_stream_trailers=true,
      )
    FilterNotSupported(filter) =>
      if pdf_reader_xref_metadata_error_allows_reconstruction(
          data,
          FilterNotSupported(filter),
        ) {
        pdf_read_reconstructed_or_raise(
          data,
          FilterNotSupported(filter),
          include_xref_stream_trailers=true,
        )
      } else {
        raise FilterNotSupported(filter)
      }
    PredictorExpected =>
      if pdf_reader_xref_metadata_error_allows_reconstruction(
          data,
          PredictorExpected,
        ) {
        pdf_read_reconstructed_or_raise(
          data,
          PredictorExpected,
          include_xref_stream_trailers=true,
        )
      } else {
        raise PredictorExpected
      }
    PredictorNotSupported(predictor) =>
      if pdf_reader_xref_metadata_error_allows_reconstruction(
          data,
          PredictorNotSupported(predictor),
        ) {
        pdf_read_reconstructed_or_raise(
          data,
          PredictorNotSupported(predictor),
          include_xref_stream_trailers=true,
        )
      } else {
        raise PredictorNotSupported(predictor)
      }
    error => raise error
  }
}

///|
/// Read one document revision from a borrowed byte view.
///
/// Revision selection uses strict classic-xref parsing and does not use the
/// reconstruction fallback used by `pdf_read_document_from_view`.
pub fn pdf_read_document_revision_from_view(
  data : BytesView,
  revision : Int,
) -> PdfDocument raise PdfError {
  pdf_read_classic_document_revision_from_view(data, revision)
}

///|
/// Read one document revision from owned PDF bytes.
pub fn pdf_read_document_revision_from_bytes(
  data : PdfBytes,
  revision : Int,
) -> PdfDocument raise PdfError {
  pdf_read_document_revision_from_view(data, revision)
}

///|
/// Read a PDF document from owned PDF bytes.
pub fn pdf_read_document_from_bytes(
  data : PdfBytes,
) -> PdfDocument raise PdfError {
  pdf_read_document_from_view(data)
}

///|
/// Read and decrypt one PDF revision using optional passwords.
///
/// Revision `1` is the newest revision. The returned value is `None` when the
/// document is encrypted and neither supplied password can decrypt it; otherwise
/// it contains the decrypted document and permission information.
pub fn pdf_read_document_revision_from_view_with_passwords(
  data : BytesView,
  revision : Int,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDecryptionResult? raise PdfError {
  let document = pdf_read_classic_document_from_view_at_revision(
    data,
    revision=Some(revision),
    user_password~,
    owner_password~,
  )
  document.decrypt_with_passwords(user_password~, owner_password~)
}

///|
/// Read and decrypt one PDF revision from owned bytes.
pub fn pdf_read_document_revision_from_bytes_with_passwords(
  data : PdfBytes,
  revision : Int,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDecryptionResult? raise PdfError {
  pdf_read_document_revision_from_view_with_passwords(
    data,
    revision,
    user_password~,
    owner_password~,
  )
}

///|
/// Read and decrypt a PDF document using optional passwords.
///
/// This is the high-level password-aware reader. It uses the same reconstruction
/// fallback policy as `pdf_read_document_from_view` before attempting
/// decryption. Unencrypted documents return a copied document inside
/// `Some(...)`.
pub fn pdf_read_document_from_view_with_passwords(
  data : BytesView,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDecryptionResult? raise PdfError {
  let document = pdf_read_probe_page_tree_or_reconstruct(
    data,
    pdf_read_classic_document_from_view_at_revision(
      data,
      user_password~,
      owner_password~,
    ),
    user_password~,
    owner_password~,
  ) catch {
    error =>
      if pdf_reader_password_error_allows_reconstruction(data, error) {
        pdf_read_reconstructed_document_from_view(
          data,
          include_xref_stream_trailers=true,
          user_password~,
          owner_password~,
        )
      } else {
        raise error
      }
  }
  document.decrypt_with_passwords(user_password~, owner_password~)
}

///|
/// Read and decrypt a PDF document from owned PDF bytes.
pub fn pdf_read_document_from_bytes_with_passwords(
  data : PdfBytes,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDecryptionResult? raise PdfError {
  pdf_read_document_from_view_with_passwords(
    data,
    user_password~,
    owner_password~,
  )
}
