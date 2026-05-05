///|
priv struct PdfCCITTCode {
  bits : Int
  width : Int
  run : Int
  makeup : Bool
}

///|
priv struct PdfCCITTMode {
  bits : Int
  width : Int
  mode : PdfCCITTModeKind
}

///|
priv enum PdfCCITTModeKind {
  CCITTPass
  CCITTHorizontal
  CCITTVertical(Int)
  CCITTUncompressed
  CCITTEOFB
}

///|
priv struct PdfCCITTRun {
  run : Int
  makeup : Bool
}

///|
priv struct PdfCCITTParams {
  k : Int
  end_of_line : Bool
  encoded_byte_align : Bool
  columns : Int
  rows : Int
  end_of_block : Bool
  black_is_1 : Bool
  damaged_rows_before_error : Int
}

///|
fn pdf_ccitt_code(
  bits : Int,
  width : Int,
  run : Int,
  makeup? : Bool = false,
) -> PdfCCITTCode {
  { bits, width, run, makeup }
}

///|
let pdf_ccitt_white_codes : Array[PdfCCITTCode] = [
  pdf_ccitt_code(0b00110101, 8, 0),
  pdf_ccitt_code(0b000111, 6, 1),
  pdf_ccitt_code(0b0111, 4, 2),
  pdf_ccitt_code(0b1000, 4, 3),
  pdf_ccitt_code(0b1011, 4, 4),
  pdf_ccitt_code(0b1100, 4, 5),
  pdf_ccitt_code(0b1110, 4, 6),
  pdf_ccitt_code(0b1111, 4, 7),
  pdf_ccitt_code(0b10011, 5, 8),
  pdf_ccitt_code(0b10100, 5, 9),
  pdf_ccitt_code(0b00111, 5, 10),
  pdf_ccitt_code(0b01000, 5, 11),
  pdf_ccitt_code(0b001000, 6, 12),
  pdf_ccitt_code(0b000011, 6, 13),
  pdf_ccitt_code(0b110100, 6, 14),
  pdf_ccitt_code(0b110101, 6, 15),
  pdf_ccitt_code(0b101010, 6, 16),
  pdf_ccitt_code(0b101011, 6, 17),
  pdf_ccitt_code(0b0100111, 7, 18),
  pdf_ccitt_code(0b0001100, 7, 19),
  pdf_ccitt_code(0b0001000, 7, 20),
  pdf_ccitt_code(0b0010111, 7, 21),
  pdf_ccitt_code(0b0000011, 7, 22),
  pdf_ccitt_code(0b0000100, 7, 23),
  pdf_ccitt_code(0b0101000, 7, 24),
  pdf_ccitt_code(0b0101011, 7, 25),
  pdf_ccitt_code(0b0010011, 7, 26),
  pdf_ccitt_code(0b0100100, 7, 27),
  pdf_ccitt_code(0b0011000, 7, 28),
  pdf_ccitt_code(0b00000010, 8, 29),
  pdf_ccitt_code(0b00000011, 8, 30),
  pdf_ccitt_code(0b00011010, 8, 31),
  pdf_ccitt_code(0b00011011, 8, 32),
  pdf_ccitt_code(0b00010010, 8, 33),
  pdf_ccitt_code(0b00010011, 8, 34),
  pdf_ccitt_code(0b00010100, 8, 35),
  pdf_ccitt_code(0b00010101, 8, 36),
  pdf_ccitt_code(0b00010110, 8, 37),
  pdf_ccitt_code(0b00010111, 8, 38),
  pdf_ccitt_code(0b00101000, 8, 39),
  pdf_ccitt_code(0b00101001, 8, 40),
  pdf_ccitt_code(0b00101010, 8, 41),
  pdf_ccitt_code(0b00101011, 8, 42),
  pdf_ccitt_code(0b00101100, 8, 43),
  pdf_ccitt_code(0b00101101, 8, 44),
  pdf_ccitt_code(0b00000100, 8, 45),
  pdf_ccitt_code(0b00000101, 8, 46),
  pdf_ccitt_code(0b00001010, 8, 47),
  pdf_ccitt_code(0b00001011, 8, 48),
  pdf_ccitt_code(0b01010010, 8, 49),
  pdf_ccitt_code(0b01010011, 8, 50),
  pdf_ccitt_code(0b01010100, 8, 51),
  pdf_ccitt_code(0b01010101, 8, 52),
  pdf_ccitt_code(0b00100100, 8, 53),
  pdf_ccitt_code(0b00100101, 8, 54),
  pdf_ccitt_code(0b01011000, 8, 55),
  pdf_ccitt_code(0b01011001, 8, 56),
  pdf_ccitt_code(0b01011010, 8, 57),
  pdf_ccitt_code(0b01011011, 8, 58),
  pdf_ccitt_code(0b01001010, 8, 59),
  pdf_ccitt_code(0b01001011, 8, 60),
  pdf_ccitt_code(0b00110010, 8, 61),
  pdf_ccitt_code(0b00110011, 8, 62),
  pdf_ccitt_code(0b00110100, 8, 63),
  pdf_ccitt_code(0b11011, 5, 64, makeup=true),
  pdf_ccitt_code(0b10010, 5, 128, makeup=true),
  pdf_ccitt_code(0b010111, 6, 192, makeup=true),
  pdf_ccitt_code(0b0110111, 7, 256, makeup=true),
  pdf_ccitt_code(0b00110110, 8, 320, makeup=true),
  pdf_ccitt_code(0b00110111, 8, 384, makeup=true),
  pdf_ccitt_code(0b01100100, 8, 448, makeup=true),
  pdf_ccitt_code(0b01100101, 8, 512, makeup=true),
  pdf_ccitt_code(0b01101000, 8, 576, makeup=true),
  pdf_ccitt_code(0b01100111, 8, 640, makeup=true),
  pdf_ccitt_code(0b011001100, 9, 704, makeup=true),
  pdf_ccitt_code(0b011001101, 9, 768, makeup=true),
  pdf_ccitt_code(0b011010010, 9, 832, makeup=true),
  pdf_ccitt_code(0b011010011, 9, 896, makeup=true),
  pdf_ccitt_code(0b011010100, 9, 960, makeup=true),
  pdf_ccitt_code(0b011010101, 9, 1024, makeup=true),
  pdf_ccitt_code(0b011010110, 9, 1088, makeup=true),
  pdf_ccitt_code(0b011010111, 9, 1152, makeup=true),
  pdf_ccitt_code(0b011011000, 9, 1216, makeup=true),
  pdf_ccitt_code(0b011011001, 9, 1280, makeup=true),
  pdf_ccitt_code(0b011011010, 9, 1344, makeup=true),
  pdf_ccitt_code(0b011011011, 9, 1408, makeup=true),
  pdf_ccitt_code(0b010011000, 9, 1472, makeup=true),
  pdf_ccitt_code(0b010011001, 9, 1536, makeup=true),
  pdf_ccitt_code(0b010011010, 9, 1600, makeup=true),
  pdf_ccitt_code(0b011000, 6, 1664, makeup=true),
  pdf_ccitt_code(0b010011011, 9, 1728, makeup=true),
  pdf_ccitt_code(0b00000001000, 11, 1792, makeup=true),
  pdf_ccitt_code(0b00000001100, 11, 1856, makeup=true),
  pdf_ccitt_code(0b00000001101, 11, 1920, makeup=true),
  pdf_ccitt_code(0b000000010010, 12, 1984, makeup=true),
  pdf_ccitt_code(0b000000010011, 12, 2048, makeup=true),
  pdf_ccitt_code(0b000000010100, 12, 2112, makeup=true),
  pdf_ccitt_code(0b000000010101, 12, 2176, makeup=true),
  pdf_ccitt_code(0b000000010110, 12, 2240, makeup=true),
  pdf_ccitt_code(0b000000010111, 12, 2304, makeup=true),
  pdf_ccitt_code(0b000000011100, 12, 2368, makeup=true),
  pdf_ccitt_code(0b000000011101, 12, 2432, makeup=true),
  pdf_ccitt_code(0b000000011110, 12, 2496, makeup=true),
  pdf_ccitt_code(0b000000011111, 12, 2560, makeup=true),
  pdf_ccitt_code(0b000000000001, 12, -1),
]

