///|
fn PdfDocument::pdf_font_has_embedded_file(
  self : PdfDocument,
  descriptor : PdfObject,
) -> Bool {
  self.lookup_direct(pdf_text_font_file_key_name, descriptor) is Some(_) ||
  self.lookup_direct(pdf_text_font_file2_key_name, descriptor) is Some(_) ||
  self.lookup_direct(pdf_text_font_file3_key_name, descriptor) is Some(_)
}

///|
/// Return whether a font dictionary has no embedded font program.
///
/// Type 3 fonts are never reported as missing, matching cpdf. Other fonts are
/// missing when they have no `/FontDescriptor`, or when their descriptor lacks
/// `/FontFile`, `/FontFile2`, and `/FontFile3`.
pub fn PdfDocument::is_missing_font(
  self : PdfDocument,
  font : PdfObject,
) -> Bool {
  match self.lookup_direct(pdf_text_subtype_key_name, font) {
    Some(PdfNameObject(name)) if name == pdf_text_type3_name => false
    _ =>
      match self.lookup_direct(pdf_text_font_descriptor_key_name, font) {
        None => true
        Some(descriptor) => !self.pdf_font_has_embedded_file(descriptor)
      }
  }
}

///|
fn PdfDocument::pdf_missing_font_entry(
  self : PdfDocument,
  page : Int,
  name : PdfName,
  font : PdfObject,
) -> @font.PdfMissingFontEntry raise PdfError {
  let encoding = match
    self.pdf_font_name_field(font, pdf_text_encoding_key_name) {
    "" => "Built-in"
    value => value
  }
  {
    page,
    name: pdf_util_string_from_name(name),
    subtype: self.pdf_font_name_field(font, pdf_text_subtype_key_name),
    basefont: self.pdf_font_name_field(font, pdf_text_base_font_key_name),
    encoding,
  }
}

///|
fn PdfDocument::pdf_missing_font_candidates(
  self : PdfDocument,
  name : PdfName,
  font : PdfObject,
) -> Array[(PdfName, PdfObject)] {
  match self.lookup_direct(pdf_text_descendant_fonts_key_name, font) {
    Some(PdfArray(descendants)) =>
      [
        for descendant in descendants => (name, descendant)
      ]
    _ => [(name, font)]
  }
}

///|
fn PdfDocument::pdf_missing_fonts_on_page(
  self : PdfDocument,
  page : Int,
  resources : PdfObject,
) -> Array[@font.PdfMissingFontEntry] raise PdfError {
  match self.lookup_direct(pdf_page_font_resource_name, resources) {
    Some(PdfDictionary(fonts)) => {
      let output : Array[@font.PdfMissingFontEntry] = Array::new(
        capacity=fonts.length(),
      )
      for font_entry in fonts {
        for
          candidate in self.pdf_missing_font_candidates(
            font_entry.0,
            font_entry.1,
          ) {
          if self.is_missing_font(candidate.1) {
            output.push(
              self.pdf_missing_font_entry(page, candidate.0, candidate.1),
            )
          }
        }
      }
      output
    }
    _ => []
  }
}

///|
/// Return cpdf's missing-font report for selected pages.
///
/// This follows cpdf's current behavior by inspecting page `/Font` resources and
/// descendant fonts. It does not recurse into Form XObjects; the cpdf source
/// marks that as a separate FIXME.
pub fn PdfDocument::missing_fonts(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Array[@font.PdfMissingFontEntry] raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "missing_fonts",
  )
  let selected_pages = @core.pdf_number_set(page_numbers)
  let output : Array[@font.PdfMissingFontEntry] = Array::new(
    capacity=page_numbers.length(),
  )
  for index, page in pages {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      output.append(self.pdf_missing_fonts_on_page(page_number, page.resources))
    }
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::missing_fonts`.
pub fn pdf_missing_fonts(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Array[@font.PdfMissingFontEntry] raise PdfError {
  document.missing_fonts(page_numbers)
}

///|
fn pdf_missing_font_entry_tuple(
  entry : @font.PdfMissingFontEntry,
) -> (Int, String, String, String, String) {
  (entry.page, entry.name, entry.subtype, entry.basefont, entry.encoding)
}

///|
/// Return cpdffont's `missing_fonts_return` tuple rows.
pub fn PdfDocument::missing_fonts_return(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Array[(Int, String, String, String, String)] raise PdfError {
  [
    for entry in self.missing_fonts(page_numbers) => {
      pdf_missing_font_entry_tuple(entry)
    }
  ]
}

///|
/// Compatibility wrapper for `PdfDocument::missing_fonts_return`.
pub fn pdf_missing_fonts_return(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Array[(Int, String, String, String, String)] raise PdfError {
  document.missing_fonts_return(page_numbers)
}

///|
fn pdf_missing_font_write_text(
  output : Array[Byte],
  position : Int,
  entry : @font.PdfMissingFontEntry,
) -> Int {
  let mut current = pdf_font_write_utf8(
    output,
    position,
    entry.page.to_string(),
  )
  current = pdf_font_write_utf8(output, current, ", ")
  current = pdf_font_write_utf8(output, current, entry.name)
  current = pdf_font_write_utf8(output, current, ", ")
  current = pdf_font_write_utf8(output, current, entry.subtype)
  current = pdf_font_write_utf8(output, current, ", ")
  current = pdf_font_write_utf8(output, current, entry.basefont)
  current = pdf_font_write_utf8(output, current, ", ")
  current = pdf_font_write_utf8(output, current, entry.encoding)
  output[current] = 10
  current + 1
}

///|
fn pdf_missing_font_text_length(entry : @font.PdfMissingFontEntry) -> Int {
  pdf_font_utf8_length(entry.page.to_string()) +
  pdf_font_utf8_length(entry.name) +
  pdf_font_utf8_length(entry.subtype) +
  pdf_font_utf8_length(entry.basefont) +
  pdf_font_utf8_length(entry.encoding) +
  9
}

///|
fn pdf_missing_fonts_text_length(
  entries : ArrayView[@font.PdfMissingFontEntry],
) -> Int {
  let mut length = 0
  for entry in entries {
    length += pdf_missing_font_text_length(entry)
  }
  length
}

///|
/// Render cpdf's plain-text missing-font report for selected pages.
pub fn PdfDocument::missing_fonts_text(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfBytes raise PdfError {
  let entries = self.missing_fonts(page_numbers)
  let output = Array::make(pdf_missing_fonts_text_length(entries), b'\x00')
  let mut position = 0
  for entry in entries {
    position = pdf_missing_font_write_text(output, position, entry)
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::missing_fonts_text`.
pub fn pdf_missing_fonts_text(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfBytes raise PdfError {
  document.missing_fonts_text(page_numbers)
}
