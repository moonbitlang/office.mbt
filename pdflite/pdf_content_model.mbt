///|
enum PdfContentLexeme {
  ContentOperand(@syntax.PdfObject)
  ContentOperator(BytesView)
  ContentComment
  ContentEnd
} derive(Debug, Eq, ToJson)

///|
enum PdfContentInlineTextFilter {
  PdfContentInlineAsciiHex
  PdfContentInlineAscii85
} derive(Debug, Eq)

///|
type PdfContentColourSpaceComponents = (@syntax.PdfObject) -> Int raise PdfError

///|
type PdfContentStreamDecoder = (@syntax.PdfStream) -> @syntax.PdfStream raise PdfError

///|
priv struct PdfContentParseContext {
  decode_stream : PdfContentStreamDecoder
  colour_space_components : PdfContentColourSpaceComponents?
}

///|
fn pdf_content_ascii(text : String) -> PdfBytes {
  @ascii.encode(text)
}

///|
fn pdf_content_name(text : String) -> PdfName {
  pdf_name_of_bytes(pdf_content_ascii(text))
}

///|
let pdf_content_length_key_name : PdfName = pdf_content_name("/Length")

///|
let pdf_content_inline_l_key_name : PdfName = pdf_content_name("/L")

///|
let pdf_content_inline_image_begin_operator : PdfBytes = pdf_content_ascii("BI")

///|
let pdf_content_inline_image_data_operator : PdfBytes = pdf_content_ascii("ID")

///|
fn pdf_content_length_name() -> PdfName {
  pdf_content_length_key_name
}

///|
fn pdf_content_inline_l_name() -> PdfName {
  pdf_content_inline_l_key_name
}
