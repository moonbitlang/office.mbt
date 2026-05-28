///|
fn pdf_draw_content_unsupported(
  op : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  raise SoftError("Cpdfdraw: unsupported draw operation " + op.debug_name())
}

///|
fn pdf_draw_form_xobject_stream(
  bbox : (Double, Double, Double, Double),
  resources : PdfObject,
  ops : ArrayView[PdfContentOp],
) -> PdfObject raise PdfError {
  let data = pdf_content_bytes_of_ops(ops)
  let (a, b, c, d) = bbox
  pdf_stream(
    PdfDictionary([
      (pdf_draw_length_key(), PdfInteger(data.length())),
      (pdf_draw_subtype_key(), PdfNameObject(pdf_draw_form_key())),
      (pdf_draw_resources_key(), resources),
      (
        pdf_draw_bbox_key(),
        PdfArray([PdfReal(a), PdfReal(b), PdfReal(c), PdfReal(d)]),
      ),
    ]),
    StreamGot(data),
  )
}

///|
fn PdfDrawRenderState::tag_ops(
  self : PdfDrawRenderState,
  tag : String,
) -> Array[PdfContentOp] {
  let mcid = self.fresh_mcid()
  if self.structure_tree_enabled {
    self.structure_data.push(
      PdfDrawStructureMCID("/" + tag, self.structure_page_number, mcid),
    )
  }
  [
    Op_BDC(
      pdf_draw_name("/" + tag),
      PdfDictionary([(pdf_draw_mcid_key(), PdfInteger(mcid))]),
    ),
  ]
}

///|
fn PdfDrawRenderState::structure_tagged_ops(
  self : PdfDrawRenderState,
  tag : String,
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let mcid = self.fresh_mcid()
  self.structure_data.push(
    PdfDrawStructureMCID(tag, self.structure_page_number, mcid),
  )
  let output : Array[PdfContentOp] = [
    Op_BDC(
      pdf_draw_name(tag),
      PdfDictionary([(pdf_draw_mcid_key(), PdfInteger(mcid))]),
    ),
  ]
  for op in ops {
    output.push(op)
  }
  output.push(Op_EMC)
  output
}

///|
fn PdfDrawSpecialTextContext::process(
  self : PdfDrawSpecialTextContext,
  text : String,
) -> String {
  pdf_addtext_process_text_with_time(
    self.time,
    text,
    pdf_addtext_replacement_pairs(self.replacement_values),
  )
}
