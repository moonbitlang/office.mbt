///|
/// Source-spelled cpdfdrawcontrol `setthickness` over explicit draw state.
pub fn pdf_setthickness(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.set_line_thickness(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setcap` over explicit draw state.
pub fn pdf_setcap(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.set_line_cap(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setjoin` over explicit draw state.
pub fn pdf_setjoin(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.set_line_join(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setmiter` over explicit draw state.
pub fn pdf_setmiter(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.set_miter_limit(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setdash` over explicit draw state.
pub fn pdf_setdash(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.set_dash_pattern(text)
}

///|
/// Source-spelled cpdfdrawcontrol `push` over explicit draw state.
pub fn pdf_push(control : PdfDrawControl) -> Unit {
  control.push_group()
}

///|
/// Source-spelled cpdfdrawcontrol `pop` over explicit draw state.
pub fn pdf_pop(control : PdfDrawControl) -> Unit raise @core.PdfError {
  control.pop_group()
}

///|
/// Source-spelled cpdfdrawcontrol `setmatrix` over explicit draw state.
pub fn pdf_setmatrix(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.set_matrix(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setmtranslate` over explicit draw state.
pub fn pdf_setmtranslate(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.matrix_translate(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setmrotate` over explicit draw state.
pub fn pdf_setmrotate(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.matrix_rotate(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setmscale` over explicit draw state.
pub fn pdf_setmscale(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.matrix_scale(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setmshearx` over explicit draw state.
pub fn pdf_setmshearx(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.matrix_shear_x(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setmsheary` over explicit draw state.
pub fn pdf_setmsheary(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.matrix_shear_y(text)
}
