///|
// The lazy-matching parser, from miniz's `tdefl_compress_normal`.
//
// "Lazy" means a match found at one position is not committed until the next
// position has been searched: if the next position starts a longer match, the
// current byte is emitted as a literal instead and the longer match wins. The
// state carried between iterations -- `saved_lit`, `saved_match_dist`,
// `saved_match_len` -- is that deferral, and it is why this cannot be written
// as a simple loop over positions.

///|
/// Feed `input` through the dictionary, recording literals and matches and
/// flushing blocks as the code buffer fills.
fn TdeflState::compress_input(
  self : TdeflState,
  input : BytesView,
  level : Int,
) -> Unit {
  let mut src = 0
  let src_len = input.length()
  while src < src_len || self.lookahead_size > 0 {
    // Fill the dictionary and insert hash entries for the bytes entering the
    // lookahead. The two branches differ in more than speed: the rolling
    // hash is seeded from two bytes in one and three in the other, depending
    // on how much history exists.
    if self.lookahead_size + self.dict_size >= tdefl_min_match_len - 1 {
      let mut dst_pos = (self.lookahead_pos + self.lookahead_size) &
        tdefl_lz_dict_size_mask
      let mut ins_pos = self.lookahead_pos + self.lookahead_size - 2
      let mut hash = (
          (
            self.dict[ins_pos & tdefl_lz_dict_size_mask].to_int() <<
            tdefl_lz_hash_shift
          ) ^
          self.dict[(ins_pos + 1) & tdefl_lz_dict_size_mask].to_int()
        ) &
        (tdefl_lz_hash_size - 1)
      let remaining = src_len - src
      let room = tdefl_max_match_len - self.lookahead_size
      let take = if remaining < room { remaining } else { room }
      for _ in 0..<take {
        let c = input[src]
        src = src + 1
        self.dict[dst_pos] = c
        if dst_pos < tdefl_max_match_len - 1 {
          self.dict[tdefl_lz_dict_size + dst_pos] = c
        }
        hash = ((hash << tdefl_lz_hash_shift) ^ c.to_int()) &
          (tdefl_lz_hash_size - 1)
        self.next[ins_pos & tdefl_lz_dict_size_mask] = self.hash[hash]
        // positions are stored truncated to 16 bits, as the C keeps them in
        // a mz_uint16
        self.hash[hash] = ins_pos & 0xFFFF
        dst_pos = (dst_pos + 1) & tdefl_lz_dict_size_mask
        ins_pos = ins_pos + 1
      }
      self.lookahead_size = self.lookahead_size + take
    } else {
      while src < src_len && self.lookahead_size < tdefl_max_match_len {
        let c = input[src]
        src = src + 1
        let dst_pos = (self.lookahead_pos + self.lookahead_size) &
          tdefl_lz_dict_size_mask
        self.dict[dst_pos] = c
        if dst_pos < tdefl_max_match_len - 1 {
          self.dict[tdefl_lz_dict_size + dst_pos] = c
        }
        self.lookahead_size = self.lookahead_size + 1
        if self.lookahead_size + self.dict_size >= tdefl_min_match_len {
          let ins_pos = self.lookahead_pos + self.lookahead_size - 1 - 2
          let hash = (
              (
                self.dict[ins_pos & tdefl_lz_dict_size_mask].to_int() <<
                (tdefl_lz_hash_shift * 2)
              ) ^
              (
                self.dict[(ins_pos + 1) & tdefl_lz_dict_size_mask].to_int() <<
                tdefl_lz_hash_shift
              ) ^
              c.to_int()
            ) &
            (tdefl_lz_hash_size - 1)
          self.next[ins_pos & tdefl_lz_dict_size_mask] = self.hash[hash]
          self.hash[hash] = ins_pos & 0xFFFF
        }
      }
    }
    let room = tdefl_lz_dict_size - self.lookahead_size
    self.dict_size = if room < self.dict_size { room } else { self.dict_size }
    // While input remains, wait for a full match length so a match is never
    // cut short by a buffer boundary. At the end there is nothing to wait
    // for, so the lookahead drains.
    if src < src_len && self.lookahead_size < tdefl_max_match_len {
      break
    }
    let mut len_to_move = 1
    let mut cur_match_dist = 0
    let mut cur_match_len = if self.saved_match_len != 0 {
      self.saved_match_len
    } else {
      tdefl_min_match_len - 1
    }
    let cur_pos = self.lookahead_pos & tdefl_lz_dict_size_mask
    if self.dict_size != 0 && !self.force_raw {
      let (found_dist, found_len) = tdefl_find_match(
        self,
        self.lookahead_pos,
        self.dict_size,
        self.lookahead_size,
        cur_match_dist,
        cur_match_len,
      )
      cur_match_dist = found_dist
      cur_match_len = found_len
    }
    // A three-byte match more than 8 KiB away costs more to encode than three
    // literals, and a distance equal to the current position would reference
    // the byte being written.
    if (cur_match_len == tdefl_min_match_len && cur_match_dist >= 8 * 1024) ||
      cur_pos == cur_match_dist {
      cur_match_dist = 0
      cur_match_len = 0
    }
    if self.saved_match_len != 0 {
      if cur_match_len > self.saved_match_len {
        // the deferred match lost: its first byte becomes a literal
        self.record_literal(self.saved_lit.to_byte())
        if cur_match_len >= 128 {
          self.record_match(cur_match_len, cur_match_dist)
          self.saved_match_len = 0
          len_to_move = cur_match_len
        } else {
          self.saved_lit = self.dict[cur_pos].to_int()
          self.saved_match_dist = cur_match_dist
          self.saved_match_len = cur_match_len
        }
      } else {
        self.record_match(self.saved_match_len, self.saved_match_dist)
        len_to_move = self.saved_match_len - 1
        self.saved_match_len = 0
      }
    } else if cur_match_dist == 0 {
      self.record_literal(self.dict[tdefl_dict_index(self.dict, cur_pos)])
    } else if self.greedy_parsing || cur_match_len >= 128 {
      self.record_match(cur_match_len, cur_match_dist)
      len_to_move = cur_match_len
    } else {
      self.saved_lit = self.dict[tdefl_dict_index(self.dict, cur_pos)].to_int()
      self.saved_match_dist = cur_match_dist
      self.saved_match_len = cur_match_len
    }
    self.lookahead_pos = self.lookahead_pos + len_to_move
    self.lookahead_size = self.lookahead_size - len_to_move
    let grown = self.dict_size + len_to_move
    self.dict_size = if grown < tdefl_lz_dict_size {
      grown
    } else {
      tdefl_lz_dict_size
    }
    // Flush when the code buffer is nearly full, or when a large block is
    // compressing badly enough that starting a fresh one is better. The two
    // are recorded separately because they are easy to confuse from outside:
    // literal-heavy input trips the second at 31 KiB, long before the first
    // can happen, so a test aiming at the capacity path needs to know which
    // one it actually reached.
    let out_of_room = self.lz_code_buf_len > tdefl_lz_code_buf_size - 8
    let compressing_badly = self.total_lz_bytes > 31 * 1024 &&
      (
        (self.lz_code_buf_len * 115) >> 7 >= self.total_lz_bytes ||
        self.force_raw
      )
    if out_of_room || compressing_badly {
      if out_of_room {
        self.capacity_flushes = self.capacity_flushes + 1
      }
      self.flush_block(level, false)
    }
  }
}

///|
/// `MZ_MIN(cur_pos, sizeof(d->m_dict) - 1)`, which the C applies at exactly
/// these two reads and nowhere else.
fn tdefl_dict_index(dict : FixedArray[Byte], pos : Int) -> Int {
  if pos < dict.length() - 1 {
    pos
  } else {
    dict.length() - 1
  }
}
