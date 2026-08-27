// DEFLATE (RFC 1951) compression and decompression for ZIP and gzip, backed by
// the `moonbit-community/flate` engine. This package deliberately exposes a
// thin wrapper: the ZIP codebase's `ZipError` surface (kinds, limits, and
// cancellation) stays stable while the encoding, Huffman tables, and streaming
// decode state machine live in flate.

///|
/// Default cap for decompressed output, guarding against decompression bombs.
let deflate_max_output_default : Int = 1 << 30

///|
/// Map flate's raw-DEFLATE failure categories onto the ZIP error surface.
/// `Truncated` becomes `OutOfBounds` (the physical offset is not recoverable
/// from flate's error, so 0 stands in); `Corrupt` and `TrailingData` become
/// `UnsupportedFeature`; the limit failure carries the caller-supplied cap;
/// cancellation becomes `ReadCancelled`.
fn map_inflate_error(err : @flate.InflateError, max_output : Int) -> ZipError {
  match err {
    InflateError(kind, message) =>
      match kind {
        Truncated => OutOfBounds(offset=0)
        Corrupt => UnsupportedFeature(msg=message)
        TrailingData =>
          UnsupportedFeature(msg="trailing bytes after deflate stream")
        OutputLimitExceeded => OutputLimitExceeded(limit=max_output)
        Cancelled => ReadCancelled
      }
  }
}

///|
/// Compress `bytes` into one complete raw DEFLATE stream. The flate engine
/// emits dynamic-Huffman blocks (default level), with strictly better
/// compression than the fixed-Huffman blocks this package used to write.
fn deflate_encode(bytes : BytesView) -> Bytes {
  @flate.deflate_all(bytes.to_owned())
}

///|
/// Compress `bytes` and report the exact stream size. When `max_output` is
/// present, an encoded size beyond it raises `OutputLimitExceeded(limit)`
/// before any byte storage is produced.
fn deflate_encoded_size(
  bytes : BytesView,
  max_output? : Int,
) -> Int raise ZipError {
  let compressed = @flate.deflate_all(bytes.to_owned())
  match max_output {
    Some(limit) if compressed.length() > limit =>
      raise OutputLimitExceeded(limit~)
    _ => ()
  }
  compressed.length()
}

///|
/// Emit the compressed stream into `out` and report its length. `out` enforces
/// its own byte budget, so an over-limit sink raises `OutputLimitExceeded`
/// here rather than mid-stream.
fn deflate_encode_to_output(
  bytes : BytesView,
  out : FixedByteOutput,
) -> Int raise ZipError {
  let compressed = @flate.deflate_all(bytes.to_owned())
  out.write_bytes(compressed)
  compressed.length()
}

///|
/// Decompress exactly one raw DEFLATE stream. `max_output` caps the decoded
/// size (raising `OutputLimitExceeded(limit)`); `cancelled` is polled at entry,
/// during decode, and once more after success (`ReadCancelled` on `true`).
/// Bytes after the final block are rejected. The preallocated two-pass flate
/// path is used so the largest expanded entry allocates exactly once, without
/// a growable backing array or a final copy.
fn deflate_decode(
  bytes : BytesView,
  max_output? : Int = deflate_max_output_default,
  cancelled? : () -> Bool = () => false,
) -> Bytes raise ZipError {
  check_zip_cancelled(cancelled)
  let decoded = try
    @flate.inflate_exact(
      bytes.to_owned(),
      max_output=Some(max_output),
      cancelled~,
      preallocated=true,
    )
  catch {
    err => raise map_inflate_error(err, max_output)
  } noraise {
    decoded => decoded
  }
  check_zip_cancelled(cancelled)
  decoded
}

///|
test "deflate stored block" {
  let stream : Bytes = [0x01, 0x02, 0x00, 0xFD, 0xFF, 0x68, 0x69]
  inspect(
    deflate_decode(stream),
    content=(
      #|b"hi"
    ),
  )
}

///|
test "deflate rejects complete bytes after the final block" {
  let stream : Bytes = [0x01, 0x02, 0x00, 0xFD, 0xFF, 0x68, 0x69, 0x00]
  try deflate_decode(stream) catch {
    UnsupportedFeature(msg~) =>
      inspect(msg, content="trailing bytes after deflate stream")
    _ => fail("expected trailing deflate bytes to be rejected")
  } noraise {
    _ => fail("expected trailing deflate bytes to be rejected")
  }
}

