///|
/// Build cpdf's URL link annotation object for add-text markup.
pub fn pdf_addtext_url_annotation(
  p0 : Point2,
  p1 : Point2,
  p2 : Point2,
  p3 : Point2,
  rectangle : PdfRectangle,
  url : String,
  url_border : Bool,
) -> PdfObject {
  PdfDictionary([
    (pdf_addtext_subtype_key_name, PdfNameObject(pdf_addtext_link_name)),
    (
      pdf_addtext_quadpoints_key_name,
      PdfArray([
        PdfReal(p0.x),
        PdfReal(p0.y),
        PdfReal(p3.x),
        PdfReal(p3.y),
        PdfReal(p1.x),
        PdfReal(p1.y),
        PdfReal(p2.x),
        PdfReal(p2.y),
      ]),
    ),
    (
      pdf_addtext_rect_key_name,
      PdfArray([
        PdfReal(rectangle.min_x),
        PdfReal(rectangle.min_y),
        PdfReal(rectangle.max_x),
        PdfReal(rectangle.max_y),
      ]),
    ),
    (
      pdf_addtext_bs_key_name,
      PdfDictionary([
        (pdf_addtext_w_key_name, PdfInteger(if url_border { 1 } else { 0 })),
      ]),
    ),
    (
      pdf_addtext_a_key_name,
      PdfDictionary([
        (pdf_addtext_uri_key_name, PdfString(@utf8.encode(url))),
        (pdf_addtext_type_key_name, PdfNameObject(pdf_addtext_action_name)),
        (pdf_addtext_s_key_name, PdfNameObject(pdf_addtext_uri_key_name)),
      ]),
    ),
  ])
}

///|
fn pdf_addtext_bounds_of_points(
  p0 : Point2,
  p1 : Point2,
  p2 : Point2,
  p3 : Point2,
) -> PdfRectangle {
  {
    min_x: double_min(double_min(p0.x, p1.x), double_min(p2.x, p3.x)),
    min_y: double_min(double_min(p0.y, p1.y), double_min(p2.y, p3.y)),
    max_x: double_max(double_max(p0.x, p1.x), double_max(p2.x, p3.x)),
    max_y: double_max(double_max(p0.y, p1.y), double_max(p2.y, p3.y)),
  }
}

///|
/// Return cpdf's add-text URL annotation height for a font selection.
pub fn pdf_addtext_url_annotation_height(
  font : PdfFont?,
  fontname : String,
  font_size : Double,
) -> Double {
  match pdf_addtext_cap_height(font, fontname) {
    Some(cap_height) => cap_height * font_size / 1000.0
    None => font_size
  }
}

///|
/// Calculate the transformed quad points and bounds for an add-text URL span.
pub fn pdf_addtext_url_annotation_geometry(
  origin : Point2,
  horizontal_offset : Double,
  vertical_offset : Double,
  justification_offset : Double,
  rotation : Double,
  rotation_offset : Point2,
  page_rotation : Double,
  start_width : Double,
  end_width : Double,
  height : Double,
) -> PdfAddTextUrlAnnotationGeometry {
  let base_x = origin.x - horizontal_offset - justification_offset
  let base_y = origin.y - vertical_offset
  let min_x = base_x + start_width
  let min_y = base_y
  let max_x = base_x + end_width
  let max_y = base_y + height
  let matrix = transform_matrix_of_transform([
    Translate(rotation_offset.x, rotation_offset.y),
    Rotate(point2(base_x, base_y), rotation + page_rotation),
  ])
  let p0 = matrix.apply(point2(min_x, min_y))
  let p1 = matrix.apply(point2(max_x, max_y))
  let p2 = matrix.apply(point2(min_x, max_y))
  let p3 = matrix.apply(point2(max_x, min_y))
  { p0, p1, p2, p3, rectangle: pdf_addtext_bounds_of_points(p0, p1, p2, p3) }
}

///|
fn pdf_addtext_url_annotation_prefix(
  text : String,
  position : Int,
) -> String raise PdfError {
  let bytes = @utf8.encode(text)
  if position < 0 || position > bytes.length() {
    raise SoftError("bad add-text URL byte offset")
  }
  @utf8.decode(bytes[:position]) catch {
    _ => raise SoftError("bad add-text URL byte offset")
  }
}

