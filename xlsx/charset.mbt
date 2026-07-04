///|
/// Built-in charset transcoding for the common table-free encodings,
/// applied when an XML part declares a non-UTF-8 encoding (or carries a
/// UTF-16 byte-order mark) and the caller supplied no explicit
/// transcoder. This mirrors Excelize, which defaults its XML decoder to
/// `charset.NewReaderLabel` (the WHATWG encoding standard), for the
/// subset that needs no large lookup table: the Windows-1252 /
/// Latin-1 / ASCII family and UTF-16. The multi-byte CJK encodings
/// (Shift-JIS/GBK/Big5/EUC-KR) still require an explicit `transcoder`.
///
/// Following WHATWG/Go, the ISO-8859-1, Latin-1, and US-ASCII labels all
/// resolve to the Windows-1252 decoder, so bytes 0x80-0x9F render as
/// CP1252 punctuation rather than C1 controls.
///
/// Returns `None` for an encoding this table does not cover, so the
/// caller can fall back to its "requires charset transcoder" error.
fn builtin_charset_decode(encoding : String, bytes : Bytes) -> String? {
  match normalize_charset_label(encoding) {
    "windows-1252" => Some(decode_windows_1252(bytes))
    "utf-16le" => decode_utf16(bytes, @encoding/utf16.Endian::Little)
    "utf-16be" => decode_utf16(bytes, @encoding/utf16.Endian::Big)
    _ => None
  }
}

///|
/// Resolves a charset label to one of the decoder families this port
/// handles, following the WHATWG encoding standard's label lists (the
/// same table Go's `charset.NewReaderLabel` uses). The Latin-1 and ASCII
/// families intentionally fold into `windows-1252`.
fn normalize_charset_label(encoding : String) -> String {
  match encoding.to_lower().trim().to_owned() {
    // Windows-1252 / Latin-1 / ASCII family (WHATWG maps them together)
    "windows-1252"
    | "cp1252"
    | "windows1252"
    | "x-cp1252"
    | "ansi"
    | "iso-8859-1"
    | "iso8859-1"
    | "iso88591"
    | "iso_8859-1"
    | "iso_8859-1:1987"
    | "iso-ir-100"
    | "latin1"
    | "latin-1"
    | "l1"
    | "cp819"
    | "ibm819"
    | "csisolatin1"
    | "us-ascii"
    | "ascii"
    | "us_ascii"
    | "iso646-us"
    | "ansi_x3.4-1968"
    | "cp367" => "windows-1252"
    // UTF-16: the plain "utf-16" label is little-endian by default in
    // WHATWG; a byte-order mark still overrides at decode time.
    "utf-16"
    | "utf16"
    | "utf-16le"
    | "utf16le"
    | "utf-16-le"
    | "utf16_le"
    | "ucs-2"
    | "ucs2"
    | "unicode"
    | "csunicode"
    | "iso-10646-ucs-2"
    | "unicodefeff" => "utf-16le"
    "utf-16be" | "utf16be" | "utf-16-be" | "utf16_be" | "unicodefffe" =>
      "utf-16be"
    other => other
  }
}

///|
/// Decodes UTF-16 bytes. A leading byte-order mark is authoritative and
/// consumed (FEFF -> big-endian, FFFE -> little-endian, matching WHATWG);
/// otherwise the label's default endianness applies. Returns `None` on
/// malformed input.
fn decode_utf16(
  bytes : Bytes,
  default_endian : @encoding/utf16.Endian,
) -> String? {
  let (endian, body) = if bytes.length() >= 2 &&
    bytes[0] == 0xfe &&
    bytes[1] == 0xff {
    (@encoding/utf16.Endian::Big, bytes[2:])
  } else if bytes.length() >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe {
    (@encoding/utf16.Endian::Little, bytes[2:])
  } else {
    (default_endian, bytes[:])
  }
  match
    (try? @encoding/utf16.decode(body, endianness=endian, ignore_bom=false)) {
    Ok(text) => Some(text)
    Err(_) => None
  }
}

///|
/// The 0x80-0x9F code points that Windows-1252 remaps away from the
/// Latin-1 C1 control block (WHATWG index-windows-1252). Index is
/// `byte - 0x80`; a 0 marks a byte Windows-1252 leaves undefined
/// (0x81, 0x8D, 0x8F, 0x90, 0x9D), which this decoder passes through as
/// the C1 control code of the same value, matching browsers and Go.
let windows_1252_high : FixedArray[Int] = [
  0x20ac, 0x0000, 0x201a, 0x0192, 0x201e, 0x2026, 0x2020, 0x2021, 0x02c6, 0x2030,
  0x0160, 0x2039, 0x0152, 0x0000, 0x017d, 0x0000, 0x0000, 0x2018, 0x2019, 0x201c,
  0x201d, 0x2022, 0x2013, 0x2014, 0x02dc, 0x2122, 0x0161, 0x203a, 0x0153, 0x0000,
  0x017e, 0x0178,
]

///|
/// Decodes Windows-1252 (and the Latin-1 / ASCII labels that fold into
/// it): identical to Latin-1 except for the 0x80-0x9F range, which maps
/// to typographic punctuation and letters.
fn decode_windows_1252(bytes : Bytes) -> String {
  let sb = StringBuilder::new()
  for b in bytes {
    let value = b.to_int()
    let code = if value >= 0x80 && value <= 0x9f {
      let mapped = windows_1252_high[value - 0x80]
      if mapped == 0 {
        value
      } else {
        mapped
      }
    } else {
      value
    }
    sb.write_char(Int::unsafe_to_char(code))
  }
  sb.to_string()
}

///|
/// Returns the UTF-16 charset label implied by a leading byte-order mark,
/// if any. A UTF-16-encoded XML document's `<?xml?>` declaration is
/// itself UTF-16 bytes, so the ASCII declaration scan cannot see its
/// encoding; the BOM is how such a document is recognized.
fn utf16_bom_label(bytes : Bytes) -> String? {
  if bytes.length() >= 2 && bytes[0] == 0xfe && bytes[1] == 0xff {
    Some("utf-16be")
  } else if bytes.length() >= 2 && bytes[0] == 0xff && bytes[1] == 0xfe {
    Some("utf-16le")
  } else {
    None
  }
}
