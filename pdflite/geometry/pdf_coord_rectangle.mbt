///|
/// A cpdf coordinate rectangle: origin plus width and height.
#derive(Debug, Eq, ToJson)
pub(all) struct PdfCoordRectangle {
  x : Double
  y : Double
  width : Double
  height : Double
}
