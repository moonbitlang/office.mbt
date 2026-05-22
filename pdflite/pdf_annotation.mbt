///|
fn pdf_annotation_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_annotation_empty_name : PdfName = pdf_annotation_name("")

///|
let pdf_annotation_subtype_key_name : PdfName = pdf_annotation_name("/Subtype")

///|
fn pdf_annotation_subtype_key() -> PdfName {
  pdf_annotation_subtype_key_name
}

///|
let pdf_annotation_contents_key_name : PdfName = pdf_annotation_name(
  "/Contents",
)

///|
fn pdf_annotation_contents_key() -> PdfName {
  pdf_annotation_contents_key_name
}

///|
let pdf_annotation_rect_key_name : PdfName = pdf_annotation_name("/Rect")

///|
fn pdf_annotation_rect_key() -> PdfName {
  pdf_annotation_rect_key_name
}

///|
let pdf_annotation_border_key_name : PdfName = pdf_annotation_name("/Border")

///|
fn pdf_annotation_border_key() -> PdfName {
  pdf_annotation_border_key_name
}

///|
let pdf_annotation_bs_key_name : PdfName = pdf_annotation_name("/BS")

///|
fn pdf_annotation_bs_key() -> PdfName {
  pdf_annotation_bs_key_name
}

///|
let pdf_annotation_subj_key_name : PdfName = pdf_annotation_name("/Subj")

///|
fn pdf_annotation_subj_key() -> PdfName {
  pdf_annotation_subj_key_name
}

///|
let pdf_annotation_colour_key_name : PdfName = pdf_annotation_name("/C")

///|
fn pdf_annotation_colour_key() -> PdfName {
  pdf_annotation_colour_key_name
}

///|
let pdf_annotation_parent_key_name : PdfName = pdf_annotation_name("/Parent")

///|
fn pdf_annotation_parent_key() -> PdfName {
  pdf_annotation_parent_key_name
}

///|
let pdf_annotation_annots_key_name : PdfName = pdf_annotation_name("/Annots")

///|
fn pdf_annotation_annots_key() -> PdfName {
  pdf_annotation_annots_key_name
}

///|
let pdf_annotation_p_key_name : PdfName = pdf_annotation_name("/P")

///|
fn pdf_annotation_p_key() -> PdfName {
  pdf_annotation_p_key_name
}

///|
let pdf_annotation_dest_key_name : PdfName = pdf_annotation_name("/Dest")

///|
fn pdf_annotation_dest_key() -> PdfName {
  pdf_annotation_dest_key_name
}

///|
let pdf_annotation_a_key_name : PdfName = pdf_annotation_name("/A")

///|
fn pdf_annotation_a_key() -> PdfName {
  pdf_annotation_a_key_name
}

///|
let pdf_annotation_d_key_name : PdfName = pdf_annotation_name("/D")

///|
fn pdf_annotation_d_key() -> PdfName {
  pdf_annotation_d_key_name
}

///|
let pdf_annotation_width_key_name : PdfName = pdf_annotation_name("/W")

///|
fn pdf_annotation_width_key() -> PdfName {
  pdf_annotation_width_key_name
}

///|
let pdf_annotation_style_key_name : PdfName = pdf_annotation_name("/S")

///|
fn pdf_annotation_style_key() -> PdfName {
  pdf_annotation_style_key_name
}

///|
let pdf_annotation_dash_key_name : PdfName = pdf_annotation_name("/D")

///|
fn pdf_annotation_dash_key() -> PdfName {
  pdf_annotation_dash_key_name
}

///|
let pdf_annotation_quadpoints_key_name : PdfName = pdf_annotation_name(
  "/QuadPoints",
)

///|
fn pdf_annotation_quadpoints_key() -> PdfName {
  pdf_annotation_quadpoints_key_name
}

///|
let pdf_annotation_line_key_name : PdfName = pdf_annotation_name("/L")

///|
fn pdf_annotation_line_key() -> PdfName {
  pdf_annotation_line_key_name
}

///|
let pdf_annotation_beveled_name : PdfName = pdf_annotation_name("/B")

///|
let pdf_annotation_inset_name : PdfName = pdf_annotation_name("/I")

///|
let pdf_annotation_underline_style_name : PdfName = pdf_annotation_name("/U")

///|
let pdf_annotation_text_name : PdfName = pdf_annotation_name("/Text")

///|
let pdf_annotation_link_name : PdfName = pdf_annotation_name("/Link")

///|
let pdf_annotation_free_text_name : PdfName = pdf_annotation_name("/FreeText")

///|
let pdf_annotation_line_name : PdfName = pdf_annotation_name("/Line")

///|
let pdf_annotation_square_name : PdfName = pdf_annotation_name("/Square")

///|
let pdf_annotation_circle_name : PdfName = pdf_annotation_name("/Circle")

///|
let pdf_annotation_polygon_name : PdfName = pdf_annotation_name("/Polygon")

///|
let pdf_annotation_polyline_name : PdfName = pdf_annotation_name("/PolyLine")

///|
let pdf_annotation_highlight_name : PdfName = pdf_annotation_name("/Highlight")

///|
let pdf_annotation_underline_name : PdfName = pdf_annotation_name("/Underline")

///|
let pdf_annotation_squiggly_name : PdfName = pdf_annotation_name("/Squiggly")

///|
let pdf_annotation_strikeout_name : PdfName = pdf_annotation_name("/StrikeOut")

///|
let pdf_annotation_stamp_name : PdfName = pdf_annotation_name("/Stamp")

///|
let pdf_annotation_caret_name : PdfName = pdf_annotation_name("/Caret")

///|
let pdf_annotation_ink_name : PdfName = pdf_annotation_name("/Ink")