///|
test "deflate fixed huffman" {
  let stream : Bytes = [0xCB, 0x48, 0xCD, 0xC9, 0xC9, 0x07, 0x00]
  inspect(
    deflate_decode(stream),
    content=(
      #|b"hello"
    ),
  )
}

///|
test "deflate dynamic huffman" {
  // zlib-generated dynamic-Huffman stream, verified complete against zlib
  // (eof=true, decodes exactly 200 repetitions of the phrase).
  let stream : Bytes = [
    0xED, 0xCA, 0xC9, 0x01, 0x82, 0x40, 0x10, 0x00, 0xB0, 0x56, 0xA6, 0xA8, 0x6D,
    0xC0, 0x03, 0xF0, 0x40, 0x06, 0x56, 0x17, 0xD4, 0xEA, 0xB1, 0x04, 0x0B, 0xC8,
    0x3B, 0x29, 0x97, 0x2E, 0x96, 0x76, 0x3D, 0xDD, 0xE3, 0x58, 0x73, 0x9B, 0xA2,
    0xCF, 0x77, 0xDC, 0xDA, 0x63, 0x7E, 0x46, 0xAE, 0x5D, 0x8D, 0xD7, 0x8F, 0xC7,
    0xC3, 0xF7, 0x13, 0xE7, 0x1C, 0x8A, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA,
    0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA, 0xAA,
    0xAA, 0xAA, 0xAA, 0xAA, 0xFA, 0x7F, 0xDD, 0x01,
  ]
  let phrase : Bytes = b"The quick brown fox jumps over the lazy dog"
  let expected_array : Array[Byte] = []
  for _ in 0..<200 {
    for b in phrase {
      expected_array.push(b)
    }
  }
  let expected = Bytes::from_array(expected_array)
  inspect(deflate_decode(stream) == expected, content="true")
}

///|
test "deflate decoding observes cancellation while producing output" {
  let input = Bytes::from_array(Array::make(32 * 1024, b'x'))
  let compressed = deflate_encode(input)
  let checks = [0]
  let result : Result[Bytes, Error] = Ok(
    deflate_decode(compressed, cancelled=() => {
      checks[0] += 1
      checks[0] >= 3
    }),
  ) catch {
    error => Err(error)
  }
  assert_true(result is Err(ReadCancelled))
  assert_true(checks[0] >= 3)
}

///|
test "deflate encode fixed literals" {
  let data : Bytes = b"MoonBit deflate"
  let compressed = deflate_encode(data)
  inspect(deflate_decode(compressed) == data, content="true")
}

///|
test "deflate encode lz77 matches" {
  let data_array : Array[Byte] = []
  for _ in 0..<1024 {
    data_array.push(b'A')
  }
  let data = Bytes::from_array(data_array)
  let compressed = deflate_encode(data)
  inspect(deflate_decode(compressed) == data, content="true")
  inspect(compressed.length() < data.length(), content="true")
}

///|
test "deflate decode enforces max_output for stored blocks" {
  // Stored block declaring 2 bytes ("hi") against a cap of 1.
  let stream : Bytes = [0x01, 0x02, 0x00, 0xFD, 0xFF, 0x68, 0x69]
  try deflate_decode(stream, max_output=1) catch {
    OutputLimitExceeded(limit~) => inspect(limit, content="1")
    _ => fail("expected OutputLimitExceeded")
  } noraise {
    _ => fail("expected deflate_decode to raise")
  }
}

///|
test "deflate decode enforces max_output for huffman literals" {
  // Fixed-Huffman block decoding to "hello" against a cap of 4.
  let stream : Bytes = [0xCB, 0x48, 0xCD, 0xC9, 0xC9, 0x07, 0x00]
  try deflate_decode(stream, max_output=4) catch {
    OutputLimitExceeded(limit~) => inspect(limit, content="4")
    _ => fail("expected OutputLimitExceeded")
  } noraise {
    _ => fail("expected deflate_decode to raise")
  }
}

///|
test "deflate decode enforces max_output for back-references" {
  let data : Array[Byte] = []
  for _ in 0..<400 {
    data.push(b'a')
  }
  let compressed = deflate_encode(Bytes::from_array(data))
  try deflate_decode(compressed, max_output=100) catch {
    OutputLimitExceeded(limit~) => inspect(limit, content="100")
    _ => fail("expected OutputLimitExceeded")
  } noraise {
    _ => fail("expected deflate_decode to raise")
  }
}
