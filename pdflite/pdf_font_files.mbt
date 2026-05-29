///|
/// Return the object number referenced by an embedded font-file marker.
pub fn PdfFontFile::object_number(self : PdfFontFile) -> Int {
  match self {
    PdfFontFile(number) | PdfFontFile2(number) | PdfFontFile3(number) => number
  }
}

///|
/// Return the embedded font-file stream object number for a parsed font.
pub fn PdfFont::embedded_fontfile_number(self : PdfFont) -> Int? {
  match self {
    PdfFontSimple(
      { fontdescriptor: Some({ fontfile: Some(fontfile), .. }), .. }
    ) => Some(fontfile.object_number())
    PdfFontCIDKeyed(
      {
        composite: { cid_fontdescriptor: { fontfile: Some(fontfile), .. }, .. },
        ..,
      }
    ) => Some(fontfile.object_number())
    _ => None
  }
}

///|
fn PdfDocument::pdf_font_descriptor_file_number(
  self : PdfDocument,
  font : PdfObject,
) -> Int? {
  match self.lookup_direct(pdf_text_font_descriptor_key_name, font) {
    Some(descriptor) =>
      match pdf_text_fontfile_of_descriptor(descriptor) {
        Some(fontfile) => Some(fontfile.object_number())
        None => None
      }
    None => None
  }
}

///|
fn PdfDocument::pdf_font_embedded_file_number(
  self : PdfDocument,
  font : PdfObject,
) -> Int? {
  match self.pdf_font_descriptor_file_number(font) {
    Some(number) => Some(number)
    None =>
      match self.lookup_direct(pdf_text_descendant_fonts_key_name, font) {
        Some(PdfArray(descendants)) =>
          for descendant in descendants {
            match self.pdf_font_descriptor_file_number(descendant) {
              Some(number) => break Some(number)
              None => continue
            }
          } nobreak {
            None
          }
        _ => None
      }
  }
}

///|
/// Return decoded embedded font-file bytes for a named page font, if present.
///
/// This is the in-memory counterpart to cpdf's `extract_fontfile`, which writes
/// the decoded font program to a path. Missing names or fonts without embedded
/// font programs return `None`; malformed font dictionaries or font-file stream
/// objects raise through the normal PDF error path.
pub fn PdfDocument::extract_fontfile_bytes(
  self : PdfDocument,
  page_number : Int,
  font_name : String,
) -> PdfBytes? raise PdfError {
  let font = self.font_from_name(font_name, page_number)
  if font == PdfNull {
    None
  } else {
    match self.pdf_font_embedded_file_number(font) {
      Some(number) =>
        Some(self.pdf_decode_stream(PdfIndirect(number)).stream_bytes())
      None => None
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::extract_fontfile_bytes`.
pub fn pdf_extract_fontfile_bytes(
  document : PdfDocument,
  page_number : Int,
  font_name : String,
) -> PdfBytes? raise PdfError {
  document.extract_fontfile_bytes(page_number, font_name)
}

///|
fn PdfDocument::pdf_font_copy_referenced_objects_from(
  self : PdfDocument,
  source : PdfDocument,
  font : PdfObject,
) -> Unit {
  for number in source.referenced_object_numbers(font) {
    self.add_object_given_number(number, source.lookup_object_or_null(number))
  }
}

///|
fn PdfDocument::pdf_font_resource_dictionary_or_empty(
  self : PdfDocument,
  resources : PdfObject,
) -> PdfObject raise PdfError {
  match self.lookup_direct(pdf_page_font_resource_name, resources) {
    Some(PdfDictionary(_) as fonts) => fonts
    Some(_) => raise DictionaryExpected
    None => PdfDictionary([])
  }
}

///|
fn PdfDocument::pdf_font_add_to_page_resources(
  self : PdfDocument,
  page : PdfPage,
  resource_name : PdfName,
  font : PdfObject,
) -> PdfPage raise PdfError {
  let fonts = self.pdf_font_resource_dictionary_or_empty(page.resources)
  let updated_fonts = fonts.add_dict_entry(resource_name, font)
  {
    ..page,
    resources: page.resources.add_dict_entry(
      pdf_page_font_resource_name, updated_fonts,
    ),
  }
}

///|
/// Copy a named font from `source` onto selected pages of this document.
///
/// This ports cpdf's `copy_font`: both documents are first renumbered into one
/// non-overlapping object space, the direct source font dictionary is added to
/// selected target pages under its `/BaseFont` name, and all objects referenced
/// by the copied font dictionary are copied into the target document.
pub fn PdfDocument::copy_font_from(
  self : PdfDocument,
  source : PdfDocument,
  font_name : String,
  font_page : Int,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let renumbered = pdf_renumber_documents([source, self])
  let source_pdf = renumbered[0]
  let target_pdf = renumbered[1]
  let font = source_pdf.font_from_name(font_name, font_page)
  let resource_name = match
    source_pdf.lookup_direct(pdf_text_base_font_key_name, font) {
    Some(PdfNameObject(name)) => name
    _ => pdf_name_of_bytes(b"/CopyFontAddedNoName")
  }
  target_pdf.pdf_font_copy_referenced_objects_from(source_pdf, font)
  let pages = target_pdf.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "copy_font")
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index, page in pages {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      rewritten.push(
        target_pdf.pdf_font_add_to_page_resources(page, resource_name, font),
      )
    } else {
      rewritten.push(page)
    }
  }
  target_pdf.change_pages(rewritten)
}

///|
/// Compatibility wrapper for `PdfDocument::copy_font_from`.
pub fn pdf_copy_font(
  source : PdfDocument,
  font_name : String,
  font_page : Int,
  page_numbers : ArrayView[Int],
  target : PdfDocument,
) -> PdfDocument raise PdfError {
  target.copy_font_from(source, font_name, font_page, page_numbers)
}
