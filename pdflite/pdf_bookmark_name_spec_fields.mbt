///|
fn pdf_bookmark_name_spec_scan_to_at(
  bytes : BytesView,
  start : Int,
) -> (Int, Int) {
  let mut end = start
  while end < bytes.length() && bytes[end].to_int() != 64 {
    end = end + 1
  }
  let next = if end < bytes.length() { end + 1 } else { end }
  (end - start, next)
}

///|
fn pdf_bookmark_name_spec_ascii_length(text : String) -> Int {
  @ascii.encode(text).length()
}

///|
fn pdf_bookmark_name_spec_copy_ascii(
  output : Array[Byte],
  position : Int,
  text : String,
) -> Int {
  let mut position = position
  for byte in @ascii.encode(text) {
    output[position] = byte
    position += 1
  }
  position
}

///|
fn pdf_bookmark_name_spec_process_at_fields_length(
  bytes : BytesView,
  bookmark_name : String,
  sequence : Int,
  filename : String,
  start_page : Int,
  end_page : Int,
) -> Int raise PdfError {
  let mut output_length = 0
  let mut index = 0
  while index < bytes.length() {
    if bytes[index].to_int() == 64 && index + 1 < bytes.length() {
      match bytes[index + 1].to_int() {
        70 => {
          output_length += pdf_bookmark_name_spec_ascii_length(filename)
          index = index + 2
        }
        78 | 83 | 69 as field => {
          let (width, next) = pdf_bookmark_name_spec_scan_to_at(
            bytes,
            index + 2,
          )
          let value = match field {
            78 => sequence
            83 => start_page
            _ => end_page
          }
          output_length += pdf_bookmark_name_spec_ascii_length(
            pdf_bookmark_name_spec_padded_number(width, value),
          )
          index = next
        }
        66 => {
          output_length += pdf_bookmark_name_spec_ascii_length(bookmark_name)
          index = index + 2
        }
        98 => {
          let mut digits_end = index + 2
          while digits_end < bytes.length() {
            let digit = bytes[digits_end].to_int()
            if digit < 48 || digit > 57 {
              break
            }
            digits_end = digits_end + 1
          }
          if digits_end == index + 2 {
            raise SoftError("Bad @b spec")
          }
          let length = pdf_bookmark_name_spec_decimal(
            bytes,
            index + 2,
            digits_end,
          )
          output_length += pdf_bookmark_name_spec_ascii_length(
            pdf_bookmark_name_spec_utf8_prefix(bookmark_name, length),
          )
          index = if digits_end < bytes.length() {
            digits_end + 1
          } else {
            digits_end
          }
        }
        _ => {
          output_length += 1
          index = index + 1
        }
      }
    } else {
      output_length += 1
      index = index + 1
    }
  }
  output_length
}

///|
fn PdfDocument::pdf_bookmark_name_spec_process_at_fields(
  self : PdfDocument,
  bookmarks : ArrayView[PdfBookmark],
  split_level : Int,
  spec : String,
  sequence : Int,
  filename : String,
  start_page : Int,
  end_page : Int,
) -> String raise PdfError {
  let bytes = @utf8.encode(spec)
  let bookmark_name = self.pdf_bookmark_name_for_page(
    bookmarks, split_level, start_page,
  )
  let output = Array::make(
    pdf_bookmark_name_spec_process_at_fields_length(
      bytes, bookmark_name, sequence, filename, start_page, end_page,
    ),
    b'\x00',
  )
  let mut position = 0
  let mut index = 0
  while index < bytes.length() {
    if bytes[index].to_int() == 64 && index + 1 < bytes.length() {
      match bytes[index + 1].to_int() {
        70 => {
          position = pdf_bookmark_name_spec_copy_ascii(
            output, position, filename,
          )
          index = index + 2
        }
        78 | 83 | 69 as field => {
          let (width, next) = pdf_bookmark_name_spec_scan_to_at(
            bytes,
            index + 2,
          )
          let value = match field {
            78 => sequence
            83 => start_page
            _ => end_page
          }
          position = pdf_bookmark_name_spec_copy_ascii(
            output,
            position,
            pdf_bookmark_name_spec_padded_number(width, value),
          )
          index = next
        }
        66 => {
          position = pdf_bookmark_name_spec_copy_ascii(
            output, position, bookmark_name,
          )
          index = index + 2
        }
        98 => {
          let mut digits_end = index + 2
          while digits_end < bytes.length() {
            let digit = bytes[digits_end].to_int()
            if digit < 48 || digit > 57 {
              break
            }
            digits_end = digits_end + 1
          }
          if digits_end == index + 2 {
            raise SoftError("Bad @b spec")
          }
          let length = pdf_bookmark_name_spec_decimal(
            bytes,
            index + 2,
            digits_end,
          )
          position = pdf_bookmark_name_spec_copy_ascii(
            output,
            position,
            pdf_bookmark_name_spec_utf8_prefix(bookmark_name, length),
          )
          index = if digits_end < bytes.length() {
            digits_end + 1
          } else {
            digits_end
          }
        }
        _ => {
          output[position] = bytes[index]
          position += 1
          index = index + 1
        }
      }
    } else {
      output[position] = bytes[index]
      position += 1
      index = index + 1
    }
  }
  @utf8.decode(Bytes::from_array(output)) catch {
    _ => raise InvalidUTF8
  }
}
