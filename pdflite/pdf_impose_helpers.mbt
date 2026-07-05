///|
fn pdf_impose_split_pages(
  pages : ArrayView[@page.PdfPage],
  chunk_size : Int,
) -> Array[Array[@page.PdfPage]] {
  let chunks : Array[Array[@page.PdfPage]] = []
  let mut index = 0
  while index < pages.length() {
    let chunk : Array[@page.PdfPage] = []
    let stop = if index + chunk_size < pages.length() {
      index + chunk_size
    } else {
      pages.length()
    }
    for page_index in index..<stop {
      chunk.push(pages[page_index])
    }
    chunks.push(chunk)
    index = stop
  }
  chunks
}

///|
fn pdf_impose_page_reference_changes(
  page_count : Int,
  pages_per_sheet : Int,
) -> Array[(Int, Int)] {
  [
    for page_number in 1..<=page_count => {
      (page_number, (page_number + pages_per_sheet - 1) / pages_per_sheet)
    }
  ]
}

///|
fn PdfDocument::pdf_impose_preprocess(
  self : PdfDocument,
  fit : Bool,
  spacing : Double,
  line_width : Double,
  fast : Bool,
) -> PdfDocument raise @core.PdfError {
  let end_page = self.endpage()
  let all_pages = pdf_impose_all_pages(end_page)
  self
  .copy_page_box(
    all_pages,
    pdf_page_cropbox_key(),
    pdf_page_mediabox_key(),
    mediabox_if_missing=true,
  )
  .remove_cropping(all_pages)
  .upright_pages(all_pages, fast~)
  .pdf_impose_add_border(line_width, fast)
  .pdf_impose_make_space(fit, spacing, fast)
}

///|
fn pdf_impose_push_objects(
  output : Array[@syntax.PdfObject],
  objects : ArrayView[@syntax.PdfObject],
) -> Unit {
  for object in objects {
    output.push(object)
  }
}

///|
fn pdf_impose_all_pages(end_page : Int) -> Array[Int] {
  [
    for page_number in 1..<=end_page => page_number
  ]
}

///|
fn pdf_impose_repeated_offsets(
  count : Int,
  offset : (Double, Double),
) -> Array[(Double, Double)] {
  if count > 0 {
    Array::make(count, offset)
  } else {
    []
  }
}

///|
fn pdf_impose_repeated_scales(
  count : Int,
  scale : (Double, Double),
) -> Array[(Double, Double)] {
  if count > 0 {
    Array::make(count, scale)
  } else {
    []
  }
}

///|
fn pdf_impose_repeated_boxes(
  count : Int,
  box : (Double, Double, Double, Double),
) -> Array[(Double, Double, Double, Double)] {
  if count > 0 {
    Array::make(count, box)
  } else {
    []
  }
}

///|
#warnings("-unused_value")
fn PdfDocument::pdf_impose_make_space(
  self : PdfDocument,
  fit : Bool,
  spacing : Double,
  fast : Bool,
) -> PdfDocument raise @core.PdfError {
  let end_page = self.endpage()
  let all_pages = pdf_impose_all_pages(end_page)
  let boxed = self.hard_box(all_pages, pdf_page_mediabox_key(), fast~)
  if spacing == 0.0 || end_page == 0 {
    boxed
  } else {
    let margin = spacing / 2.0
    let pages = boxed.pages_of_pagetree()
    let first_bounds = boxed.parse_rectangle(pages[0].mediabox)
    let width = first_bounds.max_x - first_bounds.min_x
    let height = first_bounds.max_y - first_bounds.min_y
    let offsets = pdf_impose_repeated_offsets(end_page, (margin, margin))
    if fit {
      boxed
      .scale_contents(
        all_pages,
        PdfPositionBottomLeft(0.0, 0.0),
        (width - spacing) / width,
        fast~,
      )
      .shift_pages(all_pages, offsets, fast~)
    } else {
      boxed
      .shift_pages(all_pages, offsets, fast~)
      .set_mediaboxes(
        all_pages,
        pdf_impose_repeated_boxes(
          end_page,
          (0.0, 0.0, width + spacing, height + spacing),
        ),
      )
    }
  }
}
