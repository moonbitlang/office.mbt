///|
/// Return the source cursor used by a deferred stream slice.
pub fn ToGet::input(self : ToGet) -> ByteCursor {
  self.input
}

///|
/// Return the start position of a deferred stream slice.
///
/// The value is interpreted relative to the `ByteCursor`'s offset when the
/// stream is materialized.
pub fn ToGet::position(self : ToGet) -> Int {
  self.position
}

///|
/// Return the byte length of a deferred stream slice.
pub fn ToGet::length(self : ToGet) -> Int {
  self.length
}

///|
/// Return the decryption metadata for a deferred stream slice.
pub fn ToGet::crypt(self : ToGet) -> PdfStreamDataCrypt {
  self.crypt
}
