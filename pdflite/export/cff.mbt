// A minimal reader for the `CFF ` table: the font is embedded unchanged, but
// for CID-keyed fonts the charset (which maps glyph IDs to CIDs) is needed to
// address glyphs by CID. (krilla avoids this by subsetting the font, which
// makes the CIDs equal to the new glyph IDs.)

///|
/// An INDEX: the absolute byte ranges of its entries and the end of the
/// INDEX.
fn cff_index(data : Bytes, pos : Int, end : Int) -> (Array[(Int, Int)], Int)? {
  if pos < 0 || pos + 2 > end {
    return None
  }
  let count = rd_u16(data, pos)
  if count == 0 {
    return Some(([], pos + 2))
  }
  if pos + 3 > end {
    return None
  }
  let off_size = data[pos + 2].to_int()
  if off_size < 1 || off_size > 4 {
    return None
  }
  let offsets_at = pos + 3
  // Offsets are 1-based relative to the byte before the data.
  let data_start = offsets_at + (count + 1) * off_size - 1
  if data_start + 1 > end {
    return None
  }
  let read_offset = (i : Int) => {
    let mut v = 0
    for k in 0..<off_size {
      v = (v << 8) | data[offsets_at + i * off_size + k].to_int()
    }
    v
  }
  let entries = []
  let mut prev = read_offset(0)
  if prev != 1 {
    return None
  }
  for i in 1..<=count {
    let next = read_offset(i)
    if next < prev || data_start + next > end {
      return None
    }
    entries.push((data_start + prev, data_start + next))
    prev = next
  }
  Some((entries, data_start + prev))
}

///|
/// The operators of a Top DICT with their operands (two-byte operators are
/// `1200 + b1`).
fn cff_dict(data : Bytes, start : Int, end : Int) -> Map[Int, Array[Int]]? {
  let out : Map[Int, Array[Int]] = Map([])
  let operands = []
  let mut pos = start
  while pos < end {
    let b0 = data[pos].to_int()
    if b0 <= 21 {
      let op = if b0 == 12 {
        if pos + 1 >= end {
          return None
        }
        pos += 1
        1200 + data[pos].to_int()
      } else {
        b0
      }
      out[op] = operands.copy()
      operands.clear()
      pos += 1
    } else if b0 == 28 {
      if pos + 3 > end {
        return None
      }
      operands.push(rd_i16(data, pos + 1))
      pos += 3
    } else if b0 == 29 {
      if pos + 5 > end {
        return None
      }
      operands.push(rd_u32(data, pos + 1))
      pos += 5
    } else if b0 == 30 {
      // A real number (only its presence matters here): nibbles up to 0xF.
      pos += 1
      while true {
        if pos >= end {
          return None
        }
        let b = data[pos].to_int()
        pos += 1
        if (b & 0xF) == 0xF || b >> 4 == 0xF {
          break
        }
      }
      operands.push(0)
    } else if b0 >= 32 && b0 <= 246 {
      operands.push(b0 - 139)
      pos += 1
    } else if b0 >= 247 && b0 <= 254 {
      if pos + 2 > end {
        return None
      }
      let b1 = data[pos + 1].to_int()
      operands.push(
        if b0 <= 250 {
          (b0 - 247) * 256 + b1 + 108
        } else {
          -(b0 - 251) * 256 - b1 - 108
        },
      )
      pos += 2
    } else {
      return None
    }
  }
  Some(out)
}

///|
/// The kind of a CFF font.
priv enum CffKeying {
  /// A name-keyed font: CIDs are glyph IDs.
  NameKeyed
  /// A CID-keyed font with the CID of each glyph.
  CidKeyed(Array[Int])
}

///|
/// Read the keying of the CFF table at `start` (`None` if it is malformed).
fn cff_keying(data : Bytes, start : Int, length : Int) -> CffKeying? {
  let end = start + length
  if length < 4 {
    return None
  }
  let header_size = data[start + 2].to_int()
  guard cff_index(data, start + header_size, end) is Some((_, after_names)) else {
    return None
  }
  guard cff_index(data, after_names, end) is Some((top_dicts, _)) else {
    return None
  }
  guard top_dicts.get(0) is Some((dict_start, dict_end)) else { return None }
  guard cff_dict(data, dict_start, dict_end) is Some(top) else { return None }
  // The ROS operator marks CID-keyed fonts.
  if !top.contains(1230) {
    return Some(NameKeyed)
  }
  guard top.get(17) is Some([charstrings]) else { return None }
  guard cff_index(data, start + charstrings, end) is Some((glyphs, _)) else {
    return None
  }
  let num_glyphs = glyphs.length()
  guard top.get(15) is Some([charset]) && charset > 2 else { return None }
  let mut pos = start + charset
  if pos >= end || num_glyphs == 0 {
    return None
  }
  let format = data[pos].to_int()
  pos += 1
  let cids = [0]
  match format {
    0 =>
      while cids.length() < num_glyphs {
        if pos + 2 > end {
          return None
        }
        cids.push(rd_u16(data, pos))
        pos += 2
      }
    1 | 2 => {
      let range_size = if format == 1 { 3 } else { 4 }
      while cids.length() < num_glyphs {
        if pos + range_size > end {
          return None
        }
        let first = rd_u16(data, pos)
        let n_left = if format == 1 {
          data[pos + 2].to_int()
        } else {
          rd_u16(data, pos + 2)
        }
        pos += range_size
        for k in 0..<=n_left {
          if cids.length() < num_glyphs {
            cids.push(first + k)
          }
        }
      }
    }
    _ => return None
  }
  Some(CidKeyed(cids))
}
