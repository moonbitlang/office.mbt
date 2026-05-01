///|
fn reader_bytes_for_test(values : ArrayView[Int]) -> @pdflite.PdfBytes {
  try! @pdflite.pdf_bytes_of_int_array(values)
}

///|
fn reader_push_byte(output : Array[Byte], value : Int) -> Unit {
  output.push(value.to_byte())
}

///|
fn reader_push_ascii(output : Array[Byte], text : String) -> Unit {
  for byte in @ascii.encode(text)[:] {
    output.push(byte)
  }
}

///|
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
fn reader_pdf_ascii(text : String) -> @pdflite.PdfBytes {
  @ascii.encode(text)
}

///|
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

///|
fn reader_classic_pdf_with_xref_body(
  xref_body : String,
  trailer_body : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n")
  reader_push_ascii(output, xref_body)
  reader_push_ascii(output, "trailer\n")
  reader_push_ascii(output, trailer_body)
  reader_push_ascii(output, "\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_classic_pdf_without_trailer_after_xref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  reader_push_ascii(output, "startxref\n")
  let xref_digits_position = output.length()
  reader_push_ascii(output, "0000000000\n%%EOF\n")
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 1\n0000000000 65535 f \n")
  let digits = @ascii.encode(xref_offset.to_string())
  for i = 0; i < digits.length(); i = i + 1 {
    output[xref_digits_position + 10 - digits.length() + i] = digits[i]
  }
  Bytes::from_array(output)
}

///|
fn reader_classic_pdf_with_self_prev_xref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 1\n0000000000 65535 f \n")
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 1 /Prev ")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, " >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_classic_pdf_with_missing_indirect_stream_length() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let stream_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Length 9 0 R >>\nstream\nHello\nendstream",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, stream_offset, 0)
  reader_push_classic_trailer(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn reader_classic_pdf_with_non_integer_stream_length() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let stream_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Length 2 0 R >>\nstream\nHello\nendstream",
  )
  let length_offset = reader_push_indirect_object(output, 2, 0, "/Name")
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 3\n0000000000 65535 f \n")
  reader_push_xref_entry(output, stream_offset, 0)
  reader_push_xref_entry(output, length_offset, 0)
  reader_push_classic_trailer(output, xref_offset, 3)
  Bytes::from_array(output)
}

///|
fn reader_classic_pdf_with_mismatched_stream_length_xref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let stream_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Length 2 0 R >>\nstream\nHello\nendstream",
  )
  let length_offset = reader_push_indirect_object(output, 2, 1, "5")
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 3\n0000000000 65535 f \n")
  reader_push_xref_entry(output, stream_offset, 0)
  reader_push_xref_entry(output, length_offset, 0)
  reader_push_classic_trailer(output, xref_offset, 3)
  Bytes::from_array(output)
}

///|
fn reader_classic_pdf_with_stream_length_stream_object() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let stream_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Length 2 0 R >>\nstream\nHello\nendstream",
  )
  let length_offset = reader_push_indirect_object(
    output, 2, 0, "<< /Length 1 >>\nstream\nA\nendstream",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 3\n0000000000 65535 f \n")
  reader_push_xref_entry(output, stream_offset, 0)
  reader_push_xref_entry(output, length_offset, 0)
  reader_push_classic_trailer(output, xref_offset, 3)
  Bytes::from_array(output)
}