///|
let pdf_ccitt_black_codes : Array[PdfCCITTCode] = [
  pdf_ccitt_code(0b0000110111, 10, 0),
  pdf_ccitt_code(0b010, 3, 1),
  pdf_ccitt_code(0b11, 2, 2),
  pdf_ccitt_code(0b10, 2, 3),
  pdf_ccitt_code(0b011, 3, 4),
  pdf_ccitt_code(0b0011, 4, 5),
  pdf_ccitt_code(0b0010, 4, 6),
  pdf_ccitt_code(0b00011, 5, 7),
  pdf_ccitt_code(0b000101, 6, 8),
  pdf_ccitt_code(0b000100, 6, 9),
  pdf_ccitt_code(0b0000100, 7, 10),
  pdf_ccitt_code(0b0000101, 7, 11),
  pdf_ccitt_code(0b0000111, 7, 12),
  pdf_ccitt_code(0b00000100, 8, 13),
  pdf_ccitt_code(0b00000111, 8, 14),
  pdf_ccitt_code(0b000011000, 9, 15),
  pdf_ccitt_code(0b0000010111, 10, 16),
  pdf_ccitt_code(0b0000011000, 10, 17),
  pdf_ccitt_code(0b0000001000, 10, 18),
  pdf_ccitt_code(0b00001100111, 11, 19),
  pdf_ccitt_code(0b00001101000, 11, 20),
  pdf_ccitt_code(0b00001101100, 11, 21),
  pdf_ccitt_code(0b00000110111, 11, 22),
  pdf_ccitt_code(0b00000101000, 11, 23),
  pdf_ccitt_code(0b00000010111, 11, 24),
  pdf_ccitt_code(0b00000011000, 11, 25),
  pdf_ccitt_code(0b000011001010, 12, 26),
  pdf_ccitt_code(0b000011001011, 12, 27),
  pdf_ccitt_code(0b000011001100, 12, 28),
  pdf_ccitt_code(0b000011001101, 12, 29),
  pdf_ccitt_code(0b000001101000, 12, 30),
  pdf_ccitt_code(0b000001101001, 12, 31),
  pdf_ccitt_code(0b000001101010, 12, 32),
  pdf_ccitt_code(0b000001101011, 12, 33),
  pdf_ccitt_code(0b000011010010, 12, 34),
  pdf_ccitt_code(0b000011010011, 12, 35),
  pdf_ccitt_code(0b000011010100, 12, 36),
  pdf_ccitt_code(0b000011010101, 12, 37),
  pdf_ccitt_code(0b000011010110, 12, 38),
  pdf_ccitt_code(0b000011010111, 12, 39),
  pdf_ccitt_code(0b000001101100, 12, 40),
  pdf_ccitt_code(0b000001101101, 12, 41),
  pdf_ccitt_code(0b000011011010, 12, 42),
  pdf_ccitt_code(0b000011011011, 12, 43),
  pdf_ccitt_code(0b000001010100, 12, 44),
  pdf_ccitt_code(0b000001010101, 12, 45),
  pdf_ccitt_code(0b000001010110, 12, 46),
  pdf_ccitt_code(0b000001010111, 12, 47),
  pdf_ccitt_code(0b000001100100, 12, 48),
  pdf_ccitt_code(0b000001100101, 12, 49),
  pdf_ccitt_code(0b000001010010, 12, 50),
  pdf_ccitt_code(0b000001010011, 12, 51),
  pdf_ccitt_code(0b000000100100, 12, 52),
  pdf_ccitt_code(0b000000110111, 12, 53),
  pdf_ccitt_code(0b000000111000, 12, 54),
  pdf_ccitt_code(0b000000100111, 12, 55),
  pdf_ccitt_code(0b000000101000, 12, 56),
  pdf_ccitt_code(0b000001011000, 12, 57),
  pdf_ccitt_code(0b000001011001, 12, 58),
  pdf_ccitt_code(0b000000101011, 12, 59),
  pdf_ccitt_code(0b000000101100, 12, 60),
  pdf_ccitt_code(0b000001011010, 12, 61),
  pdf_ccitt_code(0b000001100110, 12, 62),
  pdf_ccitt_code(0b000001100111, 12, 63),
  pdf_ccitt_code(0b0000001111, 10, 64, makeup=true),
  pdf_ccitt_code(0b000011001000, 12, 128, makeup=true),
  pdf_ccitt_code(0b000011001001, 12, 192, makeup=true),
  pdf_ccitt_code(0b000001011011, 12, 256, makeup=true),
  pdf_ccitt_code(0b000000110011, 12, 320, makeup=true),
  pdf_ccitt_code(0b000000110100, 12, 384, makeup=true),
  pdf_ccitt_code(0b000000110101, 12, 448, makeup=true),
  pdf_ccitt_code(0b0000001101100, 13, 512, makeup=true),
  pdf_ccitt_code(0b0000001101101, 13, 576, makeup=true),
  pdf_ccitt_code(0b0000001001010, 13, 640, makeup=true),
  pdf_ccitt_code(0b0000001001011, 13, 704, makeup=true),
  pdf_ccitt_code(0b0000001001100, 13, 768, makeup=true),
  pdf_ccitt_code(0b0000001001101, 13, 832, makeup=true),
  pdf_ccitt_code(0b0000001110010, 13, 896, makeup=true),
  pdf_ccitt_code(0b0000001110011, 13, 960, makeup=true),
  pdf_ccitt_code(0b0000001110100, 13, 1024, makeup=true),
  pdf_ccitt_code(0b0000001110101, 13, 1088, makeup=true),
  pdf_ccitt_code(0b0000001110110, 13, 1152, makeup=true),
  pdf_ccitt_code(0b0000001110111, 13, 1216, makeup=true),
  pdf_ccitt_code(0b0000001010010, 13, 1280, makeup=true),
  pdf_ccitt_code(0b0000001010011, 13, 1344, makeup=true),
  pdf_ccitt_code(0b0000001010100, 13, 1408, makeup=true),
  pdf_ccitt_code(0b0000001010101, 13, 1472, makeup=true),
  pdf_ccitt_code(0b0000001011010, 13, 1536, makeup=true),
  pdf_ccitt_code(0b0000001011011, 13, 1600, makeup=true),
  pdf_ccitt_code(0b0000001100100, 13, 1664, makeup=true),
  pdf_ccitt_code(0b0000001100101, 13, 1728, makeup=true),
  pdf_ccitt_code(0b00000001000, 11, 1792, makeup=true),
  pdf_ccitt_code(0b00000001100, 11, 1856, makeup=true),
  pdf_ccitt_code(0b00000001101, 11, 1920, makeup=true),
  pdf_ccitt_code(0b000000010010, 12, 1984, makeup=true),
  pdf_ccitt_code(0b000000010011, 12, 2048, makeup=true),
  pdf_ccitt_code(0b000000010100, 12, 2112, makeup=true),
  pdf_ccitt_code(0b000000010101, 12, 2176, makeup=true),
  pdf_ccitt_code(0b000000010110, 12, 2240, makeup=true),
  pdf_ccitt_code(0b000000010111, 12, 2304, makeup=true),
  pdf_ccitt_code(0b000000011100, 12, 2368, makeup=true),
  pdf_ccitt_code(0b000000011101, 12, 2432, makeup=true),
  pdf_ccitt_code(0b000000011110, 12, 2496, makeup=true),
  pdf_ccitt_code(0b000000011111, 12, 2560, makeup=true),
  pdf_ccitt_code(0b000000000001, 12, -1),
]

