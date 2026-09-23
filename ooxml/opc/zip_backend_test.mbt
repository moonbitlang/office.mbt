///|
test "flate consumers can read saved package binary payloads" {
  let pkg = @opc.Package::new()
  let payload : FixedArray[Byte] = [b'\x00', b'\xFF', b'\x80', b'\x01']
  pkg.add_part(
    @opc.Part::new("/media/data.bin", "application/octet-stream", payload),
  )
  pkg.set_content_types(
    @opc.ContentTypes::new().with_default("bin", "application/octet-stream"),
  )
  pkg.regenerate_content_types_part()
  let bytes = pkg.to_bytes()
  let archive = @zip.read(Bytes::from_array(bytes))
  debug_inspect(
    archive.get("media/data.bin").unwrap().to_owned() ==
    Bytes::from_array(payload),
    content="true",
  )
  let reopened = @opc.Package::open(bytes)
  debug_inspect(
    reopened.require_part("/media/data.bin").bytes() == payload,
    content="true",
  )
  debug_inspect(
    reopened.require_part("/media/data.bin").content_type,
    content="\"application/octet-stream\"",
  )
}

///|
test "invalid UTF-8 in an XML part becomes an OPC error" {
  let part = @opc.Part::new("/bad.xml", "application/xml", [b'\xFF'])
  let rejected = try {
    ignore(part.text())
    false
  } catch {
    MalformedPackage(_) => true
    _ => false
  }
  debug_inspect(rejected, content="true")
}

///|
test "ZIP write failures surface as typed OPC errors" {
  let pkg = @opc.Package::new()
  pkg.add_part(@opc.Part::new("/" + "a".repeat(65536), "", []))
  let rejected = try {
    ignore(pkg.to_bytes())
    false
  } catch {
    ZipFailure("UnsupportedFeature", _) => true
    _ => false
  }
  debug_inspect(rejected, content="true")
}
