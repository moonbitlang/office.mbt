///|
/// Converts a `UInt` to `Int`, raising when the value exceeds the signed range.
fn UInt::to_int_checked(self : UInt) -> Int raise ZipError {
  if self > (0x7FFFFFFF : UInt) {
    raise UnsupportedFeature(msg="u32 exceeds Int range")
  }
  self.reinterpret_as_int()
}

///|
/// Converts a `UInt64` to `Int`, raising when the value exceeds the signed
/// range.
fn UInt64::to_int_checked(self : UInt64) -> Int raise ZipError {
  if self > (0x7FFFFFFF : UInt64) {
    raise UnsupportedFeature(msg="u64 exceeds Int range")
  }
  self.to_int()
}

///|
/// Converts an `Int` to `UInt`, raising when the value is negative.
fn Int::to_uint_checked(self : Int) -> UInt raise ZipError {
  if self < 0 {
    raise UnsupportedFeature(msg="u32 exceeds Int range")
  }
  self.reinterpret_as_uint()
}

///|
/// Converts an `Int` to `UInt64`, raising when the value is negative.
fn Int::to_uint64_checked(self : Int) -> UInt64 raise ZipError {
  if self < 0 {
    raise UnsupportedFeature(msg="u64 exceeds Int range")
  }
  UInt64::extend_uint(self.reinterpret_as_uint())
}
