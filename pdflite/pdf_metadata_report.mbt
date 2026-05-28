///|
fn pdf_metadata_json_string_array(values : ArrayView[String]) -> Json {
  let items : Array[Json] = []
  for value in values {
    items.push(Json::string(value))
  }
  Json::array(items)
}

///|
fn pdf_metadata_combine_with_commas(values : ArrayView[String]) -> String {
  let mut output = ""
  for value in values {
    if output == "" {
      output = value
    } else {
      output = output + ", " + value
    }
  }
  output.trim().to_owned()
}

///|
fn pdf_metadata_unit_number(value : Double, unit : PdfUnit) -> Double {
  match unit {
    PdfPoint => value
    Inch => unit_inches(value, PdfPoint)
    Centimetre => unit_centimetres(value, PdfPoint)
    Millimetre => unit_millimetres(value, PdfPoint)
  }
}

///|
fn pdf_metadata_string_json(value : String) -> Json {
  if value == "" {
    Json::null()
  } else {
    Json::string(value)
  }
}

///|
fn pdf_metadata_bool_json(value : String) -> Json {
  if value == "" {
    Json::null()
  } else {
    Json::boolean(value.to_lower() == "true")
  }
}

///|
fn PdfDocument::pdf_metadata_info_encoded(
  self : PdfDocument,
  key : PdfName,
  encoding : PdfMetadataEncoding,
) -> String {
  let info = match
    self.lookup_direct(pdf_metadata_info(), self.trailer_dict()) {
    Some(dictionary) => dictionary
    None => PdfDictionary([])
  }
  match self.lookup_direct(key, info) {
    Some(PdfString(bytes)) =>
      @utf8.decode_lossy(
        pdf_metadata_encode_output(encoding, bytes) catch {
          _ => return ""
        },
      )
    Some(PdfBoolean(value)) => pdf_metadata_bool_string(value)
    _ => if key == pdf_metadata_trapped() { "False" } else { "" }
  }
}

///|
fn PdfDocument::pdf_metadata_box_array_json(
  self : PdfDocument,
  box : PdfObject,
  unit : PdfUnit,
) -> Json? {
  match self.direct(box) {
    PdfArray(values) if values.length() == 4 => {
      let output : Array[Json] = []
      for value in values {
        let number = self.get_number(value) catch { _ => return None }
        output.push(Json::number(pdf_metadata_unit_number(number, unit)))
      }
      Some(Json::array(output))
    }
    _ => None
  }
}

///|
fn PdfDocument::pdf_metadata_page_box_json(
  self : PdfDocument,
  boxes : ArrayView[PdfObject?],
  unit : PdfUnit,
) -> Json {
  if boxes.length() == 0 {
    return Json::null()
  }
  let first = boxes[0]
  for index in 1..<boxes.length() {
    if boxes[index] != first {
      return Json::string("various")
    }
  }
  match first {
    Some(box) =>
      match self.pdf_metadata_box_array_json(box, unit) {
        Some(json) => json
        None => Json::null()
      }
    None => Json::null()
  }
}

///|
fn pdf_metadata_set_json_string(
  output : Map[String, Json],
  key : String,
  value : String,
) -> Unit {
  output.set(key, pdf_metadata_string_json(value))
}

///|
fn pdf_metadata_push_text_line(
  output : Array[String],
  key : String,
  value : String,
) -> Unit {
  output.push(key)
  output.push(": ")
  output.push(value)
  output.push("\n")
}

///|
fn PdfDocument::pdf_metadata_box_text(
  self : PdfDocument,
  box : PdfObject,
  unit : PdfUnit,
) -> String {
  match self.direct(box) {
    PdfArray(values) if values.length() == 4 => {
      let a = self.get_number(values[0]) catch { _ => return "" }
      let b = self.get_number(values[1]) catch { _ => return "" }
      let c = self.get_number(values[2]) catch { _ => return "" }
      let d = self.get_number(values[3]) catch { _ => return "" }
      pdf_position_fixed_six(pdf_metadata_unit_number(a, unit)) +
      " " +
      pdf_position_fixed_six(pdf_metadata_unit_number(b, unit)) +
      " " +
      pdf_position_fixed_six(pdf_metadata_unit_number(c, unit)) +
      " " +
      pdf_position_fixed_six(pdf_metadata_unit_number(d, unit))
    }
    _ => ""
  }
}

