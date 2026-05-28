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
