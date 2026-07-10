///|
test "zip store roundtrip" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello")
  archive.add("dir/b.txt", b"world")
  let bytes = write(archive)
  let parsed = read(bytes)
  debug_inspect(
    parsed.entries().map(entry => entry.name()),
    content=(
      #|["a.txt", "dir/b.txt"]
    ),
  )
  inspect(parsed.get("a.txt") == Some(b"hello"), content="true")
  inspect(parsed.get("dir/b.txt") == Some(b"world"), content="true")
}

///|
test "zip invalid bytes" {
  let bad : Bytes = b"not a zip"
  try read(bad) catch {
    _ => ()
  } noraise {
    _ => fail("expected read to raise")
  }
}

///|
test "zip deflate roundtrip" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello", compression=Deflate)
  let bytes = write(archive)
  let parsed = read(bytes)
  inspect(parsed.get("a.txt") == Some(b"hello"), content="true")
}

///|
test "zip deflate roundtrip (data descriptor)" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello", compression=Deflate, data_descriptor=true)
  let bytes = write(archive)
  let parsed = read(bytes)
  inspect(parsed.get("a.txt") == Some(b"hello"), content="true")
}

///|
test "zip deflate roundtrip (large data exercises 32KiB window)" {
  let archive = Archive::new()
  let data_array : Array[Byte] = []
  for _ in 0..<40000 {
    data_array.push((0x41).to_byte())
  }
  let data = Bytes::from_array(data_array)
  archive.add("big.txt", data, compression=Deflate)
  let bytes = write(archive)
  let parsed = read(bytes)
  inspect(parsed.get("big.txt") == Some(data), content="true")
}

///|
test "zip write rejects too-long file names" {
  let archive = Archive::new()
  let mut name = ""
  for _ in 0..<70000 {
    name = name + "a"
  }
  archive.add(name, b"hello")
  try write(archive) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected write to raise")
  }
}