///|
fn reader_classic_pdf_with_negative_stream_length() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let stream_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Length -1 >>\nstream\nHello\nendstream",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, stream_offset, 0)
  reader_push_classic_trailer(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn reader_classic_pdf_with_mismatched_object_xref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let object_offset = reader_push_indirect_object(output, 2, 0, "2")
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n1 1\n")
  reader_push_xref_entry(output, object_offset, 0)
  reader_push_classic_trailer(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn reader_classic_pdf_with_unparseable_xref_object() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let object_offset = output.length()
  reader_push_ascii(output, "notobject\n")
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n1 1\n")
  reader_push_xref_entry(output, object_offset, 0)
  reader_push_classic_trailer(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn reader_classic_pdf_with_indirect_stream_length() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let stream_offset = output.length()
  reader_push_ascii(
    output, "1 0 obj\n<< /Length 2 0 R >>\nstream\nHello\nendstream\nendobj\n",
  )
  let length_offset = output.length()
  reader_push_ascii(output, "2 0 obj\n5\nendobj\n")
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 3\n0000000000 65535 f \n")
  reader_push_xref_entry(output, stream_offset, 0)
  reader_push_xref_entry(output, length_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 3 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_xref_stream_pdf() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, catalog_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  reader_push_ascii(output, "2 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(output, " /Size 3 /Root 1 0 R /W [1 4 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_xref_stream_pdf_with_index() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let value_offset = reader_push_indirect_object(output, 3, 0, "7")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, catalog_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, value_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  reader_push_ascii(output, "4 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(
    output, " /Size 5 /Root 1 0 R /W [1 4 2] /Index [0 2 3 2] >>\nstream\n",
  )
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_xref_stream_pdf_with_ascii_hex_filter() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, catalog_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  let encoded = @pdflite.pdf_ascii_hex_encode(Bytes::from_array(stream_data))
  reader_push_ascii(output, "2 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, encoded.length().to_string())
  reader_push_ascii(
    output, " /Size 3 /Root 1 0 R /W [1 4 2] /Filter /ASCIIHexDecode >>\nstream\n",
  )
  for byte in encoded {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_hybrid_xref_stream_pdf() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let value_offset = reader_push_indirect_object(output, 2, 0, "7")
  let xref_stream_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, value_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_stream_offset, 0)
  reader_push_ascii(output, "3 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(output, " /Size 4 /W [1 4 2] /Index [0 1 2 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\n")
  let classic_xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 4 /XRefStm ")
  reader_push_ascii(output, xref_stream_offset.to_string())
  reader_push_ascii(output, " >>\nstartxref\n")
  reader_push_ascii(output, classic_xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_linearized_classic_pdf(value : String) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let linearized_offset = reader_push_indirect_object(
    output,
    1,
    0,
    "<< /Linearized " + value + " /L 0 >>",
  )
  let catalog_offset = reader_push_indirect_object(
    output, 2, 0, "<< /Type /Catalog >>",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 3\n0000000000 65535 f \n")
  reader_push_xref_entry(output, linearized_offset, 0)
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 2 0 R /Size 3 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_classic_pdf_with_leading_junk() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\nnotobject\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_classic_trailer(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
fn reader_malformed_pdf_without_startxref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  ignore(reader_push_indirect_object(output, 1, 0, "<< /Type /Catalog >>"))
  ignore(reader_push_indirect_object(output, 2, 0, "7"))
  reader_push_ascii(output, "trailer\nnotdict\n")
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 99 /Prev 4 >>\n")
  reader_push_ascii(output, "trailer\n<< /Size 99 >>\n")
  reader_push_ascii(output, "trailer\n<< /Root 2 0 R /Size 99 >>\n")
  Bytes::from_array(output)
}

///|
fn reader_malformed_pdf_with_bad_startxref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  ignore(reader_push_indirect_object(output, 1, 0, "<< /Type /Catalog >>"))
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\n")
  reader_push_ascii(output, "startxref\n9\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_malformed_pdf_with_bad_xref_entry() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  ignore(reader_push_indirect_object(output, 1, 0, "<< /Type /Catalog >>"))
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \nnot-a-row\n")
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_malformed_pdf_with_bad_trailer_object() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer\n1\n")
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_malformed_pdf_with_missing_root_trailer() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Size 2 >>\n")
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_xref_stream_pdf_with_prev_update() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let original_offset = reader_push_indirect_object(output, 1, 0, "1")
  let base_xref = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, original_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\nstartxref\n")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  let updated_offset = reader_push_indirect_object(output, 1, 0, "2")
  let xref_stream_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, updated_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_stream_offset, 0)
  reader_push_ascii(output, "2 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(output, " /Size 3 /Root 1 0 R /Prev ")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, " /W [1 4 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  reader_push_ascii(output, xref_stream_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_xref_stream_pdf_with_prev_deleted_object() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let original_offset = reader_push_indirect_object(output, 1, 0, "1")
  let base_xref = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, original_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\nstartxref\n")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  let xref_stream_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 0, 0, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_stream_offset, 0)
  reader_push_ascii(output, "2 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(output, " /Size 3 /Root 1 0 R /Prev ")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, " /W [1 4 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  reader_push_ascii(output, xref_stream_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_xref_stream_pdf_with_object_stream_number(
  stored_object_number : Int,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let object_stream_data : Array[Byte] = []
  reader_push_ascii(object_stream_data, stored_object_number.to_string())
  reader_push_ascii(object_stream_data, " 0 ")
  let first = object_stream_data.length()
  reader_push_ascii(object_stream_data, "<< /Answer 42 >>")
  let object_stream_offset = output.length()
  reader_push_ascii(output, "3 0 obj\n<< /Type /ObjStm /N 1 /First ")
  reader_push_ascii(output, first.to_string())
  reader_push_ascii(output, " /Length ")
  reader_push_ascii(output, object_stream_data.length().to_string())
  reader_push_ascii(output, " >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, catalog_offset, 0)
  reader_push_xref_stream_entry(stream_data, 2, 3, 0)
  reader_push_xref_stream_entry(stream_data, 1, object_stream_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  reader_push_ascii(output, "4 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(output, " /Size 5 /Root 1 0 R /W [1 4 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_xref_stream_pdf_with_object_stream() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_object_stream_number(2)
}

///|
fn reader_xref_stream_pdf_with_mismatched_object_stream() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_object_stream_number(5)
}

///|
fn reader_startxref_object_pdf(body : String) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let offset = reader_push_indirect_object(output, 2, 0, body)
  reader_push_ascii(output, "startxref\n")
  reader_push_ascii(output, offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_classic_pdf_with_prev_xref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let original_offset = output.length()
  reader_push_ascii(output, "1 0 obj\n1\nendobj\n")
  let base_xref = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, original_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\nstartxref\n")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  let updated_offset = output.length()
  reader_push_ascii(output, "1 0 obj\n2\nendobj\n")
  let second_offset = output.length()
  reader_push_ascii(output, "2 0 obj\n3\nendobj\n")
  let final_xref = output.length()
  reader_push_ascii(output, "xref\n1 2\n")
  reader_push_xref_entry(output, updated_offset, 0)
  reader_push_xref_entry(output, second_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 3 /Prev ")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, " >>\nstartxref\n")
  reader_push_ascii(output, final_xref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
fn reader_classic_pdf_with_prev_deleted_object() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let original_offset = output.length()
  reader_push_ascii(output, "1 0 obj\n1\nendobj\n")
  let base_xref = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, original_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\nstartxref\n")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  let final_xref = output.length()
  reader_push_ascii(
    output, "xref\n1 1\n0000000000 00000 f \ntrailer\n<< /Root 1 0 R /Size 2 /Prev ",
  )
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, " >>\nstartxref\n")
  reader_push_ascii(output, final_xref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
test "ByteCursor read_pdf_header finds header and sets input offset" {
  let cursor = @pdflite.byte_cursor_of_bytes(
    reader_bytes_for_test([0, 1, 2, 37, 80, 68, 70, 45, 49, 46, 55, 10, 65]),
  )
  @test.assert_eq(try! cursor.read_pdf_header(), { major: 1, minor: 7 })
  @test.assert_eq(cursor.absolute_position(), 11)
  @test.assert_eq(cursor.position(), 8)
  @test.assert_eq(cursor.peek_byte(), 10)
}

///|
test "pdf_read_header_from_bytes defaults to PDF 2.0 when no header is found" {
  @test.assert_eq(
    try! @pdflite.pdf_read_header_from_bytes(reader_bytes_for_test([65, 66])),
    @pdflite.pdf_default_version,
  )
}

///|
test "pdf_read_header_from_bytes ignores malformed header digits" {
  @test.assert_eq(
    try! @pdflite.pdf_read_header_from_bytes(reader_pdf_ascii("%PDF-A.B\n")),
    @pdflite.pdf_default_version,
  )
}

///|
test "pdf_document_of_parsed_indirect_objects preserves version and generations" {
  let document = @pdflite.pdf_document_of_parsed_indirect_objects(
    [
      { number: 7, generation: 2, object: PdfInteger(70) },
      { number: 3, generation: 0, object: PdfBoolean(true) },
    ],
    version={ major: 1, minor: 6 },
  )
  @test.assert_eq(document.version(), (1, 6))
  @test.assert_eq(document.object_numbers(), [3, 7])
  @test.assert_eq(document.lookup_object_or_null(7), PdfInteger(70))
}

///|
test "pdf_read_primitive_document_from_bytes loads non-stream indirect objects" {
  let document = try! @pdflite.pdf_read_primitive_document_from_bytes(
    reader_bytes_for_test([
      37, 80, 68, 70, 45, 49, 46, 52, 10, 49, 32, 48, 32, 111, 98, 106, 10, 60, 60,
      32, 47, 84, 121, 112, 101, 32, 47, 67, 97, 116, 97, 108, 111, 103, 32, 47,
      80, 97, 103, 101, 115, 32, 50, 32, 48, 32, 82, 32, 62, 62, 10, 101, 110, 100,
      111, 98, 106, 10, 50, 32, 48, 32, 111, 98, 106, 10, 91, 49, 32, 50, 93, 10,
      101, 110, 100, 111, 98, 106, 10, 120, 114, 101, 102,
    ]),
  )
  @test.assert_eq(document.version(), (1, 4))
  @test.assert_eq(document.object_numbers(), [1, 2])
  @test.assert_eq(
    document.lookup_object_or_null(2),
    @pdflite.pdf_array([PdfInteger(1), PdfInteger(2)]),
  )
}

///|
test "pdf_parse_stream_object_from_bytes parses direct-length stream objects" {
  let parsed = try! @pdflite.pdf_parse_stream_object_from_bytes(
    reader_bytes_for_test([
      55, 32, 48, 32, 111, 98, 106, 10, 60, 60, 32, 47, 76, 101, 110, 103, 116, 104,
      32, 53, 32, 62, 62, 10, 115, 116, 114, 101, 97, 109, 10, 72, 101, 108, 108,
      111, 10, 101, 110, 100, 115, 116, 114, 101, 97, 109, 10, 101, 110, 100, 111,
      98, 106,
    ]),
  )
  @test.assert_eq(parsed.number, 7)
  @test.assert_eq(parsed.generation, 0)
  guard parsed.object is PdfStreamObject(stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(
        reader_bytes_for_test([47, 76, 101, 110, 103, 116, 104]),
      ),
    ),
    Some(PdfInteger(5)),
  )
  @test.assert_eq(
    stream.data,
    StreamGot(reader_bytes_for_test([72, 101, 108, 108, 111])),
  )
}

///|
test "pdf_parse_stream_object_from_bytes accepts CR and CRLF stream line breaks" {
  let parsed = try! @pdflite.pdf_parse_stream_object_from_bytes(
    reader_pdf_ascii(
      "7 0 obj\n<< /Length 5 >>\nstream\rHello\rendstream\nendobj",
    ),
  )
  guard parsed.object is PdfStreamObject(stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(stream.data, StreamGot(reader_pdf_ascii("Hello")))

  let crlf = try! @pdflite.pdf_parse_stream_object_from_bytes(
    reader_pdf_ascii(
      "8 0 obj\n<< /Length 5 >>\nstream\r\nWorld\r\nendstream\nendobj",
    ),
  )
  guard crlf.object is PdfStreamObject(crlf_stream) else {
    fail("expected PdfStreamObject")
  }
  @test.assert_eq(crlf_stream.data, StreamGot(reader_pdf_ascii("World")))
}

///|
test "pdf_parse_stream_object_from_bytes reports missing stream length" {
  let result : Result[@pdflite.PdfParsedIndirectObject, Error] = try? @pdflite.pdf_parse_stream_object_from_bytes(
    reader_bytes_for_test([
      55, 32, 48, 32, 111, 98, 106, 10, 60, 60, 32, 62, 62, 10, 115, 116, 114, 101,
      97, 109, 10,
    ]),
  )
  guard result is Err(@pdflite.PdfError::StreamLengthExpected) else {
    fail("expected StreamLengthExpected")
  }
}

///|
test "pdf_parse_stream_object_from_bytes reports malformed stream keyword" {
  let result : Result[@pdflite.PdfParsedIndirectObject, Error] = try? @pdflite.pdf_parse_stream_object_from_bytes(
    reader_pdf_ascii(
      "7 0 obj\n<< /Length 5 >>\nstram\nHello\nendstream\nendobj",
    ),
  )
  guard result is Err(@pdflite.PdfError::ParseStreamExpected) else {
    fail("expected ParseStreamExpected")
  }
}

///|
test "pdf_read_primitive_document_from_bytes includes direct-length stream objects" {
  let document = try! @pdflite.pdf_read_primitive_document_from_bytes(
    reader_bytes_for_test([
      37, 80, 68, 70, 45, 49, 46, 52, 10, 49, 32, 48, 32, 111, 98, 106, 10, 60, 60,
      32, 47, 76, 101, 110, 103, 116, 104, 32, 53, 32, 62, 62, 10, 115, 116, 114,
      101, 97, 109, 10, 72, 101, 108, 108, 111, 10, 101, 110, 100, 115, 116, 114,
      101, 97, 109, 10, 101, 110, 100, 111, 98, 106, 10, 50, 32, 48, 32, 111, 98,
      106, 10, 110, 117, 108, 108, 10, 101, 110, 100, 111, 98, 106, 10, 120, 114,
      101, 102,
    ]),
  )
  @test.assert_eq(document.object_numbers(), [1, 2])
  guard document.lookup_object_or_null(1) is PdfStreamObject(stream) else {
    fail("expected stream object")
  }
  @test.assert_eq(
    stream.data,
    StreamGot(reader_bytes_for_test([72, 101, 108, 108, 111])),
  )
  @test.assert_eq(document.lookup_object_or_null(2), PdfNull)
}

///|
test "pdf_read_classic_document_from_bytes uses xref and trailer root" {
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 4)
  document.set_root(1)
  let type_name = @pdflite.pdf_name_of_bytes(
    reader_bytes_for_test([47, 84, 121, 112, 101]),
  )
  let catalog = @pdflite.pdf_dictionary([
    (
      type_name,
      PdfNameObject(
        @pdflite.pdf_name_of_bytes(
          reader_bytes_for_test([47, 67, 97, 116, 97, 108, 111, 103]),
        ),
      ),
    ),
  ])
  document.add_object_given_number(1, catalog)
  let rendered = try! @pdflite.pdf_write_document(document)
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(rendered)
  @test.assert_eq(parsed.version(), (1, 4))
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.first_xref() > 0, true)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(parsed.lookup_object_or_null(1), catalog)
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_bytes_for_test([47, 82, 111, 111, 116])),
    ),
    Some(PdfIndirect(1)),
  )
}

///|
test "pdf_read_classic_document_from_bytes reads stream objects by xref" {
  let document = @pdflite.pdf_document_empty()
  document.set_version(1, 4)
  document.set_root(1)
  let stream = @pdflite.pdf_stream(
    @pdflite.pdf_dictionary([]),
    StreamGot(reader_bytes_for_test([72, 101, 108, 108, 111])),
  )
  document.add_object_given_number(1, stream)
  let rendered = try! @pdflite.pdf_write_document(document)
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(rendered)
  guard parsed.lookup_object_or_null(1) is PdfStreamObject(parsed_stream) else {
    fail("expected stream object")
  }
  @test.assert_eq(
    parsed_stream.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(
        reader_bytes_for_test([47, 76, 101, 110, 103, 116, 104]),
      ),
    ),
    Some(PdfInteger(5)),
  )
  @test.assert_eq(
    parsed_stream.data,
    StreamGot(reader_bytes_for_test([72, 101, 108, 108, 111])),
  )
}

///|
test "pdf_read_document_from_bytes reads default-index xref streams" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf(),
  )
  @test.assert_eq(parsed.version(), (1, 5))
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(
    parsed.lookup_object_or_null(1),
    PdfDictionary([
      (
        @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
        PdfNameObject(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Catalog"))),
      ),
    ]),
  )
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/W"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes reads xref stream Index ranges" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_index(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 3])
  @test.assert_eq(parsed.lookup_object_or_null(3), PdfInteger(7))
}

///|
test "pdf_read_document_from_bytes decodes filtered xref streams" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_ascii_hex_filter(),
  )
  @test.assert_eq(parsed.object_numbers(), [1])
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Filter"))),
    None,
  )
}

///|
test "pdf_read_document_from_bytes follows classic trailer XRefStm" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_hybrid_xref_stream_pdf(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(7))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/XRefStm"))),
    None,
  )
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Size"))),
    Some(PdfInteger(3)),
  )
}

///|
test "pdf_read_document_from_bytes records linearized first-object marker" {
  let integer_marker = try! @pdflite.pdf_read_document_from_bytes(
    reader_linearized_classic_pdf("1"),
  )
  @test.assert_eq(integer_marker.was_linearized(), true)
  @test.assert_eq(integer_marker.root(), 2)

  let real_marker = try! @pdflite.pdf_read_document_from_bytes(
    reader_linearized_classic_pdf("1.0"),
  )
  @test.assert_eq(real_marker.was_linearized(), true)

  let non_numeric_marker = try! @pdflite.pdf_read_document_from_bytes(
    reader_linearized_classic_pdf("/Name"),
  )
  @test.assert_eq(non_numeric_marker.was_linearized(), false)

  let leading_junk = try! @pdflite.pdf_read_document_from_bytes(
    reader_classic_pdf_with_leading_junk(),
  )
  @test.assert_eq(leading_junk.was_linearized(), false)
}

///|
test "pdf_read_document_from_bytes reconstructs missing startxref PDFs" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_without_startxref(),
  )
  @test.assert_eq(parsed.version(), (1, 4))
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(
    parsed.lookup_object_or_null(1),
    PdfDictionary([
      (
        @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
        PdfNameObject(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Catalog"))),
      ),
    ]),
  )
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Prev"))),
    None,
  )
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Size"))),
    Some(PdfInteger(3)),
  )
}

///|
test "pdf_read_document_from_bytes reconstructs bad startxref PDFs" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_bad_startxref(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
}

///|
test "pdf_read_document_from_bytes reconstructs bad xref rows" {
  let strict : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_malformed_pdf_with_bad_xref_entry(),
  )
  guard strict is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected strict XRefEntryExpected")
  }

  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_bad_xref_entry(),
  )
  @test.assert_eq(parsed.first_xref(), 0)
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [1])
}

///|
test "pdf_read_document_from_bytes reconstructs malformed trailers" {
  let strict_bad_trailer : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_malformed_pdf_with_bad_trailer_object(),
  )
  guard strict_bad_trailer is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected strict TrailerExpected")
  }

  let bad_trailer = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_bad_trailer_object(),
  )
  @test.assert_eq(bad_trailer.first_xref(), 0)
  @test.assert_eq(bad_trailer.root(), 1)
  @test.assert_eq(bad_trailer.object_numbers(), [1])

  let strict_missing_root : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_malformed_pdf_with_missing_root_trailer(),
  )
  guard strict_missing_root is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected strict RootExpected")
  }

  let missing_root = try! @pdflite.pdf_read_document_from_bytes(
    reader_malformed_pdf_with_missing_root_trailer(),
  )
  @test.assert_eq(missing_root.first_xref(), 0)
  @test.assert_eq(missing_root.root(), 1)
  @test.assert_eq(missing_root.object_numbers(), [1])
}

