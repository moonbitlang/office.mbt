// A minimal reader and rewriter for the `CFF ` table. CFF fonts are embedded
// as bare CID-keyed CFF programs (`/CIDFontType0C`), like krilla does after
// its subsetter converted them:
//
// - CID-keyed fonts are embedded unchanged; their charset maps glyph IDs to
//   the CIDs that address the glyphs.
// - Name-keyed fonts are converted to CID-keyed fonts with CIDs equal to
//   glyph IDs (a ROS, an identity charset, one Font DICT with the original
//   Private DICT, and the original subroutines and charstrings). Unlike
//   krilla's subsetter, nothing is subset or desubroutinized.

///|
/// An INDEX: the absolute byte ranges of its entries and the end of the
/// INDEX.
fn cff_index(data : Bytes, pos : Int, end : Int) -> (Array[(Int, Int)], Int)? {
  if pos < 0 || pos > end - 2 {
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
    // (Four-byte offsets with the high bit set are negative.)
    let next = read_offset(i)
    if next < prev || next > end - data_start {
      return None
    }
    entries.push((data_start + prev, data_start + next))
    prev = next
  }
  Some((entries, data_start + prev))
}

///|
/// An entry of a DICT: the operator (two-byte operators are `1200 + b1`),
/// its integer operands (reals are read as 0) and its byte range.
priv struct CffDictEntry {
  op : Int
  operands : Array[Int]
  start : Int
  end : Int
}

///|
/// The entries of a DICT.
fn cff_dict(data : Bytes, start : Int, end : Int) -> Array[CffDictEntry]? {
  let out = []
  let operands = []
  let mut entry_start = start
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
      pos += 1
      out.push(CffDictEntry::{
        op,
        operands: operands.copy(),
        start: entry_start,
        end: pos,
      })
      operands.clear()
      entry_start = pos
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
      // A real number: nibbles up to 0xF.
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
/// The operands of a DICT operator.
fn cff_operands(dict : Array[CffDictEntry], op : Int) -> Array[Int]? {
  for e in dict {
    if e.op == op {
      return Some(e.operands)
    }
  }
  None
}

///|
/// The parts of a CFF table (absolute byte ranges in the font file).
priv struct CffTable {
  start : Int
  end : Int
  /// The Name INDEX.
  names : (Int, Int)
  /// The Top DICT.
  top : Array[CffDictEntry]
  /// The entries of the String INDEX.
  strings : Array[(Int, Int)]
  /// The Global Subr INDEX.
  global_subrs : (Int, Int)
  /// The CharStrings INDEX.
  charstrings : (Int, Int)
  num_glyphs : Int
}

///|
/// Read the structure of the CFF table at `start` (`None` if it is
/// malformed).
fn cff_table(data : Bytes, start : Int, length : Int) -> CffTable? {
  let end = start + length
  if length < 4 {
    return None
  }
  let names_start = start + data[start + 2].to_int()
  guard cff_index(data, names_start, end) is Some((_, names_end)) else {
    return None
  }
  guard cff_index(data, names_end, end) is Some((top_dicts, top_end)) else {
    return None
  }
  guard top_dicts.get(0) is Some((dict_start, dict_end)) else { return None }
  guard cff_dict(data, dict_start, dict_end) is Some(top) else { return None }
  guard cff_index(data, top_end, end) is Some((strings, strings_end)) else {
    return None
  }
  guard cff_index(data, strings_end, end) is Some((_, gsubrs_end)) else {
    return None
  }
  guard cff_operands(top, 17) is Some([charstrings]) &&
    charstrings > 0 &&
    charstrings < length else {
    return None
  }
  guard cff_index(data, start + charstrings, end) is Some((glyphs, glyphs_end)) else {
    return None
  }
  if glyphs.is_empty() {
    return None
  }
  Some({
    start,
    end,
    names: (names_start, names_end),
    top,
    strings,
    global_subrs: (strings_end, gsubrs_end),
    charstrings: (start + charstrings, glyphs_end),
    num_glyphs: glyphs.length(),
  })
}

///|
/// Whether the font is CID-keyed (has the ROS operator).
fn CffTable::is_cid_keyed(self : CffTable) -> Bool {
  cff_operands(self.top, 1230) is Some(_)
}

///|
/// The CID of each glyph of a CID-keyed font, from its charset.
fn CffTable::cids(self : CffTable, data : Bytes) -> Array[Int]? {
  guard cff_operands(self.top, 15) is Some([charset]) &&
    charset > 2 &&
    charset < self.end - self.start else {
    return None
  }
  let end = self.end
  let mut pos = self.start + charset
  let format = data[pos].to_int()
  pos += 1
  let cids = [0]
  match format {
    0 =>
      while cids.length() < self.num_glyphs {
        if pos + 2 > end {
          return None
        }
        cids.push(rd_u16(data, pos))
        pos += 2
      }
    1 | 2 => {
      let range_size = if format == 1 { 3 } else { 4 }
      while cids.length() < self.num_glyphs {
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
          if cids.length() < self.num_glyphs {
            cids.push(first + k)
          }
        }
      }
    }
    _ => return None
  }
  Some(cids)
}