///|
let pdf_ccitt_mode_codes : Array[PdfCCITTMode] = [
  { bits: 0b1, width: 1, mode: CCITTVertical(0) },
  { bits: 0b011, width: 3, mode: CCITTVertical(-1) },
  { bits: 0b010, width: 3, mode: CCITTVertical(1) },
  { bits: 0b001, width: 3, mode: CCITTHorizontal },
  { bits: 0b0001, width: 4, mode: CCITTPass },
  { bits: 0b000011, width: 6, mode: CCITTVertical(-2) },
  { bits: 0b000010, width: 6, mode: CCITTVertical(2) },
  { bits: 0b0000011, width: 7, mode: CCITTVertical(-3) },
  { bits: 0b0000010, width: 7, mode: CCITTVertical(3) },
  { bits: 0b000000001111, width: 12, mode: CCITTUncompressed },
  { bits: 0b000000000001000000000001, width: 24, mode: CCITTEOFB },
]

///|
fn pdf_ccitt_default_params() -> PdfCCITTParams {
  {
    k: 0,
    end_of_line: false,
    encoded_byte_align: false,
    columns: 1728,
    rows: 0,
    end_of_block: true,
    black_is_1: false,
    damaged_rows_before_error: 0,
  }
}

///|
fn pdf_ccitt_read_run_code(
  input : BitStream,
  table : ArrayView[PdfCCITTCode],
) -> PdfCCITTRun raise PdfError {
  let mut bits = 0
  for width in 1..<=13 {
    bits = (bits << 1) | input.get_bit_int()
    for code in table {
      if code.width == width && code.bits == bits {
        return { run: code.run, makeup: code.makeup }
      }
    }
  }
  raise InvalidCCITTData
}

