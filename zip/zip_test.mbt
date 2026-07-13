///|
test "zip store roundtrip" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello")
  archive.add("dir/b.txt", b"world")
  let bytes = @zip.write(archive)
  let parsed = @zip.read(bytes)
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
  try @zip.read(bad) catch {
    _ => ()
  } noraise {
    _ => fail("expected read to raise")
  }
}

///|
test "zip deflate roundtrip" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello", compression=Deflate)
  let bytes = @zip.write(archive)
  let parsed = @zip.read(bytes)
  inspect(parsed.get("a.txt") == Some(b"hello"), content="true")
}

///|
test "zip deflate roundtrip (data descriptor)" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"hello", compression=Deflate, data_descriptor=true)
  let bytes = @zip.write(archive)
  let parsed = @zip.read(bytes)
  inspect(parsed.get("a.txt") == Some(b"hello"), content="true")
  guard parsed.entries()[0] is entry else { fail("expected parsed entry") }
  assert_true(entry.compression() is Deflate)
  assert_true(entry.data_descriptor())
  let limited = @zip.read_limited(
    bytes,
    max_entries=1,
    max_entry_uncompressed_bytes=5,
    max_total_uncompressed_bytes=5,
  )
  assert_true(limited.entries()[0].compression() is Deflate)
  assert_true(limited.entries()[0].data_descriptor())
}

///|
test "zip read-write roundtrip preserves source records exactly" {
  let source_archive = @zip.Archive::new()
  source_archive.add("stored.txt", b"stored")
  source_archive.add(
    "deflated.txt",
    b"deflated-deflated-deflated",
    compression=Deflate,
    data_descriptor=true,
  )
  let source = @zip.write(source_archive)
  assert_eq(@zip.write(@zip.read(source)), source)
}

///|
test "zip deflate roundtrip (large data exercises 32KiB window)" {
  let archive = @zip.Archive::new()
  let data_array : Array[Byte] = []
  for _ in 0..<40000 {
    data_array.push((0x41).to_byte())
  }
  let data = Bytes::from_array(data_array)
  archive.add("big.txt", data, compression=Deflate)
  let bytes = @zip.write(archive)
  let parsed = @zip.read(bytes)
  inspect(parsed.get("big.txt") == Some(data), content="true")
}

///|
test "zip write rejects too-long file names" {
  let archive = @zip.Archive::new()
  let mut name = ""
  for _ in 0..<70000 {
    name = name + "a"
  }
  archive.add(name, b"hello")
  try @zip.write(archive) catch {
    e => inspect(e is UnsupportedFeature(_), content="true")
  } noraise {
    _ => fail("expected write to raise")
  }
}

///|
test "zip read_limited rejects entry count and aggregate expansion" {
  let archive = @zip.Archive::new()
  archive.add("a.txt", b"1234")
  archive.add("b.txt", b"5678")
  let bytes = @zip.write(archive)
  try
    @zip.read_limited(
      bytes,
      max_entries=1,
      max_entry_uncompressed_bytes=8,
      max_total_uncompressed_bytes=8,
    )
  catch {
    ResourceLimitExceeded(kind~, limit~, actual~) => {
      inspect(kind, content="entry_count")
      inspect(limit, content="1")
      inspect(actual, content="2")
    }
    _ => fail("expected entry-count resource limit")
  } noraise {
    _ => fail("expected read_limited to raise")
  }
  try
    @zip.read_limited(
      bytes,
      max_entries=2,
      max_entry_uncompressed_bytes=8,
      max_total_uncompressed_bytes=7,
    )
  catch {
    ResourceLimitExceeded(kind~, limit~, actual~) => {
      inspect(kind, content="total_uncompressed_bytes")
      inspect(limit, content="7")
      inspect(actual, content="8")
    }
    _ => fail("expected aggregate resource limit")
  } noraise {
    _ => fail("expected read_limited to raise")
  }
}

///|
test "bounded ZIP provenance survives forks and invalidates on mutation" {
  let source_archive = @zip.Archive::new()
  source_archive.add("a.txt", b"bounded")
  let source = @zip.write(source_archive)
  let bounded = @zip.read_limited(
    source,
    max_entries=4,
    max_entry_uncompressed_bytes=16,
    max_total_uncompressed_bytes=32,
  )
  assert_eq(
    bounded.bounded_source_package_size(
      max_entries=4,
      max_entry_uncompressed_bytes=16,
      max_total_uncompressed_bytes=32,
    ),
    Some(source.length()),
  )
  assert_eq(
    bounded.bounded_source_package_size(
      max_entries=3,
      max_entry_uncompressed_bytes=16,
      max_total_uncompressed_bytes=32,
    ),
    None,
  )
  let fork = bounded.fork()
  assert_true(fork.replace("a.txt", b"bounded"))
  assert_eq(
    fork.bounded_source_package_size(
      max_entries=4,
      max_entry_uncompressed_bytes=16,
      max_total_uncompressed_bytes=32,
    ),
    Some(source.length()),
  )
  assert_true(fork.replace("a.txt", b"changed"))
  assert_eq(
    fork.bounded_source_package_size(
      max_entries=4,
      max_entry_uncompressed_bytes=16,
      max_total_uncompressed_bytes=32,
    ),
    None,
  )
  assert_eq(
    @zip.read(source).bounded_source_package_size(
      max_entries=4,
      max_entry_uncompressed_bytes=16,
      max_total_uncompressed_bytes=32,
    ),
    None,
  )
}

