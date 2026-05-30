///|
priv struct PdfAnnotationJsonImportRow {
  page_number : Int
  object_number : Int
  object : PdfObject
}

///|
priv struct PdfAnnotationJsonImportData {
  max_object_number : Int
  extras : Array[(Int, PdfObject)]
  annotations : Array[PdfAnnotationJsonImportRow]
}

///|
fn pdf_annotation_json_import_number(json : Json) -> Int raise PdfError {
  match json {
    Number(value, repr=_) => pdf_util_json_integral_number(value)
    _ => raise SoftError("Bad annots entry")
  }
}

///|
fn pdf_annotation_json_import_data(
  json : Json,
) -> PdfAnnotationJsonImportData raise PdfError {
  let entries = match json {
    Array(values) => values
    _ => raise SoftError("Bad Annotations JSON file")
  }
  let max_object_number : Ref[Int] = { val: 0 }
  let extras : Array[(Int, PdfObject)] = Array::new(capacity=entries.length())
  let annotations : Array[PdfAnnotationJsonImportRow] = Array::new(
    capacity=entries.length(),
  )
  for entry in entries {
    match entry {
      Array([number_json, object_json]) => {
        let number = pdf_annotation_json_import_number(number_json)
        if number > 0 {
          extras.push((number, pdf_object_of_json(object_json)))
          if number > max_object_number.val {
            max_object_number.val = number
          }
        }
      }
      Array([page_json, number_json, object_json]) => {
        let page_number = pdf_annotation_json_import_number(page_json)
        let object_number = pdf_annotation_json_import_number(number_json)
        if object_number <= 0 {
          raise SoftError("Bad annots entry")
        }
        annotations.push({
          page_number,
          object_number,
          object: pdf_object_of_json(object_json),
        })
        if object_number > max_object_number.val {
          max_object_number.val = object_number
        }
      }
      _ => raise SoftError("Bad annots entry")
    }
  }
  { max_object_number: max_object_number.val, extras, annotations }
}

///|
fn PdfDocument::pdf_annotation_json_import_renumbered(
  self : PdfDocument,
  max_object_number : Int,
) -> PdfDocument raise PdfError {
  if max_object_number <= 0 {
    self.copy()
  } else {
    let object_numbers = self.object_numbers()
    let changes : Array[(Int, Int)] = Array::new(
      capacity=object_numbers.length(),
    )
    for index, number in object_numbers {
      changes.push((number, max_object_number + index + 1))
    }
    self.renumber_objects(changes)
  }
}

///|
fn pdf_annotation_json_import_page_reference(
  page_reference_numbers : ArrayView[Int],
  page_number : Int,
) -> Int {
  if page_number >= 1 && page_number <= page_reference_numbers.length() {
    page_reference_numbers[page_number - 1]
  } else {
    page_number
  }
}

///|
fn pdf_annotation_json_import_destination(
  page_reference_numbers : ArrayView[Int],
  destination : PdfObject,
) -> PdfObject {
  match destination {
    PdfArray(items) =>
      if items.length() == 0 {
        destination
      } else {
        match items[0] {
          PdfInteger(page_number) => {
            let rewritten : Array[PdfObject] = [
              PdfIndirect(
                pdf_annotation_json_import_page_reference(
                  page_reference_numbers, page_number,
                ),
              ),
            ]
            for index in 1..<items.length() {
              rewritten.push(items[index])
            }
            PdfArray(rewritten)
          }
          _ => destination
        }
      }
    _ => destination
  }
}

///|
fn PdfDocument::pdf_annotation_json_import_destinations(
  self : PdfDocument,
  page_reference_numbers : ArrayView[Int],
  annotation : PdfObject,
) -> PdfObject raise PdfError {
  let mut rewritten = annotation
  match self.lookup_direct(pdf_annotation_p_key(), rewritten) {
    Some(PdfInteger(page_number)) =>
      rewritten = rewritten.add_dict_entry(
        pdf_annotation_p_key(),
        PdfIndirect(
          pdf_annotation_json_import_page_reference(
            page_reference_numbers, page_number,
          ),
        ),
      )
    _ => ()
  }
  match self.lookup_direct(pdf_annotation_dest_key(), rewritten) {
    Some(destination) =>
      rewritten = rewritten.add_dict_entry(
        pdf_annotation_dest_key(),
        pdf_annotation_json_import_destination(
          page_reference_numbers, destination,
        ),
      )
    None =>
      match self.lookup_direct(pdf_annotation_a_key(), rewritten) {
        Some(action) =>
          match self.lookup_direct(pdf_annotation_d_key(), action) {
            Some(destination) =>
              rewritten = rewritten.add_dict_entry(
                pdf_annotation_a_key(),
                action.add_dict_entry(
                  pdf_annotation_d_key(),
                  pdf_annotation_json_import_destination(
                    page_reference_numbers, destination,
                  ),
                ),
              )
            None => ()
          }
        None => ()
      }
  }
  rewritten
}

