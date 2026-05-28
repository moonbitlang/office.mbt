///|
/// Source-spelled cpdfdrawcontrol `xobjbbox` over explicit draw state.
pub fn pdf_xobjbbox(
  control : PdfDrawControl,
  document : PdfDocument,
  text : String,
) -> Unit raise PdfError {
  control.set_xobject_bbox_from_string(document, text)
}

///|
/// Source-spelled cpdfdrawcontrol `startxobj` over explicit draw state.
pub fn pdf_startxobj(control : PdfDrawControl, name : String) -> Unit {
  control.start_xobject(name)
}

///|
/// Source-spelled cpdfdrawcontrol `endxobj` over explicit draw state.
pub fn pdf_endxobj(control : PdfDrawControl) -> Unit raise PdfError {
  control.end_xobject()
}

///|
/// Source-spelled cpdfdrawcontrol `usexobj` over explicit draw state.
pub fn pdf_usexobj(
  control : PdfDrawControl,
  name : String,
) -> Unit raise PdfError {
  control.use_xobject(name)
}

///|
/// Source-spelled cpdfdrawcontrol `addimage` over explicit draw state.
pub fn pdf_addimage(
  control : PdfDrawControl,
  name : String,
) -> Unit raise PdfError {
  control.add_image(name)
}

///|
/// Source-spelled cpdfdrawcontrol `addopacity` over explicit draw state.
pub fn pdf_addopacity(
  control : PdfDrawControl,
  opacity : Double,
) -> Unit raise PdfError {
  control.add_opacity(opacity)
}

///|
/// Source-spelled cpdfdrawcontrol `addsopacity` over explicit draw state.
pub fn pdf_addsopacity(
  control : PdfDrawControl,
  opacity : Double,
) -> Unit raise PdfError {
  control.add_stroke_opacity(opacity)
}
