///|
#warnings("-unused_value")
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
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_malformed_stream_marker() -> @pdflite.PdfBytes {
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
  reader_push_ascii(output, " /Size 3 /Root 1 0 R /W [1 4 2] >>\nstramx\n")
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
fn reader_xref_stream_pdf_with_malformed_endstream_marker() -> @pdflite.PdfBytes {
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
  reader_push_ascii(output, "\nendstreax\nendobj\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_malformed_endobj_marker() -> @pdflite.PdfBytes {
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
  reader_push_ascii(output, "\nendstream\nendobx\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_without_type() -> @pdflite.PdfBytes {
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
  reader_push_ascii(output, "<< /Length ")
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
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_wrong_type() -> @pdflite.PdfBytes {
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
  reader_push_ascii(output, "<< /Type /Catalog /Length ")
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
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_non_name_type() -> @pdflite.PdfBytes {
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
  reader_push_ascii(output, "<< /Type 99 /Length ")
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
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_short_entry_data() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let xref_offset = output.length()
  reader_push_ascii(output, "2 0 obj\n")
  reader_push_ascii(
    output, "<< /Type /XRef /Length 1 /Size 2 /Root 1 0 R /W [1 4 2] >>\nstream\n",
  )
  reader_push_byte(output, 0)
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_bad_startxref() -> @pdflite.PdfBytes {
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
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n0\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_without_type_with_bad_startxref() -> @pdflite.PdfBytes {
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
  reader_push_ascii(output, "<< /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(output, " /Size 3 /Root 1 0 R /W [1 4 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n0\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_index_startxref(
  startxref_override : Int?,
) -> @pdflite.PdfBytes {
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
  let startxref = match startxref_override {
    Some(offset) => offset
    None => xref_offset
  }
  reader_push_ascii(output, startxref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_index() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_index_startxref(None)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_index_bad_startxref() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_index_startxref(Some(0))
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_default_in_use_width_startxref(
  startxref_override : Int?,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Payload 3 0 R >>",
  )
  let value_offset = reader_push_indirect_object(output, 3, 0, "7")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_default_in_use_entry(stream_data, catalog_offset, 0)
  reader_push_xref_stream_default_in_use_entry(stream_data, xref_offset, 0)
  reader_push_xref_stream_default_in_use_entry(stream_data, value_offset, 0)
  reader_push_ascii(output, "2 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(
    output, " /Size 4 /Root 1 0 R /W [0 4 2] /Index [1 3] >>\nstream\n",
  )
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  let startxref = match startxref_override {
    Some(offset) => offset
    None => xref_offset
  }
  reader_push_ascii(output, startxref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_default_in_use_width() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_default_in_use_width_startxref(None)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_default_in_use_width_bad_startxref() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_default_in_use_width_startxref(Some(0))
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_unknown_entry_type_startxref(
  startxref_override : Int?,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Good 3 0 R /Bad 2 0 R >>",
  )
  let skipped_offset = reader_push_indirect_object(output, 2, 0, "13")
  let value_offset = reader_push_indirect_object(output, 3, 0, "7")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, catalog_offset, 0)
  reader_push_xref_stream_entry(stream_data, 9, skipped_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, value_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  reader_push_ascii(output, "4 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(output, " /Size 5 /Root 1 0 R /W [1 4 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  let startxref = match startxref_override {
    Some(offset) => offset
    None => xref_offset
  }
  reader_push_ascii(output, startxref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_unknown_entry_type() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_unknown_entry_type_startxref(None)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_unknown_entry_type_bad_startxref() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_unknown_entry_type_startxref(Some(0))
}

///|
#warnings("-unused_value")
fn reader_xref_stream_unknown_entry_with_later_physical_update_bad_startxref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Payload 2 0 R >>",
  )
  let old_value_offset = reader_push_indirect_object(output, 2, 0, "13")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, catalog_offset, 0)
  reader_push_xref_stream_entry(stream_data, 9, old_value_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  reader_push_ascii(output, "3 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, stream_data.length().to_string())
  reader_push_ascii(output, " /Size 4 /Root 1 0 R /W [1 4 2] >>\nstream\n")
  for byte in stream_data {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\n")
  ignore(reader_push_indirect_object(output, 2, 0, "99"))
  reader_push_ascii(output, "startxref\n0\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_ascii_hex_filter_startxref(
  startxref_override : Int?,
) -> @pdflite.PdfBytes {
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
  let startxref = match startxref_override {
    Some(offset) => offset
    None => xref_offset
  }
  reader_push_ascii(output, startxref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_ascii_hex_filter() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_ascii_hex_filter_startxref(None)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_ascii_hex_filter_bad_startxref() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_ascii_hex_filter_startxref(Some(0))
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_flate_filter_startxref(
  startxref_override : Int?,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Payload 3 0 R >>",
  )
  let value_offset = reader_push_indirect_object(output, 3, 0, "7")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, catalog_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, value_offset, 0)
  let encoded = @flate.pdf_flate_encode(Bytes::from_array(stream_data))
  reader_push_ascii(output, "2 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, encoded.length().to_string())
  reader_push_ascii(
    output, " /Size 4 /Root 1 0 R /W [1 4 2] /Filter /FlateDecode >>\nstream\n",
  )
  for byte in encoded {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  let startxref = match startxref_override {
    Some(offset) => offset
    None => xref_offset
  }
  reader_push_ascii(output, startxref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_flate_filter() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_flate_filter_startxref(None)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_flate_filter_bad_startxref() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_flate_filter_startxref(Some(0))
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_flate_predictor_startxref(
  startxref_override : Int?,
  use_short_names : Bool,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Payload 3 0 R >>",
  )
  let value_offset = reader_push_indirect_object(output, 3, 0, "7")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, catalog_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, value_offset, 0)
  let predicted = reader_png_none_predictor_rows_for_test(stream_data, 7)
  let encoded = @flate.pdf_flate_encode(predicted)
  reader_push_ascii(output, "2 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, encoded.length().to_string())
  let filter_dictionary = if use_short_names {
    " /Size 4 /Root 1 0 R /W [1 4 2] /Filter /Fl /DP << /Predictor 12 /Columns 7 >> >>\nstream\n"
  } else {
    " /Size 4 /Root 1 0 R /W [1 4 2] /Filter /FlateDecode /DecodeParms << /Predictor 12 /Columns 7 >> >>\nstream\n"
  }
  reader_push_ascii(output, filter_dictionary)
  for byte in encoded {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  let startxref = match startxref_override {
    Some(offset) => offset
    None => xref_offset
  }
  reader_push_ascii(output, startxref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_flate_predictor() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_flate_predictor_startxref(None, false)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_flate_predictor_bad_startxref() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_flate_predictor_startxref(Some(0), false)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_short_flate_predictor() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_flate_predictor_startxref(None, true)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_short_flate_predictor_bad_startxref() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_flate_predictor_startxref(Some(0), true)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_filter_array_startxref(
  startxref_override : Int?,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Payload 3 0 R >>",
  )
  let value_offset = reader_push_indirect_object(output, 3, 0, "7")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, catalog_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, value_offset, 0)
  let run_length = @pdflite.pdf_run_length_encode(
    Bytes::from_array(stream_data),
  )
  let encoded = @pdflite.pdf_ascii_hex_encode(run_length)
  reader_push_ascii(output, "2 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, encoded.length().to_string())
  reader_push_ascii(
    output, " /Size 4 /Root 1 0 R /W [1 4 2] /Filter [/ASCIIHexDecode /RunLengthDecode] >>\nstream\n",
  )
  for byte in encoded {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  let startxref = match startxref_override {
    Some(offset) => offset
    None => xref_offset
  }
  reader_push_ascii(output, startxref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_filter_array() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_filter_array_startxref(None)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_filter_array_bad_startxref() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_filter_array_startxref(Some(0))
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_filter_array_predictor_startxref(
  startxref_override : Int?,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Payload 3 0 R >>",
  )
  let value_offset = reader_push_indirect_object(output, 3, 0, "7")
  let xref_offset = output.length()
  let stream_data : Array[Byte] = []
  reader_push_xref_stream_entry(stream_data, 0, 0, 65535)
  reader_push_xref_stream_entry(stream_data, 1, catalog_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, xref_offset, 0)
  reader_push_xref_stream_entry(stream_data, 1, value_offset, 0)
  let predicted = reader_png_none_predictor_rows_for_test(stream_data, 7)
  let flate = @flate.pdf_flate_encode(predicted)
  let encoded = @pdflite.pdf_ascii_hex_encode(flate)
  reader_push_ascii(output, "2 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, encoded.length().to_string())
  reader_push_ascii(
    output, " /Size 4 /Root 1 0 R /W [1 4 2] /Filter [/ASCIIHexDecode /FlateDecode] /DecodeParms [null << /Predictor 12 /Columns 7 >>] >>\nstream\n",
  )
  for byte in encoded {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\nstartxref\n")
  let startxref = match startxref_override {
    Some(offset) => offset
    None => xref_offset
  }
  reader_push_ascii(output, startxref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_filter_array_predictor() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_filter_array_predictor_startxref(None)
}

///|
#warnings("-unused_value")
fn reader_xref_stream_pdf_with_filter_array_predictor_bad_startxref() -> @pdflite.PdfBytes {
  reader_xref_stream_pdf_with_filter_array_predictor_startxref(Some(0))
}

///|
#warnings("-unused_value")
fn reader_hybrid_xref_stream_pdf_with_startxref_override(
  startxref_override : Int?,
) -> @pdflite.PdfBytes {
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
  let startxref = match startxref_override {
    Some(offset) => offset
    None => classic_xref_offset
  }
  reader_push_ascii(output, startxref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_hybrid_xref_stream_pdf() -> @pdflite.PdfBytes {
  reader_hybrid_xref_stream_pdf_with_startxref_override(None)
}

///|
#warnings("-unused_value")
fn reader_hybrid_xref_stream_pdf_with_bad_startxref() -> @pdflite.PdfBytes {
  reader_hybrid_xref_stream_pdf_with_startxref_override(Some(0))
}

///|
#warnings("-unused_value")
fn reader_hybrid_compressed_xref_stream_pdf_with_startxref_override(
  startxref_override : Int?,
) -> @pdflite.PdfBytes {
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
  let predicted = reader_png_none_predictor_rows_for_test(stream_data, 7)
  let encoded = @flate.pdf_flate_encode(predicted)
  reader_push_ascii(output, "3 0 obj\n")
  reader_push_ascii(output, "<< /Type /XRef /Length ")
  reader_push_ascii(output, encoded.length().to_string())
  reader_push_ascii(
    output, " /Size 4 /W [1 4 2] /Index [0 1 2 2] /Filter /FlateDecode /DecodeParms << /Predictor 12 /Columns 7 >> >>\nstream\n",
  )
  for byte in encoded {
    output.push(byte)
  }
  reader_push_ascii(output, "\nendstream\nendobj\n")
  let classic_xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 4 /XRefStm ")
  reader_push_ascii(output, xref_stream_offset.to_string())
  reader_push_ascii(output, " >>\nstartxref\n")
  let startxref = match startxref_override {
    Some(offset) => offset
    None => classic_xref_offset
  }
  reader_push_ascii(output, startxref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_hybrid_compressed_xref_stream_pdf() -> @pdflite.PdfBytes {
  reader_hybrid_compressed_xref_stream_pdf_with_startxref_override(None)
}

///|
#warnings("-unused_value")
fn reader_hybrid_compressed_xref_stream_pdf_with_bad_startxref() -> @pdflite.PdfBytes {
  reader_hybrid_compressed_xref_stream_pdf_with_startxref_override(Some(0))
}
