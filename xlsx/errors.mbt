///|
pub suberror XlsxError {
  MissingPart(path~ : String)
  SheetNotFound(name~ : String)
  InvalidXml(msg~ : String)
  InvalidCellRef(value~ : String)
  InvalidSharedString(index~ : Int)
  InvalidStyleId(index~ : Int)
  UnsupportedFeature(msg~ : String)
} derive(Eq, Show)
