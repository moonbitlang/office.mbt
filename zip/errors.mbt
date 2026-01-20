///|
pub enum Compression {
  Store
  Deflate
} derive(Show, Eq)

///|
pub suberror ZipError {
  OutOfBounds(offset~ : Int)
  InvalidSignature(expected~ : Int, actual~ : Int, offset~ : Int)
  MissingEndOfCentral
  UnsupportedFeature(msg~ : String)
  UnsupportedCompression(method_id~ : Int)
  InvalidUtf8(offset~ : Int)
} derive(Show, Eq)
