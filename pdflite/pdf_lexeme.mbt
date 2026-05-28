///|
/// Token produced by the low-level PDF lexer.
///
/// String, name, and comment payloads are byte-oriented PDF data. `StopLexing`
/// is an internal stop marker used when object lexing reaches stream/xref
/// boundaries, and `LexNone` means no token matched at the current cursor
/// position.
pub(all) enum PdfLexeme {
  LexNull
  LexBool(Bool)
  LexInt(Int)
  LexReal(Double)
  LexString(PdfBytes)
  LexName(PdfName)
  LexLeftSquare
  LexRightSquare
  LexLeftDict
  LexRightDict
  LexStream(PdfStreamData)
  LexEndStream
  LexObj
  LexEndObj
  LexR
  LexComment(PdfBytes)
  StopLexing
  LexNone
} derive(Debug, Eq, ToJson)
