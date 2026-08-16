///|
// Compressor state for the MoonBit port of miniz's tdefl.
//
// The shape follows the C struct rather than what one would design fresh,
// because the algorithm reads and writes these fields in an order that is
// part of the output. In particular the dictionary is deliberately larger
// than the window and the hash chain stores truncated positions -- both are
// load-bearing, and both are commented where they are used.

///|
let tdefl_lz_dict_size : Int = 32768

///|
let tdefl_lz_dict_size_mask : Int = tdefl_lz_dict_size - 1

///|
let tdefl_min_match_len : Int = 3

///|
let tdefl_max_match_len : Int = 258

///|
let tdefl_lz_hash_bits : Int = 15

///|
/// `(TDEFL_LZ_HASH_BITS + 2) / 3` in the C, which is 5 at 15 bits.
let tdefl_lz_hash_shift : Int = (tdefl_lz_hash_bits + 2) / 3

///|
let tdefl_lz_hash_size : Int = 1 << tdefl_lz_hash_bits

///|
let tdefl_lz_code_buf_size : Int = 64 * 1024

///|
let tdefl_max_huff_symbols_0 : Int = 288

///|
let tdefl_max_huff_symbols_1 : Int = 32

///|
let tdefl_max_huff_symbols_2 : Int = 19

///|
/// Probe budgets by level, straight from `s_tdefl_num_probes`. The index is
/// the zlib level; the value is both the probe count and, in the C, the low
/// twelve bits of the flags word.
let tdefl_num_probes : FixedArray[Int] = [
  0, 1, 6, 32, 16, 32, 128, 256, 512, 768, 1500,
]

///|
/// Levels at or below this parse greedily rather than lazily, which is the
/// `TDEFL_GREEDY_PARSING_FLAG` the C derives from the level.
let tdefl_greedy_max_level : Int = 3

///|
priv struct TdeflState {
  /// Two probe budgets: `[0]` for a current match shorter than 32 bytes,
  /// `[1]` once one is at least that long. `tdefl_find_match` selects with
  /// `match_len >= 32`, so a promising match gets a different search depth.
  max_probes : FixedArray[Int]
  greedy_parsing : Bool
  /// Level 0 sets TDEFL_FORCE_ALL_RAW_BLOCKS: no matching at all, and
  /// every block sent stored. It is not merely "search less" -- the
  /// matcher is skipped and flush_block takes the stored path directly.
  force_raw : Bool
  /// Oversized by `tdefl_max_match_len - 1` on purpose. `find_match` reads
  /// `dict[pos + match_len]` without masking, and the bytes past the window
  /// are a mirror of the first bytes written, so those reads stay in bounds
  /// and see what the C sees. Masking the index instead would be the obvious
  /// "fix" and would change which matches are found.
  dict : FixedArray[Byte]
  /// Hash chain: previous position that hashed the same, truncated to 16
  /// bits exactly as the C stores it in a `mz_uint16`.
  next : FixedArray[Int]
  hash : FixedArray[Int]
  huff_count : FixedArray[FixedArray[Int]]
  huff_codes : FixedArray[FixedArray[Int]]
  huff_code_sizes : FixedArray[FixedArray[Int]]
  lz_code_buf : FixedArray[Byte]
  mut lz_code_buf_len : Int
  mut lz_flags_index : Int
  mut num_flags_left : Int
  mut total_lz_bytes : Int
  mut lookahead_pos : Int
  mut lookahead_size : Int
  mut dict_size : Int
  mut saved_match_dist : Int
  mut saved_match_len : Int
  mut saved_lit : Int
  mut block_index : Int
  /// Blocks ended because the LZ code buffer ran out of room, as opposed
  /// to the poor-compression heuristic. The two branches are easy to
  /// confuse from the outside -- literal-heavy input trips the heuristic at
  /// 31 KiB, long before the 64 KiB buffer fills -- so a test that means to
  /// exercise the capacity path has to be able to say it did.
  mut capacity_flushes : Int
  /// Dictionary position the current block's bytes start at, so a block
  /// that compresses badly can be re-sent verbatim from the dictionary.
  mut lz_code_buf_dict_pos : Int
  mut adler32 : Int
  /// Emit a zlib wrapper (header now, Adler-32 at finish).
  zlib_header : Bool
  mut bit_buffer : Int
  mut bits_in : Int
  output : Array[Byte]
}

///|
fn TdeflState::new(level : Int) -> TdeflState {
  let clamped = if level < 0 { 6 } else if level > 10 { 10 } else { level }
  let probes = tdefl_num_probes[clamped]
  {
    // straight from tdefl_init; the two budgets are derived from the same
    // probe count by different divisions, and guessing the shape of that
    // arithmetic changes how far the matcher searches
    max_probes: [1 + (probes + 2) / 3, 1 + ((probes >> 2) + 2) / 3],
    greedy_parsing: clamped <= tdefl_greedy_max_level,
    force_raw: level == 0,
    dict: FixedArray::make(
      tdefl_lz_dict_size + tdefl_max_match_len - 1,
      b'\x00',
    ),
    next: FixedArray::make(tdefl_lz_dict_size, 0),
    hash: FixedArray::make(tdefl_lz_hash_size, 0),
    huff_count: FixedArray::makei(3, _ => {
      FixedArray::make(tdefl_max_huff_symbols_0, 0)
    }),
    huff_codes: FixedArray::makei(3, _ => {
      FixedArray::make(tdefl_max_huff_symbols_0, 0)
    }),
    huff_code_sizes: FixedArray::makei(3, _ => {
      FixedArray::make(tdefl_max_huff_symbols_0, 0)
    }),
    lz_code_buf: FixedArray::make(tdefl_lz_code_buf_size, b'\x00'),
    lz_code_buf_len: 1,
    lz_flags_index: 0,
    num_flags_left: 8,
    total_lz_bytes: 0,
    lookahead_pos: 0,
    lookahead_size: 0,
    dict_size: 0,
    saved_match_dist: 0,
    saved_match_len: 0,
    saved_lit: 0,
    block_index: 0,
    capacity_flushes: 0,
    lz_code_buf_dict_pos: 0,
    adler32: 1,
    zlib_header: true,
    bit_buffer: 0,
    bits_in: 0,
    output: [],
  }
}

///|
/// Append `len` low bits of `bits`, least significant first.
///
/// The C writes into a bounded buffer and silently drops once full, because
/// it flushes periodically and never actually reaches the bound. This grows
/// instead, which produces the same bytes for any input the C would not have
/// dropped -- that is, all of them.
fn TdeflState::put_bits(self : TdeflState, bits : Int, len : Int) -> Unit {
  self.bit_buffer = self.bit_buffer | (bits << self.bits_in)
  self.bits_in = self.bits_in + len
  while self.bits_in >= 8 {
    self.output.push((self.bit_buffer & 0xFF).to_byte())
    self.bit_buffer = self.bit_buffer >> 8
    self.bits_in = self.bits_in - 8
  }
}