///|
fn PdfDocument::pdf_annotation_json_import_rows_for_page(
  self : PdfDocument,
  page_reference_numbers : ArrayView[Int],
  rows : ArrayView[PdfAnnotationJsonImportRow],
  page_number : Int,
) -> Array[PdfObject] raise PdfError {
  let imported : Array[PdfObject] = Array::new(capacity=rows.length())
  for row in rows {
    if row.page_number == page_number {
      self.add_object_given_number(
        row.object_number,
        self.pdf_annotation_json_import_destinations(
          page_reference_numbers,
          row.object,
        ),
      )
      imported.push(PdfIndirect(row.object_number))
    }
  }
  imported
}

///|
fn PdfDocument::pdf_annotation_json_import_pages(
  self : PdfDocument,
  rows : ArrayView[PdfAnnotationJsonImportRow],
) -> PdfDocument raise PdfError {
  if rows.length() == 0 {
    self.copy()
  } else {
    let page_reference_numbers = self.page_reference_numbers()
    let pages = self.pages_of_pagetree()
    let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
    for index, page in pages {
      let page_number = index + 1
      let imported = self.pdf_annotation_json_import_rows_for_page(
        page_reference_numbers, rows, page_number,
      )
      if imported.length() == 0 {
        rewritten.push(page)
      } else {
        let existing = match
          self.lookup_direct(pdf_annotation_annots_key(), page.rest) {
          Some(PdfArray(annotations)) => annotations
          _ => []
        }
        rewritten.push({
          ..page,
          rest: page.rest.add_dict_entry(
            pdf_annotation_annots_key(),
            PdfArray([..existing, ..imported]),
          ),
        })
      }
    }
    self.change_pages(rewritten, change_references=true)
  }
}

///|
/// Return a copy of the document with cpdf annotation JSON appended.
///
/// Existing objects are first renumbered above the imported annotation object
/// range, matching cpdf's collision-avoidance strategy. Header rows and other
/// nonpositive extra-object rows are ignored; positive extra objects are added
/// before page annotations are rebuilt.
pub fn PdfDocument::set_annotations_json(
  self : PdfDocument,
  json : Json,
) -> PdfDocument raise PdfError {
  let data = pdf_annotation_json_import_data(json)
  let document = self.pdf_annotation_json_import_renumbered(
    data.max_object_number,
  )
  for extra in data.extras {
    document.add_object_given_number(extra.0, extra.1)
  }
  document.pdf_annotation_json_import_pages(data.annotations)
}

///|
/// Compatibility wrapper for `PdfDocument::set_annotations_json`.
pub fn pdf_set_annotations_json(
  json : Json,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.set_annotations_json(json)
}

///|
/// Compatibility wrapper matching cpdfannot's `set_annotations_json` order.
pub fn pdf_set_annotations_json_cpdf_order(
  document : PdfDocument,
  json : Json,
) -> PdfDocument raise PdfError {
  document.set_annotations_json(json)
}

///|
/// Return a copy of this document with annotations copied from `source`.
pub fn PdfDocument::copy_annotations_from(
  self : PdfDocument,
  source : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  self.set_annotations_json(source.annotations_json(page_numbers))
}

///|
/// Compatibility wrapper for `PdfDocument::copy_annotations_from`.
pub fn pdf_copy_annotations(
  page_numbers : ArrayView[Int],
  source : PdfDocument,
  target : PdfDocument,
) -> PdfDocument raise PdfError {
  target.copy_annotations_from(source, page_numbers)
}

///|
/// Return a copy of the document with `/Annots` removed from selected pages.
pub fn PdfDocument::remove_annotations(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    pages.length(),
    "remove_annotations",
  )
  let selected_pages = @core.pdf_number_set(page_numbers)
  let rewritten : Array[@page.PdfPage] = Array::new(capacity=pages.length())
  for index, page in pages {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      rewritten.push({
        ..page,
        rest: page.rest.remove_dict_entry(pdf_annotation_annots_key()),
      })
    } else {
      rewritten.push(page)
    }
  }
  self.change_pages(rewritten, change_references=true)
}

///|
/// Compatibility wrapper for `PdfDocument::remove_annotations`.
pub fn pdf_remove_annotations(
  page_numbers : ArrayView[Int],
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.remove_annotations(page_numbers)
}
