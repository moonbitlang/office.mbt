// Huffman length sets this decoder must refuse, and the ones it must not.
//
// A length set is *oversubscribed* when it declares more codes at some depth
// than that depth can hold -- the Kraft inequality is violated. It is
// *incomplete* when it declares fewer. Only the first is malformed: RFC 1951
// sanctions a block with a single distance code, which is incomplete by
// construction.
//
// This decoder checked for neither, so an oversubscribed stream produced
// output instead of an error. The vectors here were built by an independent
// implementation and their verdicts confirmed against zlib's inflater.

///|
/// A dynamic block whose literal tree declares three codes of one bit.
///
/// One bit holds two codes, so the third overwrites an earlier entry in the
/// flat lookup table. zlib rejects this stream with "invalid literal/lengths
/// set" and `mbtexcel/zip` with "oversubscribed huffman table"; this decoder
/// used to accept it and return an empty result -- silently wrong output from
/// a malformed stream, which is the wrong failure mode for a parser reading
/// untrusted files.
test "an oversubscribed literal tree is refused" {
  let stream = b"\x05\xc0\x21\x09\x00\x00\x00\x00\x20\xfd\x7f\x5a\x08"
  try pdf_deflate_decode_raw(stream) catch {
    _ => ()
  } noraise {
    decoded =>
      fail(
        "expected a malformed-stream error, decoded \{decoded.length()} bytes",
      )
  }
}

///|
/// The same block with a legal literal tree still decodes, so the check above
/// rejects the oversubscription rather than the surrounding block shape.
test "the equivalent well-formed block still decodes" {
  let stream = b"\x05\xc0\x21\x09\x00\x00\x00\x00\x20\xff\xaf\x16\x80"
  assert_eq(pdf_deflate_decode_raw(stream), Bytes::make(8, b'\x00'))
}

///|
/// An incomplete set is not malformed and must keep decoding.
///
/// This block declares one distance code of length one and never uses it,
/// which leaves half the code space unassigned. zlib accepts it. Rejecting
/// every set that fails to fill its code space would refuse streams that
/// decode correctly everywhere else, so the check is deliberately one-sided.
test "an incomplete distance tree is still accepted" {
  let stream = b"\x05\xc0\x21\x09\x00\x00\x00\x00\x20\xff\xaf\x56\x80"
  assert_eq(pdf_deflate_decode_raw(stream), Bytes::make(8, b'\x00'))
}
