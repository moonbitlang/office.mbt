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
  let seen = @core.pdf_number_set([])
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