///|
fn cff_push_u16(out : Array[Byte], v : Int) -> Unit {
  out.push(((v >> 8) & 0xFF).to_byte())
  out.push((v & 0xFF).to_byte())
}

///|
/// An operand that always takes five bytes.
fn cff_push_int32(out : Array[Byte], v : Int) -> Unit {
  out.push(b'\x1D')
  out.push(((v >> 24) & 0xFF).to_byte())
  out.push(((v >> 16) & 0xFF).to_byte())
  out.push(((v >> 8) & 0xFF).to_byte())
  out.push((v & 0xFF).to_byte())
}

///|
fn cff_push_op(out : Array[Byte], op : Int) -> Unit {
  if op >= 1200 {
    out.push(b'\x0C')
    out.push((op - 1200).to_byte())
  } else {
    out.push(op.to_byte())
  }
}

///|
fn cff_push_range(out : Array[Byte], data : Bytes, range : (Int, Int)) -> Unit {
  for i in range.0..<range.1 {
    out.push(data[i])
  }
}

///|
/// An INDEX with four-byte offsets.
fn cff_push_index(out : Array[Byte], items : Array[Bytes]) -> Unit {
  cff_push_u16(out, items.length())
  if items.is_empty() {
    return
  }
  out.push(b'\x04')
  let push_u32 = (v : Int) => {
    cff_push_u16(out, (v >> 16) & 0xFFFF)
    cff_push_u16(out, v & 0xFFFF)
  }
  let mut offset = 1
  push_u32(offset)
  for item in items {
    offset += item.length()
    push_u32(offset)
  }
  for item in items {
    for b in item {
      out.push(b)
    }
  }
}

