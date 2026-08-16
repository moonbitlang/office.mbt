///|
// The entry point: `mz_compress2`'s equivalent, producing a zlib stream.
//
// This is what has to come out byte-identical to
// `pdflite_zlib_compress(data, level)`. Everything else in the port exists to
// make this one function agree with the C.

///|
/// Adler-32 over `data`, seeded at 1 as the format requires.
fn tdefl_adler32(data : BytesView) -> Int {
  let modulus = 65521
  let mut s1 = 1
  let mut s2 = 0
  for byte in data {
    s1 = (s1 + byte.to_int()) % modulus
    s2 = (s2 + s1) % modulus
  }
  ((s2 << 16) | s1) & 0xFFFFFFFF
}

///|
/// Compress `data` to a zlib stream at `level`, the way the vendored miniz
/// does.
///
/// Levels 0..=3 parse greedily and the rest lazily, which is the
/// `TDEFL_GREEDY_PARSING_FLAG` the C derives from the level rather than a
/// separate knob.
fn tdefl_compress_zlib(data : BytesView, level : Int) -> Bytes {
  let state = TdeflState::new(level)
  state.adler32 = tdefl_adler32(data)
  state.compress_input(data, level)
  state.flush_block(level, true)
  Bytes::from_array(state.output)
}
