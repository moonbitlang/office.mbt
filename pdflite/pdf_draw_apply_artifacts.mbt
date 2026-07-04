///|
fn pdf_draw_fixup_manual_artifacts(
  ops : ArrayView[@content.PdfContentOp],
) -> Array[@content.PdfContentOp] {
  let output : Array[@content.PdfContentOp] = Array::new(capacity=ops.length())
  for op in ops {
    match op {
      Op_BMC(name) if name == pdf_draw_begin_artifact() =>
        output.push(@content.pdf_content_begin_artifact())
      Op_BMC(name) if name == pdf_draw_end_artifact() =>
        output.push(@content.pdf_content_end_artifact())
      _ => output.push(op)
    }
  }
  output
}

///|
fn pdf_draw_artifact_ops(
  ops : ArrayView[@content.PdfContentOp],
  add_artifacts : Bool,
) -> Array[@content.PdfContentOp] {
  if add_artifacts {
    @content.pdf_content_add_artifacts(ops)
  } else {
    pdf_draw_fixup_manual_artifacts(ops)
  }
}
