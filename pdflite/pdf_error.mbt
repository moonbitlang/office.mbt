///|
/// Raise a cpdf-style soft error.
///
/// This mirrors `Cpdferror.error`, which raises `SoftError`.
pub fn pdf_error(message : String) -> Unit raise PdfError {
  raise SoftError(message)
}

///|
/// Raise a cpdf-style soft error.
pub fn pdf_soft_error(message : String) -> Unit raise PdfError {
  raise SoftError(message)
}

///|
/// Raise a cpdf-style hard error.
pub fn pdf_hard_error(message : String) -> Unit raise PdfError {
  raise HardError(message)
}
