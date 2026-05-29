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
fn PdfDocument::pdf_structure_object_has_deleted_page_in_set(
  self : PdfDocument,
  object : PdfObject,
  deleted_pages : @core.PdfNumberSet,
) -> Bool {
  match self.direct(object).lookup_immediate(pdf_structure_pg_key()) {
    Some(PdfIndirect(page_number)) => deleted_pages.contains(page_number)
    _ => false
  }
}

///|
fn PdfDocument::pdf_structure_indirect_survives_in_set(
  self : PdfDocument,
  object_number : Int,
  deleted_pages : @core.PdfNumberSet,
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
      (Some(page_number), _) if deleted_pages.contains(page_number) => false
      (_, Some(page_number)) if deleted_pages.contains(page_number) => false
      _ => true
    }
  }
}

///|
fn PdfDocument::pdf_structure_k_item_survives_in_set(
  self : PdfDocument,
  item : PdfObject,
  deleted_pages : @core.PdfNumberSet,
) -> Bool {
  match item {
    PdfIndirect(object_number) =>
      self.pdf_structure_indirect_survives_in_set(object_number, deleted_pages)
    _ => true
  }
}

///|
fn PdfDocument::pdf_structure_filter_k_items_in_set(
  self : PdfDocument,
  items : ArrayView[PdfObject],
  deleted_pages : @core.PdfNumberSet,
) -> Array[PdfObject]? {
  let output : Array[PdfObject] = Array::new(capacity=items.length())
  let mut changed = false
  for item in items {
    if self.pdf_structure_k_item_survives_in_set(item, deleted_pages) {
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
fn PdfDocument::pdf_structure_filtered_k_value_in_set(
  self : PdfDocument,
  object : PdfObject,
  deleted_pages : @core.PdfNumberSet,
) -> Array[PdfObject]? {
  match self.direct(object) {
    PdfDictionary(_) as dictionary =>
      match dictionary.lookup_immediate(pdf_structure_k_key()) {
        Some(PdfInteger(_)) => None
        Some(PdfIndirect(_) as child) =>
          self.pdf_structure_filter_k_items_in_set([child], deleted_pages)
        Some(PdfArray(children)) =>
          self.pdf_structure_filter_k_items_in_set(children, deleted_pages)
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
    let deleted_pages = @core.pdf_number_set(deleted_page_numbers)
    let mut changed = true
    while changed {
      changed = false
      let object_numbers = self.object_numbers()
      let deletions : Array[Int] = Array::new(capacity=object_numbers.length())
      let deletion_seen = @core.pdf_number_set([])
      for object_number in object_numbers {
        if self.pdf_structure_object_has_deleted_page_in_set(
            self.lookup_object_or_null(object_number),
            deleted_pages,
          ) {
          @core.pdf_push_unique_number(deletions, deletion_seen, object_number)
        }
      }
      for object_number in deletions {
        if self.lookup_object_or_null(object_number) != PdfNull {
          self.remove_object(object_number)
          changed = true
        }
      }
      let object_numbers = self.object_numbers()
      let replacements : Array[(Int, PdfObject)] = Array::new(
        capacity=object_numbers.length(),
      )
      for object_number in object_numbers {
        let object = self.lookup_object_or_null(object_number)
        match
          self.pdf_structure_filtered_k_value_in_set(object, deleted_pages) {
          Some([]) =>
            @core.pdf_push_unique_number(
              deletions, deletion_seen, object_number,
            )
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
/// Trim structure-tree entries that point to pages outside the selected pages.
///
/// `page_numbers` uses the same page-selection numbering as the page helpers.
/// The document is mutated in place by deleting structure objects tied to
/// removed pages and pruning `/K` arrays that reference them.
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

///|
/// Compatibility wrapper for `PdfDocument::trim_structure_tree`.
pub fn pdf_trim_structure_tree(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  document.trim_structure_tree(page_numbers)
}
