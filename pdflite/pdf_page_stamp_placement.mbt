///|
fn pdf_page_stamp_half(value : Double) -> Double {
  value / 2.0
}

///|
fn pdf_page_stamp_shift_of_position(
  topline : Bool,
  midline : Bool,
  stamp_width : Double,
  stamp_height : Double,
  page_width : Double,
  page_height : Double,
  position : PdfPosition,
) -> (Double, Double) {
  let dy = if midline {
    stamp_height / 2.0
  } else if topline {
    stamp_height
  } else {
    0.0
  }
  match position {
    PdfPositionPosCentre(x, y) => (x - pdf_page_stamp_half(stamp_width), y - dy)
    PdfPositionPosLeft(x, y) => (x, y - dy)
    PdfPositionPosRight(x, y) => (x - stamp_width, y - dy)
    PdfPositionTop(offset) =>
      (
        pdf_page_stamp_half(page_width) - pdf_page_stamp_half(stamp_width),
        page_height - offset - stamp_height - dy,
      )
    PdfPositionTopLeft(x, y) => (x, page_height - stamp_height - y - dy)
    PdfPositionTopRight(x, y) =>
      (page_width - stamp_width - x, page_height - stamp_height - y - dy)
    PdfPositionLeft(offset) =>
      (
        offset,
        pdf_page_stamp_half(page_height) -
        pdf_page_stamp_half(stamp_height) -
        dy,
      )
    PdfPositionBottomLeft(x, y) => (x, y - dy)
    PdfPositionBottom(offset) =>
      (
        pdf_page_stamp_half(page_width) - pdf_page_stamp_half(stamp_width),
        offset - dy,
      )
    PdfPositionBottomRight(x, y) => (page_width - stamp_width - x, y - dy)
    PdfPositionRight(offset) =>
      (
        page_width - stamp_width - offset,
        pdf_page_stamp_half(page_height) -
        pdf_page_stamp_half(stamp_height) -
        dy,
      )
    PdfPositionDiagonal | PdfPositionReverseDiagonal | PdfPositionCentre =>
      (
        pdf_page_stamp_half(page_width) - pdf_page_stamp_half(stamp_width),
        pdf_page_stamp_half(page_height) -
        pdf_page_stamp_half(stamp_height) -
        dy,
      )
  }
}

///|
fn PdfDocument::pdf_page_stamp_box(
  self : PdfDocument,
  page : @page.PdfPage,
  box_name : PdfName,
) -> PdfRectangle raise PdfError {
  self.parse_rectangle(
    if box_name == pdf_page_mediabox_key() {
      page.mediabox
    } else {
      match self.lookup_direct(box_name, page.rest) {
        Some(box) => box
        None => page.mediabox
      }
    },
  )
}

///|
fn pdf_page_stamp_scale_to_fit_factor(
  x_magnification : Double,
  y_magnification : Double,
) -> Double {
  if x_magnification < 0.999 && y_magnification < 0.999 {
    if x_magnification > y_magnification {
      x_magnification
    } else {
      y_magnification
    }
  } else if x_magnification >= 1.001 && y_magnification >= 1.001 {
    if x_magnification > y_magnification {
      y_magnification
    } else {
      x_magnification
    }
  } else if x_magnification >= 1.001 {
    y_magnification
  } else {
    x_magnification
  }
}

///|
fn pdf_page_stamp_scale_to_fit_matrix(
  stamp_box : PdfRectangle,
  target_box : PdfRectangle,
  relative_to_box : PdfName,
) -> TransformMatrix raise PdfError {
  let stamp_width = stamp_box.max_x - stamp_box.min_x
  let stamp_height = stamp_box.max_y - stamp_box.min_y
  let target_width = target_box.max_x - target_box.min_x
  let target_height = target_box.max_y - target_box.min_y
  if stamp_width == 0.0 || stamp_height == 0.0 {
    raise BadNumberArgument("stamp_pages: zero-sized stamp page is invalid")
  }
  let scale = pdf_page_stamp_scale_to_fit_factor(
    target_width / stamp_width,
    target_height / stamp_height,
  )
  let dx = target_box.min_x + (target_width - stamp_width * scale) / 2.0
  let dy = target_box.min_y + (target_height - stamp_height * scale) / 2.0
  let ops : Array[TransformOp] = [Translate(dx, dy)]
  if relative_to_box != pdf_page_mediabox_key() {
    ops.push(Translate(target_box.min_x, target_box.min_y))
  }
  ops.push(Scale(point2(stamp_box.min_x, stamp_box.min_y), scale, scale))
  transform_matrix_of_ops(ops)
}

///|
fn pdf_page_stamp_position_matrix(
  stamp_box : PdfRectangle,
  target_box : PdfRectangle,
  relative_to_box : PdfName,
  position : PdfPosition,
  topline : Bool,
  midline : Bool,
) -> TransformMatrix {
  let stamp_width = stamp_box.max_x - stamp_box.min_x
  let stamp_height = stamp_box.max_y - stamp_box.min_y
  let target_width = target_box.max_x - target_box.min_x
  let target_height = target_box.max_y - target_box.min_y
  let (dx, dy) = pdf_page_stamp_shift_of_position(
    topline, midline, stamp_width, stamp_height, target_width, target_height, position,
  )
  let ops : Array[TransformOp] = []
  if relative_to_box != pdf_page_mediabox_key() {
    ops.push(Translate(target_box.min_x, target_box.min_y))
  }
  ops.push(Translate(dx, dy))
  transform_matrix_of_ops(ops)
}
