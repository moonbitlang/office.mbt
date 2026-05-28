///|
/// Compatibility wrapper for `pdf_draw_control_new`.
pub fn pdf_draw_control() -> PdfDrawControl {
  pdf_draw_control_new()
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `addrect`.
pub fn pdf_addrect(
  control : PdfDrawControl,
  document : PdfDocument,
  text : String,
) -> Unit raise PdfError {
  control.add_rect(document, text)
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `addto`.
pub fn pdf_addto(
  control : PdfDrawControl,
  document : PdfDocument,
  text : String,
) -> Unit raise PdfError {
  control.add_to(document, text)
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `addline`.
pub fn pdf_addline(
  control : PdfDrawControl,
  document : PdfDocument,
  text : String,
) -> Unit raise PdfError {
  control.add_line(document, text)
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `addbezier`.
pub fn pdf_addbezier(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.add_bezier(text)
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `addbezier23`.
pub fn pdf_addbezier23(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.add_bezier23(text)
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `addbezier13`.
pub fn pdf_addbezier13(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.add_bezier13(text)
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `addcircle`.
pub fn pdf_addcircle(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.add_circle(text)
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `stroke`.
pub fn pdf_stroke(control : PdfDrawControl) -> Unit raise PdfError {
  control.stroke()
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `fill`.
pub fn pdf_fill(control : PdfDrawControl) -> Unit raise PdfError {
  control.fill()
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `fillevenodd`.
pub fn pdf_fillevenodd(control : PdfDrawControl) -> Unit raise PdfError {
  control.fill_even_odd()
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `strokefill`.
pub fn pdf_strokefill(control : PdfDrawControl) -> Unit raise PdfError {
  control.stroke_fill()
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's
/// `strokefillevenodd`.
pub fn pdf_strokefillevenodd(control : PdfDrawControl) -> Unit raise PdfError {
  control.stroke_fill_even_odd()
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `clip`.
pub fn pdf_clip(control : PdfDrawControl) -> Unit raise PdfError {
  control.clip()
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `clipevenodd`.
pub fn pdf_clipevenodd(control : PdfDrawControl) -> Unit raise PdfError {
  control.clip_even_odd()
}

///|
/// Source-spelled compatibility wrapper for cpdfdrawcontrol's `closepath`.
pub fn pdf_closepath(control : PdfDrawControl) -> Unit raise PdfError {
  control.close_path()
}

///|
/// Source-spelled cpdfdrawcontrol `setstroke` over explicit draw state.
pub fn pdf_setstroke(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.set_stroke(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setfill` over explicit draw state.
pub fn pdf_setfill(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.set_fill(text)
}

///|
/// Source-spelled cpdfdrawcontrol `addtag` over explicit draw state.
pub fn pdf_addtag(
  control : PdfDrawControl,
  tag : String,
) -> Unit raise PdfError {
  control.add_tag(tag)
}

///|
/// Source-spelled cpdfdrawcontrol `addstag` over explicit draw state.
pub fn pdf_addstag(
  control : PdfDrawControl,
  tag : String,
) -> Unit raise PdfError {
  control.add_structure_tag(tag)
}

///|
/// Source-spelled cpdfdrawcontrol `endtag` over explicit draw state.
pub fn pdf_endtag(control : PdfDrawControl) -> Unit raise PdfError {
  control.end_tag()
}

///|
/// Source-spelled cpdfdrawcontrol `endstag` over explicit draw state.
pub fn pdf_endstag(control : PdfDrawControl) -> Unit raise PdfError {
  control.end_structure_tag()
}

///|
/// Source-spelled cpdfdrawcontrol `autotags` over explicit draw state.
pub fn pdf_autotags(
  control : PdfDrawControl,
  enabled : Bool,
) -> Unit raise PdfError {
  control.set_auto_tag(enabled)
}

///|
/// Source-spelled cpdfdrawcontrol `eltinfo` over explicit draw state.
pub fn pdf_eltinfo(
  control : PdfDrawControl,
  key : String,
  value : PdfObject,
) -> Unit raise PdfError {
  control.add_element_info(key, value)
}

///|
/// Source-spelled cpdfdrawcontrol `endeltinfo` over explicit draw state.
pub fn pdf_endeltinfo(
  control : PdfDrawControl,
  key : String,
) -> Unit raise PdfError {
  control.end_element_info(key)
}

///|
/// Source-spelled cpdfdrawcontrol `addnamespace` over explicit draw state.
pub fn pdf_addnamespace(
  control : PdfDrawControl,
  namespace_name : String,
) -> Unit raise PdfError {
  control.add_namespace(namespace_name)
}

///|
/// Source-spelled cpdfdrawcontrol `setrolemap` over explicit draw state.
pub fn pdf_setrolemap(control : PdfDrawControl, role_map : String) -> Unit {
  control.set_role_map(role_map)
}

///|
/// Source-spelled cpdfdrawcontrol `artifact` over explicit draw state.
pub fn pdf_artifact(control : PdfDrawControl) -> Unit raise PdfError {
  control.begin_artifact()
}

///|
/// Source-spelled cpdfdrawcontrol `endartifact` over explicit draw state.
pub fn pdf_endartifact(control : PdfDrawControl) -> Unit raise PdfError {
  control.end_artifact()
}

///|
/// Source-spelled cpdfdrawcontrol `autoartifacts` over explicit draw state.
pub fn pdf_autoartifacts(control : PdfDrawControl, enabled : Bool) -> Unit {
  control.set_auto_artifacts(enabled)
}

///|
/// Source-spelled cpdfdrawcontrol `setthickness` over explicit draw state.
pub fn pdf_setthickness(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.set_line_thickness(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setcap` over explicit draw state.
pub fn pdf_setcap(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.set_line_cap(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setjoin` over explicit draw state.
pub fn pdf_setjoin(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.set_line_join(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setmiter` over explicit draw state.
pub fn pdf_setmiter(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.set_miter_limit(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setdash` over explicit draw state.
pub fn pdf_setdash(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.set_dash_pattern(text)
}

///|
/// Source-spelled cpdfdrawcontrol `push` over explicit draw state.
pub fn pdf_push(control : PdfDrawControl) -> Unit {
  control.push_group()
}

///|
/// Source-spelled cpdfdrawcontrol `pop` over explicit draw state.
pub fn pdf_pop(control : PdfDrawControl) -> Unit raise PdfError {
  control.pop_group()
}

///|
/// Source-spelled cpdfdrawcontrol `setmatrix` over explicit draw state.
pub fn pdf_setmatrix(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.set_matrix(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setmtranslate` over explicit draw state.
pub fn pdf_setmtranslate(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.matrix_translate(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setmrotate` over explicit draw state.
pub fn pdf_setmrotate(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.matrix_rotate(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setmscale` over explicit draw state.
pub fn pdf_setmscale(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.matrix_scale(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setmshearx` over explicit draw state.
pub fn pdf_setmshearx(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.matrix_shear_x(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setmsheary` over explicit draw state.
pub fn pdf_setmsheary(
  control : PdfDrawControl,
  text : String,
) -> Unit raise PdfError {
  control.matrix_shear_y(text)
}

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
