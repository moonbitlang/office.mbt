///|
fn pdf_structure_name(text : String) -> PdfName {
  pdf_name_of_bytes(@ascii.encode(text))
}

///|
fn pdf_structure_pg_key() -> PdfName {
  pdf_structure_name("/Pg")
}

///|
fn pdf_structure_obj_key() -> PdfName {
  pdf_structure_name("/Obj")
}

///|
fn pdf_structure_k_key() -> PdfName {
  pdf_structure_name("/K")
}

///|
fn pdf_structure_number_member(numbers : ArrayView[Int], number : Int) -> Bool {
  for candidate in numbers {
    if candidate == number {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_structure_push_unique(numbers : Array[Int], number : Int) -> Unit {
  if !pdf_structure_number_member(numbers, number) {
    numbers.push(number)
  }
}

///|
fn PdfDocument::pdf_structure_indirect_number(
  self : PdfDocument,
  object_number : Int,
  key : PdfName,
) -> Int? {
  match self.direct(PdfIndirect(object_number)).lookup_immediate(key) {
    Some(PdfIndirect(number)) => Some(number)
    _ => None
  }
}

///|
fn PdfDocument::pdf_structure_object_has_deleted_page(
  self : PdfDocument,
  object : PdfObject,
  deleted_page_numbers : ArrayView[Int],
) -> Bool {
  match self.direct(object).lookup_immediate(pdf_structure_pg_key()) {
    Some(PdfIndirect(page_number)) =>
      pdf_structure_number_member(deleted_page_numbers, page_number)
    _ => false
  }
}

///|
fn PdfDocument::pdf_structure_indirect_survives(
  self : PdfDocument,
  object_number : Int,
  deleted_page_numbers : ArrayView[Int],
) -> Bool {
  if self.lookup_object_or_null(object_number) == PdfNull {
    false
  } else {
    match
      (
        self.pdf_structure_indirect_number(
          object_number,
          pdf_structure_pg_key(),
        ),
        self.pdf_structure_indirect_number(
          object_number,
          pdf_structure_obj_key(),
        ),
      ) {
      (Some(page_number), _) if pdf_structure_number_member(
          deleted_page_numbers, page_number,
        ) => false
      (_, Some(page_number)) if pdf_structure_number_member(
          deleted_page_numbers, page_number,
        ) => false
      _ => true
    }
  }
}

///|
fn PdfDocument::pdf_structure_k_item_survives(
  self : PdfDocument,
  item : PdfObject,
  deleted_page_numbers : ArrayView[Int],
) -> Bool {
  match item {
    PdfIndirect(object_number) =>
      self.pdf_structure_indirect_survives(object_number, deleted_page_numbers)
    _ => true
  }
}

///|
fn PdfDocument::pdf_structure_filter_k_items(
  self : PdfDocument,
  items : ArrayView[PdfObject],
  deleted_page_numbers : ArrayView[Int],
) -> Array[PdfObject]? {
  let output : Array[PdfObject] = []
  let mut changed = false
  for item in items {
    if self.pdf_structure_k_item_survives(item, deleted_page_numbers) {
      output.push(item)
    } else {
      changed = true
    }
  }
  if changed {
    Some(output)
  } else {
    None
  }
}

///|
fn PdfDocument::pdf_structure_filtered_k_value(
  self : PdfDocument,
  object : PdfObject,
  deleted_page_numbers : ArrayView[Int],
) -> Array[PdfObject]? {
  match self.direct(object) {
    PdfDictionary(_) as dictionary =>
      match dictionary.lookup_immediate(pdf_structure_k_key()) {
        Some(PdfInteger(_)) => None
        Some(PdfIndirect(_) as child) =>
          self.pdf_structure_filter_k_items([child], deleted_page_numbers)
        Some(PdfArray(children)) =>
          self.pdf_structure_filter_k_items(children, deleted_page_numbers)
        _ => None
      }
    _ => None
  }
}

///|
fn pdf_structure_k_object(items : ArrayView[PdfObject]) -> PdfObject {
  if items.length() == 1 {
    items[0]
  } else {
    PdfArray([ for item in items => item ])
  }
}

///|
fn PdfDocument::pdf_structure_trim_deleted_pages(
  self : PdfDocument,
  deleted_page_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  if deleted_page_numbers.length() > 0 {
    let mut changed = true
    while changed {
      changed = false
      let deletions : Array[Int] = []
      for object_number in self.object_numbers() {
        if self.pdf_structure_object_has_deleted_page(
            self.lookup_object_or_null(object_number),
            deleted_page_numbers,
          ) {
          pdf_structure_push_unique(deletions, object_number)
        }
      }
      for object_number in deletions {
        if self.lookup_object_or_null(object_number) != PdfNull {
          self.remove_object(object_number)
          changed = true
        }
      }
      let replacements : Array[(Int, PdfObject)] = []
      for object_number in self.object_numbers() {
        let object = self.lookup_object_or_null(object_number)
        match
          self.pdf_structure_filtered_k_value(object, deleted_page_numbers) {
          Some([]) => pdf_structure_push_unique(deletions, object_number)
          Some(filtered) =>
            replacements.push(
              (
                object_number,
                object.replace_dict_entry(
                  pdf_structure_k_key(),
                  pdf_structure_k_object(filtered),
                ),
              ),
            )
          None => ()
        }
      }
      for object_number in deletions {
        if self.lookup_object_or_null(object_number) != PdfNull {
          self.remove_object(object_number)
          changed = true
        }
      }
      for replacement in replacements {
        let (object_number, object) = replacement
        if self.lookup_object_or_null(object_number) != PdfNull {
          self.add_object_given_number(object_number, object)
          changed = true
        }
      }
    }
  }
}

///|
pub fn PdfDocument::trim_structure_tree(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  let all_page_numbers = self.page_reference_numbers()
  let kept_page_numbers = pdf_page_select_numbers(
    all_page_numbers, page_numbers,
  )
  self.pdf_structure_trim_deleted_pages(
    pdf_page_deleted_numbers(all_page_numbers, kept_page_numbers),
  )
}
