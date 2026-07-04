///|
fn PdfDocument::pdf_page_mark_all_as_artifact_streams(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  content : ArrayView[@syntax.PdfObject],
) -> Array[@syntax.PdfObject] raise @core.PdfError {
  let ops = self.pdf_page_parse_content_ops(resources, content)
  let marked : Array[@content.PdfContentOp] = [
    @content.pdf_content_begin_artifact(),
  ]
  for op in ops {
    marked.push(op)
  }
  marked.push(@content.pdf_content_end_artifact())
  [pdf_content_stream_of_ops(marked)]
}

///|
let pdf_page_struct_parent_key_name : @core.PdfName = pdf_page_name(
  "/StructParent",
)

///|
let pdf_page_struct_parents_key_name : @core.PdfName = pdf_page_name(
  "/StructParents",
)

///|
fn pdf_page_struct_parent_key() -> @core.PdfName {
  pdf_page_struct_parent_key_name
}

///|
fn pdf_page_struct_parents_key() -> @core.PdfName {
  pdf_page_struct_parents_key_name
}

///|
fn pdf_page_remove_struct_tree_op(op : @content.PdfContentOp) -> Bool {
  match op {
    Op_MP(_) | Op_DP(_, _) | Op_BMC(_) | Op_BDC(_, _) | Op_EMC => true
    _ => false
  }
}

///|
fn PdfDocument::pdf_page_remove_struct_tree_streams(
  self : PdfDocument,
  resources : @syntax.PdfObject,
  content : ArrayView[@syntax.PdfObject],
) -> Array[@syntax.PdfObject] raise @core.PdfError {
  let ops = self.pdf_page_parse_content_ops(resources, content)
  let output : Array[@content.PdfContentOp] = []
  for op in ops {
    if !pdf_page_remove_struct_tree_op(op) {
      output.push(op)
    }
  }
  [pdf_content_stream_of_ops(output)]
}

///|
fn PdfDocument::pdf_page_remove_struct_tree_page(
  self : PdfDocument,
  page : @page.PdfPage,
) -> @page.PdfPage raise @core.PdfError {
  let content = self.pdf_page_remove_struct_tree_streams(
    page.resources,
    page.content,
  )
  self.process_xobjects(page, fn(
    document,
    resources,
    streams,
  ) raise @core.PdfError {
    document.pdf_page_remove_struct_tree_streams(resources, streams)
  })
  { ..page, content, }
}

///|
fn PdfDocument::pdf_page_mark_all_as_artifact_page(
  self : PdfDocument,
  page : @page.PdfPage,
) -> @page.PdfPage raise @core.PdfError {
  let content = self.pdf_page_mark_all_as_artifact_streams(
    page.resources,
    page.content,
  )
  self.process_xobjects(page, fn(
    document,
    resources,
    streams,
  ) raise @core.PdfError {
    document.pdf_page_mark_all_as_artifact_streams(resources, streams)
  })
  { ..page, content, }
}

///|
/// Remove the structure tree and marked-content structure operators.
///
/// This ports cpdfpage's `remove_struct_tree`: `/StructTreeRoot`,
/// `/StructParent`, and `/StructParents` entries are removed throughout the
/// document, and marked-content structure delimiters are stripped from page
/// streams and referenced Form XObjects.
pub fn PdfDocument::remove_struct_tree(
  self : PdfDocument,
) -> PdfDocument raise @core.PdfError {
  let document = self.copy()
  document.remove_dict_entry_everywhere(pdf_structure_struct_tree_root_key())
  document.remove_dict_entry_everywhere(pdf_page_struct_parent_key())
  document.remove_dict_entry_everywhere(pdf_page_struct_parents_key())
  let pages = document.pages_of_pagetree()
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  for page in pages {
    rewritten.push(document.pdf_page_remove_struct_tree_page(page))
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::remove_struct_tree`.
pub fn pdf_remove_struct_tree(
  document : PdfDocument,
) -> PdfDocument raise @core.PdfError {
  document.remove_struct_tree()
}

///|
/// Mark every page content stream and referenced Form XObject as a PDF/UA artifact.
pub fn PdfDocument::mark_all_as_artifact(
  self : PdfDocument,
) -> PdfDocument raise @core.PdfError {
  let document = self.copy()
  let pages = document.pages_of_pagetree()
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  for page in pages {
    rewritten.push(document.pdf_page_mark_all_as_artifact_page(page))
  }
  document.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::mark_all_as_artifact`.
pub fn pdf_mark_all_as_artifact(
  document : PdfDocument,
) -> PdfDocument raise @core.PdfError {
  document.mark_all_as_artifact()
}
