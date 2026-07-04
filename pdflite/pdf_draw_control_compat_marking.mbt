///|
/// Source-spelled cpdfdrawcontrol `setstroke` over explicit draw state.
pub fn pdf_setstroke(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.set_stroke(text)
}

///|
/// Source-spelled cpdfdrawcontrol `setfill` over explicit draw state.
pub fn pdf_setfill(
  control : PdfDrawControl,
  text : String,
) -> Unit raise @core.PdfError {
  control.set_fill(text)
}

///|
/// Source-spelled cpdfdrawcontrol `addtag` over explicit draw state.
pub fn pdf_addtag(
  control : PdfDrawControl,
  tag : String,
) -> Unit raise @core.PdfError {
  control.add_tag(tag)
}

///|
/// Source-spelled cpdfdrawcontrol `addstag` over explicit draw state.
pub fn pdf_addstag(
  control : PdfDrawControl,
  tag : String,
) -> Unit raise @core.PdfError {
  control.add_structure_tag(tag)
}

///|
/// Source-spelled cpdfdrawcontrol `endtag` over explicit draw state.
pub fn pdf_endtag(control : PdfDrawControl) -> Unit raise @core.PdfError {
  control.end_tag()
}

///|
/// Source-spelled cpdfdrawcontrol `endstag` over explicit draw state.
pub fn pdf_endstag(control : PdfDrawControl) -> Unit raise @core.PdfError {
  control.end_structure_tag()
}

///|
/// Source-spelled cpdfdrawcontrol `autotags` over explicit draw state.
pub fn pdf_autotags(
  control : PdfDrawControl,
  enabled : Bool,
) -> Unit raise @core.PdfError {
  control.set_auto_tag(enabled)
}

///|
/// Source-spelled cpdfdrawcontrol `eltinfo` over explicit draw state.
pub fn pdf_eltinfo(
  control : PdfDrawControl,
  key : String,
  value : @syntax.PdfObject,
) -> Unit raise @core.PdfError {
  control.add_element_info(key, value)
}

///|
/// Source-spelled cpdfdrawcontrol `endeltinfo` over explicit draw state.
pub fn pdf_endeltinfo(
  control : PdfDrawControl,
  key : String,
) -> Unit raise @core.PdfError {
  control.end_element_info(key)
}

///|
/// Source-spelled cpdfdrawcontrol `addnamespace` over explicit draw state.
pub fn pdf_addnamespace(
  control : PdfDrawControl,
  namespace_name : String,
) -> Unit raise @core.PdfError {
  control.add_namespace(namespace_name)
}

///|
/// Source-spelled cpdfdrawcontrol `setrolemap` over explicit draw state.
pub fn pdf_setrolemap(control : PdfDrawControl, role_map : String) -> Unit {
  control.set_role_map(role_map)
}

///|
/// Source-spelled cpdfdrawcontrol `artifact` over explicit draw state.
pub fn pdf_artifact(control : PdfDrawControl) -> Unit raise @core.PdfError {
  control.begin_artifact()
}

///|
/// Source-spelled cpdfdrawcontrol `endartifact` over explicit draw state.
pub fn pdf_endartifact(control : PdfDrawControl) -> Unit raise @core.PdfError {
  control.end_artifact()
}

///|
/// Source-spelled cpdfdrawcontrol `autoartifacts` over explicit draw state.
pub fn pdf_autoartifacts(control : PdfDrawControl, enabled : Bool) -> Unit {
  control.set_auto_artifacts(enabled)
}
