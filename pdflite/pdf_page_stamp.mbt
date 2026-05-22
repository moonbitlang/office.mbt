///|
fn pdf_page_stamp_half(value : Double) -> Double {
  value / 2.0
}

///|
fn pdf_page_stamp_shift_of_position(
  topline : Bool,
  midline : Bool,
  stamp_width : Double,
  stamp_height : Double,
  page_width : Double,
  page_height : Double,
  position : PdfPosition,
) -> (Double, Double) {
  let dy = if midline {
    stamp_height / 2.0
  } else if topline {
    stamp_height
  } else {
    0.0
  }
  match position {
    PdfPositionPosCentre(x, y) => (x - pdf_page_stamp_half(stamp_width), y - dy)
    PdfPositionPosLeft(x, y) => (x, y - dy)
    PdfPositionPosRight(x, y) => (x - stamp_width, y - dy)
    PdfPositionTop(offset) =>
      (
        pdf_page_stamp_half(page_width) - pdf_page_stamp_half(stamp_width),
        page_height - offset - stamp_height - dy,
      )
    PdfPositionTopLeft(x, y) => (x, page_height - stamp_height - y - dy)
    PdfPositionTopRight(x, y) =>
      (page_width - stamp_width - x, page_height - stamp_height - y - dy)
    PdfPositionLeft(offset) =>
      (
        offset,
        pdf_page_stamp_half(page_height) -
        pdf_page_stamp_half(stamp_height) -
        dy,
      )
    PdfPositionBottomLeft(x, y) => (x, y - dy)
    PdfPositionBottom(offset) =>
      (
        pdf_page_stamp_half(page_width) - pdf_page_stamp_half(stamp_width),
        offset - dy,
      )
    PdfPositionBottomRight(x, y) => (page_width - stamp_width - x, y - dy)
    PdfPositionRight(offset) =>
      (
        page_width - stamp_width - offset,
        pdf_page_stamp_half(page_height) -
        pdf_page_stamp_half(stamp_height) -
        dy,
      )
    PdfPositionDiagonal | PdfPositionReverseDiagonal | PdfPositionCentre =>
      (
        pdf_page_stamp_half(page_width) - pdf_page_stamp_half(stamp_width),
        pdf_page_stamp_half(page_height) -
        pdf_page_stamp_half(stamp_height) -
        dy,
      )
  }
}

///|
fn PdfDocument::pdf_page_stamp_box(
  self : PdfDocument,
  page : PdfPage,
  box_name : PdfName,
) -> PdfRectangle raise PdfError {
  self.parse_rectangle(
    if box_name == pdf_page_mediabox_key() {
      page.mediabox
    } else {
      match self.lookup_direct(box_name, page.rest) {
        Some(box) => box
        None => page.mediabox
      }
    },
  )
}

///|
fn pdf_page_stamp_scale_to_fit_factor(
  x_magnification : Double,
  y_magnification : Double,
) -> Double {
  if x_magnification < 0.999 && y_magnification < 0.999 {
    if x_magnification > y_magnification {
      x_magnification
    } else {
      y_magnification
    }
  } else if x_magnification >= 1.001 && y_magnification >= 1.001 {
    if x_magnification > y_magnification {
      y_magnification
    } else {
      x_magnification
    }
  } else if x_magnification >= 1.001 {
    y_magnification
  } else {
    x_magnification
  }
}

///|
fn pdf_page_stamp_scale_to_fit_matrix(
  stamp_box : PdfRectangle,
  target_box : PdfRectangle,
  relative_to_box : PdfName,
) -> TransformMatrix raise PdfError {
  let stamp_width = stamp_box.max_x - stamp_box.min_x
  let stamp_height = stamp_box.max_y - stamp_box.min_y
  let target_width = target_box.max_x - target_box.min_x
  let target_height = target_box.max_y - target_box.min_y
  if stamp_width == 0.0 || stamp_height == 0.0 {
    raise BadNumberArgument("stamp_pages: zero-sized stamp page is invalid")
  }
  let scale = pdf_page_stamp_scale_to_fit_factor(
    target_width / stamp_width,
    target_height / stamp_height,
  )
  let dx = target_box.min_x + (target_width - stamp_width * scale) / 2.0
  let dy = target_box.min_y + (target_height - stamp_height * scale) / 2.0
  let ops : Array[TransformOp] = [Translate(dx, dy)]
  if relative_to_box != pdf_page_mediabox_key() {
    ops.push(Translate(target_box.min_x, target_box.min_y))
  }
  ops.push(Scale(point2(stamp_box.min_x, stamp_box.min_y), scale, scale))
  transform_matrix_of_ops(ops)
}

