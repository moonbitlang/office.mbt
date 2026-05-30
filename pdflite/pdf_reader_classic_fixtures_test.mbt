///|
#warnings("-unused_value")
fn reader_classic_pdf_with_xref_body(
  xref_body : String,
  trailer_body : String,
) -> @core.PdfBytes {
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
#warnings("-unused_value")
fn reader_classic_pdf_with_fixed_width_xref_separators() -> @core.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 2\n")
  reader_push_padded_decimal(output, 0, 10)
  reader_push_ascii(output, "_65535_f \n")
  reader_push_padded_decimal(output, catalog_offset, 10)
  reader_push_ascii(output, "_00000_n \n")
  reader_push_classic_trailer(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_pdf_with_unpadded_xref_entry() -> @core.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n1 1\n")
  reader_push_ascii(output, catalog_offset.to_string())
  reader_push_ascii(output, " 0 n\n")
  reader_push_classic_trailer(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_pdf_with_inline_xref_section_header() -> @core.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref 1 1\n")
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_classic_trailer(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_pdf_with_glued_trailer_dictionary() -> @core.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer<< /Root 1 0 R /Size 2 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_pdf_with_missing_endobj_catalog() -> @core.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let catalog_offset = output.length()
  reader_push_ascii(output, "1 0 obj\n<< /Type /Catalog >>\n")
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_classic_trailer(output, xref_offset, 2)
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_pdf_with_trailing_startxref_junk() -> @core.PdfBytes {
  let output : Array[Byte] = []
  for
    byte in reader_classic_pdf_with_xref_body(
      "0 1\n0000000000 65535 f \n", "<< /Root 1 0 R /Size 1 >>",
    )[:] {
    output.push(byte)
  }
  reader_push_ascii(output, "\nstartxref\nnot-a-number\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_pdf_with_prefixed_startxref_pointer() -> @core.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\n")
  reader_push_ascii(output, "startxref junk=")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_pdf_with_inline_startxref_pointer() -> @core.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let catalog_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Type /Catalog >>",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 2\n0000000000 65535 f \n")
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 2 >>\n")
  reader_push_ascii(output, "startxref ")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_pdf_without_trailer_after_xref() -> @core.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  reader_push_ascii(output, "startxref\n")
  let xref_digits_position = output.length()
  reader_push_ascii(output, "0000000000\n%%EOF\n")
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 1\n0000000000 65535 f \n")
  let digits = @ascii.encode(xref_offset.to_string())
  for i in 0..<digits.length() {
    output[xref_digits_position + 10 - digits.length() + i] = digits[i]
  }
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_pdf_with_self_prev_xref() -> @core.PdfBytes {
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
#warnings("-unused_value")
fn reader_classic_pdf_with_missing_indirect_stream_length() -> @core.PdfBytes {
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
#warnings("-unused_value")
fn reader_classic_pdf_with_non_integer_stream_length() -> @core.PdfBytes {
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
#warnings("-unused_value")
fn reader_classic_pdf_with_unparseable_stream_length() -> @core.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let stream_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Length 2 0 R >>\nstream\nHello\nendstream",
  )
  let length_offset = reader_push_indirect_object(output, 2, 0, "]")
  let catalog_offset = reader_push_indirect_object(
    output, 3, 0, "<< /Type /Catalog /Payload 1 0 R >>",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 4\n0000000000 65535 f \n")
  reader_push_xref_entry(output, stream_offset, 0)
  reader_push_xref_entry(output, length_offset, 0)
  reader_push_xref_entry(output, catalog_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 3 0 R /Size 4 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}

///|
#warnings("-unused_value")
fn reader_classic_pdf_with_mismatched_stream_length_xref() -> @core.PdfBytes {
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
#warnings("-unused_value")
fn reader_classic_pdf_with_stream_length_stream_object() -> @core.PdfBytes {
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
#warnings("-unused_value")
fn reader_classic_pdf_with_negative_stream_length() -> @core.PdfBytes {
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
#warnings("-unused_value")
fn reader_classic_pdf_with_mismatched_object_xref() -> @core.PdfBytes {
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
#warnings("-unused_value")
fn reader_classic_pdf_with_unparseable_xref_object() -> @core.PdfBytes {
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
#warnings("-unused_value")
fn reader_classic_pdf_with_indirect_stream_length() -> @core.PdfBytes {
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
#warnings("-unused_value")
fn reader_classic_pdf_with_comment_stream_indirect_length() -> @core.PdfBytes {
  let output : Array[Byte] = []
  reader_push_ascii(output, "%PDF-1.4\n")
  let stream_offset = reader_push_indirect_object(
    output, 1, 0, "<< /Length 2 0 R >>\nstream\nHello\nendstream",
  )
  let length_offset = reader_push_indirect_object(
    output, 2, 0, "5 % stream appears only in this comment",
  )
  let xref_offset = output.length()
  reader_push_ascii(output, "xref\n0 3\n0000000000 65535 f \n")
  reader_push_xref_entry(output, stream_offset, 0)
  reader_push_xref_entry(output, length_offset, 0)
  reader_push_ascii(output, "trailer\n<< /Root 1 0 R /Size 3 >>\nstartxref\n")
  reader_push_ascii(output, xref_offset.to_string())
  reader_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}
