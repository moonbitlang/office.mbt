///|
fn pdf_draw_resource_name_number(name : @core.PdfName) -> Int? {
  let bytes = name.bytes()
  let mut start = bytes.length()
  while start > 0 {
    let byte = bytes[start - 1].to_int()
    if byte >= 48 && byte <= 57 {
      start -= 1
    } else {
      break
    }
  }
  if start == bytes.length() {
    None
  } else {
    let mut value = 0
    for index in start..<bytes.length() {
      value = value * 10 + bytes[index].to_int() - 48
    }
    Some(value)
  }
}

///|
fn PdfDocument::pdf_draw_page_resource_numbers(
  self : PdfDocument,
  resources : @syntax.PdfObject,
) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=3)
  for
    key in [
      pdf_draw_xobject_key(),
      pdf_draw_extgstate_key(),
      pdf_draw_font_key(),
    ] {
    match self.lookup_direct(key, resources) {
      Some(PdfDictionary(entries)) =>
        for entry in entries {
          match pdf_draw_resource_name_number(entry.0) {
            Some(number) => output.push(number)
            None => ()
          }
        }
      _ => ()
    }
  }
  output
}

///|
fn PdfDocument::pdf_draw_minimum_resource_number(
  self : PdfDocument,
  selected_pages : @core.PdfNumberSet,
) -> Int raise @core.PdfError {
  let pages = self.pages_of_pagetree()
  let mut maximum = -1
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      for number in self.pdf_draw_page_resource_numbers(pages[index].resources) {
        if number > maximum {
          maximum = number
        }
      }
    }
  }
  if maximum < 0 {
    0
  } else {
    maximum + 1
  }
}
