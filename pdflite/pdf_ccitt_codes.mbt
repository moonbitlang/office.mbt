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
    pdf_ccitt_black_codes
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
  pdf_ccitt_write_code(output, pdf_ccitt_white_codes, -1, false)
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
    pdf_ccitt_black_codes
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
