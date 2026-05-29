///|
fn pdf_draw_contains_special_text(op : PdfDrawOp) -> Bool {
  match op {
    PdfDrawSpecialText(_) => true
    PdfDrawQq(ops)
    | PdfDrawTextSection(ops)
    | PdfDrawFormXObject(_, _, _, _, _, ops) =>
      pdf_drawops_contain_special_text(ops)
    _ => false
  }
}

///|
fn pdf_drawops_contain_special_text(ops : ArrayView[PdfDrawOp]) -> Bool {
  for op in ops {
    if pdf_draw_contains_special_text(op) {
      return true
    }
  }
  false
}

///|
fn pdf_draw_single_page_ops(
  document : PdfDocument,
  state : PdfDrawRenderState,
  drawops : ArrayView[PdfDrawOp],
  page_number : Int,
  filename : String,
  bates : Int,
  bates_pad : Int?,
  time : PdfStrftimeTime?,
) -> Array[PdfContentOp] raise PdfError {
  let context = document.draw_special_text_context(
    page_number,
    filename~,
    bates~,
    bates_pad~,
    time~,
  )
  pdf_drawops_to_content_ops_with_document_context(
    state, document, context, drawops,
  )
}

///|
fn PdfDocument::pdf_draw_render_page_ops(
  self : PdfDocument,
  state : PdfDrawRenderState,
  selected_pages : @core.PdfNumberSet,
  drawops : ArrayView[PdfDrawOp],
  filename : String,
  bates : Int,
  bates_pad : Int?,
  time : PdfStrftimeTime?,
) -> Array[Array[PdfContentOp]] raise PdfError {
  let pages = self.pages_of_pagetree()
  let per_page : Array[Array[PdfContentOp]] = [ for _ in pages => [] ]
  if pdf_drawops_contain_special_text(drawops) {
    for index in 0..<pages.length() {
      let page_number = index + 1
      if selected_pages.contains(page_number) {
        state.set_structure_page_number(page_number)
        per_page[index] = pdf_draw_single_page_ops(
          self, state, drawops, page_number, filename, bates, bates_pad, time,
        )
      }
    }
  } else {
    let content_ops = pdf_drawops_to_content_ops_with_document(
      state, self, drawops,
    )
    for index in 0..<pages.length() {
      let page_number = index + 1
      if selected_pages.contains(page_number) {
        per_page[index] = content_ops
      }
    }
  }
  per_page
}
