///|
fn pdf_impose_validate_transform_inputs(
  x : Int,
  y : Int,
  count : Int,
) -> Unit raise @core.PdfError {
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
) -> @geometry.TransformMatrix {
  let cex = if rtl { -cent_extra_x } else { cent_extra_x }
  let cey = if btt { -cent_extra_y } else { cent_extra_y }
  let space_col = if rtl { x - col - 1 } else { col }
  let total_fit_extra_hspace = fit_extra_hspace * (space_col.to_double() + 1.0)
  let total_fit_extra_vspace = fit_extra_vspace * (row.to_double() + 1.0)
  @geometry.transform_translate(
    px + cex + total_fit_extra_hspace,
    py + cey + total_fit_extra_vspace,
  )
}

///|
fn PdfDocument::pdf_impose_make_margin(
  self : PdfDocument,
  output_mediabox : @syntax.PdfObject,
  margin : Double,
  matrix : @geometry.TransformMatrix,
) -> @geometry.TransformMatrix raise @core.PdfError {
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
    let scale = @geometry.transform_scale(
      @geometry.point2(0.0, 0.0),
      factor,
      factor,
    )
    let shift = @geometry.transform_translate(
      (width - width * factor) / 2.0,
      (height - height * factor) / 2.0,
    )
    @geometry.transform_matrix_compose(
      shift,
      @geometry.transform_matrix_compose(scale, matrix),
    )
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
  output_mediabox : @syntax.PdfObject,
  fit_extra_hspace : Double,
  fit_extra_vspace : Double,
  cent_extra_x : Double,
  cent_extra_y : Double,
  row : Int,
  col : Int,
  px : Double,
  py : Double,
) -> @geometry.TransformMatrix raise @core.PdfError {
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
#warnings("-unused_field")
priv struct PdfImposeLayout {
  pages_per_sheet : Int
  x_slots : Int
  y_slots : Int
  output_mediabox : @syntax.PdfObject
  fit_extra_hspace : Double
  fit_extra_vspace : Double
}

///|
fn pdf_impose_output_box(width : Double, height : Double) -> @syntax.PdfObject {
  PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(width), PdfReal(height)])
}

///|
fn PdfDocument::pdf_impose_fit_layout(
  self : PdfDocument,
  x : Double,
  y : Double,
  page_width : Double,
  page_height : Double,
) -> PdfImposeLayout raise @core.PdfError {
  ignore(self)
  let across = @math.floor(x / page_width + 0.001).to_int()
  let down = @math.floor(y / page_height + 0.001).to_int()
  if across < 1 || down < 1 {
    raise BadNumberArgument("impose: not even a single page would fit")
  }
  {
    pages_per_sheet: across * down,
    x_slots: across,
    y_slots: down,
    output_mediabox: pdf_impose_output_box(x, y),
    fit_extra_hspace: (x - across.to_double() * page_width) /
    (across.to_double() + 1.0),
    fit_extra_vspace: (y - down.to_double() * page_height) /
    (down.to_double() + 1.0),
  }
}

///|
fn PdfDocument::pdf_impose_xy_layout(
  self : PdfDocument,
  x : Double,
  y : Double,
  margin : Double,
  page_count : Int,
  page_width : Double,
  page_height : Double,
) -> PdfImposeLayout raise @core.PdfError {
  ignore(self)
  let ix = x.to_int()
  let iy = y.to_int()
  if ix == 0 && iy == 0 {
    raise BadNumberArgument("impose-xy: both dimensions cannot be zero")
  }
  let (pages_per_sheet, x_slots, y_slots) = if ix == 0 {
    (page_count, page_count, 1)
  } else if iy == 0 {
    (page_count, 1, page_count)
  } else {
    (ix * iy, ix, iy)
  }
  let margin2 = margin * 2.0
  let output_mediabox = if x == 0.0 {
    pdf_impose_output_box(
      page_width * page_count.to_double() + margin2,
      page_height + margin2,
    )
  } else if y == 0.0 {
    pdf_impose_output_box(
      page_width + margin2,
      page_height * page_count.to_double() + margin2,
    )
  } else {
    pdf_impose_output_box(page_width * x + margin2, page_height * y + margin2)
  }
  {
    pages_per_sheet,
    x_slots,
    y_slots,
    output_mediabox,
    fit_extra_hspace: 0.0,
    fit_extra_vspace: 0.0,
  }
}

///|
#warnings("-unused_value")
fn PdfDocument::pdf_impose_layout(
  self : PdfDocument,
  fit : Bool,
  x : Double,
  y : Double,
  margin : Double,
  page_count : Int,
  mediabox : @syntax.PdfObject,
) -> PdfImposeLayout raise @core.PdfError {
  let bounds = self.parse_rectangle(mediabox)
  let page_width = bounds.max_x - bounds.min_x
  let page_height = bounds.max_y - bounds.min_y
  if fit {
    self.pdf_impose_fit_layout(x, y, page_width, page_height)
  } else {
    self.pdf_impose_xy_layout(x, y, margin, page_count, page_width, page_height)
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
  mediabox : @syntax.PdfObject,
  output_mediabox : @syntax.PdfObject,
  fit_extra_hspace : Double,
  fit_extra_vspace : Double,
  count : Int,
) -> Array[@geometry.TransformMatrix] raise @core.PdfError {
  pdf_impose_validate_transform_inputs(x, y, count)
  let page_box = self.parse_rectangle(mediabox)
  let width = page_box.max_x - page_box.min_x
  let height = page_box.max_y - page_box.min_y
  let final_full_cols = count % x
  let final_full_rows = count % y
  let output : Array[@geometry.TransformMatrix] = []
  let mut remaining = count
  let mut cent_extra_x = 0.0
  let mut cent_extra_y = 0.0
  if columns {
    for col in 0..<x {
      if center && remaining < y && cent_extra_y == 0.0 {
        cent_extra_y = -(height * (y - remaining).to_double()) / 2.0
      }
      for row_offset in 0..<y {
        let row = y - 1 - row_offset
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
    for row_offset in 0..<y {
      let row = y - 1 - row_offset
      if center && remaining < x && cent_extra_x == 0.0 {
        cent_extra_x = width * (x - remaining).to_double() / 2.0
      }
      for col in 0..<x {
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
