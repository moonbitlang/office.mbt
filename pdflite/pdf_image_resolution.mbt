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

///|
fn PdfDocument::pdf_image_resolution_lookup_inline_int(
  self : PdfDocument,
  first_key : PdfName,
  second_key : PdfName,
  image : PdfObject,
) -> Int? {
  match self.lookup_direct_or_else(first_key, second_key, image) {
    Some(PdfInteger(value)) => Some(value)
    _ => None
  }
}

///|
fn pdf_image_resolution_find_candidate(
  candidates : ArrayView[PdfImageResolutionCandidate],
  name : PdfName,
) -> PdfImageResolutionCandidate? {
  for candidate in candidates {
    if candidate.name == name {
      break Some(candidate)
    }
  } nobreak {
    None
  }
}

///|
fn PdfDocument::pdf_image_resolution_candidates(
  self : PdfDocument,
  resources : PdfObject,
) -> Array[PdfImageResolutionCandidate] raise PdfError {
  match self.lookup_direct(pdf_image_xobject_key(), resources) {
    Some(PdfDictionary(xobjects)) => {
      let candidates : Array[PdfImageResolutionCandidate] = Array::new(
        capacity=xobjects.length(),
      )
      for entry in xobjects {
        let object_number = match entry.1 {
          PdfIndirect(number) => number
          _ => 0
        }
        match self.lookup_direct(pdf_image_subtype_key(), entry.1) {
          Some(PdfNameObject(subtype)) if subtype == pdf_image_image_name() =>
            candidates.push({
              name: entry.0,
              object: PdfImageResolutionImage(
                self.pdf_image_lookup_int_or_default(
                  pdf_image_width_key(),
                  pdf_image_width_key(),
                  entry.1,
                  1,
                ),
                self.pdf_image_lookup_int_or_default(
                  pdf_image_height_key(),
                  pdf_image_height_key(),
                  entry.1,
                  1,
                ),
              ),
              object_number,
            })
          Some(PdfNameObject(subtype)) if subtype == pdf_image_form_name() => {
            let form = self.direct(entry.1)
            let form_resources = match
              self.lookup_direct(pdf_xobject_resources_key(), form) {
              Some(resources) => resources
              None => resources
            }
            candidates.push({
              name: entry.0,
              object: PdfImageResolutionForm(
                self.parse_matrix(pdf_image_matrix_key(), form),
                form,
                form_resources,
              ),
              object_number,
            })
          }
          _ => ()
        }
      }
      candidates
    }
    _ => []
  }
}

///|
fn PdfDocument::pdf_image_resolution_process_content(
  self : PdfDocument,
  resources : PdfObject,
  content : ArrayView[PdfObject],
  candidates : ArrayView[PdfImageResolutionCandidate],
  page_number : Int,
  inline : Bool,
  initial_matrix : TransformMatrix,
  depth : Int,
  results : Array[PdfImageResolutionEntry],
) -> Unit raise PdfError {
  if depth > 64 {
    return
  }
  let ops = self.parse_content_ops_with_resources(resources, content)
  let transforms : Array[TransformMatrix] = [initial_matrix]
  for op in ops {
    match op {
      Op_cm(matrix) =>
        if transforms.length() > 0 {
          let index = transforms.length() - 1
          transforms[index] = transform_matrix_compose(
            transforms[index],
            matrix,
          )
        }
      Op_q =>
        if transforms.length() > 0 {
          transforms.push(transforms[transforms.length() - 1])
        }
      Op_Q => if transforms.length() > 0 { ignore(transforms.pop()) }
      Op_InlineImage(dictionary, _, _) =>
        if inline && transforms.length() > 0 {
          match
            (
              self.pdf_image_resolution_lookup_inline_int(
                pdf_image_width_key(),
                pdf_image_w_key(),
                dictionary,
              ),
              self.pdf_image_resolution_lookup_inline_int(
                pdf_image_height_key(),
                pdf_image_h_key(),
                dictionary,
              ),
            ) {
            (Some(width), Some(height)) =>
              pdf_image_resolution_push_entry(
                results,
                page_number,
                pdf_image_name("/InlineImage"),
                width,
                height,
                0,
                transforms[transforms.length() - 1],
              )
            _ => ()
          }
        }
      Op_Do(name) =>
        if transforms.length() > 0 {
          match pdf_image_resolution_find_candidate(candidates, name) {
            Some(
              {
                object: PdfImageResolutionImage(width, height),
                object_number,
                ..,
              }
            ) =>
              pdf_image_resolution_push_entry(
                results,
                page_number,
                name,
                width,
                height,
                object_number,
                transforms[transforms.length() - 1],
              )
            Some(
              {
                object: PdfImageResolutionForm(matrix, form, form_resources),
                ..,
              }
            ) => {
              let form_candidates = self.pdf_image_resolution_candidates(
                form_resources,
              )
              self.pdf_image_resolution_process_content(
                form_resources,
                [form],
                form_candidates,
                page_number,
                inline,
                transform_matrix_compose(
                  matrix,
                  transforms[transforms.length() - 1],
                ),
                depth + 1,
                results,
              )
            }
            None => ()
          }
        }
      _ => ()
    }
  }
}