///|
fn pdf_ccitt_read_run(input : BitStream, white : Bool) -> Int raise PdfError {
  let table = if white {
    pdf_ccitt_white_codes[:]
  } else {
    pdf_ccitt_black_codes[:]
  }
  let mut total = 0
  while true {
    let code = pdf_ccitt_read_run_code(input, table)
    if code.run < 0 {
      return code.run
    }
    total += code.run
    if !code.makeup {
      return total
    }
  }
  raise InvalidCCITTData
}

///|
fn pdf_ccitt_read_mode(input : BitStream) -> PdfCCITTModeKind raise PdfError {
  let mut bits = 0
  for width in 1..<=24 {
    bits = (bits << 1) | input.get_bit_int()
    for code in pdf_ccitt_mode_codes {
      if code.width == width && code.bits == bits {
        return code.mode
      }
    }
  }
  raise InvalidCCITTData
}

///|
fn pdf_ccitt_write_code(
  output : BitWriter,
  table : ArrayView[PdfCCITTCode],
  run : Int,
  makeup : Bool,
) -> Unit raise PdfError {
  for code in table {
    if code.run == run && code.makeup == makeup {
      output.put_value_int(code.width, code.bits)
      return
    }
  }
  raise InvalidCCITTData
}

///|
fn pdf_ccitt_write_eol(output : BitWriter) -> Unit raise PdfError {
  pdf_ccitt_write_code(output, pdf_ccitt_white_codes[:], -1, false)
}

