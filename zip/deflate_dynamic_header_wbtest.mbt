// Dynamic-block shapes this decoder must accept.
//
// The existing round-trip and fuzz properties compress with `deflate_encode`
// and decompress with `deflate_decode`, so they only ever cover shapes our own
// writer emits -- and our writer emits a single fixed-Huffman block, never a
// dynamic one. Encoder and decoder were built together and agree with each
// other, which is exactly why a legal shape neither of them uses could stay
// broken: a dynamic block declaring an all-zero distance tree was rejected as
// malformed, so an archive was unreadable whenever it contained such a block.
//
// That miniz emits this shape was checked against the vendored copy rather
// than assumed: compressing a match-free payload with `tdefl_compress_mem_to_heap`
// yields a dynamic block with `HDIST` = 1 and a distance tree whose single
// length is zero. (zlib's encoder does *not* emit it -- `trees.c` forces at
// least two codes -- so this is a miniz-shaped stream specifically.)
//
// These tests emit dynamic blocks directly instead, so the decoder is measured
// against the format rather than against our encoder.

///|
/// Which distance tree the emitters declare.
///
/// A block coding no matches needs no distance codes, but the format still
/// requires a distance tree. Both shapes below are legal; `AllZeroDistances`
/// is the one that used to be rejected.
priv enum DistanceShape {
  /// Every distance length zero -- what miniz emits for a match-free block.
  AllZeroDistances
  /// One distance code of length 1, unreferenced. Accepted before this fix,
  /// so it exercises the emitter through a decode path that already worked.
  SingleDistanceCode
}

///|
/// A code-length alphabet: the canonical code for each symbol the emitters
/// use to describe a length sequence, as `(code, bits)` with the code in
/// most-significant-bit-first order.
priv struct CodeLengths {
  zero : (Int, Int) // symbol 0
  one : (Int, Int) // symbol 1
  two : (Int, Int) // symbol 2
  repeat_short : (Int, Int) // symbol 17: 3..10 zeros
  repeat_long : (Int, Int) // symbol 18: 11..138 zeros
  /// Length declared for each symbol, indexed by symbol.
  declared : ReadOnlyArray[Int]
}

///|
/// Symbols 0, 1, 17 and 18 at two bits each -- four codes of length two,
/// which satisfies Kraft exactly.
let literal_block_alphabet : CodeLengths = {
  zero: (0b00, 2),
  one: (0b01, 2),
  two: (0, 0),
  repeat_short: (0b10, 2),
  repeat_long: (0b11, 2),
  declared: [2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2, 2],
}

///|
/// Symbols 0, 1 and 2 at two bits, 17 and 18 at three -- also exactly Kraft.
/// A second alphabet is needed because the payload block declares a literal of
/// length two, so symbol 2 has to be describable.
let payload_block_alphabet : CodeLengths = {
  zero: (0b00, 2),
  one: (0b01, 2),
  two: (0b10, 2),
  repeat_short: (0b110, 3),
  repeat_long: (0b111, 3),
  declared: [2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, 3],
}

///|
/// The code-length symbol permutation from RFC 1951 3.2.7.
let code_length_order : ReadOnlyArray[Int] = [
  16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
]

///|
/// Write a Huffman code. Codes are most-significant-bit first while the bit
/// writer emits least-significant-bit first, so they are reversed on the way
/// out -- the same convention `deflate_encode_to_output` uses.
fn write_code(writer : BitWriter, code : (Int, Int)) -> Unit raise ZipError {
  let (value, bits) = code
  writer.write_bits(
    reverse_bits(value.reinterpret_as_uint(), bits).reinterpret_as_int(),
    bits,
  )
}

///|
/// Emit `count` zero lengths using symbols 18, 17 and 0, longest run first.
fn emit_zero_run(
  writer : BitWriter,
  alphabet : CodeLengths,
  count : Int,
) -> Unit raise ZipError {
  let mut remaining = count
  while remaining > 0 {
    if remaining >= 11 {
      let run = if remaining < 138 { remaining } else { 138 }
      write_code(writer, alphabet.repeat_long)
      writer.write_bits(run - 11, 7)
      remaining = remaining - run
    } else if remaining >= 3 {
      let run = if remaining < 10 { remaining } else { 10 }
      write_code(writer, alphabet.repeat_short)
      writer.write_bits(run - 3, 3)
      remaining = remaining - run
    } else {
      for _ in 0..<remaining {
        write_code(writer, alphabet.zero)
      }
      remaining = 0
    }
  }
}

