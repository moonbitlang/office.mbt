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
