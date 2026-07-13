///|
pub(all) enum Compression {
  Store
  Deflate
} derive(Debug)

///|
pub suberror ZipError {
  OutOfBounds(offset~ : Int)
  InvalidSignature(expected~ : Int, actual~ : Int, offset~ : Int)
  MissingEndOfCentral
  UnsupportedFeature(msg~ : String)
  UnsupportedCompression(method_id~ : Int)
  InvalidUtf8(offset~ : Int)
  OutputLimitExceeded(limit~ : Int)
  ResourceLimitExceeded(kind~ : String, limit~ : Int, actual~ : Int)
} derive(Debug)
