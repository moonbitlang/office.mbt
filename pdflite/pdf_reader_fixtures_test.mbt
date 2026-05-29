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
  let encoded = @pdflite.pdf_flate_encode(Bytes::from_array(stream_data))
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
  let encoded = @pdflite.pdf_flate_encode(predicted)
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
  let flate = @pdflite.pdf_flate_encode(predicted)
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
  let encoded = @pdflite.pdf_flate_encode(predicted)
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

///|
#warnings("-unused_value")
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
#warnings("-unused_value")
fn reader_linearized_classic_pdf_with_prev_xref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.5\n")
  let linearized_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Linearized 1 /L 0 >>",
  )
  let catalog_offset = reader_push_indirect_object(
    output, 2, 0, "<< /Type /Catalog >>",
  )
  let base_xref = output.length()
  reader_push_ascii(output, "xref\n0 3\n0000000000 65535 f \n")
  reader_push_xref_entry(output, linearized_offset, 0)
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 2 0 R /Size 3 >>\nstartxref\n")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")

  let update_offset = reader_push_indirect_object(output, 3, 0, "3")
  let final_xref = output.length()
  reader_push_ascii(output, "xref\n3 1\n")
  reader_push_xref_entry(output, update_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 2 0 R /Size 4 /Prev ")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, " >>\nstartxref\n")
  reader_push_ascii(output, final_xref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
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
#warnings("-unused_value")
fn reader_classic_pdf_with_page_tree_objects_missing_from_xref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Pages 2 0 R >>",
  )
  ignore(
    reader_push_indirect_object(
      output, 2, 0, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    ),
  )
  ignore(
    reader_push_indirect_object(
      output, 3, 0, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] >>",
    ),
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 4 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_pdf_with_catalog_missing_from_xref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  ignore(
    reader_push_indirect_object(
      output, 1, 0, "<< /Type /Catalog /Pages 2 0 R >>",
    ),
  )
  ignore(
    reader_push_indirect_object(
      output, 2, 0, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    ),
  )
  ignore(
    reader_push_indirect_object(
      output, 3, 0, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 10 10] >>",
    ),
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 1\n0000000000 65535 f \n")
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 4 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
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
#warnings("-unused_value")
fn reader_malformed_pdf_with_glued_reconstruction_trailers() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  ignore(reader_push_indirect_object(output, 1, 0, "<< /Type /Catalog >>"))
  reader_push_ascii(output, "trailer << /Size 2 >>\n")
  reader_push_ascii(output, "trailer<< /Root 1 0 R /Size 2 >>\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_malformed_pdf_with_endobj_text_in_catalog_string() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  ignore(
    reader_push_indirect_object(
      output, 1, 0, "<< /Type /Catalog /Title (literal endobj marker) >>",
    ),
  )
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_malformed_pdf_with_bad_startxref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  ignore(reader_push_indirect_object(output, 1, 0, "<< /Type /Catalog >>"))
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\n")
  reader_push_ascii(output, "startxref\n9\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_xref_deleted_payload_bad_startxref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Payload 2 0 R >>",
  )
  ignore(reader_push_indirect_object(output, 2, 0, "13"))
  reader_push_ascii(output, "xref\n0 3\n0000000000 65535 f \n")
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "0000000000 00000 f \n")
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 3 >>\nstartxref\n")
  reader_push_ascii(output, "0\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_xref_deleted_payload_with_later_update_bad_startxref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Payload 2 0 R >>",
  )
  ignore(reader_push_indirect_object(output, 2, 0, "13"))
  reader_push_ascii(output, "xref\n0 3\n0000000000 65535 f \n")
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "0000000000 00000 f \n")
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 3 >>\n")
  reader_push_ascii(output, "startxref\n0\n%%EOF\n")
  ignore(reader_push_indirect_object(output, 2, 0, "99"))
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_malformed_pdf_with_malformed_startxref_number() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  ignore(reader_push_indirect_object(output, 1, 0, "<< /Type /Catalog >>"))
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\n")
  reader_push_ascii(output, "startxref\nabc\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_malformed_pdf_with_overflow_startxref_number() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  ignore(reader_push_indirect_object(output, 1, 0, "<< /Type /Catalog >>"))
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\n")
  reader_push_ascii(output, "startxref\n2147483648\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_malformed_pdf_with_out_of_range_startxref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  ignore(reader_push_indirect_object(output, 1, 0, "<< /Type /Catalog >>"))
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\n")
  reader_push_ascii(output, "startxref\n999999\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
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
#warnings("-unused_value")
fn reader_malformed_pdf_with_bad_xref_subsection_count() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  ignore(reader_push_indirect_object(output, 1, 0, "<< /Type /Catalog >>"))
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 /Bad\n0000000000 65535 f \n")
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
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
#warnings("-unused_value")
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
#warnings("-unused_value")
fn reader_malformed_pdf_with_bad_object_offset() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let junk_offset = output.length()
  reader_push_ascii(output, "notobject\n")
  ignore(reader_push_indirect_object(output, 1, 0, "<< /Type /Catalog >>"))
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, junk_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_malformed_pdf_with_indirect_stream_length() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  ignore(
    reader_push_indirect_object(
      output, 1, 0, "<< /Length 2 0 R >>\nstream\nHello\nendstream",
    ),
  )
  ignore(reader_push_indirect_object(output, 2, 0, "5"))
  ignore(
    reader_push_indirect_object(
      output, 3, 0, "<< /Type /Catalog /Payload 1 0 R >>",
    ),
  )
  ignore(
    reader_push_indirect_object(
      output, 4, 0, "<< /Length 9 0 R >>\nstream\nIgnored\nendstream",
    ),
  )
  reader_push_ascii(output, "trailer\n<< /Root 3 0 R /Size 5 >>\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_malformed_pdf_with_object_header_inside_stream() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  ignore(
    reader_push_indirect_object(
      output, 1, 0, "<< /Type /Catalog /Payload 2 0 R >>",
    ),
  )
  reader_push_ascii(output, "2 0 obj\n<< /Length 35 >>\nstream\n")
  reader_push_ascii(output, "9 0 obj\n<< /Type /Catalog >>\nendobj")
  reader_push_ascii(output, "\nendstream\nendobj\n")
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 3 >>\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_malformed_pdf_with_nested_object_header_in_bad_object() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  reader_push_ascii(output, "1 0 obj\n]\n")
  reader_push_ascii(output, "2 0 obj\n<< /Type /Catalog >>\nendobj\n")
  reader_push_ascii(output, "3 0 obj\n<< /Type /Catalog >>\nendobj\n")
  reader_push_ascii(output, "trailer\n<< /Root 3 0 R /Size 4 >>\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_pdf_with_unreadable_stream_and_catalog() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let stream_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Length 9 0 R >>\nstream\nHello\nendstream",
  )
  let catalog_offset = reader_push_indirect_object(
    output, 2, 0, "<< /Type /Catalog /Payload 1 0 R >>",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 3\n0000000000 65535 f \n")
  reader_push_xref_entry(output, stream_offset, 0)
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 2 0 R /Size 3 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_pdf_with_malformed_stream_and_catalog(
  stream_body : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let stream_offset = reader_push_indirect_object(output, 1, 0, stream_body)
  let catalog_offset = reader_push_indirect_object(
    output, 2, 0, "<< /Type /Catalog /Payload 1 0 R >>",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 3\n0000000000 65535 f \n")
  reader_push_xref_entry(output, stream_offset, 0)
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 2 0 R /Size 3 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_pdf_with_truncated_stream_before_catalog() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Payload 2 0 R >>",
  )
  let stream_offset = output.length()
  reader_push_ascii(output, "2 0 obj\n<< /Length 1000 >>\nstream\nHi\n")
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 1\n0000000000 65535 f \n")
  reader_push_ascii(output, "2 1\n")
  reader_push_xref_entry(output, stream_offset, 0)
  reader_push_ascii(output, "1 1\n")
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 3 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_pdf_with_malformed_object_before_catalog(
  bad_body : String,
) -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Payload 2 0 R >>",
  )
  let bad_offset = reader_push_indirect_object(output, 2, 0, bad_body)
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 1\n0000000000 65535 f \n")
  reader_push_ascii(output, "2 1\n")
  reader_push_xref_entry(output, bad_offset, 0)
  reader_push_ascii(output, "1 1\n")
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 3 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

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
  let encoded = @pdflite.pdf_flate_encode(predicted)
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
  let encoded_object_stream = @pdflite.pdf_flate_encode(
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
  let encoded_object_stream = @pdflite.pdf_ascii_hex_encode(
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

///|
#warnings("-unused_value")
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
#warnings("-unused_value")
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
#warnings("-unused_value")
fn reader_classic_catalog_pdf_with_prev_xref_bad_startxref() -> @pdflite.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let original_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Revision 1 >>",
  )
  let base_xref = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, original_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\nstartxref\n")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  let updated_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog /Revision 2 >>",
  )
  let second_offset = reader_push_indirect_object(output, 2, 0, "3")
  reader_push_ascii(output, "xref\n1 2\n")
  reader_push_xref_entry(output, updated_offset, 0)
  reader_push_xref_entry(output, second_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 3 /Prev ")
  reader_push_ascii(output, base_xref.to_string())
  reader_push_ascii(output, " >>\nstartxref\n0\n%%EOF\n")
  Bytes::from_array(output)
}
