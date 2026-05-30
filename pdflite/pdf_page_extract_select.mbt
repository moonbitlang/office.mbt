///|
fn pdf_page_select_pages(
  pages : ArrayView[@page.PdfPage],
  page_numbers : ArrayView[Int],
) -> Array[@page.PdfPage] raise @core.PdfError {
  if page_numbers.length() == 0 {
    raise PageTreeExpected
  }
  let selected : Array[@page.PdfPage] = Array::new(
    capacity=page_numbers.length(),
  )
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
) -> Array[Int] raise @core.PdfError {
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
