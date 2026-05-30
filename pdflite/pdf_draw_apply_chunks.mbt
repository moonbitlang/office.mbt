///|
fn pdf_draw_double_trailing_new_page(
  drawops : ArrayView[PdfDrawOp],
) -> Array[PdfDrawOp] {
  let output = [ for op in drawops => op ]
  if output.length() > 0 && output[output.length() - 1] == PdfDrawNewPage {
    output.push(PdfDrawNewPage)
  }
  output
}

///|
fn pdf_draw_split_on_new_page(
  drawops : ArrayView[PdfDrawOp],
) -> Array[Array[PdfDrawOp]] {
  let chunks : Array[Array[PdfDrawOp]] = [[]]
  for op in drawops {
    if op == PdfDrawNewPage {
      chunks.push([])
    } else {
      chunks[chunks.length() - 1].push(op)
    }
  }
  if chunks.length() > 1 && chunks[chunks.length() - 1].length() == 0 {
    ignore(chunks.pop())
  }
  chunks
}

///|
fn PdfDocument::pdf_draw_has_fresh_structure_tree(self : PdfDocument) -> Bool {
  match
    self.lookup_chain(self.trailer_dict(), [
      pdf_structure_root_key(),
      pdf_draw_struct_tree_root_key(),
    ]) {
    Some(PdfDictionary([(key, PdfNameObject(value))])) =>
      key == pdf_draw_type_key() && value == pdf_draw_struct_tree_root_key()
    _ => false
  }
}

///|
fn PdfDocument::pdf_draw_apply_chunk(
  self : PdfDocument,
  state : PdfDrawRenderState,
  page_numbers : ArrayView[Int],
  drawops : ArrayView[PdfDrawOp],
  struct_tree : Bool,
  fast : Bool,
  underneath : Bool,
  filename : String,
  bates : Int,
  bates_pad : Int?,
  time : @date.PdfStrftimeTime?,
  add_artifacts : Bool,
) -> PdfDocument raise PdfError {
  state.set_structure_tree_enabled(struct_tree)
  let selected_pages = @core.pdf_number_set(page_numbers)
  state.set_minimum_resource_number(
    self.pdf_draw_minimum_resource_number(selected_pages),
  )
  let per_page = self.pdf_draw_render_page_ops(
    state, selected_pages, drawops, filename, bates, bates_pad, time,
  )
  let draw_resources = state.resources()
  let pages = self.pages_of_pagetree()
  let rewritten : Array[PdfPage] = Array::new(capacity=pages.length())
  for index in 0..<pages.length() {
    let page_number = index + 1
    let page = pages[index]
    if selected_pages.contains(page_number) {
      let content_ops = pdf_draw_artifact_ops(
        per_page[index],
        add_artifacts || struct_tree,
      )
      let page = {
        ..page,
        resources: self.combine_pdf_resources(page.resources, draw_resources),
      }
      rewritten.push(
        if underneath {
          self.prepend_operators(page, content_ops, fast~)
        } else {
          self.postpend_operators(page, content_ops, fast~)
        },
      )
    } else {
      rewritten.push(page)
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
fn pdf_draw_next_range(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> (PdfDocument, Array[Int]) raise PdfError {
  let end_page = document.endpage()
  match page_numbers {
    [page_number] if end_page > page_number => (document, [page_number + 1])
    _ => (document.pad_after([end_page]), [end_page + 1])
  }
}