///|
/// Report image resolutions for selected pages.
///
/// Results match cpdf's tuple order: page number, XObject name, image width,
/// image height, horizontal DPI, vertical DPI, and object number. Entries are
/// kept when either axis is below `dpi`.
pub fn PdfDocument::image_resolution(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
  inline? : Bool = false,
) -> Array[(Int, String, Int, Int, Double, Double, Int)] raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(page_numbers, pages.length(), "images")
  let results : Array[PdfImageResolutionEntry] = Array::new(
    capacity=page_numbers.length(),
  )
  for page_number in page_numbers {
    let page = pages[page_number - 1]
    let candidates = self.pdf_image_resolution_candidates(page.resources)
    if inline || candidates.length() > 0 {
      self.pdf_image_resolution_process_content(
        page.resources,
        page.content,
        candidates,
        page_number,
        inline,
        transform_identity_matrix,
        0,
        results,
      )
    }
  }
  let filtered : Array[PdfImageResolutionEntry] = Array::new(
    capacity=results.length(),
  )
  for entry in results {
    if entry.xdpi < dpi || entry.ydpi < dpi {
      filtered.push(entry)
    }
  }
  filtered.sort_by(pdf_image_resolution_entry_compare)
  [
    for entry in filtered => {
      (
        entry.page_number,
        entry.xobject,
        entry.width,
        entry.height,
        entry.xdpi,
        entry.ydpi,
        entry.object_number,
      )
    }
  ]
}

///|
fn pdf_image_resolution_entry_json(
  entry : (Int, String, Int, Int, Double, Double, Int),
) -> Json {
  Json::object(
    Map([
      ("Object", pdf_image_json_int(entry.6)),
      ("Page", pdf_image_json_int(entry.0)),
      ("XObject", Json::string(entry.1)),
      ("W", pdf_image_json_int(entry.2)),
      ("H", pdf_image_json_int(entry.3)),
      ("Xdpi", Json::number(entry.4)),
      ("Ydpi", Json::number(entry.5)),
    ]),
  )
}

///|
/// Report image resolution data as cpdf-style JSON rows.
pub fn PdfDocument::image_resolution_json(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
  inline? : Bool = false,
) -> Json raise PdfError {
  Json::array(
    [
      for entry in self.image_resolution(page_numbers, dpi, inline~) => {
        pdf_image_resolution_entry_json(entry)
      }
    ],
  )
}

///|
/// Report image resolution data as UTF-8 JSON bytes.
pub fn PdfDocument::image_resolution_json_blob(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
  inline? : Bool = false,
) -> PdfBytes raise PdfError {
  @utf8.encode(
    self.image_resolution_json(page_numbers, dpi, inline~).stringify(),
  )
}

///|
/// Compatibility wrapper for `PdfDocument::image_resolution`.
pub fn pdf_image_resolution(
  inline : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
) -> Array[(Int, String, Int, Int, Double, Double, Int)] raise PdfError {
  document.image_resolution(page_numbers, dpi, inline~)
}

///|
/// Compatibility wrapper for `PdfDocument::image_resolution_json`.
pub fn pdf_image_resolution_json(
  inline : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
) -> Json raise PdfError {
  document.image_resolution_json(page_numbers, dpi, inline~)
}

///|
/// Compatibility wrapper for `PdfDocument::image_resolution_json_blob`.
pub fn pdf_image_resolution_json_blob(
  inline : Bool,
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  dpi : Double,
) -> PdfBytes raise PdfError {
  document.image_resolution_json_blob(page_numbers, dpi, inline~)
}
