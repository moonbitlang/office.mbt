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

///|
/// Return a concise, user-facing summary for a `PdfError`.
///
/// The suffix keeps the precise variant visible for tests and callers that use
/// CLI output while replacing raw constructor-only messages with useful text.
pub fn pdf_error_summary(error : PdfError) -> String {
  match error {
    SoftError(message) => message
    HardError(message) => message
    EndOfInput => "unexpected end of input (EndOfInput)"
    ParseObjectExpected => "expected a PDF object (ParseObjectExpected)"
    ParseArrayMalformed => "malformed PDF array (ParseArrayMalformed)"
    ParseSingleObjectExpected =>
      "expected one complete PDF object (ParseSingleObjectExpected)"
    ParseIndirectObjectExpected =>
      "expected an indirect PDF object (ParseIndirectObjectExpected)"
    ParseEndObjectExpected => "expected endobj marker (ParseEndObjectExpected)"
    ParseStreamExpected => "expected PDF stream data (ParseStreamExpected)"
    ParseEndStreamExpected =>
      "expected endstream marker (ParseEndStreamExpected)"
    StreamLengthExpected =>
      "missing or invalid PDF stream length (StreamLengthExpected)"
    StreamDataExpected => "missing PDF stream data (StreamDataExpected)"
    ParsedObjectExpected =>
      "expected a parsed PDF object (ParsedObjectExpected)"
    StartXRefExpected =>
      "missing or invalid startxref marker (StartXRefExpected)"
    XRefExpected => "missing or invalid cross-reference data (XRefExpected)"
    XRefEntryExpected => "malformed cross-reference entry (XRefEntryExpected)"
    TrailerExpected => "missing or invalid PDF trailer (TrailerExpected)"
    RootExpected => "missing or invalid PDF catalog root (RootExpected)"
    PageTreeExpected => "missing or invalid page tree (PageTreeExpected)"
    _ => @debug.to_string(error)
  }
}