///|
test "pdf_read_document_from_bytes reports missing reconstructed root" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_pdf_ascii("%PDF-1.4\n1 0 obj\n1\nendobj\n"),
  )
  guard result is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected RootExpected")
  }
}

///|
test "pdf_read_document_from_bytes propagates unreconstructable errors" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_pdf_ascii("%PDF-1.4\nstartxref\nabc\n%%EOF\n"),
  )
  guard result is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }
}

///|
test "pdf_read_document_from_bytes follows xref stream Prev chains" {
  let updated = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_prev_update(),
  )
  @test.assert_eq(updated.object_numbers(), [1])
  @test.assert_eq(updated.lookup_object_or_null(1), PdfInteger(2))
  @test.assert_eq(
    updated
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Prev"))),
    None,
  )

  let deleted = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_prev_deleted_object(),
  )
  @test.assert_eq(deleted.object_numbers(), [])
  @test.assert_eq(deleted.lookup_object_or_null(1), PdfNull)
}

///|
test "pdf_read_document_from_bytes extracts xref object-stream entries" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_object_stream(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2, 3])
  @test.assert_eq(
    parsed.lookup_object_or_null(2),
    PdfDictionary([
      (@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Answer")), PdfInteger(42)),
    ]),
  )
  guard parsed.lookup_object_or_null(3) is PdfStreamObject(object_stream) else {
    fail("expected object stream")
  }
  @test.assert_eq(
    object_stream.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Type")),
    ),
    Some(PdfNameObject(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/ObjStm")))),
  )
}

///|
test "pdf_read_document_from_bytes rejects mismatched object-stream entries" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_xref_stream_pdf_with_mismatched_object_stream(),
  )
  guard result is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }
}

