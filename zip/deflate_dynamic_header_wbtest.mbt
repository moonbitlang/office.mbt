// Dynamic-block header shapes this decoder must accept.
//
// The existing round-trip and fuzz properties compress with `deflate_encode`
// and decompress with `deflate_decode`, so they only ever cover shapes our own
// writer emits -- and our writer emits a single fixed-Huffman block, never a
// dynamic one. Encoder and decoder were built together and agree with each
// other, which is exactly why a legal shape neither of them uses could stay
// broken: a dynamic block declaring an all-zero distance tree was rejected as
// malformed, so any archive written by miniz (or zlib, or a real Office
// application) that contained a match-free block could not be read.
//
// These tests emit dynamic blocks directly instead, so the decoder is measured
// against the format rather than against our encoder.

///|
/// Which distance tree `emit_dynamic_literal_block` declares.
///
/// A block coding no matches needs no distance codes, but the format still
/// requires a distance tree. Both shapes below are legal and both appear in
/// the wild; `AllZeroDistances` is the one that used to be rejected.
priv enum DistanceShape {
  /// Every distance length zero -- what miniz emits for a match-free block.
  AllZeroDistances
  /// One distance code of length 1, unreferenced. Accepted before this fix,
  /// so it exercises the emitter through a path that was already correct.
  SingleDistanceCode
}

///|
/// Code-length alphabet used by the emitter: symbols 0, 1, 17 and 18, each
/// given length 2. Four codes of length 2 satisfy Kraft exactly, so the tree
/// is complete whichever symbols a particular block happens to use.
const CL_ZERO : Int = 0b00

///|
const CL_ONE : Int = 0b01

///|
const CL_REPEAT_SHORT : Int = 0b10 // symbol 17: 3..10 zeros

///|
const CL_REPEAT_LONG : Int = 0b11 // symbol 18: 11..138 zeros

///|
/// Emit `count` zero lengths using symbols 18, 17 and 0, longest run first.
fn emit_zero_run(writer : BitWriter, count : Int) -> Unit raise ZipError {
  let mut remaining = count
  while remaining > 0 {
    if remaining >= 11 {
      let run = if remaining < 138 { remaining } else { 138 }
      writer.write_bits(
        reverse_bits(CL_REPEAT_LONG.reinterpret_as_uint(), 2).reinterpret_as_int(),
        2,
      )
      writer.write_bits(run - 11, 7)
      remaining = remaining - run
    } else if remaining >= 3 {
      let run = if remaining < 10 { remaining } else { 10 }
      writer.write_bits(
        reverse_bits(CL_REPEAT_SHORT.reinterpret_as_uint(), 2).reinterpret_as_int(),
        2,
      )
      writer.write_bits(run - 3, 3)
      remaining = remaining - run
    } else {
      for _ in 0..<remaining {
        writer.write_bits(
          reverse_bits(CL_ZERO.reinterpret_as_uint(), 2).reinterpret_as_int(),
          2,
        )
      }
      remaining = 0
    }
  }
}

///|
/// Build a single dynamic-Huffman block coding `count` copies of `byte`.
///
/// The literal tree gives `byte` and the end-of-block symbol one bit each; the
/// block codes no matches, so the distance tree it declares is never
/// referenced and `shape` chooses which legal form it takes. `hdist` is the
/// declared distance-tree size, which the format allows to exceed what the
/// block uses.
///
/// This is deliberately a simple encoder rather than an optimal one -- its job
/// is to produce header shapes, not small output.
fn emit_dynamic_literal_block(
  byte : Int,
  count : Int,
  hdist : Int,
  shape : DistanceShape,
) -> Bytes raise ZipError {
  // `FixedByteOutput::allocated` wants the exact size, so measure first --
  // the same two-pass shape `deflate_encode_with_limit` uses.
  let counting = FixedByteOutput::counting()
  emit_dynamic_literal_block_into(counting, byte, count, hdist, shape)
  let out = FixedByteOutput::allocated(counting.length())
  emit_dynamic_literal_block_into(out, byte, count, hdist, shape)
  out.finish()
}