///|
fn PdfDocument::pdf_metadata_info_box_text(
  self : PdfDocument,
  boxes : ArrayView[PdfObject?],
  unit : PdfUnit,
) -> String {
  if boxes.length() == 0 {
    return ""
  }
  let first = boxes[0]
  for index in 1..<boxes.length() {
    if boxes[index] != first {
      return "various"
    }
  }
  match first {
    Some(box) => self.pdf_metadata_box_text(box, unit)
    None => ""
  }
}

///|
fn PdfDocument::pdf_metadata_info_json_boxes(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
  unit : PdfUnit,
  output : Map[String, Json],
) -> Unit {
  let mediaboxes : Array[PdfObject?] = []
  let cropboxes : Array[PdfObject?] = []
  let bleedboxes : Array[PdfObject?] = []
  let trimboxes : Array[PdfObject?] = []
  let artboxes : Array[PdfObject?] = []
  for page in pages {
    mediaboxes.push(Some(page.mediabox))
    cropboxes.push(self.lookup_direct(pdf_metadata_cropbox(), page.rest))
    bleedboxes.push(self.lookup_direct(pdf_metadata_bleedbox(), page.rest))
    trimboxes.push(self.lookup_direct(pdf_metadata_trimbox(), page.rest))
    artboxes.push(self.lookup_direct(pdf_metadata_artbox(), page.rest))
  }
  output.set("MediaBox", self.pdf_metadata_page_box_json(mediaboxes, unit))
  output.set("CropBox", self.pdf_metadata_page_box_json(cropboxes, unit))
  output.set("BleedBox", self.pdf_metadata_page_box_json(bleedboxes, unit))
  output.set("TrimBox", self.pdf_metadata_page_box_json(trimboxes, unit))
  output.set("ArtBox", self.pdf_metadata_page_box_json(artboxes, unit))
}

///|
let pdf_metadata_xmp_report_fields : Array[(String, String, String)] = [
  ("XMP pdf:Keywords", pdf_metadata_adobe_namespace, "Keywords"),
  ("XMP pdf:Producer", pdf_metadata_adobe_namespace, "Producer"),
  ("XMP pdf:Trapped", pdf_metadata_adobe_namespace, "Trapped"),
  ("XMP pdf:Title", pdf_metadata_adobe_namespace, "Title"),
  ("XMP pdf:Creator", pdf_metadata_adobe_namespace, "Creator"),
  ("XMP pdf:Subject", pdf_metadata_adobe_namespace, "Subject"),
  ("XMP pdf:Author", pdf_metadata_adobe_namespace, "Author"),
  ("XMP pdf:CreationDate", pdf_metadata_adobe_namespace, "CreationDate"),
  ("XMP pdf:ModDate", pdf_metadata_adobe_namespace, "ModDate"),
  ("XMP xmp:CreateDate", pdf_metadata_xmp_namespace, "CreateDate"),
  ("XMP xmp:CreatorTool", pdf_metadata_xmp_namespace, "CreatorTool"),
  ("XMP xmp:MetadataDate", pdf_metadata_xmp_namespace, "MetadataDate"),
  ("XMP xmp:ModifyDate", pdf_metadata_xmp_namespace, "ModifyDate"),
  ("XMP dc:title", pdf_metadata_dc_namespace, "title"),
  ("XMP dc:creator", pdf_metadata_dc_namespace, "creator"),
  ("XMP dc:subject", pdf_metadata_dc_namespace, "subject"),
  ("XMP dc:description", pdf_metadata_dc_namespace, "description"),
  ("PDF/UA pdfuaid:amd", pdf_metadata_pdfuaid_namespace, "amd"),
  ("PDF/UA pdfuaid:corr", pdf_metadata_pdfuaid_namespace, "corr"),
]