///|
fn pdf_addtext_url_annotation_widths_with_measure(
  text : String,
  url : PdfAddTextUrl,
  measure : (String) -> Double raise PdfError,
) -> (Double, Double) raise PdfError {
  (
    measure(pdf_addtext_url_annotation_prefix(text, url.start)),
    measure(pdf_addtext_url_annotation_prefix(text, url.end)),
  )
}

///|
/// Measure cpdf's start and end prefix widths for an add-text URL span.
pub fn pdf_addtext_url_annotation_widths(
  text : String,
  url : PdfAddTextUrl,
  measure : (String) -> Double,
) -> (Double, Double) raise PdfError {
  pdf_addtext_url_annotation_widths_with_measure(text, url, fn(prefix) {
    measure(prefix)
  })
}

///|
/// Build indirect URL link annotations for one cpdf add-text line.
///
/// This mirrors cpdf's add-text annotation pass: each parsed URL span is
/// measured against the visible line, converted to transformed quad points, and
/// written as a new indirect annotation object.
pub fn PdfDocument::addtext_url_annotation_references(
  self : PdfDocument,
  text : String,
  urls : ArrayView[PdfAddTextUrl],
  measure : (String) -> Double raise PdfError,
  origin : Point2,
  horizontal_offset : Double,
  vertical_offset : Double,
  justification_offset : Double,
  rotation : Double,
  rotation_offset : Point2,
  page_rotation : Double,
  font : PdfFont?,
  fontname : String,
  font_size : Double,
  url_border : Bool,
) -> Array[PdfObject] raise PdfError {
  let height = pdf_addtext_url_annotation_height(font, fontname, font_size)
  let annotations : Array[PdfObject] = Array::new(capacity=urls.length())
  for url in urls {
    let (start_width, end_width) = pdf_addtext_url_annotation_widths_with_measure(
      text, url, measure,
    )
    let geometry = pdf_addtext_url_annotation_geometry(
      origin, horizontal_offset, vertical_offset, justification_offset, rotation,
      rotation_offset, page_rotation, start_width, end_width, height,
    )
    let object_number = self.add_object(
      pdf_addtext_url_annotation(
        geometry.p0,
        geometry.p1,
        geometry.p2,
        geometry.p3,
        geometry.rectangle,
        url.url,
        url_border,
      ),
    )
    annotations.push(PdfIndirect(object_number))
  }
  annotations
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_url_annotation_references`.
pub fn pdf_addtext_url_annotation_references(
  document : PdfDocument,
  text : String,
  urls : ArrayView[PdfAddTextUrl],
  measure : (String) -> Double raise PdfError,
  origin : Point2,
  horizontal_offset : Double,
  vertical_offset : Double,
  justification_offset : Double,
  rotation : Double,
  rotation_offset : Point2,
  page_rotation : Double,
  font : PdfFont?,
  fontname : String,
  font_size : Double,
  url_border : Bool,
) -> Array[PdfObject] raise PdfError {
  document.addtext_url_annotation_references(
    text, urls, measure, origin, horizontal_offset, vertical_offset, justification_offset,
    rotation, rotation_offset, page_rotation, font, fontname, font_size, url_border,
  )
}

///|
/// Return a page rest dictionary with cpdf add-text annotations prepended.
///
/// Empty new annotation lists leave `rest` unchanged. Existing `/Annots`
/// arrays are resolved through `document`; missing or malformed values are
/// treated as empty, matching cpdf's add-text page update.
pub fn PdfDocument::addtext_page_rest_with_annotations(
  self : PdfDocument,
  rest : PdfObject,
  annotations : ArrayView[PdfObject],
) -> PdfObject raise PdfError {
  if annotations.length() == 0 {
    rest
  } else {
    let updated : Array[PdfObject] = [
      for annotation in annotations => annotation
    ]
    match self.lookup_direct(pdf_addtext_annots_key(), rest) {
      Some(PdfArray(existing)) =>
        for annotation in existing {
          updated.push(annotation)
        }
      _ => ()
    }
    rest.add_dict_entry(pdf_addtext_annots_key(), PdfArray(updated))
  }
}

///|
/// Compatibility wrapper for `PdfDocument::addtext_page_rest_with_annotations`.
pub fn pdf_addtext_page_rest_with_annotations(
  document : PdfDocument,
  rest : PdfObject,
  annotations : ArrayView[PdfObject],
) -> PdfObject raise PdfError {
  document.addtext_page_rest_with_annotations(rest, annotations)
}