///|
test "pdf_read_document_from_bytes rejects non-xref startxref objects" {
  let non_stream : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_startxref_object_pdf("7"),
  )
  guard non_stream is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected XRefExpected")
  }

  let wrong_stream_type : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_document_from_bytes(
    reader_startxref_object_pdf("<< /Length 0 >>\nstream\n\nendstream"),
  )
  guard wrong_stream_type is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected XRefExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes resolves indirect stream length" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_indirect_stream_length(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  guard parsed.lookup_object_or_null(1) is PdfStreamObject(stream) else {
    fail("expected stream object")
  }
  @test.assert_eq(
    stream.dictionary.lookup_immediate(
      @pdflite.pdf_name_of_bytes(
        reader_bytes_for_test([47, 76, 101, 110, 103, 116, 104]),
      ),
    ),
    Some(PdfIndirect(2)),
  )
  @test.assert_eq(
    stream.data,
    StreamGot(reader_bytes_for_test([72, 101, 108, 108, 111])),
  )
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(5))
}

///|
test "pdf_read_classic_document_from_bytes follows trailer Prev xrefs" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_prev_xref(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(parsed.lookup_object_or_null(1), PdfInteger(2))
  @test.assert_eq(parsed.lookup_object_or_null(2), PdfInteger(3))
  @test.assert_eq(
    parsed
    .trailer_dict()
    .lookup_immediate(@pdflite.pdf_name_of_bytes(reader_pdf_ascii("/Prev"))),
    None,
  )
}

