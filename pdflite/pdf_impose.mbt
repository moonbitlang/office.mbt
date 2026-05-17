///|
fn pdf_impose_validate_transform_inputs(
  x : Int,
  y : Int,
  count : Int,
) -> Unit raise PdfError {
  if x <= 0 || y <= 0 {
    raise BadNumberArgument("impose: x and y must be positive")
  }
  if count < 0 {
    raise BadNumberArgument("impose: page count must be non-negative")
  }
}

///|
fn pdf_impose_order(
  row : Int,
  col : Int,
  x : Int,
  y : Int,
  rtl : Bool,
  btt : Bool,
) -> (Int, Int) {
  (if btt { y - row - 1 } else { row }, if rtl { x - col - 1 } else { col })
}

///|
fn pdf_impose_adjusted_row(
  original_row : Int,
  y : Int,
  final_full_rows : Int,
  remaining : Int,
  center : Bool,
) -> Int {
  if center && remaining <= final_full_rows {
    let final_empty_rows = y - final_full_rows
    original_row + (y - 1 - 1 - final_empty_rows / 2)
  } else {
    original_row
  }
}

///|
fn pdf_impose_adjusted_col(
  original_col : Int,
  x : Int,
  final_full_cols : Int,
  remaining : Int,
  center : Bool,
) -> Int {
  if center && remaining <= final_full_cols {
    let final_empty_cols = x - final_full_cols
    original_col + (x - 1 - 1 - final_empty_cols / 2)
  } else {
    original_col
  }
}

///|
fn pdf_impose_translate(
  x : Int,
  rtl : Bool,
  btt : Bool,
  cent_extra_x : Double,
  cent_extra_y : Double,
  fit_extra_hspace : Double,
  fit_extra_vspace : Double,
  row : Int,
  col : Int,
  px : Double,
  py : Double,
) -> TransformMatrix {
  let cex = if rtl { -cent_extra_x } else { cent_extra_x }
  let cey = if btt { -cent_extra_y } else { cent_extra_y }
  let space_col = if rtl { x - col - 1 } else { col }
  let total_fit_extra_hspace = fit_extra_hspace * (space_col.to_double() + 1.0)
  let total_fit_extra_vspace = fit_extra_vspace * (row.to_double() + 1.0)
  transform_translate(
    px + cex + total_fit_extra_hspace,
    py + cey + total_fit_extra_vspace,
  )
}

///|
fn PdfDocument::pdf_impose_make_margin(
  self : PdfDocument,
  output_mediabox : PdfObject,
  margin : Double,
  matrix : TransformMatrix,
) -> TransformMatrix raise PdfError {
  if margin == 0.0 {
    matrix
  } else {
    let box = self.parse_rectangle(output_mediabox)
    let width = box.max_x - box.min_x
    let height = box.max_y - box.min_y
    if margin > width / 2.0 || margin > height / 2.0 {
      raise BadNumberArgument("impose: margin would fill whole page")
    }
    let hfactor = (width - margin - margin) / width
    let vfactor = (height - margin - margin) / height
    let factor = if hfactor < vfactor { hfactor } else { vfactor }
    let scale = transform_scale(point2(0.0, 0.0), factor, factor)
    let shift = transform_translate(
      (width - width * factor) / 2.0,
      (height - height * factor) / 2.0,
    )
    transform_matrix_compose(shift, transform_matrix_compose(scale, matrix))
  }
}

///|
fn PdfDocument::pdf_impose_transform_for_slot(
  self : PdfDocument,
  fit : Bool,
  x : Int,
  rtl : Bool,
  btt : Bool,
  margin : Double,
  output_mediabox : PdfObject,
  fit_extra_hspace : Double,
  fit_extra_vspace : Double,
  cent_extra_x : Double,
  cent_extra_y : Double,
  row : Int,
  col : Int,
  px : Double,
  py : Double,
) -> TransformMatrix raise PdfError {
  let matrix = pdf_impose_translate(
    x, rtl, btt, cent_extra_x, cent_extra_y, fit_extra_hspace, fit_extra_vspace,
    row, col, px, py,
  )
  if fit {
    self.pdf_impose_make_margin(output_mediabox, margin, matrix)
  } else {
    matrix
  }
}

///|
#warnings("-unused_field")
priv struct PdfImposeLayout {
  pages_per_sheet : Int
  x_slots : Int
  y_slots : Int
  output_mediabox : PdfObject
  fit_extra_hspace : Double
  fit_extra_vspace : Double
}

