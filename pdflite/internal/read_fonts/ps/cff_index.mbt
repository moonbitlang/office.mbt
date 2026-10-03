// Port of read-fonts 0.39.2 `src/ps/cff/index.rs` and the CFF `Index`
// table from `generated/generated_cff.rs` and `generated_cff2.rs`.

///|
/// A CFF (version 1) INDEX, or with `count_size` 4 a CFF2 INDEX
/// (upstream `Index2`).
pub struct Index1 {
  data : BytesView
  count_size : Int
}

///|
/// Reads an INDEX header (requires at least 3 bytes, like the generated
/// `FontRead` impl).
pub fn Index1::read(data : BytesView) -> Index1 raise PsError {
  if data.length() < 3 {
    raise oob()
  }
  { data, count_size: 2, }
}

///|
/// Reads a CFF2 INDEX header (requires at least 5 bytes).
pub fn Index1::read2(data : BytesView) -> Index1 raise PsError {
  if data.length() < 5 {
    raise oob()
  }
  { data, count_size: 4, }
}

///|
pub fn Index1::count(self : Index1) -> Int {
  if self.count_size == 4 {
    let v = read_u32_at(self.data, 0) catch { _ => 0 }
    // (A `u32` count: counts >= 2^31 can never be in bounds.)
    if v < 0 {
      0x3FFFFFFF
    } else {
      v
    }
  } else {
    (self.data[0].to_int() << 8) | self.data[1].to_int()
  }
}

///|
pub fn Index1::off_size(self : Index1) -> Int {
  self.data[self.count_size].to_int()
}

///|
fn Index1::offsets_range(self : Index1) -> (Int, Int) {
  let start = self.count_size + 1
  let len = (self.count().to_int64() + 1L) * self.off_size().to_int64()
  let end = start.to_int64() + len
  (start, if end > 0x7FFFFFFFL { 0x7FFFFFFF } else { end.to_int() })
}

///|
/// The raw offset array (empty if out of bounds).
pub fn Index1::offsets(self : Index1) -> BytesView {
  let (s, e) = self.offsets_range()
  match get_range(self.data, s, e) {
    Some(v) => v
    None => b""[:]
  }
}

///|
/// The object data (empty if out of bounds).
pub fn Index1::data(self : Index1) -> BytesView {
  let (_, start) = self.offsets_range()
  let len = self.data.length() - start
  let len = if len < 0 { 0 } else { len }
  match get_range(self.data, start, start + len) {
    Some(v) => v
    None => b""[:]
  }
}

///|
/// Returns the total size in bytes of the index table.
pub fn Index1::size_in_bytes(self : Index1) -> Int raise PsError {
  let count = self.count()
  match count {
    0 => self.count_size
    _ => {
      let off = self.get_offset(count) catch { _ => raise oob() }
      self.count_size + 1 + self.offsets().length() + off
    }
  }
}

///|
/// Returns the offset of the object at the given index.
pub fn Index1::get_offset(self : Index1, index : Int) -> Int raise PsError {
  read_offset(index, self.count(), self.off_size(), self.offsets())
}

///|
/// Returns the data for the object at the given index.
pub fn Index1::get(self : Index1, index : Int) -> BytesView raise PsError {
  let start = self.get_offset(index)
  let end = self.get_offset(index + 1)
  match get_range(self.data(), start, end) {
    Some(v) => v
    None => raise oob()
  }
}

///|
/// Reads an offset which is encoded as a variable sized integer.
fn read_offset(
  index : Int,
  count : Int,
  offset_size : Int,
  offset_data : BytesView,
) -> Int raise PsError {
  // There are actually count + 1 entries in the offset array.
  //
  // "Offsets in the offset array are relative to the byte that precedes
  // the object data. Therefore the first element of the offset array is
  // always 1."
  if index < 0 || index > count {
    raise oob()
  }
  let data_offset = index * offset_size
  let off = match offset_size {
    1 => read_u8_at(offset_data, data_offset)
    2 => read_u16_at(offset_data, data_offset)
    3 => read_u24_at(offset_data, data_offset)
    4 => {
      // u32 as usize; values >= 2^31 can never be in bounds
      let v = read_u32_at(offset_data, data_offset)
      if v < 0 {
        2147483647
      } else {
        v
      }
    }
    _ => raise InvalidIndexOffsetSize(offset_size)
  }
  // As above, subtract one to get the actual offset.
  if off == 0 {
    raise ZeroOffsetInIndex
  }
  off - 1
}

///|
/// Common type for uniform access to CFF index formats.
pub(all) enum Index {
  Empty
  Format1(Index1)
}

///|
/// Creates a new index from the given data.
pub fn Index::new(data : BytesView, is_cff2 : Bool) -> Index raise PsError {
  if is_cff2 {
    if data.length() == 4 && read_u32_at(data, 0) == 0 {
      return Empty
    }
    return Format1(Index1::read2(data))
  }
  if data.length() == 2 && read_u16_at(data, 0) == 0 {
    return Empty
  }
  Format1(Index1::read(data))
}

///|
/// Returns the number of objects in the index.
pub fn Index::count(self : Index) -> Int {
  match self {
    Empty => 0
    Format1(ix) => ix.count()
  }
}

///|
/// Computes a bias that is added to a subroutine operator in a charstring.
pub fn Index::subr_bias(self : Index) -> Int {
  let count = self.count()
  if count < 1240 {
    107
  } else if count < 33900 {
    1131
  } else {
    32768
  }
}

///|
/// Returns the total size in bytes of the index table.
pub fn Index::size_in_bytes(self : Index) -> Int raise PsError {
  match self {
    Empty => 0
    Format1(ix) => ix.size_in_bytes()
  }
}

///|
/// Returns the offset at the given index.
pub fn Index::get_offset(self : Index, index : Int) -> Int raise PsError {
  match self {
    Empty => raise oob()
    Format1(ix) => ix.get_offset(index)
  }
}

///|
/// Returns the data for the object at the given index.
pub fn Index::get(self : Index, index : Int) -> BytesView raise PsError {
  match self {
    Empty => raise oob()
    Format1(ix) => ix.get(index)
  }
}

///|
pub fn Index::off_size(self : Index) -> Int {
  match self {
    Empty => 0
    Format1(ix) => ix.off_size()
  }
}
