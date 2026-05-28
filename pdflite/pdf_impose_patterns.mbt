///|
let pdf_impose_matrix_key_name : PdfName = pdf_page_name("/Matrix")

///|
fn pdf_impose_pattern_name_used(
  used_names : ArrayView[PdfName],
  name : PdfName,
) -> Bool {
  for used_name in used_names {
    if used_name == name {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_impose_pattern_add_used(
  used_names : Array[PdfName],
  name : PdfName,
) -> Unit {
  if !pdf_impose_pattern_name_used(used_names, name) {
    used_names.push(name)
  }
}

///|
fn PdfDocument::pdf_impose_patterns_used_with_scn(
  self : PdfDocument,
  content : ArrayView[PdfObject],
  resources : PdfObject,
) -> Array[PdfName] raise PdfError {
  let used_names : Array[PdfName] = []
  match self.lookup_direct(pdf_page_pattern_resource_name, resources) {
    Some(_) => {
      let ops = self.parse_content_ops_with_resources(resources, content)
      for op in ops {
        match op {
          Op_scnName(name, []) | Op_SCNName(name, []) =>
            pdf_impose_pattern_add_used(used_names, name)
          _ => ()
        }
      }
    }
    None => ()
  }
  used_names
}

///|
fn pdf_impose_xobject_done(done : ArrayView[Int], number : Int) -> Bool {
  for item in done {
    if item == number {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn PdfDocument::pdf_impose_change_pattern_object(
  self : PdfDocument,
  matrix : TransformMatrix,
  pattern : PdfObject,
) -> PdfObject raise PdfError {
  let old_pattern = self.direct(pattern)
  let existing = self.parse_matrix(pdf_impose_matrix_key_name, old_pattern)
  let new_matrix = transform_matrix_compose(matrix, existing)
  PdfIndirect(
    self.add_object(
      old_pattern.add_dict_entry(
        pdf_impose_matrix_key_name,
        pdf_object_of_matrix(new_matrix),
      ),
    ),
  )
}

///|
fn PdfDocument::pdf_impose_change_pattern_matrices_resources(
  self : PdfDocument,
  matrix : TransformMatrix,
  resources : PdfObject,
  names_used_with_scn : ArrayView[PdfName],
  xobjects_done : Array[Int],
) -> PdfObject raise PdfError {
  match self.lookup_direct(pdf_page_xobject_key(), resources) {
    Some(PdfDictionary(entries)) =>
      for entry in entries {
        match entry.1 {
          PdfIndirect(number) =>
            self.pdf_impose_change_pattern_matrices_xobject(
              matrix,
              entry.1,
              number,
              xobjects_done,
            )
          _ => raise DictionaryExpected
        }
      }
    _ => ()
  }
  match self.lookup_direct(pdf_page_pattern_resource_name, resources) {
    Some(PdfDictionary(patterns)) => {
      let entries : Array[(PdfName, PdfObject)] = []
      for entry in patterns {
        let (name, pattern) = entry
        if pdf_impose_pattern_name_used(names_used_with_scn, name) {
          entries.push(
            (name, self.pdf_impose_change_pattern_object(matrix, pattern)),
          )
        } else {
          entries.push(entry)
        }
      }
      resources.add_dict_entry(
        pdf_page_pattern_resource_name,
        PdfDictionary(entries),
      )
    }
    _ => resources
  }
}

///|
fn PdfDocument::pdf_impose_change_pattern_matrices_xobject(
  self : PdfDocument,
  matrix : TransformMatrix,
  xobject : PdfObject,
  xobject_number : Int,
  xobjects_done : Array[Int],
) -> Unit raise PdfError {
  if pdf_impose_xobject_done(xobjects_done, xobject_number) {
    ()
  } else {
    xobjects_done.push(xobject_number)
    let direct_xobject = self.direct(xobject)
    match self.lookup_direct(pdf_page_subtype_key(), direct_xobject) {
      Some(PdfNameObject(name)) if name == pdf_page_type_form() => {
        let resources = match
          self.lookup_direct(pdf_page_resources_key(), direct_xobject) {
          Some(value) => value
          None => PdfDictionary([])
        }
        let used = self.pdf_impose_patterns_used_with_scn(
          [direct_xobject],
          resources,
        )
        match self.lookup_direct(pdf_page_resources_key(), direct_xobject) {
          Some(_) => {
            let updated_resources = self.pdf_impose_change_pattern_matrices_resources(
              matrix, resources, used, xobjects_done,
            )
            self.add_object_given_number(
              xobject_number,
              direct_xobject.add_dict_entry(
                pdf_page_resources_key(),
                updated_resources,
              ),
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
fn PdfDocument::pdf_impose_change_pattern_matrices_page(
  self : PdfDocument,
  matrix : TransformMatrix,
  page : PdfPage,
) -> PdfPage raise PdfError {
  let used = self.pdf_impose_patterns_used_with_scn(
    page.content,
    page.resources,
  )
  let xobjects_done : Array[Int] = []
  {
    ..page,
    resources: self.pdf_impose_change_pattern_matrices_resources(
      matrix,
      page.resources,
      used,
      xobjects_done,
    ),
  }
}

///|
/// Rewrite pattern matrices used by a page after applying a page transform.
pub fn PdfDocument::change_pattern_matrices_page(
  self : PdfDocument,
  matrix : TransformMatrix,
  page : PdfPage,
) -> PdfPage raise PdfError {
  self.pdf_impose_change_pattern_matrices_page(matrix, page)
}

///|
/// Compatibility wrapper matching cpdfpage's `change_pattern_matrices_page`.
pub fn pdf_change_pattern_matrices_page(
  document : PdfDocument,
  matrix : TransformMatrix,
  page : PdfPage,
) -> PdfPage raise PdfError {
  document.change_pattern_matrices_page(matrix, page)
}