///|
fn pdf_ccitt_write_mode(
  output : BitWriter,
  mode : PdfCCITTModeKind,
) -> Unit raise PdfError {
  match mode {
    CCITTPass => output.put_value_int(4, 0b0001)
    CCITTHorizontal => output.put_value_int(3, 0b001)
    CCITTVertical(0) => output.put_value_int(1, 0b1)
    CCITTVertical(-1) => output.put_value_int(3, 0b011)
    CCITTVertical(1) => output.put_value_int(3, 0b010)
    CCITTVertical(-2) => output.put_value_int(6, 0b000011)
    CCITTVertical(2) => output.put_value_int(6, 0b000010)
    CCITTVertical(-3) => output.put_value_int(7, 0b0000011)
    CCITTVertical(3) => output.put_value_int(7, 0b0000010)
    CCITTEOFB => output.put_value_int(24, 0b000000000001000000000001)
    CCITTUncompressed => raise CCITTNotSupported("CCITT Uncompressed")
    CCITTVertical(_) => raise InvalidCCITTData
  }
}

///|
fn pdf_ccitt_write_run(
  output : BitWriter,
  white : Bool,
  length : Int,
) -> Unit raise PdfError {
  if length < 0 {
    raise InvalidCCITTData
  }
  let table = if white {
    pdf_ccitt_white_codes[:]
  } else {
    pdf_ccitt_black_codes[:]
  }
  let mut remaining = length
  while remaining >= 64 {
    let mut best = 0
    for code in table {
      if code.makeup && code.run <= remaining && code.run > best {
        best = code.run
      }
    }
    pdf_ccitt_write_code(output, table, best, true)
    remaining -= best
  }
  pdf_ccitt_write_code(output, table, remaining, false)
}

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
      let a1 = pdf_ccitt_find_b1(line[:], column, white, whiteval, blackval)
      let a2 = pdf_ccitt_find_b2(line[:], column, white, whiteval, blackval)
      let b1 = pdf_ccitt_find_b1(
        reference[:],
        column,
        white,
        whiteval,
        blackval,
      )
      let b2 = pdf_ccitt_find_b2(
        reference[:],
        column,
        white,
        whiteval,
        blackval,
      )
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