///|
test "pdf_read_classic_document_from_bytes keeps newer deleted xref entries" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_prev_deleted_object(),
  )
  @test.assert_eq(parsed.object_numbers(), [])
  @test.assert_eq(parsed.lookup_object_or_null(1), PdfNull)
}

///|
test "pdf_read_classic_document_from_bytes accepts blank xref lines" {
  let parsed = try! @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n\n0000000000 65535 f \n", "<< /Root 1 0 R /Size 1 >>",
    ),
  )
  @test.assert_eq(parsed.root(), 1)
  @test.assert_eq(parsed.object_numbers(), [])
}

///|
test "pdf_read_classic_document_from_bytes reports missing startxref" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_pdf_ascii(
      "%PDF-1.4\nxref\n0 1\n0000000000 65535 f \ntrailer\n<< /Root 1 0 R /Size 1 >>\n%%EOF\n",
    ),
  )
  guard result is Err(@pdflite.PdfError::StartXRefExpected) else {
    fail("expected StartXRefExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes reports malformed startxref number" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_pdf_ascii("%PDF-1.4\nstartxref\nabc\n%%EOF\n"),
  )
  guard result is Err(@pdflite.PdfError::NumberExpected) else {
    fail("expected NumberExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes reports missing xref marker" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_pdf_ascii("%PDF-1.4\nstartxref\n9\n%%EOF\n"),
  )
  guard result is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected XRefExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes reports trailerless xrefs" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_without_trailer_after_xref(),
  )
  guard result is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected TrailerExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes reports malformed xref rows" {
  let bad_token : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n0000000000 00000 q \n", "<< /Root 1 0 R /Size 1 >>",
    ),
  )
  guard bad_token is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }
  let short_row : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body("0\n", "<< /Root 1 0 R /Size 1 >>"),
  )
  guard short_row is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes reports malformed trailers" {
  let non_dictionary : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body("0 1\n0000000000 65535 f \n", "1"),
  )
  guard non_dictionary is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected TrailerExpected")
  }
  let missing_root : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n0000000000 65535 f \n", "<< /Size 1 >>",
    ),
  )
  guard missing_root is Err(@pdflite.PdfError::RootExpected) else {
    fail("expected RootExpected")
  }
  let bad_prev : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_xref_body(
      "0 1\n0000000000 65535 f \n", "<< /Root 1 0 R /Size 1 /Prev -1 >>",
    ),
  )
  guard bad_prev is Err(@pdflite.PdfError::TrailerExpected) else {
    fail("expected TrailerExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes stops cyclic Prev chains" {
  let result : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_self_prev_xref(),
  )
  guard result is Err(@pdflite.PdfError::XRefExpected) else {
    fail("expected XRefExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes reports indirect stream length errors" {
  let missing_xref : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_missing_indirect_stream_length(),
  )
  guard missing_xref is Err(@pdflite.PdfError::StreamLengthExpected) else {
    fail("expected StreamLengthExpected")
  }

  let non_integer : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_non_integer_stream_length(),
  )
  guard non_integer is Err(@pdflite.PdfError::StreamLengthExpected) else {
    fail("expected StreamLengthExpected")
  }

  let mismatched : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_mismatched_stream_length_xref(),
  )
  guard mismatched is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }

  let stream_length_object : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_stream_length_stream_object(),
  )
  guard stream_length_object is Err(@pdflite.PdfError::StreamLengthExpected) else {
    fail("expected StreamLengthExpected")
  }

  let negative_direct : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_negative_stream_length(),
  )
  guard negative_direct is Err(@pdflite.PdfError::StreamLengthExpected) else {
    fail("expected StreamLengthExpected")
  }
}

///|
test "pdf_read_classic_document_from_bytes reports xref object mismatches" {
  let mismatched_object : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_mismatched_object_xref(),
  )
  guard mismatched_object is Err(@pdflite.PdfError::XRefEntryExpected) else {
    fail("expected XRefEntryExpected")
  }
  let unparseable_object : Result[@pdflite.PdfDocument, Error] = try? @pdflite.pdf_read_classic_document_from_bytes(
    reader_classic_pdf_with_unparseable_xref_object(),
  )
  guard unparseable_object
    is Err(@pdflite.PdfError::ParseIndirectObjectExpected) else {
    fail("expected ParseIndirectObjectExpected")
  }
}

///|
test "pdf_read_document_from_bytes is the public classic reader entry point" {
  let parsed = try! @pdflite.pdf_read_document_from_bytes(
    reader_classic_pdf_with_prev_xref(),
  )
  @test.assert_eq(parsed.object_numbers(), [1, 2])
  @test.assert_eq(parsed.lookup_object_or_null(1), PdfInteger(2))
}
