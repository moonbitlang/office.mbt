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
/// One cpdf-style missing-font report entry.
///
/// `encoding == "Built-in"` records cpdf's fallback when a missing font does
/// not have a named `/Encoding`.
pub(all) struct PdfMissingFontEntry {
  page : Int
  name : String
  subtype : String
  basefont : String
  encoding : String
} derive(Debug, Eq, ToJson)

///|
/// One row from cpdf's font encoding table.
///
/// `unicode_name` is empty when this port has no Unicode character-name table
/// entry for the codepoint. `utf8` is `<nonprintable>` for C0/C1 controls.
pub(all) struct PdfFontTableEntry {
  code : Int
  unicode : String
  utf8 : String
  unicode_name : String
  glyphnames : String
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
/// Return the bytes cpdf's `print_fonts` would print.
pub fn PdfDocument::print_fonts(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  json? : Bool = false,
) -> PdfBytes raise PdfError {
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
) -> PdfBytes raise PdfError {
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
fn pdf_font_entry_json(entry : PdfFontListEntry) -> Json {
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
/// Compatibility wrapper matching cpdffont's `json_fonts`.
pub fn pdf_json_fonts(
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
fn pdf_font_name_segments(font_name : String) -> Array[String] {
  let segments : Array[String] = []
  let mut start = 0
  for index in 0..<font_name.length() {
    if font_name.at(index).to_int() == 47 {
      if index > start {
        segments.push(font_name[start:index].to_owned())
      }
      start = index + 1
    }
  }
  if start < font_name.length() {
    segments.push(font_name[start:].to_owned())
  }
  segments
}

///|
fn pdf_font_segment_name(segment : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode("/" + segment))
}

///|
/// Resolve a cpdf font name path on a page.
///
/// `font_name` is the name shown by `list_fonts`, such as `/F1` for a page font
/// or `/Fm/FX` for a font inside a Form XObject. Valid pages whose path is not
/// found return `PdfNull`.
pub fn PdfDocument::font_from_name(
  self : PdfDocument,
  font_name : String,
  page_number : Int,
) -> PdfObject raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    [page_number],
    pages.length(),
    "font_from_name",
  )
  let segments = pdf_font_name_segments(font_name)
  if segments.length() == 0 {
    PdfNull
  } else {
    let mut resources = pages[page_number - 1].resources
    let mut found = PdfNull
    let mut failed = false
    for index, segment in segments {
      if !failed {
        let key = pdf_font_segment_name(segment)
        if index == segments.length() - 1 {
          match self.lookup_direct(pdf_page_font_resource_name, resources) {
            Some(fonts) =>
              match self.lookup_direct(key, fonts) {
                Some(font) => found = font
                None => failed = true
              }
            None => failed = true
          }
        } else {
          match self.lookup_direct(pdf_page_xobject_key(), resources) {
            Some(xobjects) =>
              match self.lookup_direct(key, xobjects) {
                Some(xobject) =>
                  match self.lookup_direct(pdf_page_resources_key(), xobject) {
                    Some(next_resources) => resources = next_resources
                    None => failed = true
                  }
                None => failed = true
              }
            None => failed = true
          }
        }
      }
    }
    if failed {
      PdfNull
    } else {
      found
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::font_from_name`.
pub fn pdf_font_from_name(
  document : PdfDocument,
  font_name : String,
  page_number : Int,
) -> PdfObject raise PdfError {
  document.font_from_name(font_name, page_number)
}

///|
fn PdfDocument::pdf_font_table_target_font(
  self : PdfDocument,
  font_name : String,
  page_number : Int,
) -> PdfObject raise PdfError {
  let font = self.font_from_name(font_name, page_number)
  let mut selected = font
  match font {
    PdfDictionary(entries) =>
      for entry in entries {
        match self.lookup_direct(pdf_text_base_font_key_name, entry.1) {
          Some(PdfNameObject(name)) if pdf_util_string_from_name(name) ==
            font_name => selected = entry.1
          _ => ()
        }
      }
    _ => ()
  }
  selected
}

///|
fn pdf_font_table_charset(font : PdfFont) -> Array[PdfName]? {
  match font {
    PdfFontSimple({ fontdescriptor: Some({ charset: Some(charset), .. }), .. }) =>
      Some(charset)
    _ => None
  }
}

///|
fn pdf_font_table_text_bytes(
  font : PdfFont,
  code : Int,
) -> PdfBytes raise PdfError {
  let bytes : Array[Byte] = []
  if font.uses_two_byte_codes() {
    bytes.push(pdf_byte_of_int(0))
  }
  bytes.push(pdf_byte_of_int(code))
  Bytes::from_array(bytes)
}

///|
fn pdf_font_table_strip_name_slash(name : PdfName) -> String {
  let text = pdf_util_string_from_name(name) catch {
    _ => @ascii.decode_lossy(name.bytes())
  }
  if text.has_prefix("/") {
    text[1:].to_owned()
  } else {
    text
  }
}

///|
fn pdf_font_table_glyphnames_text(glyphnames : ArrayView[PdfName]) -> String {
  let mut text = ""
  for glyphname in glyphnames {
    text = text + pdf_font_table_strip_name_slash(glyphname)
  }
  text
}

///|
fn pdf_font_table_in_charset(
  glyphnames : String,
  charset : ArrayView[PdfName],
) -> Bool {
  for name in charset {
    if pdf_font_table_strip_name_slash(name) == glyphnames {
      return true
    }
  }
  false
}

///|
fn pdf_font_table_utf8_text(
  codepoints : ArrayView[Int],
) -> String raise PdfError {
  let bytes = pdf_utf8_of_codepoints(codepoints)
  @utf8.decode(bytes) catch {
    _ => ""
  }
}

///|
fn pdf_font_table_unicode_fields(
  codepoints : ArrayView[Int],
) -> (String, String, String) raise PdfError {
  match codepoints {
    [codepoint] => {
      let data = pdf_unicode_data_lookup(codepoint)
      let unicode = match data {
        Some(data) => data.code_value
        None => ""
      }
      let unicode_name = match data {
        Some(data) => data.character_name
        None => ""
      }
      let is_control = match data {
        Some(data) => data.general_category == "Cc"
        None => false
      }
      let utf8 = if is_control {
        "<nonprintable>"
      } else {
        pdf_font_table_utf8_text(codepoints)
      }
      (unicode, utf8, unicode_name)
    }
    _ => ("***multiple", pdf_font_table_utf8_text(codepoints), "***multiple")
  }
}

///|
fn pdf_font_table_entry(
  font : PdfFont,
  extractor : PdfTextExtractor,
  code : Int,
) -> PdfFontTableEntry? raise PdfError {
  let text = pdf_font_table_text_bytes(font, code)
  let glyphnames = extractor.glyphnames_of_text(text)
  let glyphnames_text = pdf_font_table_glyphnames_text(glyphnames)
  if glyphnames_text == ".notdef" {
    None
  } else {
    match pdf_font_table_charset(font) {
      Some(charset) if !pdf_font_table_in_charset(glyphnames_text, charset) =>
        None
      _ => {
        let codepoints = extractor.codepoints_of_text(text)
        let (unicode, utf8, unicode_name) = pdf_font_table_unicode_fields(
          codepoints,
        )
        Some({ code, unicode, utf8, unicode_name, glyphnames: glyphnames_text })
      }
    }
  }
}

///|
/// Return cpdf's font encoding table rows for one named page font.
///
/// This is the in-memory counterpart to cpdf's `print_font_table`. Font names
/// use the same page resource path syntax as `font_from_name`, such as `/F1`.
pub fn PdfDocument::font_table(
  self : PdfDocument,
  font_name : String,
  page_number : Int,
) -> Array[PdfFontTableEntry] raise PdfError {
  let font_object = self.pdf_font_table_target_font(font_name, page_number)
  let font = self.read_font(font_object)
  let extractor = font.text_extractor()
  let output : Array[PdfFontTableEntry] = []
  for code in 0..<256 {
    match pdf_font_table_entry(font, extractor, code) {
      Some(entry) => output.push(entry)
      None => ()
    }
  }
  output
}

///|
/// Compatibility wrapper for `PdfDocument::font_table`.
pub fn pdf_font_table(
  document : PdfDocument,
  font_name : String,
  page_number : Int,
) -> Array[PdfFontTableEntry] raise PdfError {
  document.font_table(font_name, page_number)
}

///|
fn pdf_font_push_table_line(
  output : Array[Byte],
  entry : PdfFontTableEntry,
) -> Unit {
  pdf_font_push_utf8(output, entry.code.to_string())
  pdf_font_push_utf8(output, " = U+")
  pdf_font_push_utf8(output, entry.unicode)
  pdf_font_push_utf8(output, " (")
  pdf_font_push_utf8(output, entry.utf8)
  pdf_font_push_utf8(output, " - ")
  pdf_font_push_utf8(output, entry.unicode_name)
  pdf_font_push_utf8(output, ") = ")
  pdf_font_push_utf8(output, entry.glyphnames)
  output.push(10)
}

///|
/// Render cpdf's plain-text font encoding table for one named page font.
pub fn PdfDocument::font_table_text(
  self : PdfDocument,
  font_name : String,
  page_number : Int,
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  for entry in self.font_table(font_name, page_number) {
    pdf_font_push_table_line(output, entry)
  }
  Bytes::from_array(output)
}

///|
/// Compatibility wrapper for `PdfDocument::font_table_text`.
pub fn pdf_font_table_text(
  document : PdfDocument,
  font_name : String,
  page_number : Int,
) -> PdfBytes raise PdfError {
  document.font_table_text(font_name, page_number)
}

///|
/// Return the bytes cpdf's `print_font_table` would print.
pub fn PdfDocument::print_font_table(
  self : PdfDocument,
  font_name : String,
  page_number : Int,
) -> PdfBytes raise PdfError {
  self.font_table_text(font_name, page_number)
}

///|
/// Compatibility wrapper matching cpdffont's `print_font_table`.
pub fn pdf_print_font_table(
  document : PdfDocument,
  font_name : String,
  page_number : Int,
) -> PdfBytes raise PdfError {
  document.print_font_table(font_name, page_number)
}

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
  let rewritten : Array[PdfPage] = []
  for index, page in pages {
    let page_number = index + 1
    if pdf_page_box_contains_page(page_numbers, page_number) {
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
) -> PdfMissingFontEntry raise PdfError {
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
) -> Array[PdfMissingFontEntry] raise PdfError {
  let output : Array[PdfMissingFontEntry] = []
  match self.lookup_direct(pdf_page_font_resource_name, resources) {
    Some(PdfDictionary(fonts)) =>
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
    _ => ()
  }
  output
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
) -> Array[PdfMissingFontEntry] raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "missing_fonts",
  )
  let output : Array[PdfMissingFontEntry] = []
  for index, page in pages {
    let page_number = index + 1
    if pdf_page_box_contains_page(page_numbers, page_number) {
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
) -> Array[PdfMissingFontEntry] raise PdfError {
  document.missing_fonts(page_numbers)
}

///|
fn pdf_missing_font_entry_tuple(
  entry : PdfMissingFontEntry,
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
fn pdf_missing_font_push_text(
  output : Array[Byte],
  entry : PdfMissingFontEntry,
) -> Unit {
  pdf_font_push_utf8(output, entry.page.to_string())
  pdf_font_push_utf8(output, ", ")
  pdf_font_push_utf8(output, entry.name)
  pdf_font_push_utf8(output, ", ")
  pdf_font_push_utf8(output, entry.subtype)
  pdf_font_push_utf8(output, ", ")
  pdf_font_push_utf8(output, entry.basefont)
  pdf_font_push_utf8(output, ", ")
  pdf_font_push_utf8(output, entry.encoding)
  output.push(10)
}

///|
/// Render cpdf's plain-text missing-font report for selected pages.
pub fn PdfDocument::missing_fonts_text(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfBytes raise PdfError {
  let output : Array[Byte] = []
  for entry in self.missing_fonts(page_numbers) {
    pdf_missing_font_push_text(output, entry)
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
