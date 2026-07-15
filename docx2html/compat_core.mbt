///|
/// Diagnostic emitted while reading or converting a document.
pub type Message = @core.Message

///|
/// Converted value together with accumulated diagnostics.
pub type ConversionResult = @core.ConversionResult

///|
/// Machine-readable XML work or allocation guard raised by DOCX processing.
pub type DocxXmlResourceLimit = @core.DocxXmlResourceLimit

///|
/// Errors raised for invalid archives, invalid XML, missing parts, or unsupported input.
pub(all) suberror DocxError {
  InvalidZip(message~ : String)
  InvalidXml(message~ : String)
  MissingPart(message~ : String)
  Unsupported(message~ : String)
  ResourceLimit(limit~ : DocxXmlResourceLimit, message~ : String)
} derive(Debug, Eq)

///|
/// Creates a warning diagnostic.
pub fn warning(message : String) -> Message {
  @core.warning(message)
}

///|
/// Creates an error diagnostic.
pub fn error(message : String) -> Message {
  @core.error(message)
}

///|
/// Creates a successful conversion result with no diagnostics.
pub fn success(value : String) -> ConversionResult {
  @core.success(value)
}

///|
/// Combines conversion results, preserving values and diagnostics.
pub fn combine_results(results : Array[ConversionResult]) -> ConversionResult {
  @core.combine_results(results)
}

///|
fn[T] bridge_core_error(
  action : () -> T raise @core.DocxError,
) -> T raise DocxError {
  action() catch {
    InvalidZip(message~) => raise InvalidZip(message~)
    InvalidXml(message~) => raise InvalidXml(message~)
    MissingPart(message~) => raise MissingPart(message~)
    Unsupported(message~) => raise Unsupported(message~)
    ResourceLimit(limit~, message~) => raise ResourceLimit(limit~, message~)
  }
}
