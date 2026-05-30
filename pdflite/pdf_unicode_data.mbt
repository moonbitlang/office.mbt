///|
priv struct PdfUnicodeDataLookup {
  code_value : String
  general_category : String
  character_name : String
}

///|
let pdf_unicode_data_cache : Ref[Array[@unicodedata.PdfUnicodeDataEntry]?] = {
  val: None,
}

///|
let pdf_unicode_data_lookup_cache : Ref[
  @hashmap.HashMap[Int, PdfUnicodeDataLookup]?,
] = { val: None }

///|
fn pdf_unicode_data_field(
  source : BytesView,
  start : Int,
  end : Int,
) -> String raise PdfError {
  @ascii.decode(source[start:end]) catch {
    _ => raise SoftError("malformed UnicodeData.txt row")
  }
}

///|
fn pdf_unicode_data_parse_row(
  source : BytesView,
  start : Int,
  end : Int,
) -> @unicodedata.PdfUnicodeDataEntry raise PdfError {
  let fields : Array[String] = []
  let mut field_start = start
  let mut index = start
  while index < end {
    if source[index].to_int() == 59 {
      fields.push(pdf_unicode_data_field(source, field_start, index))
      field_start = index + 1
    }
    index += 1
  }
  fields.push(pdf_unicode_data_field(source, field_start, end))
  guard fields.length() == 15 else {
    raise SoftError("malformed UnicodeData.txt row")
  }
  {
    code_value: fields[0],
    character_name: fields[1],
    general_category: fields[2],
    canonical_combining_classes: fields[3],
    bidirectional_category: fields[4],
    character_decomposition_mapping: fields[5],
    decimal_digit_value: fields[6],
    digit_value: fields[7],
    numeric_value: fields[8],
    mirrored: fields[9],
    unicode_10_name: fields[10],
    iso_10646_comment_field: fields[11],
    uppercase_mapping: fields[12],
    lowercase_mapping: fields[13],
    titlecase_mapping: fields[14],
  }
}

///|
/// Parse UnicodeData.txt bytes into cpdf-compatible rows.
pub fn pdf_parse_unicode_data(
  source : BytesView,
) -> Array[@unicodedata.PdfUnicodeDataEntry] raise PdfError {
  let entries : Array[@unicodedata.PdfUnicodeDataEntry] = []
  let mut index = 0
  while index < source.length() {
    let row_start = index
    while index < source.length() && source[index].to_int() != 10 {
      index += 1
    }
    let mut row_end = index
    if row_end > row_start && source[row_end - 1].to_int() == 13 {
      row_end -= 1
    }
    entries.push(pdf_unicode_data_parse_row(source, row_start, row_end))
    if index < source.length() {
      index += 1
    }
  }
  entries
}

///|
/// Decode cpdf's flate-compressed UnicodeData source bytes, then parse rows.
pub fn pdf_parse_flate_unicode_data(
  source : BytesView,
) -> Array[@unicodedata.PdfUnicodeDataEntry] raise PdfError {
  pdf_parse_unicode_data(pdf_flate_decode_view(source))
}

///|
/// Return cpdf's parsed UnicodeData table, decoded and parsed on demand.
pub fn pdf_unicode_data() -> Array[@unicodedata.PdfUnicodeDataEntry] raise PdfError {
  match pdf_unicode_data_cache.val {
    Some(entries) => entries
    None => {
      let entries = pdf_parse_flate_unicode_data(pdf_unicode_data_source())
      pdf_unicode_data_cache.val = Some(entries)
      entries
    }
  }
}

///|
/// Source-spelled compatibility wrapper for cpdfunicodedata's `unicodedata`.
pub fn pdf_unicodedata() -> Array[@unicodedata.PdfUnicodeDataEntry] raise PdfError {
  pdf_unicode_data()
}

///|
fn pdf_unicode_data_hex_digit(value : Byte) -> Int? {
  match value.to_int() {
    digit if digit >= 0x30 && digit <= 0x39 => Some(digit - 0x30)
    upper if upper >= 0x41 && upper <= 0x46 => Some(upper - 0x41 + 10)
    lower if lower >= 0x61 && lower <= 0x66 => Some(lower - 0x61 + 10)
    _ => None
  }
}

///|
fn pdf_unicode_data_codepoint(text : String) -> Int? {
  let bytes = @ascii.encode(text)
  guard bytes.length() > 0 else { return None }
  let mut value = 0
  for byte in bytes {
    match pdf_unicode_data_hex_digit(byte) {
      Some(digit) => value = value * 16 + digit
      None => return None
    }
  }
  Some(value)
}

///|
fn pdf_unicode_data_lookup_table() -> @hashmap.HashMap[
  Int,
  PdfUnicodeDataLookup,
] raise PdfError {
  match pdf_unicode_data_lookup_cache.val {
    Some(table) => table
    None => {
      let table : @hashmap.HashMap[Int, PdfUnicodeDataLookup] = HashMap([])
      for entry in pdf_unicode_data() {
        match pdf_unicode_data_codepoint(entry.code_value) {
          Some(codepoint) =>
            table[codepoint] = {
              code_value: entry.code_value,
              general_category: entry.general_category,
              character_name: entry.character_name,
            }
          None => raise SoftError("malformed UnicodeData code value")
        }
      }
      pdf_unicode_data_lookup_cache.val = Some(table)
      table
    }
  }
}

///|
fn pdf_unicode_data_lookup(
  codepoint : Int,
) -> PdfUnicodeDataLookup? raise PdfError {
  pdf_unicode_data_lookup_table().get(codepoint)
}
