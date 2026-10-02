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
  Int(Int)
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
  Ref(Int)
}

///|
/// An indirect object: either a plain object or a stream.
pub(all) enum Indirect {
  Plain(Obj)
  Stream(Array[(String, Obj)], Bytes)
}

///|
/// A dictionary builder.
pub struct DictBuilder {
  entries : Array[(String, Obj)]
}

///|
pub fn DictBuilder::new() -> DictBuilder {
  { entries: [] }
}

///|
/// Set (or replace) an entry.
pub fn DictBuilder::set(self : DictBuilder, key : String, value : Obj) -> Unit {
  for i, entry in self.entries {
    if entry.0 == key {
      self.entries[i] = (key, value)
      return
    }
  }
  self.entries.push((key, value))
}

///|
pub fn DictBuilder::get(self : DictBuilder, key : String) -> Obj? {
  for entry in self.entries {
    if entry.0 == key {
      return Some(entry.1)
    }
  }
  None
}

///|
pub fn DictBuilder::finish(self : DictBuilder) -> Obj {
  Dict(self.entries)
}

///|
pub fn DictBuilder::entries(self : DictBuilder) -> Array[(String, Obj)] {
  self.entries
}

///|
/// A rectangle as a PDF array `[x0 y0 x1 y1]`.
pub fn pdf_rect(x0 : Double, y0 : Double, x1 : Double, y1 : Double) -> Obj {
  Arr([Real(x0), Real(y0), Real(x1), Real(y1)])
}

///|
/// Format a real number like pdf-writer: integral values are written as
/// integers, others with at most five decimal places.
pub fn format_real(v : Double) -> String {
  if v.is_nan() || v.is_inf() {
    return "0"
  }
  if v == v.floor() && v.abs() < 2147483647.0 {
    return v.to_int().to_string()
  }
  let neg = v < 0.0
  let scaled = (v.abs() * 100000.0 + 0.5).floor()
  if scaled == 0.0 {
    return "0"
  }
  let scaled = scaled.to_int64()
  let int_part = scaled / 100000L
  let mut frac = scaled % 100000L
  let sb = StringBuilder::new()
  if neg {
    sb.write_char('-')
  }
  sb.write_string(int_part.to_string())
  if frac != 0L {
    // Five digits, trailing zeros trimmed.
    let mut digits = 5
    while frac % 10L == 0L {
      frac = frac / 10L
      digits -= 1
    }
    sb.write_char('.')
    let s = frac.to_string()
    for _ in 0..<(digits - s.length()) {
      sb.write_char('0')
    }
    sb.write_string(s)
  }
  sb.to_string()
}

///|
fn is_regular_name_byte(b : Int) -> Bool {
  b > 0x20 &&
  b < 0x7F &&
  b != '#'.to_int() &&
  b != '/'.to_int() &&
  b != '('.to_int() &&
  b != ')'.to_int() &&
  b != '<'.to_int() &&
  b != '>'.to_int() &&
  b != '['.to_int() &&
  b != ']'.to_int() &&
  b != '{'.to_int() &&
  b != '}'.to_int() &&
  b != '%'.to_int()
}

///|
let hex_digits : String = "0123456789ABCDEF"

///|
fn write_hex_byte(buf : @buffer.Buffer, b : Int) -> Unit {
  buf.write_byte(hex_digits[(b >> 4) & 0xF].to_byte())
  buf.write_byte(hex_digits[b & 0xF].to_byte())
}

///|
fn write_ascii(buf : @buffer.Buffer, s : String) -> Unit {
  for c in s {
    buf.write_byte(c.to_int().to_byte())
  }
}

///|
/// Encode a string as UTF-8 bytes.
pub fn utf8_bytes(s : String) -> Bytes {
  let buf = @buffer.new()
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
pub fn text_string_bytes(s : String) -> Bytes {
  let mut ascii = true
  for c in s {
    let cp = c.to_int()
    if cp > 0x7E || (cp < 0x20 && cp != '\n'.to_int() && cp != '\r'.to_int() && cp != '\t'.to_int()) {
      ascii = false
      break
    }
  }
  let buf = @buffer.new()
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
/// Write a name (with the leading slash).
pub fn write_name(buf : @buffer.Buffer, name : String) -> Unit {
  buf.write_byte(b'/')
  for b in utf8_bytes(name) {
    let b = b.to_int()
    if is_regular_name_byte(b) {
      buf.write_byte(b.to_byte())
    } else {
      buf.write_byte(b'#')
      write_hex_byte(buf, b)
    }
  }
}

///|
/// Serialize an object.
pub fn write_obj(buf : @buffer.Buffer, obj : Obj) -> Unit {
  match obj {
    Null => write_ascii(buf, "null")
    Bool(b) => write_ascii(buf, if b { "true" } else { "false" })
    Int(i) => write_ascii(buf, i.to_string())
    Real(r) => write_ascii(buf, format_real(r))
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
    Ref(r) => write_ascii(buf, "\{r} 0 R")
  }
}

///|
/// Serialize a whole file from its indirect objects (numbered `1..=count`).
pub fn write_file(
  version : String,
  objects : Map[Int, Indirect],
  count : Int,
  root : Int,
  info : Int?,
  file_id : (Bytes, Bytes)?,
) -> Bytes {
  let buf = @buffer.new()
  write_ascii(buf, "%PDF-\{version}\n%")
  buf.write_byte(b'\x80')
  buf.write_byte(b'\x80')
  buf.write_byte(b'\x80')
  buf.write_byte(b'\x80')
  buf.write_byte(b'\n')
  let offsets : Array[Int?] = Array::make(count + 1, None)
  for i in 1..=count {
    guard objects.get(i) is Some(object) else { continue }
    offsets[i] = Some(buf.length())
    write_ascii(buf, "\{i} 0 obj\n")
    match object {
      Plain(obj) => write_obj(buf, obj)
      Stream(dict, data) => {
        let entries = dict.copy()
        entries.push(("Length", Int(data.length())))
        write_obj(buf, Dict(entries))
        write_ascii(buf, "\nstream\n")
        buf.write_bytes(data)
        write_ascii(buf, "\nendstream")
      }
    }
    write_ascii(buf, "\nendobj\n\n")
  }
  let xref_offset = buf.length()
  write_ascii(buf, "xref\n0 \{count + 1}\n")
  write_ascii(buf, "0000000000 65535 f\r\n")
  for i in 1..=count {
    match offsets[i] {
      Some(off) => {
        let s = off.to_string()
        for _ in 0..<(10 - s.length()) {
          buf.write_byte(b'0')
        }
        write_ascii(buf, s)
        write_ascii(buf, " 00000 n\r\n")
      }
      None => write_ascii(buf, "0000000000 65535 f\r\n")
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
