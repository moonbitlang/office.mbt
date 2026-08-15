///|
// miniz's tdefl Huffman table construction, ported to MoonBit.
//
// This is the part of the compressor where "equivalent" is not good enough.
// Any correct Huffman builder produces a valid deflate stream, and only this
// one produces miniz's bytes, so every tie-break here is load-bearing:
// symbols are ordered by a *stable* radix sort on frequency, code lengths come
// from Moffat-Katajainen rather than from a heap, and over-long codes are
// shortened by a specific repair loop. Substituting a textbook implementation
// would pass every round-trip test and fail the only test that matters.

///|
/// The longest code length the builder tracks before enforcing a limit.
let tdefl_max_supported_huff_codesize : Int = 32

///|
/// One symbol and its frequency, which the algorithm below reuses as one
/// symbol and its code length. The reuse is miniz's, not an economy added
/// here: `m_key` is a frequency on the way in, a parent pointer in the middle,
/// and a code length on the way out.
priv struct TdeflSymFreq {
  mut key : Int
  sym_index : Int
}

///|
/// Stable two-pass radix sort on the 16-bit key.
///
/// Stability is the whole point. Two symbols of equal frequency have to come
/// out in the order they went in, because the code lengths assigned next
/// depend on that order, and so do the codes, and so do the bytes.
///
/// Returns the array holding the sorted result, which alternates between the
/// two buffers exactly as the C does -- including its early exit when the
/// high byte carries no information, which changes the number of passes and
/// therefore which buffer the answer lands in.
fn tdefl_radix_sort_syms(
  num_syms : Int,
  syms0 : FixedArray[TdeflSymFreq],
  syms1 : FixedArray[TdeflSymFreq],
) -> FixedArray[TdeflSymFreq] {
  let hist = FixedArray::make(256 * 2, 0)
  for i in 0..<num_syms {
    let freq = syms0[i].key
    hist[freq & 0xFF] = hist[freq & 0xFF] + 1
    hist[256 + ((freq >> 8) & 0xFF)] = hist[256 + ((freq >> 8) & 0xFF)] + 1
  }
  let mut total_passes = 2
  while total_passes > 1 && num_syms == hist[(total_passes - 1) * 256] {
    total_passes = total_passes - 1
  }
  let mut cur = syms0
  let mut new_syms = syms1
  let mut pass_shift = 0
  for pass in 0..<total_passes {
    let offsets = FixedArray::make(256, 0)
    let mut cur_ofs = 0
    for i in 0..<256 {
      offsets[i] = cur_ofs
      cur_ofs = cur_ofs + hist[(pass << 8) + i]
    }
    for i in 0..<num_syms {
      let bucket = (cur[i].key >> pass_shift) & 0xFF
      new_syms[offsets[bucket]] = cur[i]
      offsets[bucket] = offsets[bucket] + 1
    }
    let swap = cur
    cur = new_syms
    new_syms = swap
    pass_shift = pass_shift + 8
  }
  cur
}

///|
/// Moffat and Katajainen's in-place minimum-redundancy code lengths.
///
/// `a` arrives sorted by ascending frequency and leaves holding code lengths.
/// The three phases overwrite the same field in turn -- frequencies become
/// parent indices become depths -- which is why this reads as index
/// arithmetic rather than as tree building. It is transcribed rather than
/// rewritten for exactly that reason.
fn tdefl_calculate_minimum_redundancy(
  a : FixedArray[TdeflSymFreq],
  n : Int,
) -> Unit {
  if n == 0 {
    return
  }
  if n == 1 {
    a[0].key = 1
    return
  }
  // every assignment to m_key in the C lands in a mz_uint16, so each one
  // truncates. Dropping that here does not merely widen a number: the
  // wrapped value is what the next phase reads as a parent index.
  a[0].key = (a[0].key + a[1].key) & 0xFFFF
  let mut root = 0
  let mut leaf = 2
  for next in 1..<(n - 1) {
    if leaf >= n || a[root].key < a[leaf].key {
      a[next].key = a[root].key
      a[root].key = next
      root = root + 1
    } else {
      a[next].key = a[leaf].key
      leaf = leaf + 1
    }
    if leaf >= n || (root < next && a[root].key < a[leaf].key) {
      a[next].key = (a[next].key + a[root].key) & 0xFFFF
      a[root].key = next
      root = root + 1
    } else {
      a[next].key = (a[next].key + a[leaf].key) & 0xFFFF
      leaf = leaf + 1
    }
  }
  a[n - 2].key = 0
  for next = n - 3; next >= 0; next = next - 1 {
    a[next].key = (a[a[next].key].key + 1) & 0xFFFF
  }
  let mut avbl = 1
  let mut used = 0
  let mut dpth = 0
  let mut root2 = n - 2
  let mut next2 = n - 1
  while avbl > 0 {
    while root2 >= 0 && a[root2].key == dpth {
      used = used + 1
      root2 = root2 - 1
    }
    while avbl > used {
      a[next2].key = dpth
      next2 = next2 - 1
      avbl = avbl - 1
    }
    avbl = 2 * used
    dpth = dpth + 1
    used = 0
  }
}

