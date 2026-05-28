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