///|
/// Convert a name-keyed CFF font into a CID-keyed one with CIDs equal to
/// glyph IDs (`None` if the font is malformed).
fn CffTable::to_cid_keyed(self : CffTable, data : Bytes) -> Bytes? {
  // The Private DICT and the local subroutines following it are copied as
  // one block, which keeps the relative offset of the subroutines valid.
  guard cff_operands(self.top, 18) is Some([private_size, private_offset]) &&
    private_size >= 0 &&
    private_offset > 0 &&
    private_offset <= self.end - self.start - private_size else {
    return None
  }
  let private_start = self.start + private_offset
  let private_end = private_start + private_size
  guard cff_dict(data, private_start, private_end) is Some(private_dict) else {
    return None
  }
  let mut block_end = private_end
  if cff_operands(private_dict, 19) is Some([subrs]) {
    guard subrs > 0 &&
      cff_index(data, private_start + subrs, self.end) is Some((_, subrs_end)) else {
      return None
    }
    if subrs_end > block_end {
      block_end = subrs_end
    }
  }
  let n = self.num_glyphs
  let num_strings = self.strings.length()
  // The original Top DICT entries, except those that point to data or are
  // replaced.
  let mut font_matrix = None
  let kept : Array[Byte] = []
  for e in self.top {
    match e.op {
      15 | 16 | 17 | 18 => ()
      1207 => font_matrix = Some((e.start, e.end))
      _ => cff_push_range(kept, data, (e.start, e.end))
    }
  }
  // The Top DICT: ROS first, then the kept entries, the FontMatrix (the
  // Font DICT gets an identity matrix) and the offsets. It has the same
  // size for all offsets.
  let build_top = (charset : Int, fd_select : Int, fd_array : Int, cs : Int) => {
    let top : Array[Byte] = []
    // Registry "Adobe" and ordering "Identity" are appended to the strings.
    // (32-bit operands: SIDs can exceed the 16-bit operand range.)
    for sid in [391 + num_strings, 392 + num_strings] {
      cff_push_int32(top, sid)
    }
    top.push(b'\x8B') // supplement 0
    cff_push_op(top, 1230)
    for b in kept {
      top.push(b)
    }
    match font_matrix {
      Some(range) => cff_push_range(top, data, range)
      None => {
        // [0.001 0 0 0.001 0 0]
        let thousandth = [b'\x1E', b'\x0A', b'\x00', b'\x1F']
        for b in thousandth {
          top.push(b)
        }
        top.push(b'\x8B')
        top.push(b'\x8B')
        for b in thousandth {
          top.push(b)
        }
        top.push(b'\x8B')
        top.push(b'\x8B')
        cff_push_op(top, 1207)
      }
    }
    cff_push_int32(top, n)
    cff_push_op(top, 1234) // CIDCount
    cff_push_int32(top, charset)
    cff_push_op(top, 15)
    cff_push_int32(top, cs)
    cff_push_op(top, 17)
    cff_push_int32(top, fd_array)
    cff_push_op(top, 1236)
    cff_push_int32(top, fd_select)
    cff_push_op(top, 1237)
    Bytes::from_array(top)
  }
  let strings : Array[Bytes] = self.strings.map(r => data[r.0:r.1].to_owned())
  strings.push(b"Adobe")
  strings.push(b"Identity")
  let head : Array[Byte] = [b'\x01', b'\x00', b'\x04', b'\x04']
  cff_push_range(head, data, self.names)
  let top_size = {
    let index : Array[Byte] = []
    cff_push_index(index, [build_top(0, 0, 0, 0)])
    index.length()
  }
  let rest : Array[Byte] = []
  cff_push_index(rest, strings)
  cff_push_range(rest, data, self.global_subrs)
  let charset_at = head.length() + top_size + rest.length()
  // An identity charset (format 2: one range of CIDs 1..n-1).
  let charset : Array[Byte] = [b'\x02']
  if n > 1 {
    cff_push_u16(charset, 1)
    cff_push_u16(charset, n - 2)
  }
  let fd_select_at = charset_at + charset.length()
  // FDSelect format 3: all glyphs use Font DICT 0.
  let fd_select : Array[Byte] = [b'\x03']
  cff_push_u16(fd_select, 1)
  cff_push_u16(fd_select, 0)
  fd_select.push(b'\x00')
  cff_push_u16(fd_select, n)
  let fd_array_at = fd_select_at + fd_select.length()
  // The Font DICT: an identity FontMatrix and the Private DICT (whose
  // offset depends on the size of the FDArray, which doesn't depend on it).
  let font_dict = (private_at : Int) => {
    let d : Array[Byte] = [b'\x8C', b'\x8B', b'\x8B', b'\x8C', b'\x8B', b'\x8B']
    cff_push_op(d, 1207)
    cff_push_int32(d, private_size)
    cff_push_int32(d, private_at)
    cff_push_op(d, 18)
    let index : Array[Byte] = []
    cff_push_index(index, [Bytes::from_array(d)])
    index
  }
  let private_at = fd_array_at + font_dict(0).length()
  let charstrings_at = private_at + (block_end - private_start)
  let out : Array[Byte] = []
  for b in head {
    out.push(b)
  }
  cff_push_index(out, [
    build_top(charset_at, fd_select_at, fd_array_at, charstrings_at),
  ])
  for part in [rest, charset, fd_select, font_dict(private_at)] {
    for b in part {
      out.push(b)
    }
  }
  cff_push_range(out, data, (private_start, block_end))
  cff_push_range(out, data, self.charstrings)
  Some(Bytes::from_array(out))
}

