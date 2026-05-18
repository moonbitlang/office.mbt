///|
/// One font resource entry reported by cpdf-style font listing.
///
/// `page` is one-based. `name`, `subtype`, `basefont`, and `encoding` are PDF
/// names rendered with their leading slash; missing non-name fields are empty
/// strings to match cpdf's text listing and JSON-null conversion.
pub(all) struct PdfFontListEntry {
  page : Int
  name : String
  subtype : String
  basefont : String
  encoding : String
  font : PdfObject
} derive(Debug, Eq, ToJson)

///|
fn PdfDocument::pdf_font_name_field(
  self : PdfDocument,
  font : PdfObject,
  key : PdfName,
) -> String raise PdfError {
  match self.lookup_direct(key, font) {
    Some(PdfNameObject(name)) => pdf_util_string_from_name(name)
    _ => ""
  }
}

///|
fn PdfDocument::pdf_font_list_entry(
  self : PdfDocument,
  page : Int,
  name : String,
  font : PdfObject,
) -> PdfFontListEntry raise PdfError {
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
  fonts : ArrayView[(PdfName, PdfObject)],
) -> Array[PdfFontListEntry] raise PdfError {
  let output : Array[PdfFontListEntry] = []
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
  xobjects : ArrayView[(PdfName, PdfObject)],
  seen : Array[Int],
) -> Array[PdfFontListEntry] raise PdfError {
  let output : Array[PdfFontListEntry] = []
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
  resources : PdfObject,
  seen : Array[Int],
) -> Array[PdfFontListEntry] raise PdfError {
  let output : Array[PdfFontListEntry] = []
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
) -> Array[PdfFontListEntry] raise PdfError {
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
) -> Array[PdfFontListEntry] raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "list_fonts")
  let output : Array[PdfFontListEntry] = []
  let seen_xobjects : Array[Int] = []
  for index, page in pages {
    let page_number = index + 1
    if pdf_page_box_contains_page(page_numbers, page_number) {
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
) -> Array[PdfFontListEntry] raise PdfError {
  document.list_fonts(page_numbers)
}

///|
fn pdf_font_push_utf8(output : Array[Byte], text : String) -> Unit {
  for byte in @utf8.encode(text) {
    output.push(byte)
  }
}

///|
fn pdf_font_push_listing_line(
  output : Array[Byte],
  entry : PdfFontListEntry,
) -> Unit {
  pdf_font_push_utf8(output, entry.page.to_string())
  output.push(32)
  pdf_font_push_utf8(output, entry.name)
  output.push(32)
  pdf_font_push_utf8(output, entry.subtype)
  output.push(32)
  pdf_font_push_utf8(output, entry.basefont)
  output.push(32)
  pdf_font_push_utf8(output, entry.encoding)
  output.push(10)
}

///|
/// Render cpdf's plain-text font listing for selected pages.
pub fn PdfDocument::list_fonts_text(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  for entry in self.list_fonts(page_numbers) {
    pdf_font_push_listing_line(output, entry)
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::list_fonts_text`.
pub fn pdf_list_fonts_text(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfBytes raise PdfError {
  document.list_fonts_text(page_numbers)
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
fn pdf_font_entry_json(entry : PdfFontListEntry) -> Json {
  Json::object(
    Map::of([
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
) -> Json raise PdfError {
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
) -> Json raise PdfError {
  document.fonts_json(page_numbers)
}

///|
/// Return cpdf's JSON font listing as UTF-8 JSON bytes.
pub fn PdfDocument::fonts_json_blob(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfBytes raise PdfError {
  @utf8.encode(self.fonts_json(page_numbers).stringify())
}

///|
/// Compatibility wrapper for `PdfDocument::fonts_json_blob`.
pub fn pdf_fonts_json_blob(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfBytes raise PdfError {
  document.fonts_json_blob(page_numbers)
}

///|
fn PdfDocument::pdf_font_remove_descriptor_files(
  self : PdfDocument,
  object : PdfObject,
) -> PdfObject raise PdfError {
  match object {
    PdfDictionary(_) =>
      match self.lookup_direct(pdf_text_type_key_name, object) {
        Some(PdfNameObject(kind)) if kind == pdf_text_font_name =>
          match self.lookup_direct(pdf_text_font_descriptor_key_name, object) {
            Some(PdfDictionary(_) | PdfStreamObject(_) as descriptor) => {
              let stripped = descriptor
                .remove_dict_entry(pdf_text_font_file_key_name)
                .remove_dict_entry(pdf_text_font_file2_key_name)
                .remove_dict_entry(pdf_text_font_file3_key_name)
              object.add_dict_entry(
                pdf_text_font_descriptor_key_name,
                PdfIndirect(self.add_object(stripped)),
              )
            }
            _ => object
          }
        _ => object
      }
    _ => object
  }
}

///|
/// Return a copy of the document with embedded font-file references removed.
///
/// This ports cpdf's `remove_fonts`: every parsed `/Type /Font` dictionary with
/// a `/FontDescriptor` receives a new descriptor object with `/FontFile`,
/// `/FontFile2`, and `/FontFile3` removed. The original document and original
/// descriptor objects are left untouched.
pub fn PdfDocument::remove_embedded_fonts(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let pdf = self.copy()
  let entries = pdf.parsed_object_entries()
  for entry in entries {
    pdf.add_object_given_number(
      entry.0,
      pdf.pdf_font_remove_descriptor_files(entry.2),
      generation=entry.1,
    )
  }
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::remove_embedded_fonts`.
pub fn pdf_remove_fonts(document : PdfDocument) -> PdfDocument raise PdfError {
  document.remove_embedded_fonts()
}
