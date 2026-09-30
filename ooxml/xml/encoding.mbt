///|
/// Decodes XML bytes using the UTF-8/UTF-16 BOM or initial XML byte signature.
/// The XML reader remains responsible for validating the declaration.
pub fn decode_xml_bytes(bytes : BytesView) -> String raise XmlError {
  try {
    match bytes {
      [0xff, 0xfe, ..] => @utf16.decode(bytes, ignore_bom=true)
      [0xfe, 0xff, ..] => @utf16.decode(bytes, ignore_bom=true, endianness=Big)
      [b'<', 0x00, ..] => @utf16.decode(bytes)
      [0x00, b'<', ..] => @utf16.decode(bytes, endianness=Big)
      _ => @utf8.decode(bytes, ignore_bom=true)
    }
  } catch {
    _ => raise Malformed("invalid UTF-8 or UTF-16 XML text")
  }
}
