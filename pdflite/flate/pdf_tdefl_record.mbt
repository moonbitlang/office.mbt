///|
// Recording literals and matches into the LZ code buffer.
//
// The buffer interleaves a flags byte with the codes it describes: one bit per
// entry saying literal or match, written into a byte that was reserved
// *before* the entries it covers. The C tracks that with a pointer held back
// at the reserved position (`m_pLZ_flags`) while `m_pLZ_code_buf` runs ahead;
// this keeps the same two positions as indices, because the flush path depends
// on exactly where each ends up.
//
// The flags byte fills from the top: each record shifts it right and a match
// sets the high bit, so after eight records the first record's bit has walked
// down to bit 0. A partly-filled byte is corrected at flush time by shifting
// the remainder, which is why `num_flags_left` has to be exact.

///|
/// Record one literal byte.
fn TdeflState::record_literal(self : TdeflState, lit : Byte) -> Unit {
  self.total_lz_bytes = self.total_lz_bytes + 1
  self.lz_code_buf[self.lz_code_buf_len] = lit
  self.lz_code_buf_len = self.lz_code_buf_len + 1
  let flags = self.lz_code_buf[self.lz_flags_index].to_int()
  self.lz_code_buf[self.lz_flags_index] = ((flags >> 1) & 0xFF).to_byte()
  self.num_flags_left = self.num_flags_left - 1
  if self.num_flags_left == 0 {
    self.num_flags_left = 8
    self.lz_flags_index = self.lz_code_buf_len
    self.lz_code_buf_len = self.lz_code_buf_len + 1
  }
  self.huff_count[0][lit.to_int()] = self.huff_count[0][lit.to_int()] + 1
}

///|
/// Record one match of `match_len` bytes at `match_dist` back.
///
/// Distance is stored biased by one, which is also what indexes the two
/// distance-symbol tables: `small` covers the low 512 distances directly,
/// `large` covers the rest by their high byte. Choosing between them on
/// `match_dist < 512` *after* the bias is what makes both tables line up.
fn TdeflState::record_match(
  self : TdeflState,
  match_len : Int,
  match_dist_in : Int,
) -> Unit {
  self.total_lz_bytes = self.total_lz_bytes + match_len
  self.lz_code_buf[self.lz_code_buf_len] = (match_len - tdefl_min_match_len).to_byte()
  let match_dist = match_dist_in - 1
  self.lz_code_buf[self.lz_code_buf_len + 1] = (match_dist & 0xFF).to_byte()
  self.lz_code_buf[self.lz_code_buf_len + 2] = ((match_dist >> 8) & 0xFF).to_byte()
  self.lz_code_buf_len = self.lz_code_buf_len + 3
  let flags = self.lz_code_buf[self.lz_flags_index].to_int()
  self.lz_code_buf[self.lz_flags_index] = (((flags >> 1) | 0x80) & 0xFF).to_byte()
  self.num_flags_left = self.num_flags_left - 1
  if self.num_flags_left == 0 {
    self.num_flags_left = 8
    self.lz_flags_index = self.lz_code_buf_len
    self.lz_code_buf_len = self.lz_code_buf_len + 1
  }
  let s0 = tdefl_small_dist_sym[match_dist & 511]
  let s1 = tdefl_large_dist_sym[(match_dist >> 8) & 127]
  let dist_sym = if match_dist < 512 { s0 } else { s1 }
  self.huff_count[1][dist_sym] = self.huff_count[1][dist_sym] + 1
  let len_sym = tdefl_len_sym[match_len - tdefl_min_match_len]
  self.huff_count[0][len_sym] = self.huff_count[0][len_sym] + 1
}
