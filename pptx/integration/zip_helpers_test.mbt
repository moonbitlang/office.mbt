///|
fn utf8_bytes(text : String) -> FixedArray[Byte] {
  @utf8.encode(text).to_fixedarray()
}

///|
fn fixture_zip(
  entries : Array[(String, FixedArray[Byte])],
) -> FixedArray[Byte] raise {
  let archive = @zip.Archive::Archive()
  for (name, bytes) in entries {
    archive.add(name, Bytes::from_array(bytes))
  }
  @zip.write(archive).to_fixedarray()
}
