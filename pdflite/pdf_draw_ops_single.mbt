///|
/// Convert one cpdf draw operation to flat PDF content operators.
///
/// The currently ported rendering subset covers the direct operator mappings in
/// the front of `cpdfdraw.ml`'s `ops_of_drawop`: graphics state, matrix, path,
/// colour, paint, clip, `q`/`Q` grouping, resource-backed XObjects, fontpack
/// text, and paragraph layout. Later slices will fill in tagged-content and
/// page-level rendering.
pub fn PdfDrawOp::to_content_ops(
  self : PdfDrawOp,
) -> Array[@content.PdfContentOp] raise PdfError {
  self.to_content_ops_internal(None, None, None)
}

///|
/// Convert one cpdf draw operation using resource allocation state.
pub fn PdfDrawOp::to_content_ops_with_state(
  self : PdfDrawOp,
  state : PdfDrawRenderState,
) -> Array[@content.PdfContentOp] raise PdfError {
  self.to_content_ops_internal(Some(state), None, None)
}

///|
/// Convert one cpdf draw operation using resource state and special-text data.
pub fn PdfDrawOp::to_content_ops_with_context(
  self : PdfDrawOp,
  state : PdfDrawRenderState,
  context : PdfDrawSpecialTextContext,
) -> Array[@content.PdfContentOp] raise PdfError {
  self.to_content_ops_internal(Some(state), None, Some(context))
}

///|
/// Convert one cpdf draw operation using resource state and a document for
/// indirect object allocation.
pub fn PdfDrawOp::to_content_ops_with_document(
  self : PdfDrawOp,
  state : PdfDrawRenderState,
  document : PdfDocument,
) -> Array[@content.PdfContentOp] raise PdfError {
  self.to_content_ops_internal(Some(state), Some(document), None)
}

///|
/// Convert one cpdf draw operation using document resources and special-text data.
pub fn PdfDrawOp::to_content_ops_with_document_context(
  self : PdfDrawOp,
  state : PdfDrawRenderState,
  document : PdfDocument,
  context : PdfDrawSpecialTextContext,
) -> Array[@content.PdfContentOp] raise PdfError {
  self.to_content_ops_internal(Some(state), Some(document), Some(context))
}