///|
fn pdf_page_stamp_position_matrix(
  stamp_box : PdfRectangle,
  target_box : PdfRectangle,
  relative_to_box : PdfName,
  position : PdfPosition,
  topline : Bool,
  midline : Bool,
) -> TransformMatrix {
  let stamp_width = stamp_box.max_x - stamp_box.min_x
  let stamp_height = stamp_box.max_y - stamp_box.min_y
  let target_width = target_box.max_x - target_box.min_x
  let target_height = target_box.max_y - target_box.min_y
  let (dx, dy) = pdf_page_stamp_shift_of_position(
    topline, midline, stamp_width, stamp_height, target_width, target_height, position,
  )
  let ops : Array[TransformOp] = []
  if relative_to_box != pdf_page_mediabox_key() {
    ops.push(Translate(target_box.min_x, target_box.min_y))
  }
  ops.push(Translate(dx, dy))
  transform_matrix_of_ops(ops)
}

///|
fn PdfDocument::pdf_page_stamp_transform_overlay(
  self : PdfDocument,
  overlay_page : PdfPage,
  under_page : PdfPage,
  relative_to_box : PdfName,
  position : PdfPosition,
  topline : Bool,
  midline : Bool,
  scale_to_fit : Bool,
  fast : Bool,
) -> PdfPage raise PdfError {
  let stamp_box = self.pdf_page_stamp_box(overlay_page, relative_to_box)
  let target_box = self.pdf_page_stamp_box(under_page, relative_to_box)
  let matrix = if scale_to_fit {
    pdf_page_stamp_scale_to_fit_matrix(stamp_box, target_box, relative_to_box)
  } else {
    pdf_page_stamp_position_matrix(
      stamp_box, target_box, relative_to_box, position, topline, midline,
    )
  }
  self.transform_annotations(matrix, overlay_page.rest)
  let transformed = self.prepend_operators(overlay_page, [Op_cm(matrix)], fast~)
  self.pdf_impose_change_pattern_matrices_page(matrix, transformed)
}

///|
fn PdfDocument::pdf_page_stamp_protect_content(
  self : PdfDocument,
  resources : PdfObject,
  content : ArrayView[PdfObject],
  fast : Bool,
) -> Array[PdfObject] raise PdfError {
  let deficit = if fast {
    0
  } else {
    let ops = self.pdf_page_parse_content_ops(resources, content)
    let mut saves = 0
    let mut restores = 0
    for op in ops {
      match op {
        Op_q => saves += 1
        Op_Q => restores += 1
        _ => ()
      }
    }
    if saves > restores {
      saves - restores
    } else {
      0
    }
  }
  let begin_number = self.add_object(pdf_content_stream_of_ops([Op_q]))
  let end_ops : Array[PdfContentOp] = []
  for _ in 0..<deficit {
    end_ops.push(Op_Q)
  }
  end_ops.push(Op_Q)
  let end_number = self.add_object(pdf_content_stream_of_ops(end_ops))
  let output : Array[PdfObject] = [PdfIndirect(begin_number)]
  for object in content {
    output.push(object)
  }
  output.push(PdfIndirect(end_number))
  output
}

///|
fn pdf_page_stamp_concat_content(
  first : ArrayView[PdfObject],
  second : ArrayView[PdfObject],
) -> Array[PdfObject] {
  let output : Array[PdfObject] = []
  for object in first {
    output.push(object)
  }
  for object in second {
    output.push(object)
  }
  output
}

///|
fn PdfDocument::pdf_page_stamp_pair(
  self : PdfDocument,
  overlay_page : PdfPage,
  under_page : PdfPage,
  relative_to_box : PdfName,
  position : PdfPosition,
  topline : Bool,
  midline : Bool,
  scale_to_fit : Bool,
  is_over : Bool,
  fast : Bool,
) -> PdfPage raise PdfError {
  let overlay_page = self.pdf_page_stamp_transform_overlay(
    overlay_page, under_page, relative_to_box, position, topline, midline, scale_to_fit,
    fast,
  )
  let under_content = self.pdf_page_stamp_protect_content(
    under_page.resources,
    under_page.content,
    fast,
  )
  let overlay_content = self.pdf_page_stamp_protect_content(
    overlay_page.resources,
    overlay_page.content,
    fast,
  )
  {
    ..under_page,
    content: if is_over {
      pdf_page_stamp_concat_content(under_content, overlay_content)
    } else {
      pdf_page_stamp_concat_content(overlay_content, under_content)
    },
    rest: self.combine_pdf_rests(under_page.rest, overlay_page.rest),
    resources: self.combine_pdf_resources(
      under_page.resources,
      overlay_page.resources,
    ),
  }
}

///|
fn pdf_page_stamp_identity_changes(count : Int) -> Array[(Int, Int)] {
  [
    for page_number in 1..<=count => (page_number, page_number)
  ]
}

///|
fn pdf_page_stamp_all_but_last(pages : ArrayView[PdfPage]) -> Array[PdfPage] {
  [
    for index in 0..<(pages.length() - 1) => pages[index]
  ]
}

///|
fn PdfDocument::pdf_page_stamp_overlay_first_page(
  self : PdfDocument,
) -> PdfDocument raise PdfError {
  let pages = self.pages_of_pagetree()
  guard pages.length() > 0 else { raise SoftError("empty PDF") }
  self.change_pages([pages[0]], change_references=true, changes=[(1, 1)])
}

