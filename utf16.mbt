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
  @encoding/utf8.encode(s).length()
}

///|
/// Convert a UTF-8 byte offset to a UTF-16 code unit index.
pub fn utf8_offset_to_utf16_index(
  bytes : BytesView,
  offset : Int,
) -> Int raise UtfIndexError {
  let len = bytes.length()
  if offset < 0 || offset > len {
    raise UtfIndexError::OutOfRange(index=offset, len~)
  }
  let prefix = bytes[:offset]
  let decoded = @encoding/utf8.decode(prefix) catch {
    _ => raise UtfIndexError::InvalidUtf8(offset~)
  }
  decoded.length()
}

///|
/// Convert a UTF-16 code unit index to a UTF-8 byte offset.
pub fn utf16_index_to_utf8_offset(
  s : StringView,
  index : Int,
) -> Int raise UtfIndexError {
  let len = s.length()
  if index < 0 || index > len {
    raise UtfIndexError::OutOfRange(index~, len~)
  }
  let prefix = s[:index] catch {
      _ => raise UtfIndexError::InvalidBoundary(index~)
    }
  @encoding/utf8.encode(prefix).length()
}