///|
fn pdf_ccitt_blank_line(columns : Int, whiteval : Int) -> Array[Int] {
  [
    for _ in 0..<columns => whiteval
  ]
}

///|
fn pdf_ccitt_output_span(
  line : Array[Int],
  column : Int,
  length : Int,
  value : Int,
) -> Int raise PdfError {
  if length < 0 || column < 0 || column + length > line.length() {
    raise InvalidCCITTData
  }
  for index in column..<(column + length) {
    line[index] = value
  }
  column + length
}

///|
fn pdf_ccitt_output_line(
  output : BitWriter,
  line : ArrayView[Int],
) -> Unit raise PdfError {
  for bit in line {
    output.put_bit(bit)
  }
  output.align()
}

///|
fn pdf_ccitt_find_value(line : ArrayView[Int], start : Int, value : Int) -> Int {
  let mut position = start
  while position >= 0 && position < line.length() && line[position] != value {
    position += 1
  }
  if position > line.length() {
    line.length()
  } else {
    position
  }
}

///|
fn pdf_ccitt_find_b1(
  reference : ArrayView[Int],
  column : Int,
  white : Bool,
  whiteval : Int,
  blackval : Int,
) -> Int {
  let current = if white { whiteval } else { blackval }
  let opposite = if white { blackval } else { whiteval }
  let mut position = column
  if !(column == 0 && white) {
    position = pdf_ccitt_find_value(reference, position, current)
  }
  pdf_ccitt_find_value(reference, position, opposite)
}

///|
fn pdf_ccitt_find_b2(
  reference : ArrayView[Int],
  column : Int,
  white : Bool,
  whiteval : Int,
  blackval : Int,
) -> Int {
  let current = if white { whiteval } else { blackval }
  let opposite = if white { blackval } else { whiteval }
  let mut position = column
  if !(column == 0 && white) {
    position = pdf_ccitt_find_value(reference, position, current)
  }
  position = pdf_ccitt_find_value(reference, position, opposite)
  pdf_ccitt_find_value(reference, position, current)
}

///|
fn pdf_ccitt_decode_g3_1d(
  input : BitStream,
  output : BitWriter,
  params : PdfCCITTParams,
  whiteval : Int,
  blackval : Int,
) -> PdfBytes raise PdfError {
  let mut row = 0
  let mut column = 0
  let mut line = pdf_ccitt_blank_line(params.columns, whiteval)
  let mut white = true
  let mut finished = false
  try {
    while !finished {
      if params.rows > 0 && row >= params.rows {
        finished = true
      }
      if !finished && column >= params.columns {
        pdf_ccitt_output_line(output, line[:])
        row += 1
        column = 0
        line = pdf_ccitt_blank_line(params.columns, whiteval)
        white = true
        if params.encoded_byte_align {
          input.align()
        }
      } else if !finished {
        let run = pdf_ccitt_read_run(input, white)
        if run < 0 {
          if column > 0 {
            column = pdf_ccitt_output_span(
              line,
              column,
              params.columns - column,
              whiteval,
            )
          }
        } else {
          column = pdf_ccitt_output_span(
            line,
            column,
            run,
            if white {
              whiteval
            } else {
              blackval
            },
          )
          white = !white
        }
      }
    }
    output.to_bytes()
  } catch {
    EndOfInput => output.to_bytes()
    InvalidCCITTData => raise InvalidCCITTData
    _ => raise InvalidCCITTData
  }
}