///|
let pdf_annotation_popup_name : PdfName = pdf_annotation_name("/Popup")

///|
let pdf_annotation_file_attachment_name : PdfName = pdf_annotation_name(
  "/FileAttachment",
)

///|
let pdf_annotation_sound_name : PdfName = pdf_annotation_name("/Sound")

///|
let pdf_annotation_movie_name : PdfName = pdf_annotation_name("/Movie")

///|
let pdf_annotation_widget_name : PdfName = pdf_annotation_name("/Widget")

///|
let pdf_annotation_screen_name : PdfName = pdf_annotation_name("/Screen")

///|
let pdf_annotation_printer_mark_name : PdfName = pdf_annotation_name(
  "/PrinterMark",
)

///|
let pdf_annotation_trap_net_name : PdfName = pdf_annotation_name("/TrapNet")

///|
let pdf_annotation_watermark_name : PdfName = pdf_annotation_name("/Watermark")

///|
let pdf_annotation_three_dee_name : PdfName = pdf_annotation_name("/3D")

///|
let pdf_annotation_unknown_name : PdfName = pdf_annotation_name("/Unknown")

///|
/// Border style used by an annotation border dictionary.
pub(all) enum PdfAnnotationStyle {
  AnnotationNoStyle
  AnnotationSolid
  AnnotationDashed
  AnnotationBeveled
  AnnotationInset
  AnnotationUnderlineStyle
} derive(Debug, Eq, ToJson)

///|
/// Parsed annotation border information.
///
/// `vertical_radius` and `horizontal_radius` come from the legacy `/Border`
/// array form. `style` and `dash_array` represent `/BS` dictionary entries when
/// present.
pub(all) struct PdfAnnotationBorder {
  width : Double
  vertical_radius : Double
  horizontal_radius : Double
  style : PdfAnnotationStyle
  dash_array : Array[Int]
} derive(Debug, Eq, ToJson)

///|
/// RGB annotation colour from the `/C` entry.
///
/// Components are stored as integer channel values after parsing PDF numbers.
pub(all) struct PdfAnnotationColour {
  red : Int
  green : Int
  blue : Int
} derive(Debug, Eq, ToJson)

///|
/// Supported annotation subtype.
///
/// Popup annotations embed their resolved parent annotation when available.
/// Unknown subtype names are preserved as `AnnotationUnknown`.
pub(all) enum PdfAnnotationSubtype {
  AnnotationText
  AnnotationLink
  AnnotationFreeText
  AnnotationLine
  AnnotationSquare
  AnnotationCircle
  AnnotationPolygon
  AnnotationPolyLine
  AnnotationHighlight
  AnnotationUnderline
  AnnotationSquiggly
  AnnotationStrikeOut
  AnnotationStamp
  AnnotationCaret
  AnnotationInk
  AnnotationPopup(PdfAnnotation)
  AnnotationFileAttachment
  AnnotationSound
  AnnotationMovie
  AnnotationWidget
  AnnotationScreen
  AnnotationPrinterMark
  AnnotationTrapNet
  AnnotationWatermark
  AnnotationThreeDee
  AnnotationUnknown(PdfName)
} derive(Debug, Eq, ToJson)

///|
/// Parsed PDF annotation dictionary.
///
/// `contents` and `subject` are raw PDF string bytes. `rectangle` is required
/// when reading from a PDF. `rest` preserves dictionary entries not modeled by
/// the typed fields so they can be written back.
pub(all) struct PdfAnnotation {
  subtype : PdfAnnotationSubtype
  contents : PdfBytes?
  subject : PdfBytes?
  rectangle : PdfRectangle
  border : PdfAnnotationBorder
  colour : PdfAnnotationColour?
  rest : PdfObject
} derive(Debug, Eq, ToJson)

///|
fn pdf_annotation_default_border() -> PdfAnnotationBorder {
  {
    width: 1.0,
    vertical_radius: 0.0,
    horizontal_radius: 0.0,
    style: AnnotationNoStyle,
    dash_array: [],
  }
}

///|
fn pdf_annotation_zero_rectangle() -> PdfRectangle {
  { min_x: 0.0, min_y: 0.0, max_x: 0.0, max_y: 0.0 }
}

///|
/// Build an annotation border, copying the supplied dash array.
pub fn pdf_annotation_make_border(
  width : Double,
  vertical_radius? : Double = 0.0,
  horizontal_radius? : Double = 0.0,
  style? : PdfAnnotationStyle = AnnotationNoStyle,
  dash_array? : ArrayView[Int] = [],
) -> PdfAnnotationBorder {
  {
    width,
    vertical_radius,
    horizontal_radius,
    style,
    dash_array: [
      for dash in dash_array => dash
    ],
  }
}

///|
/// Build an annotation value with CamlPDF-compatible defaults.
///
/// Defaults are no contents, no subject, a zero rectangle, default border, no
/// colour, and no preserved extra dictionary entries.
pub fn pdf_annotation_make(
  subtype : PdfAnnotationSubtype,
  contents? : PdfBytes? = None,
  border? : PdfAnnotationBorder = pdf_annotation_default_border(),
  rectangle? : PdfRectangle = pdf_annotation_zero_rectangle(),
  colour? : PdfAnnotationColour? = None,
  subject? : PdfBytes? = None,
) -> PdfAnnotation {
  { subtype, contents, subject, rectangle, border, colour, rest: PdfNull }
}

