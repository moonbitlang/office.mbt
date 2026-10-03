// Port of read-fonts 0.39.2 `src/ps/cff/fd_select.rs` and the FDSelect
// tables from `generated/generated_cff.rs`.

///|
/// Maps glyph identifiers to font DICT indices.
pub enum FdSelect {
  /// One byte per glyph.
  Format0(BytesView)
  /// Ranges of (u16 first, u8 fd).
  Format3(BytesView)
  /// Ranges of (u32 first, u16 fd).
  Format4(BytesView)
}

///|
pub fn FdSelect::read(data : BytesView) -> FdSelect raise PsError {
  let format = read_u8_at(data, 0)
  match format {
    0 => Format0(data[1:])
    3 => {
      // MIN_SIZE: format + n_ranges + sentinel
      if data.length() < 5 {
        raise oob()
      }
      let n_ranges = read_u16_at(data, 1)
      Format3(get_range(data, 3, 3 + n_ranges * 3).unwrap_or(b""))
    }
    4 => {
      if data.length() < 9 {
        raise oob()
      }
      let n_ranges = read_u32_at(data, 1)
      let len = n_ranges.to_int64() * 6L
      if n_ranges < 0 || len > 2147483647L {
        Format4(b"")
      } else {
        Format4(get_range(data, 5, 5 + len.to_int()).unwrap_or(b""))
      }
    }
    other => raise Read(@read_fonts.ReadError::InvalidFormat(other.to_int64()))
  }
}

///|
/// Returns the associated font DICT index for the given glyph identifier.
pub fn FdSelect::font_index(self : FdSelect, glyph_id : GlyphId) -> Int? {
  let gid = glyph_id.to_u32()
  match self {
    Format0(fds) =>
      if gid < fds.length().reinterpret_as_uint() {
        Some(fds[gid.reinterpret_as_int()].to_int())
      } else {
        None
      }
    Format3(ranges) => {
      let n = ranges.length() / 3
      let first = fn(i : Int) {
        ((ranges[i * 3].to_int() << 8) | ranges[i * 3 + 1].to_int()).reinterpret_as_uint()
      }
      let ix = binary_search_ix(n, first, gid)
      if ix < n {
        Some(ranges[ix * 3 + 2].to_int())
      } else {
        None
      }
    }
    Format4(ranges) => {
      let n = ranges.length() / 6
      let first = fn(i : Int) {
        let p = i * 6
        ((ranges[p].to_int() << 24) |
        (ranges[p + 1].to_int() << 16) |
        (ranges[p + 2].to_int() << 8) |
        ranges[p + 3].to_int()).reinterpret_as_uint()
      }
      let ix = binary_search_ix(n, first, gid)
      if ix < n {
        Some((ranges[ix * 6 + 4].to_int() << 8) | ranges[ix * 6 + 5].to_int())
      } else {
        None
      }
    }
  }
}

///|
/// Rust `slice::binary_search_by(|range| range.first().cmp(&gid))` followed
/// by `Ok(ix) => ix, Err(ix) => ix.saturating_sub(1)`.
fn binary_search_ix(n : Int, first : (Int) -> UInt, gid : UInt) -> Int {
  // Mirrors the std implementation (which may return any matching index
  // when there are duplicates).
  let mut size = n
  if size == 0 {
    return 0
  }
  let mut base = 0
  while size > 1 {
    let half = size / 2
    let mid = base + half
    // cmp == Greater -> keep base
    base = if first(mid) > gid { base } else { mid }
    size -= half
  }
  let f = first(base)
  if f == gid {
    base
  } else {
    let ix = base + (if f < gid { 1 } else { 0 })
    if ix > 0 {
      ix - 1
    } else {
      0
    }
  }
}
