///|
priv enum PdfCoordToken {
  CoordNumber(Double)
  CoordWord(String)
}

///|
/// A cpdf coordinate rectangle: origin plus width and height.
pub(all) struct PdfCoordRectangle {
  x : Double
  y : Double
  width : Double
  height : Double
} derive(Debug, Eq, ToJson)
