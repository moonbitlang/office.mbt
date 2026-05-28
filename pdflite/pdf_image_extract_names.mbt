///|
fn pdf_image_replace_percent_objnum(stem : String) -> String {
  let input = @utf8.encode(stem)
  let pattern = b"%objnum"
  let mut output_length = input.length()
  let mut index = 0
  while index < input.length() {
    let mut matched = index + pattern.length() <= input.length()
    if matched {
      for pattern_index in 0..<pattern.length() {
        if input[index + pattern_index] != pattern[pattern_index] {
          matched = false
          break
        }
      }
    }
    if matched {
      output_length = output_length - pattern.length() + 2
      index += pattern.length()
    } else {
      index += 1
    }
  }
  let output = Array::make(output_length, b'\x00')
  let mut position = 0
  index = 0
  while index < input.length() {
    let mut matched = index + pattern.length() <= input.length()
    if matched {
      for pattern_index in 0..<pattern.length() {
        if input[index + pattern_index] != pattern[pattern_index] {
          matched = false
          break
        }
      }
    }
    if matched {
      output[position] = 64
      output[position + 1] = 83
      position += 2
      index += pattern.length()
    } else {
      output[position] = input[index]
      position += 1
      index += 1
    }
  }
  @utf8.decode(Bytes::from_array(output)) catch {
    _ => stem
  }
}

///|
fn PdfDocument::pdf_image_extraction_name(
  self : PdfDocument,
  encoding : PdfMetadataEncoding,
  stem : String,
  page_number : Int,
  image : PdfObject,
  state : PdfImageExtractionRunState,
) -> String raise PdfError {
  let object_number = match image {
    PdfIndirect(number) => number
    _ => 0
  }
  self.bookmark_name_of_spec(
    encoding,
    [],
    0,
    pdf_image_replace_percent_objnum(stem) + "-p" + page_number.to_string(),
    state.next_serial(),
    "",
    object_number,
    0,
  )
}
