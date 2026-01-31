///|
test "zip store roundtrip" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello")
  archive.add("dir/b.txt", b"world")
  let bytes = write(archive)
  let parsed = read(bytes)
  inspect(
    parsed.names(),
    content=(
      #|["a.txt", "dir/b.txt"]
    ),
  )
  inspect(
    parsed.get("a.txt"),
    content=(
      #|Some(b"hello")
    ),
  )
  inspect(
    parsed.get("dir/b.txt"),
    content=(
      #|Some(b"world")
    ),
  )
}

///|
test "zip invalid bytes" {
  let bad : Bytes = "not a zip"
  let result : Result[Archive, ZipError] = try? read(bad)
  inspect(result is Err(_), content="true")
}

///|
test "zip deflate roundtrip" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello", compression=Deflate)
  let bytes = write(archive)
  let parsed = read(bytes)
  inspect(
    parsed.get("a.txt"),
    content=(
      #|Some(b"hello")
    ),
  )
}

///|
test "zip deflate roundtrip (data descriptor)" {
  let archive = Archive::new()
  archive.add("a.txt", b"hello", compression=Deflate, data_descriptor=true)
  let bytes = write(archive)
  let parsed = read(bytes)
  inspect(parsed.get("a.txt"), content="Some(b\"hello\")")
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
  let result : Result[Bytes, Error] = try? write(archive)
  inspect(result is Err(ZipError::UnsupportedFeature(_)), content="true")
}
