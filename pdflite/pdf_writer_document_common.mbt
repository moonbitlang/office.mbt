///|
fn pdf_writer_push_padded_decimal(
  output : Array[Byte],
  value : Int,
  width : Int,
) -> Unit {
  let text = value.to_string()
  if text.length() < width {
    for _ in 0..<(width - text.length()) {
      pdf_writer_push_byte(output, 48)
    }
  }
  pdf_writer_push_ascii(output, text)
}

///|
fn pdf_writer_push_header(
  output : Array[Byte],
  major : Int,
  minor : Int,
) -> Unit {
  pdf_writer_push_ascii(output, "%PDF-")
  pdf_writer_push_ascii(output, major.to_string())
  pdf_writer_push_byte(output, 46)
  pdf_writer_push_ascii(output, minor.to_string())
  pdf_writer_push_ascii(output, "\n%")
  for value in [226, 227, 207, 211] {
    pdf_writer_push_byte(output, value)
  }
  pdf_writer_push_byte(output, 10)
}

///|
fn pdf_writer_write_document_objects(
  output : Array[Byte],
  document : PdfDocument,
) -> Array[(Int, Int, Int)] raise @core.PdfError {
  let object_numbers = document.object_numbers()
  let xrefs : Array[(Int, Int, Int)] = Array::new(
    capacity=object_numbers.length(),
  )
  for number in object_numbers {
    match document.objects.get_entry(number).unwrap() {
      { data: ObjectParsed(object), generation }
      | { data: ObjectParsedAlreadyDecrypted(object), generation } => {
        xrefs.push((number, output.length(), generation))
        pdf_writer_push_view(
          output,
          pdf_write_indirect_object({ number, generation, object }),
        )
      }
      _ => raise ParsedObjectExpected
    }
  }
  xrefs
}

///|
let pdf_writer_root_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  Bytes::from_array([47, 82, 111, 111, 116]),
)

///|
fn pdf_writer_root_name() -> @core.PdfName {
  pdf_writer_root_key_name
}

///|
let pdf_writer_size_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  Bytes::from_array([47, 83, 105, 122, 101]),
)

///|
fn pdf_writer_size_name() -> @core.PdfName {
  pdf_writer_size_key_name
}

///|
let pdf_writer_type_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  Bytes::from_array([47, 84, 121, 112, 101]),
)

///|
fn pdf_writer_type_name() -> @core.PdfName {
  pdf_writer_type_key_name
}

///|
let pdf_writer_xref_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  Bytes::from_array([47, 88, 82, 101, 102]),
)

///|
fn pdf_writer_xref_name() -> @core.PdfName {
  pdf_writer_xref_key_name
}

///|
let pdf_writer_w_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  Bytes::from_array([47, 87]),
)

///|
fn pdf_writer_w_name() -> @core.PdfName {
  pdf_writer_w_key_name
}

///|
let pdf_writer_index_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  Bytes::from_array([47, 73, 110, 100, 101, 120]),
)

///|
fn pdf_writer_index_name() -> @core.PdfName {
  pdf_writer_index_key_name
}

///|
let pdf_writer_prev_key_name : @core.PdfName = @core.pdf_name_of_bytes(
  Bytes::from_array([47, 80, 114, 101, 118]),
)

///|
fn pdf_writer_prev_name() -> @core.PdfName {
  pdf_writer_prev_key_name
}

///|
let pdf_writer_flate_decode_name_value : @core.PdfName = @core.pdf_name_of_bytes(
  Bytes::from_array([47, 70, 108, 97, 116, 101, 68, 101, 99, 111, 100, 101]),
)

///|
fn pdf_writer_flate_decode_name() -> @core.PdfName {
  pdf_writer_flate_decode_name_value
}

///|
fn pdf_writer_trailer_dictionary(
  document : PdfDocument,
) -> @syntax.PdfObject raise @core.PdfError {
  let mut trailer = document.trailer_dict()
  trailer = trailer.add_dict_entry(
    pdf_writer_size_name(),
    PdfInteger(document.objects.max_object_number() + 1),
  )
  if document.root() != 0 {
    trailer = trailer.add_dict_entry(
      pdf_writer_root_name(),
      PdfIndirect(document.root()),
    )
  }
  trailer
}
