///|
test "entries carry stored CRCs so validators can detect tolerated corruption" {
  let archive = @zip.Archive::new()
  archive.add("hello.txt", b"hello zip world")
  // Entries created in memory compute their CRC from the data.
  assert_eq(archive.entries()[0].crc32(), @zip.crc32(b"hello zip world"))
  let bytes = @zip.write(archive)
  let reread = @zip.read(bytes)
  // Round trip: the stored central-directory CRC matches the data.
  let entry = reread.entries()[0]
  assert_eq(entry.crc32(), @zip.crc32(entry.data()))
  // Flip one payload byte (Store compression: the data sits raw in the
  // archive). The inflate path tolerates this; the stored CRC exposes it.
  let corrupted = Bytes::from_array(bytes.to_array())
  let payload = b"hello zip world"
  let mut payload_at = -1
  for i in 0..<(corrupted.length() - payload.length()) {
    if corrupted[i:i + payload.length()] == payload {
      payload_at = i
      break
    }
  }
  assert_true(payload_at >= 0)
  let mutated = corrupted.to_array()
  mutated[payload_at] = b'H'
  let tampered = @zip.read(Bytes::from_array(mutated))
  let bad = tampered.entries()[0]
  assert_true(bad.crc32() != @zip.crc32(bad.data()))
  assert_eq(bad.data(), b"Hello zip world")
}
