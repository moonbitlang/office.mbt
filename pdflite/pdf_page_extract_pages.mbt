///|
fn pdf_page_select_pages(
  pages : ArrayView[PdfPage],
  page_numbers : ArrayView[Int],
) -> Array[PdfPage] raise PdfError {
  if page_numbers.length() == 0 {
    raise PageTreeExpected
  }
  let selected : Array[PdfPage] = Array::new(capacity=page_numbers.length())
  for page_number in page_numbers {
    if page_number < 1 || page_number > pages.length() {
      raise PageTreeExpected
    }
    selected.push(pages[page_number - 1])
  }
  selected
}

///|
fn pdf_page_select_numbers(
  numbers : ArrayView[Int],
  page_numbers : ArrayView[Int],
) -> Array[Int] raise PdfError {
  if page_numbers.length() == 0 {
    raise PageTreeExpected
  }
  let selected : Array[Int] = Array::new(capacity=page_numbers.length())
  for page_number in page_numbers {
    if page_number < 1 || page_number > numbers.length() {
      raise PageTreeExpected
    }
    selected.push(numbers[page_number - 1])
  }
  selected
}

///|
fn pdf_page_number_index(numbers : ArrayView[Int], number : Int) -> Int? {
  for i in 0..<numbers.length() {
    if numbers[i] == number {
      break Some(i)
    }
  } nobreak {
    None
  }
}

///|
fn PdfDocument::pdf_page_annotation_numbers(
  self : PdfDocument,
  page_object : PdfObject,
) -> Array[Int] {
  let annots_object = match
    page_object.lookup_immediate(pdf_page_annots_key()) {
    Some(PdfIndirect(number)) => self.lookup_object_or_null(number)
    Some(value) => value
    None => PdfNull
  }
  match annots_object {
    PdfArray(items) => {
      let numbers : Array[Int] = Array::new(capacity=items.length())
      for item in items {
        match item {
          PdfIndirect(number) => numbers.push(number)
          _ => ()
        }
      }
      numbers
    }
    _ => []
  }
}

///|
fn pdf_page_fixup_annotation_link(
  object : PdfObject,
  key : PdfName,
  old_numbers : ArrayView[Int],
  new_numbers : ArrayView[Int],
) -> PdfObject raise PdfError {
  match object.lookup_immediate(key) {
    Some(PdfIndirect(old_number)) =>
      match pdf_page_number_index(old_numbers, old_number) {
        Some(index) =>
          object.add_dict_entry(key, PdfIndirect(new_numbers[index]))
        None => object
      }
    _ => object
  }
}

///|
fn PdfDocument::pdf_page_fixup_annotation_links(
  self : PdfDocument,
  old_numbers : ArrayView[Int],
  new_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  for number in new_numbers {
    let object = self.lookup_object_or_null(number)
    let with_popup = pdf_page_fixup_annotation_link(
      object,
      pdf_page_popup_key(),
      old_numbers,
      new_numbers,
    )
    let with_parent = pdf_page_fixup_annotation_link(
      with_popup,
      pdf_page_parent_key(),
      old_numbers,
      new_numbers,
    )
    if with_parent != object {
      self.add_object_given_number(number, with_parent)
    }
  }
}

