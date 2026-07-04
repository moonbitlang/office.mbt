///|
/// Return complete table-directory records from a TrueType font.
///
/// This is the first structural pass in `Cpdftruetype.parse`: it reads
/// `numTables`, then each `(tag, checksum, offset, length)` table record.
pub fn pdf_truetype_tables(
  data : BytesView,
) -> Array[@truetype.PdfTrueTypeTableRecord] {
  let records : Array[@truetype.PdfTrueTypeTableRecord] = []
  match pdf_truetype_read_u16(data, 4) {
    Some(table_count) =>
      for index in 0..<table_count {
        let table_offset = 12 + index * 16
        match
          (
            pdf_truetype_read_tag(data, table_offset),
            pdf_truetype_read_u32(data, table_offset + 4),
            pdf_truetype_read_u32_as_int(data, table_offset + 8),
            pdf_truetype_read_u32_as_int(data, table_offset + 12),
          ) {
          (Some(tag), Some(checksum), Some(offset), Some(length)) =>
            records.push({ tag, checksum, offset, length })
          _ => break
        }
      }
    None => ()
  }
  records
}

///|
/// Return one table-directory record by tag.
pub fn pdf_truetype_table(
  data : BytesView,
  tag : String,
) -> @truetype.PdfTrueTypeTableRecord? {
  for record in pdf_truetype_tables(data) {
    if record.tag == tag {
      break Some(record)
    }
  } nobreak {
    None
  }
}

///|
fn pdf_truetype_required_table(
  data : BytesView,
  tag : String,
) -> @truetype.PdfTrueTypeTableRecord raise @core.PdfError {
  match pdf_truetype_table(data, tag) {
    Some(record) => record
    None => raise SoftError("No " + tag + " table found in TrueType font")
  }
}

///|
fn pdf_truetype_required_u16(
  data : BytesView,
  offset : Int,
  label : String,
) -> Int raise @core.PdfError {
  match pdf_truetype_read_u16(data, offset) {
    Some(value) => value
    None => raise SoftError("Truncated TrueType " + label)
  }
}

///|
fn pdf_truetype_required_i16(
  data : BytesView,
  offset : Int,
  label : String,
) -> Int raise @core.PdfError {
  match pdf_truetype_read_i16(data, offset) {
    Some(value) => value
    None => raise SoftError("Truncated TrueType " + label)
  }
}

///|
fn pdf_truetype_required_u32_as_int(
  data : BytesView,
  offset : Int,
  label : String,
) -> Int raise @core.PdfError {
  match pdf_truetype_read_u32_as_int(data, offset) {
    Some(value) => value
    None => raise SoftError("Truncated TrueType " + label)
  }
}
