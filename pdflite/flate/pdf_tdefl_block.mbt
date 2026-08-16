///|
// Block emission: the two block headers, and the walk that turns the LZ code
// buffer into bits.

///|
/// Low `n` bits mask, indexed by bit count. `mz_bitmasks` in the C.
let tdefl_bitmasks : FixedArray[Int] = [
  0x0000, 0x0001, 0x0003, 0x0007, 0x000F, 0x001F, 0x003F, 0x007F, 0x00FF, 0x01FF,
  0x03FF, 0x07FF, 0x0FFF, 0x1FFF, 0x3FFF, 0x7FFF, 0xFFFF,
]

///|
/// Extra-bit counts for the three repeat codes 16, 17, 18, which the C spells
/// as the string literal "\02\03\07".
let tdefl_repeat_extra_bits : FixedArray[Int] = [2, 3, 7]

///|
/// A fixed-Huffman block: the code lengths are defined by the format, so they
/// are installed directly and only the codes are derived.
fn TdeflState::start_static_block(self : TdeflState) -> Unit {
  let sizes = self.huff_code_sizes[0]
  for i in 0..<=143 {
    sizes[i] = 8
  }
  for i in 144..<=255 {
    sizes[i] = 9
  }
  for i in 256..<=279 {
    sizes[i] = 7
  }
  for i in 280..<=287 {
    sizes[i] = 8
  }
  for i in 0..<32 {
    self.huff_code_sizes[1][i] = 5
  }
  self.optimize_huffman_table(0, 288, 15, true)
  self.optimize_huffman_table(1, 32, 15, true)
  self.put_bits(1, 2)
}

///|
/// A dynamic-Huffman block: build both tables, then send the tables
/// themselves, run-length encoded through a third Huffman table.
///
/// The run-length encoding is the fiddly part and is transcribed rather than
/// restructured. A run of zero lengths and a run of repeated non-zero lengths
/// are flushed by different rules, and each is flushed *before* the other
/// starts -- which is why both flushes appear at several points that look
/// redundant and are not.
fn TdeflState::start_dynamic_block(self : TdeflState) -> Unit {
  // the end-of-block symbol always appears exactly once
  self.huff_count[0][256] = 1
  self.optimize_huffman_table(0, tdefl_max_huff_symbols_0, 15, false)
  self.optimize_huffman_table(1, tdefl_max_huff_symbols_1, 15, false)
  let mut num_lit_codes = 286
  while num_lit_codes > 257 && self.huff_code_sizes[0][num_lit_codes - 1] == 0 {
    num_lit_codes = num_lit_codes - 1
  }
  let mut num_dist_codes = 30
  while num_dist_codes > 1 && self.huff_code_sizes[1][num_dist_codes - 1] == 0 {
    num_dist_codes = num_dist_codes - 1
  }
  let to_pack = FixedArray::make(
    tdefl_max_huff_symbols_0 + tdefl_max_huff_symbols_1,
    0,
  )
  for i in 0..<num_lit_codes {
    to_pack[i] = self.huff_code_sizes[0][i]
  }
  for i in 0..<num_dist_codes {
    to_pack[num_lit_codes + i] = self.huff_code_sizes[1][i]
  }
  let total_to_pack = num_lit_codes + num_dist_codes
  let packed = FixedArray::make(
    tdefl_max_huff_symbols_0 + tdefl_max_huff_symbols_1,
    0,
  )
  let mut num_packed = 0
  let mut rle_z_count = 0
  let mut rle_repeat_count = 0
  // 0xFF cannot be a real code size, so the first entry never counts as a
  // repeat of whatever came before it
  let mut prev_code_size = 0xFF
  for i in 0..<tdefl_max_huff_symbols_2 {
    self.huff_count[2][i] = 0
  }
  let flush_prev = () => {
    if rle_repeat_count != 0 {
      if rle_repeat_count < 3 {
        self.huff_count[2][prev_code_size] = self.huff_count[2][prev_code_size] +
          rle_repeat_count
        for _ in 0..<rle_repeat_count {
          packed[num_packed] = prev_code_size
          num_packed = num_packed + 1
        }
      } else {
        self.huff_count[2][16] = self.huff_count[2][16] + 1
        packed[num_packed] = 16
        packed[num_packed + 1] = rle_repeat_count - 3
        num_packed = num_packed + 2
      }
      rle_repeat_count = 0
    }
  }
  let flush_zero = () => {
    if rle_z_count != 0 {
      if rle_z_count < 3 {
        self.huff_count[2][0] = self.huff_count[2][0] + rle_z_count
        for _ in 0..<rle_z_count {
          packed[num_packed] = 0
          num_packed = num_packed + 1
        }
      } else if rle_z_count <= 10 {
        self.huff_count[2][17] = self.huff_count[2][17] + 1
        packed[num_packed] = 17
        packed[num_packed + 1] = rle_z_count - 3
        num_packed = num_packed + 2
      } else {
        self.huff_count[2][18] = self.huff_count[2][18] + 1
        packed[num_packed] = 18
        packed[num_packed + 1] = rle_z_count - 11
        num_packed = num_packed + 2
      }
      rle_z_count = 0
    }
  }
  for i in 0..<total_to_pack {
    let code_size = to_pack[i]
    if code_size == 0 {
      flush_prev()
      rle_z_count = rle_z_count + 1
      if rle_z_count == 138 {
        flush_zero()
      }
    } else {
      flush_zero()
      if code_size != prev_code_size {
        flush_prev()
        self.huff_count[2][code_size] = self.huff_count[2][code_size] + 1
        packed[num_packed] = code_size
        num_packed = num_packed + 1
      } else {
        rle_repeat_count = rle_repeat_count + 1
        if rle_repeat_count == 6 {
          flush_prev()
        }
      }
    }
    prev_code_size = code_size
  }
  if rle_repeat_count != 0 {
    flush_prev()
  } else {
    flush_zero()
  }
  self.optimize_huffman_table(2, tdefl_max_huff_symbols_2, 7, false)
  self.put_bits(2, 2)
  self.put_bits(num_lit_codes - 257, 5)
  self.put_bits(num_dist_codes - 1, 5)
  // the code-length lengths are sent in a fixed permutation, so trailing
  // zeros in *that* order can be dropped
  let mut num_bit_lengths = 18
  while num_bit_lengths >= 0 &&
        self.huff_code_sizes[2][tdefl_code_size_swizzle[num_bit_lengths]] == 0 {
    num_bit_lengths = num_bit_lengths - 1
  }
  num_bit_lengths = if num_bit_lengths + 1 > 4 {
    num_bit_lengths + 1
  } else {
    4
  }
  self.put_bits(num_bit_lengths - 4, 4)
  for i in 0..<num_bit_lengths {
    self.put_bits(self.huff_code_sizes[2][tdefl_code_size_swizzle[i]], 3)
  }
  let mut index = 0
  while index < num_packed {
    let code = packed[index]
    index = index + 1
    self.put_bits(self.huff_codes[2][code], self.huff_code_sizes[2][code])
    if code >= 16 {
      self.put_bits(packed[index], tdefl_repeat_extra_bits[code - 16])
      index = index + 1
    }
  }
}

