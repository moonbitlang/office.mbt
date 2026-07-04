///|
fn pdf_pagespec_range(start : Int, finish : Int) -> Array[Int] {
  let output : Array[Int] = Array::new(
    capacity=if start <= finish {
      finish - start + 1
    } else {
      start - finish + 1
    },
  )
  if start <= finish {
    let mut page = start
    while page <= finish {
      output.push(page)
      page += 1
    }
  } else {
    let mut page = start
    while page >= finish {
      output.push(page)
      page -= 1
    }
  }
  output
}

///|
fn pdf_pagespec_all_pages(end_page : Int) -> Array[Int] {
  pdf_pagespec_range(1, end_page)
}

///|
fn pdf_pagespec_invert_range(
  end_page : Int,
  range : ArrayView[Int],
) -> Array[Int] {
  if end_page <= 0 {
    []
  } else {
    let selected_pages = Array::make(end_page + 1, false)
    for selected in range {
      if selected >= 1 && selected <= end_page {
        selected_pages[selected] = true
      }
    }
    let output : Array[Int] = Array::new(capacity=end_page)
    for page in 1..<=end_page {
      if !selected_pages[page] {
        output.push(page)
      }
    }
    output
  }
}

///|
fn pdf_pagespec_count_commas(tokens : ArrayView[PdfPageSpecToken]) -> Int {
  let mut count = 0
  for token in tokens {
    if token is PageSpecComma {
      count += 1
    }
  }
  count
}

///|
fn pdf_pagespec_sum_lengths(parts : ArrayView[Array[Int]]) -> Int {
  let mut length = 0
  for part in parts {
    length += part.length()
  }
  length
}

///|
fn pdf_pagespec_flatten(parts : ArrayView[Array[Int]]) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=pdf_pagespec_sum_lengths(parts))
  for part in parts {
    for page in part {
      output.push(page)
    }
  }
  output
}

///|
/// Return pages in `1..=end_page` that are not present in `range`.
pub fn pdf_invert_page_range(
  end_page : Int,
  range : ArrayView[Int],
) -> Array[Int] {
  pdf_pagespec_invert_range(end_page, range)
}

///|
/// Source-spelled compatibility alias for cpdfpagespec's `invert_range`.
pub fn pdf_invert_range(end_page : Int, range : ArrayView[Int]) -> Array[Int] {
  pdf_pagespec_invert_range(end_page, range)
}

///|
fn pdf_pagespec_duplicate_range(
  count : Int,
  range : ArrayView[Int],
) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=count * range.length())
  for page in range {
    for _ in 0..<count {
      output.push(page)
    }
  }
  output
}

///|
fn pdf_pagespec_filter_odd(range : ArrayView[Int]) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=range.length())
  for page in range {
    if page % 2 != 0 {
      output.push(page)
    }
  }
  output
}

///|
fn pdf_pagespec_filter_even(range : ArrayView[Int]) -> Array[Int] {
  let output : Array[Int] = Array::new(capacity=range.length())
  for page in range {
    if page % 2 == 0 {
      output.push(page)
    }
  }
  output
}

///|
fn pdf_pagespec_token_number(
  context : PdfPageSpecContext,
  token : PdfPageSpecToken,
) -> Int? raise PdfError {
  match token {
    PageSpecNumber(value) => Some(value)
    PageSpecWord("end") => Some(context.end_page)
    PageSpecWord(text) if text.has_prefix("~") => {
      let rest = text.unsafe_substring(start=1, end=text.length())
      match pdf_pagespec_parse_nonnegative_int(rest) {
        Some(value) => Some(context.end_page + 1 - value)
        None => {
          context.bad()
          None
        }
      }
    }
    _ => None
  }
}

///|
fn pdf_pagespec_split_commas(
  tokens : ArrayView[PdfPageSpecToken],
  context : PdfPageSpecContext,
  comma_count : Int,
) -> Array[Array[PdfPageSpecToken]] raise PdfError {
  let parts : Array[Array[PdfPageSpecToken]] = Array::new(
    capacity=comma_count + 1,
  )
  let mut current : Array[PdfPageSpecToken] = Array::new(
    capacity=tokens.length(),
  )
  for token in tokens {
    if token is PageSpecComma {
      if current.length() == 0 {
        context.bad()
      }
      parts.push(current)
      current = Array::new(capacity=tokens.length())
    } else {
      current.push(token)
    }
  }
  if current.length() == 0 {
    context.bad()
  }
  parts.push(current)
  parts
}