///|
fn PdfDocument::pdf_page_fixup_duplicate_annots(
  self : PdfDocument,
) -> Unit raise PdfError {
  let page_numbers = self.page_reference_numbers()
  let existing_annots : Array[Array[Int]] = Array::new(
    capacity=page_numbers.length(),
  )
  for page_number in page_numbers {
    existing_annots.push(
      self.pdf_page_annotation_numbers(self.lookup_object_or_null(page_number)),
    )
  }
  let seen = @number_set.pdf_number_set([])
  let new_annots : Array[Array[Int]] = Array::new(
    capacity=existing_annots.length(),
  )
  for annots in existing_annots {
    let page_annots : Array[Int] = Array::new(capacity=annots.length())
    for annotation_number in annots {
      if seen.contains(annotation_number) {
        page_annots.push(
          self.add_object(self.lookup_object_or_null(annotation_number)),
        )
      } else {
        page_annots.push(annotation_number)
      }
    }
    for annotation_number in annots {
      seen.add(annotation_number)
    }
    for annotation_number in page_annots {
      seen.add(annotation_number)
    }
    new_annots.push(page_annots)
  }
  for i in 0..<new_annots.length() {
    let annots = new_annots[i]
    if annots.length() > 0 {
      self.pdf_page_fixup_annotation_links(existing_annots[i], annots)
      self.add_object_given_number(
        page_numbers[i],
        self
        .lookup_object_or_null(page_numbers[i])
        .add_dict_entry(
          pdf_page_annots_key(),
          PdfArray([ for number in annots => PdfIndirect(number) ]),
        ),
      )
    }
  }
}

///|
fn PdfDocument::pdf_page_destination_was_nulled(
  self : PdfDocument,
  destination : PdfObject,
) -> Bool {
  match self.direct(destination) {
    PdfArray(items) if items.length() > 0 =>
      match items[0] {
        PdfNull => true
        PdfIndirect(number) => self.lookup_object_or_null(number) == PdfNull
        _ => false
      }
    _ => false
  }
}

///|
fn PdfDocument::pdf_page_live_destinations(
  self : PdfDocument,
  dests_tree : PdfObject,
) -> Array[(PdfBytes, PdfObject)] {
  let entries = self.read_name_tree(dests_tree)
  let output : Array[(PdfBytes, PdfObject)] = Array::new(
    capacity=entries.length(),
  )
  for entry in entries {
    let (_, destination) = entry
    if !self.pdf_page_destination_was_nulled(destination) {
      output.push(entry)
    }
  }
  output
}

///|
fn PdfDocument::pdf_page_live_catalog_destinations(
  self : PdfDocument,
  dests : PdfObject,
) -> PdfObject {
  match dests {
    PdfDictionary(entries) => {
      let output : Array[(PdfName, PdfObject)] = Array::new(
        capacity=entries.length(),
      )
      for entry in entries {
        let (_, destination) = entry
        if !self.pdf_page_destination_was_nulled(destination) {
          output.push(entry)
        }
      }
      PdfDictionary(output)
    }
    _ => dests
  }
}

///|
fn PdfDocument::pdf_page_fixup_catalog_destinations(
  self : PdfDocument,
) -> Unit raise PdfError {
  match self.pdf_page_active_catalog() {
    Some((root_object, uses_trailer_root)) =>
      match root_object.lookup_immediate(pdf_page_dests_key()) {
        Some(PdfIndirect(dests_number)) =>
          self.add_object_given_number(
            dests_number,
            self.pdf_page_live_catalog_destinations(
              self.lookup_object_or_null(dests_number),
            ),
          )
        Some(dests) =>
          self.pdf_page_replace_active_catalog_entry(
            pdf_page_dests_key(),
            self.pdf_page_live_catalog_destinations(dests),
            root_object,
            uses_trailer_root,
          )
        None => ()
      }
    None => ()
  }
}

///|
fn PdfDocument::pdf_page_fixup_destination_name_tree(
  self : PdfDocument,
) -> Unit raise PdfError {
  match self.pdf_page_active_catalog() {
    Some((root_object, uses_trailer_root)) =>
      match root_object.lookup_immediate(pdf_page_names_key()) {
        Some(PdfIndirect(names_number)) => {
          let names_object = self.lookup_object_or_null(names_number)
          match self.lookup_direct(pdf_page_dests_key(), names_object) {
            Some(dests_tree) =>
              self.add_object_given_number(
                names_number,
                names_object.add_dict_entry(
                  pdf_page_dests_key(),
                  self.build_name_tree(
                    self.pdf_page_live_destinations(dests_tree),
                  ),
                ),
              )
            None => ()
          }
        }
        Some(PdfDictionary(_) as names_object) =>
          match self.lookup_direct(pdf_page_dests_key(), names_object) {
            Some(dests_tree) =>
              self.pdf_page_replace_active_catalog_entry(
                pdf_page_names_key(),
                names_object.add_dict_entry(
                  pdf_page_dests_key(),
                  self.build_name_tree(
                    self.pdf_page_live_destinations(dests_tree),
                  ),
                ),
                root_object,
                uses_trailer_root,
              )
            None => ()
          }
        _ => ()
      }
    _ => ()
  }
}

