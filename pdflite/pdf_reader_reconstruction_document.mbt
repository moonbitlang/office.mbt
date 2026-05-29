///|
fn pdf_read_reconstructed_document_from_view(
  data : BytesView,
  include_xref_stream_trailers? : Bool = true,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> PdfDocument raise PdfError {
  let cursor = byte_cursor_of_view(data)
  let version = pdf_read_header_from_cursor(cursor)
  let document = pdf_document_empty()
  document.set_version(version.major, version.minor)
  document.set_first_xref(0)
  document.set_was_linearized(pdf_read_was_linearized(data))
  let plan = @reader.pdf_reader_reconstruction_plan(
    data,
    include_xref_stream_trailers,
    pdf_reader_reconstruction_callbacks(),
  )
  document.load_reconstructed_plan(
    data, plan, include_xref_stream_trailers, user_password, owner_password,
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
