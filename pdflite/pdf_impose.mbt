///|
fn pdf_impose_validate_transform_inputs(
  x : Int,
  y : Int,
  count : Int,
) -> Unit raise PdfError {
  if x <= 0 || y <= 0 {
    raise BadNumberArgument("impose: x and y must be positive")
  }
  if count < 0 {
    raise BadNumberArgument("impose: page count must be non-negative")
  }
}

///|
fn pdf_impose_order(
  row : Int,
  col : Int,
  x : Int,
  y : Int,
  rtl : Bool,
  btt : Bool,
) -> (Int, Int) {
  (if btt { y - row - 1 } else { row }, if rtl { x - col - 1 } else { col })
}

///|
fn pdf_impose_adjusted_row(
  original_row : Int,
  y : Int,
  final_full_rows : Int,
  remaining : Int,
  center : Bool,
) -> Int {
  if center && remaining <= final_full_rows {
    let final_empty_rows = y - final_full_rows
    original_row + (y - 1 - 1 - final_empty_rows / 2)
  } else {
    original_row
  }
}

///|
fn pdf_impose_adjusted_col(
  original_col : Int,
  x : Int,
  final_full_cols : Int,
  remaining : Int,
  center : Bool,
) -> Int {
  if center && remaining <= final_full_cols {
    let final_empty_cols = x - final_full_cols
    original_col + (x - 1 - 1 - final_empty_cols / 2)
  } else {
    original_col
  }
}

///|
fn pdf_impose_translate(
  x : Int,
  rtl : Bool,
  btt : Bool,
  cent_extra_x : Double,
  cent_extra_y : Double,
  fit_extra_hspace : Double,
  fit_extra_vspace : Double,
  row : Int,
  col : Int,
  px : Double,
  py : Double,
) -> TransformMatrix {
  let cex = if rtl { -cent_extra_x } else { cent_extra_x }
  let cey = if btt { -cent_extra_y } else { cent_extra_y }
  let space_col = if rtl { x - col - 1 } else { col }
  let total_fit_extra_hspace = fit_extra_hspace * (space_col.to_double() + 1.0)
  let total_fit_extra_vspace = fit_extra_vspace * (row.to_double() + 1.0)
  transform_translate(
    px + cex + total_fit_extra_hspace,
    py + cey + total_fit_extra_vspace,
  )
}

///|
fn PdfDocument::pdf_impose_make_margin(
  self : PdfDocument,
  output_mediabox : PdfObject,
  margin : Double,
  matrix : TransformMatrix,
) -> TransformMatrix raise PdfError {
  if margin == 0.0 {
    matrix
  } else {
    let box = self.parse_rectangle(output_mediabox)
    let width = box.max_x - box.min_x
    let height = box.max_y - box.min_y
    if margin > width / 2.0 || margin > height / 2.0 {
      raise BadNumberArgument("impose: margin would fill whole page")
    }
    let hfactor = (width - margin - margin) / width
    let vfactor = (height - margin - margin) / height
    let factor = if hfactor < vfactor { hfactor } else { vfactor }
    let scale = transform_scale(point2(0.0, 0.0), factor, factor)
    let shift = transform_translate(
      (width - width * factor) / 2.0,
      (height - height * factor) / 2.0,
    )
    transform_matrix_compose(shift, transform_matrix_compose(scale, matrix))
  }
}

///|
fn PdfDocument::pdf_impose_transform_for_slot(
  self : PdfDocument,
  fit : Bool,
  x : Int,
  rtl : Bool,
  btt : Bool,
  margin : Double,
  output_mediabox : PdfObject,
  fit_extra_hspace : Double,
  fit_extra_vspace : Double,
  cent_extra_x : Double,
  cent_extra_y : Double,
  row : Int,
  col : Int,
  px : Double,
  py : Double,
) -> TransformMatrix raise PdfError {
  let matrix = pdf_impose_translate(
    x, rtl, btt, cent_extra_x, cent_extra_y, fit_extra_hspace, fit_extra_vspace,
    row, col, px, py,
  )
  if fit {
    self.pdf_impose_make_margin(output_mediabox, margin, matrix)
  } else {
    matrix
  }
}

///|
fn pdf_impose_concat_ops(
  first : ArrayView[PdfContentOp],
  second : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for op in first {
    output.push(op)
  }
  for op in second {
    output.push(op)
  }
  output
}