///|
fn pdf_annotation_style_of_name(name : PdfName) -> PdfAnnotationStyle {
  if name == pdf_annotation_style_key() {
    AnnotationSolid
  } else if name == pdf_annotation_dash_key() {
    AnnotationDashed
  } else if name == pdf_annotation_beveled_name {
    AnnotationBeveled
  } else if name == pdf_annotation_inset_name {
    AnnotationInset
  } else if name == pdf_annotation_underline_style_name {
    AnnotationUnderlineStyle
  } else {
    AnnotationNoStyle
  }
}

///|
fn pdf_annotation_subtype_name(subtype : PdfAnnotationSubtype) -> PdfName {
  match subtype {
    AnnotationText => pdf_annotation_text_name
    AnnotationLink => pdf_annotation_link_name
    AnnotationFreeText => pdf_annotation_free_text_name
    AnnotationLine => pdf_annotation_line_name
    AnnotationSquare => pdf_annotation_square_name
    AnnotationCircle => pdf_annotation_circle_name
    AnnotationPolygon => pdf_annotation_polygon_name
    AnnotationPolyLine => pdf_annotation_polyline_name
    AnnotationHighlight => pdf_annotation_highlight_name
    AnnotationUnderline => pdf_annotation_underline_name
    AnnotationSquiggly => pdf_annotation_squiggly_name
    AnnotationStrikeOut => pdf_annotation_strikeout_name
    AnnotationStamp => pdf_annotation_stamp_name
    AnnotationCaret => pdf_annotation_caret_name
    AnnotationInk => pdf_annotation_ink_name
    AnnotationPopup(_) => pdf_annotation_popup_name
    AnnotationFileAttachment => pdf_annotation_file_attachment_name
    AnnotationSound => pdf_annotation_sound_name
    AnnotationMovie => pdf_annotation_movie_name
    AnnotationWidget => pdf_annotation_widget_name
    AnnotationScreen => pdf_annotation_screen_name
    AnnotationPrinterMark => pdf_annotation_printer_mark_name
    AnnotationTrapNet => pdf_annotation_trap_net_name
    AnnotationWatermark => pdf_annotation_watermark_name
    AnnotationThreeDee => pdf_annotation_three_dee_name
    AnnotationUnknown(_) => pdf_annotation_unknown_name
  }
}

///|
fn PdfDocument::pdf_annotation_subtype(
  self : PdfDocument,
  annotation : PdfObject,
  depth : Int,
) -> PdfAnnotationSubtype raise PdfError {
  match self.lookup_direct(pdf_annotation_subtype_key(), annotation) {
    Some(PdfNameObject(name)) if name == pdf_annotation_text_name =>
      AnnotationText
    Some(PdfNameObject(name)) if name == pdf_annotation_free_text_name =>
      AnnotationFreeText
    Some(PdfNameObject(name)) if name == pdf_annotation_popup_name =>
      match
        self.direct(annotation).lookup_immediate(pdf_annotation_parent_key()) {
        Some(PdfIndirect(parent)) if depth < 64 =>
          AnnotationPopup(
            self.pdf_annotation_read_depth(PdfIndirect(parent), depth + 1),
          )
        _ => AnnotationUnknown(pdf_annotation_empty_name)
      }
    Some(PdfNameObject(name)) if name == pdf_annotation_stamp_name =>
      AnnotationStamp
    Some(PdfNameObject(name)) if name == pdf_annotation_link_name =>
      AnnotationLink
    Some(PdfNameObject(name)) if name == pdf_annotation_line_name =>
      AnnotationLine
    Some(PdfNameObject(name)) if name == pdf_annotation_square_name =>
      AnnotationSquare
    Some(PdfNameObject(name)) if name == pdf_annotation_circle_name =>
      AnnotationCircle
    Some(PdfNameObject(name)) if name == pdf_annotation_polygon_name =>
      AnnotationPolygon
    Some(PdfNameObject(name)) if name == pdf_annotation_polyline_name =>
      AnnotationPolyLine
    Some(PdfNameObject(name)) if name == pdf_annotation_highlight_name =>
      AnnotationHighlight
    Some(PdfNameObject(name)) if name == pdf_annotation_underline_name =>
      AnnotationUnderline
    Some(PdfNameObject(name)) if name == pdf_annotation_squiggly_name =>
      AnnotationSquiggly
    Some(PdfNameObject(name)) if name == pdf_annotation_strikeout_name =>
      AnnotationStrikeOut
    Some(PdfNameObject(name)) if name == pdf_annotation_caret_name =>
      AnnotationCaret
    Some(PdfNameObject(name)) if name == pdf_annotation_ink_name =>
      AnnotationInk
    Some(PdfNameObject(name)) if name == pdf_annotation_file_attachment_name =>
      AnnotationFileAttachment
    Some(PdfNameObject(name)) if name == pdf_annotation_sound_name =>
      AnnotationSound
    Some(PdfNameObject(name)) if name == pdf_annotation_movie_name =>
      AnnotationMovie
    Some(PdfNameObject(name)) if name == pdf_annotation_widget_name =>
      AnnotationWidget
    Some(PdfNameObject(name)) if name == pdf_annotation_screen_name =>
      AnnotationScreen
    Some(PdfNameObject(name)) if name == pdf_annotation_printer_mark_name =>
      AnnotationPrinterMark
    Some(PdfNameObject(name)) if name == pdf_annotation_trap_net_name =>
      AnnotationTrapNet
    Some(PdfNameObject(name)) if name == pdf_annotation_watermark_name =>
      AnnotationWatermark
    Some(PdfNameObject(name)) if name == pdf_annotation_three_dee_name =>
      AnnotationThreeDee
    Some(PdfNameObject(name)) => AnnotationUnknown(name)
    _ => AnnotationUnknown(pdf_annotation_empty_name)
  }
}