///|
/// The charstrings and subroutines of a name-keyed font.
priv struct CffPrograms {
  charstrings : Array[(Int, Int)]
  global_subrs : Array[(Int, Int)]
  local_subrs : Array[(Int, Int)]
}

///|
fn CffTable::programs(self : CffTable, data : Bytes) -> CffPrograms? {
  guard cff_index(data, self.charstrings.0, self.end) is Some((charstrings, _)) else {
    return None
  }
  guard cff_index(data, self.global_subrs.0, self.end)
    is Some((global_subrs, _)) else {
    return None
  }
  let mut local_subrs = []
  if cff_operands(self.top, 18) is Some([size, offset]) &&
    size >= 0 &&
    offset > 0 &&
    offset <= self.end - self.start - size {
    let private_start = self.start + offset
    guard cff_dict(data, private_start, private_start + size) is Some(private) else {
      return None
    }
    if cff_operands(private, 19) is Some([subrs]) {
      guard subrs > 0 &&
        cff_index(data, private_start + subrs, self.end) is Some((l, _)) else {
        return None
      }
      local_subrs = l
    }
  }
  Some({ charstrings, global_subrs, local_subrs, })
}

///|
/// The subroutine bias of a Type 2 charstring INDEX.
fn cff_subr_bias(count : Int) -> Int {
  if count < 1240 {
    107
  } else if count < 33900 {
    1131
  } else {
    32768
  }
}

///|
/// Whether the charstring of a glyph uses the deprecated `seac` form of
/// `endchar` (accented characters composed by StandardEncoding codes, which
/// can't be resolved once the font is CID-keyed); `None` if the charstring
/// is malformed. krilla's subsetter rejects these glyphs.
fn CffPrograms::uses_seac(
  self : CffPrograms,
  data : Bytes,
  glyph : Int,
) -> Bool? {
  guard self.charstrings.get(glyph) is Some(program) else { return None }
  let stack : Array[Int] = []
  let hints = Ref::{ val: 0, }
  // 0: returned, 1: endchar, 2: seac, -1: malformed.
  fn run(range : (Int, Int), depth : Int) -> Int {
    if depth > 10 {
      return -1
    }
    let mut pos = range.0
    while pos < range.1 {
      let b0 = data[pos].to_int()
      if b0 >= 32 && b0 <= 246 {
        stack.push(b0 - 139)
        pos += 1
      } else if b0 >= 247 && b0 <= 254 {
        if pos + 2 > range.1 {
          return -1
        }
        let b1 = data[pos + 1].to_int()
        stack.push(
          if b0 <= 250 {
            (b0 - 247) * 256 + b1 + 108
          } else {
            -(b0 - 251) * 256 - b1 - 108
          },
        )
        pos += 2
      } else if b0 == 28 {
        if pos + 3 > range.1 {
          return -1
        }
        stack.push(rd_i16(data, pos + 1))
        pos += 3
      } else if b0 == 255 {
        // A 16.16 fixed-point number (its integer part).
        if pos + 5 > range.1 {
          return -1
        }
        stack.push(rd_u32(data, pos + 1) >> 16)
        pos += 5
      } else {
        pos += 1
        match b0 {
          10 | 29 => {
            guard stack.pop() is Some(index) else { return -1 }
            let subrs = if b0 == 10 {
              self.local_subrs
            } else {
              self.global_subrs
            }
            guard subrs.get(index + cff_subr_bias(subrs.length())) is Some(subr) else {
              return -1
            }
            let r = run(subr, depth + 1)
            if r != 0 {
              return r
            }
          }
          11 => return 0
          14 => return if stack.length() >= 4 { 2 } else { 1 }
          1 | 3 | 18 | 23 => {
            hints.val += stack.length() / 2
            stack.clear()
          }
          19 | 20 => {
            hints.val += stack.length() / 2
            stack.clear()
            pos += (hints.val + 7) / 8
          }
          12 => {
            pos += 1
            stack.clear()
          }
          _ => stack.clear()
        }
      }
    }
    0
  }
  match run(program, 0) {
    2 => Some(true)
    -1 => None
    _ => Some(false)
  }
}
