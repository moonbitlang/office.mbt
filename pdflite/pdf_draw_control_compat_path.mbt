///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `addrect`.
pub fn pdf_addrect(
  control : PdfDrawControl,
  document : PdfDocument,
  text : String,
) -> Unit raise @core.PdfError {
  control.add_rect(document, text)
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `addto`.
pub fn pdf_addto(
  control : PdfDrawControl,
  document : PdfDocument,
  text : String,
) -> Unit raise @core.PdfError {
  control.add_to(document, text)
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `addline`.
pub fn pdf_addline(
  control : PdfDrawControl,
  document : PdfDocument,
  text : String,
) -> Unit raise @core.PdfError {
  control.add_line(document, text)
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `addbezier`.
pub fn pdf_addbezier(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.add_bezier(text)
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `addbezier23`.
pub fn pdf_addbezier23(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.add_bezier23(text)
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `addbezier13`.
pub fn pdf_addbezier13(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.add_bezier13(text)
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `addcircle`.
pub fn pdf_addcircle(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.add_circle(text)
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `stroke`.
pub fn pdf_stroke(control : PdfDrawControl) -> Unit raise @core.PdfError {
  control.stroke()
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `fill`.
pub fn pdf_fill(control : PdfDrawControl) -> Unit raise @core.PdfError {
  control.fill()
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `fillevenodd`.
pub fn pdf_fillevenodd(control : PdfDrawControl) -> Unit raise @core.PdfError {
  control.fill_even_odd()
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `strokefill`.
pub fn pdf_strokefill(control : PdfDrawControl) -> Unit raise @core.PdfError {
  control.stroke_fill()
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's
/// `strokefillevenodd`.
pub fn pdf_strokefillevenodd(
  control : PdfDrawControl,
) -> Unit raise @core.PdfError {
  control.stroke_fill_even_odd()
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `clip`.
pub fn pdf_clip(control : PdfDrawControl) -> Unit raise @core.PdfError {
  control.clip()
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `clipevenodd`.
pub fn pdf_clipevenodd(control : PdfDrawControl) -> Unit raise @core.PdfError {
  control.clip_even_odd()
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `closepath`.
pub fn pdf_closepath(control : PdfDrawControl) -> Unit raise @core.PdfError {
  control.close_path()
}
