// Port of read-fonts 0.39.2 `src/ps/cff/v1.rs`.

///|
/// The [Compact Font Format](https://learn.microsoft.com/en-us/typography/opentype/spec/cff) table.
pub struct Cff {
  data : BytesView
  names : Index1
  top_dicts : Index1
  strings : Index1
  global_subrs : Index1
}

///|
pub fn Cff::read(data : BytesView) -> Cff raise PsError {
  // CffHeader: major, minor, hdr_size, off_size, padding
  if data.length() < 4 {
    raise oob()
  }
  let hdr_size = data[2].to_int()
  let start = 4 + (if hdr_size > 4 { hdr_size - 4 } else { 0 })
  let trailing = match get_from(data, start) {
    Some(d) => d
    None => b""[:]
  }
  let mut d = trailing
  let names = Index1::read(d)
  d = split_off(d, names.size_in_bytes())
  let top_dicts = Index1::read(d)
  d = split_off(d, top_dicts.size_in_bytes())
  let strings = Index1::read(d)
  d = split_off(d, strings.size_in_bytes())
  let global_subrs = Index1::read(d)
  { data, names, top_dicts, strings, global_subrs, }
}

///|
fn split_off(d : BytesView, n : Int) -> BytesView raise PsError {
  match get_from(d, n) {
    Some(v) => v
    None => raise oob()
  }
}

///|
pub fn Cff::offset_data(self : Cff) -> BytesView {
  self.data
}

///|
/// Returns the name index.
pub fn Cff::names(self : Cff) -> Index1 {
  self.names
}

///|
/// Returns the PostScript name for the font in the font set at the
/// given index.
pub fn Cff::name(self : Cff, index : Int) -> BytesView? {
  try self.names.get(index) catch {
    _ => None
  } noraise {
    v => Some(v)
  }
}

///|
/// Returns the top dict index.
pub fn Cff::top_dicts(self : Cff) -> Index1 {
  self.top_dicts
}

///|
/// Returns the string index.
pub fn Cff::strings(self : Cff) -> Index1 {
  self.strings
}

///|
/// Returns the associated string for the given identifier.
///
/// If the identifier does not represent a standard string, the result is
/// looked up in the string index.
pub fn Cff::string(self : Cff, id : Sid) -> BytesView? {
  match id.resolve_standard() {
    Ok(name) => Some(ascii_bytes(name))
    Err(ix) =>
      try self.strings.get(ix) catch {
        _ => None
      } noraise {
        v => Some(v)
      }
  }
}

///|
fn ascii_bytes(s : String) -> BytesView {
  let b = Bytes::makei(s.length(), i => s[i].to_byte())
  b[:]
}

///|
/// Returns the global subroutine index.
pub fn Cff::global_subrs(self : Cff) -> Index1 {
  self.global_subrs
}

///|
/// Returns the character set associated with the top dict at the given
/// index.
pub fn Cff::charset(self : Cff, top_dict_index : Int) -> Charset? raise PsError {
  let top_dict = self.top_dicts.get(top_dict_index)
  let offset_data = self.data
  let mut charset_offset : Int? = None
  let mut num_glyphs : Int? = None
  for entry in entries(top_dict) {
    match entry {
      Ok(Charset(offset)) => charset_offset = Some(offset)
      Ok(CharstringsOffset(offset)) => {
        guard get_from(offset_data, offset) is Some(d) else { raise oob() }
        num_glyphs = Some(Index1::read(d).count())
      }
      // The ROS operator signifies a CID-keyed font and the charset
      // maps to CIDs rather than SIDs which we don't parse for
      // glyph names.
      Ok(Ros(..)) => return None
      _ => ()
    }
  }
  if charset_offset is Some(charset_offset) && num_glyphs is Some(num_glyphs) {
    Some(Charset::new(offset_data, charset_offset, num_glyphs))
  } else {
    None
  }
}
