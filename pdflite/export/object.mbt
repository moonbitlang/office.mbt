// The object model of the exporter and its serialization.
//
// The exporter builds PDF files from scratch: objects are values of [Obj],
// indirect objects are allocated by the `SerializeContext` and written in
// increasing object-number order with a classic cross-reference table.

///|
/// A PDF object as written by the exporter.
pub(all) enum Obj {
  /// The `null` object.
  Null
  /// A boolean.
  Bool(Bool)
  /// An integer.
  Int(Int32)
  /// A real number.
  Real(Double)
  /// A name (without the leading slash; escaped on output).
  Name(String)
  /// A byte string.
  Str(Bytes)
  /// A text string: written in PDFDocEncoding if it is printable ASCII and
  /// as UTF-16BE with a byte order mark otherwise.
  TextStr(String)
  /// An array.
  Arr(Array[Obj])
  /// A dictionary (keys without the leading slash).
  Dict(Array[(String, Obj)])
  /// A reference to an indirect object.
  Ref(Int32)
}

///|
/// An indirect object: either a plain object or a stream.
pub(all) enum Indirect {
  Plain(Obj)
  Stream(Array[(String, Obj)], Bytes)
}

///|
/// A dictionary builder.
priv struct DictBuilder {
  entries : Array[(String, Obj)]
}

///|
fn DictBuilder::new() -> DictBuilder {
  { entries: [], }
}

///|
/// Set (or replace) an entry.
fn DictBuilder::set(self : DictBuilder, key : String, value : Obj) -> Unit {
  for i, entry in self.entries {
    if entry.0 == key {
      self.entries[i] = (key, value)
      return
    }
  }
  self.entries.push((key, value))
}

