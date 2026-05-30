///|
fn PdfDocument::pdf_font_list_entry(
  self : PdfDocument,
  page : Int,
  name : String,
  font : @syntax.PdfObject,
) -> @font.PdfFontListEntry raise @core.PdfError {
  let direct_font = self.direct(font)
  {
    page,
    name,
    subtype: self.pdf_font_name_field(direct_font, pdf_text_subtype_key_name),
    basefont: self.pdf_font_name_field(direct_font, pdf_text_base_font_key_name),
    encoding: self.pdf_font_name_field(direct_font, pdf_text_encoding_key_name),
    font: direct_font,
  }
}

///|
fn PdfDocument::pdf_font_list_fonts_dictionary(
  self : PdfDocument,
  page : Int,
  prefix : String,
  fonts : ArrayView[(@core.PdfName, @syntax.PdfObject)],
) -> Array[@font.PdfFontListEntry] raise @core.PdfError {
  let output : Array[@font.PdfFontListEntry] = Array::new(
    capacity=fonts.length(),
  )
  for entry in fonts {
    output.push(
      self.pdf_font_list_entry(
        page,
        prefix + pdf_util_string_from_name(entry.0),
        entry.1,
      ),
    )
  }
  output
}

///|
fn PdfDocument::pdf_font_list_xobjects(
  self : PdfDocument,
  page : Int,
  prefix : String,
  xobjects : ArrayView[(@core.PdfName, @syntax.PdfObject)],
  seen : Array[Int],
) -> Array[@font.PdfFontListEntry] raise @core.PdfError {
  let output : Array[@font.PdfFontListEntry] = Array::new(
    capacity=xobjects.length(),
  )
  for entry in xobjects {
    match entry.1 {
      PdfIndirect(number) =>
        output.append(
          self.pdf_font_list_xobject(
            page,
            prefix + pdf_util_string_from_name(entry.0),
            number,
            seen,
          ),
        )
      _ => ()
    }
  }
  output
}

///|
fn PdfDocument::pdf_font_list_resources(
  self : PdfDocument,
  page : Int,
  prefix : String,
  resources : @syntax.PdfObject,
  seen : Array[Int],
) -> Array[@font.PdfFontListEntry] raise @core.PdfError {
  let output : Array[@font.PdfFontListEntry] = []
  match self.lookup_direct(pdf_page_font_resource_name, resources) {
    Some(PdfDictionary(fonts)) =>
      output.append(self.pdf_font_list_fonts_dictionary(page, prefix, fonts))
    _ => ()
  }
  match self.lookup_direct(pdf_page_xobject_key(), resources) {
    Some(PdfDictionary(xobjects)) =>
      output.append(self.pdf_font_list_xobjects(page, prefix, xobjects, seen))
    _ => ()
  }
  output
}

///|
fn PdfDocument::pdf_font_list_xobject(
  self : PdfDocument,
  page : Int,
  prefix : String,
  xobject_number : Int,
  seen : Array[Int],
) -> Array[@font.PdfFontListEntry] raise @core.PdfError {
  if seen.contains(xobject_number) {
    []
  } else {
    seen.push(xobject_number)
    let xobject = self.lookup_object_or_null(xobject_number)
    match self.lookup_direct(pdf_page_resources_key(), xobject) {
      Some(resources) =>
        self.pdf_font_list_resources(page, prefix, resources, seen)
      _ => []
    }
  }
}