///|
/// Write the block header up to and including the code-length lengths.
fn emit_dynamic_header(
  writer : BitWriter,
  alphabet : CodeLengths,
  hlit : Int,
  hdist : Int,
) -> Unit raise ZipError {
  writer.write_bits(1, 1) // BFINAL
  writer.write_bits(2, 2) // BTYPE = 10, dynamic Huffman
  writer.write_bits(hlit - 257, 5)
  writer.write_bits(hdist - 1, 5)
  writer.write_bits(14, 4) // HCLEN = 18 code-length lengths
  for i in 0..<18 {
    writer.write_bits(alphabet.declared[code_length_order[i]], 3)
  }
}

///|
/// Run an emitter twice: `FixedByteOutput::allocated` wants the exact size, so
/// measure first. The same two-pass shape `deflate_encode_with_limit` uses.
fn emit_twice(
  body : (BitWriter) -> Unit raise ZipError,
) -> Bytes raise ZipError {
  let counting = FixedByteOutput::counting()
  let measure = BitWriter::new(counting)
  body(measure)
  measure.finish()
  let out = FixedByteOutput::allocated(counting.length())
  let writer = BitWriter::new(out)
  body(writer)
  writer.finish()
  out.finish()
}

///|
/// Build a dynamic block coding `count` copies of `byte`.
///
/// The literal tree gives `byte` and the end-of-block symbol one bit each; the
/// block codes no matches, so the distance tree it declares is never
/// referenced and `shape` chooses which legal form it takes. `hdist` is the
/// declared distance-tree size, which the format allows to exceed what the
/// block uses.
///
/// Deliberately a simple encoder rather than an optimal one -- its job is to
/// produce header shapes, not small output.
fn emit_dynamic_literal_block(
  byte : Int,
  count : Int,
  hdist : Int,
  shape : DistanceShape,
) -> Bytes raise ZipError {
  emit_twice(writer => {
    let alphabet = literal_block_alphabet
    emit_dynamic_header(writer, alphabet, 257, hdist)
    // 257 literal/length lengths: 1 at `byte`, 1 at the end-of-block symbol.
    emit_zero_run(writer, alphabet, byte)
    write_code(writer, alphabet.one)
    emit_zero_run(writer, alphabet, 255 - byte)
    write_code(writer, alphabet.one)
    match shape {
      AllZeroDistances => emit_zero_run(writer, alphabet, hdist)
      SingleDistanceCode => {
        write_code(writer, alphabet.one)
        emit_zero_run(writer, alphabet, hdist - 1)
      }
    }
    // Both literal codes are one bit: `byte` sorts before 256, so it takes 0.
    for _ in 0..<count {
      writer.write_bits(0, 1)
    }
    writer.write_bits(1, 1) // end of block
  })
}

///|
/// Build a dynamic block coding one byte per entry of `choices`: `'A'` for
/// false, `'B'` for true. The distance tree is all zero.
///
/// Unlike `emit_dynamic_literal_block` this declares literals of two different
/// code lengths, so the decoder walks a literal tree of mixed depth rather
/// than one where every code is a single bit.
fn emit_dynamic_payload_block(
  choices : ArrayView[Bool],
) -> Bytes raise ZipError {
  emit_twice(writer => {
    let alphabet = payload_block_alphabet
    emit_dynamic_header(writer, alphabet, 257, 1)
    // 'A' = 65 at length 1, 'B' = 66 at length 2, end-of-block at length 2.
    emit_zero_run(writer, alphabet, 65)
    write_code(writer, alphabet.one)
    write_code(writer, alphabet.two)
    emit_zero_run(writer, alphabet, 189)
    write_code(writer, alphabet.two)
    emit_zero_run(writer, alphabet, 1) // all-zero distance tree
    // Canonical: 65 -> 0 (1 bit), 66 -> 10, end-of-block -> 11.
    for choice in choices {
      if choice {
        writer.write_bits(reverse_bits(0b10U, 2).reinterpret_as_int(), 2)
      } else {
        writer.write_bits(0, 1)
      }
    }
    writer.write_bits(reverse_bits(0b11U, 2).reinterpret_as_int(), 2)
  })
}

