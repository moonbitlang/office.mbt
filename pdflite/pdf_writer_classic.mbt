///|
fn pdf_writer_push_classic_xref_and_trailer(
  output : Array[Byte],
  document : PdfDocument,
  xrefs : ArrayView[(Int, Int, Int)],
  xref_start : Int,
) -> Unit raise @core.PdfError {
  let size = document.objects.max_object_number() + 1
  pdf_writer_push_ascii(output, "xref\n0 ")
  pdf_writer_push_ascii(output, size.to_string())
  pdf_writer_push_byte(output, 10)
  pdf_writer_push_ascii(output, "0000000000 65535 f \n")
  let mut xref_index = 0
  for number in 1..<size {
    if xref_index < xrefs.length() && xrefs[xref_index].0 == number {
      let (_, offset, generation) = xrefs[xref_index]
      pdf_writer_push_padded_decimal(output, offset, 10)
      pdf_writer_push_byte(output, 32)
      pdf_writer_push_padded_decimal(output, generation, 5)
      pdf_writer_push_ascii(output, " n \n")
      xref_index += 1
    } else {
      pdf_writer_push_ascii(output, "0000000000 65535 f \n")
    }
  }
  pdf_writer_push_ascii(output, "trailer\n")
  let trailer = pdf_writer_trailer_dictionary(document)
  pdf_writer_push_view(output, pdf_write_object(trailer))
  pdf_writer_push_ascii(output, "\nstartxref\n")
  pdf_writer_push_ascii(output, xref_start.to_string())
  pdf_writer_push_ascii(output, "\n%%EOF\n")
}

///|
fn pdf_writer_int_array_contains(values : ArrayView[Int], value : Int) -> Bool {
  for item in values {
    if item == value {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_writer_changed_object_numbers(document : PdfDocument) -> Array[Int] {
  let log = document.event_log()
  let numbers : Array[Int] = Array::new(capacity=log.length() + 1)
  numbers.push(0)
  let seen : @hashmap.HashMap[Int, Bool] = HashMap([])
  seen[0] = true
  for item in log {
    let (number, _) = item
    if number > 0 && !seen.contains(number) {
      seen[number] = true
      numbers.push(number)
    }
  }
  numbers.sort()
  numbers
}

///|
fn pdf_writer_write_document_objects_for_numbers(
  output : Array[Byte],
  document : PdfDocument,
  numbers : ArrayView[Int],
) -> Array[(Int, Int, Int)] raise @core.PdfError {
  let xrefs : Array[(Int, Int, Int)] = Array::new(capacity=numbers.length())
  for number in numbers {
    if number > 0 {
      match document.objects.get_entry(number) {
        Some({ data: ObjectParsed(object), generation })
        | Some({ data: ObjectParsedAlreadyDecrypted(object), generation }) => {
          xrefs.push((number, output.length(), generation))
          pdf_writer_push_view(
            output,
            pdf_write_indirect_object({ number, generation, object }),
          )
        }
        Some(_) => raise ParsedObjectExpected
        None => ()
      }
    }
  }
  xrefs
}

///|
fn pdf_writer_push_classic_xref_entry(
  output : Array[Byte],
  xrefs : ArrayView[(Int, Int, Int)],
  number : Int,
  xref_index : Ref[Int],
) -> Unit {
  if number == 0 {
    pdf_writer_push_ascii(output, "0000000000 65535 f \n")
  } else {
    while xref_index.val < xrefs.length() && xrefs[xref_index.val].0 < number {
      xref_index.val += 1
    }
    if xref_index.val < xrefs.length() && xrefs[xref_index.val].0 == number {
      let (_, offset, generation) = xrefs[xref_index.val]
      pdf_writer_push_padded_decimal(output, offset, 10)
      pdf_writer_push_byte(output, 32)
      pdf_writer_push_padded_decimal(output, generation, 5)
      pdf_writer_push_ascii(output, " n \n")
    } else {
      pdf_writer_push_ascii(output, "0000000000 65535 f \n")
    }
  }
}

///|
fn pdf_writer_push_classic_xref_subsection(
  output : Array[Byte],
  xrefs : ArrayView[(Int, Int, Int)],
  start : Int,
  length : Int,
  xref_index : Ref[Int],
) -> Unit {
  pdf_writer_push_ascii(output, start.to_string())
  pdf_writer_push_byte(output, 32)
  pdf_writer_push_ascii(output, length.to_string())
  pdf_writer_push_byte(output, 10)
  for number in start..<(start + length) {
    pdf_writer_push_classic_xref_entry(output, xrefs, number, xref_index)
  }
}

///|
fn pdf_writer_push_classic_sparse_xref_and_trailer(
  output : Array[Byte],
  document : PdfDocument,
  xrefs : ArrayView[(Int, Int, Int)],
  entry_numbers : ArrayView[Int],
  xref_start : Int,
  previous_xref : Int,
) -> Unit raise @core.PdfError {
  pdf_writer_push_ascii(output, "xref\n")
  let xref_index : Ref[Int] = { val: 0 }
  let mut run_start = -1
  let mut run_length = 0
  for number in entry_numbers {
    if run_length == 0 {
      run_start = number
      run_length = 1
    } else if number == run_start + run_length {
      run_length += 1
    } else {
      pdf_writer_push_classic_xref_subsection(
        output, xrefs, run_start, run_length, xref_index,
      )
      run_start = number
      run_length = 1
    }
  }
  if run_length > 0 {
    pdf_writer_push_classic_xref_subsection(
      output, xrefs, run_start, run_length, xref_index,
    )
  }
  pdf_writer_push_ascii(output, "trailer\n")
  let trailer = pdf_writer_trailer_dictionary(document).add_dict_entry(
    pdf_writer_prev_name(),
    PdfInteger(previous_xref),
  )
  pdf_writer_push_view(output, pdf_write_object(trailer))
  pdf_writer_push_ascii(output, "\nstartxref\n")
  pdf_writer_push_ascii(output, xref_start.to_string())
  pdf_writer_push_ascii(output, "\n%%EOF\n")
}

///|
/// Serialize a complete document with a classic xref table.
pub fn pdf_write_document(
  document : PdfDocument,
) -> @core.PdfBytes raise @core.PdfError {
  let output : Array[Byte] = []
  let (major, minor) = document.version()
  pdf_writer_push_header(output, major, minor)
  let xrefs = pdf_writer_write_document_objects(output, document)
  let xref_start = output.length()
  pdf_writer_push_classic_xref_and_trailer(output, document, xrefs, xref_start)
  Bytes::from_array(output)
}

///|
/// Append a classic incremental update to original PDF bytes.
///
/// Only objects marked as changed in `document` are written. The previous
/// `startxref` position is read from `original` and emitted as `/Prev`.
pub fn pdf_write_document_incremental_update(
  original : @core.PdfBytes,
  document : PdfDocument,
) -> @core.PdfBytes raise @core.PdfError {
  let previous_xref = @reader.pdf_read_startxref_position(original)
  let output : Array[Byte] = Array::new(capacity=original.length() + 1)
  for byte in original {
    output.push(byte)
  }
  pdf_writer_push_byte(output, 10)
  let changed_numbers = pdf_writer_changed_object_numbers(document)
  let xrefs = pdf_writer_write_document_objects_for_numbers(
    output, document, changed_numbers,
  )
  let xref_start = output.length()
  pdf_writer_push_classic_sparse_xref_and_trailer(
    output, document, xrefs, changed_numbers, xref_start, previous_xref,
  )
  Bytes::from_array(output)
}