///|
fn pdf_metadata_add_xmp_report_field(
  output : Map[String, Json],
  metadata : BytesView,
  field : (String, String, String),
) -> Unit {
  match
    pdf_metadata_get_xmp_data(
      metadata,
      field.1,
      pdf_metadata_namespace_fallback_prefix(field.1),
      field.2,
    ) {
    Some(value) => output.set(field.0, Json::string(value))
    None => ()
  }
}

///|
fn pdf_metadata_add_xmp_report_line(
  output : Array[String],
  tree : PdfMetadataXmlTree,
  field : (String, String, String),
) -> Unit {
  match pdf_metadata_xmltree_get_data_for(field.1, field.2, tree) {
    Some(value) => {
      output.push(field.0)
      output.push(": ")
      output.push(value)
      output.push("\n")
    }
    None => ()
  }
}

///|
/// Return cpdf-style document information report fields as JSON.
pub fn PdfDocument::info_json(
  self : PdfDocument,
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
  unit? : PdfUnit = PdfPoint,
) -> Json raise PdfError {
  let output : Map[String, Json] = Map([])
  let (major, minor) = self.version()
  let pages = self.pages_of_pagetree()
  output.set(
    "Version",
    Json::array([pdf_util_json_number(major), pdf_util_json_number(minor)]),
  )
  output.set("Pages", pdf_util_json_number(pages.length()))
  let info_fields : Array[(String, PdfName)] = [
    ("Title", pdf_metadata_name("/Title")),
    ("Author", pdf_metadata_name("/Author")),
    ("Subject", pdf_metadata_name("/Subject")),
    ("Keywords", pdf_metadata_name("/Keywords")),
    ("Creator", pdf_metadata_name("/Creator")),
    ("Producer", pdf_metadata_name("/Producer")),
    ("Created", pdf_metadata_name("/CreationDate")),
    ("Modified", pdf_metadata_name("/ModDate")),
  ]
  for field in info_fields {
    pdf_metadata_set_json_string(
      output,
      field.0,
      self.pdf_metadata_info_encoded(field.1, encoding),
    )
  }
  output.set(
    "Trapped",
    pdf_metadata_bool_json(
      self.pdf_metadata_info_encoded(pdf_metadata_trapped(), encoding),
    ),
  )
  pdf_metadata_set_json_string(
    output,
    "PageMode",
    self.catalog_item(pdf_metadata_page_mode()),
  )
  pdf_metadata_set_json_string(
    output,
    "PageLayout",
    self.catalog_item(pdf_metadata_page_layout()),
  )
  output.set(
    "OpenAction",
    self.pdf_util_json_of_object(
      self.open_action(),
      true,
      false,
      false,
      false,
      false,
    ),
  )
  let viewer_bool_fields : Array[(String, PdfName)] = [
    ("HideToolbar", pdf_metadata_name("/HideToolbar")),
    ("HideMenubar", pdf_metadata_name("/HideMenubar")),
    ("HideWindowUI", pdf_metadata_name("/HideWindowUI")),
    ("FitWindow", pdf_metadata_name("/FitWindow")),
    ("CenterWindow", pdf_metadata_name("/CenterWindow")),
    ("DisplayDocTitle", pdf_metadata_name("/DisplayDocTitle")),
  ]
  for field in viewer_bool_fields {
    output.set(
      field.0,
      pdf_metadata_bool_json(self.viewer_preference_item(field.1)),
    )
  }
  pdf_metadata_set_json_string(
    output,
    "NonFullPageScreenMode",
    self.viewer_preference_item(pdf_metadata_non_full_screen_page_mode()),
  )
  output.set(
    "AcroForm",
    Json::boolean(self.catalog_item(pdf_metadata_acroform()) != ""),
  )
  output.set("XFA", Json::boolean(self.is_xfa()))
  output.set(
    "Marked",
    Json::boolean(self.mark_info_item(pdf_metadata_name("/Marked"))),
  )
  output.set(
    "UserProperties",
    Json::boolean(self.mark_info_item(pdf_metadata_name("/UserProperties"))),
  )
  output.set(
    "Suspects",
    Json::boolean(self.mark_info_item(pdf_metadata_name("/Suspects"))),
  )
  self.pdf_metadata_info_json_boxes(pages, unit, output)
  Json::object(output)
}

