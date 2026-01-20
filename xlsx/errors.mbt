///|
pub suberror XlsxError {
  MissingPart(path~ : String)
  SheetNotFound(name~ : String)
  InvalidXml(msg~ : String)
  InvalidCellRef(value~ : String)
  InvalidSharedString(index~ : Int)
  InvalidStyleId(index~ : Int)
  InvalidTable(msg~ : String)
  InvalidSparkline(msg~ : String)
  InvalidPivotTable(msg~ : String)
  InvalidVmlDrawing(msg~ : String)
  StreamModeConflict(msg~ : String)
  StreamRowOrder(last~ : Int, next~ : Int)
  StreamWriterClosed
  UnsupportedFeature(msg~ : String)
} derive(Eq, Show)
