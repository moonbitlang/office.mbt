///|
fn pdf_pagespec_same_values(
  left : ArrayView[Int],
  right : ArrayView[Int],
) -> Bool {
  if left.length() != right.length() {
    false
  } else {
    for index in 0..<left.length() {
      if left[index] != right[index] {
        break false
      }
    } nobreak {
      true
    }
  }
}

///|
fn pdf_pagespec_join_ranges(ranges : ArrayView[(Int, Int)]) -> String {
  let mut output = ""
  for index in 0..<ranges.length() {
    let (start, finish) = ranges[index]
    if index > 0 {
      output = output + ","
    }
    if start == finish {
      output = output + start.to_string()
    } else {
      output = output + start.to_string() + "-" + finish.to_string()
    }
  }
  output
}

///|
/// Format selected pages as a compact cpdf page specification.
pub fn pdf_string_of_pagespec_for_count(
  end_page : Int,
  pages : ArrayView[Int],
) -> String {
  if pages.length() == 0 {
    ""
  } else {
    let sorted = pages.to_owned()
    sorted.sort()
    if end_page > 3 &&
      pdf_pagespec_same_values(
        sorted,
        pdf_pagespec_filter_even(pdf_pagespec_all_pages(end_page)),
      ) {
      "even"
    } else if end_page > 2 &&
      pdf_pagespec_same_values(
        sorted,
        pdf_pagespec_filter_odd(pdf_pagespec_all_pages(end_page)),
      ) {
      "odd"
    } else if pdf_pagespec_same_values(sorted, pdf_pagespec_all_pages(end_page)) {
      "all"
    } else {
      let ranges : Array[(Int, Int)] = Array::new(capacity=sorted.length())
      let mut start = sorted[0]
      let mut previous = sorted[0]
      for index in 1..<sorted.length() {
        let page = sorted[index]
        if page == previous + 1 {
          previous = page
        } else {
          ranges.push((start, previous))
          start = page
          previous = page
        }
      }
      ranges.push((start, previous))
      pdf_pagespec_join_ranges(ranges)
    }
  }
}
