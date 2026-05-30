///|
fn pdf_ccitt_decode_g3_1d(
  input : @core.BitStream,
  output : @core.BitWriter,
  params : PdfCCITTParams,
  whiteval : Int,
  blackval : Int,
) -> @core.PdfBytes raise @core.PdfError {
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
        pdf_ccitt_output_line(output, line)
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
  input : @core.BitStream,
  output : @core.BitWriter,
  params : PdfCCITTParams,
  whiteval : Int,
  blackval : Int,
) -> @core.PdfBytes raise @core.PdfError {
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
        pdf_ccitt_output_line(output, line)
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
              pdf_ccitt_find_b2(reference, column, white, whiteval, blackval) -
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
              pdf_ccitt_find_b1(reference, column, white, whiteval, blackval) -
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
          CCITTUncompressed =>
            raise @core.PdfError::CCITTNotSupported("CCITT Uncompressed")
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
) -> @core.PdfBytes raise @core.PdfError {
  if params.columns <= 0 ||
    params.rows < 0 ||
    params.damaged_rows_before_error < 0 {
    raise InvalidCCITTData
  }
  ignore(params.end_of_line)
  ignore(params.end_of_block)
  let whiteval = if params.black_is_1 { 0 } else { 1 }
  let blackval = if params.black_is_1 { 1 } else { 0 }
  let input = @core.bitstream_of_view(data)
  let output = @core.bit_writer_new()
  if params.k > 0 {
    raise CCITTNotSupported("CCITTFax K > 0")
  } else if params.k < 0 {
    pdf_ccitt_decode_g4(input, output, params, whiteval, blackval)
  } else {
    pdf_ccitt_decode_g3_1d(input, output, params, whiteval, blackval)
  }
}