///|
fn pdf_page_root_pages_number(pdf : PdfDocument) -> Int raise PdfError {
  let root = match pdf.pdf_page_active_catalog() {
    Some((catalog, _)) => catalog
    None => raise RootExpected
  }
  match root.lookup_immediate(pdf_page_pages_key()) {
    Some(PdfIndirect(number)) => number
    _ => raise PageTreeExpected
  }
}

///|
fn PdfDocument::pdf_page_tree_nodes_not_pages_inner(
  self : PdfDocument,
  node : PdfObject,
  node_number : Int,
  depth : Int,
) -> Array[Int] raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  match self.lookup_direct(pdf_page_type_key(), node) {
    Some(PdfNameObject(name)) if name == pdf_page_type_page() => []
    _ =>
      match self.lookup_direct(pdf_page_kids_key(), node) {
        Some(PdfArray(kids)) => {
          let nodes : Array[Int] = Array::new(capacity=kids.length() + 1)
          nodes.push(node_number)
          for kid in kids {
            match kid {
              PdfIndirect(number) =>
                for
                  nested in self.pdf_page_tree_nodes_not_pages_inner(
                    self.direct(kid),
                    number,
                    depth + 1,
                  ) {
                  nodes.push(nested)
                }
              _ => ()
            }
          }
          nodes
        }
        _ => []
      }
  }
}

///|
fn PdfDocument::pdf_page_tree_nodes_not_pages(
  self : PdfDocument,
) -> Array[Int] raise PdfError {
  let pages_number = pdf_page_root_pages_number(self)
  self.pdf_page_tree_nodes_not_pages_inner(
    self.lookup_object_or_null(pages_number),
    pages_number,
    0,
  )
}

///|
fn PdfDocument::pdf_page_reference_numbers_unordered_inner(
  self : PdfDocument,
  node : PdfObject,
  node_number : Int,
  depth : Int,
) -> Array[Int] raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  match self.lookup_direct(pdf_page_type_key(), node) {
    Some(PdfNameObject(name)) if name == pdf_page_type_page() => [node_number]
    _ =>
      match self.lookup_direct(pdf_page_kids_key(), node) {
        Some(PdfArray(kids)) => {
          let numbers : Array[Int] = Array::new(capacity=kids.length())
          for kid in kids {
            match kid {
              PdfIndirect(number) =>
                for
                  page_number in self.pdf_page_reference_numbers_unordered_inner(
                    self.direct(kid),
                    number,
                    depth + 1,
                  ) {
                  numbers.push(page_number)
                }
              _ => ()
            }
          }
          numbers
        }
        _ => [node_number]
      }
  }
}

///|
fn PdfDocument::pdf_page_reference_numbers_unordered(
  self : PdfDocument,
) -> Array[Int] raise PdfError {
  let pages_number = pdf_page_root_pages_number(self)
  self.pdf_page_reference_numbers_unordered_inner(
    self.lookup_object_or_null(pages_number),
    pages_number,
    0,
  )
}

///|
fn pdf_page_first_duplicate_number(numbers : ArrayView[Int]) -> Int? {
  let sorted = numbers.to_owned()
  sorted.sort()
  for i in 1..<sorted.length() {
    if sorted[i - 1] == sorted[i] {
      break Some(sorted[i])
    }
  } nobreak {
    None
  }
}

