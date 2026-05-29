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
