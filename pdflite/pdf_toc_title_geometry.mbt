///|
fn pdf_toc_title_elements(
  fontpack : PdfFontPack,
  font_size : Double,
  title : BytesView,
  process_struct_tree : Bool,
) -> Array[PdfTypeElement] raise PdfError {
  let output : Array[PdfTypeElement] = []
  pdf_toc_append_optional_elements(output, process_struct_tree, [
    PdfTypeTag("P", 0),
  ])
  for line in pdf_toc_split_title(title) {
    pdf_toc_append_elements(
      output,
      pdf_toc_of_utf8(fontpack, font_size * 2.0, line),
    )
    output.push(PdfTypeNewLine)
  }
  pdf_toc_append_optional_elements(output, process_struct_tree, [PdfTypeEndTag])
  output.push(PdfTypeVGlue(font_size * 2.0))
  output
}

///|
fn pdf_toc_first_font(
  elements : ArrayView[PdfTypeElement],
) -> PdfTypeElement raise PdfError {
  for element in elements {
    match element {
      PdfTypeFont(_, _, _) => return element
      _ => ()
    }
  }
  raise SoftError("toc_type_elements: no font")
}

///|
fn pdf_toc_rectangle_object(rectangle : @geometry.PdfRectangle) -> PdfObject {
  PdfArray([
    PdfReal(rectangle.min_x),
    PdfReal(rectangle.min_y),
    PdfReal(rectangle.max_x),
    PdfReal(rectangle.max_y),
  ])
}

///|
fn pdf_toc_cropbox_page(
  page : @page.PdfPage,
  cropbox : PdfObject?,
) -> @page.PdfPage raise PdfError {
  match cropbox {
    Some(cropbox) =>
      {
        ..page,
        rest: page.rest.add_dict_entry(pdf_page_cropbox_key(), cropbox),
      }
    None => page
  }
}

///|
fn pdf_toc_cropbox_pages(
  pages : ArrayView[@page.PdfPage],
  cropbox : PdfObject?,
) -> Array[@page.PdfPage] raise PdfError {
  let output : Array[@page.PdfPage] = []
  for page in pages {
    output.push(pdf_toc_cropbox_page(page, cropbox))
  }
  output
}

///|
/// Split a TOC title on the literal byte sequence `\n`.
///
/// This mirrors `cpdftoc.ml`'s `split_toc_title`, which splits before UTF-8
/// conversion and preserves leading, trailing, and adjacent empty title lines.
pub fn pdf_toc_split_title(title : BytesView) -> Array[PdfBytes] {
  let lines : Array[PdfBytes] = []
  let mut line_start = 0
  let mut index = 0
  while index < title.length() {
    if title[index] == b'\\' &&
      index + 1 < title.length() &&
      title[index + 1] == b'n' {
      lines.push(pdf_bytes_of_view(title[line_start:index]))
      index += 2
      line_start = index
    } else {
      index += 1
    }
  }
  lines.push(pdf_bytes_of_view(title[line_start:]))
  lines
}

///|
/// Replace literal `\n` byte pairs in a TOC title with real line-feed bytes.
pub fn pdf_toc_title_real_newlines(title : BytesView) -> PdfBytes {
  let mut length = 0
  let mut index = 0
  while index < title.length() {
    length += 1
    if title[index] == b'\\' &&
      index + 1 < title.length() &&
      title[index + 1] == b'n' {
      index += 2
    } else {
      index += 1
    }
  }
  let output = Array::make(length, b'\x00')
  let mut position = 0
  index = 0
  while index < title.length() {
    if title[index] == b'\\' &&
      index + 1 < title.length() &&
      title[index + 1] == b'n' {
      output[position] = b'\n'
      position += 1
      index += 2
    } else {
      output[position] = title[index]
      position += 1
      index += 1
    }
  }
  Bytes::from_array(output)
}
