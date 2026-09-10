///|
// Generated independently with Python's zlib, stored blocks.
test "decode external zlib stored fixture" {
  let encoded = b"\x78\x01\x01\x03\x00\xfc\xff\x61\x62\x63\x02\x4d\x01\x27"
  assert_eq(pdf_flate_decode(encoded), b"abc")
  let combined = @core.pdf_bytes_concat_views([encoded, b" EI next"])
  let (decoded, consumed) = pdf_flate_decode_view_prefix(combined)
  assert_eq(decoded, b"abc")
  assert_eq(consumed, encoded.length())
}

///|
// Generated independently with Python's zlib, fixed blocks.
test "decode external zlib fixed fixture" {
  let encoded = b"\x78\x01\x2b\xc9\x48\x55\x28\x2c\xcd\x4c\xce\x56\x48\x2a\xca\x2f\xcf\x53\x48\xcb\xaf\x50\xc8\x2a\xcd\x2d\x28\x56\xc8\x2f\x4b\x2d\x52\x28\x01\x4a\xe7\x24\x56\x55\x2a\xa4\xe4\xa7\xeb\x81\x79\xa3\x8a\x47\x15\x8f\x2a\x1e\x55\x3c\xaa\x78\x54\xf1\xa8\xe2\x51\xc5\xa3\x8a\x47\x15\x8f\x2a\x1e\x55\x3c\xaa\x78\x54\xf1\xa8\xe2\x51\xc5\xa3\x8a\x29\x56\x0c\x00\x1a\x89\x5c\x17"
  assert_eq(
    pdf_flate_decode(encoded),
    repeating(b"the quick brown fox jumps over the lazy dog. ", 45 * 100),
  )
  let combined = @core.pdf_bytes_concat_views([encoded, b" EI next"])
  let (decoded, consumed) = pdf_flate_decode_view_prefix(combined)
  assert_eq(
    decoded,
    repeating(b"the quick brown fox jumps over the lazy dog. ", 45 * 100),
  )
  assert_eq(consumed, encoded.length())
}

///|
// Generated independently with Python's zlib, dynamic blocks.
test "decode external zlib dynamic fixture" {
  let encoded = b"\x78\x9c\xed\xca\xdb\x15\x40\x30\x14\x05\xd1\x56\x4e\x05\x7a\x22\x82\x78\x5d\x22\xf1\xaa\x9e\xa5\x05\xbf\xf3\x39\x6b\x76\xea\xbc\xd6\x1c\xdc\xa0\x2a\xda\x31\xab\xb1\x53\x7d\x9e\x96\x4d\xb6\xfb\xa8\xf4\xee\xb1\xbc\x2f\xd5\xd6\x16\x5f\x81\xc1\x60\x30\x18\x0c\x06\x83\xc1\x60\x30\x18\x0c\x06\x83\x7f\xe3\x07\x1a\x89\x5c\x17"
  assert_eq(
    pdf_flate_decode(encoded),
    repeating(b"the quick brown fox jumps over the lazy dog. ", 45 * 100),
  )
  let combined = @core.pdf_bytes_concat_views([encoded, b" EI next"])
  let (decoded, consumed) = pdf_flate_decode_view_prefix(combined)
  assert_eq(
    decoded,
    repeating(b"the quick brown fox jumps over the lazy dog. ", 45 * 100),
  )
  assert_eq(consumed, encoded.length())
}

///|
fn expect_invalid_flate(data : Bytes) -> Unit raise {
  try pdf_flate_decode(data) catch {
    InvalidFlateData => ()
    error => raise error
  } noraise {
    _ => fail("expected invalid Flate data")
  }
}

///|
test "empty input and borrowed ranges retain their contracts" {
  assert_eq(pdf_flate_decode(b""), b"")
  assert_eq(pdf_flate_decode_view_prefix(b""), (b"", 0))
  let data = b"prefix payload suffix"
  let encoded = pdf_flate_encode_view(data[7:14])
  assert_eq(pdf_flate_decode(encoded), b"payload")
  let surrounded = @core.pdf_bytes_concat_views([b"before", encoded, b"after"])
  assert_eq(
    pdf_flate_decode_view(surrounded[6:6 + encoded.length()]),
    b"payload",
  )
  for level in 0..<=9 {
    assert_eq(
      pdf_flate_encode_with_level(b"payload", level),
      pdf_flate_encode_view_with_level(data[7:14], level),
    )
  }
  assert_eq(
    pdf_flate_encode(b"payload"),
    pdf_flate_encode_with_level(b"payload", 6),
  )
}

