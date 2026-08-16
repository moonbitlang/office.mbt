///|
// Ending a block: choose how to send it, then send it.
//
// The choice is made by trying. A dynamic or static block is emitted
// speculatively, and if it came out no smaller than the bytes it encodes the
// whole attempt is rolled back and the bytes are sent stored instead. That is
// why the bit-writer state has to be saved and restored precisely: a rollback
// that forgot `bits_in` would resume mid-byte and shift everything after it.

///|
/// The compression level flags the zlib header advertises, derived the way
/// the C derives them -- by finding the probe count in the level table and
/// bucketing its index. It is advisory in the format, but it is part of the
/// bytes, so it has to match.
fn tdefl_zlib_flevel(level : Int) -> Int {
  let clamped = if level < 0 { 6 } else if level > 10 { 10 } else { level }
  if clamped < 2 {
    0
  } else if clamped < 6 {
    1
  } else if clamped == 6 {
    2
  } else {
    3
  }
}

///|
/// Finish the current block. `finish` marks the last one.
fn TdeflState::flush_block(
  self : TdeflState,
  level : Int,
  finish : Bool,
) -> Unit {
  // A partly-filled flags byte holds its bits high; shift them down so the
  // first record's bit is at bit 0, where the walk expects it. When no
  // records used the byte at all, drop it -- otherwise the walk would read a
  // flags byte with no codes behind it.
  let flags = self.lz_code_buf[self.lz_flags_index].to_int()
  self.lz_code_buf[self.lz_flags_index] = ((flags >> self.num_flags_left) & 0xFF).to_byte()
  if self.num_flags_left == 8 {
    self.lz_code_buf_len = self.lz_code_buf_len - 1
  }
  if self.zlib_header && self.block_index == 0 {
    let cmf = 0x78
    let header = (cmf << 8) | (tdefl_zlib_flevel(level) << 6)
    let check = header + (31 - header % 31)
    self.put_bits(cmf, 8)
    self.put_bits(check & 0xFF, 8)
  }
  self.put_bits(if finish { 1 } else { 0 }, 1)
  let saved_output_len = self.output.length()
  let saved_bit_buffer = self.bit_buffer
  let saved_bits_in = self.bits_in
  // static codes below 48 bytes: the dynamic tables would cost more to
  // describe than they save
  let representable = self.lookahead_pos - self.lz_code_buf_dict_pos <=
    self.dict_size
  let use_raw = self.force_raw && representable
  if !use_raw {
    self.compress_block(self.total_lz_bytes < 48)
  }
  let grew = self.total_lz_bytes > 0 &&
    self.output.length() - saved_output_len + 1 >= self.total_lz_bytes
  if (use_raw || grew) && representable {
    // roll back everything the attempt wrote, including the partial byte
    while self.output.length() > saved_output_len {
      let _ = self.output.pop()
    }
    self.bit_buffer = saved_bit_buffer
    self.bits_in = saved_bits_in
    self.put_bits(0, 2)
    if self.bits_in != 0 {
      self.put_bits(0, 8 - self.bits_in)
    }
    // LEN then ~LEN, which the C writes by toggling the same value
    let mut len = self.total_lz_bytes
    for _ in 0..<2 {
      self.put_bits(len & 0xFFFF, 16)
      len = len ^ 0xFFFF
    }
    for i in 0..<self.total_lz_bytes {
      self.put_bits(
        self.dict[(self.lz_code_buf_dict_pos + i) & tdefl_lz_dict_size_mask].to_int(),
        8,
      )
    }
  }
  if finish {
    if self.bits_in != 0 {
      self.put_bits(0, 8 - self.bits_in)
    }
    if self.zlib_header {
      // Adler-32 is the one big-endian field in an otherwise little-endian
      // format, so it is written a byte at a time from the top
      let mut a = self.adler32
      for _ in 0..<4 {
        self.put_bits((a >> 24) & 0xFF, 8)
        a = (a << 8) & 0xFFFFFFFF
      }
    }
  }
  for i in 0..<tdefl_max_huff_symbols_0 {
    self.huff_count[0][i] = 0
  }
  for i in 0..<tdefl_max_huff_symbols_1 {
    self.huff_count[1][i] = 0
  }
  self.lz_code_buf_len = 1
  self.lz_flags_index = 0
  self.lz_code_buf[0] = b'\x00'
  self.num_flags_left = 8
  self.lz_code_buf_dict_pos = self.lz_code_buf_dict_pos + self.total_lz_bytes
  self.total_lz_bytes = 0
  self.block_index = self.block_index + 1
}