///|
/// Walk the LZ code buffer and emit each literal or match.
///
/// The flags word is refilled with `| 0x100`, a sentinel bit that rides down
/// with the shifts and marks when the eight real bits are spent. Without it
/// the walk cannot tell a consumed flags byte from one that happens to be
/// zero.
fn TdeflState::compress_lz_codes(self : TdeflState) -> Unit {
  let mut flags = 1
  let mut at = 0
  while at < self.lz_code_buf_len {
    if flags == 1 {
      flags = self.lz_code_buf[at].to_int() | 0x100
      at = at + 1
      if at >= self.lz_code_buf_len {
        break
      }
    }
    if (flags & 1) != 0 {
      let match_len = self.lz_code_buf[at].to_int()
      let match_dist = self.lz_code_buf[at + 1].to_int() |
        (self.lz_code_buf[at + 2].to_int() << 8)
      at = at + 3
      let len_sym = tdefl_len_sym[match_len]
      self.put_bits(
        self.huff_codes[0][len_sym],
        self.huff_code_sizes[0][len_sym],
      )
      let len_extra = tdefl_len_extra[match_len]
      self.put_bits(match_len & tdefl_bitmasks[len_extra], len_extra)
      let (sym, dist_extra) = if match_dist < 512 {
        (tdefl_small_dist_sym[match_dist], tdefl_small_dist_extra[match_dist])
      } else {
        (
          tdefl_large_dist_sym[match_dist >> 8],
          tdefl_large_dist_extra[match_dist >> 8],
        )
      }
      self.put_bits(self.huff_codes[1][sym], self.huff_code_sizes[1][sym])
      self.put_bits(match_dist & tdefl_bitmasks[dist_extra], dist_extra)
    } else {
      let lit = self.lz_code_buf[at].to_int()
      at = at + 1
      self.put_bits(self.huff_codes[0][lit], self.huff_code_sizes[0][lit])
    }
    flags = flags >> 1
  }
  self.put_bits(self.huff_codes[0][256], self.huff_code_sizes[0][256])
}

///|
fn TdeflState::compress_block(self : TdeflState, static_block : Bool) -> Unit {
  if static_block {
    self.start_static_block()
  } else {
    self.start_dynamic_block()
  }
  self.compress_lz_codes()
}