///|
/// Return cpdf's font resource listing for selected pages.
///
/// The listing walks page `/Resources` dictionaries and nested Form XObject
/// resources. Duplicate indirect XObjects are processed once per call, matching
/// cpdf's intended "do not process an xobject twice" behavior.
pub fn PdfDocument::list_fonts(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Array[@font.PdfFontListEntry] raise @core.PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "list_fonts")
  let selected_pages = @core.pdf_number_set(page_numbers)
  let output : Array[@font.PdfFontListEntry] = Array::new(
    capacity=page_numbers.length(),
  )
  let seen_xobjects : Array[Int] = Array::new(capacity=page_numbers.length())
  for index, page in pages {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      output.append(
        self.pdf_font_list_resources(
          page_number,
          "",
          page.resources,
          seen_xobjects,
        ),
      )
    }
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::list_fonts`.
pub fn pdf_list_fonts(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Array[@font.PdfFontListEntry] raise @core.PdfError {
  document.list_fonts(page_numbers)
}

///|
fn pdf_font_write_listing_line(
  output : Array[Byte],
  position : Int,
  entry : @font.PdfFontListEntry,
) -> Int {
  let mut current = pdf_font_write_utf8(
    output,
    position,
    entry.page.to_string(),
  )
  output[current] = 32
  current += 1
  current = pdf_font_write_utf8(output, current, entry.name)
  output[current] = 32
  current += 1
  current = pdf_font_write_utf8(output, current, entry.subtype)
  output[current] = 32
  current += 1
  current = pdf_font_write_utf8(output, current, entry.basefont)
  output[current] = 32
  current += 1
  current = pdf_font_write_utf8(output, current, entry.encoding)
  output[current] = 10
  current + 1
}

///|
fn pdf_font_listing_line_length(entry : @font.PdfFontListEntry) -> Int {
  pdf_font_utf8_length(entry.page.to_string()) +
  pdf_font_utf8_length(entry.name) +
  pdf_font_utf8_length(entry.subtype) +
  pdf_font_utf8_length(entry.basefont) +
  pdf_font_utf8_length(entry.encoding) +
  5
}

///|
fn pdf_font_listing_text_length(
  entries : ArrayView[@font.PdfFontListEntry],
) -> Int {
  let mut length = 0
  for entry in entries {
    length += pdf_font_listing_line_length(entry)
  }
  length
}

///|
/// Render cpdf's plain-text font listing for selected pages.
pub fn PdfDocument::list_fonts_text(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> @core.PdfBytes raise @core.PdfError {
  let entries = self.list_fonts(page_numbers)
  let output = Array::make(pdf_font_listing_text_length(entries), b'\x00')
  let mut position = 0
  for entry in entries {
    position = pdf_font_write_listing_line(output, position, entry)
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::list_fonts_text`.
pub fn pdf_list_fonts_text(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> @core.PdfBytes raise @core.PdfError {
  document.list_fonts_text(page_numbers)
}

///|
/// Return the bytes cpdf's `print_fonts` would print.
pub fn PdfDocument::print_fonts(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  json? : Bool = false,
) -> @core.PdfBytes raise @core.PdfError {
  if json {
    self.fonts_json_blob(page_numbers)
  } else {
    self.list_fonts_text(page_numbers)
  }
}

///|
/// Compatibility wrapper matching cpdffont's `print_fonts`.
pub fn pdf_print_fonts(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  json? : Bool = false,
) -> @core.PdfBytes raise @core.PdfError {
  document.print_fonts(page_numbers, json~)
}

///|
fn pdf_font_json_nullable_name(value : String) -> Json {
  if value == "" {
    Json::null()
  } else {
    Json::string(value)
  }
}

///|
fn pdf_font_entry_json(entry : @font.PdfFontListEntry) -> Json {
  Json::object(
    Map([
      ("page", pdf_util_json_number(entry.page)),
      ("name", Json::string(entry.name)),
      ("subtype", pdf_font_json_nullable_name(entry.subtype)),
      ("basefont", pdf_font_json_nullable_name(entry.basefont)),
      ("encoding", pdf_font_json_nullable_name(entry.encoding)),
    ]),
  )
}

///|
/// Return cpdf's JSON font listing for selected pages.
pub fn PdfDocument::fonts_json(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Json raise @core.PdfError {
  Json::array(
    [
      for entry in self.list_fonts(page_numbers) => pdf_font_entry_json(entry)
    ],
  )
}

///|
/// Compatibility wrapper for `PdfDocument::fonts_json`.
pub fn pdf_fonts_json(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Json raise @core.PdfError {
  document.fonts_json(page_numbers)
}

///|
/// Compatibility wrapper matching cpdffont's `json_fonts`.
pub fn pdf_json_fonts(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Json raise @core.PdfError {
  document.fonts_json(page_numbers)
}

///|
/// Return cpdf's JSON font listing as UTF-8 JSON bytes.
pub fn PdfDocument::fonts_json_blob(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> @core.PdfBytes raise @core.PdfError {
  @utf8.encode(self.fonts_json(page_numbers).stringify())
}

///|
/// Compatibility wrapper for `PdfDocument::fonts_json_blob`.
pub fn pdf_fonts_json_blob(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> @core.PdfBytes raise @core.PdfError {
  document.fonts_json_blob(page_numbers)
}
