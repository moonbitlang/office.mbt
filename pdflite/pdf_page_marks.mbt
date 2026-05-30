///|
let pdf_page_marks_allowance : Double = 9.0

///|
fn PdfDocument::pdf_page_marks_rectangle(
  self : PdfDocument,
  page : @page.PdfPage,
  box_name : PdfName,
) -> @geometry.PdfRectangle? raise PdfError {
  let object = if box_name == pdf_page_mediabox_key() {
    Some(page.mediabox)
  } else {
    self.lookup_direct(box_name, page.rest)
  }
  match object {
    Some(PdfArray([_, _, _, _]) as rectangle) =>
      Some(self.parse_rectangle(rectangle))
    _ => None
  }
}

///|
fn PdfDocument::pdf_page_show_box_ops(
  self : PdfDocument,
  page : @page.PdfPage,
  colour : (Double, Double, Double),
  dash_on : Double,
  dash_off : Double,
  box_name : PdfName,
) -> Array[@content.PdfContentOp] raise PdfError {
  match self.pdf_page_marks_rectangle(page, box_name) {
    Some(bounds) => {
      let dash = if dash_on == 0.0 && dash_off == 0.0 {
        []
      } else {
        [dash_on, dash_off]
      }
      [
        Op_q,
        Op_RG(colour.0 / 255.0, colour.1 / 255.0, colour.2 / 255.0),
        Op_w(1.0),
        Op_d(dash, 0.0),
        Op_re(
          bounds.min_x,
          bounds.min_y,
          bounds.max_x - bounds.min_x,
          bounds.max_y - bounds.min_y,
        ),
        Op_S,
        Op_Q,
      ]
    }
    None => []
  }
}

///|
fn PdfDocument::pdf_page_show_boxes_ops(
  self : PdfDocument,
  page : @page.PdfPage,
) -> Array[@content.PdfContentOp] raise PdfError {
  let ops : Array[@content.PdfContentOp] = [
    @content.pdf_content_begin_artifact(),
  ]
  for
    op in self.pdf_page_show_box_ops(
      page,
      (255.0, 0.0, 0.0),
      0.0,
      0.0,
      pdf_page_mediabox_key(),
    ) {
    ops.push(op)
  }
  for
    op in self.pdf_page_show_box_ops(
      page,
      (0.0, 255.0, 0.0),
      7.0,
      7.0,
      pdf_page_cropbox_key(),
    ) {
    ops.push(op)
  }
  for
    op in self.pdf_page_show_box_ops(
      page,
      (0.0, 0.0, 255.0),
      5.0,
      5.0,
      pdf_page_artbox_key(),
    ) {
    ops.push(op)
  }
  for
    op in self.pdf_page_show_box_ops(
      page,
      (255.0, 150.0, 0.0),
      3.0,
      3.0,
      pdf_page_trimbox_key(),
    ) {
    ops.push(op)
  }
  for
    op in self.pdf_page_show_box_ops(
      page,
      (255.0, 9.0, 147.0),
      2.0,
      2.0,
      pdf_page_bleedbox_key(),
    ) {
    ops.push(op)
  }
  ops.push(@content.pdf_content_end_artifact())
  ops
}

///|
fn pdf_page_trim_marks_push_line(
  ops : Array[@content.PdfContentOp],
  x0 : Double,
  y0 : Double,
  x1 : Double,
  y1 : Double,
) -> Unit {
  ops.push(Op_m(x0, y0))
  ops.push(Op_l(x1, y1))
  ops.push(Op_s)
}

///|
fn pdf_page_trim_marks_ops(
  trim : @geometry.PdfRectangle,
  media : @geometry.PdfRectangle,
) -> Array[@content.PdfContentOp] {
  let ops : Array[@content.PdfContentOp] = [
    Op_q,
    Op_K(1.0, 1.0, 1.0, 1.0),
    Op_w(1.0),
    @content.pdf_content_begin_artifact(),
  ]
  pdf_page_trim_marks_push_line(
    ops,
    media.min_x,
    trim.max_y,
    trim.min_x - pdf_page_marks_allowance,
    trim.max_y,
  )
  pdf_page_trim_marks_push_line(
    ops,
    trim.min_x,
    trim.max_y + pdf_page_marks_allowance,
    trim.min_x,
    media.max_y,
  )
  pdf_page_trim_marks_push_line(
    ops,
    trim.max_x + pdf_page_marks_allowance,
    trim.max_y,
    media.max_x,
    trim.max_y,
  )
  pdf_page_trim_marks_push_line(
    ops,
    trim.max_x,
    trim.max_y + pdf_page_marks_allowance,
    trim.max_x,
    media.max_y,
  )
  pdf_page_trim_marks_push_line(
    ops,
    trim.max_x + pdf_page_marks_allowance,
    trim.min_y,
    media.max_x,
    trim.min_y,
  )
  pdf_page_trim_marks_push_line(
    ops,
    trim.max_x,
    trim.min_y - pdf_page_marks_allowance,
    trim.max_x,
    media.min_y,
  )
  pdf_page_trim_marks_push_line(
    ops,
    trim.min_x - pdf_page_marks_allowance,
    trim.min_y,
    media.min_x,
    trim.min_y,
  )
  pdf_page_trim_marks_push_line(
    ops,
    trim.min_x,
    trim.min_y - pdf_page_marks_allowance,
    trim.min_x,
    media.min_y,
  )
  ops.push(@content.pdf_content_end_artifact())
  ops.push(Op_Q)
  ops
}

///|
fn PdfDocument::pdf_page_trim_marks_page(
  self : PdfDocument,
  page : @page.PdfPage,
  fast : Bool,
) -> @page.PdfPage raise PdfError {
  match
    (
      self.pdf_page_marks_rectangle(page, pdf_page_trimbox_key()),
      self.pdf_page_marks_rectangle(page, pdf_page_mediabox_key()),
    ) {
    (Some(trim), Some(media)) =>
      self.postpend_operators(page, pdf_page_trim_marks_ops(trim, media), fast~)
    _ => page
  }
}

///|
/// Draw coloured outlines for the standard page boxes on selected pages.
///
/// This ports cpdf's `show_boxes`: `/MediaBox`, `/CropBox`, `/ArtBox`,
/// `/TrimBox`, and `/BleedBox` are appended as artifact-marked stroked
/// rectangles when present.
pub fn PdfDocument::show_page_boxes(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  self.pdf_page_box_rewrite_pages(page_numbers, "show_page_boxes", (_, _, page) => {
    self.postpend_operators(page, self.pdf_page_show_boxes_ops(page), fast~)
  })
}

///|
/// Compatibility wrapper for `PdfDocument::show_page_boxes`.
pub fn pdf_show_boxes(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.show_page_boxes(page_numbers, fast~)
}

///|
/// Add trim marks around `/TrimBox` on selected pages.
///
/// Pages without a valid `/TrimBox` are left unchanged, matching cpdf's
/// `trim_marks`.
pub fn PdfDocument::trim_marks(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  self.pdf_page_box_rewrite_pages(page_numbers, "trim_marks", (_, _, page) => {
    self.pdf_page_trim_marks_page(page, fast)
  })
}

///|
/// Compatibility wrapper for `PdfDocument::trim_marks`.
pub fn pdf_trim_marks(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  fast? : Bool = false,
) -> PdfDocument raise PdfError {
  document.trim_marks(page_numbers, fast~)
}
