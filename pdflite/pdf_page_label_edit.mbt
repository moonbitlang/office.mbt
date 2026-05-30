///|
fn pdf_page_label_continuation(
  labels : ArrayView[@label.PdfPageLabel],
  start_page : Int,
) -> @label.PdfPageLabel? {
  if labels.length() == 0 {
    None
  } else {
    let label = labels[labels.length() - 1]
    Some({
      ..label,
      start_page,
      start_value: start_page + (label.start_value - label.start_page),
    })
  }
}

///|
/// Insert or replace a label range over a page interval.
///
/// Existing ranges after `range_end_page` are preserved, and a continuation
/// range is inserted when needed so later labels keep their previous numbering.
pub fn pdf_page_label_add_label(
  end_page : Int,
  labels : ArrayView[@label.PdfPageLabel],
  label : @label.PdfPageLabel,
  range_end_page : Int,
) -> Array[@label.PdfPageLabel] {
  let before_or_during_or_equal : Array[@label.PdfPageLabel] = Array::new(
    capacity=labels.length(),
  )
  let after : Array[@label.PdfPageLabel] = Array::new(capacity=labels.length())
  for existing in labels {
    if existing.start_page <= range_end_page {
      before_or_during_or_equal.push(existing)
    } else {
      after.push(existing)
    }
  }
  let before_or_during : Array[@label.PdfPageLabel] = Array::new(
    capacity=before_or_during_or_equal.length(),
  )
  for existing in before_or_during_or_equal {
    if existing.start_page != label.start_page {
      before_or_during.push(existing)
    }
  }
  let before : Array[@label.PdfPageLabel] = Array::new(
    capacity=before_or_during.length() + 1,
  )
  for existing in before_or_during {
    if !(existing.start_page > label.start_page &&
      existing.start_page <= range_end_page) {
      before.push(existing)
    }
  }
  let output = before
  output.push(label)
  if range_end_page != end_page &&
    !(after.length() > 0 && after[0].start_page == range_end_page + 1) {
    match
      pdf_page_label_continuation(before_or_during_or_equal, range_end_page + 1) {
      Some(replica) => output.push(replica)
      None => ()
    }
  }
  for existing in after {
    output.push(existing)
  }
  output
}

///|
fn pdf_page_label_range_extents(
  page_numbers : ArrayView[Int],
) -> Array[(Int, Int)] {
  let ranges : Array[(Int, Int)] = Array::new(capacity=page_numbers.length())
  if page_numbers.length() > 0 {
    let mut start = page_numbers[0]
    let mut previous = page_numbers[0]
    for index in 1..<page_numbers.length() {
      let page_number = page_numbers[index]
      if page_number == previous + 1 {
        previous = page_number
      } else {
        ranges.push((start, previous))
        start = page_number
        previous = page_number
      }
    }
    ranges.push((start, previous))
  }
  ranges
}

///|
fn pdf_page_label_has_page_one(labels : ArrayView[@label.PdfPageLabel]) -> Bool {
  for label in labels {
    if label.start_page == 1 {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_page_label_start_additions(ranges : ArrayView[(Int, Int)]) -> Array[Int] {
  let additions : Array[Int] = Array::new(capacity=ranges.length())
  let mut so_far = 0
  for range in ranges {
    let (start_page, end_page) = range
    additions.push(so_far)
    so_far += end_page - start_page + 1
  }
  additions
}

///|
fn pdf_page_label_with_basic_if_needed(
  labels : ArrayView[@label.PdfPageLabel],
) -> Array[@label.PdfPageLabel] {
  let output : Array[@label.PdfPageLabel] = Array::new(
    capacity=labels.length() + 1,
  )
  if !pdf_page_label_has_page_one(labels) {
    output.push(@label.pdf_page_label_basic)
  }
  for label in labels {
    output.push(label)
  }
  output
}

///|
/// Add page-label ranges to the selected one-based page numbers.
///
/// `page_numbers` is interpreted in its existing order; contiguous runs are
/// labelled as ranges. When `progress` is true, each later range starts after
/// the number of pages already labelled by earlier ranges.
pub fn PdfDocument::add_page_labels(
  self : PdfDocument,
  progress : Bool,
  style : @label.PdfPageLabelStyle,
  prefix : PdfBytes?,
  start_value : Int,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  let ranges = pdf_page_label_range_extents(page_numbers)
  if ranges.length() == 0 {
    raise BadPageSpecification("empty page label range")
  }
  let additions = pdf_page_label_start_additions(ranges)
  let end_page = self.endpage()
  let mut labels = pdf_page_label_with_basic_if_needed(self.read_page_labels())
  for index in 0..<ranges.length() {
    let (range_start, range_end) = ranges[index]
    let addition = if progress { additions[index] } else { 0 }
    labels = pdf_page_label_add_label(
      end_page,
      labels,
      {
        label_style: style,
        label_prefix: prefix,
        start_page: range_start,
        start_value: start_value + addition,
      },
      range_end,
    )
  }
  self.write_page_labels(labels)
}

///|
/// Compatibility wrapper for `PdfDocument::add_page_labels`.
pub fn pdf_add_page_labels(
  document : PdfDocument,
  progress : Bool,
  style : @label.PdfPageLabelStyle,
  prefix : PdfBytes?,
  start_value : Int,
  page_numbers : ArrayView[Int],
) -> PdfDocument raise PdfError {
  document.add_page_labels(progress, style, prefix, start_value, page_numbers)
}
