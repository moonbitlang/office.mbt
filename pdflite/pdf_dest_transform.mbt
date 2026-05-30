///|
fn pdf_dest_clip(value : Double) -> Double {
  if value < -32768.0 {
    -32768.0
  } else if value > 32768.0 {
    32768.0
  } else {
    value
  }
}

///|
fn pdf_dest_transform_point(
  matrix : TransformMatrix,
  x : Double,
  y : Double,
) -> Point2 {
  let point = matrix.apply(point2(x, y))
  point2(pdf_dest_clip(point.x), pdf_dest_clip(point.y))
}

///|
/// Applies a page transform matrix to destination coordinates.
///
/// Only destinations tied to page objects are transformed. Named destinations,
/// string destinations, non-page-number actions, and already page-number-based
/// targets are preserved.
pub fn PdfDocument::transform_destination(
  self : PdfDocument,
  matrix : TransformMatrix,
  destination : @destination.PdfDestination,
) -> @destination.PdfDestination raise PdfError {
  match destination {
    DestFitH(TargetPageObject(_) as target, Some(top)) => {
      let point = pdf_dest_transform_point(matrix, 0.0, top)
      DestFitH(target, Some(point.y))
    }
    DestFitV(TargetPageObject(_) as target, Some(left)) => {
      let point = pdf_dest_transform_point(matrix, left, 0.0)
      DestFitV(target, Some(point.x))
    }
    DestFitBH(TargetPageObject(_) as target, Some(top)) => {
      let point = pdf_dest_transform_point(matrix, 0.0, top)
      DestFitBH(target, Some(point.y))
    }
    DestFitBV(TargetPageObject(_) as target, Some(left)) => {
      let point = pdf_dest_transform_point(matrix, left, 0.0)
      DestFitBV(target, Some(point.x))
    }
    DestXYZ(TargetPageObject(_) as target, Some(left), Some(top), zoom) => {
      let point = pdf_dest_transform_point(matrix, left, top)
      DestXYZ(target, Some(point.x), Some(point.y), zoom)
    }
    DestXYZ(TargetPageObject(_) as target, None, Some(top), zoom) => {
      let point = pdf_dest_transform_point(matrix, 0.0, top)
      DestXYZ(target, None, Some(point.y), zoom)
    }
    DestXYZ(TargetPageObject(_) as target, Some(left), None, zoom) => {
      let point = pdf_dest_transform_point(matrix, left, 0.0)
      DestXYZ(target, Some(point.x), None, zoom)
    }
    DestFitR(TargetPageObject(_) as target, left, bottom, right, top) => {
      let left_top = pdf_dest_transform_point(matrix, left, top)
      let right_bottom = pdf_dest_transform_point(matrix, right, bottom)
      DestFitR(target, left_top.x, right_bottom.y, right_bottom.x, left_top.y)
    }
    DestAction(action) =>
      match
        (
          self.lookup_direct(pdf_dest_s_key(), action),
          self.lookup_direct(pdf_dest_d_key(), action),
        ) {
        (Some(PdfNameObject(name)), Some(raw_destination)) if name ==
          pdf_dest_goto_name() =>
          DestAction(
            action.add_dict_entry(
              pdf_dest_d_key(),
              pdf_object_of_destination(
                self.transform_destination(
                  matrix,
                  self.read_destination(raw_destination, shallow=true),
                ),
              ),
            ),
          )
        _ => destination
      }
    _ => destination
  }
}

///|
/// Applies a page transform matrix to destination coordinates.
///
/// This is the standalone form of `PdfDocument::transform_destination`.
pub fn pdf_transform_destination(
  document : PdfDocument,
  matrix : TransformMatrix,
  destination : @destination.PdfDestination,
) -> @destination.PdfDestination raise PdfError {
  document.transform_destination(matrix, destination)
}
