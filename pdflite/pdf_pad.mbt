///|
fn pdf_pad_name(text : String) -> @core.PdfName {
  @core.pdf_name_of_bytes(@ascii.encode(text))
}

///|
let pdf_pad_annots_key_name : @core.PdfName = pdf_pad_name("/Annots")

///|
fn pdf_pad_annots_key() -> @core.PdfName {
  pdf_pad_annots_key_name
}

///|
fn pdf_pad_sorted_page_numbers(
  page_numbers : ArrayView[Int],
  end_page : Int,
  context : String,
) -> Array[Int] raise @core.PdfError {
  let sorted : Array[Int] = Array::new(capacity=page_numbers.length())
  for page_number in page_numbers {
    sorted.push(page_number)
  }
  sorted.sort()
  for page_number in sorted {
    if page_number < 1 || page_number > end_page {
      raise BadPageSpecification(
        context + ": range contains pages not present in pdf",
      )
    }
  }
  sorted
}

///|
fn pdf_pad_unique_sorted_page_numbers(
  page_numbers : ArrayView[Int],
  end_page : Int,
  context : String,
) -> Array[Int] raise @core.PdfError {
  let sorted = pdf_pad_sorted_page_numbers(page_numbers, end_page, context)
  let unique : Array[Int] = Array::new(capacity=sorted.length())
  for page_number in sorted {
    if unique.length() == 0 || unique[unique.length() - 1] != page_number {
      unique.push(page_number)
    }
  }
  unique
}

///|
fn pdf_pad_insert_positions(
  page_numbers : ArrayView[Int],
  before : Bool,
) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=page_numbers.length())
  for page_number in page_numbers {
    output.push(if before { page_number - 1 } else { page_number })
  }
  output
}

///|
fn pdf_pad_blank_page(
  page : @page.PdfPage,
) -> @page.PdfPage raise @core.PdfError {
  {
    content: [],
    mediabox: page.mediabox,
    resources: PdfDictionary([]),
    rotate: page.rotate,
    rest: page.rest.remove_dict_entry(pdf_pad_annots_key()),
  }
}

///|
fn pdf_pad_blank_pages(
  pages : ArrayView[@page.PdfPage],
  positions : ArrayView[Int],
  before : Bool,
) -> Array[@page.PdfPage] raise @core.PdfError {
  let output : Array[@page.PdfPage] = Array::new(capacity=positions.length())
  for position in positions {
    let page_index = if before { position } else { position - 1 }
    output.push(pdf_pad_blank_page(pages[page_index]))
  }
  output
}

///|
fn pdf_pad_inserted_page_count(
  inserted_pages : ArrayView[Array[@page.PdfPage]],
) -> Int {
  let mut count = 0
  for inserted in inserted_pages {
    count += inserted.length()
  }
  count
}

///|
fn pdf_pad_insert_pages(
  pages : ArrayView[@page.PdfPage],
  positions : ArrayView[Int],
  inserted_pages : ArrayView[Array[@page.PdfPage]],
) -> Array[@page.PdfPage] {
  let output : Array[@page.PdfPage] = Array::new(
    capacity=pages.length() + pdf_pad_inserted_page_count(inserted_pages),
  )
  let mut insertion = 0
  while insertion < positions.length() && positions[insertion] == 0 {
    for page in inserted_pages[insertion] {
      output.push(page)
    }
    insertion += 1
  }
  for index in 0..<pages.length() {
    output.push(pages[index])
    let position = index + 1
    while insertion < positions.length() && positions[insertion] == position {
      for page in inserted_pages[insertion] {
        output.push(page)
      }
      insertion += 1
    }
  }
  output
}

///|
fn pdf_pad_change_table(
  original_count : Int,
  positions : ArrayView[Int],
) -> Array[(Int, Int)] {
  let changes : Array[(Int, Int)] = Array::new(capacity=original_count)
  let mut insertion = 0
  for old_page in 1..<=original_count {
    while insertion < positions.length() && positions[insertion] < old_page {
      insertion += 1
    }
    changes.push((old_page, old_page + insertion))
  }
  changes
}

///|
fn pdf_pad_page_number_range(count : Int) -> Array[Int] {
  let output : Array[Int] = Array::new(
    capacity=if count > 0 { count } else { 0 },
  )
  for page_number in 1..<=count {
    output.push(page_number)
  }
  output
}

///|
fn PdfDocument::pdf_pad_with_blank_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  before : Bool,
  context : String,
) -> PdfDocument raise @core.PdfError {
  let end_page = self.endpage()
  let sorted = pdf_pad_sorted_page_numbers(page_numbers, end_page, context)
  let positions = pdf_pad_insert_positions(sorted, before)
  let pages = self.pages_of_pagetree()
  let blank_pages = pdf_pad_blank_pages(pages, positions, before)
  let inserted : Array[Array[@page.PdfPage]] = Array::new(
    capacity=blank_pages.length(),
  )
  for page in blank_pages {
    let single : Array[@page.PdfPage] = Array::new(capacity=1)
    single.push(page)
    inserted.push(single)
  }
  self.change_pages(
    pdf_pad_insert_pages(pages, positions, inserted),
    change_references=true,
    changes=pdf_pad_change_table(pages.length(), positions),
  )
}