///|
/// Return cpdf-style document information report fields as UTF-8 JSON bytes.
pub fn PdfDocument::info_json_blob(
  self : PdfDocument,
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
  unit? : PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  @utf8.encode(self.info_json(encoding~, unit~).stringify())
}

///|
/// Return cpdf-style document information report fields as stdout-style UTF-8 bytes.
pub fn PdfDocument::info_blob(
  self : PdfDocument,
  encoding? : PdfMetadataEncoding = PdfMetadataUTF8,
  unit? : PdfUnit = PdfPoint,
) -> PdfBytes raise PdfError {
  let output : Array[String] = []
  let (major, minor) = self.version()
  let pages = self.pages_of_pagetree()
  pdf_metadata_push_text_line(
    output,
    "Version",
    major.to_string() + "." + minor.to_string(),
  )
  pdf_metadata_push_text_line(output, "Pages", pages.length().to_string())
  let info_fields : Array[(String, PdfName)] = [
    ("Title", pdf_metadata_name("/Title")),
    ("Author", pdf_metadata_name("/Author")),
    ("Subject", pdf_metadata_name("/Subject")),
    ("Keywords", pdf_metadata_name("/Keywords")),
    ("Creator", pdf_metadata_name("/Creator")),
    ("Producer", pdf_metadata_name("/Producer")),
    ("Created", pdf_metadata_name("/CreationDate")),
    ("Modified", pdf_metadata_name("/ModDate")),
    ("Trapped", pdf_metadata_trapped()),
  ]
  for field in info_fields {
    pdf_metadata_push_text_line(
      output,
      field.0,
      self.pdf_metadata_info_encoded(field.1, encoding),
    )
  }
  pdf_metadata_push_text_line(
    output,
    "PageMode",
    self.catalog_item(pdf_metadata_page_mode()),
  )
  pdf_metadata_push_text_line(
    output,
    "PageLayout",
    self.catalog_item(pdf_metadata_page_layout()),
  )
  pdf_metadata_push_text_line(output, "OpenAction", self.open_action_string())
  let viewer_fields : Array[(String, PdfName)] = [
    ("HideToolbar", pdf_metadata_name("/HideToolbar")),
    ("HideMenubar", pdf_metadata_name("/HideMenubar")),
    ("HideWindowUI", pdf_metadata_name("/HideWindowUI")),
    ("FitWindow", pdf_metadata_name("/FitWindow")),
    ("CenterWindow", pdf_metadata_name("/CenterWindow")),
    ("DisplayDocTitle", pdf_metadata_name("/DisplayDocTitle")),
    ("NonFullScreenPageMode", pdf_metadata_non_full_screen_page_mode()),
  ]
  for field in viewer_fields {
    pdf_metadata_push_text_line(
      output,
      field.0,
      self.viewer_preference_item(field.1),
    )
  }
  let acroform = match self.catalog_item(pdf_metadata_acroform()) {
    "" => "False"
    value => value
  }
  pdf_metadata_push_text_line(output, "AcroForm", acroform)
  pdf_metadata_push_text_line(
    output,
    "XFA",
    if self.is_xfa() {
      "True"
    } else {
      "False"
    },
  )
  pdf_metadata_push_text_line(
    output,
    "Marked",
    if self.mark_info_item(pdf_metadata_name("/Marked")) {
      "True"
    } else {
      "False"
    },
  )
  pdf_metadata_push_text_line(
    output,
    "UserProperties",
    if self.mark_info_item(pdf_metadata_name("/UserProperties")) {
      "True"
    } else {
      "False"
    },
  )
  pdf_metadata_push_text_line(
    output,
    "Suspects",
    if self.mark_info_item(pdf_metadata_name("/Suspects")) {
      "True"
    } else {
      "False"
    },
  )
  let mediaboxes : Array[PdfObject?] = []
  let cropboxes : Array[PdfObject?] = []
  let bleedboxes : Array[PdfObject?] = []
  let trimboxes : Array[PdfObject?] = []
  let artboxes : Array[PdfObject?] = []
  for page in pages {
    mediaboxes.push(Some(page.mediabox))
    cropboxes.push(self.lookup_direct(pdf_metadata_cropbox(), page.rest))
    bleedboxes.push(self.lookup_direct(pdf_metadata_bleedbox(), page.rest))
    trimboxes.push(self.lookup_direct(pdf_metadata_trimbox(), page.rest))
    artboxes.push(self.lookup_direct(pdf_metadata_artbox(), page.rest))
  }
  pdf_metadata_push_text_line(
    output,
    "MediaBox",
    self.pdf_metadata_info_box_text(mediaboxes, unit),
  )
  pdf_metadata_push_text_line(
    output,
    "CropBox",
    self.pdf_metadata_info_box_text(cropboxes, unit),
  )
  pdf_metadata_push_text_line(
    output,
    "BleedBox",
    self.pdf_metadata_info_box_text(bleedboxes, unit),
  )
  pdf_metadata_push_text_line(
    output,
    "TrimBox",
    self.pdf_metadata_info_box_text(trimboxes, unit),
  )
  pdf_metadata_push_text_line(
    output,
    "ArtBox",
    self.pdf_metadata_info_box_text(artboxes, unit),
  )
  @utf8.encode(output.join(""))
}