///|
fn pdf_impose_push_objects(
  output : Array[PdfObject],
  objects : ArrayView[PdfObject],
) -> Unit {
  for object in objects {
    output.push(object)
  }
}

///|
#warnings("-unused_value")
fn PdfDocument::pdf_impose_transform_content(
  self : PdfDocument,
  resources : PdfObject,
  matrix : TransformMatrix,
  content : ArrayView[PdfObject],
  fast : Bool,
) -> Array[PdfObject] raise PdfError {
  if fast {
    let output : Array[PdfObject] = [
      pdf_content_stream_of_ops([Op_q, Op_cm(matrix)]),
    ]
    pdf_impose_push_objects(output, content)
    output.push(pdf_content_stream_of_ops([Op_Q]))
    output
  } else {
    let old_ops = self.parse_content_ops_with_resources(resources, content)
    let protected_ops = pdf_impose_concat_ops(
      pdf_page_protect(old_ops),
      old_ops,
    )
    [
      pdf_content_stream_of_ops(
        pdf_impose_concat_ops(
          [Op_q, Op_cm(matrix)],
          pdf_impose_concat_ops(protected_ops, [Op_Q]),
        ),
      ),
    ]
  }
}

///|
#warnings("-unused_value")
fn PdfDocument::pdf_impose_transforms(
  self : PdfDocument,
  fit : Bool,
  x : Int,
  y : Int,
  columns : Bool,
  rtl : Bool,
  btt : Bool,
  center : Bool,
  margin : Double,
  mediabox : PdfObject,
  output_mediabox : PdfObject,
  fit_extra_hspace : Double,
  fit_extra_vspace : Double,
  count : Int,
) -> Array[TransformMatrix] raise PdfError {
  pdf_impose_validate_transform_inputs(x, y, count)
  let page_box = self.parse_rectangle(mediabox)
  let width = page_box.max_x - page_box.min_x
  let height = page_box.max_y - page_box.min_y
  let final_full_cols = count % x
  let final_full_rows = count % y
  let output : Array[TransformMatrix] = []
  let mut remaining = count
  let mut cent_extra_x = 0.0
  let mut cent_extra_y = 0.0
  if columns {
    for col = 0; col < x; col = col + 1 {
      if center && remaining < y && cent_extra_y == 0.0 {
        cent_extra_y = -(height * (y - remaining).to_double()) / 2.0
      }
      for row = y - 1; row >= 0; row = row - 1 {
        let original_row = row
        let (ordered_row, ordered_col) = pdf_impose_order(
          row, col, x, y, rtl, btt,
        )
        let adjusted_row = pdf_impose_adjusted_row(
          original_row, y, final_full_rows, remaining, center,
        )
        if remaining > 0 {
          output.push(
            self.pdf_impose_transform_for_slot(
              fit,
              x,
              rtl,
              btt,
              margin,
              output_mediabox,
              fit_extra_hspace,
              fit_extra_vspace,
              cent_extra_x,
              cent_extra_y,
              adjusted_row,
              ordered_col,
              width * ordered_col.to_double(),
              height * ordered_row.to_double(),
            ),
          )
        }
        remaining -= 1
      }
    }
  } else {
    for row = y - 1; row >= 0; row = row - 1 {
      if center && remaining < x && cent_extra_x == 0.0 {
        cent_extra_x = width * (x - remaining).to_double() / 2.0
      }
      for col = 0; col < x; col = col + 1 {
        let original_col = col
        let (ordered_row, ordered_col) = pdf_impose_order(
          row, col, x, y, rtl, btt,
        )
        let adjusted_col = pdf_impose_adjusted_col(
          original_col, x, final_full_cols, remaining, center,
        )
        if remaining > 0 {
          output.push(
            self.pdf_impose_transform_for_slot(
              fit,
              x,
              rtl,
              btt,
              margin,
              output_mediabox,
              fit_extra_hspace,
              fit_extra_vspace,
              cent_extra_x,
              cent_extra_y,
              ordered_row,
              adjusted_col,
              width * ordered_col.to_double(),
              height * ordered_row.to_double(),
            ),
          )
        }
        remaining -= 1
      }
    }
  }
  output
}
