// Port of read-fonts 0.39.2 `src/ps/cff/encoding.rs`.

///|
/// Mapping from character codes to string ids.
pub enum RawEncoding {
  Predefined(PredefinedEncoding)
  Custom(CustomEncoding)
}

///|
/// Parses an encoding at the given offset.
///
/// Special offsets 0 and 1 are parsed as the predefined standard and
/// expert encodings, respectively.
pub fn RawEncoding::new(
  data : BytesView,
  offset : Int,
) -> RawEncoding raise PsError {
  match offset {
    0 => Predefined(Standard)
    1 => Predefined(Expert)
    _ =>
      match get_from(data, offset) {
        Some(d) => Custom(CustomEncoding::new(d))
        None => raise oob()
      }
  }
}

///|
/// Maps a character code to a glyph identifier.
pub fn RawEncoding::map(
  self : RawEncoding,
  charset : Charset,
  code : Int,
) -> GlyphId? {
  match self {
    Predefined(predefined) => {
      guard predefined.sid(code) is Some(sid) else { return None }
      try charset.glyph_id(sid) catch {
        _ => None
      } noraise {
        g => Some(g)
      }
    }
    Custom(custom) => custom.map(charset, code)
  }
}

///|
/// Custom mapping from character codes to string ids.
pub enum CustomEncoding {
  /// Sequence of character codes where the string id is equal to the index
  /// of the code plus one (codes, supplements).
  Format0(BytesView, BytesView)
  /// Sequence of ranges mapping character codes to string ids (ranges,
  /// supplements).
  Format1(BytesView, BytesView)
}

///|
/// Parses a custom encoding from the given data.
pub fn CustomEncoding::new(data : BytesView) -> CustomEncoding raise PsError {
  let cursor = Cursor::new(data)
  let header = cursor.read_u8()
  let has_supplement = (header & 0x80) != 0
  let read_supplement = fn() raise PsError {
    if has_supplement {
      let count = cursor.read_u8()
      cursor.read_array(count, 3)
    } else {
      b""
    }
  }
  let format = header & 0x7F
  match format {
    0 => {
      let n_codes = cursor.read_u8()
      let codes = cursor.read_array(n_codes, 1)
      let supp = read_supplement()
      Format0(codes, supp)
    }
    1 => {
      let n_ranges = cursor.read_u8()
      let ranges = cursor.read_array(n_ranges, 2)
      let supp = read_supplement()
      Format1(ranges, supp)
    }
    _ => raise Read(@read_fonts.ReadError::InvalidFormat(format.to_int64()))
  }
}

///|
/// Maps a character code to a glyph identifier.
pub fn CustomEncoding::map(
  self : CustomEncoding,
  charset : Charset,
  code : Int,
) -> GlyphId? {
  let read_sup = fn(sup : BytesView) -> GlyphId? {
    for i in 0..<(sup.length() / 3) {
      if sup[i * 3].to_int() == code {
        let sid = (sup[i * 3 + 1].to_int() << 8) | sup[i * 3 + 2].to_int()
        return try charset.glyph_id(Sid::new(sid)) catch {
          _ => None
        } noraise {
          g => Some(g)
        }
      }
    }
    None
  }
  match self {
    Format0(codes, sup) =>
      match read_sup(sup) {
        Some(g) => Some(g)
        None => {
          for i in 0..<codes.length() {
            if codes[i].to_int() == code {
              // notdef is implicit so add one
              return Some(GlyphId::from_int(i + 1))
            }
          }
          None
        }
      }
    Format1(ranges, sup) =>
      match read_sup(sup) {
        Some(g) => Some(g)
        None => {
          let mut gid = 1
          for i in 0..<(ranges.length() / 2) {
            let first = ranges[i * 2].to_int()
            let n_left = ranges[i * 2 + 1].to_int()
            let end = if first + n_left > 255 { 255 } else { first + n_left }
            if code >= first && code <= end {
              gid += code - first
              return Some(GlyphId::from_int(gid))
            }
            gid += n_left + 1
          }
          None
        }
      }
  }
}
