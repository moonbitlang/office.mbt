///|
/// Typeset UTF-8 text into a standalone PDF document using an existing font
/// pack.
///
/// When `process_struct_tree` is set, paragraph tags are added and a
/// `/StructTreeRoot` with page-level parent-tree entries is installed.
pub fn pdf_texttopdf_typeset(
  fontpack : PdfFontPack,
  font_size : Double,
  paper : @geometry.PaperSize,
  text : BytesView,
  process_struct_tree? : Bool = false,
  subformat? : PdfUASubformat? = None,
  title? : String? = None,
) -> PdfDocument raise PdfError {
  let process_struct_tree = process_struct_tree || subformat != None
  let title = match (subformat, title) {
    (Some(_), Some(title)) => Some(title)
    (Some(_), None) => raise TitleExpected
    (None, title) => title
  }
  let document = pdf_document_empty()
  let instructions = pdf_texttopdf_of_utf8_with_newlines(
    fontpack, font_size, text,
  )
  let tagged = if process_struct_tree {
    pdf_texttopdf_tag_paragraphs(instructions)
  } else {
    instructions
  }
  let elements = pdf_texttopdf_document_elements(tagged)
  let margin = @geometry.unit_points(paper.width(), paper.unit()) / 15.0
  let result = document.pdf_type_typeset(
    process_struct_tree, margin, margin, margin, margin, paper, elements,
  )
  let pages = if process_struct_tree {
    pdf_texttopdf_struct_parent_pages(result.pages)
  } else {
    result.pages
  }
  let page_root = document.add_pagetree(pages)
  ignore(document.add_root(page_root, []))
  if process_struct_tree {
    document.pdf_texttopdf_add_structure_tree(result.tags, subformat)
  }
  match (subformat, title) {
    (Some(subformat), Some(title)) =>
      document.pdf_ua_apply_subformat_metadata(subformat, title)
    _ => ()
  }
  document
}

///|
/// Compatibility wrapper matching cpdftexttopdf's `typeset` required argument
/// order.
pub fn pdf_texttopdf_typeset_cpdf_order(
  process_struct_tree : Bool,
  paper : @geometry.PaperSize,
  fontpack : PdfFontPack,
  font_size : Double,
  text : BytesView,
  subformat? : PdfUASubformat? = None,
  title? : String? = None,
) -> PdfDocument raise PdfError {
  pdf_texttopdf_typeset(
    fontpack,
    font_size,
    paper,
    text,
    process_struct_tree~,
    subformat~,
    title~,
  )
}