///|
/// Return cpdf-style XMP metadata report fields as JSON.
pub fn PdfDocument::xmp_info_json(self : PdfDocument) -> Json raise PdfError {
  let output : Map[String, Json] = Map([])
  output.set(
    "Subformats",
    pdf_metadata_json_string_array(self.determine_subformats()),
  )
  match self.language() {
    Some(language) =>
      output.set("Language", Json::string(@utf8.decode_lossy(language)))
    None => output.set("Language", Json::null())
  }
  match self.metadata() {
    Some(metadata) =>
      for field in pdf_metadata_xmp_report_fields {
        pdf_metadata_add_xmp_report_field(output, metadata, field)
      }
    None => ()
  }
  Json::object(output)
}

///|
/// Return cpdf-style XMP metadata report fields as UTF-8 JSON bytes.
pub fn PdfDocument::xmp_info_json_blob(
  self : PdfDocument,
) -> PdfBytes raise PdfError {
  @utf8.encode(self.xmp_info_json().stringify())
}

///|
/// Return cpdf-style XMP metadata report fields as stdout-style UTF-8 bytes.
pub fn PdfDocument::xmp_info_blob(
  self : PdfDocument,
) -> PdfBytes raise PdfError {
  let output : Array[String] = []
  output.push("Subformats: ")
  output.push(pdf_metadata_combine_with_commas(self.determine_subformats()))
  output.push("\nLanguage: ")
  match self.language() {
    Some(language) => {
      output.push("\"")
      output.push(@utf8.decode_lossy(language))
      output.push("\"")
    }
    None => ()
  }
  output.push("\n")
  match self.metadata() {
    Some(metadata) => {
      let document = pdf_metadata_xmltree_of_bytes(metadata) catch {
        _ => return @utf8.encode(output.join(""))
      }
      for field in pdf_metadata_xmp_report_fields {
        pdf_metadata_add_xmp_report_line(output, document.tree, field)
      }
    }
    None => ()
  }
  @utf8.encode(output.join(""))
}