///|
fn PdfDocument::pdf_annotation_number_array(
  self : PdfDocument,
  object : PdfObject,
) -> Array[Int] raise PdfError {
  match self.direct(object) {
    PdfArray(items) => {
      let output : Array[Int] = []
      for item in items {
        output.push(self.get_number(item).to_int())
      }
      output
    }
    _ => []
  }
}

///|
fn PdfDocument::pdf_annotation_border(
  self : PdfDocument,
  annotation : PdfObject,
) -> PdfAnnotationBorder raise PdfError {
  match self.lookup_direct(pdf_annotation_bs_key(), annotation) {
    Some(border_style_dict) => {
      let width = match
        self.lookup_direct(pdf_annotation_width_key(), border_style_dict) {
        Some(width) => self.get_number(width)
        _ => 1.0
      }
      let style = match
        self.lookup_direct(pdf_annotation_style_key(), border_style_dict) {
        Some(PdfNameObject(name)) => pdf_annotation_style_of_name(name)
        _ => AnnotationNoStyle
      }
      let dash_array = match
        self.lookup_direct(pdf_annotation_dash_key(), border_style_dict) {
        Some(dash) => self.pdf_annotation_number_array(dash)
        _ => []
      }
      { width, vertical_radius: 0.0, horizontal_radius: 0.0, style, dash_array }
    }
    None =>
      match self.lookup_direct(pdf_annotation_border_key(), annotation) {
        Some(PdfArray([horizontal, vertical, width])) =>
          {
            width: self.get_number(width),
            vertical_radius: self.get_number(vertical),
            horizontal_radius: self.get_number(horizontal),
            style: AnnotationNoStyle,
            dash_array: [],
          }
        Some(PdfArray([horizontal, vertical, width, dash_array])) =>
          {
            width: self.get_number(width),
            vertical_radius: self.get_number(vertical),
            horizontal_radius: self.get_number(horizontal),
            style: AnnotationNoStyle,
            dash_array: self.pdf_annotation_number_array(dash_array),
          }
        _ => pdf_annotation_default_border()
      }
  }
}

///|
fn PdfDocument::pdf_annotation_colour(
  self : PdfDocument,
  annotation : PdfObject,
) -> PdfAnnotationColour? raise PdfError {
  match self.lookup_direct(pdf_annotation_colour_key(), annotation) {
    Some(PdfArray([red, green, blue])) =>
      Some({
        red: self.get_number(red).to_int(),
        green: self.get_number(green).to_int(),
        blue: self.get_number(blue).to_int(),
      })
    _ => None
  }
}

///|
fn pdf_annotation_is_record_key(key : PdfName) -> Bool {
  key == pdf_annotation_subtype_key() ||
  key == pdf_annotation_contents_key() ||
  key == pdf_annotation_rect_key() ||
  key == pdf_annotation_border_key() ||
  key == pdf_annotation_subj_key() ||
  key == pdf_annotation_bs_key() ||
  key == pdf_annotation_colour_key()
}

///|
fn pdf_annotation_rest(annotation : PdfObject) -> PdfObject raise PdfError {
  match annotation {
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = []
      for entry in entries {
        let (key, _) = entry
        if !pdf_annotation_is_record_key(key) {
          output.push(entry)
        }
      }
      PdfDictionary(output)
    }
    _ => raise DictionaryExpected
  }
}

///|
fn PdfDocument::pdf_annotation_read_depth(
  self : PdfDocument,
  annotation : PdfObject,
  depth : Int,
) -> PdfAnnotation raise PdfError {
  let direct_annotation = self.direct(annotation)
  {
    subtype: self.pdf_annotation_subtype(direct_annotation, depth),
    contents: match
      self.lookup_direct(pdf_annotation_contents_key(), direct_annotation) {
      Some(PdfString(contents)) => Some(contents)
      _ => None
    },
    subject: match
      self.lookup_direct(pdf_annotation_subj_key(), direct_annotation) {
      Some(PdfString(subject)) => Some(subject)
      _ => None
    },
    rectangle: match
      self.lookup_direct(pdf_annotation_rect_key(), direct_annotation) {
      Some(rectangle) => self.parse_rectangle(rectangle)
      None => raise RectangleExpected
    },
    border: self.pdf_annotation_border(direct_annotation),
    colour: self.pdf_annotation_colour(direct_annotation),
    rest: pdf_annotation_rest(direct_annotation),
  }
}

///|
/// Read one annotation dictionary from this document.
///
/// The annotation object may be direct or indirect. `/Rect` is required. Popup
/// parents are resolved recursively up to a bounded depth to avoid cycles.
pub fn PdfDocument::read_annotation(
  self : PdfDocument,
  annotation : PdfObject,
) -> PdfAnnotation raise PdfError {
  self.pdf_annotation_read_depth(annotation, 0)
}

///|
fn PdfDocument::pdf_annotation_popup_parent(
  self : PdfDocument,
  annotation : PdfObject,
) -> Int? {
  match self.direct(annotation).lookup_immediate(pdf_annotation_parent_key()) {
    Some(PdfIndirect(parent)) => Some(parent)
    _ => None
  }
}

///|
/// Read annotations from a page's `/Annots` array.
///
/// Missing or malformed `/Annots` entries are treated as no annotations. When a
/// popup annotation and its parent both appear in the page array, the parent is
/// skipped and represented through `AnnotationPopup`.
pub fn PdfDocument::annotations_of_page(
  self : PdfDocument,
  page : PdfPage,
) -> Array[PdfAnnotation] raise PdfError {
  match self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
    Some(PdfArray(annotations)) => {
      let popup_parents : Array[Int] = []
      for annotation in annotations {
        match self.pdf_annotation_popup_parent(annotation) {
          Some(parent) => popup_parents.push(parent)
          None => ()
        }
      }
      let popup_parent_set = @number_set.pdf_number_set(popup_parents)
      let output : Array[PdfAnnotation] = []
      for annotation in annotations {
        match annotation {
          PdfIndirect(number) if popup_parent_set.contains(number) => ()
          _ => output.push(self.read_annotation(annotation))
        }
      }
      output
    }
    _ => []
  }
}

