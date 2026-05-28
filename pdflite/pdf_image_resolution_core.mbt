///|
priv enum PdfImageResolutionObject {
  PdfImageResolutionImage(Int, Int)
  PdfImageResolutionForm(TransformMatrix, PdfObject, PdfObject)
}

///|
priv struct PdfImageResolutionCandidate {
  name : PdfName
  object : PdfImageResolutionObject
  object_number : Int
}

///|
priv struct PdfImageResolutionEntry {
  page_number : Int
  xobject : String
  width : Int
  height : Int
  xdpi : Double
  ydpi : Double
  object_number : Int
}

///|
fn pdf_image_resolution_compare_double(left : Double, right : Double) -> Int {
  if left < right {
    -1
  } else if left > right {
    1
  } else {
    0
  }
}

///|
fn pdf_image_resolution_entry_compare(
  left : PdfImageResolutionEntry,
  right : PdfImageResolutionEntry,
) -> Int {
  let page = left.page_number.compare(right.page_number)
  if page != 0 {
    page
  } else {
    let xobject = left.xobject.compare(right.xobject)
    if xobject != 0 {
      xobject
    } else {
      let width = left.width.compare(right.width)
      if width != 0 {
        width
      } else {
        let height = left.height.compare(right.height)
        if height != 0 {
          height
        } else {
          let xdpi = pdf_image_resolution_compare_double(left.xdpi, right.xdpi)
          if xdpi != 0 {
            xdpi
          } else {
            let ydpi = pdf_image_resolution_compare_double(
              left.ydpi,
              right.ydpi,
            )
            if ydpi != 0 {
              ydpi
            } else {
              left.object_number.compare(right.object_number)
            }
          }
        }
      }
    }
  }
}

///|
fn pdf_image_resolution_distance(left : Point2, right : Point2) -> Double {
  let dx = right.x - left.x
  let dy = right.y - left.y
  (dx * dx + dy * dy).sqrt()
}

///|
fn pdf_image_resolution_inches(matrix : TransformMatrix) -> (Double, Double) {
  let origin = matrix.apply(point2(0.0, 0.0))
  let x_axis = matrix.apply(point2(1.0, 0.0))
  let y_axis = matrix.apply(point2(0.0, 1.0))
  (
    unit_inches(pdf_image_resolution_distance(origin, x_axis), PdfPoint),
    unit_inches(pdf_image_resolution_distance(origin, y_axis), PdfPoint),
  )
}

///|
fn pdf_image_resolution_push_entry(
  entries : Array[PdfImageResolutionEntry],
  page_number : Int,
  name : PdfName,
  width : Int,
  height : Int,
  object_number : Int,
  matrix : TransformMatrix,
) -> Unit raise PdfError {
  let (x_inches, y_inches) = pdf_image_resolution_inches(matrix)
  entries.push({
    page_number,
    xobject: pdf_image_name_to_string(name),
    width,
    height,
    xdpi: width.to_double() / x_inches,
    ydpi: height.to_double() / y_inches,
    object_number,
  })
}
