///|
fn pdf_read_reconstructed_document_from_view(
  data : BytesView,
  include_xref_stream_trailers? : Bool = true,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDocument raise PdfError {
  let cursor = byte_cursor_of_view(data)
  let version = cursor.read_pdf_header()
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  document.set_first_xref(0)
  document.set_was_linearized(pdf_read_was_linearized(data))
  let classic_xref_sections = pdf_read_reconstructed_classic_xref_sections(data)
  let xref_stream_sections : Array[PdfXRefSection] = if include_xref_stream_trailers {
    pdf_read_reconstructed_xref_stream_sections(data)
  } else {
    []
  }
  let xref_coverage = pdf_reconstructed_xref_coverage(
    data, classic_xref_sections, xref_stream_sections,
  )
  let classic_xrefs = pdf_reconstructed_classic_xref_entries(
    classic_xref_sections,
  )
  document.load_reconstructed_classic_xref_plain_objects(data, classic_xrefs)
  let reconstructed_xrefs = pdf_read_reconstructed_xrefs(data)
  for xref in reconstructed_xrefs {
    let parsed_result : Result[PdfParsedIndirectObject, Error] = try? cursor.read_reconstructed_object_at(
      xref.offset,
      reconstructed_xrefs,
    )
    match parsed_result {
      Ok(parsed) =>
        if parsed.number > 0 &&
          parsed.number == xref.object_number &&
          parsed.generation == xref.generation &&
          !xref_coverage.contains(parsed.number, xref.offset) &&
          !pdf_reader_object_is_xref_stream(parsed.object) {
          document.load_object_given_number(
            parsed.number,
            parsed.object,
            generation=parsed.generation,
          )
        }
      Err(_) => ()
    }
  }
  if include_xref_stream_trailers {
    document.load_reconstructed_xref_stream_objects(data, xref_stream_sections)
    document.load_reconstructed_physical_object_stream_members()
  }
  document.set_trailer_and_root(
    document.select_reconstructed_trailer(
      pdf_read_reconstructed_trailers(data, include_xref_stream_trailers),
    ),
  )
  if include_xref_stream_trailers && document.is_encrypted() {
    document.load_reconstructed_xref_stream_embedded_objects_with_passwords(
      pdf_reconstructed_xref_stream_entries(xref_stream_sections),
      user_password,
      owner_password,
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
fn pdf_read_reconstructed_or_raise(
  data : BytesView,
  original_error : PdfError,
  include_xref_stream_trailers? : Bool = false,
) -> PdfDocument raise PdfError {
  pdf_read_reconstructed_document_from_view(data, include_xref_stream_trailers~) catch {
    _ => raise original_error
  }
}

///|
fn pdf_read_probe_page_tree_or_reconstruct(
  data : BytesView,
  document : PdfDocument,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDocument raise PdfError {
  let catalog = Some(document.catalog()) catch { _ => None }
  match catalog {
    Some(catalog) if catalog.lookup_immediate(pdf_page_pages_key()) is Some(_) =>
      try {
        ignore(document.endpage())
        document
      } catch {
        error =>
          pdf_read_reconstructed_or_raise(
            data,
            error,
            include_xref_stream_trailers=true,
          )
      }
    Some(_) => document
    None =>
      pdf_read_reconstruct_valid_page_tree_or_original(
        data, document, user_password, owner_password,
      )
  }
}

///|
fn pdf_read_reconstruction_validation_document(
  document : PdfDocument,
  user_password : BytesView?,
  owner_password : BytesView?,
) -> PdfDocument {
  if document.is_encrypted() {
    let decrypted : Result[PdfDecryptionResult?, Error] = try? document.decrypt_with_passwords(
      user_password~,
      owner_password~,
    )
    match decrypted {
      Ok(Some(result)) => result.document
      _ => document
    }
  } else {
    document
  }
}

///|
fn pdf_read_reconstruct_valid_page_tree_or_original(
  data : BytesView,
  document : PdfDocument,
  user_password : BytesView?,
  owner_password : BytesView?,
) -> PdfDocument {
  let reconstructed = pdf_read_reconstructed_document_from_view(
    data,
    include_xref_stream_trailers=true,
    user_password~,
    owner_password~,
  ) catch {
    _ => document
  }
  try {
    let validation = pdf_read_reconstruction_validation_document(
      reconstructed, user_password, owner_password,
    )
    ignore(validation.endpage())
    reconstructed
  } catch {
    _ => document
  }
}
