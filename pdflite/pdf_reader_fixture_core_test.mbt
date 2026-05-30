///|
#warnings("-unused_value")
fn reader_bytes_for_test(values : ArrayView[Int]) -> @core.PdfBytes {
  try! @core.pdf_bytes_of_int_array(values)
}

///|
#warnings("-unused_value")
fn reader_stream_bytes_for_test(
  stream : @syntax.PdfStream,
) -> @core.PdfBytes raise {
  @syntax.pdf_stream(stream.dictionary, stream.data).stream_bytes()
}

///|
#warnings("-unused_value")
fn reader_assert_deferred_stream_data_for_test(
  stream : @syntax.PdfStream,
  expected : @core.PdfBytes,
) -> Unit raise {
  guard stream.data is StreamToGet(_) else {
    fail("expected deferred stream data")
  }
  @test.assert_eq(reader_stream_bytes_for_test(stream), expected)
}

///|
#warnings("-unused_value")
fn reader_push_byte(output : Array[Byte], value : Int) -> Unit {
  output.push(value.to_byte())
}

///|
#warnings("-unused_value")
fn reader_push_ascii(output : Array[Byte], text : String) -> Unit {
  for byte in @ascii.encode(text)[:] {
    output.push(byte)
  }
}

///|
#warnings("-unused_value")
fn reader_push_padded_decimal(
  output : Array[Byte],
  value : Int,
  width : Int,
) -> Unit {
  let text = value.to_string()
  if text.length() < width {
    for _ in 0..<(width - text.length()) {
      reader_push_byte(output, 48)
    }
  }
  reader_push_ascii(output, text)
}

///|
#warnings("-unused_value")
fn reader_push_big_endian(
  output : Array[Byte],
  value : Int,
  width : Int,
) -> Unit {
  let mut divisor = 1
  if width > 1 {
    for _ in 1..<width {
      divisor *= 256
    }
  }
  let mut remaining_divisor = divisor
  while remaining_divisor > 0 {
    reader_push_byte(output, value / remaining_divisor % 256)
    remaining_divisor /= 256
  }
}

///|
#warnings("-unused_value")
fn reader_push_xref_stream_entry(
  output : Array[Byte],
  kind : Int,
  field2 : Int,
  field3 : Int,
) -> Unit {
  reader_push_byte(output, kind)
  reader_push_big_endian(output, field2, 4)
  reader_push_big_endian(output, field3, 2)
}

///|
#warnings("-unused_value")
fn reader_push_xref_stream_default_in_use_entry(
  output : Array[Byte],
  offset : Int,
  generation : Int,
) -> Unit {
  reader_push_big_endian(output, offset, 4)
  reader_push_big_endian(output, generation, 2)
}

///|
#warnings("-unused_value")
fn reader_png_none_predictor_rows_for_test(
  data : ArrayView[Byte],
  columns : Int,
) -> @core.PdfBytes {
  let output : Array[Byte] = []
  let row_count = (data.length() + columns - 1) / columns
  for row in 0..<row_count {
    let row_start = row * columns
    output.push(0)
    let row_end = if row_start + columns > data.length() {
      data.length()
    } else {
      row_start + columns
    }
    for index in row_start..<row_end {
      output.push(data[index])
    }
  }
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_push_xref_entry(
  output : Array[Byte],
  offset : Int,
  generation : Int,
) -> Unit {
  reader_push_padded_decimal(output, offset, 10)
  reader_push_byte(output, 32)
  reader_push_padded_decimal(output, generation, 5)
  reader_push_ascii(output, " n \n")
}

///|
#warnings("-unused_value")
fn reader_pdf_ascii(text : String) -> @core.PdfBytes {
  @ascii.encode(text)
}

///|
#warnings("-unused_value")
fn reader_cr_line_endings_for_test(bytes : @core.PdfBytes) -> @core.PdfBytes {
  let output : Array[Byte] = []
  for byte in bytes {
    let replacement = if byte.to_int() == 10 { (13).to_byte() } else { byte }
    output.push(replacement)
  }
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_wrap_view_for_test(
  prefix : String,
  data : BytesView,
  suffix : String,
) -> @core.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, prefix)
  for byte in data {
    output.push(byte)
  }
  reader_push_ascii(output, suffix)
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_push_indirect_object(
  output : Array[Byte],
  number : Int,
  generation : Int,
  body : String,
) -> Int {
  let offset = output.length()
  reader_push_ascii(output, number.to_string())
  reader_push_byte(output, 32)
  reader_push_ascii(output, generation.to_string())
  reader_push_ascii(output, " obj\n")
  reader_push_ascii(output, body)
  reader_push_ascii(output, "\nendobj\n")
  offset
}

///|
#warnings("-unused_value")
fn reader_push_classic_trailer(
  output : Array[Byte],
  xref_offset : Int,
  size : Int,
) -> Unit {
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size ")
  reader_push_ascii(output, size.to_string())
  reader_push_ascii(output, " >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
}
