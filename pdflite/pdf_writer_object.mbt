///|
let pdf_writer_length_key_name : PdfName = pdf_name_of_bytes(
  Bytes::from_array([47, 76, 101, 110, 103, 116, 104]),
)

///|
fn pdf_writer_length_name() -> PdfName {
  pdf_writer_length_key_name
}

///|
fn pdf_write_stream_dictionary(
  stream : @syntax.PdfStream,
  length : Int,
) -> @syntax.PdfObject raise PdfError {
  stream.dictionary.add_dict_entry(pdf_writer_length_name(), PdfInteger(length))
}

///|
fn pdf_write_object_to(
  output : Array[Byte],
  object : @syntax.PdfObject,
) -> Unit raise PdfError {
  match object {
    PdfNull => pdf_writer_push_ascii(output, "null")
    PdfBoolean(true) => pdf_writer_push_ascii(output, "true")
    PdfBoolean(false) => pdf_writer_push_ascii(output, "false")
    PdfInteger(value) => pdf_writer_push_ascii(output, value.to_string())
    PdfReal(value) => pdf_writer_push_real(output, value)
    PdfString(bytes) => pdf_write_string_to(output, bytes)
    PdfNameObject(name) => pdf_write_name_to(output, name)
    PdfArray(values) => {
      pdf_writer_push_byte(output, 91)
      for i in 0..<values.length() {
        if i > 0 {
          pdf_writer_push_byte(output, 32)
        }
        pdf_write_object_to(output, values[i])
      }
      pdf_writer_push_byte(output, 93)
    }
    PdfDictionary(entries) => {
      pdf_writer_push_ascii(output, "<<")
      for entry in entries {
        let (name, value) = entry
        pdf_writer_push_byte(output, 32)
        pdf_write_name_to(output, name)
        pdf_writer_push_byte(output, 32)
        pdf_write_object_to(output, value)
      }
      pdf_writer_push_ascii(output, " >>")
    }
    PdfStreamObject(stream) => {
      let bytes = @syntax.pdf_stream_data_view(stream.data)
      pdf_write_object_to(
        output,
        pdf_write_stream_dictionary(stream, bytes.length()),
      )
      pdf_writer_push_ascii(output, "\nstream\n")
      pdf_writer_push_view(output, bytes)
      pdf_writer_push_ascii(output, "\nendstream")
    }
    PdfIndirect(number) => {
      pdf_writer_push_ascii(output, number.to_string())
      pdf_writer_push_ascii(output, " 0 R")
    }
  }
}

///|
/// Serialize a direct PDF object.
///
/// Stream lengths are refreshed from the current stream data while writing.
pub fn pdf_write_object(object : @syntax.PdfObject) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  pdf_write_object_to(output, object)
  Bytes::from_array(output)
}

///|
/// Compatibility alias for `pdf_write_object`.
pub fn pdf_string_of_pdf(object : @syntax.PdfObject) -> PdfBytes raise PdfError {
  pdf_write_object(object)
}

///|
/// Compatibility alias for `pdf_write_object`.
///
/// Stream data is included because `PdfStreamObject` serialization writes the
/// stream dictionary, `stream` marker, bytes, and `endstream` marker.
pub fn pdf_string_of_pdf_including_data(
  object : @syntax.PdfObject,
) -> PdfBytes raise PdfError {
  pdf_write_object(object)
}

///|
/// Serialize one indirect object including `obj` and `endobj` wrappers.
pub fn pdf_write_indirect_object(
  object : @syntax.PdfParsedIndirectObject,
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  pdf_writer_push_ascii(output, object.number.to_string())
  pdf_writer_push_byte(output, 32)
  pdf_writer_push_ascii(output, object.generation.to_string())
  pdf_writer_push_ascii(output, " obj\n")
  pdf_write_object_to(output, object.object)
  pdf_writer_push_ascii(output, "\nendobj\n")
  Bytes::from_array(output)
}
