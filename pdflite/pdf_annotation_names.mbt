///|
fn pdf_annotation_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_annotation_empty_name : @core.PdfName = pdf_annotation_name("")

///|
let pdf_annotation_subtype_key_name : @core.PdfName = pdf_annotation_name(
  "/Subtype",
)

///|
fn pdf_annotation_subtype_key() -> @core.PdfName {
  pdf_annotation_subtype_key_name
}

///|
let pdf_annotation_contents_key_name : @core.PdfName = pdf_annotation_name(
  "/Contents",
)

///|
fn pdf_annotation_contents_key() -> @core.PdfName {
  pdf_annotation_contents_key_name
}

///|
let pdf_annotation_rect_key_name : @core.PdfName = pdf_annotation_name("/Rect")

///|
fn pdf_annotation_rect_key() -> @core.PdfName {
  pdf_annotation_rect_key_name
}

///|
let pdf_annotation_border_key_name : @core.PdfName = pdf_annotation_name(
  "/Border",
)

///|
fn pdf_annotation_border_key() -> @core.PdfName {
  pdf_annotation_border_key_name
}

///|
let pdf_annotation_bs_key_name : @core.PdfName = pdf_annotation_name("/BS")

///|
fn pdf_annotation_bs_key() -> @core.PdfName {
  pdf_annotation_bs_key_name
}

///|
let pdf_annotation_subj_key_name : @core.PdfName = pdf_annotation_name("/Subj")

///|
fn pdf_annotation_subj_key() -> @core.PdfName {
  pdf_annotation_subj_key_name
}

///|
let pdf_annotation_colour_key_name : @core.PdfName = pdf_annotation_name("/C")

///|
fn pdf_annotation_colour_key() -> @core.PdfName {
  pdf_annotation_colour_key_name
}

///|
let pdf_annotation_parent_key_name : @core.PdfName = pdf_annotation_name(
  "/Parent",
)

///|
fn pdf_annotation_parent_key() -> @core.PdfName {
  pdf_annotation_parent_key_name
}

///|
let pdf_annotation_annots_key_name : @core.PdfName = pdf_annotation_name(
  "/Annots",
)

///|
fn pdf_annotation_annots_key() -> @core.PdfName {
  pdf_annotation_annots_key_name
}

///|
let pdf_annotation_p_key_name : @core.PdfName = pdf_annotation_name("/P")

///|
fn pdf_annotation_p_key() -> @core.PdfName {
  pdf_annotation_p_key_name
}

///|
let pdf_annotation_dest_key_name : @core.PdfName = pdf_annotation_name("/Dest")

///|
fn pdf_annotation_dest_key() -> @core.PdfName {
  pdf_annotation_dest_key_name
}

///|
let pdf_annotation_a_key_name : @core.PdfName = pdf_annotation_name("/A")

///|
fn pdf_annotation_a_key() -> @core.PdfName {
  pdf_annotation_a_key_name
}

///|
let pdf_annotation_d_key_name : @core.PdfName = pdf_annotation_name("/D")

///|
fn pdf_annotation_d_key() -> @core.PdfName {
  pdf_annotation_d_key_name
}

///|
let pdf_annotation_width_key_name : @core.PdfName = pdf_annotation_name("/W")

///|
fn pdf_annotation_width_key() -> @core.PdfName {
  pdf_annotation_width_key_name
}

///|
let pdf_annotation_style_key_name : @core.PdfName = pdf_annotation_name("/S")

///|
fn pdf_annotation_style_key() -> @core.PdfName {
  pdf_annotation_style_key_name
}

///|
let pdf_annotation_dash_key_name : @core.PdfName = pdf_annotation_name("/D")

///|
fn pdf_annotation_dash_key() -> @core.PdfName {
  pdf_annotation_dash_key_name
}

///|
let pdf_annotation_quadpoints_key_name : @core.PdfName = pdf_annotation_name(
  "/QuadPoints",
)

///|
fn pdf_annotation_quadpoints_key() -> @core.PdfName {
  pdf_annotation_quadpoints_key_name
}

///|
let pdf_annotation_line_key_name : @core.PdfName = pdf_annotation_name("/L")

///|
fn pdf_annotation_line_key() -> @core.PdfName {
  pdf_annotation_line_key_name
}

///|
let pdf_annotation_beveled_name : @core.PdfName = pdf_annotation_name("/B")

///|
let pdf_annotation_inset_name : @core.PdfName = pdf_annotation_name("/I")

///|
let pdf_annotation_underline_style_name : @core.PdfName = pdf_annotation_name(
  "/U",
)

///|
let pdf_annotation_text_name : @core.PdfName = pdf_annotation_name("/Text")

///|
let pdf_annotation_link_name : @core.PdfName = pdf_annotation_name("/Link")

///|
let pdf_annotation_free_text_name : @core.PdfName = pdf_annotation_name(
  "/FreeText",
)

///|
let pdf_annotation_line_name : @core.PdfName = pdf_annotation_name("/Line")

///|
let pdf_annotation_square_name : @core.PdfName = pdf_annotation_name("/Square")

///|
let pdf_annotation_circle_name : @core.PdfName = pdf_annotation_name("/Circle")

///|
let pdf_annotation_polygon_name : @core.PdfName = pdf_annotation_name(
  "/Polygon",
)

///|
let pdf_annotation_polyline_name : @core.PdfName = pdf_annotation_name(
  "/PolyLine",
)

///|
let pdf_annotation_highlight_name : @core.PdfName = pdf_annotation_name(
  "/Highlight",
)

///|
let pdf_annotation_underline_name : @core.PdfName = pdf_annotation_name(
  "/Underline",
)

///|
let pdf_annotation_squiggly_name : @core.PdfName = pdf_annotation_name(
  "/Squiggly",
)

///|
let pdf_annotation_strikeout_name : @core.PdfName = pdf_annotation_name(
  "/StrikeOut",
)

///|
let pdf_annotation_stamp_name : @core.PdfName = pdf_annotation_name("/Stamp")

///|
let pdf_annotation_caret_name : @core.PdfName = pdf_annotation_name("/Caret")

///|
let pdf_annotation_ink_name : @core.PdfName = pdf_annotation_name("/Ink")

///|
let pdf_annotation_popup_name : @core.PdfName = pdf_annotation_name("/Popup")

///|
let pdf_annotation_file_attachment_name : @core.PdfName = pdf_annotation_name(
  "/FileAttachment",
)

///|
let pdf_annotation_sound_name : @core.PdfName = pdf_annotation_name("/Sound")

///|
let pdf_annotation_movie_name : @core.PdfName = pdf_annotation_name("/Movie")

///|
let pdf_annotation_widget_name : @core.PdfName = pdf_annotation_name("/Widget")

///|
let pdf_annotation_screen_name : @core.PdfName = pdf_annotation_name("/Screen")

///|
let pdf_annotation_printer_mark_name : @core.PdfName = pdf_annotation_name(
  "/PrinterMark",
)

///|
let pdf_annotation_trap_net_name : @core.PdfName = pdf_annotation_name(
  "/TrapNet",
)

///|
let pdf_annotation_watermark_name : @core.PdfName = pdf_annotation_name(
  "/Watermark",
)

///|
let pdf_annotation_three_dee_name : @core.PdfName = pdf_annotation_name("/3D")

///|
let pdf_annotation_unknown_name : @core.PdfName = pdf_annotation_name(
  "/Unknown",
)