///|
fn DictBuilder::get(self : DictBuilder, key : String) -> Obj? {
  for entry in self.entries {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
fn DictBuilder::finish(self : DictBuilder) -> Obj {
  Dict(self.entries)
}

///|
fn DictBuilder::entries(self : DictBuilder) -> Array[(String, Obj)] {
  self.entries
}

///|
/// A rectangle as a PDF array `[x0 y0 x1 y1]`.
fn pdf_rect(x0 : Double, y0 : Double, x1 : Double, y1 : Double) -> Obj {
  Arr([Real(x0), Real(y0), Real(x1), Real(y1)])
}

///|
/// Format a real number like pdf-writer, which writes `f32`s: integral
/// values in the range of `i32` as integers, others with the shortest
/// decimal digits that read back as the same `f32` (ryu's: the closest to
/// the value, an exact tie to the even digit), never in exponent notation;
/// an integral value beyond `i32` and below 1e12 ends in `.0`, as ryu
/// writes it. Three deviations: non-finite values (which pdf-writer writes
/// as invalid `NaN`/`inf` tokens) are written as `0`; a finite value beyond
/// the range of `f32` (which becomes `inf` there) as the digits of the
/// rounded double; and 2^31 as `2147483600.0`, its shortest digits
/// (pdf-writer writes `2147483647`: its test for an integer,
/// `value as i32 as f32 == value`, holds for the saturated cast).
/// `real_oracle_wbtest.mbt` has what pdf-writer writes for 8876 values.
fn format_real(v : Double) -> String {
  let buf = Buffer()
  write_real(buf, v)
  let sb = StringBuilder()
  for b in buf.contents() {
    sb.write_char(b.to_int().unsafe_to_char())
  }
  sb.to_string()
}

///|
/// Write `format_real(v)` to `buf` without intermediate strings.
fn write_real(buf : @buffer.Buffer, v : Double) -> Unit {
  // First what most numbers of a content stream are: an integral value that
  // an `f32` holds as it is (below 2^24), for which `write_any_real` comes
  // to writing its digits.
  if v > -16777216.0 && v < 16777216.0 {
    let i = v.to_int()
    if i.to_double() == v {
      if i < 0 {
        buf.write_byte(b'-')
        write_digits(buf, (-i).to_int64())
      } else {
        write_digits(buf, i.to_int64())
      }
      return
    }
  }
  write_any_real(buf, v)
}

///|
/// `write_real` for any value (what it does for the values that it does not
/// write itself first).
fn write_any_real(buf : @buffer.Buffer, v : Double) -> Unit {
  if v.is_nan() || v.is_inf() {
    buf.write_byte(b'0')
    return
  }
  let f = Float::from_double(v)
  let x = f.to_double()
  if x.is_inf() {
    // Beyond the range of `f32`.
    write_ascii(buf, integral_string(v.round()))
    return
  }
  if x >= -2147483648.0 && x < 2147483648.0 {
    // (In the range of `i32`, so the cast truncates and `x == x.floor()` is
    // whether the cast gives `x` back.)
    let i = x.to_int()
    if i.to_double() == x {
      let i = i.to_int64()
      if i < 0L {
        buf.write_byte(b'-')
        write_digits(buf, -i)
      } else {
        write_digits(buf, i)
      }
      return
    }
  }
  // The shortest digits `n * 10^exp` (at most 9 significant digits) that
  // round to the same `f32`, as ryu chooses them.
  let bits = f.reinterpret_as_uint()
  let decimal = ryu_f2d(bits & 0x7FFFFFU, (bits >> 23) & 0xFFU)
  let mut digits = decimal.mantissa.to_uint64().reinterpret_as_int64()
  let mut exp = decimal.exponent
  while digits != 0L && digits % 10L == 0L {
    digits = digits / 10L
    exp += 1
  }
  if x < 0.0 {
    buf.write_byte(b'-')
  }
  if exp >= 0 {
    write_digits(buf, digits)
    for _ in 0..<exp {
      buf.write_byte(b'0')
    }
    // Below 1e12 (as an `f32`) pdf-writer writes ryu's text, which marks an
    // integral value with `.0`; from there on Rust's `Display`, which does
    // not.
    if x.abs() < 999999995904.0 {
      buf.write_byte(b'.')
      buf.write_byte(b'0')
    }
    return
  }
  // The last `-exp` digits are behind the decimal point.
  let frac_digits = -exp
  if frac_digits < int64_pow10.length() && digits >= int64_pow10[frac_digits] {
    // There are digits before the point too.
    let unit = int64_pow10[frac_digits]
    let int_part = digits / unit
    write_digits(buf, int_part)
    buf.write_byte(b'.')
    write_padded_digits(buf, digits - int_part * unit, frac_digits)
  } else {
    // All digits are behind the point, after the zeros that fill it up
    // (`digits` has at most 9 digits, so it is below `10^frac_digits`).
    buf.write_byte(b'0')
    buf.write_byte(b'.')
    write_padded_digits(buf, digits, frac_digits)
  }
}

///|
/// Powers of ten `10^0 ..= 10^18` as `Int64`s.
let int64_pow10 : ReadOnlyArray[Int64] = [
  1L, 10L, 100L, 1000L, 10000L, 100000L, 1000000L, 10000000L, 100000000L, 1000000000L,
  10000000000L, 100000000000L, 1000000000000L, 10000000000000L, 100000000000000L,
  1000000000000000L, 10000000000000000L, 100000000000000000L, 1000000000000000000L,
]

///|
/// Write the decimal digits of a non-negative `n`.
fn write_digits(buf : @buffer.Buffer, n : Int64) -> Unit {
  // (Divisions by the constant 10, most significant digit first: numbers in
  // a content stream are short, and a division by a power of ten from a
  // table per digit is what this replaced.)
  if n >= 10L {
    write_digits(buf, n / 10L)
  }
  buf.write_byte(((n % 10L).to_int() + '0'.to_int()).to_byte())
}

///|
/// Write the last `width` decimal digits of a non-negative `n`, with
/// leading zeros (`width >= 1`).
fn write_padded_digits(buf : @buffer.Buffer, n : Int64, width : Int32) -> Unit {
  if width > 1 {
    write_padded_digits(buf, n / 10L, width - 1)
  }
  buf.write_byte(((n % 10L).to_int() + '0'.to_int()).to_byte())
}

///|
/// The decimal digits of an integral value.
fn integral_string(v : Double) -> String {
  if v.abs() < 9.0e18 {
    return v.to_int64().to_string()
  }
  // `Double::to_string` uses exponent notation from 1e21 on (`1.5e+300`),
  // which is not valid PDF syntax: expand it.
  let s = v.to_string()
  guard s.find("e+") is Some(e) else { return s }
  let mut exp = 0
  for c in s.unsafe_substring(start=e + 2, end=s.length()) {
    exp = exp * 10 + (c.to_int() - '0'.to_int())
  }
  let sb = StringBuilder()
  let mut frac_digits = 0
  let mut after_point = false
  for c in s.unsafe_substring(start=0, end=e) {
    if c == '.' {
      after_point = true
    } else {
      sb.write_char(c)
      if after_point {
        frac_digits += 1
      }
    }
  }
  for _ in 0..<(exp - frac_digits) {
    sb.write_char('0')
  }
  sb.to_string()
}

///|
/// Whether a byte of a name is written as it is: the printable ASCII
/// characters but `#`, the delimiters `/ ( ) < > [ ] { }` and `%`.
fn is_regular_name_byte(b : Int32) -> Bool {
  // (One bit per byte, in two words: names are written for every font,
  // color space and graphics state that a content stream selects.
  // `object_wbtest.mbt` compares this with the list above for every byte.)
  if b < 0x40 {
    b >= 0 && ((REGULAR_NAME_BYTES_LOW >> b) & 1UL) == 1UL
  } else {
    b < 0x80 && ((REGULAR_NAME_BYTES_HIGH >> (b - 0x40)) & 1UL) == 1UL
  }
}

///|
/// The regular name bytes below 0x40: 0x21 to 0x3F but `# % ( ) / < >`.
const REGULAR_NAME_BYTES_LOW : UInt64 = 0xAFFF7CD600000000UL

///|
/// The regular name bytes from 0x40: 0x40 to 0x7E but `[ ] { }`.
const REGULAR_NAME_BYTES_HIGH : UInt64 = 0x57FFFFFFD7FFFFFFUL

///|
let hex_digits : String = "0123456789ABCDEF"

///|
fn write_hex_byte(buf : @buffer.Buffer, b : Int32) -> Unit {
  buf.write_byte(hex_digit((b >> 4) & 0xF))
  buf.write_byte(hex_digit(b & 0xF))
}

///|
/// The digit of `hex_digits` for `n` in `0..16`, computed: two of them are
/// written for every glyph of a CID font.
fn hex_digit(n : Int32) -> Byte {
  if n < 10 {
    (n + '0'.to_int()).to_byte()
  } else {
    (n - 10 + 'A'.to_int()).to_byte()
  }
}

///|
/// Write ASCII text as it is.
fn write_ascii(buf : @buffer.Buffer, s : String) -> Unit {
  // (By code unit, which for ASCII is by character.)
  for i in 0..<s.length() {
    buf.write_byte(s.unsafe_get(i).to_int().to_byte())
  }
}

///|
/// Write an integer in decimal, the text of `Int::to_string` without the
/// string.
fn write_int(buf : @buffer.Buffer, i : Int32) -> Unit {
  let i = i.to_int64()
  if i < 0L {
    buf.write_byte(b'-')
    write_digits(buf, -i)
  } else {
    write_digits(buf, i)
  }
}

///|
/// Encode a string as UTF-8 bytes.
pub fn utf8_bytes(s : String) -> Bytes {
  let buf = Buffer()
  for c in s {
    let cp = c.to_int()
    if cp < 0x80 {
      buf.write_byte(cp.to_byte())
    } else if cp < 0x800 {
      buf.write_byte((0xC0 | (cp >> 6)).to_byte())
      buf.write_byte((0x80 | (cp & 0x3F)).to_byte())
    } else if cp < 0x10000 {
      buf.write_byte((0xE0 | (cp >> 12)).to_byte())
      buf.write_byte((0x80 | ((cp >> 6) & 0x3F)).to_byte())
      buf.write_byte((0x80 | (cp & 0x3F)).to_byte())
    } else {
      buf.write_byte((0xF0 | (cp >> 18)).to_byte())
      buf.write_byte((0x80 | ((cp >> 12) & 0x3F)).to_byte())
      buf.write_byte((0x80 | ((cp >> 6) & 0x3F)).to_byte())
      buf.write_byte((0x80 | (cp & 0x3F)).to_byte())
    }
  }
  buf.to_bytes()
}

///|
/// Encode a text string: printable ASCII as is, everything else as UTF-16BE
/// with a byte order mark.
fn text_string_bytes(s : String) -> Bytes {
  let mut ascii = true
  for c in s {
    let cp = c.to_int()
    if cp > 0x7E ||
      (
        cp < 0x20 &&
        cp != '\n'.to_int() &&
        cp != '\r'.to_int() &&
        cp != '\t'.to_int()
      ) {
      ascii = false
      break
    }
  }
  let buf = Buffer()
  if ascii {
    for c in s {
      buf.write_byte(c.to_int().to_byte())
    }
  } else {
    buf.write_byte(b'\xFE')
    buf.write_byte(b'\xFF')
    for i in 0..<s.length() {
      let u = s.unsafe_get(i).to_int()
      buf.write_byte((u >> 8).to_byte())
      buf.write_byte((u & 0xFF).to_byte())
    }
  }
  buf.to_bytes()
}

///|
fn write_string_bytes(buf : @buffer.Buffer, bytes : Bytes) -> Unit {
  // Use a literal string if all bytes are printable, else a hex string.
  let mut printable = true
  for b in bytes {
    let b = b.to_int()
    if b < 0x20 || b > 0x7E {
      printable = false
      break
    }
  }
  if printable {
    buf.write_byte(b'(')
    for b in bytes {
      if b == b'(' || b == b')' || b == b'\\' {
        buf.write_byte(b'\\')
      }
      buf.write_byte(b)
    }
    buf.write_byte(b')')
  } else {
    buf.write_byte(b'<')
    for b in bytes {
      write_hex_byte(buf, b.to_int())
    }
    buf.write_byte(b'>')
  }
}

///|
/// `write_string_bytes` for the first `len` bytes of `bytes` (`len <=
/// bytes.length()`): what the content stream shows of its scratch buffer,
/// without a `Bytes` of its own.
fn write_string_prefix(
  buf : @buffer.Buffer,
  bytes : FixedArray[Byte],
  len : Int32,
) -> Unit {
  // Use a literal string if all bytes are printable, else a hex string.
  let mut printable = true
  for i in 0..<len {
    let b = bytes[i].to_int()
    if b < 0x20 || b > 0x7E {
      printable = false
      break
    }
  }
  if printable {
    buf.write_byte(b'(')
    for i in 0..<len {
      let b = bytes[i]
      if b == b'(' || b == b')' || b == b'\\' {
        buf.write_byte(b'\\')
      }
      buf.write_byte(b)
    }
    buf.write_byte(b')')
  } else {
    buf.write_byte(b'<')
    for i in 0..<len {
      write_hex_byte(buf, bytes[i].to_int())
    }
    buf.write_byte(b'>')
  }
}

///|
/// Write a name (with the leading slash).
fn write_name(buf : @buffer.Buffer, name : String) -> Unit {
  buf.write_byte(b'/')
  // The regular bytes that the name starts with, which is all of nearly
  // every name, by code unit.
  let len = name.length()
  let mut start = 0
  while start < len {
    let unit = name.unsafe_get(start).to_int()
    if !is_regular_name_byte(unit) {
      break
    }
    buf.write_byte(unit.to_byte())
    start += 1
  }
  if start == len {
    return
  }
  // (`start` is not inside a surrogate pair: no surrogate is a regular
  // byte.)
  for c in name.unsafe_substring(start~, end=len) {
    let cp = c.to_int()
    if cp < 0x80 {
      write_name_byte(buf, cp)
    } else {
      // Non-ASCII characters are escaped byte by byte of their UTF-8.
      for b in utf8_bytes(c.to_string()) {
        write_name_byte(buf, b.to_int())
      }
    }
  }
}

///|
#inline
fn write_name_byte(buf : @buffer.Buffer, b : Int32) -> Unit {
  if is_regular_name_byte(b) {
    buf.write_byte(b.to_byte())
  } else {
    buf.write_byte(b'#')
    write_hex_byte(buf, b)
  }
}

///|
/// Serialize an object.
fn write_obj(buf : @buffer.Buffer, obj : Obj) -> Unit {
  match obj {
    Null => write_ascii(buf, "null")
    Bool(b) => write_ascii(buf, if b { "true" } else { "false" })
    Int(i) => write_int(buf, i)
    Real(r) => write_real(buf, r)
    Name(n) => write_name(buf, n)
    Str(s) => write_string_bytes(buf, s)
    TextStr(s) => write_string_bytes(buf, text_string_bytes(s))
    Arr(items) => {
      buf.write_byte(b'[')
      for i, item in items {
        if i > 0 {
          buf.write_byte(b' ')
        }
        write_obj(buf, item)
      }
      buf.write_byte(b']')
    }
    Dict(entries) => {
      buf.write_byte(b'<')
      buf.write_byte(b'<')
      for entry in entries {
        write_name(buf, entry.0)
        buf.write_byte(b' ')
        write_obj(buf, entry.1)
        buf.write_byte(b'\n')
      }
      buf.write_byte(b'>')
      buf.write_byte(b'>')
    }
    Ref(r) => {
      write_int(buf, r)
      write_ascii(buf, " 0 R")
    }
  }
}

///|
/// Serialize a whole file from its indirect objects (numbered `1..=count`).
fn write_file(
  version : String,
  objects : Map[Int32, Indirect],
  count : Int32,
  root : Int32,
  info : Int32?,
  file_id : (Bytes, Bytes)?,
) -> Bytes {
  let buf = Buffer()
  write_ascii(buf, "%PDF-\{version}\n%")
  buf.write_byte(b'\x80')
  buf.write_byte(b'\x80')
  buf.write_byte(b'\x80')
  buf.write_byte(b'\x80')
  buf.write_byte(b'\n')
  // The offset of each object (`-1`: there is none with the number).
  let offsets : Array[Int32] = Array::make(count + 1, -1)
  for i in 1..<=count {
    guard objects.get(i) is Some(object) else { continue }
    offsets[i] = buf.length()
    write_int(buf, i)
    write_ascii(buf, " 0 obj\n")
    match object {
      Plain(obj) => write_obj(buf, obj)
      Stream(dict, data) => {
        // The dictionary with the length of the data, replacing any
        // `/Length` of the dictionary (e.g. of streams copied from other
        // files): written as [write_obj] writes a dictionary.
        buf.write_byte(b'<')
        buf.write_byte(b'<')
        for entry in dict {
          if entry.0 != "Length" {
            write_name(buf, entry.0)
            buf.write_byte(b' ')
            write_obj(buf, entry.1)
            buf.write_byte(b'\n')
          }
        }
        write_ascii(buf, "/Length ")
        write_int(buf, data.length())
        write_ascii(buf, "\n>>\nstream\n")
        buf.write_bytes(data)
        write_ascii(buf, "\nendstream")
      }
    }
    write_ascii(buf, "\nendobj\n\n")
  }
  let xref_offset = buf.length()
  write_ascii(buf, "xref\n0 ")
  write_int(buf, count + 1)
  write_ascii(buf, "\n0000000000 65535 f\r\n")
  for i in 1..<=count {
    let offset = offsets[i]
    if offset >= 0 {
      // Ten digits (a file of more than `Int` bytes is not written).
      write_padded_digits(buf, offset.to_int64(), 10)
      write_ascii(buf, " 00000 n\r\n")
    } else {
      write_ascii(buf, "0000000000 65535 f\r\n")
    }
  }
  let trailer = DictBuilder::new()
  trailer.set("Size", Int(count + 1))
  trailer.set("Root", Ref(root))
  if info is Some(info) {
    trailer.set("Info", Ref(info))
  }
  if file_id is Some((a, b)) {
    trailer.set("ID", Arr([Str(a), Str(b)]))
  }
  write_ascii(buf, "trailer\n")
  write_obj(buf, trailer.finish())
  write_ascii(buf, "\nstartxref\n\{xref_offset}\n%%EOF")
  buf.to_bytes()
}