///|
fn pdf_page_rewrite_first_kid(
  kids : ArrayView[PdfObject],
  old_number : Int,
  new_number : Int,
) -> (Array[PdfObject], Bool) {
  let output : Array[PdfObject] = Array::new(capacity=kids.length())
  let mut rewritten = false
  for kid in kids {
    match kid {
      PdfIndirect(number) if !rewritten && number == old_number => {
        output.push(PdfIndirect(new_number))
        rewritten = true
      }
      _ => output.push(kid)
    }
  }
  (output, rewritten)
}

///|
fn PdfDocument::pdf_page_rewrite_first_indirect(
  self : PdfDocument,
  node_number : Int,
  old_number : Int,
  new_number : Int,
) -> Bool raise PdfError {
  let node = self.lookup_object_or_null(node_number)
  match node.lookup_immediate(pdf_page_kids_key()) {
    Some(PdfArray(kids)) => {
      let (rewritten_kids, rewritten) = pdf_page_rewrite_first_kid(
        kids, old_number, new_number,
      )
      if rewritten {
        self.add_object_given_number(
          node_number,
          node.add_dict_entry(pdf_page_kids_key(), PdfArray(rewritten_kids)),
        )
      }
      rewritten
    }
    _ => false
  }
}

///|
fn PdfDocument::pdf_page_rewrite_page_tree_first(
  self : PdfDocument,
  nodes : ArrayView[Int],
  page_number : Int,
) -> Unit raise PdfError {
  let new_number = self.add_object(self.lookup_object_or_null(page_number))
  let mut rewritten = false
  for node_number in nodes {
    if !rewritten {
      rewritten = self.pdf_page_rewrite_first_indirect(
        node_number, page_number, new_number,
      )
    }
  }
  if !rewritten {
    self.remove_object(new_number)
    raise PageTreeExpected
  }
}

///|
fn PdfDocument::pdf_page_fixup_duplicate_pages(
  self : PdfDocument,
) -> Unit raise PdfError {
  let nodes = self.pdf_page_tree_nodes_not_pages()
  let mut done = false
  while !done {
    match
      pdf_page_first_duplicate_number(
        self.pdf_page_reference_numbers_unordered(),
      ) {
      Some(page_number) =>
        self.pdf_page_rewrite_page_tree_first(nodes, page_number)
      None => done = true
    }
  }
}

///|
fn PdfDocument::pdf_page_fixup_parents_inner(
  self : PdfDocument,
  parent_number : Int,
  node_number : Int,
  depth : Int,
) -> Unit raise PdfError {
  if depth > 10000 {
    raise PageTreeExpected
  }
  let node = self.lookup_object_or_null(node_number)
  match node.lookup_immediate(pdf_page_parent_key()) {
    Some(PdfIndirect(_)) =>
      self.add_object_given_number(
        node_number,
        node.add_dict_entry(pdf_page_parent_key(), PdfIndirect(parent_number)),
      )
    _ => ()
  }
  match self.lookup_direct(pdf_page_kids_key(), node) {
    Some(PdfArray(kids)) =>
      for kid in kids {
        match kid {
          PdfIndirect(number) =>
            self.pdf_page_fixup_parents_inner(node_number, number, depth + 1)
          _ => ()
        }
      }
    _ => ()
  }
}

///|
fn PdfDocument::pdf_page_fixup_parents(
  self : PdfDocument,
) -> Unit raise PdfError {
  self.pdf_page_fixup_parents_inner(0, pdf_page_root_pages_number(self), 0)
}

///|
fn pdf_page_inheritable_keys() -> Array[PdfName] {
  [
    pdf_page_mediabox_key(),
    pdf_page_cropbox_key(),
    pdf_page_rotate_key(),
    pdf_page_resources_key(),
  ]
}

