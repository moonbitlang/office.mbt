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
    InvalidFlateData => ()
    _ => fail("expected InvalidFlateData")
  } noraise {
    decoded =>
      fail(
        "expected a malformed-stream error, decoded \{decoded.length()} bytes",
      )
  }
}

///|
/// The same rule stated directly on the builder, which is where it lives.
///
/// Going through a whole stream cannot say *which* check refused it, because
/// this decoder raises one undifferentiated `InvalidFlateData` for every
/// malformed shape. Calling the builder with length sets chosen to sit either
/// side of the Kraft boundary does say, and it does not depend on a
/// hand-assembled block staying valid in every other respect.
test "the builder accepts complete and incomplete sets and refuses excess" {
  // Kraft sums, at one code per listed length: 1/2 + 1/4 + 1/4 = 1 exactly.
  let complete : Array[Int] = [1, 2, 2]
  ignore(pdf_flate_build_huffman(complete))
  // 1/2 -- half the code space unassigned, which is legal.
  let incomplete : Array[Int] = [1]
  ignore(pdf_flate_build_huffman(incomplete))
  // 3/2 -- three one-bit codes where two fit.
  let oversubscribed : Array[Int] = [1, 1, 1]
  try pdf_flate_build_huffman(oversubscribed) catch {
    InvalidFlateData => ()
    _ => fail("expected InvalidFlateData")
  } noraise {
    _ => fail("expected an oversubscribed length set to be refused")
  }
  // The boundary is exact: two one-bit codes fill the space and are fine, and
  // a deeper set is refused only once it exceeds what its depth can hold.
  ignore(pdf_flate_build_huffman([1, 1]))
  ignore(pdf_flate_build_huffman([2, 2, 2, 2]))
  try pdf_flate_build_huffman([2, 2, 2, 2, 2]) catch {
    InvalidFlateData => ()
    _ => fail("expected InvalidFlateData")
  } noraise {
    _ => fail("expected five two-bit codes to be refused")
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
