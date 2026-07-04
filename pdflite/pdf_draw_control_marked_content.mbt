///|
/// Append a marked-content tag operation to the current frame.
pub fn PdfDrawControl::add_tag(
  self : PdfDrawControl,
  tag : String,
) -> Unit raise @core.PdfError {
  self.add_op(PdfDrawTag(tag))
}

///|
/// Append a structure-tag begin operation to the current frame.
pub fn PdfDrawControl::add_structure_tag(
  self : PdfDrawControl,
  tag : String,
) -> Unit raise @core.PdfError {
  self.add_op(PdfDrawSTag(tag))
}

///|
/// Append a marked-content tag end operation to the current frame.
pub fn PdfDrawControl::end_tag(
  self : PdfDrawControl,
) -> Unit raise @core.PdfError {
  self.add_op(PdfDrawEndTag)
}

///|
/// Append a structure-tag end operation to the current frame.
pub fn PdfDrawControl::end_structure_tag(
  self : PdfDrawControl,
) -> Unit raise @core.PdfError {
  self.add_op(PdfDrawEndSTag)
}

///|
/// Append an automatic-structure-tag toggle operation.
pub fn PdfDrawControl::set_auto_tag(
  self : PdfDrawControl,
  enabled : Bool,
) -> Unit raise @core.PdfError {
  self.add_op(PdfDrawAutoTag(enabled))
}

///|
/// Append an artifact begin operation for structured PDF output.
pub fn PdfDrawControl::begin_artifact(
  self : PdfDrawControl,
) -> Unit raise @core.PdfError {
  self.add_op(PdfDrawBeginArtifact)
}

///|
/// Append an artifact end operation for structured PDF output.
pub fn PdfDrawControl::end_artifact(
  self : PdfDrawControl,
) -> Unit raise @core.PdfError {
  self.add_op(PdfDrawEndArtifact)
}

///|
/// Append a structure namespace declaration.
pub fn PdfDrawControl::add_namespace(
  self : PdfDrawControl,
  namespace_name : String,
) -> Unit raise @core.PdfError {
  self.add_op(PdfDrawNamespace(namespace_name))
}

///|
/// Append structure element metadata for `key`.
pub fn PdfDrawControl::add_element_info(
  self : PdfDrawControl,
  key : String,
  value : @syntax.PdfObject,
) -> Unit raise @core.PdfError {
  self.add_op(PdfDrawEltInfo(key, value))
}

///|
/// Append the end marker for structure element metadata keyed by `key`.
pub fn PdfDrawControl::end_element_info(
  self : PdfDrawControl,
  key : String,
) -> Unit raise @core.PdfError {
  self.add_op(PdfDrawEndEltInfo(key))
}

///|
/// Set the role-map body used by structured draw output.
///
/// The value follows cpdf's `-rolemap` convention: pass entries such as
/// `"/H1 /H /Aside /Div"` without the surrounding `<< >>`.
pub fn PdfDrawControl::set_role_map(
  self : PdfDrawControl,
  role_map : String,
) -> Unit {
  self.role_map = role_map
}

///|
/// Return the role-map body configured on this draw-control state.
pub fn PdfDrawControl::role_map(self : PdfDrawControl) -> String {
  self.role_map
}

///|
/// Enable or disable automatic artifact wrapping for structured draw output.
pub fn PdfDrawControl::set_auto_artifacts(
  self : PdfDrawControl,
  enabled : Bool,
) -> Unit {
  self.auto_artifacts = enabled
}

///|
/// Return whether automatic artifact wrapping is enabled on this state.
pub fn PdfDrawControl::auto_artifacts(self : PdfDrawControl) -> Bool {
  self.auto_artifacts
}