///|
/// Compatibility wrapper for `PdfDocument::annotations_of_page`.
pub fn pdf_annotations_of_page(
  document : PdfDocument,
  page : PdfPage,
) -> Array[PdfAnnotation] raise PdfError {
  document.annotations_of_page(page)
}

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
fn pdf_annotation_push_listing_line(
  output : Array[Byte],
  page_number : Int,
  contents : BytesView,
) -> Unit {
  pdf_writer_push_ascii(output, "Page ")
  pdf_writer_push_ascii(output, page_number.to_string())
  pdf_writer_push_ascii(output, ": ")
  pdf_writer_push_view(output, contents)
  pdf_writer_push_byte(output, 10)
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
  let output : Array[(Int, PdfBytes)] = []
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
  let output : Array[Byte] = []
  for index, page in pages {
    let page_number = index + 1
    if pdf_page_box_contains_page(page_numbers, page_number) {
      match self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
        Some(PdfArray(annotations)) =>
          for annotation in annotations {
            let contents = self.pdf_annotation_contents_text(
              encoding, annotation,
            )
            if contents.length() > 0 {
              pdf_annotation_push_listing_line(output, page_number, contents)
            }
          }
        _ => ()
      }
    }
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

///|
fn pdf_annotation_json_int_array_contains(
  values : ArrayView[Int],
  value : Int,
) -> Bool {
  for item in values {
    if item == value {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_annotation_json_rewrite_destination(
  page_numbers : PdfPageNumberLookup,
  destination : PdfObject,
) -> PdfObject {
  match destination {
    PdfArray(items) =>
      if items.length() == 0 {
        destination
      } else {
        match items[0] {
          PdfIndirect(number) => {
            let rewritten : Array[PdfObject] = [
              PdfInteger(page_numbers.page_number(number)),
            ]
            for index in 1..<items.length() {
              rewritten.push(items[index])
            }
            PdfArray(rewritten)
          }
          _ => destination
        }
      }
    _ => destination
  }
}

///|
fn PdfDocument::pdf_annotation_json_rewrite_destinations(
  self : PdfDocument,
  page_numbers : PdfPageNumberLookup,
  annotation : PdfObject,
) -> PdfObject raise PdfError {
  let mut rewritten = annotation
  match self.indirect_number(pdf_annotation_p_key(), rewritten) {
    Some(number) =>
      rewritten = rewritten.add_dict_entry(
        pdf_annotation_p_key(),
        PdfInteger(page_numbers.page_number(number)),
      )
    None => ()
  }
  match self.lookup_direct(pdf_annotation_dest_key(), rewritten) {
    Some(destination) =>
      rewritten = rewritten.add_dict_entry(
        pdf_annotation_dest_key(),
        pdf_annotation_json_rewrite_destination(page_numbers, destination),
      )
    None =>
      match self.lookup_direct(pdf_annotation_a_key(), rewritten) {
        Some(action) =>
          match self.lookup_direct(pdf_annotation_d_key(), action) {
            Some(destination) =>
              rewritten = rewritten.add_dict_entry(
                pdf_annotation_a_key(),
                action.add_dict_entry(
                  pdf_annotation_d_key(),
                  pdf_annotation_json_rewrite_destination(
                    page_numbers, destination,
                  ),
                ),
              )
            None => ()
          }
        None => ()
      }
  }
  rewritten
}

///|
fn pdf_annotation_json_extra_root(
  object : PdfObject,
) -> PdfObject raise PdfError {
  match object.dictionary_view() {
    Some(_) =>
      object
      .remove_dict_entry(pdf_annotation_popup_name)
      .remove_dict_entry(pdf_annotation_parent_key())
    None => object
  }
}

///|
fn PdfDocument::pdf_annotation_json_extra_numbers(
  self : PdfDocument,
  roots : ArrayView[PdfObject],
  annotation_numbers : ArrayView[Int],
) -> Array[Int] raise PdfError {
  let found : @hashmap.HashMap[Int, Bool] = HashMap([])
  for root in roots {
    let searchable = pdf_annotation_json_extra_root(root)
    for number in self.referenced_object_numbers(searchable) {
      if !pdf_annotation_json_int_array_contains(annotation_numbers, number) {
        found[number] = true
      }
    }
  }
  let numbers = found.keys().to_array()
  numbers.sort()
  numbers
}

///|
fn PdfDocument::pdf_annotation_json_page(
  self : PdfDocument,
  page_numbers : PdfPageNumberLookup,
  page : PdfPage,
  page_number : Int,
  extra_roots : Array[PdfObject],
  annotation_numbers : Array[Int],
) -> Array[Json] raise PdfError {
  let output : Array[Json] = []
  match self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
    Some(PdfArray(annotations)) =>
      for annotation_ref in annotations {
        match annotation_ref {
          PdfIndirect(object_number) => {
            let annotation = self.direct(annotation_ref)
            let rewritten = self.pdf_annotation_json_rewrite_destinations(
              page_numbers, annotation,
            )
            extra_roots.push(rewritten)
            annotation_numbers.push(object_number)
            output.push(
              Json::array([
                pdf_util_json_number(page_number),
                pdf_util_json_number(object_number),
                self.json_of_object(rewritten, utf8=true, clean_strings=true),
              ]),
            )
          }
          _ => ()
        }
      }
    _ => ()
  }
  output
}

///|
fn pdf_annotation_json_format_header() -> Json {
  Json::array([
    pdf_util_json_number(-1),
    Json::object(
      Map([
        (
          "/CPDFJSONannotformatversion",
          Json::object(Map([("I", pdf_util_json_number(1))])),
        ),
      ]),
    ),
  ])
}

///|
/// Return cpdf's annotation JSON export for selected pages.
///
/// Only indirect page annotation entries are exported, matching cpdf's JSON
/// path. Page-object references in `/P`, `/Dest`, and action `/D` destinations
/// without `/Dest` are rewritten to 1-based page numbers. Referenced ancillary
/// objects are appended after annotation entries, excluding `/Popup` and
/// `/Parent` links.
pub fn PdfDocument::annotations_json(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Json raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "annotations_json",
  )
  let page_reference_numbers = self.page_reference_numbers()
  let page_number_lookup = pdf_page_number_lookup(page_reference_numbers)
  let entries : Array[Json] = [pdf_annotation_json_format_header()]
  let extra_roots : Array[PdfObject] = []
  let annotation_numbers : Array[Int] = []
  for index, page in pages {
    let page_number = index + 1
    if pdf_page_box_contains_page(page_numbers, page_number) {
      entries.append(
        self.pdf_annotation_json_page(
          page_number_lookup, page, page_number, extra_roots, annotation_numbers,
        ),
      )
    }
  }
  for
    number in self.pdf_annotation_json_extra_numbers(
      extra_roots, annotation_numbers,
    ) {
    entries.push(
      Json::array([
        pdf_util_json_number(number),
        self.json_of_object(
          self.lookup_object_or_null(number),
          utf8=true,
          clean_strings=true,
        ),
      ]),
    )
  }
  Json::array(entries)
}

///|
/// Return cpdf's annotation JSON export as UTF-8 JSON bytes.
pub fn PdfDocument::annotations_json_blob(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfBytes raise PdfError {
  @utf8.encode(self.annotations_json(page_numbers).stringify())
}

///|
/// Compatibility wrapper for `PdfDocument::annotations_json_blob`.
pub fn pdf_get_annotations_json(
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfBytes raise PdfError {
  document.annotations_json_blob(page_numbers)
}

///|
priv struct PdfAnnotationJsonImportRow {
  page_number : Int
  object_number : Int
  object : PdfObject
}

///|
priv struct PdfAnnotationJsonImportData {
  max_object_number : Int
  extras : Array[(Int, PdfObject)]
  annotations : Array[PdfAnnotationJsonImportRow]
}

///|
fn pdf_annotation_json_import_number(json : Json) -> Int raise PdfError {
  match json {
    Number(value, repr=_) => pdf_util_json_integral_number(value)
    _ => raise SoftError("Bad annots entry")
  }
}

///|
fn pdf_annotation_json_import_data(
  json : Json,
) -> PdfAnnotationJsonImportData raise PdfError {
  let entries = match json {
    Array(values) => values
    _ => raise SoftError("Bad Annotations JSON file")
  }
  let max_object_number : Ref[Int] = { val: 0 }
  let extras : Array[(Int, PdfObject)] = []
  let annotations : Array[PdfAnnotationJsonImportRow] = []
  for entry in entries {
    match entry {
      Array([number_json, object_json]) => {
        let number = pdf_annotation_json_import_number(number_json)
        if number > 0 {
          extras.push((number, pdf_object_of_json(object_json)))
          if number > max_object_number.val {
            max_object_number.val = number
          }
        }
      }
      Array([page_json, number_json, object_json]) => {
        let page_number = pdf_annotation_json_import_number(page_json)
        let object_number = pdf_annotation_json_import_number(number_json)
        if object_number <= 0 {
          raise SoftError("Bad annots entry")
        }
        annotations.push({
          page_number,
          object_number,
          object: pdf_object_of_json(object_json),
        })
        if object_number > max_object_number.val {
          max_object_number.val = object_number
        }
      }
      _ => raise SoftError("Bad annots entry")
    }
  }
  { max_object_number: max_object_number.val, extras, annotations }
}

///|
fn PdfDocument::pdf_annotation_json_import_renumbered(
  self : PdfDocument,
  max_object_number : Int,
) -> PdfDocument raise PdfError {
  if max_object_number <= 0 {
    self.copy()
  } else {
    let changes : Array[(Int, Int)] = []
    for index, number in self.object_numbers() {
      changes.push((number, max_object_number + index + 1))
    }
    self.renumber_objects(changes)
  }
}

///|
fn pdf_annotation_json_import_page_reference(
  page_reference_numbers : ArrayView[Int],
  page_number : Int,
) -> Int {
  if page_number >= 1 && page_number <= page_reference_numbers.length() {
    page_reference_numbers[page_number - 1]
  } else {
    page_number
  }
}

///|
fn pdf_annotation_json_import_destination(
  page_reference_numbers : ArrayView[Int],
  destination : PdfObject,
) -> PdfObject {
  match destination {
    PdfArray(items) =>
      if items.length() == 0 {
        destination
      } else {
        match items[0] {
          PdfInteger(page_number) => {
            let rewritten : Array[PdfObject] = [
              PdfIndirect(
                pdf_annotation_json_import_page_reference(
                  page_reference_numbers, page_number,
                ),
              ),
            ]
            for index in 1..<items.length() {
              rewritten.push(items[index])
            }
            PdfArray(rewritten)
          }
          _ => destination
        }
      }
    _ => destination
  }
}

///|
fn PdfDocument::pdf_annotation_json_import_destinations(
  self : PdfDocument,
  page_reference_numbers : ArrayView[Int],
  annotation : PdfObject,
) -> PdfObject raise PdfError {
  let mut rewritten = annotation
  match self.lookup_direct(pdf_annotation_p_key(), rewritten) {
    Some(PdfInteger(page_number)) =>
      rewritten = rewritten.add_dict_entry(
        pdf_annotation_p_key(),
        PdfIndirect(
          pdf_annotation_json_import_page_reference(
            page_reference_numbers, page_number,
          ),
        ),
      )
    _ => ()
  }
  match self.lookup_direct(pdf_annotation_dest_key(), rewritten) {
    Some(destination) =>
      rewritten = rewritten.add_dict_entry(
        pdf_annotation_dest_key(),
        pdf_annotation_json_import_destination(
          page_reference_numbers, destination,
        ),
      )
    None =>
      match self.lookup_direct(pdf_annotation_a_key(), rewritten) {
        Some(action) =>
          match self.lookup_direct(pdf_annotation_d_key(), action) {
            Some(destination) =>
              rewritten = rewritten.add_dict_entry(
                pdf_annotation_a_key(),
                action.add_dict_entry(
                  pdf_annotation_d_key(),
                  pdf_annotation_json_import_destination(
                    page_reference_numbers, destination,
                  ),
                ),
              )
            None => ()
          }
        None => ()
      }
  }
  rewritten
}

///|
fn PdfDocument::pdf_annotation_json_import_rows_for_page(
  self : PdfDocument,
  page_reference_numbers : ArrayView[Int],
  rows : ArrayView[PdfAnnotationJsonImportRow],
  page_number : Int,
) -> Array[PdfObject] raise PdfError {
  let imported : Array[PdfObject] = []
  for row in rows {
    if row.page_number == page_number {
      self.add_object_given_number(
        row.object_number,
        self.pdf_annotation_json_import_destinations(
          page_reference_numbers,
          row.object,
        ),
      )
      imported.push(PdfIndirect(row.object_number))
    }
  }
  imported
}

///|
fn PdfDocument::pdf_annotation_json_import_pages(
  self : PdfDocument,
  rows : ArrayView[PdfAnnotationJsonImportRow],
) -> PdfDocument raise PdfError {
  if rows.length() == 0 {
    self.copy()
  } else {
    let page_reference_numbers = self.page_reference_numbers()
    let pages = self.pages_of_pagetree()
    let rewritten : Array[PdfPage] = []
    for index, page in pages {
      let page_number = index + 1
      let imported = self.pdf_annotation_json_import_rows_for_page(
        page_reference_numbers, rows, page_number,
      )
      if imported.length() == 0 {
        rewritten.push(page)
      } else {
        let existing = match
          self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
          Some(PdfArray(annotations)) => annotations
          _ => []
        }
        rewritten.push({
          ..page,
          rest: page.rest.add_dict_entry(
            pdf_annotation_annots_key(),
            PdfArray([..existing, ..imported]),
          ),
        })
      }
    }
    self.change_pages(rewritten, change_references=true)
  }
}

///|
/// Return a copy of the document with cpdf annotation JSON appended.
///
/// Existing objects are first renumbered above the imported annotation object
/// range, matching cpdf's collision-avoidance strategy. Header rows and other
/// nonpositive extra-object rows are ignored; positive extra objects are added
/// before page annotations are rebuilt.
pub fn PdfDocument::set_annotations_json(
  self : PdfDocument,
  json : Json,
) -> PdfDocument raise PdfError {
  let data = pdf_annotation_json_import_data(json)
  let document = self.pdf_annotation_json_import_renumbered(
    data.max_object_number,
  )
  for extra in data.extras {
    document.add_object_given_number(extra.0, extra.1)
  }
  document.pdf_annotation_json_import_pages(data.annotations)
}

///|
/// Compatibility wrapper for `PdfDocument::set_annotations_json`.
pub fn pdf_set_annotations_json(
  json : Json,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.set_annotations_json(json)
}

///|
/// Return a copy of this document with annotations copied from `source`.
pub fn PdfDocument::copy_annotations_from(
  self : PdfDocument,
  source : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  self.set_annotations_json(source.annotations_json(page_numbers))
}

///|
/// Compatibility wrapper for `PdfDocument::copy_annotations_from`.
pub fn pdf_copy_annotations(
  page_numbers : ArrayView[Int],
  source : PdfDocument,
  target : PdfDocument,
) -> PdfDocument raise PdfError {
  target.copy_annotations_from(source, page_numbers)
}

///|
/// Return a copy of the document with `/Annots` removed from selected pages.
pub fn PdfDocument::remove_annotations(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "remove_annotations",
  )
  let rewritten : Array[PdfPage] = []
  for index, page in pages {
    let page_number = index + 1
    if pdf_page_box_contains_page(page_numbers, page_number) {
      rewritten.push({
        ..page,
        rest: page.rest.remove_dict_entry(pdf_annotation_annots_key()),
      })
    } else {
      rewritten.push(page)
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::remove_annotations`.
pub fn pdf_remove_annotations(
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.remove_annotations(page_numbers)
}

///|
fn pdf_annotation_rectangle_object(rectangle : PdfRectangle) -> PdfObject {
  PdfArray([
    PdfReal(rectangle.min_x),
    PdfReal(rectangle.min_y),
    PdfReal(rectangle.max_x),
    PdfReal(rectangle.max_y),
  ])
}

///|
fn pdf_annotation_border_object(border : PdfAnnotationBorder) -> PdfObject {
  let base : Array[PdfObject] = [
    PdfReal(border.horizontal_radius),
    PdfReal(border.vertical_radius),
    PdfReal(border.width),
  ]
  if border.dash_array.length() > 0 {
    base.push(PdfArray([ for dash in border.dash_array => PdfInteger(dash) ]))
  }
  PdfArray(base)
}

///|
fn pdf_annotation_rest_entries(
  rest : PdfObject,
) -> Array[(PdfName, PdfObject)] raise PdfError {
  match rest {
    PdfNull => []
    PdfDictionary(entries) => [ for entry in entries => entry ]
    _ => raise DictionaryExpected
  }
}

///|
fn pdf_object_of_annotation(
  annotation : PdfAnnotation,
) -> PdfObject raise PdfError {
  let entries : Array[(PdfName, PdfObject)] = [
    (
      pdf_annotation_subtype_key(),
      PdfNameObject(pdf_annotation_subtype_name(annotation.subtype)),
    ),
    (
      pdf_annotation_contents_key(),
      match annotation.contents {
        Some(contents) => PdfString(contents)
        None => PdfNull
      },
    ),
    (
      pdf_annotation_rect_key(),
      pdf_annotation_rectangle_object(annotation.rectangle),
    ),
    (
      pdf_annotation_border_key(),
      pdf_annotation_border_object(annotation.border),
    ),
  ]
  for entry in pdf_annotation_rest_entries(annotation.rest) {
    entries.push(entry)
  }
  match annotation.colour {
    Some(colour) =>
      entries.push(
        (
          pdf_annotation_colour_key(),
          PdfArray([
            PdfInteger(colour.red),
            PdfInteger(colour.green),
            PdfInteger(colour.blue),
          ]),
        ),
      )
    None => ()
  }
  match annotation.subject {
    Some(subject) =>
      entries.push((pdf_annotation_subj_key(), PdfString(subject)))
    None => ()
  }
  PdfDictionary(entries)
}

///|
/// Return a page value with an annotation prepended to `/Annots`.
///
/// The annotation is written as a direct dictionary. Existing annotation arrays
/// are preserved after the new entry; a non-array `/Annots` value raises.
pub fn PdfDocument::add_annotation(
  self : PdfDocument,
  page : PdfPage,
  annotation : PdfAnnotation,
) -> PdfPage raise PdfError {
  let object = pdf_object_of_annotation(annotation)
  let annotations = match
    self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
    Some(PdfArray(existing)) => [object, ..existing]
    Some(_) => raise DictionaryExpected
    None => [object]
  }
  {
    ..page,
    rest: page.rest.add_dict_entry(
      pdf_annotation_annots_key(),
      PdfArray(annotations),
    ),
  }
}

///|
/// Compatibility wrapper for `PdfDocument::add_annotation`.
pub fn pdf_add_annotation(
  document : PdfDocument,
  page : PdfPage,
  annotation : PdfAnnotation,
) -> PdfPage raise PdfError {
  document.add_annotation(page, annotation)
}

///|
fn PdfDocument::pdf_annotation_transform_one(
  self : PdfDocument,
  matrix : TransformMatrix,
  annotation_number : Int,
) -> Unit raise PdfError {
  let annotation = self.lookup_object_or_null(annotation_number)
  let transformed = self.pdf_annotation_transform_object(matrix, annotation)
  if transformed != annotation {
    self.add_object_given_number(annotation_number, transformed)
  }
}

///|
fn PdfDocument::pdf_annotation_transform_object(
  self : PdfDocument,
  matrix : TransformMatrix,
  annotation : PdfObject,
) -> PdfObject raise PdfError {
  let mut transformed = annotation
  match self.lookup_direct(pdf_annotation_rect_key(), annotation) {
    Some(rectangle) =>
      transformed = transformed.add_dict_entry(
        pdf_annotation_rect_key(),
        self.transform_rect(matrix, rectangle),
      )
    None => ()
  }
  match self.lookup_direct(pdf_annotation_quadpoints_key(), annotation) {
    Some(quadpoints) =>
      transformed = transformed.add_dict_entry(
        pdf_annotation_quadpoints_key(),
        self.transform_quadpoints(matrix, quadpoints),
      )
    None => ()
  }
  match self.lookup_direct(pdf_annotation_line_key(), annotation) {
    Some(line) =>
      transformed = transformed.add_dict_entry(
        pdf_annotation_line_key(),
        self.transform_rect(matrix, line),
      )
    None => ()
  }
  transformed
}

///|
/// Transform annotation geometry referenced by a page dictionary.
///
/// Applies `matrix` to `/Rect`, `/QuadPoints`, and `/L` entries. Indirect
/// annotations are updated in this document; direct annotation dictionaries in
/// the page's `/Annots` array are updated in place.
pub fn PdfDocument::transform_annotations(
  self : PdfDocument,
  matrix : TransformMatrix,
  rest : PdfObject,
) -> Unit raise PdfError {
  match self.lookup_direct(pdf_annotation_annots_key(), rest) {
    Some(PdfArray(annotations)) =>
      for index in 0..<annotations.length() {
        match annotations[index] {
          PdfIndirect(number) =>
            self.pdf_annotation_transform_one(matrix, number)
          PdfDictionary(_) as annotation => {
            let transformed = self.pdf_annotation_transform_object(
              matrix, annotation,
            )
            if transformed != annotation {
              annotations[index] = transformed
            }
          }
          _ => ()
        }
      }
    _ => ()
  }
}

///|
/// Compatibility wrapper for `PdfDocument::transform_annotations`.
pub fn pdf_transform_annotations(
  document : PdfDocument,
  matrix : TransformMatrix,
  rest : PdfObject,
) -> Unit raise PdfError {
  document.transform_annotations(matrix, rest)
}