///|
fn PdfDocument::pdf_pad_with_document(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  before : Bool,
  pad_document : PdfDocument,
  context : String,
) -> PdfDocument raise @core.PdfError {
  let end_page = self.endpage()
  let sorted = pdf_pad_unique_sorted_page_numbers(
    page_numbers, end_page, context,
  )
  let positions = pdf_pad_insert_positions(sorted, before)
  let pad_end_page = pad_document.endpage()
  let merged = pdf_merge_pdfs(false, false, ["a", "b"], [self, pad_document], [
    pdf_pad_page_number_range(end_page),
    pdf_pad_page_number_range(pad_end_page),
  ])
  let pages = merged.pages_of_pagetree()
  let original_pages : Array[@page.PdfPage] = Array::new(capacity=end_page)
  let pad_pages : Array[@page.PdfPage] = Array::new(capacity=pad_end_page)
  for index in 0..<pages.length() {
    if index < end_page {
      original_pages.push(pages[index])
    } else {
      pad_pages.push(pages[index])
    }
  }
  let inserted : Array[Array[@page.PdfPage]] = Array::new(
    capacity=positions.length(),
  )
  for _ in positions {
    let copy : Array[@page.PdfPage] = Array::new(capacity=pad_pages.length())
    for page in pad_pages {
      copy.push(page)
    }
    inserted.push(copy)
  }
  merged.change_pages(pdf_pad_insert_pages(original_pages, positions, inserted))
}

///|
fn PdfDocument::pdf_pad_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  before : Bool,
  pad_with : PdfDocument?,
  context : String,
) -> PdfDocument raise @core.PdfError {
  match pad_with {
    Some(pad_document) =>
      self.pdf_pad_with_document(page_numbers, before, pad_document, context)
    None => self.pdf_pad_with_blank_pages(page_numbers, before, context)
  }
}

///|
/// Insert blank pages or pages from `pad_with` after selected one-based pages.
pub fn PdfDocument::pad_after(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  pad_with? : PdfDocument? = None,
) -> PdfDocument raise @core.PdfError {
  self.pdf_pad_pages(page_numbers, false, pad_with, "padafter")
}

///|
/// Compatibility wrapper for `PdfDocument::pad_after`.
pub fn pdf_pad_after(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  pad_with? : PdfDocument? = None,
) -> PdfDocument raise @core.PdfError {
  document.pad_after(page_numbers, pad_with~)
}

///|
/// Source-spelled cpdfpad `padafter` wrapper with cpdf argument order.
pub fn pdf_padafter(
  page_numbers : ArrayView[Int],
  document : PdfDocument,
  pad_with? : PdfDocument? = None,
) -> PdfDocument raise @core.PdfError {
  document.pad_after(page_numbers, pad_with~)
}

///|
/// Insert blank pages or pages from `pad_with` before selected one-based pages.
pub fn PdfDocument::pad_before(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  pad_with? : PdfDocument? = None,
) -> PdfDocument raise @core.PdfError {
  self.pdf_pad_pages(page_numbers, true, pad_with, "padbefore")
}

///|
/// Compatibility wrapper for `PdfDocument::pad_before`.
pub fn pdf_pad_before(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  pad_with? : PdfDocument? = None,
) -> PdfDocument raise @core.PdfError {
  document.pad_before(page_numbers, pad_with~)
}

///|
/// Source-spelled cpdfpad `padbefore` wrapper with cpdf argument order.
pub fn pdf_padbefore(
  page_numbers : ArrayView[Int],
  document : PdfDocument,
  pad_with? : PdfDocument? = None,
) -> PdfDocument raise @core.PdfError {
  document.pad_before(page_numbers, pad_with~)
}

///|
fn pdf_pad_multiple_blank_page(page : @page.PdfPage) -> @page.PdfPage {
  {
    content: [],
    mediabox: page.mediabox,
    resources: PdfDictionary([]),
    rotate: page.rotate,
    rest: PdfDictionary([]),
  }
}

///|
/// Pad a document to a page count that is a multiple of `multiple`.
///
/// Positive multiples append blank pages. Negative multiples prepend them. A
/// multiple of zero is invalid.
pub fn PdfDocument::pad_to_multiple(
  self : PdfDocument,
  multiple : Int,
) -> PdfDocument raise @core.PdfError {
  if multiple == 0 {
    raise BadNumberArgument("pad_to_multiple: zero multiple")
  }
  let prepend = multiple < 0
  let size = if prepend { -multiple } else { multiple }
  let pages = self.pages_of_pagetree()
  if pages.length() == 0 {
    self
  } else {
    let remainder = pages.length() % size
    let pages_to_add = if remainder == 0 { 0 } else { size - remainder }
    if pages_to_add == 0 {
      self
    } else {
      let blank = pdf_pad_multiple_blank_page(pages[pages.length() - 1])
      let blanks : Array[@page.PdfPage] = Array::new(capacity=pages_to_add)
      for _ in 0..<pages_to_add {
        blanks.push(blank)
      }
      let padded : Array[@page.PdfPage] = Array::new(
        capacity=pages.length() + blanks.length(),
      )
      if prepend {
        for page in blanks {
          padded.push(page)
        }
        for page in pages {
          padded.push(page)
        }
      } else {
        for page in pages {
          padded.push(page)
        }
        for page in blanks {
          padded.push(page)
        }
      }
      let changes : Array[(Int, Int)] = Array::new(capacity=pages.length())
      if prepend {
        for old_page in 1..<=pages.length() {
          changes.push((old_page, old_page + pages_to_add))
        }
      } else {
        for old_page in 1..<=pages.length() {
          changes.push((old_page, old_page))
        }
      }
      self.change_pages(padded, change_references=true, changes~)
    }
  }
}

///|
/// Compatibility wrapper for `PdfDocument::pad_to_multiple`.
pub fn pdf_pad_to_multiple(
  document : PdfDocument,
  multiple : Int,
) -> PdfDocument raise @core.PdfError {
  document.pad_to_multiple(multiple)
}

///|
/// Source-spelled cpdfpad `padmultiple` wrapper with cpdf argument order.
pub fn pdf_padmultiple(
  multiple : Int,
  document : PdfDocument,
) -> PdfDocument raise @core.PdfError {
  document.pad_to_multiple(multiple)
}
