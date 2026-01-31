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
