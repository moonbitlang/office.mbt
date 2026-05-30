///|
fn pdf_image_add_unique_page(pages : Array[Int], page_number : Int) -> Unit {
  if !pages.contains(page_number) {
    pages.push(page_number)
  }
}

///|
fn pdf_image_list_find_entry(
  entries : ArrayView[PdfImageListEntry],
  object_number : Int,
) -> Int {
  if object_number <= 0 {
    -1
  } else {
    for index in 0..<entries.length() {
      if entries[index].object_number == object_number {
        break index
      }
    } nobreak {
      -1
    }
  }
}

///|
fn PdfDocument::pdf_image_list_add_image(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  page_number : Int,
  name : PdfName,
  image : @syntax.PdfObject,
  object_number : Int,
  data_length : Int,
  inline : Bool,
  entries : Array[PdfImageListEntry],
  form_numbers : @hashmap.HashMap[Int, Bool],
) -> Unit raise PdfError {
  let existing = pdf_image_list_find_entry(entries, object_number)
  if existing >= 0 {
    pdf_image_add_unique_page(entries[existing].pages, page_number)
  } else {
    let (mask, mask_object_number) = self.pdf_image_list_mask(
      resources, page_number, image, inline, entries, form_numbers,
    )
    entries.push({
      object_number,
      pages: [page_number],
      name: pdf_image_name_to_string(name),
      width: self.pdf_image_lookup_int_or_default(
        pdf_image_width_key(),
        pdf_image_w_key(),
        image,
        1,
      ),
      height: self.pdf_image_lookup_int_or_default(
        pdf_image_height_key(),
        pdf_image_h_key(),
        image,
        1,
      ),
      byte_count: self.pdf_image_stream_length(image, data_length),
      bits_per_component: self.pdf_image_bits_per_component_number(image),
      colourspace: self.pdf_image_colourspace_name(image, resources),
      filter: self.pdf_image_filter_name(image),
      mask,
      mask_object_number,
    })
  }
}
