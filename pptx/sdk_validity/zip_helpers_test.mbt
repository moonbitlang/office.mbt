///|
fn utf8_bytes(text : String) -> FixedArray[Byte] {
  @utf8.encode(text).to_fixedarray()
}
