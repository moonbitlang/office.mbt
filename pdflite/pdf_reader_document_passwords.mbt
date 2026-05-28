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
