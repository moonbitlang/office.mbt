///|
fn pdf_annotation_rectangle_object(
  rectangle : @geometry.PdfRectangle,
) -> @syntax.PdfObject {
  PdfArray([
    PdfReal(rectangle.min_x),
    PdfReal(rectangle.min_y),
    PdfReal(rectangle.max_x),
    PdfReal(rectangle.max_y),
  ])
}

///|
fn pdf_annotation_border_object(
  border : @annotation.PdfAnnotationBorder,
) -> @syntax.PdfObject {
  let base : Array[@syntax.PdfObject] = [
    PdfReal(border.horizontal_radius),
    PdfReal(border.vertical_radius),
    PdfReal(border.width),
  ]
  if border.dash_array.length() > 0 {
    base.push(PdfArray([ for dash in border.dash_array => PdfInteger(dash) ]))
  }
  PdfArray(base)
}

///|
fn pdf_annotation_rest_entries(
  rest : @syntax.PdfObject,
) -> Array[(PdfName, @syntax.PdfObject)] raise PdfError {
  match rest {
    PdfNull => []
    PdfDictionary(entries) => [ for entry in entries => entry ]
    _ => raise DictionaryExpected
  }
}

///|
fn pdf_object_of_annotation(
  annotation : @annotation.PdfAnnotation,
) -> @syntax.PdfObject raise PdfError {
  let entries : Array[(PdfName, @syntax.PdfObject)] = [
    (
      pdf_annotation_subtype_key(),
      PdfNameObject(pdf_annotation_subtype_name(annotation.subtype)),
    ),
    (
      pdf_annotation_contents_key(),
      match annotation.contents {
        Some(contents) => PdfString(contents)
        None => PdfNull
      },
    ),
    (
      pdf_annotation_rect_key(),
      pdf_annotation_rectangle_object(annotation.rectangle),
    ),
    (
      pdf_annotation_border_key(),
      pdf_annotation_border_object(annotation.border),
    ),
  ]
  for entry in pdf_annotation_rest_entries(annotation.rest) {
    entries.push(entry)
  }
  match annotation.colour {
    Some(colour) =>
      entries.push(
        (
          pdf_annotation_colour_key(),
          PdfArray([
            PdfInteger(colour.red),
            PdfInteger(colour.green),
            PdfInteger(colour.blue),
          ]),
        ),
      )
    None => ()
  }
  match annotation.subject {
    Some(subject) =>
      entries.push((pdf_annotation_subj_key(), PdfString(subject)))
    None => ()
  }
  PdfDictionary(entries)
}

///|
/// Return a page value with an annotation prepended to `/Annots`.
///
/// The annotation is written as a direct dictionary. Existing annotation arrays
/// are preserved after the new entry; a non-array `/Annots` value raises.
pub fn PdfDocument::add_annotation(
  self : PdfDocument,
  page : @page.PdfPage,
  annotation : @annotation.PdfAnnotation,
) -> @page.PdfPage raise PdfError {
  let object = pdf_object_of_annotation(annotation)
  let annotations = match
    self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
    Some(PdfArray(existing)) => [object, ..existing]
    Some(_) => raise DictionaryExpected
    None => [object]
  }
  {
    ..page,
    rest: page.rest.add_dict_entry(
      pdf_annotation_annots_key(),
      PdfArray(annotations),
    ),
  }
}

///|
/// Compatibility wrapper for `PdfDocument::add_annotation`.
pub fn pdf_add_annotation(
  document : PdfDocument,
  page : @page.PdfPage,
  annotation : @annotation.PdfAnnotation,
) -> @page.PdfPage raise PdfError {
  document.add_annotation(page, annotation)
}

///|
fn PdfDocument::pdf_annotation_transform_one(
  self : PdfDocument,
  matrix : @geometry.TransformMatrix,
  annotation_number : Int,
) -> Unit raise PdfError {
  let annotation = self.lookup_object_or_null(annotation_number)
  let transformed = self.pdf_annotation_transform_object(matrix, annotation)
  if transformed != annotation {
    self.add_object_given_number(annotation_number, transformed)
  }
}

///|
fn PdfDocument::pdf_annotation_transform_object(
  self : PdfDocument,
  matrix : @geometry.TransformMatrix,
  annotation : @syntax.PdfObject,
) -> @syntax.PdfObject raise PdfError {
  let mut transformed = annotation
  match self.lookup_direct(pdf_annotation_rect_key(), annotation) {
    Some(rectangle) =>
      transformed = transformed.add_dict_entry(
        pdf_annotation_rect_key(),
        self.transform_rect(matrix, rectangle),
      )
    None => ()
  }
  match self.lookup_direct(pdf_annotation_quadpoints_key(), annotation) {
    Some(quadpoints) =>
      transformed = transformed.add_dict_entry(
        pdf_annotation_quadpoints_key(),
        self.transform_quadpoints(matrix, quadpoints),
      )
    None => ()
  }
  match self.lookup_direct(pdf_annotation_line_key(), annotation) {
    Some(line) =>
      transformed = transformed.add_dict_entry(
        pdf_annotation_line_key(),
        self.transform_rect(matrix, line),
      )
    None => ()
  }
  transformed
}

///|
/// Transform annotation geometry referenced by a page dictionary.
///
/// Applies `matrix` to `/Rect`, `/QuadPoints`, and `/L` entries. Indirect
/// annotations are updated in this document; direct annotation dictionaries in
/// the page's `/Annots` array are updated in place.
pub fn PdfDocument::transform_annotations(
  self : PdfDocument,
  matrix : @geometry.TransformMatrix,
  rest : @syntax.PdfObject,
) -> Unit raise PdfError {
  match self.lookup_direct(pdf_annotation_annots_key(), rest) {
    Some(PdfArray(annotations)) =>
      for index in 0..<annotations.length() {
        match annotations[index] {
          PdfIndirect(number) =>
            self.pdf_annotation_transform_one(matrix, number)
          PdfDictionary(_) as annotation => {
            let transformed = self.pdf_annotation_transform_object(
              matrix, annotation,
            )
            if transformed != annotation {
              annotations[index] = transformed
            }
          }
          _ => ()
        }
      }
    _ => ()
  }
}

///|
/// Compatibility wrapper for `PdfDocument::transform_annotations`.
pub fn pdf_transform_annotations(
  document : PdfDocument,
  matrix : @geometry.TransformMatrix,
  rest : @syntax.PdfObject,
) -> Unit raise PdfError {
  document.transform_annotations(matrix, rest)
}
