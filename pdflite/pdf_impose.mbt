///|
/// Impose pages into cpdf-style sheets.
///
/// In non-fit mode, `x` and `y` are grid dimensions; one of them may be zero to
/// stack all pages in the other direction. In fit mode, `x` and `y` are the
/// output page width and height, and the grid is calculated from the current
/// page size.
pub fn PdfDocument::impose(
  self : PdfDocument,
  x : Double,
  y : Double,
  fit? : Bool = false,
  columns? : Bool = false,
  rtl? : Bool = false,
  btt? : Bool = false,
  center? : Bool = false,
  margin? : Double = 0.0,
  spacing? : Double = 0.0,
  line_width? : Double = 0.0,
  fast? : Bool = false,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  let source = if process_struct_tree {
    self.mark_all_as_artifact()
  } else {
    self
  }
  let original_page_count = source.endpage()
  if original_page_count == 0 {
    raise BadNumberArgument("impose: pages must not be empty")
  }
  let prepared = source.pdf_impose_preprocess(fit, spacing, line_width, fast)
  let prepared_pages = prepared.pages_of_pagetree()
  let layout = prepared.pdf_impose_layout(
    fit,
    x,
    y,
    margin,
    original_page_count,
    prepared_pages[0].mediabox,
  )
  let imposed_pages : Array[@page.PdfPage] = []
  for page_set in pdf_impose_split_pages(prepared_pages, layout.pages_per_sheet) {
    imposed_pages.push(
      prepared.pdf_impose_pages_core(
        prepared.renumber_pages(page_set),
        fit,
        layout.x_slots,
        layout.y_slots,
        columns,
        rtl,
        btt,
        center,
        margin,
        layout.output_mediabox,
        fast,
        layout.fit_extra_hspace,
        layout.fit_extra_vspace,
      ),
    )
  }
  let imposed = prepared.change_pages(
    imposed_pages,
    change_references=true,
    changes=pdf_impose_page_reference_changes(
      original_page_count,
      layout.pages_per_sheet,
    ),
  )
  if fit {
    imposed
  } else {
    let output_count = imposed.endpage()
    imposed.shift_pages(
      pdf_impose_all_pages(output_count),
      pdf_impose_repeated_offsets(output_count, (margin, margin)),
      fast~,
    )
  }
}

///|
/// Compatibility wrapper for `PdfDocument::impose`.
pub fn pdf_impose(
  document : PdfDocument,
  x : Double,
  y : Double,
  fit? : Bool = false,
  columns? : Bool = false,
  rtl? : Bool = false,
  btt? : Bool = false,
  center? : Bool = false,
  margin? : Double = 0.0,
  spacing? : Double = 0.0,
  line_width? : Double = 0.0,
  fast? : Bool = false,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  document.impose(
    x,
    y,
    fit~,
    columns~,
    rtl~,
    btt~,
    center~,
    margin~,
    spacing~,
    line_width~,
    fast~,
    process_struct_tree~,
  )
}

///|
/// Legacy cpdf two-up stack operation.
///
/// This first imposes source pages in a 2x1 non-fit grid, then rotates the
/// imposed sheets by -90 degrees and uprights them into ordinary page geometry.
pub fn PdfDocument::twoup_stack(
  self : PdfDocument,
  fast? : Bool = false,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  let imposed = self.impose(2.0, 1.0, fast~, process_struct_tree~)
  let all_pages = pdf_impose_all_pages(imposed.endpage())
  imposed.rotate_pages(-90, all_pages).upright_pages(all_pages, fast~)
}

///|
/// Compatibility wrapper for `PdfDocument::twoup_stack`.
pub fn pdf_twoup_stack(
  document : PdfDocument,
  fast? : Bool = false,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  document.twoup_stack(fast~, process_struct_tree~)
}

///|
/// Legacy cpdf two-up operation.
///
/// This scales source pages down, imposes them 2x1, rotates/uprights the
/// imposed sheets, then scales each sheet back to the first page's original
/// size.
pub fn PdfDocument::twoup(
  self : PdfDocument,
  fast? : Bool = false,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  if pages.length() == 0 {
    raise BadNumberArgument("twoup: pages must not be empty")
  }
  let bounds = self.parse_rectangle(pages[0].mediabox)
  let width = bounds.max_x - bounds.min_x
  let height = bounds.max_y - bounds.min_y
  let scale = if width > height {
    let page_ratio = height / width
    let sheet_ratio = width / 2.0 / height
    if page_ratio < sheet_ratio {
      page_ratio
    } else {
      sheet_ratio
    }
  } else {
    let page_ratio = width / height
    let sheet_ratio = height / 2.0 / width
    if page_ratio < sheet_ratio {
      page_ratio
    } else {
      sheet_ratio
    }
  }
  let source_count = self.endpage()
  let source_pages = pdf_impose_all_pages(source_count)
  let scaled = self.scale_pages(
    source_pages,
    pdf_impose_repeated_scales(source_count, (scale, scale)),
    fast~,
  )
  let imposed = scaled.impose(
    2.0,
    1.0,
    center=true,
    fast~,
    process_struct_tree~,
  )
  let output_count = imposed.endpage()
  let output_pages = pdf_impose_all_pages(output_count)
  let upright = imposed
    .rotate_pages(-90, output_pages)
    .upright_pages(output_pages, fast~)
  upright.scale_to_fit_pages(
    output_pages,
    pdf_impose_repeated_scales(output_count, (width, height)),
    position=PdfPositionDiagonal,
    fast~,
  )
}

///|
/// Compatibility wrapper for `PdfDocument::twoup`.
pub fn pdf_twoup(
  document : PdfDocument,
  fast? : Bool = false,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  document.twoup(fast~, process_struct_tree~)
}
