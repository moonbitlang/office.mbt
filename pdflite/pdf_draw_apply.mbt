///|
fn pdf_draw_resource_name_number(name : PdfName) -> Int? {
  let bytes = name.bytes()
  let mut start = bytes.length()
  while start > 0 {
    let byte = bytes[start - 1].to_int()
    if byte >= 48 && byte <= 57 {
      start -= 1
    } else {
      break
    }
  }
  if start == bytes.length() {
    None
  } else {
    let mut value = 0
    for index in start..<bytes.length() {
      value = value * 10 + bytes[index].to_int() - 48
    }
    Some(value)
  }
}

///|
fn PdfDocument::pdf_draw_page_resource_numbers(
  self : PdfDocument,
  resources : PdfObject,
) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=3)
  for
    key in [
      pdf_draw_xobject_key(),
      pdf_draw_extgstate_key(),
      pdf_draw_font_key(),
    ] {
    match self.lookup_direct(key, resources) {
      Some(PdfDictionary(entries)) =>
        for entry in entries {
          match pdf_draw_resource_name_number(entry.0) {
            Some(number) => output.push(number)
            None => ()
          }
        }
      _ => ()
    }
  }
  output
}

///|
fn PdfDocument::pdf_draw_minimum_resource_number(
  self : PdfDocument,
  selected_pages : @number_set.PdfNumberSet,
) -> Int raise PdfError {
  let pages = self.pages_of_pagetree()
  let mut maximum = -1
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      for number in self.pdf_draw_page_resource_numbers(pages[index].resources) {
        if number > maximum {
          maximum = number
        }
      }
    }
  }
  if maximum < 0 {
    0
  } else {
    maximum + 1
  }
}

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
fn pdf_draw_fixup_manual_artifacts(
  ops : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = Array::new(capacity=ops.length())
  for op in ops {
    match op {
      Op_BMC(name) if name == pdf_draw_begin_artifact() =>
        output.push(pdf_content_begin_artifact())
      Op_BMC(name) if name == pdf_draw_end_artifact() =>
        output.push(pdf_content_end_artifact())
      _ => output.push(op)
    }
  }
  output
}

///|
fn pdf_draw_artifact_ops(
  ops : ArrayView[PdfContentOp],
  add_artifacts : Bool,
) -> Array[PdfContentOp] {
  if add_artifacts {
    pdf_content_add_artifacts(ops)
  } else {
    pdf_draw_fixup_manual_artifacts(ops)
  }
}

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
  selected_pages : @number_set.PdfNumberSet,
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
  time : PdfStrftimeTime?,
  add_artifacts : Bool,
) -> PdfDocument raise PdfError {
  state.set_structure_tree_enabled(struct_tree)
  let selected_pages = @number_set.pdf_number_set(page_numbers)
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

///|
/// Draw cpdf draw operations on selected pages.
///
/// This ports the page orchestration from `cpdfdraw.ml`: draw operations are
/// split around `PdfDrawNewPage`, selected page ranges are advanced or padded
/// between chunks, resources are merged into page resources, manual artifact
/// back-channel markers are fixed before writing content, and `struct_tree`
/// writes a fresh structure tree from rendered MCIDs only when the document has
/// cpdf's fresh `/StructTreeRoot` placeholder. If a real structure tree is
/// already present, or no fresh placeholder exists, requested structure mode
/// artifacts the drawn content instead of replacing the tree. When `role_map`
/// is not empty, it is parsed as the body of a PDF role-map dictionary and
/// attached to the generated `/StructTreeRoot`.
pub fn PdfDocument::draw(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  drawops : ArrayView[PdfDrawOp],
  struct_tree? : Bool = false,
  fast? : Bool = false,
  underneath? : Bool = false,
  filename? : String = "",
  bates? : Int = 1,
  bates_pad? : Int? = None,
  time? : PdfStrftimeTime? = None,
  add_artifacts? : Bool = false,
  role_map? : String = "",
) -> PdfDocument raise PdfError {
  pdf_page_box_validate_page_numbers(page_numbers, self.endpage(), "draw")
  let write_structure_tree = struct_tree &&
    self.pdf_draw_has_fresh_structure_tree()
  let effective_add_artifacts = add_artifacts ||
    (struct_tree && !write_structure_tree)
  let state = pdf_draw_render_state_new()
  state.set_structure_tree_enabled(write_structure_tree)
  let chunks = pdf_draw_split_on_new_page(
    pdf_draw_double_trailing_new_page(drawops),
  )
  let mut document = self
  let mut current_pages = [ for page_number in page_numbers => page_number ]
  for index in 0..<chunks.length() {
    state.reset_for_page_chunk()
    if chunks[index].length() > 0 {
      if current_pages.length() > 0 {
        state.set_structure_page_number(current_pages[0])
      } else {
        state.set_structure_page_number(0)
      }
      document = document.pdf_draw_apply_chunk(
        state,
        current_pages,
        chunks[index],
        write_structure_tree,
        fast,
        underneath,
        filename,
        bates,
        bates_pad,
        time,
        effective_add_artifacts,
      )
    }
    if index + 1 < chunks.length() {
      let next = pdf_draw_next_range(document, current_pages)
      document = next.0
      current_pages = next.1
    }
  }
  if write_structure_tree {
    document.pdf_draw_write_structure_tree(state.structure_data, role_map)
  }
  document
}

///|
/// Compatibility wrapper for `PdfDocument::draw`.
pub fn pdf_draw(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  drawops : ArrayView[PdfDrawOp],
  struct_tree? : Bool = false,
  fast? : Bool = false,
  underneath? : Bool = false,
  filename? : String = "",
  bates? : Int = 1,
  bates_pad? : Int? = None,
  time? : PdfStrftimeTime? = None,
  add_artifacts? : Bool = false,
  role_map? : String = "",
) -> PdfDocument raise PdfError {
  document.draw(
    page_numbers,
    drawops,
    struct_tree~,
    fast~,
    underneath~,
    filename~,
    bates~,
    bates_pad~,
    time~,
    add_artifacts~,
    role_map~,
  )
}
