///|
#warnings("-unused_value")
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
#warnings("-unused_value")
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
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_compressed_prev_update_startxref(
  startxref_override : Int?,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let original_offset = reader_push_indirect_object(output, 1, 0, "1")
  let catalog_offset = reader_push_indirect_object(
    output, 2, 0, "<< /Type /Catalog /Payload 1 0 R >>",
  )
  let base_xref = output.length()
  reader_push_ascii(output, "xref\n0 3\n0000000000 65535 f \n")
  reader_push_xref_entry(output, original_offset, 0)
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 2 0 R /Size 3 >>\nstartxref\n")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  let updated_offset = reader_push_indirect_object(output, 1, 0, "2")
  let xref_stream_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, updated_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, catalog_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_stream_offset, 0)
  let predicted = reader_png_none_predictor_rows_for_test(stream_data, 7)
  let encoded = @flate.pdf_flate_encode(predicted)
  reader_push_ascii(output, "3 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, encoded.length().to_string())
  reader_push_ascii(output, " /Size 4 /Root 2 0 R /Prev ")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(
    output, " /W [1 4 2] /Filter /FlateDecode /DecodeParms << /Predictor 12 /Columns 7 >> >>\nstream\n",
  )
  for byte in encoded {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  let startxref = match startxref_override {
    Some(offset) => offset
    None => xref_stream_offset
  }
  reader_push_ascii(output, startxref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_compressed_prev_update() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_compressed_prev_update_startxref(None)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_compressed_prev_update_bad_startxref() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_compressed_prev_update_startxref(Some(0))
}

///|
#warnings("-unused_value")
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
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_two_object_stream_entries() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Payload 2 0 R /Other 5 0 R >>",
  )
  let first_object = reader_pdf_ascii("<< /Answer 42 >>")
  let second_object = reader_pdf_ascii("[1 2 3]")
  let object_stream_data : Array[Byte] = []
  reader_push_ascii(object_stream_data, "2 0 5 ")
  reader_push_ascii(object_stream_data, first_object.length().to_string())
  reader_push_ascii(object_stream_data, " ")
  let first = object_stream_data.length()
  for byte in first_object {
    object_stream_data.push(byte)
  }
  for byte in second_object {
    object_stream_data.push(byte)
  }
  let object_stream_offset = output.length()
  reader_push_ascii(output, "3 0 obj\n<< /Type /ObjStm /N 2 /First ")
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
  reader_push_xref_stream_entry(stream_data, 2, 3, 1)
  reader_push_ascii(output, "4 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(output, " /Size 6 /Root 1 0 R /W [1 4 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_stream_object_in_object_stream() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Payload 2 0 R >>",
  )
  let stream_object = reader_pdf_ascii(
    "<< /Length 99 >>\nstream\nHi\nendstream",
  )
  let object_stream_data : Array[Byte] = []
  reader_push_ascii(object_stream_data, "2 0 ")
  let first = object_stream_data.length()
  for byte in stream_object {
    object_stream_data.push(byte)
  }
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
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_bad_first_object_stream_root_and_physical_page_tree() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let pages_offset = reader_push_indirect_object(
    output, 2, 0, "<< /Type /Pages /Kids [5 0 R] /Count 1 >>",
  )
  let page_offset = reader_push_indirect_object(
    output, 5, 0, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] /Resources << >> >>",
  )
  let object_stream_data : Array[Byte] = []
  reader_push_ascii(object_stream_data, "1 0 ")
  reader_push_ascii(object_stream_data, "<< /Type /Catalog /Pages 2 0 R >>")
  let bad_first = object_stream_data.length() + 4
  let object_stream_offset = output.length()
  reader_push_ascii(output, "3 0 obj\n<< /Type /ObjStm /N 1 /First ")
  reader_push_ascii(output, bad_first.to_string())
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
  reader_push_xref_stream_entry(stream_data, 2, 3, 0)
  reader_push_xref_stream_entry(stream_data, 1, pages_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, object_stream_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, page_offset, 0)
  reader_push_ascii(output, "4 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(output, " /Size 6 /Root 1 0 R /W [1 4 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\n")
  ignore(
    reader_push_indirect_object(
      output, 1, 0, "<< /Type /Catalog /Pages 2 0 R >>",
    ),
  )
  reader_push_ascii(output, "startxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_mismatched_object_stream_root_and_physical_catalog() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let object_stream_data : Array[Byte] = []
  reader_push_ascii(object_stream_data, "2 0 ")
  let first = object_stream_data.length()
  reader_push_ascii(object_stream_data, "<< /Type /Catalog >>")
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
  reader_push_xref_stream_entry(stream_data, 2, 3, 0)
  reader_push_xref_stream_entry(stream_data, 0, 0, 0)
  reader_push_xref_stream_entry(stream_data, 1, object_stream_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  reader_push_ascii(output, "4 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(output, " /Size 5 /Root 1 0 R /W [1 4 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\n")
  ignore(reader_push_indirect_object(output, 1, 0, "<< /Type /Catalog >>"))
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 5 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_object_stream_root_bad_startxref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let object_stream_data : Array[Byte] = []
  reader_push_ascii(object_stream_data, "1 0 ")
  let first = object_stream_data.length()
  reader_push_ascii(object_stream_data, "<< /Type /Catalog >>")
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
  reader_push_xref_stream_entry(stream_data, 2, 3, 0)
  reader_push_xref_stream_entry(stream_data, 1, 999999, 0)
  reader_push_xref_stream_entry(stream_data, 1, object_stream_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  reader_push_xref_stream_entry(stream_data, 2, 99, 0)
  reader_push_ascii(output, "4 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(output, " /Size 6 /Root 1 0 R /W [1 4 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n0\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_bad_filtered_object_stream_root() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let object_stream_data : Array[Byte] = []
  reader_push_ascii(object_stream_data, "1 0 ")
  let first = object_stream_data.length()
  reader_push_ascii(object_stream_data, "<< /Type /Catalog >>")
  let object_stream_offset = output.length()
  reader_push_ascii(output, "3 0 obj\n<< /Type /ObjStm /N 1 /First ")
  reader_push_ascii(output, first.to_string())
  reader_push_ascii(output, " /Length ")
  reader_push_ascii(output, object_stream_data.length().to_string())
  reader_push_ascii(output, " /Filter /BadObjectStreamFilter >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 2, 3, 0)
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
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
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_decodeparms_object_stream_root(
  decodeparms : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let object_stream_data : Array[Byte] = []
  reader_push_ascii(object_stream_data, "1 0 ")
  let first = object_stream_data.length()
  reader_push_ascii(object_stream_data, "<< /Type /Catalog >>")
  let encoded_object_stream = @flate.pdf_flate_encode(
    Bytes::from_array(object_stream_data),
  )
  let object_stream_offset = output.length()
  reader_push_ascii(output, "3 0 obj\n<< /Type /ObjStm /N 1 /First ")
  reader_push_ascii(output, first.to_string())
  reader_push_ascii(output, " /Length ")
  reader_push_ascii(output, encoded_object_stream.length().to_string())
  reader_push_ascii(output, " /Filter /FlateDecode /DecodeParms ")
  reader_push_ascii(output, decodeparms)
  reader_push_ascii(output, " >>\nstream\n")
  for byte in encoded_object_stream {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 2, 3, 0)
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
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
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_bad_decodeparms_object_stream_root() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_decodeparms_object_stream_root("/Bad")
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_unsupported_predictor_object_stream_root() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_decodeparms_object_stream_root(
    "<< /Predictor 9 >>",
  )
}

///|
#warnings("-unused_value")
fn reader_xref_stream_prev_update_with_object_stream_root_bad_startxref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let old_catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Old true >>",
  )
  let first_xref_offset = output.length()
  let first_xref_data : Array[Byte] = []
  reader_push_xref_stream_entry(first_xref_data, 0, 0, 65535)
  reader_push_xref_stream_entry(first_xref_data, 1, old_catalog_offset, 0)
  reader_push_xref_stream_entry(first_xref_data, 1, first_xref_offset, 0)
  reader_push_ascii(output, "2 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, first_xref_data.length().to_string())
  reader_push_ascii(output, " /Size 3 /Root 1 0 R /W [1 4 2] >>\nstream\n")
  for byte in first_xref_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  reader_push_ascii(output, first_xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")

  let object_stream_data : Array[Byte] = []
  reader_push_ascii(object_stream_data, "1 0 ")
  let first = object_stream_data.length()
  reader_push_ascii(object_stream_data, "<< /Type /Catalog /New true >>")
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
  let second_xref_offset = output.length()
  let second_xref_data : Array[Byte] = []
  reader_push_xref_stream_entry(second_xref_data, 0, 0, 65535)
  reader_push_xref_stream_entry(second_xref_data, 2, 3, 0)
  reader_push_xref_stream_entry(second_xref_data, 0, 0, 0)
  reader_push_xref_stream_entry(second_xref_data, 1, object_stream_offset, 0)
  reader_push_xref_stream_entry(second_xref_data, 1, second_xref_offset, 0)
  reader_push_ascii(output, "4 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, second_xref_data.length().to_string())
  reader_push_ascii(output, " /Size 5 /Root 1 0 R /Prev ")
  reader_push_ascii(output, first_xref_offset.to_string())
  reader_push_ascii(output, " /W [1 4 2] >>\nstream\n")
  for byte in second_xref_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n0\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_encrypted_xref_stream_pdf_with_missing_object_stream_for_test() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Payload 2 0 R >>",
  )
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, catalog_offset, 0)
  reader_push_xref_stream_entry(stream_data, 2, 7, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  reader_push_ascii(output, "3 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(
    output, " /Size 4 /Root 1 0 R /Encrypt << /Filter /Standard >> /W [1 4 2] >>\nstream\n",
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
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_object_stream() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_object_stream_number(2)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_object_stream_bad_first() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let object_stream_data : Array[Byte] = []
  reader_push_ascii(object_stream_data, "2 0 ")
  let bad_first = object_stream_data.length() + 32
  reader_push_ascii(object_stream_data, "<< /Answer 42 >>")
  let object_stream_offset = output.length()
  reader_push_ascii(output, "3 0 obj\n<< /Type /ObjStm /N 1 /First ")
  reader_push_ascii(output, bad_first.to_string())
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
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_indirect_object_stream_filter_startxref(
  startxref_override : Int?,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let filter_offset = reader_push_indirect_object(
    output, 2, 0, "/ASCIIHexDecode",
  )
  let object_stream_data : Array[Byte] = []
  reader_push_ascii(object_stream_data, "5 0 ")
  let first = object_stream_data.length()
  reader_push_ascii(object_stream_data, "<< /Answer 42 >>")
  let encoded_object_stream = @codec.pdf_ascii_hex_encode(
    Bytes::from_array(object_stream_data),
  )
  let object_stream_offset = output.length()
  reader_push_ascii(output, "3 0 obj\n<< /Type /ObjStm /N 1 /First ")
  reader_push_ascii(output, first.to_string())
  reader_push_ascii(output, " /Filter 2 0 R /Length ")
  reader_push_ascii(output, encoded_object_stream.length().to_string())
  reader_push_ascii(output, " >>\nstream\n")
  for byte in encoded_object_stream {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\n")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, catalog_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, filter_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, object_stream_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  reader_push_xref_stream_entry(stream_data, 2, 3, 0)
  reader_push_ascii(output, "4 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(output, " /Size 6 /Root 1 0 R /W [1 4 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  let startxref = match startxref_override {
    Some(value) => value
    None => xref_offset
  }
  reader_push_ascii(output, startxref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_indirect_object_stream_filter() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_indirect_object_stream_filter_startxref(None)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_indirect_object_stream_filter_bad_startxref() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_indirect_object_stream_filter_startxref(Some(0))
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_indirect_object_stream_bounds_startxref(
  startxref_override : Int?,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let count_offset = reader_push_indirect_object(output, 2, 0, "1")
  let object_stream_data : Array[Byte] = []
  reader_push_ascii(object_stream_data, "7 0 ")
  let first = object_stream_data.length()
  reader_push_ascii(object_stream_data, "<< /Answer 42 >>")
  let object_stream_offset = output.length()
  reader_push_ascii(
    output, "3 0 obj\n<< /Type /ObjStm /N 2 0 R /First 5 0 R /Length ",
  )
  reader_push_ascii(output, object_stream_data.length().to_string())
  reader_push_ascii(output, " >>\nstream\n")
  for byte in object_stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\n")
  let first_offset = reader_push_indirect_object(
    output,
    5,
    0,
    first.to_string(),
  )
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, catalog_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, count_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, object_stream_offset, 0)
  reader_push_xref_stream_entry(stream_data, 0, 0, 0)
  reader_push_xref_stream_entry(stream_data, 1, first_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  reader_push_xref_stream_entry(stream_data, 2, 3, 0)
  reader_push_ascii(output, "6 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(output, " /Size 8 /Root 1 0 R /W [1 4 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  let startxref = match startxref_override {
    Some(value) => value
    None => xref_offset
  }
  reader_push_ascii(output, startxref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_indirect_object_stream_bounds() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_indirect_object_stream_bounds_startxref(None)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_indirect_object_stream_bounds_bad_startxref() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_indirect_object_stream_bounds_startxref(Some(0))
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_mismatched_object_stream() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_object_stream_number(5)
}

///|
#warnings("-unused_value")
fn reader_startxref_object_pdf(body : String) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let offset = reader_push_indirect_object(output, 2, 0, body)
  reader_push_ascii(output, "startxref\n")
  reader_push_ascii(output, offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}