///|
/// Shorten codes longer than `max_code_size` by moving length budget around
/// until the Kraft sum is exactly 2^max_code_size again.
fn tdefl_huffman_enforce_max_code_size(
  num_codes : FixedArray[Int],
  code_list_len : Int,
  max_code_size : Int,
) -> Unit {
  if code_list_len <= 1 {
    return
  }
  for i in (max_code_size + 1)..<=tdefl_max_supported_huff_codesize {
    num_codes[max_code_size] = num_codes[max_code_size] + num_codes[i]
  }
  let mut total = 0L
  for i = max_code_size; i > 0; i = i - 1 {
    total = total + (num_codes[i].to_int64() << (max_code_size - i))
  }
  while total != 1L << max_code_size {
    num_codes[max_code_size] = num_codes[max_code_size] - 1
    for i = max_code_size - 1; i > 0; i = i - 1 {
      if num_codes[i] != 0 {
        num_codes[i] = num_codes[i] - 1
        num_codes[i + 1] = num_codes[i + 1] + 2
        break
      }
    }
    total = total - 1L
  }
}

///|
/// Code length per symbol for `freqs`, limited to `code_size_limit` bits.
///
/// This is the non-static half of miniz's `tdefl_optimize_huffman_table`,
/// separated so it can be compared against the C directly. The assignment
/// walks the sorted symbols backwards while walking lengths forwards, which
/// is what makes the tie-break visible: three symbols of equal frequency come
/// out 2, 2, 1 rather than symmetric, and any builder that disagrees produces
/// a different stream.
fn tdefl_code_sizes(
  freqs : ArrayView[Int],
  code_size_limit : Int,
) -> FixedArray[Int] {
  let table_len = freqs.length()
  let sizes = FixedArray::make(table_len, 0)
  let syms0 = FixedArray::make(table_len, { key: 0, sym_index: 0 })
  let syms1 = FixedArray::make(table_len, { key: 0, sym_index: 0 })
  for i in 0..<table_len {
    syms0[i] = { key: 0, sym_index: 0 }
    syms1[i] = { key: 0, sym_index: 0 }
  }
  let mut used = 0
  for i in 0..<table_len {
    if freqs[i] != 0 {
      syms0[used] = { key: freqs[i], sym_index: i }
      used = used + 1
    }
  }
  if used == 0 {
    return sizes
  }
  let sorted = tdefl_radix_sort_syms(used, syms0, syms1)
  tdefl_calculate_minimum_redundancy(sorted, used)
  let num_codes = FixedArray::make(1 + tdefl_max_supported_huff_codesize, 0)
  for i in 0..<used {
    num_codes[sorted[i].key] = num_codes[sorted[i].key] + 1
  }
  tdefl_huffman_enforce_max_code_size(num_codes, used, code_size_limit)
  let mut k = used
  for i in 1..<=code_size_limit {
    for _ in 0..<num_codes[i] {
      k = k - 1
      sizes[sorted[k].sym_index] = i
    }
  }
  sizes
}

///|
/// Build one Huffman table in `state`: code lengths, then canonical codes.
///
/// `static_table` takes the lengths already in `huff_code_sizes` rather than
/// deriving them from counts, which is how the fixed-block tables are set up.
///
/// Codes come out **bit-reversed**. Deflate writes Huffman codes most
/// significant bit first while the bit writer emits least significant bit
/// first, so reversing here is what makes a single `put_bits` correct for both
/// codes and the LSB-first extra bits that follow them.
fn TdeflState::optimize_huffman_table(
  self : TdeflState,
  table_num : Int,
  table_len : Int,
  code_size_limit : Int,
  static_table : Bool,
) -> Unit {
  let num_codes = FixedArray::make(1 + tdefl_max_supported_huff_codesize, 0)
  if static_table {
    for i in 0..<table_len {
      let size = self.huff_code_sizes[table_num][i]
      num_codes[size] = num_codes[size] + 1
    }
  } else {
    let counts = self.huff_count[table_num]
    let syms0 = FixedArray::makei(table_len, _ => { key: 0, sym_index: 0 })
    let syms1 = FixedArray::makei(table_len, _ => { key: 0, sym_index: 0 })
    let mut used = 0
    for i in 0..<table_len {
      if counts[i] != 0 {
        syms0[used] = { key: counts[i], sym_index: i }
        used = used + 1
      }
    }
    let sorted = tdefl_radix_sort_syms(used, syms0, syms1)
    tdefl_calculate_minimum_redundancy(sorted, used)
    for i in 0..<used {
      num_codes[sorted[i].key] = num_codes[sorted[i].key] + 1
    }
    tdefl_huffman_enforce_max_code_size(num_codes, used, code_size_limit)
    for i in 0..<tdefl_max_huff_symbols_0 {
      self.huff_code_sizes[table_num][i] = 0
      self.huff_codes[table_num][i] = 0
    }
    let mut j = used
    for i in 1..<=code_size_limit {
      for _ in 0..<num_codes[i] {
        j = j - 1
        self.huff_code_sizes[table_num][sorted[j].sym_index] = i
      }
    }
  }
  let next_code = FixedArray::make(tdefl_max_supported_huff_codesize + 1, 0)
  next_code[1] = 0
  let mut j = 0
  for i in 2..<=code_size_limit {
    j = (j + num_codes[i - 1]) << 1
    next_code[i] = j
  }
  for i in 0..<table_len {
    let code_size = self.huff_code_sizes[table_num][i]
    if code_size == 0 {
      continue
    }
    let mut code = next_code[code_size]
    next_code[code_size] = code + 1
    let mut rev_code = 0
    for _ in 0..<code_size {
      rev_code = (rev_code << 1) | (code & 1)
      code = code >> 1
    }
    self.huff_codes[table_num][i] = rev_code & 0xFFFF
  }
}