///|
test "zip write_limited fails before output growth crosses the ceiling" {
  let stored = @zip.Archive::new()
  stored.add("stored.bin", b"0123456789")
  let exact = @zip.write(stored)
  assert_eq(@zip.write_limited(stored, max_output_bytes=exact.length()), exact)
  try @zip.write_limited(stored, max_output_bytes=exact.length() - 1) catch {
    OutputLimitExceeded(limit~) => assert_eq(limit, exact.length() - 1)
    _ => fail("expected stored output limit")
  } noraise {
    _ => fail("expected stored archive to exceed its output limit")
  }

  let deflated = @zip.Archive::new()
  let data = Bytes::makei(512, index => (index % 251).to_byte())
  deflated.add("deflated.bin", data, compression=Deflate)
  try @zip.write_limited(deflated, max_output_bytes=64) catch {
    OutputLimitExceeded(limit~) => assert_eq(limit, 64)
    _ => fail("expected deflate output limit")
  } noraise {
    _ => fail("expected deflated archive to exceed its output limit")
  }

  let preserved = @zip.read_limited(
    exact,
    max_entries=1,
    max_entry_uncompressed_bytes=10,
    max_total_uncompressed_bytes=10,
  )
  try @zip.write_limited(preserved, max_output_bytes=8) catch {
    OutputLimitExceeded(limit~) => assert_eq(limit, 8)
    _ => fail("expected preserved-record output limit")
  } noraise {
    _ => fail("expected preserved record to be checked before copying")
  }
}

///|
test "zip local-record overlap validation scales to large valid archives" {
  let entry_count = 32_768
  let archive = @zip.Archive::new()
  for index in 0..<entry_count {
    archive.add("entry-\{index}.txt", b"")
  }
  let parsed = @zip.read_limited(
    @zip.write(archive),
    max_entries=entry_count,
    max_entry_uncompressed_bytes=0,
    max_total_uncompressed_bytes=0,
  )
  assert_eq(parsed.entries().length(), entry_count)
}

///|
test "zip read_limited rejects deflate output beyond a lying declaration" {
  let archive = @zip.Archive::new()
  let data : Array[Byte] = []
  for _ in 0..<4096 {
    data.push((0x41).to_byte())
  }
  archive.add("bomb.txt", Bytes::from_array(data), compression=Deflate)
  let raw = @zip.write(archive).to_array()
  // The central-directory uncompressed size is the four bytes at offset 24.
  // Find its signature so this remains independent of compressed payload size.
  let mut central = -1
  for i in 0..<(raw.length() - 3) {
    if raw[i] == (0x50).to_byte() &&
      raw[i + 1] == (0x4B).to_byte() &&
      raw[i + 2] == (0x01).to_byte() &&
      raw[i + 3] == (0x02).to_byte() {
      central = i
      break
    }
  }
  if central < 0 {
    fail("missing central directory")
  }
  raw[central + 24] = (16).to_byte()
  raw[central + 25] = (0).to_byte()
  raw[central + 26] = (0).to_byte()
  raw[central + 27] = (0).to_byte()
  // Keep the local and central declarations bound while lying about the
  // inflated length; the streaming ceiling must still stop materialization.
  raw[22] = (16).to_byte()
  raw[23] = (0).to_byte()
  raw[24] = (0).to_byte()
  raw[25] = (0).to_byte()
  try
    @zip.read_limited(
      Bytes::from_array(raw),
      max_entries=1,
      max_entry_uncompressed_bytes=32,
      max_total_uncompressed_bytes=32,
    )
  catch {
    ResourceLimitExceeded(kind~, limit~, actual~) => {
      inspect(kind, content="entry_uncompressed_bytes")
      inspect(limit, content="32")
      inspect(actual, content="33")
    }
    _ => fail("expected decompression resource limit")
  } noraise {
    _ => fail("expected read_limited to raise")
  }
}

///|
test "zip read_limited rejects forged compressed sizes without panicking" {
  let archive = @zip.Archive::new()
  archive.add("forged.txt", b"payload", data_descriptor=true)
  let raw = @zip.write(archive).to_array()
  let mut central = -1
  for i in 0..<(raw.length() - 3) {
    if raw[i] == (0x50).to_byte() &&
      raw[i + 1] == (0x4B).to_byte() &&
      raw[i + 2] == (0x01).to_byte() &&
      raw[i + 3] == (0x02).to_byte() {
      central = i
      break
    }
  }
  if central < 0 {
    fail("missing central directory")
  }
  raw[central + 20] = (0xFF).to_byte()
  raw[central + 21] = (0xFF).to_byte()
  raw[central + 22] = (0xFF).to_byte()
  raw[central + 23] = (0x7F).to_byte()
  try
    @zip.read_limited(
      Bytes::from_array(raw),
      max_entries=1,
      max_entry_uncompressed_bytes=64,
      max_total_uncompressed_bytes=64,
    )
  catch {
    OutOfBounds(..) => ()
    _ => fail("expected bounded out-of-range error")
  } noraise {
    _ => fail("expected forged compressed size to raise")
  }
}