///|
fn pdf_ccitt_decode_g4(
  input : BitStream,
  output : BitWriter,
  params : PdfCCITTParams,
  whiteval : Int,
  blackval : Int,
) -> PdfBytes raise PdfError {
  let mut row = 0
  let mut column = 0
  let mut reference = pdf_ccitt_blank_line(params.columns, whiteval)
  let mut line = pdf_ccitt_blank_line(params.columns, whiteval)
  let mut white = true
  let mut finished = false
  try {
    while !finished {
      if params.rows > 0 && row >= params.rows {
        finished = true
      }
      if !finished && column >= params.columns {
        pdf_ccitt_output_line(output, line[:])
        reference = line.copy()
        line = pdf_ccitt_blank_line(params.columns, whiteval)
        row += 1
        column = 0
        white = true
        if params.encoded_byte_align {
          input.align()
        }
      } else if !finished {
        match pdf_ccitt_read_mode(input) {
          CCITTPass =>
            column = pdf_ccitt_output_span(
              line,
              column,
              pdf_ccitt_find_b2(reference[:], column, white, whiteval, blackval) -
              column,
              if white {
                whiteval
              } else {
                blackval
              },
            )
          CCITTHorizontal =>
            if white {
              column = pdf_ccitt_output_span(
                line,
                column,
                pdf_ccitt_read_run(input, true),
                whiteval,
              )
              column = pdf_ccitt_output_span(
                line,
                column,
                pdf_ccitt_read_run(input, false),
                blackval,
              )
            } else {
              column = pdf_ccitt_output_span(
                line,
                column,
                pdf_ccitt_read_run(input, false),
                blackval,
              )
              column = pdf_ccitt_output_span(
                line,
                column,
                pdf_ccitt_read_run(input, true),
                whiteval,
              )
            }
          CCITTVertical(delta) => {
            column = pdf_ccitt_output_span(
              line,
              column,
              pdf_ccitt_find_b1(reference[:], column, white, whiteval, blackval) -
              column -
              delta,
              if white {
                whiteval
              } else {
                blackval
              },
            )
            white = !white
          }
          CCITTEOFB => finished = true
          CCITTUncompressed => raise CCITTNotSupported("CCITT Uncompressed")
        }
      }
    }
    output.to_bytes()
  } catch {
    EndOfInput => output.to_bytes()
    CCITTNotSupported(reason) => raise CCITTNotSupported(reason)
    InvalidCCITTData => raise InvalidCCITTData
    _ => raise InvalidCCITTData
  }
}

///|
fn pdf_ccitt_decode_view(
  data : BytesView,
  params : PdfCCITTParams,
) -> PdfBytes raise PdfError {
  if params.columns <= 0 ||
    params.rows < 0 ||
    params.damaged_rows_before_error < 0 {
    raise InvalidCCITTData
  }
  ignore(params.end_of_line)
  ignore(params.end_of_block)
  let whiteval = if params.black_is_1 { 0 } else { 1 }
  let blackval = if params.black_is_1 { 1 } else { 0 }
  let input = bitstream_of_view(data)
  let output = bit_writer_new()
  if params.k > 0 {
    raise CCITTNotSupported("CCITTFax K > 0")
  } else if params.k < 0 {
    pdf_ccitt_decode_g4(input, output, params, whiteval, blackval)
  } else {
    pdf_ccitt_decode_g3_1d(input, output, params, whiteval, blackval)
  }
}
