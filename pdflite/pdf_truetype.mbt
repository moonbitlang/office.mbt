///|
fn pdf_truetype_read_u16(data : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset > data.length() - 2 {
    None
  } else {
    Some(data[offset].to_int() * 256 + data[offset + 1].to_int())
  }
}

///|
fn pdf_truetype_read_u32_as_int(data : BytesView, offset : Int) -> Int? {
  if offset < 0 || offset > data.length() - 4 {
    None
  } else {
    let value = data[offset].to_int().to_int64() * 16777216L +
      data[offset + 1].to_int().to_int64() * 65536L +
      data[offset + 2].to_int().to_int64() * 256L +
      data[offset + 3].to_int().to_int64()
    if value > 2147483647L {
      None
    } else {
      Some(value.to_int())
    }
  }
}

///|
fn pdf_truetype_is_cmap_tag(data : BytesView, offset : Int) -> Bool {
  offset >= 0 &&
  offset <= data.length() - 4 &&
  data[offset].to_int() == 0x63 &&
  data[offset + 1].to_int() == 0x6D &&
  data[offset + 2].to_int() == 0x61 &&
  data[offset + 3].to_int() == 0x70
}

///|
fn pdf_truetype_collect_cmap_records(
  data : BytesView,
  cmap_offset : Int,
  records : Array[(Int, Int)],
) -> Unit {
  match pdf_truetype_read_u16(data, cmap_offset + 2) {
    Some(record_count) => {
      let mut index = 0
      let mut done = false
      while !done && index < record_count {
        let record_offset = cmap_offset + 4 + index * 8
        match
          (
            pdf_truetype_read_u16(data, record_offset),
            pdf_truetype_read_u16(data, record_offset + 2),
            pdf_truetype_read_u32_as_int(data, record_offset + 4),
          ) {
          (Some(platform_id), Some(encoding_id), Some(_)) => {
            records.insert(0, (platform_id, encoding_id))
            index += 1
          }
          _ => done = true
        }
      }
    }
    None => ()
  }
}

///|
/// Return the TrueType cmap platform and encoding IDs.
///
/// This ports `Cpdftruetype.cmaps`, which is used as a PDF/UA verification
/// helper. The source function catches parse failures and returns the records
/// collected before the failure; this function likewise ignores malformed or
/// incomplete parts of the font after complete cmap records have been read.
pub fn pdf_truetype_cmaps(data : BytesView) -> Array[(Int, Int)] {
  let records : Array[(Int, Int)] = []
  match pdf_truetype_read_u16(data, 4) {
    Some(table_count) => {
      let mut index = 0
      let mut done = false
      while !done && index < table_count {
        let table_offset = 12 + index * 16
        if table_offset > data.length() - 16 {
          done = true
        } else {
          if pdf_truetype_is_cmap_tag(data, table_offset) {
            match pdf_truetype_read_u32_as_int(data, table_offset + 8) {
              Some(cmap_offset) =>
                pdf_truetype_collect_cmap_records(data, cmap_offset, records)
              None => ()
            }
            done = true
          }
          index += 1
        }
      }
    }
    None => ()
  }
  records
}
