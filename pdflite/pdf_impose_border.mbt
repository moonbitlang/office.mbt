///|
let pdf_impose_cpdf_stamp_name : PdfName = pdf_page_name("/CPDFSTAMP")

///|
fn pdf_impose_border_ops(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  line_width : Double,
) -> Array[@content.PdfContentOp] {
  [
    @content.pdf_content_begin_artifact(),
    Op_q,
    Op_BMC(pdf_impose_cpdf_stamp_name),
    Op_rg(0.0, 0.0, 0.0),
    Op_RG(0.0, 0.0, 0.0),
    Op_w(line_width),
    Op_re(x, y, width, height),
    Op_s,
    Op_EMC,
    Op_Q,
    @content.pdf_content_end_artifact(),
  ]
}

///|
#warnings("-unused_value")
fn PdfDocument::pdf_impose_add_border(
  self : PdfDocument,
  line_width : Double,
  fast : Bool,
) -> PdfDocument raise PdfError {
  let end_page = self.endpage()
  if line_width == 0.0 || end_page == 0 {
    self
  } else {
    let pages = self.pages_of_pagetree()
    let first_bounds = self.parse_rectangle(pages[0].mediabox)
    let inset = line_width / 2.0
    self.append_page_content_ops(
      pdf_impose_all_pages(end_page),
      pdf_impose_border_ops(
        first_bounds.min_x + inset,
        first_bounds.min_y + inset,
        first_bounds.max_x - line_width,
        first_bounds.max_y - line_width,
        line_width,
      ),
      fast~,
    )
  }
}
