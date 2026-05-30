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
  initial_matrix : @geometry.TransformMatrix,
  depth : Int,
  results : Array[PdfImageResolutionEntry],
) -> Unit raise PdfError {
  if depth > 64 {
    return
  }
  let ops = self.parse_content_ops_with_resources(resources, content)
  let transforms : Array[@geometry.TransformMatrix] = [initial_matrix]
  for op in ops {
    match op {
      Op_cm(matrix) =>
        if transforms.length() > 0 {
          let index = transforms.length() - 1
          transforms[index] = @geometry.transform_matrix_compose(
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
                @geometry.transform_matrix_compose(
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