///|
test "levels outside zero through nine raise instead of clamping" {
  for level in [-1, 10] {
    try pdf_flate_encode_with_level(b"x", level) catch {
      InvalidFlateData => ()
      error => raise error
    } noraise {
      _ => fail("expected invalid compression level")
    }
    try pdf_flate_encode_view_with_level(b"x", level) catch {
      InvalidFlateData => ()
      error => raise error
    } noraise {
      _ => fail("expected invalid compression level")
    }
  }
}

///|
test "truncation headers dictionary and checksum errors are rejected" {
  let encoded = pdf_flate_encode(b"payload")
  for size in 1..<encoded.length() {
    expect_invalid_flate(encoded[:size].to_owned())
  }
  // Invalid method; invalid CINFO with a valid FCHECK; preset dictionary;
  // reserved DEFLATE block type; incorrect Adler-32.
  for
    data in [
      b"\x00\x00\x03\x00\x00\x00\x00\x01", b"\x88\x1c\x03\x00\x00\x00\x00\x01", b"\x78\x20\x00\x00\x00\x01\x03\x00\x00\x00\x00\x01",
      b"\x78\x01\x07\x00\x00\x00\x00\x01", b"\x78\x01\x03\x00\x00\x00\x00\x02",
    ] {
    expect_invalid_flate(data)
    try pdf_flate_decode_view_prefix(data) catch {
      InvalidFlateData => ()
      error => raise error
    } noraise {
      _ => fail("expected invalid prefix")
    }
  }
  // PDF repair may include residual syntax after the complete zlib stream.
  assert_eq(
    pdf_flate_decode(@core.pdf_bytes_concat_views([encoded, b"extra"])),
    b"payload",
  )
  assert_eq(
    pdf_flate_decode(@core.pdf_bytes_concat_views([encoded, encoded])),
    b"payload",
  )
  // A checksum for the original output must not hide garbage before the trailer.
  expect_invalid_flate(
    @core.pdf_bytes_concat_views([
      encoded[:encoded.length() - 4],
      b"extra",
      encoded[encoded.length() - 4:],
    ]),
  )
}

///|
test "prefix length survives input and output backpressure and large suffixes" {
  for input in [incompressible(200000), repeating(b"abc", 200000), b""] {
    for level in [0, 6, 9] {
      let encoded = pdf_flate_encode_with_level(input, level)
      let following = repeating(b" EI next", 100000)
      let combined = @core.pdf_bytes_concat_views([encoded, following])
      let (decoded, consumed) = pdf_flate_decode_view_prefix(combined)
      assert_eq(decoded, input)
      assert_eq(consumed, encoded.length())
      assert_eq(combined[consumed:], following)
      assert_eq(pdf_flate_decode(encoded), input)
    }
  }
}

///|
test "output limit accepts the exact boundary and rejects the next byte" {
  for level in [0, 6] {
    for size in [0, 1, 32768, 32769, 70000] {
      let source = repeating(b"a", size)
      let encoded = pdf_flate_encode_with_level(source, level)
      assert_eq(
        pdf_flate_decode_prefix_limited(encoded, size),
        (source, encoded.length()),
      )
      guard size > 0 else { continue }
      try pdf_flate_decode_prefix_limited(encoded, size - 1) catch {
        FlateOutputLimitExceeded(limit) => assert_eq(limit, size - 1)
        error => raise error
      } noraise {
        _ => fail("expected output limit")
      }
    }
  }
}

///|
test "historical Huffman regression fixtures retain valid and invalid verdicts" {
  let header = b"\x78\x01"
  let trailer = b"\x00\x08\x00\x01" // Adler-32 of eight zero bytes
  for
    body in [
      b"\x05\xc0\x21\x09\x00\x00\x00\x00\x20\xff\xaf\x16\x80", b"\x05\xc0\x21\x09\x00\x00\x00\x00\x20\xff\xaf\x56\x80",
    ] {
    assert_eq(
      pdf_flate_decode(@core.pdf_bytes_concat_views([header, body, trailer])),
      repeating(b"\x00", 8),
    )
  }
  // Three one-bit literal codes cannot fit in a binary Huffman tree.
  expect_invalid_flate(
    @core.pdf_bytes_concat_views([
      header, b"\x05\xc0\x21\x09\x00\x00\x00\x00\x20\xfd\x7f\x5a\x08", b"\x00\x00\x00\x01",
    ]),
  )
}
