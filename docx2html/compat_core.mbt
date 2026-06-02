///|
pub type Message = @core.Message

///|
pub type ConversionResult = @core.ConversionResult

///|
pub(all) suberror DocxError {
  InvalidZip(message~ : String)
  InvalidXml(message~ : String)
  MissingPart(message~ : String)
  Unsupported(message~ : String)
} derive(Debug, Eq)

///|
pub fn warning(message : String) -> Message {
  @core.warning(message)
}

///|
pub fn error(message : String) -> Message {
  @core.error(message)
}

///|
pub fn success(value : String) -> ConversionResult {
  @core.success(value)
}

///|
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
  }
}
