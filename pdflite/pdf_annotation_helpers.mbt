///|
fn pdf_annotation_style_of_name(
  name : PdfName,
) -> @annotation.PdfAnnotationStyle {
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
fn pdf_annotation_subtype_name(
  subtype : @annotation.PdfAnnotationSubtype,
) -> PdfName {
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
