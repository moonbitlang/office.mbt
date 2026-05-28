///|
fn pdf_writer_push_big_endian_field(
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
    pdf_writer_push_byte(output, value / remaining_divisor % 256)
    remaining_divisor /= 256
  }
}

///|
fn pdf_writer_push_xref_stream_entry(
  output : Array[Byte],
  kind : Int,
  field2 : Int,
  field3 : Int,
) -> Unit {
  pdf_writer_push_big_endian_field(output, kind, 1)
  pdf_writer_push_big_endian_field(output, field2, 4)
  pdf_writer_push_big_endian_field(output, field3, 2)
}

///|
fn pdf_writer_xref_stream_data(
  xrefs : ArrayView[(Int, Int, Int)],
  size : Int,
  xref_stream_number : Int,
  xref_stream_offset : Int,
) -> PdfBytes {
  let output : Array[Byte] = Array::new(capacity=size * 7)
  let mut xref_index = 0
  for number in 0..<size {
    if number == 0 {
      pdf_writer_push_xref_stream_entry(output, 0, 0, 65535)
    } else if number == xref_stream_number {
      pdf_writer_push_xref_stream_entry(output, 1, xref_stream_offset, 0)
    } else {
      while xref_index < xrefs.length() && xrefs[xref_index].0 < number {
        xref_index += 1
      }
      if xref_index < xrefs.length() && xrefs[xref_index].0 == number {
        let (_, offset, generation) = xrefs[xref_index]
        pdf_writer_push_xref_stream_entry(output, 1, offset, generation)
      } else {
        pdf_writer_push_xref_stream_entry(output, 0, 0, 65535)
      }
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_writer_xref_stream_entry_numbers(
  document : PdfDocument,
  xref_stream_number : Int,
) -> Array[Int] {
  let numbers = pdf_writer_changed_object_numbers(document)
  if !pdf_writer_int_array_contains(numbers, xref_stream_number) {
    numbers.push(xref_stream_number)
  }
  numbers.sort()
  numbers
}

///|
fn pdf_writer_xref_stream_data_for_numbers(
  xrefs : ArrayView[(Int, Int, Int)],
  entry_numbers : ArrayView[Int],
  xref_stream_number : Int,
  xref_stream_offset : Int,
) -> PdfBytes {
  let output : Array[Byte] = Array::new(capacity=entry_numbers.length() * 7)
  let mut xref_index = 0
  for number in entry_numbers {
    if number == 0 {
      pdf_writer_push_xref_stream_entry(output, 0, 0, 65535)
    } else if number == xref_stream_number {
      pdf_writer_push_xref_stream_entry(output, 1, xref_stream_offset, 0)
    } else {
      while xref_index < xrefs.length() && xrefs[xref_index].0 < number {
        xref_index += 1
      }
      if xref_index < xrefs.length() && xrefs[xref_index].0 == number {
        let (_, offset, generation) = xrefs[xref_index]
        pdf_writer_push_xref_stream_entry(output, 1, offset, generation)
      } else {
        pdf_writer_push_xref_stream_entry(output, 0, 0, 65535)
      }
    }
  }
  Bytes::from_array(output)
}

///|
fn pdf_writer_xref_stream_index_pairs(
  entry_numbers : ArrayView[Int],
) -> Array[(Int, Int)] {
  let pairs : Array[(Int, Int)] = Array::new(capacity=entry_numbers.length())
  let mut run_start = -1
  let mut run_length = 0
  for number in entry_numbers {
    if run_length == 0 {
      run_start = number
      run_length = 1
    } else if number == run_start + run_length {
      run_length += 1
    } else {
      pairs.push((run_start, run_length))
      run_start = number
      run_length = 1
    }
  }
  if run_length > 0 {
    pairs.push((run_start, run_length))
  }
  pairs
}

///|
fn pdf_writer_xref_stream_index_object(
  pairs : ArrayView[(Int, Int)],
) -> PdfObject {
  let values : Array[PdfObject] = Array::new(capacity=pairs.length() * 2)
  for pair in pairs {
    let (start, length) = pair
    values.push(PdfInteger(start))
    values.push(PdfInteger(length))
  }
  PdfArray(values)
}

///|
fn pdf_writer_xref_stream_trailer(
  document : PdfDocument,
  size : Int,
  previous_xref : Int?,
) -> PdfObject raise PdfError {
  let trailer = pdf_writer_trailer_dictionary(document)
    .add_dict_entry(
      pdf_writer_type_name(),
      PdfNameObject(pdf_writer_xref_name()),
    )
    .add_dict_entry(pdf_writer_size_name(), PdfInteger(size))
    .add_dict_entry(
      pdf_writer_w_name(),
      PdfArray([PdfInteger(1), PdfInteger(4), PdfInteger(2)]),
    )
  match previous_xref {
    Some(previous) =>
      trailer.add_dict_entry(pdf_writer_prev_name(), PdfInteger(previous))
    None => trailer
  }
}

///|
fn pdf_write_document_with_xref_stream_filter(
  document : PdfDocument,
  filter : PdfName?,
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  let (major, minor) = document.version()
  if major > 1 || (major == 1 && minor >= 5) {
    pdf_writer_push_header(output, major, minor)
  } else {
    pdf_writer_push_header(output, 1, 5)
  }
  let xrefs = pdf_writer_write_document_objects(output, document)
  let xref_stream_offset = output.length()
  let xref_stream_number = document.objects.max_object_number() + 1
  let size = xref_stream_number + 1
  let xref_data = pdf_writer_xref_stream_data(
    xrefs, size, xref_stream_number, xref_stream_offset,
  )
  let stream = pdf_stream(
    pdf_writer_xref_stream_trailer(document, size, None).add_dict_entry(
      pdf_writer_length_name(),
      PdfInteger(xref_data.length()),
    ),
    StreamGot(xref_data),
  )
  let xref_object = match filter {
    Some(filter) => pdf_encode_stream_with_filter(filter, stream)
    None => stream
  }
  pdf_writer_push_view(
    output,
    pdf_write_indirect_object({
      number: xref_stream_number,
      generation: 0,
      object: xref_object,
    }),
  )
  pdf_writer_push_ascii(output, "startxref\n")
  pdf_writer_push_ascii(output, xref_stream_offset.to_string())
  pdf_writer_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
/// Serialize a complete document with an uncompressed xref stream.
///
/// The output header is at least PDF 1.5, because xref streams require that
/// version.
pub fn pdf_write_document_with_xref_stream(
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  pdf_write_document_with_xref_stream_filter(document, None)
}

///|
fn pdf_write_document_incremental_update_with_xref_stream_filter(
  original : PdfBytes,
  document : PdfDocument,
  filter : PdfName?,
) -> PdfBytes raise PdfError {
  let previous_xref = pdf_read_startxref_position(original)
  let output : Array[Byte] = Array::new(capacity=original.length() + 1)
  for byte in original {
    output.push(byte)
  }
  pdf_writer_push_byte(output, 10)
  let xref_stream_number = document.objects.max_object_number() + 1
  let entry_numbers = pdf_writer_xref_stream_entry_numbers(
    document, xref_stream_number,
  )
  let xrefs = pdf_writer_write_document_objects_for_numbers(
    output, document, entry_numbers,
  )
  let xref_stream_offset = output.length()
  let size = xref_stream_number + 1
  let xref_data = pdf_writer_xref_stream_data_for_numbers(
    xrefs, entry_numbers, xref_stream_number, xref_stream_offset,
  )
  let index_pairs = pdf_writer_xref_stream_index_pairs(entry_numbers)
  let stream = pdf_stream(
    pdf_writer_xref_stream_trailer(document, size, Some(previous_xref))
    .add_dict_entry(
      pdf_writer_index_name(),
      pdf_writer_xref_stream_index_object(index_pairs),
    )
    .add_dict_entry(pdf_writer_length_name(), PdfInteger(xref_data.length())),
    StreamGot(xref_data),
  )
  let xref_object = match filter {
    Some(filter) => pdf_encode_stream_with_filter(filter, stream)
    None => stream
  }
  pdf_writer_push_view(
    output,
    pdf_write_indirect_object({
      number: xref_stream_number,
      generation: 0,
      object: xref_object,
    }),
  )
  pdf_writer_push_ascii(output, "startxref\n")
  pdf_writer_push_ascii(output, xref_stream_offset.to_string())
  pdf_writer_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
/// Append an incremental update using an uncompressed xref stream.
pub fn pdf_write_document_incremental_update_with_xref_stream(
  original : PdfBytes,
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  pdf_write_document_incremental_update_with_xref_stream_filter(
    original,
    document,
    None,
  )
}

///|
/// Serialize a complete document with a Flate-compressed xref stream.
pub fn pdf_write_document_with_compressed_xref_stream(
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  pdf_write_document_with_xref_stream_filter(
    document,
    Some(pdf_writer_flate_decode_name()),
  )
}

///|
/// Append an incremental update using a Flate-compressed xref stream.
pub fn pdf_write_document_incremental_update_with_compressed_xref_stream(
  original : PdfBytes,
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  pdf_write_document_incremental_update_with_xref_stream_filter(
    original,
    document,
    Some(pdf_writer_flate_decode_name()),
  )
}