///|
fn PdfDocument::pdf_page_preserve_materialized_inherited_entries(
  self : PdfDocument,
  source : PdfDocument,
  old_page_numbers : ArrayView[Int],
  new_page_numbers : ArrayView[Int],
) -> Unit raise PdfError {
  for index in 0..<old_page_numbers.length() {
    let old_page = source.lookup_object_or_null(old_page_numbers[index])
    let new_page_number = new_page_numbers[index]
    let original = self.lookup_object_or_null(new_page_number)
    let mut updated = original
    for key in pdf_page_inheritable_keys() {
      match old_page.lookup_immediate(key) {
        Some(value) => updated = updated.add_dict_entry(key, value)
        None => ()
      }
    }
    if updated != original {
      self.add_object_given_number(new_page_number, updated)
    }
  }
}

///|
/// Extract selected pages into a new document.
///
/// `page_numbers` are 1-based. Bookmarks, destinations, annotations, and page
/// labels are repaired for the retained pages where possible. `retain_numbering`
/// preserves original page-label numbering; `process_struct_tree` trims tagged
/// structure references to deleted pages.
pub fn PdfDocument::pdf_of_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  retain_numbering? : Bool = false,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  let source = self.copy()
  let all_page_numbers = source.page_reference_numbers()
  let old_page_numbers = pdf_page_select_numbers(all_page_numbers, page_numbers)
  source.replace_inherit(old_page_numbers)
  let has_page_labels = source.pdf_page_label_has_labels()
  let retained_page_labels = if retain_numbering && has_page_labels {
    pdf_page_label_merge([source], [
      [
        for page_number in page_numbers => page_number
      ],
    ])
  } else {
    []
  }
  let has_bookmarks = source.pdf_bookmark_has_outlines()
  let retained_bookmarks = if has_bookmarks {
    source.pdf_bookmarks_for_pages(page_numbers) catch {
      _ => []
    }
  } else {
    []
  }
  let selected = pdf_page_select_pages(source.pages_of_pagetree(), page_numbers)
  let deleted_page_numbers = if process_struct_tree {
    pdf_page_deleted_numbers(all_page_numbers, old_page_numbers)
  } else {
    []
  }
  let pdf = source.change_pages(selected)
  let pdf = if has_bookmarks {
    pdf.add_bookmarks(retained_bookmarks)
  } else {
    pdf
  }
  let new_page_numbers = pdf.page_reference_numbers()
  pdf.pdf_page_preserve_materialized_inherited_entries(
    source, old_page_numbers, new_page_numbers,
  )
  pdf.pdf_page_renumber_references(
    pdf_page_reference_changes(old_page_numbers, new_page_numbers),
  )
  if process_struct_tree {
    pdf.pdf_structure_trim_deleted_pages(deleted_page_numbers)
  }
  pdf.pdf_page_fixup_duplicate_pages()
  pdf.pdf_page_fixup_parents()
  pdf.pdf_page_fixup_duplicate_annots()
  pdf.remove_unreferenced()
  pdf.pdf_page_fixup_destination_name_tree()
  pdf.pdf_page_fixup_catalog_destinations()
  let pdf = if has_page_labels {
    if retain_numbering {
      pdf.write_page_labels(retained_page_labels)
    } else {
      pdf.remove_page_labels()
    }
  } else {
    pdf
  }
  pdf.remove_unreferenced()
  pdf
}

///|
/// Compatibility wrapper for `PdfDocument::pdf_of_pages`.
pub fn pdf_of_pages(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  retain_numbering? : Bool = false,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  document.pdf_of_pages(page_numbers, retain_numbering~, process_struct_tree~)
}

///|
fn pdf_page_deleted_numbers(
  all_page_numbers : ArrayView[Int],
  active_page_numbers : ArrayView[Int],
) -> Array[Int] {
  let active_pages = @number_set.pdf_number_set(active_page_numbers)
  let deleted : Array[Int] = Array::new(capacity=all_page_numbers.length())
  for number in all_page_numbers {
    if !active_pages.contains(number) {
      deleted.push(number)
    }
  }
  deleted
}