///|
fn pdf_impose_output_box(width : Double, height : Double) -> PdfObject {
  PdfArray([PdfReal(0.0), PdfReal(0.0), PdfReal(width), PdfReal(height)])
}

///|
fn PdfDocument::pdf_impose_fit_layout(
  self : PdfDocument,
  x : Double,
  y : Double,
  page_width : Double,
  page_height : Double,
) -> PdfImposeLayout raise PdfError {
  ignore(self)
  let across = @math.floor(x / page_width + 0.001).to_int()
  let down = @math.floor(y / page_height + 0.001).to_int()
  if across < 1 || down < 1 {
    raise BadNumberArgument("impose: not even a single page would fit")
  }
  {
    pages_per_sheet: across * down,
    x_slots: across,
    y_slots: down,
    output_mediabox: pdf_impose_output_box(x, y),
    fit_extra_hspace: (x - across.to_double() * page_width) /
    (across.to_double() + 1.0),
    fit_extra_vspace: (y - down.to_double() * page_height) /
    (down.to_double() + 1.0),
  }
}

///|
fn PdfDocument::pdf_impose_xy_layout(
  self : PdfDocument,
  x : Double,
  y : Double,
  margin : Double,
  page_count : Int,
  page_width : Double,
  page_height : Double,
) -> PdfImposeLayout raise PdfError {
  ignore(self)
  let ix = x.to_int()
  let iy = y.to_int()
  if ix == 0 && iy == 0 {
    raise BadNumberArgument("impose-xy: both dimensions cannot be zero")
  }
  let (pages_per_sheet, x_slots, y_slots) = if ix == 0 {
    (page_count, page_count, 1)
  } else if iy == 0 {
    (page_count, 1, page_count)
  } else {
    (ix * iy, ix, iy)
  }
  let margin2 = margin * 2.0
  let output_mediabox = if x == 0.0 {
    pdf_impose_output_box(
      page_width * page_count.to_double() + margin2,
      page_height + margin2,
    )
  } else if y == 0.0 {
    pdf_impose_output_box(
      page_width + margin2,
      page_height * page_count.to_double() + margin2,
    )
  } else {
    pdf_impose_output_box(page_width * x + margin2, page_height * y + margin2)
  }
  {
    pages_per_sheet,
    x_slots,
    y_slots,
    output_mediabox,
    fit_extra_hspace: 0.0,
    fit_extra_vspace: 0.0,
  }
}

///|
#warnings("-unused_value")
fn PdfDocument::pdf_impose_layout(
  self : PdfDocument,
  fit : Bool,
  x : Double,
  y : Double,
  margin : Double,
  page_count : Int,
  mediabox : PdfObject,
) -> PdfImposeLayout raise PdfError {
  let bounds = self.parse_rectangle(mediabox)
  let page_width = bounds.max_x - bounds.min_x
  let page_height = bounds.max_y - bounds.min_y
  if fit {
    self.pdf_impose_fit_layout(x, y, page_width, page_height)
  } else {
    self.pdf_impose_xy_layout(x, y, margin, page_count, page_width, page_height)
  }
}

///|
fn pdf_impose_concat_ops(
  first : ArrayView[PdfContentOp],
  second : ArrayView[PdfContentOp],
) -> Array[PdfContentOp] {
  let output : Array[PdfContentOp] = []
  for op in first {
    output.push(op)
  }
  for op in second {
    output.push(op)
  }
  output
}

///|
fn pdf_impose_push_objects(
  output : Array[PdfObject],
  objects : ArrayView[PdfObject],
) -> Unit {
  for object in objects {
    output.push(object)
  }
}

///|
fn pdf_impose_all_pages(end_page : Int) -> Array[Int] {
  let pages : Array[Int] = []
  for page_number in 1..<=end_page {
    pages.push(page_number)
  }
  pages
}

///|
fn pdf_impose_repeated_offsets(
  count : Int,
  offset : (Double, Double),
) -> Array[(Double, Double)] {
  let offsets : Array[(Double, Double)] = []
  for _ in 0..<count {
    offsets.push(offset)
  }
  offsets
}

///|
fn pdf_impose_repeated_boxes(
  count : Int,
  box : (Double, Double, Double, Double),
) -> Array[(Double, Double, Double, Double)] {
  let boxes : Array[(Double, Double, Double, Double)] = []
  for _ in 0..<count {
    boxes.push(box)
  }
  boxes
}

