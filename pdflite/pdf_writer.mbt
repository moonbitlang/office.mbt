///|
fn pdf_writer_push_byte(output : Array[Byte], value : Int) -> Unit {
  output.push(value.to_byte())
}

///|
fn pdf_writer_push_view(output : Array[Byte], view : BytesView) -> Unit {
  for byte in view {
    output.push(byte)
  }
}

///|
fn pdf_writer_push_ascii(output : Array[Byte], text : String) -> Unit {
  pdf_writer_push_view(output, @ascii.encode(text)[:])
}

///|
fn pdf_writer_hex_digit(value : Int) -> Byte {
  if value < 10 {
    (48 + value).to_byte()
  } else {
    (55 + value).to_byte()
  }
}

///|
fn pdf_writer_push_hex_escape(output : Array[Byte], value : Int) -> Unit {
  pdf_writer_push_byte(output, 35)
  output.push(pdf_writer_hex_digit(value / 16))
  output.push(pdf_writer_hex_digit(value % 16))
}

///|
fn pdf_writer_push_octal_escape(output : Array[Byte], value : Int) -> Unit {
  pdf_writer_push_byte(output, 92)
  pdf_writer_push_byte(output, 48 + value / 64)
  pdf_writer_push_byte(output, 48 + value / 8 % 8)
  pdf_writer_push_byte(output, 48 + value % 8)
}

///|
fn pdf_writer_length_name() -> PdfName {
  pdf_name_of_bytes(Bytes::from_array([47, 76, 101, 110, 103, 116, 104]))
}

///|
fn pdf_write_stream_dictionary(stream : PdfStream) -> PdfObject raise PdfError {
  match stream.data {
    StreamGot(bytes) =>
      stream.dictionary.add_dict_entry(
        pdf_writer_length_name(),
        PdfInteger(bytes.length()),
      )
    StreamToGet(_) => raise StreamDataExpected
  }
}

///|
fn pdf_write_name_to(output : Array[Byte], name : PdfName) -> Unit {
  let bytes = name.bytes()
  let mut start = 0
  pdf_writer_push_byte(output, 47)
  if bytes.length() > 0 && bytes[0].to_int() == 47 {
    start = 1
  }
  for i = start; i < bytes.length(); i = i + 1 {
    let value = bytes[i].to_int()
    if value < 33 || value > 126 || pdf_is_delimiter_byte(value) || value == 35 {
      pdf_writer_push_hex_escape(output, value)
    } else {
      output.push(bytes[i])
    }
  }
}

///|
fn pdf_write_string_to(output : Array[Byte], bytes : PdfBytes) -> Unit {
  pdf_writer_push_byte(output, 40)
  for byte in bytes {
    let value = byte.to_int()
    match value {
      40 => pdf_writer_push_ascii(output, "\\(")
      41 => pdf_writer_push_ascii(output, "\\)")
      92 => pdf_writer_push_ascii(output, "\\\\")
      10 => pdf_writer_push_ascii(output, "\\n")
      13 => pdf_writer_push_ascii(output, "\\r")
      9 => pdf_writer_push_ascii(output, "\\t")
      8 => pdf_writer_push_ascii(output, "\\b")
      12 => pdf_writer_push_ascii(output, "\\f")
      value if value >= 32 && value <= 126 => output.push(byte)
      _ => pdf_writer_push_octal_escape(output, value)
    }
  }
  pdf_writer_push_byte(output, 41)
}

///|
fn pdf_write_object_to(
  output : Array[Byte],
  object : PdfObject,
) -> Unit raise PdfError {
  match object {
    PdfNull => pdf_writer_push_ascii(output, "null")
    PdfBoolean(true) => pdf_writer_push_ascii(output, "true")
    PdfBoolean(false) => pdf_writer_push_ascii(output, "false")
    PdfInteger(value) => pdf_writer_push_ascii(output, value.to_string())
    PdfReal(value) => pdf_writer_push_ascii(output, value.to_string())
    PdfString(bytes) => pdf_write_string_to(output, bytes)
    PdfNameObject(name) => pdf_write_name_to(output, name)
    PdfArray(values) => {
      pdf_writer_push_byte(output, 91)
      for i = 0; i < values.length(); i = i + 1 {
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
      pdf_write_object_to(output, pdf_write_stream_dictionary(stream))
      pdf_writer_push_ascii(output, "\nstream\n")
      match stream.data {
        StreamGot(bytes) => pdf_writer_push_view(output, bytes[:])
        StreamToGet(_) => raise StreamDataExpected
      }
      pdf_writer_push_ascii(output, "\nendstream")
    }
    PdfIndirect(number) => {
      pdf_writer_push_ascii(output, number.to_string())
      pdf_writer_push_ascii(output, " 0 R")
    }
  }
}

///|
pub fn pdf_write_object(object : PdfObject) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  pdf_write_object_to(output, object)
  Bytes::from_array(output)
}

///|
pub fn pdf_write_indirect_object(
  object : PdfParsedIndirectObject,
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
fn pdf_writer_root_name() -> PdfName {
  pdf_name_of_bytes(Bytes::from_array([47, 82, 111, 111, 116]))
}

///|
fn pdf_writer_size_name() -> PdfName {
  pdf_name_of_bytes(Bytes::from_array([47, 83, 105, 122, 101]))
}

///|
fn pdf_writer_trailer_dictionary(
  document : PdfDocument,
) -> PdfObject raise PdfError {
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

///|
pub fn pdf_write_document(document : PdfDocument) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  let xrefs : Array[(Int, Int, Int)] = []
  let (major, minor) = document.version()
  pdf_writer_push_ascii(output, "%PDF-")
  pdf_writer_push_ascii(output, major.to_string())
  pdf_writer_push_byte(output, 46)
  pdf_writer_push_ascii(output, minor.to_string())
  pdf_writer_push_ascii(output, "\n%")
  for value in [226, 227, 207, 211] {
    pdf_writer_push_byte(output, value)
  }
  pdf_writer_push_byte(output, 10)
  for number in document.object_numbers() {
    match document.objects.get_entry(number) {
      Some({ data: ObjectParsed(object), generation })
      | Some({ data: ObjectParsedAlreadyDecrypted(object), generation }) => {
        xrefs.push((number, output.length(), generation))
        pdf_writer_push_view(
          output,
          pdf_write_indirect_object({ number, generation, object })[:],
        )
      }
      Some(_) => raise ParsedObjectExpected
      None => ()
    }
  }
  let xref_start = output.length()
  let size = document.objects.max_object_number() + 1
  pdf_writer_push_ascii(output, "xref\n0 ")
  pdf_writer_push_ascii(output, size.to_string())
  pdf_writer_push_byte(output, 10)
  pdf_writer_push_ascii(output, "0000000000 65535 f \n")
  let mut xref_index = 0
  for number = 1; number < size; number = number + 1 {
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
  pdf_writer_push_view(
    output,
    pdf_write_object(pdf_writer_trailer_dictionary(document))[:],
  )
  pdf_writer_push_ascii(output, "\nstartxref\n")
  pdf_writer_push_ascii(output, xref_start.to_string())
  pdf_writer_push_ascii(output, "\n%%EOF\n")
  Bytes::from_array(output)
}
