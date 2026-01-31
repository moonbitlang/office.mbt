///|
/// Errors for mapping between UTF-8 byte offsets and UTF-16 code unit indices.
pub suberror UtfIndexError {
  OutOfRange(index~ : Int, len~ : Int)
  InvalidBoundary(index~ : Int)
  InvalidUtf8(offset~ : Int)
} derive(Show, Eq)

///|
/// Return UTF-16 code unit length for a string.
pub fn utf16_len(s : StringView) -> Int {
  s.length()
}

///|
/// Return UTF-8 byte length for a string.
pub fn utf8_len(s : StringView) -> Int {
  utf8_len_from_utf16(s)
}

///|
/// Convert a UTF-8 byte offset to a UTF-16 code unit index.
pub fn utf8_offset_to_utf16_index(
  bytes : BytesView,
  offset : Int,
) -> Int raise UtfIndexError {
  utf16_index_from_utf8_prefix(bytes, offset)
}

///|
/// Convert a UTF-16 code unit index to a UTF-8 byte offset.
pub fn utf16_index_to_utf8_offset(
  s : StringView,
  index : Int,
) -> Int raise UtfIndexError {
  let len = s.length()
  if index < 0 || index > len {
    raise OutOfRange(index~, len~)
  }
  if index > 0 && index < len {
    let prev = s[index - 1]
    let cur = s[index]
    if is_high_surrogate(prev) && is_low_surrogate(cur) {
      raise InvalidBoundary(index~)
    }
  }
  utf8_len_from_utf16_prefix(s, index)
}

///|
fn is_high_surrogate(u : UInt16) -> Bool {
  u >= 0xD800 && u <= 0xDBFF
}

///|
fn is_low_surrogate(u : UInt16) -> Bool {
  u >= 0xDC00 && u <= 0xDFFF
}

///|
fn utf8_len_from_utf16(s : StringView) -> Int {
  utf8_len_from_utf16_prefix(s, s.length())
}

///|
fn utf8_len_from_utf16_prefix(s : StringView, end_utf16 : Int) -> Int {
  let mut bytes = 0
  let mut i = 0
  while i < end_utf16 {
    let u0 = s[i]
    if is_high_surrogate(u0) && i + 1 < end_utf16 && is_low_surrogate(s[i + 1]) {
      bytes = bytes + 4
      i = i + 2
    } else {
      let cp = u0.to_int()
      if cp < 0x80 {
        bytes = bytes + 1
      } else if cp < 0x800 {
        bytes = bytes + 2
      } else {
        bytes = bytes + 3
      }
      i = i + 1
    }
  }
  bytes
}

///|
fn utf16_index_from_utf8_prefix(
  bytes : BytesView,
  offset : Int,
) -> Int raise UtfIndexError {
  let len = bytes.length()
  if offset < 0 || offset > len {
    raise OutOfRange(index=offset, len~)
  }
  let mut pos = 0
  let mut utf16_units = 0
  while pos < offset {
    let b0 = bytes[pos].to_int()
    if b0 < 0x80 {
      pos = pos + 1
      utf16_units = utf16_units + 1
      continue
    }
    if b0 >= 0xC2 && b0 <= 0xDF {
      if pos + 2 > offset {
        raise InvalidUtf8(offset~)
      }
      let b1 = bytes[pos + 1].to_int()
      if (b1 & 0xC0) != 0x80 {
        raise InvalidUtf8(offset~)
      }
      pos = pos + 2
      utf16_units = utf16_units + 1
      continue
    }
    if b0 >= 0xE0 && b0 <= 0xEF {
      if pos + 3 > offset {
        raise InvalidUtf8(offset~)
      }
      let b1 = bytes[pos + 1].to_int()
      let b2 = bytes[pos + 2].to_int()
      if (b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80 {
        raise InvalidUtf8(offset~)
      }
      if (b0 == 0xE0 && b1 < 0xA0) || (b0 == 0xED && b1 >= 0xA0) {
        raise InvalidUtf8(offset~)
      }
      pos = pos + 3
      utf16_units = utf16_units + 1
      continue
    }
    if b0 >= 0xF0 && b0 <= 0xF4 {
      if pos + 4 > offset {
        raise InvalidUtf8(offset~)
      }
      let b1 = bytes[pos + 1].to_int()
      let b2 = bytes[pos + 2].to_int()
      let b3 = bytes[pos + 3].to_int()
      if (b1 & 0xC0) != 0x80 || (b2 & 0xC0) != 0x80 || (b3 & 0xC0) != 0x80 {
        raise InvalidUtf8(offset~)
      }
      if (b0 == 0xF0 && b1 < 0x90) || (b0 == 0xF4 && b1 > 0x8F) {
        raise InvalidUtf8(offset~)
      }
      pos = pos + 4
      utf16_units = utf16_units + 2
      continue
    }
    raise InvalidUtf8(offset~)
  }
  utf16_units
}
