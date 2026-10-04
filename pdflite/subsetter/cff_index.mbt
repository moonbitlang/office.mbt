// Port of subsetter 0.2.6 `src/cff/index.rs` (taken from ttf-parser).

///|
/// The offsets of an INDEX (upstream `VarOffsets`).
priv struct VarOffsets {
  data : BytesView
  offset_size : Int
}

///|
fn VarOffsets::len(self : VarOffsets) -> Int {
  self.data.length() / self.offset_size
}

///|
fn VarOffsets::get(self : VarOffsets, index : Int) -> Int? {
  if index < 0 || index >= self.len() {
    return None
  }
  let start = index * self.offset_size
  let r = Reader::new_at(self.data, start)
  let n = match self.offset_size {
    1 => r.read_u8().map(v => v.to_int64())
    2 => r.read_u16().map(v => v.to_int64())
    3 => r.read_u24().map(v => v.to_int64())
    _ => r.read_u32().map(v => v.to_uint64().reinterpret_as_int64())
  }
  guard n is Some(n) else { return None }
  // Offsets are offset by one byte in the font, so we have to shift them
  // back.
  if n == 0L {
    None
  } else {
    Some(u32_offset((n - 1L).to_int().reinterpret_as_uint()))
  }
}

///|
fn VarOffsets::last(self : VarOffsets) -> Int? {
  if self.len() > 0 {
    self.get(self.len() - 1)
  } else {
    None
  }
}

///|
/// A CFF INDEX.
priv struct Index {
  data : BytesView
  offsets : VarOffsets
}

///|
fn Index::default() -> Index {
  { data: b"", offsets: { data: b"", offset_size: 1, }, }
}

///|
fn Index::len(self : Index) -> Int {
  let n = self.offsets.len()
  if n > 0 {
    n - 1
  } else {
    0
  }
}

///|
fn Index::get(self : Index, index : Int) -> BytesView? {
  guard self.offsets.get(index) is Some(start) else { return None }
  guard self.offsets.get(index + 1) is Some(end) else { return None }
  if start <= end && end <= self.data.length() {
    Some(self.data[start:end])
  } else {
    None
  }
}

///|
/// The items of the index (upstream `IndexIter`, which stops at the first
/// item whose offsets are invalid).
fn Index::items(self : Index) -> Array[BytesView] {
  let out = []
  for i in 0..<self.len() {
    guard self.get(i) is Some(item) else { break }
    out.push(item)
  }
  out
}

///|
fn read_offset_size(r : Reader) -> Int? {
  match r.read_u8() {
    Some(v) if v >= 1 && v <= 4 => Some(v)
    _ => None
  }
}

///|
/// Parse an INDEX with a `u16` count.
fn parse_index(r : Reader) -> Index? {
  guard r.read_u16() is Some(count) else { return None }
  parse_index_impl(count, r)
}

///|
fn parse_index_impl(count : Int, r : Reader) -> Index? {
  if count == 0 {
    return Some(Index::default())
  }
  guard read_offset_size(r) is Some(offset_size) else { return None }
  let offsets_len = (count + 1) * offset_size
  guard r.read_bytes(offsets_len) is Some(data) else { return None }
  let offsets = VarOffsets::{ data, offset_size, }
  match offsets.last() {
    Some(last_offset) => {
      guard r.read_bytes(last_offset) is Some(data) else { return None }
      Some({ data, offsets, })
    }
    None => Some(Index::default())
  }
}

///|
/// Skip an INDEX with a `u16` count.
fn skip_index(r : Reader) -> Unit? {
  guard r.read_u16() is Some(count) else { return None }
  if count == 0 {
    return Some(())
  }
  guard read_offset_size(r) is Some(offset_size) else { return None }
  let offsets_len = (count + 1) * offset_size
  guard r.read_bytes(offsets_len) is Some(data) else { return None }
  let offsets = VarOffsets::{ data, offset_size, }
  if offsets.last() is Some(last_offset) {
    r.skip_bytes(last_offset)
  }
  Some(())
}

///|
/// An index that owns its data.
priv struct OwnedIndex {
  data : Bytes
  header_size : Int
}

///|
fn OwnedIndex::default() -> OwnedIndex {
  { data: b"\x00\x00", header_size: 2, }
}

///|
/// Create an index from a vector of data.
fn create_index(data : Array[BytesView]) -> OwnedIndex raise SubsetError {
  let count = data.length()
  if count > 0xFFFF {
    raise OverflowError
  }
  // + 1 Since we start counting from the preceding byte.
  let mut total = 1L
  for v in data {
    total += v.length().to_int64()
  }

  // Empty Index only contains the count field
  if count == 0 {
    return OwnedIndex::default()
  }
  let offset_size = if total <= 0xFFL {
    1
  } else if total <= 0xFFFFL {
    2
  } else if total <= 0xFFFFFFL {
    3
  } else {
    4
  }
  let w = Writer::new()
  w.write_u16(count)
  w.write_u8(offset_size)
  let mut cur_offset = 0L
  let write_offset = (len : Int) => {
    cur_offset += len.to_int64()
    match offset_size {
      1 => w.write_u8(cur_offset.to_int())
      2 => w.write_u16(cur_offset.to_int())
      3 => w.write_u24(cur_offset.to_int())
      _ => w.write_u32(cur_offset.to_int().reinterpret_as_uint())
    }
  }
  write_offset(1)
  for el in data {
    write_offset(el.length())
  }
  let header_size = w.len()
  for el in data {
    w.write_bytes(el)
  }
  { header_size, data: w.finish(), }
}
