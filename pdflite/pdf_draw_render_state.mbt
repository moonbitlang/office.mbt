///|
fn PdfDrawRenderState::fresh_name(
  self : PdfDrawRenderState,
  prefix : String,
) -> PdfName {
  self.resource_number += 1
  pdf_draw_name(prefix + self.resource_number.to_string())
}

///|
fn PdfDrawRenderState::fresh_mcid(self : PdfDrawRenderState) -> Int {
  self.marked_content_id += 1
  self.marked_content_id
}

///|
fn PdfDrawRenderState::set_minimum_resource_number(
  self : PdfDrawRenderState,
  minimum : Int,
) -> Unit {
  if self.resource_number < minimum {
    self.resource_number = minimum
  }
}

///|
fn PdfDrawRenderState::reset_for_page_chunk(self : PdfDrawRenderState) -> Unit {
  self.extgstates.clear()
  self.marked_content_id = -1
}

///|
fn PdfDrawRenderState::set_structure_tree_enabled(
  self : PdfDrawRenderState,
  enabled : Bool,
) -> Unit {
  self.structure_tree_enabled = enabled
}

///|
fn PdfDrawRenderState::set_structure_page_number(
  self : PdfDrawRenderState,
  page_number : Int,
) -> Unit {
  self.structure_page_number = page_number
}

///|
fn PdfDrawRenderState::adopt_resource_number(
  self : PdfDrawRenderState,
  child : PdfDrawRenderState,
) -> Unit {
  if child.resource_number > self.resource_number {
    self.resource_number = child.resource_number
  }
  if child.marked_content_id > self.marked_content_id {
    self.marked_content_id = child.marked_content_id
  }
}