///|
fn bytes_hex(bytes : Bytes) -> String {
  let digits : ReadOnlyArray[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let text = StringBuilder()
  for byte in bytes {
    let value = byte.to_int()
    text.write_char(digits[value >> 4])
    text.write_char(digits[value & 0xF])
  }
  text.to_string()
}

///|
/// The emitters are only evidence if they emit what they claim to. These
/// vectors were built by an independent Python implementation of the same
/// layout and confirmed to decompress correctly under zlib's inflater, so
/// matching them pins these emitters to streams a reference decoder accepts.
///
/// Without this, a bug in an emitter would look like a bug in the decoder.
test "the block emitters reproduce externally verified streams" {
  // Compared as hex so these read the same here as in the reference that
  // produced them; `Show` for `Bytes` prints printable octets as characters.
  inspect(
    bytes_hex(emit_dynamic_literal_block(0, 8, 1, AllZeroDistances)),
    content="05c021090000000020ffaf1680",
  )
  inspect(
    bytes_hex(emit_dynamic_literal_block(0, 8, 1, SingleDistanceCode)),
    content="05c021090000000020ffaf5680",
  )
  inspect(
    bytes_hex(emit_dynamic_literal_block(255, 3, 30, AllZeroDistances)),
    content="05dd210900000000a0ffabf50902",
  )
  inspect(
    bytes_hex(emit_dynamic_literal_block(65, 17, 5, AllZeroDistances)),
    content="05c4210900000000a06dfe3f65020010",
  )
  inspect(
    bytes_hex(emit_dynamic_payload_block([])),
    content="05c0b10900000080a0dbecffa362",
  )
  inspect(
    bytes_hex(emit_dynamic_payload_block([false])),
    content="05c0b10900000080a0dbecffa3c2",
  )
  inspect(
    bytes_hex(emit_dynamic_payload_block([true])),
    content="05c0b10900000080a0dbecffa3a201",
  )
  inspect(
    bytes_hex(emit_dynamic_payload_block([false, true, true, false, true])),
    content="05c0b10900000080a0dbecffa34269",
  )
}

///|
/// The regression: a block whose distance tree is entirely zero.
///
/// RFC 1951 3.2.7 requires a dynamic block to declare a distance tree even
/// when it codes no matches. Such a tree *may* be all zero -- it may equally
/// declare unused nonzero codes, which is what `SingleDistanceCode` builds --
/// and miniz emits the all-zero form. This decoder used to raise
/// `UnsupportedFeature("empty huffman table")` for it, so an archive was
/// unreadable whenever it contained such a block.
test "a dynamic block may declare an all-zero distance tree" {
  let stream = emit_dynamic_literal_block(0, 8, 1, AllZeroDistances)
  inspect(deflate_decode(stream, max_output=64).length(), content="8")
}

///|
/// The literal's position sets the two zero-run lengths in the header, so
/// sweeping all 256 of them enumerates every decomposition `emit_zero_run` can
/// produce from that side -- including the ones either side of a maximal
/// symbol-18 run, where 139 zeros become 138 plus a single literal symbol and
/// 141 become 138 plus a symbol-17 run.
///
/// The repeat count is swept separately, because it changes only the payload
/// bits and not the header at all: folding it in here would multiply the case
/// count without producing one additional distinct header.
test "the decoder accepts a literal declared at any position" {
  let shapes = [AllZeroDistances, SingleDistanceCode]
  let mut checked = 0
  for byte in 0..<256 {
    for shape in shapes {
      let stream = emit_dynamic_literal_block(byte, 3, 1, shape)
      let decoded = deflate_decode(stream, max_output=64)
      assert_eq(decoded, Bytes::make(3, byte.to_byte()))
      checked = checked + 1
    }
  }
  // 256 literal positions x 2 distance-tree shapes, every one a distinct header.
  assert_eq(checked, 512)
}

///|
/// Every declared distance-tree size, at both shapes.
///
/// `HDIST` is five bits plus one, so 32 is the format's limit and not 30.
/// zlib is stricter than the format here and refuses more than 30 with "too
/// many length or distance symbols", because distance codes 30 and 31 have no
/// defined meaning. Declaring them is still legal as long as nothing uses
/// them, so this decoder accepts 31 and 32 -- and if a block did reference
/// code 30 or 31, `decode_huffman_block` bounds-checks the symbol against
/// `dist_base` and raises rather than reading past it.
///
/// Those last two sizes are therefore checked against this decoder alone; the
/// other 30 are shapes zlib accepts too.
///
/// Sweeping `HDIST` is also what drives `emit_zero_run` through all three of
/// its branches from the distance side: the distance run is `hdist` zeros long
/// under `AllZeroDistances` and `hdist - 1` under `SingleDistanceCode`, so
/// between them the sweep covers runs of 0 through 32 and crosses both the
/// 3-and 11-zero thresholds.
///
/// The literal is swept here too, even though the test above already covers
/// every literal position at `hdist` = 1. The literal's runs decide how many
/// bits precede the distance-length description, and the zero-run codes are
/// not byte-aligned, so the description does not always start at the same bit
/// offset. These seven literals start it at three distinct offsets (5, 6 and
/// 7); across all 256 there are five.
test "the decoder accepts every declared distance-tree size" {
  let bytes = [0, 1, 65, 127, 128, 254, 255]
  let shapes = [AllZeroDistances, SingleDistanceCode]
  let mut checked = 0
  for hdist in 1..<=32 {
    for byte in bytes {
      for shape in shapes {
        let stream = emit_dynamic_literal_block(byte, 2, hdist, shape)
        let decoded = deflate_decode(stream, max_output=64)
        assert_eq(decoded, Bytes::make(2, byte.to_byte()))
        checked = checked + 1
      }
    }
  }
  // 32 declared sizes x 7 literals x 2 distance-tree shapes.
  assert_eq(checked, 448)
}

///|
/// Repeat counts, which vary the payload bits rather than the header.
test "the decoder returns every literal a block repeats" {
  for count in [1, 2, 3, 10, 48, 200] {
    let stream = emit_dynamic_literal_block(65, count, 1, AllZeroDistances)
    assert_eq(deflate_decode(stream, max_output=256), Bytes::make(count, b'A'))
  }
}

///|
/// A block that declares an all-zero distance tree and then references it is
/// malformed, and has to be refused rather than silently decoded.
///
/// The comments on `empty_huffman` claim this; nothing else here exercises it,
/// because every other block these emitters build codes no matches at all.
/// zlib rejects this same stream with "invalid distance code".
test "referencing an all-zero distance tree is refused" {
  // Literal 'A', then length symbol 257, which obliges the decoder to read a
  // distance code that the declared tree does not contain.
  let stream = b"\x0d\xc0\xb1\x09\x00\x00\x00\x80\xa0\xdb\xfc\xff\xa9\xc2\x00"
  try deflate_decode(stream, max_output=64) catch {
    UnsupportedFeature(msg~) => inspect(msg, content="invalid huffman code")
    _ => fail("expected an invalid-huffman-code error")
  } noraise {
    _ => fail("expected a malformed-stream error, but decoding succeeded")
  }
}

///|
/// `empty_huffman` decodes nothing, at any input.
test "the empty huffman table decodes no symbol" {
  for probe in [b"\x00", b"\xff", b"\xa5"] {
    let reader = BitReader::new(probe)
    try decode_symbol(reader, empty_huffman()) catch {
      UnsupportedFeature(msg~) => inspect(msg, content="invalid huffman code")
      _ => fail("expected an invalid-huffman-code error")
    } noraise {
      _ => fail("expected the empty table to decode nothing")
    }
  }
}

///|
/// Payload contents, which the enumeration above deliberately does not vary:
/// every block it builds repeats one literal, so the decoder never walks
/// between codes of different lengths within a block.
///
/// `count` and `max_size` are chosen so the generator actually reaches both
/// literals and a spread of lengths -- MoonBit generates array element `i` at
/// size `i`, so an element near the front is always zero and a short
/// `max_size` yields a near-constant payload. The assertions after the check
/// measure what was generated rather than trusting that it varied.
test "the decoder reproduces generated payloads" {
  let lengths : @sorted_set.SortedSet[Int] = SortedSet([])
  let distinct : @sorted_set.SortedSet[String] = SortedSet([])
  let mut saw_a = false
  let mut saw_b = false
  let mut mixed = 0
  @quickcheck.check(
    (raw : Array[Int]) => {
      let choices = raw.map(value => value % 2 != 0)
      let shape = StringBuilder()
      let mut ones = 0
      for choice in choices {
        if choice {
          saw_b = true
          ones = ones + 1
          shape.write_char('B')
        } else {
          saw_a = true
          shape.write_char('A')
        }
      }
      if ones > 0 && ones < choices.length() {
        mixed = mixed + 1
      }
      lengths.add(choices.length())
      distinct.add(shape.to_string())
      let stream = emit_dynamic_payload_block(choices)
      let decoded = deflate_decode(stream, max_output=256)
      if decoded.length() != choices.length() {
        return false
      }
      for i in 0..<choices.length() {
        let want = if choices[i] { 66 } else { 65 }
        if decoded[i].to_int() != want {
          return false
        }
      }
      true
    },
    count=200,
    max_size=64,
    seed=0x7A69_705F_646FUL,
  )
  // Without these the property could pass while generating one payload 200
  // times, which is what an earlier version of this test did. Counting
  // distinct payloads and payloads that mix both literals measures content,
  // not just length -- a run of all-'A' payloads of varying length would
  // satisfy a length-only guard while never walking between codes of
  // different bit lengths, which is the thing this test exists to cover.
  assert_true(saw_a)
  assert_true(saw_b)
  // Floors set below what this seed actually produces (152 mixed, 144
  // distinct, 46 lengths), so they fail loudly if the generator degenerates
  // rather than encoding the current numbers as expectations.
  assert_true(mixed >= 120)
  assert_true(distinct.length() >= 120)
  assert_true(lengths.length() >= 30)
}
