///|
fn pdf_chop_rectangle_object(
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @syntax.PdfObject {
  PdfArray([PdfReal(min_x), PdfReal(min_y), PdfReal(max_x), PdfReal(max_y)])
}

///|
fn pdf_chop_box(
  document : PdfDocument,
  page : @page.PdfPage,
) -> @geometry.PdfRectangle raise PdfError {
  match document.lookup_direct(pdf_chop_cropbox_key(), page.rest) {
    Some(cropbox) => document.parse_rectangle(cropbox)
    None => document.parse_rectangle(page.mediabox)
  }
}

///|
fn pdf_chop_erase_boxes(
  rest : @syntax.PdfObject,
) -> @syntax.PdfObject raise PdfError {
  rest
  .remove_dict_entry(pdf_chop_cropbox_key())
  .remove_dict_entry(pdf_chop_bleedbox_key())
  .remove_dict_entry(pdf_chop_trimbox_key())
  .remove_dict_entry(pdf_chop_artbox_key())
  .remove_dict_entry(pdf_chop_annots_key())
}

///|
fn pdf_chop_page_with_box(
  page : @page.PdfPage,
  min_x : Double,
  min_y : Double,
  max_x : Double,
  max_y : Double,
) -> @page.PdfPage raise PdfError {
  {
    ..page,
    mediabox: pdf_chop_rectangle_object(min_x, min_y, max_x, max_y),
    rest: pdf_chop_erase_boxes(page.rest),
  }
}

///|
fn pdf_chop_index_order(count : Int, reverse : Bool) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=count)
  for index in 0..<count {
    output.push(if reverse { count - index - 1 } else { index })
  }
  output
}

///|
fn pdf_chop_grid_pages(
  page : @page.PdfPage,
  bounds : @geometry.PdfRectangle,
  x : Int,
  y : Int,
  columns : Bool,
  btt : Bool,
  rtl : Bool,
) -> Array[@page.PdfPage] raise PdfError {
  let width = (bounds.max_x - bounds.min_x) / x.to_double()
  let height = (bounds.max_y - bounds.min_y) / y.to_double()
  let pages : Array[@page.PdfPage] = Array::new(capacity=x * y)
  let x_order = pdf_chop_index_order(x, rtl)
  let y_order = pdf_chop_index_order(y, !btt)
  if columns {
    for tx in x_order {
      for ty in y_order {
        let min_x = bounds.min_x + width * tx.to_double()
        let min_y = bounds.min_y + height * ty.to_double()
        pages.push(
          pdf_chop_page_with_box(
            page,
            min_x,
            min_y,
            min_x + width,
            min_y + height,
          ),
        )
      }
    }
  } else {
    for ty in y_order {
      for tx in x_order {
        let min_x = bounds.min_x + width * tx.to_double()
        let min_y = bounds.min_y + height * ty.to_double()
        pages.push(
          pdf_chop_page_with_box(
            page,
            min_x,
            min_y,
            min_x + width,
            min_y + height,
          ),
        )
      }
    }
  }
  pages
}

///|
fn pdf_chop_pair_pages(
  first : @page.PdfPage,
  second : @page.PdfPage,
  columns : Bool,
) -> Array[@page.PdfPage] {
  let pages : Array[@page.PdfPage] = Array::new(capacity=2)
  if columns {
    pages.push(second)
    pages.push(first)
  } else {
    pages.push(first)
    pages.push(second)
  }
  pages
}

///|
fn pdf_chop_page_boxes(
  document : PdfDocument,
  page : @page.PdfPage,
  line : Double,
  x : Int,
  y : Int,
  columns : Bool,
  btt : Bool,
  rtl : Bool,
) -> Array[@page.PdfPage] raise PdfError {
  let bounds = pdf_chop_box(document, page)
  if x == 0 {
    let top = pdf_chop_page_with_box(
      page,
      bounds.min_x,
      line,
      bounds.max_x,
      bounds.max_y,
    )
    let bottom = pdf_chop_page_with_box(
      page,
      bounds.min_x,
      bounds.min_y,
      bounds.max_x,
      line,
    )
    pdf_chop_pair_pages(top, bottom, columns)
  } else if y == 0 {
    let left = pdf_chop_page_with_box(
      page,
      bounds.min_x,
      bounds.min_y,
      line,
      bounds.max_y,
    )
    let right = pdf_chop_page_with_box(
      page,
      line,
      bounds.min_y,
      bounds.max_x,
      bounds.max_y,
    )
    pdf_chop_pair_pages(left, right, columns)
  } else {
    pdf_chop_grid_pages(page, bounds, x, y, columns, btt, rtl)
  }
}

///|
fn pdf_chop_validate_page_numbers(
  page_numbers : ArrayView[Int],
  end_page : Int,
  context : String,
) -> Unit raise PdfError {
  for page_number in page_numbers {
    if page_number < 1 || page_number > end_page {
      raise BadPageSpecification(
        context + ": range contains pages not present in pdf",
      )
    }
  }
}

///|
fn pdf_chop_validate_grid(x : Int, y : Int) -> Unit raise PdfError {
  if x <= 0 || y <= 0 {
    raise BadNumberArgument("chop: x and y must be positive")
  }
}

///|
fn pdf_chop_selected_page_count(
  original_count : Int,
  selected_pages : @core.PdfNumberSet,
) -> Int {
  let mut count = 0
  for page_number in 1..<=original_count {
    if selected_pages.contains(page_number) {
      count += 1
    }
  }
  count
}

///|
fn pdf_chop_change_table(
  original_count : Int,
  selected_pages : @core.PdfNumberSet,
  selected_count : Int,
  pieces_per_selected_page : Int,
) -> Array[(Int, Int)] {
  let changes : Array[(Int, Int)] = Array::new(
    capacity=original_count + selected_count * (pieces_per_selected_page - 1),
  )
  let mut next_page = 1
  for old_page in 1..<=original_count {
    if selected_pages.contains(old_page) {
      for new_page in next_page..<(next_page + pieces_per_selected_page) {
        changes.push((old_page, new_page))
      }
      next_page += pieces_per_selected_page
    } else {
      changes.push((old_page, next_page))
      next_page += 1
    }
  }
  changes
}

///|
fn PdfDocument::pdf_chop_inner(
  self : PdfDocument,
  line : Double,
  x : Int,
  y : Int,
  columns : Bool,
  btt : Bool,
  rtl : Bool,
  page_numbers : ArrayView[Int],
  context : String,
) -> PdfDocument raise PdfError {
  let end_page = self.endpage()
  pdf_chop_validate_page_numbers(page_numbers, end_page, context)
  let pages = self.pages_of_pagetree()
  let pieces = if x == 0 || y == 0 { 2 } else { x * y }
  let selected_pages = @core.pdf_number_set(page_numbers)
  let selected_count = pdf_chop_selected_page_count(
    pages.length(),
    selected_pages,
  )
  let output : Array[@page.PdfPage] = Array::new(
    capacity=pages.length() + selected_count * (pieces - 1),
  )
  for index in 0..<pages.length() {
    let page_number = index + 1
    if selected_pages.contains(page_number) {
      for
        chopped in pdf_chop_page_boxes(
          self,
          pages[index],
          line,
          x,
          y,
          columns,
          btt,
          rtl,
        ) {
        output.push(chopped)
      }
    } else {
      output.push(pages[index])
    }
  }
  self.change_pages(
    output,
    change_references=true,
    changes=pdf_chop_change_table(
      pages.length(),
      selected_pages,
      selected_count,
      pieces,
    ),
  )
}
