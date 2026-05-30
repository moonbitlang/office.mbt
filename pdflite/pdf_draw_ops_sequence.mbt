///|
fn pdf_drawops_to_content_ops_internal(
  state : PdfDrawRenderState?,
  document : PdfDocument?,
  context : PdfDrawSpecialTextContext?,
  ops : ArrayView[PdfDrawOp],
) -> Array[@content.PdfContentOp] raise PdfError {
  let output : Array[@content.PdfContentOp] = Array::new(capacity=ops.length())
  for op in ops {
    for content_op in op.to_content_ops_internal(state, document, context) {
      output.push(content_op)
    }
  }
  output
}

///|
/// Convert a sequence of cpdf draw operations to flat PDF content operators.
pub fn pdf_drawops_to_content_ops(
  ops : ArrayView[PdfDrawOp],
) -> Array[@content.PdfContentOp] raise PdfError {
  pdf_drawops_to_content_ops_internal(None, None, None, ops)
}

///|
/// Compatibility wrapper for `PdfDrawOp::to_content_ops`.
pub fn pdf_drawop_to_content_ops(
  op : PdfDrawOp,
) -> Array[@content.PdfContentOp] raise PdfError {
  op.to_content_ops()
}

///|
/// Convert a sequence of cpdf draw operations using resource allocation state.
pub fn pdf_drawops_to_content_ops_with_state(
  state : PdfDrawRenderState,
  ops : ArrayView[PdfDrawOp],
) -> Array[@content.PdfContentOp] raise PdfError {
  pdf_drawops_to_content_ops_internal(Some(state), None, None, ops)
}

///|
/// Convert a sequence of cpdf draw operations using state and special-text data.
pub fn pdf_drawops_to_content_ops_with_context(
  state : PdfDrawRenderState,
  context : PdfDrawSpecialTextContext,
  ops : ArrayView[PdfDrawOp],
) -> Array[@content.PdfContentOp] raise PdfError {
  pdf_drawops_to_content_ops_internal(Some(state), None, Some(context), ops)
}

///|
/// Compatibility wrapper for `PdfDrawOp::to_content_ops_with_state`.
pub fn pdf_drawop_to_content_ops_with_state(
  state : PdfDrawRenderState,
  op : PdfDrawOp,
) -> Array[@content.PdfContentOp] raise PdfError {
  op.to_content_ops_with_state(state)
}

///|
/// Compatibility wrapper for `PdfDrawOp::to_content_ops_with_context`.
pub fn pdf_drawop_to_content_ops_with_context(
  state : PdfDrawRenderState,
  context : PdfDrawSpecialTextContext,
  op : PdfDrawOp,
) -> Array[@content.PdfContentOp] raise PdfError {
  op.to_content_ops_with_context(state, context)
}

///|
/// Convert a sequence of cpdf draw operations using resource state and a
/// document for indirect object allocation.
pub fn pdf_drawops_to_content_ops_with_document(
  state : PdfDrawRenderState,
  document : PdfDocument,
  ops : ArrayView[PdfDrawOp],
) -> Array[@content.PdfContentOp] raise PdfError {
  pdf_drawops_to_content_ops_internal(Some(state), Some(document), None, ops)
}

///|
/// Convert a sequence of cpdf draw operations using document resources and
/// special-text data.
pub fn pdf_drawops_to_content_ops_with_document_context(
  state : PdfDrawRenderState,
  document : PdfDocument,
  context : PdfDrawSpecialTextContext,
  ops : ArrayView[PdfDrawOp],
) -> Array[@content.PdfContentOp] raise PdfError {
  pdf_drawops_to_content_ops_internal(
    Some(state),
    Some(document),
    Some(context),
    ops,
  )
}

///|
/// Compatibility wrapper for `PdfDrawOp::to_content_ops_with_document`.
pub fn pdf_drawop_to_content_ops_with_document(
  state : PdfDrawRenderState,
  document : PdfDocument,
  op : PdfDrawOp,
) -> Array[@content.PdfContentOp] raise PdfError {
  op.to_content_ops_with_document(state, document)
}

///|
/// Compatibility wrapper for `PdfDrawOp::to_content_ops_with_document_context`.
pub fn pdf_drawop_to_content_ops_with_document_context(
  state : PdfDrawRenderState,
  document : PdfDocument,
  context : PdfDrawSpecialTextContext,
  op : PdfDrawOp,
) -> Array[@content.PdfContentOp] raise PdfError {
  op.to_content_ops_with_document_context(state, document, context)
}
