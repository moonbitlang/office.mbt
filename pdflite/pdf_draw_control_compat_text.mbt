///|
/// Source-spelled cpdfdrawcontrol `addbt` over explicit draw state.
pub fn pdf_addbt(control : PdfDrawControl) -> Unit {
  control.begin_text_section()
}

///|
/// Source-spelled cpdfdrawcontrol `addet` over explicit draw state.
pub fn pdf_addet(control : PdfDrawControl) -> Unit raise PdfError {
  control.end_text_section()
}

///|
/// Source-spelled cpdfdrawcontrol `addnewpage` over explicit draw state.
pub fn pdf_addnewpage(control : PdfDrawControl) -> Unit raise PdfError {
  control.add_new_page()
}

///|
/// Source-spelled cpdfdrawcontrol `addleading` over explicit draw state.
pub fn pdf_addleading(
  control : PdfDrawControl,
  leading : Double,
) -> Unit raise PdfError {
  control.add_leading(leading)
}

///|
/// Source-spelled cpdfdrawcontrol `addcharspace` over explicit draw state.
pub fn pdf_addcharspace(
  control : PdfDrawControl,
  spacing : Double,
) -> Unit raise PdfError {
  control.add_char_space(spacing)
}

///|
/// Source-spelled cpdfdrawcontrol `addwordspace` over explicit draw state.
pub fn pdf_addwordspace(
  control : PdfDrawControl,
  spacing : Double,
) -> Unit raise PdfError {
  control.add_word_space(spacing)
}

///|
/// Source-spelled cpdfdrawcontrol `addtextscale` over explicit draw state.
pub fn pdf_addtextscale(
  control : PdfDrawControl,
  scale : Double,
) -> Unit raise PdfError {
  control.add_text_scale(scale)
}

///|
/// Source-spelled cpdfdrawcontrol `addrendermode` over explicit draw state.
pub fn pdf_addrendermode(
  control : PdfDrawControl,
  mode : Int,
) -> Unit raise PdfError {
  control.add_render_mode(mode)
}

///|
/// Source-spelled cpdfdrawcontrol `addrise` over explicit draw state.
pub fn pdf_addrise(
  control : PdfDrawControl,
  rise : Double,
) -> Unit raise PdfError {
  control.add_rise(rise)
}

///|
/// Source-spelled cpdfdrawcontrol `addnewline` over explicit draw state.
pub fn pdf_addnewline(control : PdfDrawControl) -> Unit raise PdfError {
  control.add_newline()
}

///|
/// Source-spelled cpdfdrawcontrol `getfontname` over explicit draw state.
pub fn pdf_getfontname(control : PdfDrawControl) -> String {
  control.font_name()
}

///|
/// Source-spelled cpdfdrawcontrol `setfontname` over explicit draw state.
pub fn pdf_setfontname(control : PdfDrawControl, font_name : String) -> Unit {
  control.set_font_name(font_name)
}

///|
/// Source-spelled cpdfdrawcontrol `getfontsize` over explicit draw state.
pub fn pdf_getfontsize(control : PdfDrawControl) -> Double {
  control.font_size()
}

///|
/// Source-spelled cpdfdrawcontrol `setfontsize` over explicit draw state.
pub fn pdf_setfontsize(control : PdfDrawControl, font_size : Double) -> Unit {
  control.set_font_size(font_size)
}

///|
/// Source-spelled cpdfdrawcontrol `getindent` over explicit draw state.
pub fn pdf_getindent(control : PdfDrawControl) -> Double? {
  control.paragraph_indent()
}

///|
/// Source-spelled cpdfdrawcontrol `add_default_fontpack` over explicit state.
pub fn pdf_add_default_fontpack(
  control : PdfDrawControl,
  font_name : String,
) -> Unit raise PdfError {
  control.add_default_fontpack(font_name)
}

///|
/// Source-spelled cpdfdrawcontrol `addtext` over explicit draw state.
pub fn pdf_addtext(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.add_text(text)
}

///|
/// Source-spelled cpdfdrawcontrol `addspecialtext` over explicit draw state.
pub fn pdf_addspecialtext(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.add_special_text(text)
}

///|
/// Source-spelled cpdfdrawcontrol `addpara` over explicit draw state.
pub fn pdf_addpara(
  control : PdfDrawControl,
  document : PdfDocument,
  spec : String,
) -> Unit raise PdfError {
  control.add_para(document, spec)
}

///|
/// Source-spelled cpdfdrawcontrol `addparas` over explicit draw state.
pub fn pdf_addparas(
  control : PdfDrawControl,
  document : PdfDocument,
  spec : String,
) -> Unit raise PdfError {
  control.add_paras(document, spec)
}
