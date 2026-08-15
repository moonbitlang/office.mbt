///|
// The LZ77 match search, ported from miniz's portable `tdefl_find_match`.
//
// Three details here decide which matches are found, and all three look like
// things a careful rewrite would tidy up:
//
//   * `dist` is a 16-bit truncation of an unsigned subtraction. Widening it
//     changes which candidates pass the `max_dist` test near the window wrap.
//   * `dict[probe_pos + match_len]` is read without masking. The dictionary is
//     oversized by `max_match_len - 1` and its tail mirrors the head precisely
//     so this read is in bounds; masking the index instead would compare
//     against the wrong byte.
//   * the probe budget is decremented once per *three* probes, because the C
//     unrolls `TDEFL_PROBE` three times inside the counting loop. A natural
//     one-probe-per-iteration rewrite searches a third as far and picks
//     different matches.
//
// None of the three would fail a round-trip test. All three change the bytes.

///|
/// Best match at `lookahead_pos`, given a match already `match_len` long.
///
/// Returns the improved `(distance, length)`, or the pair it was given when
/// nothing better is found.
fn tdefl_find_match(
  state : TdeflState,
  lookahead_pos : Int,
  max_dist : Int,
  max_match_len : Int,
  match_dist_in : Int,
  match_len_in : Int,
) -> (Int, Int) {
  let pos = lookahead_pos & tdefl_lz_dict_size_mask
  let mut match_len = match_len_in
  let mut match_dist = match_dist_in
  if max_match_len <= match_len {
    return (match_dist, match_len)
  }
  let dict = state.dict
  let mut probe_pos = pos
  // the two bytes just past the current match; a candidate that fails to
  // match these cannot improve on it, which is the cheap rejection that makes
  // the chain walk affordable
  let mut c0 = dict[pos + match_len]
  let mut c1 = dict[pos + match_len - 1]
  let mut num_probes_left = state.max_probes[if match_len >= 32 { 1 } else { 0 }]
  let mut dist = 0
  for {
    // walk the hash chain until a candidate agrees on c0/c1, or the budget
    // or the window runs out
    let mut candidate = false
    while not(candidate) {
      num_probes_left = num_probes_left - 1
      if num_probes_left == 0 {
        return (match_dist, match_len)
      }
      let mut probe = 0
      // three probes per budget decrement, exactly as the C unrolls them
      while probe < 3 {
        let next_probe_pos = state.next[probe_pos]
        if next_probe_pos == 0 {
          return (match_dist, match_len)
        }
        dist = (lookahead_pos - next_probe_pos) & 0xFFFF
        if dist > max_dist {
          return (match_dist, match_len)
        }
        probe_pos = next_probe_pos & tdefl_lz_dict_size_mask
        if dict[probe_pos + match_len] == c0 &&
          dict[probe_pos + match_len - 1] == c1 {
          candidate = true
          break
        }
        probe = probe + 1
      }
    }
    if dist == 0 {
      break
    }
    let mut probe_len = 0
    while probe_len < max_match_len {
      if dict[pos + probe_len] != dict[probe_pos + probe_len] {
        break
      }
      probe_len = probe_len + 1
    }
    if probe_len > match_len {
      match_dist = dist
      match_len = probe_len
      if match_len == max_match_len {
        return (match_dist, match_len)
      }
      c0 = dict[pos + match_len]
      c1 = dict[pos + match_len - 1]
    }
  }
  (match_dist, match_len)
}