///|
/// Stamp the first page of `overlay` onto selected pages by merging content.
pub fn PdfDocument::stamp_pages(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  overlay : PdfDocument,
  relative_to_box? : PdfName = pdf_page_mediabox_key(),
  position? : PdfPosition = PdfPositionBottomLeft(0.0, 0.0),
  topline? : Bool = false,
  midline? : Bool = false,
  fast? : Bool = false,
  scale_to_fit? : Bool = false,
  is_over? : Bool = true,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  let overlay = if process_struct_tree {
    overlay.remove_struct_tree().mark_all_as_artifact()
  } else {
    overlay.copy()
  }
  let prefix = self.shortest_unused_prefix()
  overlay.add_prefix(prefix)
  let bookmarks = self.read_bookmarks(preserve_actions=true) catch { _ => [] }
  let bookmark_page_numbers = self.page_reference_numbers()
  let base = self.remove_bookmarks()
  let overlay_without_bookmarks = overlay.remove_bookmarks()
  let base_pages = base.pages_of_pagetree()
  pdf_page_box_validate_page_numbers(
    page_numbers,
    base_pages.length(),
    "stamp_pages",
  )
  let merged = pdf_merge_pdfs(
    false,
    false,
    ["a", "b"],
    [base, overlay_without_bookmarks.pdf_page_stamp_overlay_first_page()],
    [pdf_xobject_all_page_range(base), [1]],
  )
  merged.set_saved_encryption(self.saved_encryption())
  merged.pdf_xobject_copy_trailer_id_from(self)
  let merged_pages = merged.pages_of_pagetree()
  guard merged_pages.length() > 0 else { raise PageTreeExpected }
  let overlay_page = merged_pages[merged_pages.length() - 1]
  let under_pages = pdf_page_stamp_all_but_last(merged_pages)
  let new_pages : Array[PdfPage] = []
  for index in 0..<under_pages.length() {
    let page_number = index + 1
    let stamp_page = if pdf_page_box_contains_page(page_numbers, page_number) {
      overlay_page
    } else {
      pdf_page_blank(paper_a4)
    }
    new_pages.push(
      merged.pdf_page_stamp_pair(
        stamp_page,
        under_pages[index],
        relative_to_box,
        position,
        topline,
        midline,
        scale_to_fit,
        is_over,
        fast,
      ),
    )
  }
  let changed = merged.change_pages(
    new_pages,
    change_references=true,
    changes=pdf_page_stamp_identity_changes(new_pages.length()),
  )
  let final_page_numbers = changed.page_reference_numbers()
  if bookmarks.length() > 0 {
    changed.add_bookmarks(
      pdf_xobject_retained_bookmarks(
        bookmarks, bookmark_page_numbers, final_page_numbers,
      ),
    )
  } else {
    changed
  }
}

///|
/// Compatibility wrapper for `PdfDocument::stamp_pages`.
pub fn pdf_stamp(
  document : PdfDocument,
  page_numbers : ArrayView[Int],
  overlay : PdfDocument,
  relative_to_box? : PdfName = pdf_page_mediabox_key(),
  position? : PdfPosition = PdfPositionBottomLeft(0.0, 0.0),
  topline? : Bool = false,
  midline? : Bool = false,
  fast? : Bool = false,
  scale_to_fit? : Bool = false,
  is_over? : Bool = true,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  document.stamp_pages(
    page_numbers,
    overlay,
    relative_to_box~,
    position~,
    topline~,
    midline~,
    fast~,
    scale_to_fit~,
    is_over~,
    process_struct_tree~,
  )
}

///|
/// Stamp using cpdfpage's string page-box names.
pub fn PdfDocument::stamp_pages_string(
  self : PdfDocument,
  page_numbers : ArrayView[Int],
  overlay : PdfDocument,
  relative_to_box : String,
  position? : PdfPosition = PdfPositionBottomLeft(0.0, 0.0),
  topline? : Bool = false,
  midline? : Bool = false,
  fast? : Bool = false,
  scale_to_fit? : Bool = false,
  is_over? : Bool = true,
  process_struct_tree? : Bool = false,
) -> PdfDocument raise PdfError {
  self.stamp_pages(
    page_numbers,
    overlay,
    relative_to_box=pdf_page_box_name_of_string(relative_to_box),
    position~,
    topline~,
    midline~,
    fast~,
    scale_to_fit~,
    is_over~,
    process_struct_tree~,
  )
}

///|
/// Compatibility wrapper matching cpdfpage's `stamp` argument order.
pub fn pdf_stamp_cpdf_order(
  process_struct_tree : Bool,
  relative_to_box : String,
  position : PdfPosition,
  topline : Bool,
  midline : Bool,
  fast : Bool,
  scale_to_fit : Bool,
  is_over : Bool,
  page_numbers : ArrayView[Int],
  overlay : PdfDocument,
  document : PdfDocument,
) -> PdfDocument raise PdfError {
  document.stamp_pages_string(
    page_numbers,
    overlay,
    relative_to_box,
    position~,
    topline~,
    midline~,
    fast~,
    scale_to_fit~,
    is_over~,
    process_struct_tree~,
  )
}
