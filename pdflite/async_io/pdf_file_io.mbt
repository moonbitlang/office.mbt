///|
/// Read and parse a PDF document from a file.
///
/// File bytes are loaded asynchronously and then passed to the byte reader.
pub async fn pdf_read_document_from_file(
  path : StringView,
) -> @pdflite.PdfDocument {
  @pdflite.pdf_read_document_from_bytes(@fs.read_file(path).binary())
}

///|
/// Read a specific PDF revision from a file.
///
/// Revision numbering follows the core reader: revision `1` is the newest
/// revision and larger numbers walk backward through `/Prev`.
pub async fn pdf_read_document_revision_from_file(
  path : StringView,
  revision : Int,
) -> @pdflite.PdfDocument {
  @pdflite.pdf_read_document_revision_from_bytes(
    @fs.read_file(path).binary(),
    revision,
  )
}

///|
/// Count revisions in a PDF file.
pub async fn pdf_revisions_from_file(path : StringView) -> Int {
  @pdflite.pdf_revisions_from_bytes(@fs.read_file(path).binary())
}

///|
/// Read only the PDF header version from a file.
///
/// The same header-probe rules as `@reader.pdf_read_header_from_bytes` apply.
pub async fn pdf_read_header_from_file(path : StringView) -> @reader.PdfVersion {
  @reader.pdf_read_header_from_bytes(@fs.read_file(path).binary())
}

///|
/// Return true if a file appears to be linearized.
pub async fn pdf_is_linearized_file(path : StringView) -> Bool {
  @pdflite.pdf_is_linearized(@fs.read_file(path).binary())
}

///|
/// Replace a stream object with bytes read from `filename`.
///
/// This is the native filesystem counterpart of cpdftweak's `replace_stream`.
pub async fn pdf_replace_stream(
  document : @pdflite.PdfDocument,
  objspec : String,
  filename : StringView,
) -> Unit {
  document.replace_stream_by_spec(objspec, @fs.read_file(filename).binary())
}

///|
/// Replace catalog optional-content groups from a cpdf OCG JSON file.
pub async fn pdf_ocg_replace(
  filename : StringView,
  document : @pdflite.PdfDocument,
) -> @pdflite.PdfDocument {
  let text = @utf8.decode(@fs.read_file(filename).binary()) catch {
    _ => raise @pdflite.PdfError::SoftError("ocg_replace: malformed JSON")
  }
  let json = @json.parse(text) catch {
    _ => raise @pdflite.PdfError::SoftError("ocg_replace: malformed JSON")
  }
  @pdflite.pdf_ocg_replace_json(json, document)
}

///|
/// Read a file and decrypt it with optional user and owner passwords.
///
/// Returns `None` when the file is encrypted and no supplied password
/// authenticates. Unencrypted files return a successful decryption result with
/// empty denied permissions.
pub async fn pdf_read_document_from_file_with_passwords(
  path : StringView,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> @pdflite.PdfDecryptionResult? {
  @pdflite.pdf_read_document_from_bytes_with_passwords(
    @fs.read_file(path).binary(),
    user_password~,
    owner_password~,
  )
}

///|
/// Read a specific revision from a file and decrypt it with optional passwords.
///
/// Returns `None` when the revision is encrypted and no supplied password
/// authenticates.
pub async fn pdf_read_document_revision_from_file_with_passwords(
  path : StringView,
  revision : Int,
  user_password? : BytesView? = None,
  owner_password? : BytesView? = None,
) -> @pdflite.PdfDecryptionResult? {
  @pdflite.pdf_read_document_revision_from_bytes_with_passwords(
    @fs.read_file(path).binary(),
    revision,
    user_password~,
    owner_password~,
  )
}
