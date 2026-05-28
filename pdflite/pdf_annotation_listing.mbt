///|
fn PdfDocument::pdf_annotation_contents_text(
  self : PdfDocument,
  encoding : PdfMetadataEncoding,
  annotation : PdfObject,
) -> PdfBytes raise PdfError {
  match self.lookup_direct(pdf_annotation_contents_key(), annotation) {
    Some(PdfString(contents)) => pdf_metadata_encode_output(encoding, contents)
    _ => []
  }
}

///|
fn pdf_annotation_write_listing_view(
  output : Array[Byte],
  position : Int,
  data : BytesView,
) -> Int {
  let mut current = position
  for byte in data {
    output[current] = byte
    current += 1
  }
  current
}

///|
fn pdf_annotation_write_listing_ascii(
  output : Array[Byte],
  position : Int,
  text : String,
) -> Int {
  pdf_annotation_write_listing_view(output, position, @ascii.encode(text))
}

///|
fn pdf_annotation_write_listing_line(
  output : Array[Byte],
  position : Int,
  page_number : Int,
  contents : BytesView,
) -> Int {
  let mut current = pdf_annotation_write_listing_ascii(
    output, position, "Page ",
  )
  current = pdf_annotation_write_listing_ascii(
    output,
    current,
    page_number.to_string(),
  )
  current = pdf_annotation_write_listing_ascii(output, current, ": ")
  current = pdf_annotation_write_listing_view(output, current, contents)
  output[current] = 10
  current + 1
}

///|
fn pdf_annotation_listing_line_length(
  page_number : Int,
  contents : BytesView,
) -> Int {
  @ascii.encode("Page ").length() +
  @ascii.encode(page_number.to_string()).length() +
  @ascii.encode(": ").length() +
  contents.length() +
  1
}

///|
/// Return old-style annotation contents as `(page_number, contents)` pairs.
///
/// Every annotation entry contributes one pair. Annotations without `/Contents`
/// contribute an empty byte string, matching cpdf's old list behavior.
pub fn PdfDocument::get_annotations(
  self : PdfDocument,
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
) -> Array[(Int, PdfBytes)] raise PdfError {
  let pages = self.pages_of_pagetree()
  let output : Array[(Int, PdfBytes)] = Array::new(capacity=pages.length())
  for index, page in pages {
    match self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
      Some(PdfArray(annotations)) =>
        for annotation in annotations {
          output.push(
            (index + 1, self.pdf_annotation_contents_text(encoding, annotation)),
          )
        }
      _ => ()
    }
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::get_annotations`.
pub fn pdf_get_annotations(
  encoding : PdfMetadataEncoding,
  document : PdfDocument,
) -> Array[(Int, PdfBytes)] raise PdfError {
  document.get_annotations(encoding~)
}

///|
/// Render cpdf's old-style annotation listing for selected pages.
///
/// Unlike `get_annotations`, this suppresses empty `/Contents` entries and
/// returns the bytes cpdf would print instead of writing to stdout.
pub fn PdfDocument::list_annotations(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
) -> PdfBytes raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "list_annotations",
  )
  let selected_pages = @number_set.pdf_number_set(page_numbers)
  let rows : Array[(Int, PdfBytes)] = Array::new(capacity=page_numbers.length())
  let mut output_length = 0
  for index, page in pages {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      match self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
        Some(PdfArray(annotations)) =>
          for annotation in annotations {
            let contents = self.pdf_annotation_contents_text(
              encoding, annotation,
            )
            if contents.length() > 0 {
              output_length += pdf_annotation_listing_line_length(
                page_number, contents,
              )
              rows.push((page_number, contents))
            }
          }
        _ => ()
      }
    }
  }
  let output = Array::make(output_length, b'\x00')
  let mut position = 0
  for row in rows {
    position = pdf_annotation_write_listing_line(output, position, row.0, row.1)
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::list_annotations`.
pub fn pdf_list_annotations(
  page_numbers : ArrayView[Int],
  encoding : PdfMetadataEncoding,
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.list_annotations(page_numbers, encoding~)
}
