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
  time? : @date.PdfStrftimeTime? = None,
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
  time? : @date.PdfStrftimeTime? = None,
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