///|
fn emit_dynamic_literal_block_into(
  out : FixedByteOutput,
  byte : Int,
  count : Int,
  hdist : Int,
  shape : DistanceShape,
) -> Unit raise ZipError {
  let writer = BitWriter::new(out)
  writer.write_bits(1, 1) // BFINAL
  writer.write_bits(2, 2) // BTYPE = 10, dynamic Huffman
  writer.write_bits(0, 5) // HLIT  = 257 literal/length lengths
  writer.write_bits(hdist - 1, 5) // HDIST
  writer.write_bits(14, 4) // HCLEN = 18 code-length lengths
  let order : ReadOnlyArray[Int] = [
    16, 17, 18, 0, 8, 7, 9, 6, 10, 5, 11, 4, 12, 3, 13, 2, 14, 1, 15,
  ]
  for i in 0..<18 {
    let symbol = order[i]
    let length = if symbol == 0 || symbol == 1 || symbol == 17 || symbol == 18 {
      2
    } else {
      0
    }
    writer.write_bits(length, 3)
  }
  let one = reverse_bits(CL_ONE.reinterpret_as_uint(), 2).reinterpret_as_int()
  // 257 literal/length lengths: 1 at `byte`, 1 at the end-of-block symbol.
  emit_zero_run(writer, byte)
  writer.write_bits(one, 2)
  emit_zero_run(writer, 255 - byte)
  writer.write_bits(one, 2)
  // `hdist` distance lengths.
  match shape {
    AllZeroDistances => emit_zero_run(writer, hdist)
    SingleDistanceCode => {
      writer.write_bits(one, 2)
      emit_zero_run(writer, hdist - 1)
    }
  }
  // Both literal codes are one bit: `byte` sorts before 256, so it takes 0.
  for _ in 0..<count {
    writer.write_bits(0, 1)
  }
  writer.write_bits(1, 1) // end of block
  writer.finish()
}

///|
/// The emitter is only evidence if it emits what it claims to. These four
/// vectors were built by an independent Python implementation of the same
/// layout and confirmed to decompress correctly under zlib's inflater, so
/// matching them pins this emitter to streams a reference decoder accepts.
///
/// Without this, a bug in the emitter would look like a bug in the decoder.
test "the block emitter reproduces externally verified streams" {
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
}

///|
fn bytes_hex(bytes : Bytes) -> String {
  let digits : ReadOnlyArray[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
  ]
  let text = StringBuilder::new()
  for byte in bytes {
    let value = byte.to_int()
    text.write_char(digits[value >> 4])
    text.write_char(digits[value & 0xF])
  }
  text.to_string()
}

///|
/// The regression: a block whose distance tree is entirely zero.
///
/// RFC 1951 3.2.7 requires a dynamic block to declare a distance tree even
/// when it codes no matches, and every length in that tree is then zero. This
/// decoder used to raise `UnsupportedFeature("empty huffman table")` here,
/// which meant it could not read archives produced by miniz -- the compressor
/// `pdflite` ships and a common choice elsewhere.
test "a dynamic block may declare an all-zero distance tree" {
  let stream = emit_dynamic_literal_block(0, 8, 1, AllZeroDistances)
  inspect(deflate_decode(stream, max_output=64).length(), content="8")
}

///|
/// The declared distance tree may also be larger than the block needs.
test "an all-zero distance tree may be declared at any HDIST" {
  for hdist in [1, 2, 5, 17, 30] {
    let stream = emit_dynamic_literal_block(65, 4, hdist, AllZeroDistances)
    let decoded = deflate_decode(stream, max_output=64)
    assert_eq(decoded, b"AAAA")
  }
}

///|
/// Every header shape this emitter can build is legal, so the decoder has to
/// accept all of them and return the literals the block codes.
///
/// The parameters are folded out of the generated integers, so shrinking
/// reports a simpler seed rather than a minimal `(byte, count, hdist)` --
/// enough to reproduce a failure, not enough to read one directly. Both
/// distance shapes are generated: `SingleDistanceCode` decoded correctly
/// before this fix, so if it ever fails alongside `AllZeroDistances` the
/// emitter is at fault rather than the distance-tree handling.
test "the decoder accepts every dynamic header shape the emitter can build" {
  @quickcheck.check(
    (raw : Array[Int]) => {
      guard raw.length() > 0 else { return true }
      // Fold with wraparound so every non-empty array yields a full parameter
      // set; a length guard would discard most cases at this `max_size`.
      let pick = (i : Int, span : Int) => {
        let value = raw[i % raw.length()] % span
        if value < 0 {
          value + span
        } else {
          value
        }
      }
      let byte = pick(0, 256)
      let count = 1 + pick(1, 48)
      let hdist = 1 + pick(2, 30)
      let shape = if pick(3, 2) == 0 {
        AllZeroDistances
      } else {
        SingleDistanceCode
      }
      let stream = emit_dynamic_literal_block(byte, count, hdist, shape)
      let decoded = deflate_decode(stream, max_output=128)
      if decoded.length() != count {
        return false
      }
      for i in 0..<count {
        if decoded[i].to_int() != byte {
          return false
        }
      }
      true
    },
    count=200,
    max_size=8,
    seed=0x7A69_705F_646FUL,
  )
}