///|
#warnings("-unused_value")
fn PdfDocument::pdf_impose_make_space(
  self : PdfDocument,
  fit : Bool,
  spacing : Double,
  fast : Bool,
) -> PdfDocument raise PdfError {
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

///|
let pdf_impose_cpdf_stamp_name : PdfName = pdf_page_name("/CPDFSTAMP")

///|
fn pdf_impose_border_ops(
  x : Double,
  y : Double,
  width : Double,
  height : Double,
  line_width : Double,
) -> Array[PdfContentOp] {
  [
    pdf_content_begin_artifact(),
    Op_q,
    Op_BMC(pdf_impose_cpdf_stamp_name),
    Op_rg(0.0, 0.0, 0.0),
    Op_RG(0.0, 0.0, 0.0),
    Op_w(line_width),
    Op_re(x, y, width, height),
    Op_s,
    Op_EMC,
    Op_Q,
    pdf_content_end_artifact(),
  ]
}

///|
#warnings("-unused_value")
fn PdfDocument::pdf_impose_add_border(
  self : PdfDocument,
  line_width : Double,
  fast : Bool,
) -> PdfDocument raise PdfError {
  let end_page = self.endpage()
  if line_width == 0.0 || end_page == 0 {
    self
  } else {
    let pages = self.pages_of_pagetree()
    let first_bounds = self.parse_rectangle(pages[0].mediabox)
    let inset = line_width / 2.0
    self.append_page_content_ops(
      pdf_impose_all_pages(end_page),
      pdf_impose_border_ops(
        first_bounds.min_x + inset,
        first_bounds.min_y + inset,
        first_bounds.max_x - line_width,
        first_bounds.max_y - line_width,
        line_width,
      ),
      fast~,
    )
  }
}

///|
let pdf_impose_matrix_key_name : PdfName = pdf_page_name("/Matrix")

///|
fn pdf_impose_pattern_name_used(
  used_names : ArrayView[PdfName],
  name : PdfName,
) -> Bool {
  for used_name in used_names {
    if used_name == name {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn pdf_impose_pattern_add_used(
  used_names : Array[PdfName],
  name : PdfName,
) -> Unit {
  if !pdf_impose_pattern_name_used(used_names, name) {
    used_names.push(name)
  }
}

///|
fn PdfDocument::pdf_impose_patterns_used_with_scn(
  self : PdfDocument,
  content : ArrayView[PdfObject],
  resources : PdfObject,
) -> Array[PdfName] raise PdfError {
  let used_names : Array[PdfName] = []
  match self.lookup_direct(pdf_page_pattern_resource_name, resources) {
    Some(_) => {
      let ops = self.parse_content_ops_with_resources(resources, content)
      for op in ops {
        match op {
          Op_scnName(name, []) | Op_SCNName(name, []) =>
            pdf_impose_pattern_add_used(used_names, name)
          _ => ()
        }
      }
    }
    None => ()
  }
  used_names
}

///|
fn pdf_impose_xobject_done(done : ArrayView[Int], number : Int) -> Bool {
  for item in done {
    if item == number {
      break true
    }
  } nobreak {
    false
  }
}

///|
fn PdfDocument::pdf_impose_change_pattern_object(
  self : PdfDocument,
  matrix : TransformMatrix,
  pattern : PdfObject,
) -> PdfObject raise PdfError {
  let old_pattern = self.direct(pattern)
  let existing = self.parse_matrix(pdf_impose_matrix_key_name, old_pattern)
  let new_matrix = transform_matrix_compose(matrix, existing)
  PdfIndirect(
    self.add_object(
      old_pattern.add_dict_entry(
        pdf_impose_matrix_key_name,
        pdf_object_of_matrix(new_matrix),
      ),
    ),
  )
}

///|
fn PdfDocument::pdf_impose_change_pattern_matrices_resources(
  self : PdfDocument,
  matrix : TransformMatrix,
  resources : PdfObject,
  names_used_with_scn : ArrayView[PdfName],
  xobjects_done : Array[Int],
) -> PdfObject raise PdfError {
  match self.lookup_direct(pdf_page_xobject_key(), resources) {
    Some(PdfDictionary(entries)) =>
      for entry in entries {
        match entry.1 {
          PdfIndirect(number) =>
            self.pdf_impose_change_pattern_matrices_xobject(
              matrix,
              entry.1,
              number,
              xobjects_done,
            )
          _ => raise DictionaryExpected
        }
      }
    _ => ()
  }
  match self.lookup_direct(pdf_page_pattern_resource_name, resources) {
    Some(PdfDictionary(patterns)) => {
      let entries : Array[(PdfName, PdfObject)] = []
      for entry in patterns {
        let (name, pattern) = entry
        if pdf_impose_pattern_name_used(names_used_with_scn, name) {
          entries.push(
            (name, self.pdf_impose_change_pattern_object(matrix, pattern)),
          )
        } else {
          entries.push(entry)
        }
      }
      resources.add_dict_entry(
        pdf_page_pattern_resource_name,
        PdfDictionary(entries),
      )
    }
    _ => resources
  }
}

///|
fn PdfDocument::pdf_impose_change_pattern_matrices_xobject(
  self : PdfDocument,
  matrix : TransformMatrix,
  xobject : PdfObject,
  xobject_number : Int,
  xobjects_done : Array[Int],
) -> Unit raise PdfError {
  if pdf_impose_xobject_done(xobjects_done, xobject_number) {
    ()
  } else {
    xobjects_done.push(xobject_number)
    let direct_xobject = self.direct(xobject)
    match self.lookup_direct(pdf_page_subtype_key(), direct_xobject) {
      Some(PdfNameObject(name)) if name == pdf_page_type_form() => {
        let resources = match
          self.lookup_direct(pdf_page_resources_key(), direct_xobject) {
          Some(value) => value
          None => PdfDictionary([])
        }
        let used = self.pdf_impose_patterns_used_with_scn(
          [direct_xobject],
          resources,
        )
        match self.lookup_direct(pdf_page_resources_key(), direct_xobject) {
          Some(_) => {
            let updated_resources = self.pdf_impose_change_pattern_matrices_resources(
              matrix, resources, used, xobjects_done,
            )
            self.add_object_given_number(
              xobject_number,
              direct_xobject.add_dict_entry(
                pdf_page_resources_key(),
                updated_resources,
              ),
            )
          }
          None => ()
        }
      }
      _ => ()
    }
  }
}

///|
fn PdfDocument::pdf_impose_change_pattern_matrices_page(
  self : PdfDocument,
  matrix : TransformMatrix,
  page : PdfPage,
) -> PdfPage raise PdfError {
  let used = self.pdf_impose_patterns_used_with_scn(
    page.content,
    page.resources,
  )
  let xobjects_done : Array[Int] = []
  {
    ..page,
    resources: self.pdf_impose_change_pattern_matrices_resources(
      matrix,
      page.resources,
      used,
      xobjects_done,
    ),
  }
}

///|
#warnings("-unused_value")
fn PdfDocument::pdf_impose_transform_content(
  self : PdfDocument,
  resources : PdfObject,
  matrix : TransformMatrix,
  content : ArrayView[PdfObject],
  fast : Bool,
) -> Array[PdfObject] raise PdfError {
  if fast {
    let output : Array[PdfObject] = [
      pdf_content_stream_of_ops([Op_q, Op_cm(matrix)]),
    ]
    pdf_impose_push_objects(output, content)
    output.push(pdf_content_stream_of_ops([Op_Q]))
    output
  } else {
    let old_ops = self.parse_content_ops_with_resources(resources, content)
    let protected_ops = pdf_impose_concat_ops(
      pdf_page_protect(old_ops),
      old_ops,
    )
    [
      pdf_content_stream_of_ops(
        pdf_impose_concat_ops(
          [Op_q, Op_cm(matrix)],
          pdf_impose_concat_ops(protected_ops, [Op_Q]),
        ),
      ),
    ]
  }
}

///|
fn PdfDocument::pdf_impose_combine_page_resources(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
) -> PdfObject {
  let mut resources = pages[0].resources
  for index in 1..<pages.length() {
    resources = self.combine_pdf_resources(resources, pages[index].resources)
  }
  resources
}

///|
fn PdfDocument::pdf_impose_combine_page_rests(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
) -> PdfObject {
  let mut rest = pages[0].rest
  for index in 1..<pages.length() {
    rest = self.combine_pdf_rests(rest, pages[index].rest)
  }
  rest
}

///|
#warnings("-unused_value")
fn PdfDocument::pdf_impose_pages_core(
  self : PdfDocument,
  pages : ArrayView[PdfPage],
  fit : Bool,
  x : Int,
  y : Int,
  columns : Bool,
  rtl : Bool,
  btt : Bool,
  center : Bool,
  margin : Double,
  output_mediabox : PdfObject,
  fast : Bool,
  fit_extra_hspace : Double,
  fit_extra_vspace : Double,
) -> PdfPage raise PdfError {
  if pages.length() == 0 {
    raise BadNumberArgument("impose: pages must not be empty")
  }
  let first_page = pages[0]
  let transforms = self.pdf_impose_transforms(
    fit,
    x,
    y,
    columns,
    rtl,
    btt,
    center,
    margin,
    first_page.mediabox,
    output_mediabox,
    fit_extra_hspace,
    fit_extra_vspace,
    pages.length(),
  )
  for index in 0..<pages.length() {
    self.transform_annotations(transforms[index], pages[index].rest)
  }
  let transformed_pages : Array[PdfPage] = []
  for index in 0..<pages.length() {
    transformed_pages.push(
      self.pdf_impose_change_pattern_matrices_page(
        transforms[index],
        pages[index],
      ),
    )
  }
  let resources = self.pdf_impose_combine_page_resources(transformed_pages)
  let rest = self.pdf_impose_combine_page_rests(transformed_pages)
  let content : Array[PdfObject] = []
  for index in 0..<transformed_pages.length() {
    pdf_impose_push_objects(
      content,
      self.pdf_impose_transform_content(
        resources,
        transforms[index],
        transformed_pages[index].content,
        fast,
      ),
    )
  }
  {
    mediabox: output_mediabox,
    rotate: first_page.rotate,
    content,
    resources,
    rest,
  }
}

///|
#warnings("-unused_value")
fn PdfDocument::pdf_impose_transforms(
  self : PdfDocument,
  fit : Bool,
  x : Int,
  y : Int,
  columns : Bool,
  rtl : Bool,
  btt : Bool,
  center : Bool,
  margin : Double,
  mediabox : PdfObject,
  output_mediabox : PdfObject,
  fit_extra_hspace : Double,
  fit_extra_vspace : Double,
  count : Int,
) -> Array[TransformMatrix] raise PdfError {
  pdf_impose_validate_transform_inputs(x, y, count)
  let page_box = self.parse_rectangle(mediabox)
  let width = page_box.max_x - page_box.min_x
  let height = page_box.max_y - page_box.min_y
  let final_full_cols = count % x
  let final_full_rows = count % y
  let output : Array[TransformMatrix] = []
  let mut remaining = count
  let mut cent_extra_x = 0.0
  let mut cent_extra_y = 0.0
  if columns {
    for col = 0; col < x; col = col + 1 {
      if center && remaining < y && cent_extra_y == 0.0 {
        cent_extra_y = -(height * (y - remaining).to_double()) / 2.0
      }
      for row = y - 1; row >= 0; row = row - 1 {
        let original_row = row
        let (ordered_row, ordered_col) = pdf_impose_order(
          row, col, x, y, rtl, btt,
        )
        let adjusted_row = pdf_impose_adjusted_row(
          original_row, y, final_full_rows, remaining, center,
        )
        if remaining > 0 {
          output.push(
            self.pdf_impose_transform_for_slot(
              fit,
              x,
              rtl,
              btt,
              margin,
              output_mediabox,
              fit_extra_hspace,
              fit_extra_vspace,
              cent_extra_x,
              cent_extra_y,
              adjusted_row,
              ordered_col,
              width * ordered_col.to_double(),
              height * ordered_row.to_double(),
            ),
          )
        }
        remaining -= 1
      }
    }
  } else {
    for row = y - 1; row >= 0; row = row - 1 {
      if center && remaining < x && cent_extra_x == 0.0 {
        cent_extra_x = width * (x - remaining).to_double() / 2.0
      }
      for col = 0; col < x; col = col + 1 {
        let original_col = col
        let (ordered_row, ordered_col) = pdf_impose_order(
          row, col, x, y, rtl, btt,
        )
        let adjusted_col = pdf_impose_adjusted_col(
          original_col, x, final_full_cols, remaining, center,
        )
        if remaining > 0 {
          output.push(
            self.pdf_impose_transform_for_slot(
              fit,
              x,
              rtl,
              btt,
              margin,
              output_mediabox,
              fit_extra_hspace,
              fit_extra_vspace,
              cent_extra_x,
              cent_extra_y,
              ordered_row,
              adjusted_col,
              width * ordered_col.to_double(),
              height * ordered_row.to_double(),
            ),
          )
        }
        remaining -= 1
      }
    }
  }
  output
}
