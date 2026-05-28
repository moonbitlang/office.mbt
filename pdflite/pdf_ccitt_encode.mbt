///|
fn pdf_ccitt_encode_read_run(
  input : BitStream,
  max_columns : Int,
) -> (Bool, Int) raise PdfError {
  if max_columns <= 0 {
    raise InvalidCCITTData
  }
  let iswhite = input.get_bit()
  let mut length = 1
  while length < max_columns {
    let position = input.position()
    let next = input.get_bit()
    if next == iswhite {
      length += 1
    } else {
      input.seek(position)
      return (iswhite, length)
    }
  }
  (iswhite, length)
}

///|
fn pdf_ccitt_encode_g3_1d_view(
  data : BytesView,
  columns : Int,
  rows : Int,
) -> PdfBytes raise PdfError {
  if columns <= 0 || rows < 0 {
    raise InvalidCCITTData
  }
  let row_bytes = (columns - 1) / 8 + 1
  if rows > 0 && row_bytes > data.length() / rows {
    raise InvalidCCITTData
  }
  let input = bitstream_of_view(data)
  let output = bit_writer_new()
  let mut rows_left = rows
  let mut columns_left = columns
  while rows_left > 0 {
    let (iswhite, length) = pdf_ccitt_encode_read_run(input, columns_left)
    if !iswhite && columns_left == columns {
      pdf_ccitt_write_run(output, true, 0)
    }
    pdf_ccitt_write_run(output, iswhite, length)
    columns_left -= length
    if columns_left == 0 {
      input.align()
      columns_left = columns
      rows_left -= 1
    }
  }
  pdf_ccitt_write_eol(output)
  pdf_ccitt_write_eol(output)
  output.to_bytes()
}

///|
fn pdf_ccitt_line_from_data(
  data : BytesView,
  columns : Int,
  row : Int,
) -> Array[Int] raise PdfError {
  let row_bytes = (columns - 1) / 8 + 1
  let row_start = row * row_bytes
  if row_start + row_bytes > data.length() {
    raise EndOfInput
  }
  let line : Array[Int] = []
  for column in 0..<columns {
    let byte = data[row_start + column / 8].to_int()
    let shift = 7 - column % 8
    line.push((byte >> shift) & 1)
  }
  line
}

///|
fn pdf_ccitt_encode_g4_view(
  data : BytesView,
  columns : Int,
  rows : Int,
) -> PdfBytes raise PdfError {
  if columns <= 0 || rows < 0 {
    raise InvalidCCITTData
  }
  let row_bytes = (columns - 1) / 8 + 1
  if rows > 0 && row_bytes > data.length() / rows {
    raise InvalidCCITTData
  }
  let output = bit_writer_new()
  let whiteval = 1
  let blackval = 0
  let mut reference = pdf_ccitt_blank_line(columns, whiteval)
  for row in 0..<rows {
    let line = pdf_ccitt_line_from_data(data, columns, row)
    let mut column = 0
    let mut white = true
    while column < columns {
      let a1 = pdf_ccitt_find_b1(line, column, white, whiteval, blackval)
      let a2 = pdf_ccitt_find_b2(line, column, white, whiteval, blackval)
      let b1 = pdf_ccitt_find_b1(reference, column, white, whiteval, blackval)
      let b2 = pdf_ccitt_find_b2(reference, column, white, whiteval, blackval)
      if b2 < a1 {
        pdf_ccitt_write_mode(output, CCITTPass)
        column = b2
      } else {
        let delta = b1 - a1
        if delta >= -3 && delta <= 3 {
          pdf_ccitt_write_mode(output, CCITTVertical(delta))
          column = a1
          white = !white
        } else {
          pdf_ccitt_write_mode(output, CCITTHorizontal)
          pdf_ccitt_write_run(output, white, a1 - column)
          pdf_ccitt_write_run(output, !white, a2 - a1)
          column = a2
        }
      }
    }
    reference = line
  }
  pdf_ccitt_write_mode(output, CCITTEOFB)
  output.to_bytes()
}
