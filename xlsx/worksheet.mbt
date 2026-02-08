///|
fn Worksheet::ensure_stream_idle(self : Worksheet) -> Unit raise XlsxError {
  if self.stream_state != Idle {
    raise StreamModeConflict(msg="worksheet is in stream writer mode")
  }
}

///|
fn Worksheet::sorted_cells(self : Worksheet) -> Array[Cell] {
  let sorted : Array[Cell] = []
  for cell in self.cells {
    sorted.push(cell)
  }
  sort_cells(sorted)
  sorted
}

///|
fn parse_range_ref(
  range_ref : StringView,
) -> (Int, Int, Int, Int) raise XlsxError {
  let parts : Array[String] = []
  for part in range_ref.split(":") {
    parts.push(part.to_string())
  }
  if parts.length() != 2 {
    raise InvalidCellRef(value=range_ref.to_string())
  }
  let (row1, col1) = cell_ref_to_rc(parts[0])
  let (row2, col2) = cell_ref_to_rc(parts[1])
  let min_row = if row1 < row2 { row1 } else { row2 }
  let max_row = if row1 > row2 { row1 } else { row2 }
  let min_col = if col1 < col2 { col1 } else { col2 }
  let max_col = if col1 > col2 { col1 } else { col2 }
  (min_row, min_col, max_row, max_col)
}

///|
fn normalize_range_ref(range_ref : StringView) -> String raise XlsxError {
  let (min_row, min_col, max_row, max_col) = parse_range_ref(range_ref)
  let start_ref = cell_ref_from(min_row, min_col)
  let end_ref = cell_ref_from(max_row, max_col)
  "\{start_ref}:\{end_ref}"
}

///|
fn cell_in_bounds(
  row : Int,
  col : Int,
  min_row : Int,
  min_col : Int,
  max_row : Int,
  max_col : Int,
) -> Bool {
  row >= min_row && row <= max_row && col >= min_col && col <= max_col
}

///|
fn normalize_cell_or_range_ref(
  reference : StringView,
) -> String raise XlsxError {
  if reference.contains(":") {
    normalize_range_ref(reference)
  } else {
    let (row, col) = cell_ref_to_rc(reference)
    cell_ref_from(row, col)
  }
}

///|
fn cell_in_reference(
  reference : StringView,
  row : Int,
  col : Int,
) -> Bool raise XlsxError {
  if reference.contains(":") {
    let (min_row, min_col, max_row, max_col) = parse_range_ref(reference)
    cell_in_bounds(row, col, min_row, min_col, max_row, max_col)
  } else {
    let (target_row, target_col) = cell_ref_to_rc(reference)
    target_row == row && target_col == col
  }
}

///|
fn Worksheet::merged_anchor_for_cell(
  self : Worksheet,
  row : Int,
  col : Int,
) -> String? raise XlsxError {
  for range_ref in self.merged_cells {
    let (min_row, min_col, max_row, max_col) = parse_range_ref(range_ref)
    if cell_in_bounds(row, col, min_row, min_col, max_row, max_col) {
      return Some(cell_ref_from(min_row, min_col))
    }
  }
  None
}

///|
pub fn Worksheet::set_cell(
  self : Worksheet,
  reference : String,
  value : String,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let (row, col) = cell_ref_to_rc(reference)
  let canonical = cell_ref_from(row, col)
  match self.cell_index_of(row, col) {
    Some(i) => {
      let style_id = self.cells[i].style_id
      self.cells[i] = {
        reference: canonical,
        row,
        col,
        value,
        value_type: String,
        rich_text: None,
        formula: None,
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id,
      }
    }
    None => {
      let index = self.cells.length()
      self.cells.push({
        reference: canonical,
        row,
        col,
        value,
        value_type: String,
        rich_text: None,
        formula: None,
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id: 0,
      })
      self.record_cell_index_if_valid(row, col, index)
    }
  }
}

///|
pub fn Worksheet::get_cell(
  self : Worksheet,
  reference : StringView,
) -> String? raise XlsxError {
  let (row, col) = cell_ref_to_rc(reference)
  match self.cell_index_of(row, col) {
    Some(i) => Some(self.cells[i].value)
    None => None
  }
}

///|
pub fn Worksheet::set_cell_value(
  self : Worksheet,
  reference : String,
  value : CellValue,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let (row, col) = cell_ref_to_rc(reference)
  let canonical = cell_ref_from(row, col)
  let value_type = cell_value_type(value)
  let raw_value = cell_value_raw_string(value)
  match self.cell_index_of(row, col) {
    Some(i) => {
      let style_id = self.cells[i].style_id
      self.cells[i] = {
        reference: canonical,
        row,
        col,
        value: raw_value,
        value_type,
        rich_text: None,
        formula: None,
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id,
      }
    }
    None => {
      let index = self.cells.length()
      self.cells.push({
        reference: canonical,
        row,
        col,
        value: raw_value,
        value_type,
        rich_text: None,
        formula: None,
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id: 0,
      })
      self.record_cell_index_if_valid(row, col, index)
    }
  }
}

///|
pub fn Worksheet::get_cell_value_raw(
  self : Worksheet,
  reference : StringView,
) -> CellValue? raise XlsxError {
  let (row, col) = cell_ref_to_rc(reference)
  match self.cell_index_of(row, col) {
    Some(i) =>
      Some(cell_value_from_raw(self.cells[i].value_type, self.cells[i].value))
    None => None
  }
}

///|
pub fn Worksheet::get_cell_type(
  self : Worksheet,
  reference : StringView,
) -> CellValueType? raise XlsxError {
  match self.get_cell_value_raw(reference) {
    Some(value) => Some(cell_value_type(value))
    None => None
  }
}

///|
pub fn Worksheet::set_auto_filter(
  self : Worksheet,
  range_ref : String,
  options : ArrayView[AutoFilterOption],
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let filter = auto_filter_from_options(range_ref, options)
  self.auto_filter = Some(filter)
}

///|
pub fn Worksheet::clear_auto_filter(self : Worksheet) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  self.auto_filter = None
}

///|
pub fn Worksheet::set_cell_rich_text(
  self : Worksheet,
  reference : String,
  runs : ArrayView[RichTextRun],
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let total = rich_text_total_units(runs)
  if total > max_cell_chars {
    raise CellTextTooLong(len=total)
  }
  let (row, col) = cell_ref_to_rc(reference)
  let canonical = cell_ref_from(row, col)
  let stored_runs : Array[RichTextRun] = []
  for run in runs {
    stored_runs.push(run)
  }
  let value = rich_text_plain_text(runs)
  match self.cell_index_of(row, col) {
    Some(i) => {
      let style_id = self.cells[i].style_id
      self.cells[i] = {
        reference: canonical,
        row,
        col,
        value,
        value_type: String,
        rich_text: Some(stored_runs),
        formula: None,
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id,
      }
    }
    None => {
      let index = self.cells.length()
      self.cells.push({
        reference: canonical,
        row,
        col,
        value,
        value_type: String,
        rich_text: Some(stored_runs),
        formula: None,
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id: 0,
      })
      self.record_cell_index_if_valid(row, col, index)
    }
  }
}

///|
pub fn Worksheet::get_cell_rich_text(
  self : Worksheet,
  reference : StringView,
) -> Array[RichTextRun]? raise XlsxError {
  let (row, col) = cell_ref_to_rc(reference)
  match self.cell_index_of(row, col) {
    Some(i) => {
      let cell = self.cells[i]
      if cell.value_type != String {
        None
      } else {
        match cell.rich_text {
          Some(runs) => {
            let copied : Array[RichTextRun] = []
            for run in runs {
              copied.push(run)
            }
            Some(copied)
          }
          None => {
            let runs : Array[RichTextRun] = []
            runs.push({ text: cell.value, font: None })
            Some(runs)
          }
        }
      }
    }
    None => None
  }
}

///|
pub fn Worksheet::set_cell_formula(
  self : Worksheet,
  reference : String,
  formula : String,
  value? : String = "",
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let (row, col) = cell_ref_to_rc(reference)
  let canonical = cell_ref_from(row, col)
  match self.cell_index_of(row, col) {
    Some(i) => {
      let style_id = self.cells[i].style_id
      self.cells[i] = {
        reference: canonical,
        row,
        col,
        value,
        value_type: String,
        rich_text: None,
        formula: Some(formula),
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id,
      }
    }
    None => {
      let index = self.cells.length()
      self.cells.push({
        reference: canonical,
        row,
        col,
        value,
        value_type: String,
        rich_text: None,
        formula: Some(formula),
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id: 0,
      })
      self.record_cell_index_if_valid(row, col, index)
    }
  }
}

///|
pub fn Worksheet::get_cell_formula(
  self : Worksheet,
  reference : StringView,
) -> String? raise XlsxError {
  let (row, col) = cell_ref_to_rc(reference)
  match self.cell_index_of(row, col) {
    Some(i) =>
      match self.cells[i].formula {
        Some(value) => if value == "" { None } else { Some(value) }
        None => None
      }
    None => None
  }
}

///|
pub fn Worksheet::set_cell_formula_opts(
  self : Worksheet,
  reference : String,
  formula : String,
  opts? : FormulaOpts = FormulaOpts::new(),
  value? : String = "",
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let formula_kind = opts.formula_type
  match formula_kind {
    None => self.set_cell_formula(reference, formula, value~)
    Some(Normal) => self.set_cell_formula(reference, formula, value~)
    Some(DataTable) => self.set_cell_formula(reference, formula, value~)
    Some(Array) => {
      let range_ref = match opts.range_ref {
        Some(value) => normalize_range_ref(value)
        None => raise InvalidSheetOperation(msg="array formula ref missing")
      }
      let (min_row, min_col, max_row, max_col) = parse_range_ref(range_ref)
      let (master_row, master_col) = cell_ref_to_rc(reference)
      let canonical_master = cell_ref_from(master_row, master_col)
      if canonical_master != cell_ref_from(min_row, min_col) {
        raise InvalidSheetOperation(
          msg="array formula master must be top-left of ref",
        )
      }
      fn set_formula_cell(
        sheet : Worksheet,
        row : Int,
        col : Int,
        formula : String,
        formula_ref : String,
        value : String,
      ) -> Unit raise XlsxError {
        let canonical = cell_ref_from(row, col)
        match sheet.cell_index_of(row, col) {
          Some(i) => {
            let style_id = sheet.cells[i].style_id
            sheet.cells[i] = {
              reference: canonical,
              row,
              col,
              value,
              value_type: String,
              rich_text: None,
              formula: Some(formula),
              formula_type: Some(Array),
              formula_ref: Some(formula_ref),
              formula_shared_index: None,
              style_id,
            }
          }
          None => {
            let index = sheet.cells.length()
            sheet.cells.push({
              reference: canonical,
              row,
              col,
              value,
              value_type: String,
              rich_text: None,
              formula: Some(formula),
              formula_type: Some(Array),
              formula_ref: Some(formula_ref),
              formula_shared_index: None,
              style_id: 0,
            })
            sheet.record_cell_index_if_valid(row, col, index)
          }
        }
      }

      for row in min_row..<=max_row {
        for col in min_col..<=max_col {
          if row == min_row && col == min_col {
            set_formula_cell(self, row, col, formula, range_ref, value)
          } else {
            set_formula_cell(self, row, col, "", range_ref, "")
          }
        }
      }
    }
    Some(Shared) => {
      let range_ref = match opts.range_ref {
        Some(value) => normalize_range_ref(value)
        None => raise InvalidSheetOperation(msg="shared formula ref missing")
      }
      let (min_row, min_col, max_row, max_col) = parse_range_ref(range_ref)
      let (master_row, master_col) = cell_ref_to_rc(reference)
      let canonical_master = cell_ref_from(master_row, master_col)
      if canonical_master != cell_ref_from(min_row, min_col) {
        raise InvalidSheetOperation(
          msg="shared formula master must be top-left of ref",
        )
      }
      let mut max_si = -1
      for cell in self.cells {
        match cell.formula_shared_index {
          Some(si) => if si > max_si { max_si = si }
          None => ()
        }
      }
      let shared_index = max_si + 1
      fn set_shared_cell(
        sheet : Worksheet,
        row : Int,
        col : Int,
        formula : String,
        formula_ref : String?,
        shared_index : Int,
        value : String,
      ) -> Unit raise XlsxError {
        let canonical = cell_ref_from(row, col)
        match sheet.cell_index_of(row, col) {
          Some(i) => {
            let style_id = sheet.cells[i].style_id
            sheet.cells[i] = {
              reference: canonical,
              row,
              col,
              value,
              value_type: String,
              rich_text: None,
              formula: Some(formula),
              formula_type: Some(Shared),
              formula_ref,
              formula_shared_index: Some(shared_index),
              style_id,
            }
          }
          None => {
            let index = sheet.cells.length()
            sheet.cells.push({
              reference: canonical,
              row,
              col,
              value,
              value_type: String,
              rich_text: None,
              formula: Some(formula),
              formula_type: Some(Shared),
              formula_ref,
              formula_shared_index: Some(shared_index),
              style_id: 0,
            })
            sheet.record_cell_index_if_valid(row, col, index)
          }
        }
      }

      for row in min_row..<=max_row {
        for col in min_col..<=max_col {
          if row == min_row && col == min_col {
            set_shared_cell(
              self,
              row,
              col,
              formula,
              Some(range_ref),
              shared_index,
              value,
            )
          } else {
            set_shared_cell(self, row, col, "", None, shared_index, "")
          }
        }
      }
    }
  }
}

///|
pub fn Worksheet::set_cell_hyperlink(
  self : Worksheet,
  reference : String,
  target : String,
  link_type : HyperlinkType,
  display? : String = "",
  tooltip? : String = "",
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let (row, col) = cell_ref_to_rc(reference)
  let canonical = cell_ref_from(row, col)
  let resolved = match self.merged_anchor_for_cell(row, col) {
    Some(value) => value
    None => canonical
  }
  if link_type == Unset {
    self.remove_cell_hyperlink(resolved)
    return
  }
  let display_value = if display == "" { None } else { Some(display) }
  let tooltip_value = if tooltip == "" { None } else { Some(tooltip) }
  let normalized_ref = normalize_cell_or_range_ref(resolved)
  let mut updated = false
  for i, link in self.hyperlinks {
    if link.reference == normalized_ref {
      self.hyperlinks[i] = {
        reference: normalized_ref,
        target,
        link_type,
        display: display_value,
        tooltip: tooltip_value,
      }
      updated = true
      break
    }
  }
  if !updated {
    if self.hyperlinks.length() > max_sheet_hyperlinks {
      raise HyperlinkLimitExceeded(limit=max_sheet_hyperlinks)
    }
    self.hyperlinks.push({
      reference: normalized_ref,
      target,
      link_type,
      display: display_value,
      tooltip: tooltip_value,
    })
  }
}

///|
pub fn Worksheet::set_cell_hyperlink_opts(
  self : Worksheet,
  reference : String,
  target : String,
  link_type : HyperlinkType,
  opts? : HyperlinkOpts = HyperlinkOpts::new(),
) -> Unit raise XlsxError {
  let display = match opts.display {
    Some(value) => value
    None => ""
  }
  let tooltip = match opts.tooltip {
    Some(value) => value
    None => ""
  }
  self.set_cell_hyperlink(reference, target, link_type, display~, tooltip~)
}

///|
pub fn Worksheet::get_cell_hyperlink(
  self : Worksheet,
  reference : StringView,
) -> Hyperlink? raise XlsxError {
  let (row, col) = cell_ref_to_rc(reference)
  for link in self.hyperlinks {
    if cell_in_reference(link.reference, row, col) {
      return Some(link)
    }
  }
  None
}

///|
pub fn Worksheet::remove_cell_hyperlink(
  self : Worksheet,
  reference : StringView,
) -> Unit raise XlsxError {
  let (row, col) = cell_ref_to_rc(reference)
  let updated : Array[Hyperlink] = []
  for link in self.hyperlinks {
    if cell_in_reference(link.reference, row, col) {
      continue
    }
    updated.push(link)
  }
  self.hyperlinks.clear()
  self.hyperlinks.append(updated[:])
}

///|
pub fn Worksheet::add_comment(
  self : Worksheet,
  comment : Comment,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let (row, col) = cell_ref_to_rc(comment.cell)
  let canonical = cell_ref_from(row, col)
  for entry in self.comments {
    if entry.cell == canonical {
      raise CommentAlreadyExists(cell=canonical)
    }
  }
  let author_name = if comment.author == "" { "Author" } else { comment.author }
  let author = if count_utf16_units(author_name) > max_comment_author_chars {
    truncate_utf16_units(author_name, max_comment_author_chars)
  } else {
    author_name
  }
  let paragraph : Array[RichTextRun] = []
  for run in comment.paragraph {
    paragraph.push(run)
  }
  self.comments.push({
    cell: canonical,
    author,
    text: comment.text,
    paragraph,
    width: comment.width,
    height: comment.height,
  })
}

///|
pub fn Worksheet::delete_comment(
  self : Worksheet,
  cell : StringView,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let (row, col) = cell_ref_to_rc(cell)
  let canonical = cell_ref_from(row, col)
  let updated : Array[Comment] = []
  for entry in self.comments {
    if entry.cell == canonical {
      continue
    }
    updated.push(entry)
  }
  self.comments.clear()
  self.comments.append(updated[:])
}

///|
pub fn Worksheet::set_cell_style(
  self : Worksheet,
  reference : String,
  style_id : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if style_id < 0 {
    raise InvalidStyleId(index=style_id)
  }
  let (row, col) = cell_ref_to_rc(reference)
  let canonical = cell_ref_from(row, col)
  match self.cell_index_of(row, col) {
    Some(i) => {
      let cell = self.cells[i]
      self.cells[i] = {
        reference: canonical,
        row,
        col,
        value: cell.value,
        value_type: cell.value_type,
        rich_text: cell.rich_text,
        formula: cell.formula,
        formula_type: cell.formula_type,
        formula_ref: cell.formula_ref,
        formula_shared_index: cell.formula_shared_index,
        style_id,
      }
    }
    None => {
      let index = self.cells.length()
      self.cells.push({
        reference: canonical,
        row,
        col,
        value: "",
        value_type: String,
        rich_text: None,
        formula: None,
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id,
      })
      self.record_cell_index_if_valid(row, col, index)
    }
  }
}

///|
pub fn Worksheet::get_cell_style(
  self : Worksheet,
  reference : StringView,
) -> Int? raise XlsxError {
  let (row, col) = cell_ref_to_rc(reference)
  match self.cell_index_of(row, col) {
    Some(i) => Some(self.cells[i].style_id)
    None => None
  }
}

///|
pub fn Worksheet::set_cell_style_rc(
  self : Worksheet,
  row : Int,
  col : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if style_id < 0 {
    raise InvalidStyleId(index=style_id)
  }
  let reference = cell_ref_from(row, col)
  match self.cell_index_of(row, col) {
    Some(i) => {
      let cell = self.cells[i]
      self.cells[i] = {
        reference,
        row,
        col,
        value: cell.value,
        value_type: cell.value_type,
        rich_text: cell.rich_text,
        formula: cell.formula,
        formula_type: cell.formula_type,
        formula_ref: cell.formula_ref,
        formula_shared_index: cell.formula_shared_index,
        style_id,
      }
    }
    None => {
      let index = self.cells.length()
      self.cells.push({
        reference,
        row,
        col,
        value: "",
        value_type: String,
        rich_text: None,
        formula: None,
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id,
      })
      self.record_cell_index_if_valid(row, col, index)
    }
  }
}

///|
pub fn Worksheet::get_cell_style_rc(
  self : Worksheet,
  row : Int,
  col : Int,
) -> Int? raise XlsxError {
  if row <= 0 || col <= 0 {
    raise InvalidCellRef(value="\{col}:\{row}")
  }
  match self.cell_index_of(row, col) {
    Some(i) => Some(self.cells[i].style_id)
    None => None
  }
}

///|
pub fn Worksheet::merge_cells(
  self : Worksheet,
  range_ref : String,
) -> Unit raise XlsxError {
  let normalized = normalize_range_ref(range_ref)
  for existing in self.merged_cells {
    if existing == normalized {
      return
    }
  }
  self.merged_cells.push(normalized)
}

///|
pub fn Worksheet::unmerge_cells(
  self : Worksheet,
  range_ref : String,
) -> Unit raise XlsxError {
  let normalized = normalize_range_ref(range_ref)
  for i, existing in self.merged_cells {
    if existing == normalized {
      ignore(self.merged_cells.remove(i))
      return
    }
  }
}

///|
pub fn Worksheet::add_table(
  self : Worksheet,
  range_ref : String,
  name : String,
  columns : ArrayView[String],
  display_name? : String = "",
  style_name? : String = "TableStyleMedium9",
  show_first_column? : Bool = false,
  show_last_column? : Bool = false,
  show_row_stripes? : Bool = true,
  show_column_stripes? : Bool = false,
  show_header_row? : Bool = true,
) -> Table raise XlsxError {
  let table = Table::new(
    name,
    range_ref,
    columns,
    display_name~,
    style_name~,
    show_first_column~,
    show_last_column~,
    show_row_stripes~,
    show_column_stripes~,
    show_header_row~,
  )
  self.tables.push(table)
  table
}

///|
pub fn Worksheet::delete_table(
  self : Worksheet,
  name : StringView,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let updated : Array[Table] = []
  let mut removed = false
  let target = name.to_string()
  for table in self.tables {
    if table.name == target || table.display_name == target {
      removed = true
      continue
    }
    updated.push(table)
  }
  if !removed {
    raise TableNotFound(name=target)
  }
  self.tables.clear()
  self.tables.append(updated[:])
}

///|
pub fn Worksheet::add_sparkline(
  self : Worksheet,
  location : String,
  range_ref : String,
  sparkline_type? : SparklineType = Line,
) -> Unit raise XlsxError {
  self.add_sparkline_group([location], [range_ref], sparkline_type~)
}

///|
pub fn Worksheet::add_sparkline_group(
  self : Worksheet,
  locations : ArrayView[String],
  ranges : ArrayView[String],
  sparkline_type? : SparklineType = Line,
) -> Unit raise XlsxError {
  if locations.length() == 0 || ranges.length() == 0 {
    raise InvalidSparkline(msg="sparkline inputs empty")
  }
  if locations.length() != ranges.length() {
    raise InvalidSparkline(msg="sparkline inputs mismatch")
  }
  let sparklines = build_sparklines(locations, ranges)
  self.sparkline_groups.push({
    sparkline_type,
    sparklines,
    options: SparklineGroupOptions::new(),
  })
}

///|
pub fn Worksheet::add_sparkline_options(
  self : Worksheet,
  options : SparklineOptions,
) -> Unit raise XlsxError {
  let group = build_sparkline_group_from_options(options)
  self.sparkline_groups.push(group)
}

///|
pub fn Worksheet::add_pivot_table_xml(
  self : Worksheet,
  table_xml : String,
  cache_definition_xml : String,
  cache_records_xml? : String = "",
  name? : String = "",
) -> PivotTable raise XlsxError {
  self.ensure_stream_idle()
  let pivot = PivotTable::new(
    table_xml,
    cache_definition_xml,
    cache_records_xml~,
    name~,
  )
  self.pivot_tables.push(pivot)
  pivot
}

///|
pub fn Worksheet::add_pivot_table(
  self : Worksheet,
  table_xml : String,
  cache_definition_xml : String,
  cache_records_xml? : String = "",
  name? : String = "",
) -> PivotTable raise XlsxError {
  self.add_pivot_table_xml(
    table_xml,
    cache_definition_xml,
    cache_records_xml~,
    name~,
  )
}

///|
pub fn Worksheet::delete_pivot_table(
  self : Worksheet,
  name : StringView,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let target = name.to_string()
  if target == "" {
    raise InvalidSheetOperation(msg="pivot table name empty")
  }
  let remaining : Array[PivotTable] = []
  let mut removed = false
  for pivot in self.pivot_tables {
    if pivot.name == target {
      removed = true
    } else {
      remaining.push(pivot)
    }
  }
  if !removed {
    raise InvalidSheetOperation(msg="pivot table not found")
  }
  self.pivot_tables.clear()
  for pivot in remaining {
    self.pivot_tables.push(pivot)
  }
}

///|
fn normalize_extension(extension : StringView) -> String raise XlsxError {
  let value = extension.to_string()
  let trimmed = if value.has_prefix(".") {
    if value.length() <= 1 {
      raise UnsupportedFeature(msg="image extension missing")
    }
    let view = value[1:] catch {
        _ => raise UnsupportedFeature(msg="invalid image extension")
      }
    view.to_string()
  } else {
    value
  }
  if trimmed == "" {
    raise UnsupportedFeature(msg="image extension missing")
  }
  trimmed
}

///|
fn normalize_extension_lower_requires_dot(
  extension : StringView,
  unsupported_msg : StringView,
) -> String raise XlsxError {
  let raw = extension.to_string()
  if !raw.has_prefix(".") || raw.length() <= 1 {
    raise UnsupportedFeature(msg=unsupported_msg.to_string())
  }
  let view = raw[1:] catch {
      _ => raise UnsupportedFeature(msg=unsupported_msg.to_string())
    }
  let trimmed = view.to_string()
  if trimmed == "" {
    raise UnsupportedFeature(msg=unsupported_msg.to_string())
  }
  trimmed.to_lower()
}

///|
fn check_header_footer_image_size(
  value : StringView,
  field_name : StringView,
) -> Unit raise XlsxError {
  if value.to_string() == "" {
    raise InvalidHeaderFooter(msg="\{field_name.to_string()} empty")
  }
}

///|
fn normalize_picture_options(
  offset_x : Int,
  offset_y : Int,
  scale_x : Double,
  scale_y : Double,
  hyperlink : String,
  hyperlink_type : HyperlinkType,
) -> (Int, Int, Double, Double, String, HyperlinkType) raise XlsxError {
  if offset_x < 0 || offset_y < 0 {
    raise InvalidSheetOperation(msg="picture offset must be >= 0")
  }
  if scale_x <= 0.0 || scale_y <= 0.0 {
    raise InvalidSheetOperation(msg="picture scale must be > 0")
  }
  if hyperlink == "" {
    return (offset_x, offset_y, scale_x, scale_y, "", Unset)
  }
  if hyperlink_type == Unset {
    raise InvalidHyperlink(msg="picture hyperlink type missing")
  }
  (offset_x, offset_y, scale_x, scale_y, hyperlink, hyperlink_type)
}

///|
let picture_emu_per_pixel = 9525

///|
let default_picture_width_px = 200

///|
let default_picture_height_px = 160

///|
let default_col_width_pixels = 64

///|
let default_row_height_pixels : Int = convert_row_height_to_pixels(15.0)

///|
let max_graphic_name_length = 254

///|
let max_graphic_alt_text_length = 65535

///|
fn convert_col_width_to_pixels(width : Double) -> Int {
  if width == 0.0 {
    return 0
  }
  let pixels = width * 8.0 + 0.5
  pixels.to_int()
}

///|
fn convert_row_height_to_pixels(height : Double) -> Int {
  if height == 0.0 {
    return 0
  }
  Double::ceil(4.0 / 3.4 * height).to_int()
}

///|
fn Worksheet::col_width_pixels(self : Worksheet, col : Int) -> Int {
  match self.col_dimensions.get(col) {
    Some(dim) =>
      if dim.hidden {
        0
      } else {
        match dim.width {
          Some(width) => convert_col_width_to_pixels(width)
          None => {
            let props = sheet_props_with_defaults(self.sheet_props)
            match props.default_col_width {
              Some(w) => convert_col_width_to_pixels(w)
              None =>
                match props.base_col_width {
                  Some(v) => convert_col_width_to_pixels(Double::from_int(v))
                  None => default_col_width_pixels
                }
            }
          }
        }
      }
    None => {
      let props = sheet_props_with_defaults(self.sheet_props)
      match props.default_col_width {
        Some(w) => convert_col_width_to_pixels(w)
        None =>
          match props.base_col_width {
            Some(v) => convert_col_width_to_pixels(Double::from_int(v))
            None => default_col_width_pixels
          }
      }
    }
  }
}

///|
fn Worksheet::row_height_pixels(self : Worksheet, row : Int) -> Int {
  match self.row_dimensions.get(row) {
    Some(dim) =>
      if dim.hidden {
        0
      } else {
        match dim.height {
          Some(height) => convert_row_height_to_pixels(height)
          None => {
            let props = sheet_props_with_defaults(self.sheet_props)
            match props.default_row_height {
              Some(h) => convert_row_height_to_pixels(h)
              None => default_row_height_pixels
            }
          }
        }
      }
    None => {
      let props = sheet_props_with_defaults(self.sheet_props)
      match props.default_row_height {
        Some(h) => convert_row_height_to_pixels(h)
        None => default_row_height_pixels
      }
    }
  }
}

///|
fn Worksheet::merged_rect_for_cell(
  self : Worksheet,
  row : Int,
  col : Int,
) -> (Int, Int, Int, Int)? raise XlsxError {
  for range_ref in self.merged_cells {
    let (min_row, min_col, max_row, max_col) = parse_range_ref(range_ref)
    if cell_in_bounds(row, col, min_row, min_col, max_row, max_col) {
      return Some((min_row, min_col, max_row, max_col))
    }
  }
  None
}

///|
fn Worksheet::anchor_cell_size_pixels(
  self : Worksheet,
  row : Int,
  col : Int,
) -> (Int, Int, Int, Int) raise XlsxError {
  match self.merged_rect_for_cell(row, col) {
    Some((min_row, min_col, max_row, max_col)) => {
      let mut cell_width = 0
      let mut cell_height = 0
      for c in min_col..<=max_col {
        cell_width = cell_width + self.col_width_pixels(c)
      }
      for r in min_row..<=max_row {
        cell_height = cell_height + self.row_height_pixels(r)
      }
      (min_row, min_col, cell_width, cell_height)
    }
    None => (row, col, self.col_width_pixels(col), self.row_height_pixels(row))
  }
}

///|
pub fn Worksheet::add_header_footer_image(
  self : Worksheet,
  options : HeaderFooterImageOptions,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let extension = normalize_extension_lower_requires_dot(
    options.extension,
    "unsupported header/footer image extension",
  )
  let content_type = match image_content_type(extension) {
    Some(value) => value
    None =>
      raise UnsupportedFeature(msg="unsupported header/footer image extension")
  }
  check_header_footer_image_size(options.width, "header/footer width")
  check_header_footer_image_size(options.height, "header/footer height")
  let image : HeaderFooterImage = {
    position: options.position,
    data: options.data,
    extension,
    content_type,
    is_footer: options.is_footer,
    first_page: options.first_page,
    width: options.width,
    height: options.height,
  }
  let updated : Array[HeaderFooterImage] = []
  for existing in self.header_footer_images {
    if existing.position == image.position &&
      existing.is_footer == image.is_footer &&
      existing.first_page == image.first_page {
      continue
    }
    updated.push(existing)
  }
  updated.push(image)
  self.header_footer_images.clear()
  self.header_footer_images.append(updated[:])
}

///|
pub fn Worksheet::add_picture_from_bytes(
  self : Worksheet,
  reference : String,
  data : Bytes,
  extension : String,
  offset_x? : Int = 0,
  offset_y? : Int = 0,
  scale_x? : Double = 1.0,
  scale_y? : Double = 1.0,
  hyperlink? : String = "",
  hyperlink_type? : HyperlinkType = Unset,
  name? : String = "",
  alt_text? : String = "",
  lock_aspect_ratio? : Bool = false,
  auto_fit? : Bool = false,
  auto_fit_ignore_aspect? : Bool = false,
  print_object? : Bool = true,
  locked? : Bool = true,
  positioning? : PicturePositioning = OneCell,
) -> Unit raise XlsxError {
  let ext = normalize_extension_lower_requires_dot(
    extension, "unsupported picture extension",
  )
  let content_type = match image_content_type(ext) {
    Some(value) => value
    None => raise UnsupportedFeature(msg="unsupported picture extension")
  }
  self.add_image(
    reference,
    data,
    ext,
    content_type,
    offset_x~,
    offset_y~,
    scale_x~,
    scale_y~,
    hyperlink~,
    hyperlink_type~,
    name~,
    alt_text~,
    lock_aspect_ratio~,
    auto_fit~,
    auto_fit_ignore_aspect~,
    print_object~,
    locked~,
    positioning~,
  )
}

///|
pub fn Worksheet::add_picture_from_bytes_with_options(
  self : Worksheet,
  reference : String,
  data : Bytes,
  extension : String,
  options : GraphicOptions,
) -> Unit raise XlsxError {
  let offset_x = match options.offset_x {
    Some(value) => value
    None => 0
  }
  let offset_y = match options.offset_y {
    Some(value) => value
    None => 0
  }
  let scale_x = match options.scale_x {
    Some(value) => value
    None => 1.0
  }
  let scale_y = match options.scale_y {
    Some(value) => value
    None => 1.0
  }
  let hyperlink = match options.hyperlink {
    Some(value) => value
    None => ""
  }
  let hyperlink_type = match options.hyperlink_type {
    Some(value) => value
    None => Unset
  }
  let name = match options.name {
    Some(value) => value
    None => ""
  }
  let alt_text = match options.alt_text {
    Some(value) => value
    None => ""
  }
  let lock_aspect_ratio = match options.lock_aspect_ratio {
    Some(value) => value
    None => false
  }
  let auto_fit = match options.auto_fit {
    Some(value) => value
    None => false
  }
  let auto_fit_ignore_aspect = match options.auto_fit_ignore_aspect {
    Some(value) => value
    None => false
  }
  let print_object = match options.print_object {
    Some(value) => value
    None => true
  }
  let locked = match options.locked {
    Some(value) => value
    None => true
  }
  let positioning = match options.positioning {
    Some(value) => value
    None => OneCell
  }
  self.add_picture_from_bytes(
    reference,
    data,
    extension,
    offset_x~,
    offset_y~,
    scale_x~,
    scale_y~,
    hyperlink~,
    hyperlink_type~,
    name~,
    alt_text~,
    lock_aspect_ratio~,
    auto_fit~,
    auto_fit_ignore_aspect~,
    print_object~,
    locked~,
    positioning~,
  )
}

///|
pub async fn Worksheet::add_picture(
  self : Worksheet,
  reference : String,
  path : String,
  offset_x? : Int = 0,
  offset_y? : Int = 0,
  scale_x? : Double = 1.0,
  scale_y? : Double = 1.0,
  hyperlink? : String = "",
  hyperlink_type? : HyperlinkType = Unset,
  name? : String = "",
  alt_text? : String = "",
  lock_aspect_ratio? : Bool = false,
  auto_fit? : Bool = false,
  auto_fit_ignore_aspect? : Bool = false,
  print_object? : Bool = true,
  locked? : Bool = true,
  positioning? : PicturePositioning = OneCell,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let extension = match extension_from_path(path) {
    Some(value) => value
    None => raise UnsupportedFeature(msg="image extension missing")
  }
  let bytes = read_file_bytes(path) catch {
    err => raise InvalidSheetOperation(msg="read picture failed: \{err}")
  }
  self.add_picture_from_bytes(
    reference,
    bytes,
    ".\{extension}",
    offset_x~,
    offset_y~,
    scale_x~,
    scale_y~,
    hyperlink~,
    hyperlink_type~,
    name~,
    alt_text~,
    lock_aspect_ratio~,
    auto_fit~,
    auto_fit_ignore_aspect~,
    print_object~,
    locked~,
    positioning~,
  )
}

///|
pub async fn Worksheet::add_picture_with_options(
  self : Worksheet,
  reference : String,
  path : String,
  options : GraphicOptions,
) -> Unit raise XlsxError {
  let offset_x = match options.offset_x {
    Some(value) => value
    None => 0
  }
  let offset_y = match options.offset_y {
    Some(value) => value
    None => 0
  }
  let scale_x = match options.scale_x {
    Some(value) => value
    None => 1.0
  }
  let scale_y = match options.scale_y {
    Some(value) => value
    None => 1.0
  }
  let hyperlink = match options.hyperlink {
    Some(value) => value
    None => ""
  }
  let hyperlink_type = match options.hyperlink_type {
    Some(value) => value
    None => Unset
  }
  let name = match options.name {
    Some(value) => value
    None => ""
  }
  let alt_text = match options.alt_text {
    Some(value) => value
    None => ""
  }
  let lock_aspect_ratio = match options.lock_aspect_ratio {
    Some(value) => value
    None => false
  }
  let auto_fit = match options.auto_fit {
    Some(value) => value
    None => false
  }
  let auto_fit_ignore_aspect = match options.auto_fit_ignore_aspect {
    Some(value) => value
    None => false
  }
  let print_object = match options.print_object {
    Some(value) => value
    None => true
  }
  let locked = match options.locked {
    Some(value) => value
    None => true
  }
  let positioning = match options.positioning {
    Some(value) => value
    None => OneCell
  }
  self.add_picture(
    reference,
    path,
    offset_x~,
    offset_y~,
    scale_x~,
    scale_y~,
    hyperlink~,
    hyperlink_type~,
    name~,
    alt_text~,
    lock_aspect_ratio~,
    auto_fit~,
    auto_fit_ignore_aspect~,
    print_object~,
    locked~,
    positioning~,
  )
}

///|
pub fn Worksheet::add_image(
  self : Worksheet,
  reference : String,
  data : Bytes,
  extension : String,
  content_type : String,
  offset_x? : Int = 0,
  offset_y? : Int = 0,
  scale_x? : Double = 1.0,
  scale_y? : Double = 1.0,
  hyperlink? : String = "",
  hyperlink_type? : HyperlinkType = Unset,
  name? : String = "",
  alt_text? : String = "",
  lock_aspect_ratio? : Bool = false,
  auto_fit? : Bool = false,
  auto_fit_ignore_aspect? : Bool = false,
  print_object? : Bool = true,
  locked? : Bool = true,
  positioning? : PicturePositioning = OneCell,
) -> Unit raise XlsxError {
  let (row, col) = cell_ref_to_rc(reference)
  let ext = normalize_extension(extension)
  if name != "" && name.length() > max_graphic_name_length {
    raise GraphicNameTooLong(len=name.length(), limit=max_graphic_name_length)
  }
  if alt_text != "" && alt_text.length() > max_graphic_alt_text_length {
    raise GraphicAltTextTooLong(
      len=alt_text.length(),
      limit=max_graphic_alt_text_length,
    )
  }
  let (
    normalized_offset_x,
    normalized_offset_y,
    normalized_scale_x,
    normalized_scale_y,
    normalized_hyperlink,
    normalized_hyperlink_type,
  ) = normalize_picture_options(
    offset_x, offset_y, scale_x, scale_y, hyperlink, hyperlink_type,
  )
  let (anchor_row, anchor_col, cell_width_px, cell_height_px) = if auto_fit {
    self.anchor_cell_size_pixels(row, col)
  } else {
    (row, col, 0, 0)
  }
  let (img_w_px, img_h_px) = match
    image_dimensions_px(data[:], ext.to_lower()) {
    Some((w, h)) => (w, h)
    None => (default_picture_width_px, default_picture_height_px)
  }
  let mut base_w_px = Double::from_int(img_w_px)
  let mut base_h_px = Double::from_int(img_h_px)
  if auto_fit {
    let cw = Double::from_int(cell_width_px)
    let ch = Double::from_int(cell_height_px)
    if auto_fit_ignore_aspect {
      base_w_px = cw
      base_h_px = ch
    } else if cw < base_w_px || ch < base_h_px {
      let asp_w = cw / base_w_px
      let asp_h = ch / base_h_px
      let asp = if asp_w < asp_h { asp_w } else { asp_h }
      base_w_px = base_w_px * asp
      base_h_px = base_h_px * asp
    }
  }
  let width_emu = (Double::from_int(picture_emu_per_pixel) *
    base_w_px *
    normalized_scale_x)
    .round()
    .to_int()
  let height_emu = (Double::from_int(picture_emu_per_pixel) *
    base_h_px *
    normalized_scale_y)
    .round()
    .to_int()
  let stored_reference = if auto_fit {
    cell_ref_from(anchor_row, anchor_col)
  } else {
    reference
  }
  self.images.push({
    reference: stored_reference,
    data,
    extension: ext,
    content_type,
    offset_x: normalized_offset_x,
    offset_y: normalized_offset_y,
    scale_x: normalized_scale_x,
    scale_y: normalized_scale_y,
    width_emu,
    height_emu,
    print_object,
    locked,
    hyperlink: normalized_hyperlink,
    hyperlink_type: normalized_hyperlink_type,
    name,
    alt_text,
    lock_aspect_ratio,
    positioning,
  })
}

///|
fn image_with_reference(image : Image, reference : String) -> Image {
  {
    reference,
    data: image.data,
    extension: image.extension,
    content_type: image.content_type,
    offset_x: image.offset_x,
    offset_y: image.offset_y,
    scale_x: image.scale_x,
    scale_y: image.scale_y,
    width_emu: image.width_emu,
    height_emu: image.height_emu,
    print_object: image.print_object,
    locked: image.locked,
    hyperlink: image.hyperlink,
    hyperlink_type: image.hyperlink_type,
    name: image.name,
    alt_text: image.alt_text,
    lock_aspect_ratio: image.lock_aspect_ratio,
    positioning: image.positioning,
  }
}

///|
fn chart_with_reference(chart : Chart, reference : String) -> Chart {
  {
    reference,
    xml: chart.xml,
    offset_x: chart.offset_x,
    offset_y: chart.offset_y,
    width_emu: chart.width_emu,
    height_emu: chart.height_emu,
    print_object: chart.print_object,
    locked: chart.locked,
    positioning: chart.positioning,
  }
}

///|
pub fn Worksheet::get_pictures(
  self : Worksheet,
  cell : StringView,
) -> Array[Image] raise XlsxError {
  let (row, col) = cell_ref_to_rc(cell)
  let images : Array[Image] = []
  for image in self.images {
    let (img_row, img_col) = cell_ref_to_rc(image.reference)
    if img_row == row && img_col == col {
      images.push(image)
    }
  }
  images
}

///|
pub fn Worksheet::get_picture_cells(
  self : Worksheet,
) -> Array[String] raise XlsxError {
  let cells : Array[String] = []
  let seen : Map[String, Bool] = {}
  for image in self.images {
    let (row, col) = cell_ref_to_rc(image.reference)
    let reference = cell_ref_from(row, col)
    if !seen.contains(reference) {
      seen[reference] = true
      cells.push(reference)
    }
  }
  cells
}

///|
pub fn Worksheet::delete_picture(
  self : Worksheet,
  cell : StringView,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let (row, col) = cell_ref_to_rc(cell)
  let updated : Array[Image] = []
  for image in self.images {
    let (img_row, img_col) = cell_ref_to_rc(image.reference)
    if img_row == row && img_col == col {
      continue
    }
    updated.push(image)
  }
  self.images.clear()
  self.images.append(updated[:])
}

///|
pub fn Worksheet::add_chart(
  self : Worksheet,
  reference : String,
  xml : String,
) -> Unit raise XlsxError {
  let (_row, _col) = cell_ref_to_rc(reference)
  self.charts.push({
    reference,
    xml,
    offset_x: 0,
    offset_y: 0,
    width_emu: picture_emu_per_pixel * 480,
    height_emu: picture_emu_per_pixel * 260,
    print_object: true,
    locked: true,
    positioning: TwoCell,
  })
}

///|
pub fn Worksheet::add_chart_with_options(
  self : Worksheet,
  reference : String,
  opts : ChartOptions,
) -> Unit raise XlsxError {
  let (_row, _col) = cell_ref_to_rc(reference)
  let offset_x = match opts.format.offset_x {
    Some(value) => value
    None => 0
  }
  let offset_y = match opts.format.offset_y {
    Some(value) => value
    None => 0
  }
  let scale_x = match opts.format.scale_x {
    Some(value) => value
    None => 1.0
  }
  let scale_y = match opts.format.scale_y {
    Some(value) => value
    None => 1.0
  }
  if offset_x < 0 || offset_y < 0 {
    raise InvalidSheetOperation(msg="chart offset must be >= 0")
  }
  if scale_x <= 0.0 || scale_y <= 0.0 {
    raise InvalidSheetOperation(msg="chart scale must be > 0")
  }
  let print_object = match opts.format.print_object {
    Some(value) => value
    None => true
  }
  let locked = match opts.format.locked {
    Some(value) => value
    None => true
  }
  let positioning = match opts.format.positioning {
    Some(value) => value
    None => TwoCell
  }
  let width_emu = (Double::from_int(
      picture_emu_per_pixel * opts.dimension.width,
    ) *
    scale_x)
    .round()
    .to_int()
  let height_emu = (Double::from_int(
      picture_emu_per_pixel * opts.dimension.height,
    ) *
    scale_y)
    .round()
    .to_int()
  let xml = chart_options_to_xml(opts)
  self.charts.push({
    reference,
    xml,
    offset_x,
    offset_y,
    width_emu,
    height_emu,
    print_object,
    locked,
    positioning,
  })
}

///|
pub fn Worksheet::delete_chart(
  self : Worksheet,
  cell : StringView,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let (row, col) = cell_ref_to_rc(cell)
  let updated : Array[Chart] = []
  for chart in self.charts {
    let (chart_row, chart_col) = cell_ref_to_rc(chart.reference)
    if chart_row == row && chart_col == col {
      continue
    }
    updated.push(chart)
  }
  self.charts.clear()
  self.charts.append(updated[:])
}

///|
pub fn Worksheet::add_shape(
  self : Worksheet,
  shape : Shape,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  self.shapes.push(shape)
}

///|
pub fn Worksheet::add_vml_drawing_xml(
  self : Worksheet,
  xml : String,
) -> Unit raise XlsxError {
  if xml == "" {
    raise InvalidVmlDrawing(msg="vml drawing xml empty")
  }
  self.vml_drawing_xml = Some(xml)
}

///|
pub fn Worksheet::add_vml_drawing_hf_xml(
  self : Worksheet,
  xml : String,
) -> Unit raise XlsxError {
  if xml == "" {
    raise InvalidVmlDrawing(msg="vml drawing hf xml empty")
  }
  self.vml_drawing_hf_xml = Some(xml)
}

///|
pub fn Worksheet::add_form_control(
  self : Worksheet,
  control : FormControl,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  self.form_controls.push(control)
}

///|
pub fn Worksheet::get_form_controls(self : Worksheet) -> ArrayView[FormControl] {
  self.form_controls[:]
}

///|
pub fn Worksheet::delete_form_control(
  self : Worksheet,
  cell : StringView,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let (target_row, target_col) = cell_ref_to_rc(cell)
  let remaining : Array[FormControl] = []
  let mut removed = false
  for control in self.form_controls {
    let (row, col) = cell_ref_to_rc(control.cell)
    if row == target_row && col == target_col {
      removed = true
    } else {
      remaining.push(control)
    }
  }
  if !removed {
    return
  }
  self.form_controls.clear()
  for control in remaining {
    self.form_controls.push(control)
  }
}

///|
pub fn Worksheet::add_slicer(
  self : Worksheet,
  slicer : Slicer,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  self.slicers.push(slicer)
}

///|
pub fn Worksheet::get_slicers(self : Worksheet) -> ArrayView[Slicer] {
  self.slicers[:]
}

///|
pub fn Worksheet::delete_slicer(
  self : Worksheet,
  name : StringView,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let target = name.to_string()
  if target == "" {
    raise InvalidSheetOperation(msg="slicer name empty")
  }
  let remaining : Array[Slicer] = []
  let mut removed = false
  for slicer in self.slicers {
    if slicer.name == target {
      removed = true
    } else {
      remaining.push(slicer)
    }
  }
  if !removed {
    raise InvalidSheetOperation(msg="slicer not found")
  }
  self.slicers.clear()
  for slicer in remaining {
    self.slicers.push(slicer)
  }
}

///|
pub fn Worksheet::add_data_validation_xml(
  self : Worksheet,
  xml : String,
) -> Unit {
  self.data_validations.push(xml)
}

///|
pub fn Worksheet::add_data_validation(
  self : Worksheet,
  dv : DataValidation,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let xml = data_validation_xml(dv)
  self.data_validations.push(xml)
}

///|
pub fn Worksheet::add_data_validation_list(
  self : Worksheet,
  range_ref : String,
  values : ArrayView[String],
  allow_blank? : Bool = true,
) -> Unit raise XlsxError {
  if values.length() == 0 {
    raise UnsupportedFeature(msg="empty validation list")
  }
  let dv = DataValidation::new(allow_blank)
  dv.set_sqref(range_ref)
  dv.set_drop_list(values)
  self.add_data_validation(dv)
}

///|
pub fn Worksheet::get_data_validations(
  self : Worksheet,
) -> Array[DataValidation] raise XlsxError {
  let validations : Array[DataValidation] = []
  for xml in self.data_validations {
    validations.push(data_validation_from_xml(xml))
  }
  validations
}

///|
pub fn Worksheet::delete_data_validation(
  self : Worksheet,
  sqrefs? : Array[String] = [],
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if sqrefs.length() == 0 {
    self.data_validations.clear()
    return
  }
  let sqref_text = sqrefs.join(" ")
  let del_cells = flat_sqref(sqref_text)
  let updated : Array[String] = []
  for xml in self.data_validations {
    let tag = match tag_attributes_in(xml, "dataValidation") {
      Some(value) => value
      None => raise InvalidXml(msg="data validation tag missing")
    }
    let sqref = match attr_value(tag, "sqref") {
      Some(value) => unescape_xml_text(value)
      None => raise InvalidXml(msg="data validation sqref missing")
    }
    let next_sqref = delete_cells_from_sqref(sqref, del_cells)
    if next_sqref == "" {
      continue
    }
    match replace_attr_value_in_open_tag(xml, "sqref", next_sqref) {
      Some(value) => updated.push(value)
      None => raise InvalidXml(msg="data validation sqref update failed")
    }
  }
  self.data_validations.clear()
  self.data_validations.append(updated[:])
}

///|
pub fn Worksheet::add_ignored_errors(
  self : Worksheet,
  range_ref : String,
  error_type : IgnoredErrorType,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if range_ref == "" {
    raise InvalidSheetOperation(msg="ignored errors range empty")
  }
  let sqref = normalize_cell_or_range_ref(range_ref)
  let entry = ignored_error_from_type(sqref, error_type)
  for existing in self.ignored_errors {
    if existing == entry {
      return
    }
  }
  self.ignored_errors.push(entry)
}

///|
pub fn Worksheet::add_conditional_format_xml(
  self : Worksheet,
  xml : String,
) -> Unit {
  self.conditional_formats.push(xml)
}

///|
let ext_uri_conditional_formatting_rule_id = "{B025F937-C7B1-47D3-B67F-A62EFF666E3E}"

///|
let ns_spreadsheet_x14 = "http://schemas.microsoft.com/office/spreadsheetml/2009/9/main"

///|
fn pad_left_dec(value : Int, width : Int) -> String {
  let text = value.to_string()
  if text.length() >= width {
    return text
  }
  let padding = width - text.length()
  String::repeat("0", padding) + text
}

///|
fn Worksheet::next_x14_cf_rule_id(self : Worksheet) -> String {
  let mut counter = self.x14_cf_rule_id_counter
  while true {
    let suffix = pad_left_dec(counter, 12)
    let id = "{00000000-0000-0000-0000-\{suffix}}"
    counter = counter + 1
    if self.x14_data_bars.get(id) is None {
      self.x14_cf_rule_id_counter = counter
      return id
    }
  }
  "{00000000-0000-0000-0000-000000000000}"
}

///|
fn inject_x14_id_ext_lst_into_cf_rule(
  rule_xml : String,
  id : StringView,
) -> String raise XlsxError {
  if rule_xml.contains("<extLst>") {
    return rule_xml
  }
  let close_tag = "</cfRule>"
  match rule_xml.find(close_tag) {
    Some(pos) => {
      let before = rule_xml[:pos] catch {
          _ => raise InvalidXml(msg="cfRule slice invalid")
        }
      let after = rule_xml[pos:] catch {
          _ => raise InvalidXml(msg="cfRule slice invalid")
        }
      "\{before}<extLst><ext uri=\"\{ext_uri_conditional_formatting_rule_id}\" xmlns:x14=\"\{ns_spreadsheet_x14}\"><x14:id>\{escape_xml_text(id)}</x14:id></ext></extLst>\{after}"
    }
    None => raise InvalidXml(msg="cfRule tag invalid")
  }
}

///|
pub fn Worksheet::set_conditional_format(
  self : Worksheet,
  range_ref : String,
  options : ArrayView[ConditionalFormatOptions],
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if options.length() == 0 {
    raise InvalidConditionalFormat(msg="options empty")
  }
  let (sqref, master_cell) = prepare_conditional_format_range(range_ref)
  let mut priority = 0
  for xml in self.conditional_formats {
    let mut count = 0
    let mut first = true
    for _ in xml.split("<cfRule") {
      if first {
        first = false
        continue
      }
      count = count + 1
    }
    priority = priority + count
  }
  let rules = conditional_format_rules_xml(options, priority, master_cell)
  let updated_rules : Array[String] = []
  for i, opt in options {
    let mut rule = rules[i]
    if opt.format_type.to_string().to_lower() == "data_bar" {
      let direction = opt.bar_direction.to_string()
      let has_direction = direction == "leftToRight" ||
        direction == "rightToLeft"
      let needs_x14 = opt.bar_solid ||
        has_direction ||
        opt.bar_border_color != ""
      if needs_x14 {
        let id = self.next_x14_cf_rule_id()
        self.x14_data_bars[id] = {
          sqref,
          bar_direction: if has_direction {
            direction
          } else {
            ""
          },
          bar_solid: opt.bar_solid,
          bar_border_color: opt.bar_border_color,
        }
        rule = inject_x14_id_ext_lst_into_cf_rule(rule, id)
      }
    }
    updated_rules.push(rule)
  }
  let xml = conditional_format_xml(sqref, updated_rules)
  self.conditional_formats.push(xml)
}

///|
pub fn Worksheet::get_conditional_formats(
  self : Worksheet,
) -> Map[String, Array[ConditionalFormatOptions]] raise XlsxError {
  let formats : Map[String, Array[ConditionalFormatOptions]] = {}
  for xml in self.conditional_formats {
    let (sqref, opts) = parse_conditional_format_xml(xml, self.x14_data_bars)
    match formats.get(sqref) {
      Some(existing) => {
        existing.append(opts[:])
        formats[sqref] = existing
      }
      None => formats[sqref] = opts
    }
  }
  formats
}

///|
pub fn Worksheet::unset_conditional_format(
  self : Worksheet,
  range_ref : String,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let del_cells = flat_sqref(
    range_ref.to_string().replace_all(old=",", new=" "),
  )
  let updated : Array[String] = []
  for xml in self.conditional_formats {
    let tag = match tag_attributes_in(xml, "conditionalFormatting") {
      Some(value) => value
      None => raise InvalidXml(msg="conditionalFormatting tag missing")
    }
    let sqref = match attr_value(tag, "sqref") {
      Some(value) => unescape_xml_text(value)
      None => raise InvalidXml(msg="conditionalFormatting sqref missing")
    }
    let next_sqref = delete_cells_from_sqref(sqref, del_cells)
    if next_sqref == "" {
      continue
    }
    match replace_attr_value_in_open_tag(xml, "sqref", next_sqref) {
      Some(value) => updated.push(value)
      None => raise InvalidXml(msg="conditionalFormatting sqref update failed")
    }
  }
  self.conditional_formats.clear()
  self.conditional_formats.append(updated[:])
  if self.x14_data_bars.length() > 0 {
    let prior : Map[String, X14DataBarProps] = {}
    for id, props in self.x14_data_bars {
      prior[id] = props
    }
    let referenced : Map[String, X14DataBarProps] = {}
    for xml in self.conditional_formats {
      let tag = match tag_attributes_in(xml, "conditionalFormatting") {
        Some(value) => value
        None => continue
      }
      let sqref = match attr_value(tag, "sqref") {
        Some(value) => unescape_xml_text(value)
        None => continue
      }
      let mut first = true
      for chunk in xml.split("<x14:id>") {
        if first {
          first = false
          continue
        }
        let text = chunk.to_string()
        let end = match text.find("</x14:id>") {
          Some(pos) => pos
          None => continue
        }
        let id = unescape_xml_text(text[:end] catch { _ => "" })
        match prior.get(id) {
          Some(props) =>
            referenced[id] = {
              sqref,
              bar_direction: props.bar_direction,
              bar_solid: props.bar_solid,
              bar_border_color: props.bar_border_color,
            }
          None => ()
        }
      }
    }
    self.x14_data_bars.clear()
    for id, props in referenced {
      self.x14_data_bars[id] = props
    }
  }
}

///|
pub fn Worksheet::set_cell_rc(
  self : Worksheet,
  row : Int,
  col : Int,
  value : String,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let reference = cell_ref_from(row, col)
  match self.cell_index_of(row, col) {
    Some(i) => {
      let style_id = self.cells[i].style_id
      self.cells[i] = {
        reference,
        row,
        col,
        value,
        value_type: String,
        rich_text: None,
        formula: None,
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id,
      }
    }
    None => {
      let index = self.cells.length()
      self.cells.push({
        reference,
        row,
        col,
        value,
        value_type: String,
        rich_text: None,
        formula: None,
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id: 0,
      })
      self.record_cell_index_if_valid(row, col, index)
    }
  }
}

///|
pub fn Worksheet::set_cell_value_rc(
  self : Worksheet,
  row : Int,
  col : Int,
  value : CellValue,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let reference = cell_ref_from(row, col)
  let value_type = cell_value_type(value)
  let raw_value = cell_value_raw_string(value)
  match self.cell_index_of(row, col) {
    Some(i) => {
      let style_id = self.cells[i].style_id
      self.cells[i] = {
        reference,
        row,
        col,
        value: raw_value,
        value_type,
        rich_text: None,
        formula: None,
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id,
      }
    }
    None => {
      let index = self.cells.length()
      self.cells.push({
        reference,
        row,
        col,
        value: raw_value,
        value_type,
        rich_text: None,
        formula: None,
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id: 0,
      })
      self.record_cell_index_if_valid(row, col, index)
    }
  }
}

///|
pub fn Worksheet::set_cell_formula_rc(
  self : Worksheet,
  row : Int,
  col : Int,
  formula : String,
  value? : String = "",
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let reference = cell_ref_from(row, col)
  match self.cell_index_of(row, col) {
    Some(i) => {
      let style_id = self.cells[i].style_id
      self.cells[i] = {
        reference,
        row,
        col,
        value,
        value_type: String,
        rich_text: None,
        formula: Some(formula),
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id,
      }
    }
    None => {
      let index = self.cells.length()
      self.cells.push({
        reference,
        row,
        col,
        value,
        value_type: String,
        rich_text: None,
        formula: Some(formula),
        formula_type: None,
        formula_ref: None,
        formula_shared_index: None,
        style_id: 0,
      })
      self.record_cell_index_if_valid(row, col, index)
    }
  }
}

///|
pub fn Worksheet::get_cell_rc(
  self : Worksheet,
  row : Int,
  col : Int,
) -> String? raise XlsxError {
  if row <= 0 || col <= 0 {
    raise InvalidCellRef(value="\{col}:\{row}")
  }
  match self.cell_index_of(row, col) {
    Some(i) => Some(self.cells[i].value)
    None => None
  }
}

///|
pub fn Worksheet::get_cell_value_raw_rc(
  self : Worksheet,
  row : Int,
  col : Int,
) -> CellValue? raise XlsxError {
  if row <= 0 || col <= 0 {
    raise InvalidCellRef(value="\{col}:\{row}")
  }
  match self.cell_index_of(row, col) {
    Some(i) =>
      Some(cell_value_from_raw(self.cells[i].value_type, self.cells[i].value))
    None => None
  }
}

///|
pub fn Worksheet::max_row(self : Worksheet) -> Int {
  let mut max_row = 0
  for cell in self.cells {
    if cell.row > max_row {
      max_row = cell.row
    }
  }
  max_row
}

///|
pub fn Worksheet::max_col(self : Worksheet) -> Int {
  let mut max_col = 0
  for cell in self.cells {
    if cell.col > max_col {
      max_col = cell.col
    }
  }
  max_col
}

///|
pub fn Worksheet::set_row(
  self : Worksheet,
  row : Int,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  if row <= 0 {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  for i, value in values {
    self.set_cell_rc(row, i + 1, value)
  }
}

///|
pub fn Worksheet::get_row(
  self : Worksheet,
  row : Int,
) -> Array[String] raise XlsxError {
  if row <= 0 {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  let mut max_col = 0
  for cell in self.cells {
    if cell.row == row && cell.col > max_col {
      max_col = cell.col
    }
  }
  if max_col == 0 {
    return []
  }
  let values : Array[String] = Array::make(max_col, "")
  for cell in self.cells {
    if cell.row == row {
      values[cell.col - 1] = cell.value
    }
  }
  values
}

///|
pub fn Worksheet::set_col(
  self : Worksheet,
  col : Int,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  for i, value in values {
    self.set_cell_rc(i + 1, col, value)
  }
}

///|
pub fn Worksheet::get_col(
  self : Worksheet,
  col : Int,
) -> Array[String] raise XlsxError {
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  let mut max_row = 0
  for cell in self.cells {
    if cell.col == col && cell.row > max_row {
      max_row = cell.row
    }
  }
  if max_row == 0 {
    return []
  }
  let values : Array[String] = Array::make(max_row, "")
  for cell in self.cells {
    if cell.col == col {
      values[cell.row - 1] = cell.value
    }
  }
  values
}

///|
fn default_row_dimension() -> RowDimension {
  { height: None, hidden: false, outline_level: 0, style_id: None }
}

///|
fn default_col_dimension() -> ColDimension {
  { width: None, hidden: false, outline_level: 0, style_id: None }
}

///|
fn row_dimension_is_default(dim : RowDimension) -> Bool {
  dim.height is None &&
  dim.hidden == false &&
  dim.outline_level == 0 &&
  dim.style_id is None
}

///|
fn col_dimension_is_default(dim : ColDimension) -> Bool {
  dim.width is None &&
  dim.hidden == false &&
  dim.outline_level == 0 &&
  dim.style_id is None
}

///|
fn Worksheet::row_dimension_value(self : Worksheet, row : Int) -> RowDimension {
  match self.row_dimensions.get(row) {
    Some(value) => value
    None => default_row_dimension()
  }
}

///|
fn Worksheet::col_dimension_value(self : Worksheet, col : Int) -> ColDimension {
  match self.col_dimensions.get(col) {
    Some(value) => value
    None => default_col_dimension()
  }
}

///|
fn Worksheet::set_row_dimension(
  self : Worksheet,
  row : Int,
  dim : RowDimension,
) -> Unit {
  if row_dimension_is_default(dim) {
    self.row_dimensions.remove(row)
  } else {
    self.row_dimensions[row] = dim
  }
}

///|
fn Worksheet::set_col_dimension(
  self : Worksheet,
  col : Int,
  dim : ColDimension,
) -> Unit {
  if col_dimension_is_default(dim) {
    self.col_dimensions.remove(col)
  } else {
    self.col_dimensions[col] = dim
  }
}

///|
pub fn Worksheet::set_row_height(
  self : Worksheet,
  row : Int,
  height : Double,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if row <= 0 {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  if height < 0.0 {
    raise InvalidSheetOperation(msg="row height is negative")
  }
  let dim = self.row_dimension_value(row)
  let updated : RowDimension = {
    height: Some(height),
    hidden: dim.hidden,
    outline_level: dim.outline_level,
    style_id: dim.style_id,
  }
  self.set_row_dimension(row, updated)
}

///|
pub fn Worksheet::get_row_height(
  self : Worksheet,
  row : Int,
) -> Double? raise XlsxError {
  if row <= 0 {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  match self.row_dimensions.get(row) {
    Some(dim) => dim.height
    None => None
  }
}

///|
pub fn Worksheet::set_row_visible(
  self : Worksheet,
  row : Int,
  visible : Bool,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if row <= 0 {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  let dim = self.row_dimension_value(row)
  let updated : RowDimension = {
    height: dim.height,
    hidden: !visible,
    outline_level: dim.outline_level,
    style_id: dim.style_id,
  }
  self.set_row_dimension(row, updated)
}

///|
pub fn Worksheet::row_visible(
  self : Worksheet,
  row : Int,
) -> Bool raise XlsxError {
  if row <= 0 {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  match self.row_dimensions.get(row) {
    Some(dim) => !dim.hidden
    None => true
  }
}

///|
pub fn Worksheet::set_row_outline_level(
  self : Worksheet,
  row : Int,
  level : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if row <= 0 {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  if level < 0 || level > 7 {
    raise InvalidSheetOperation(msg="row outline level out of range")
  }
  let dim = self.row_dimension_value(row)
  let updated : RowDimension = {
    height: dim.height,
    hidden: dim.hidden,
    outline_level: level,
    style_id: dim.style_id,
  }
  self.set_row_dimension(row, updated)
}

///|
pub fn Worksheet::row_outline_level(
  self : Worksheet,
  row : Int,
) -> Int raise XlsxError {
  if row <= 0 {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  match self.row_dimensions.get(row) {
    Some(dim) => dim.outline_level
    None => 0
  }
}

///|
pub fn Worksheet::set_row_style_range(
  self : Worksheet,
  start : Int,
  end : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if start <= 0 || end <= 0 {
    raise InvalidCellRef(value="\{0}:\{start}")
  }
  if end < start {
    raise InvalidSheetOperation(msg="row style range invalid")
  }
  let style = if style_id > 0 { Some(style_id) } else { None }
  for row in start..<=end {
    let dim = self.row_dimension_value(row)
    let updated : RowDimension = {
      height: dim.height,
      hidden: dim.hidden,
      outline_level: dim.outline_level,
      style_id: style,
    }
    self.set_row_dimension(row, updated)
  }
}

///|
pub fn Worksheet::set_row_style(
  self : Worksheet,
  row : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  self.set_row_style_range(row, row, style_id)
}

///|
pub fn Worksheet::get_row_style(
  self : Worksheet,
  row : Int,
) -> Int? raise XlsxError {
  if row <= 0 {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  match self.row_dimensions.get(row) {
    Some(dim) => dim.style_id
    None => None
  }
}

///|
pub fn Worksheet::set_col_width(
  self : Worksheet,
  col : Int,
  width : Double,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  if width < 0.0 {
    raise InvalidSheetOperation(msg="column width is negative")
  }
  let dim = self.col_dimension_value(col)
  let updated : ColDimension = {
    width: Some(width),
    hidden: dim.hidden,
    outline_level: dim.outline_level,
    style_id: dim.style_id,
  }
  self.set_col_dimension(col, updated)
}

///|
pub fn Worksheet::get_col_width(
  self : Worksheet,
  col : Int,
) -> Double? raise XlsxError {
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  match self.col_dimensions.get(col) {
    Some(dim) => dim.width
    None => None
  }
}

///|
pub fn Worksheet::set_col_visible(
  self : Worksheet,
  col : Int,
  visible : Bool,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  let dim = self.col_dimension_value(col)
  let updated : ColDimension = {
    width: dim.width,
    hidden: !visible,
    outline_level: dim.outline_level,
    style_id: dim.style_id,
  }
  self.set_col_dimension(col, updated)
}

///|
pub fn Worksheet::col_visible(
  self : Worksheet,
  col : Int,
) -> Bool raise XlsxError {
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  match self.col_dimensions.get(col) {
    Some(dim) => !dim.hidden
    None => true
  }
}

///|
pub fn Worksheet::set_col_outline_level(
  self : Worksheet,
  col : Int,
  level : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  if level < 0 || level > 7 {
    raise InvalidSheetOperation(msg="column outline level out of range")
  }
  let dim = self.col_dimension_value(col)
  let updated : ColDimension = {
    width: dim.width,
    hidden: dim.hidden,
    outline_level: level,
    style_id: dim.style_id,
  }
  self.set_col_dimension(col, updated)
}

///|
pub fn Worksheet::col_outline_level(
  self : Worksheet,
  col : Int,
) -> Int raise XlsxError {
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  match self.col_dimensions.get(col) {
    Some(dim) => dim.outline_level
    None => 0
  }
}

///|
pub fn Worksheet::set_col_style(
  self : Worksheet,
  col : Int,
  style_id : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  let dim = self.col_dimension_value(col)
  let style = if style_id > 0 { Some(style_id) } else { None }
  let updated : ColDimension = {
    width: dim.width,
    hidden: dim.hidden,
    outline_level: dim.outline_level,
    style_id: style,
  }
  self.set_col_dimension(col, updated)
}

///|
pub fn Worksheet::get_col_style(
  self : Worksheet,
  col : Int,
) -> Int? raise XlsxError {
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  match self.col_dimensions.get(col) {
    Some(dim) => dim.style_id
    None => None
  }
}

///|
pub fn Worksheet::insert_rows(
  self : Worksheet,
  row : Int,
  count : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  self.invalidate_cell_index()
  if row <= 0 {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  if count <= 0 {
    raise InvalidSheetOperation(msg="row count must be positive")
  }
  for i, cell in self.cells {
    if cell.row >= row {
      let new_row = cell.row + count
      let reference = cell_ref_from(new_row, cell.col)
      self.cells[i] = {
        reference,
        row: new_row,
        col: cell.col,
        value: cell.value,
        value_type: cell.value_type,
        rich_text: cell.rich_text,
        formula: cell.formula,
        formula_type: cell.formula_type,
        formula_ref: cell.formula_ref,
        formula_shared_index: cell.formula_shared_index,
        style_id: cell.style_id,
      }
    }
  }
  let updated_merges : Array[String] = []
  for range_ref in self.merged_cells {
    updated_merges.push(adjust_range_after_row_insert(range_ref, row, count))
  }
  self.merged_cells.clear()
  self.merged_cells.append(updated_merges[:])
  let updated_links : Array[Hyperlink] = []
  for link in self.hyperlinks {
    let reference = adjust_hyperlink_ref_after_row_insert(
      link.reference,
      row,
      count,
    )
    updated_links.push({
      reference,
      target: link.target,
      link_type: link.link_type,
      display: link.display,
      tooltip: link.tooltip,
    })
  }
  self.hyperlinks.clear()
  self.hyperlinks.append(updated_links[:])
  match self.auto_filter {
    Some(filter) =>
      self.auto_filter = Some(
        adjust_auto_filter_after_row_insert(filter, row, count),
      )
    None => ()
  }
  let updated_tables : Array[Table] = []
  for table in self.tables {
    updated_tables.push(adjust_table_after_row_insert(table, row, count))
  }
  self.tables.clear()
  self.tables.append(updated_tables[:])
  let updated_sparklines : Array[SparklineGroup] = []
  for group in self.sparkline_groups {
    let adjusted = adjust_sparkline_group_after_row_insert(group, row, count)
    if adjusted.sparklines.length() > 0 {
      updated_sparklines.push(adjusted)
    }
  }
  self.sparkline_groups.clear()
  self.sparkline_groups.append(updated_sparklines[:])
  let updated_images : Array[Image] = []
  for image in self.images {
    let reference = adjust_cell_after_row_insert(image.reference, row, count)
    updated_images.push(image_with_reference(image, reference))
  }
  self.images.clear()
  self.images.append(updated_images[:])
  let updated_charts : Array[Chart] = []
  for chart in self.charts {
    let reference = adjust_cell_after_row_insert(chart.reference, row, count)
    updated_charts.push(chart_with_reference(chart, reference))
  }
  self.charts.clear()
  self.charts.append(updated_charts[:])
  let updated_rows : Map[Int, RowDimension] = {}
  for row_index, dim in self.row_dimensions {
    let new_row = if row_index >= row { row_index + count } else { row_index }
    updated_rows[new_row] = dim
  }
  self.row_dimensions.clear()
  for row_index, dim in updated_rows {
    self.row_dimensions[row_index] = dim
  }
  let break_start = row - 1
  let updated_breaks = adjust_page_breaks_after_insert(
    self.row_breaks,
    break_start,
    count,
  )
  self.row_breaks.clear()
  self.row_breaks.append(updated_breaks[:])
}

///|
pub fn Worksheet::remove_rows(
  self : Worksheet,
  row : Int,
  count : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  self.invalidate_cell_index()
  if row <= 0 {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  if count <= 0 {
    raise InvalidSheetOperation(msg="row count must be positive")
  }
  let end_row = row + count - 1
  let updated_cells : Array[Cell] = []
  for cell in self.cells {
    if cell.row < row {
      updated_cells.push(cell)
      continue
    }
    if cell.row <= end_row {
      continue
    }
    let new_row = cell.row - count
    let reference = cell_ref_from(new_row, cell.col)
    updated_cells.push({
      reference,
      row: new_row,
      col: cell.col,
      value: cell.value,
      value_type: cell.value_type,
      rich_text: cell.rich_text,
      formula: cell.formula,
      formula_type: cell.formula_type,
      formula_ref: cell.formula_ref,
      formula_shared_index: cell.formula_shared_index,
      style_id: cell.style_id,
    })
  }
  self.cells.clear()
  self.cells.append(updated_cells[:])
  let updated_merges : Array[String] = []
  for range_ref in self.merged_cells {
    match adjust_range_after_row_remove(range_ref, row, count) {
      Some(value) => updated_merges.push(value)
      None => ()
    }
  }
  self.merged_cells.clear()
  self.merged_cells.append(updated_merges[:])
  let updated_links : Array[Hyperlink] = []
  for link in self.hyperlinks {
    match adjust_hyperlink_ref_after_row_remove(link.reference, row, count) {
      Some(reference) =>
        updated_links.push({
          reference,
          target: link.target,
          link_type: link.link_type,
          display: link.display,
          tooltip: link.tooltip,
        })
      None => ()
    }
  }
  self.hyperlinks.clear()
  self.hyperlinks.append(updated_links[:])
  match self.auto_filter {
    Some(filter) =>
      match adjust_auto_filter_after_row_remove(filter, row, count) {
        Some(updated) => self.auto_filter = Some(updated)
        None => self.auto_filter = None
      }
    None => ()
  }
  let updated_tables : Array[Table] = []
  for table in self.tables {
    match adjust_table_after_row_remove(table, row, count) {
      Some(value) => updated_tables.push(value)
      None => ()
    }
  }
  self.tables.clear()
  self.tables.append(updated_tables[:])
  let updated_sparklines : Array[SparklineGroup] = []
  for group in self.sparkline_groups {
    let adjusted = adjust_sparkline_group_after_row_remove(group, row, count)
    if adjusted.sparklines.length() > 0 {
      updated_sparklines.push(adjusted)
    }
  }
  self.sparkline_groups.clear()
  self.sparkline_groups.append(updated_sparklines[:])
  let updated_images : Array[Image] = []
  for image in self.images {
    match adjust_cell_after_row_remove(image.reference, row, count) {
      Some(reference) =>
        updated_images.push(image_with_reference(image, reference))
      None => ()
    }
  }
  self.images.clear()
  self.images.append(updated_images[:])
  let updated_charts : Array[Chart] = []
  for chart in self.charts {
    match adjust_cell_after_row_remove(chart.reference, row, count) {
      Some(reference) =>
        updated_charts.push(chart_with_reference(chart, reference))
      None => ()
    }
  }
  self.charts.clear()
  self.charts.append(updated_charts[:])
  let updated_rows : Map[Int, RowDimension] = {}
  for row_index, dim in self.row_dimensions {
    if row_index < row {
      updated_rows[row_index] = dim
    } else if row_index > end_row {
      updated_rows[row_index - count] = dim
    }
  }
  self.row_dimensions.clear()
  for row_index, dim in updated_rows {
    self.row_dimensions[row_index] = dim
  }
  let break_start = row - 1
  let updated_breaks = adjust_page_breaks_after_remove(
    self.row_breaks,
    break_start,
    count,
  )
  self.row_breaks.clear()
  self.row_breaks.append(updated_breaks[:])
}

///|
/// Remove a single row (1-based) and shift rows upward.
pub fn Worksheet::remove_row(
  self : Worksheet,
  row : Int,
) -> Unit raise XlsxError {
  self.remove_rows(row, 1)
}

///|
fn parse_cell_ref_with_abs(
  reference : StringView,
) -> (Int, Int, Bool, Bool) raise XlsxError {
  let len = reference.length()
  let mut idx = 0
  let mut abs_col = false
  if idx < len && reference[idx] == '$' {
    abs_col = true
    idx = idx + 1
  }
  let mut col = 0
  let mut has_col = false
  while idx < len {
    let u0 = reference[idx]
    if u0 is ('A'..='Z') || u0 is ('a'..='z') {
      let upper = if u0 is ('a'..='z') { u0 - 32 } else { u0 }
      col = col * 26 + (upper.to_int() - ('A' : UInt16).to_int() + 1)
      has_col = true
      idx = idx + 1
    } else {
      break
    }
  }
  if !has_col {
    raise InvalidCellRef(value=reference.to_string())
  }
  let mut abs_row = false
  if idx < len && reference[idx] == '$' {
    abs_row = true
    idx = idx + 1
  }
  let mut row = 0
  let mut has_row = false
  while idx < len {
    let u0 = reference[idx]
    if u0 is ('0'..='9') {
      has_row = true
      row = row * 10 + (u0.to_int() - ('0' : UInt16).to_int())
      idx = idx + 1
    } else {
      raise InvalidCellRef(value=reference.to_string())
    }
  }
  if !has_row {
    raise InvalidCellRef(value=reference.to_string())
  }
  if row <= 0 {
    raise InvalidCellRef(value=reference.to_string())
  }
  (row, col, abs_col, abs_row)
}

///|
fn format_cell_ref_with_abs(
  row : Int,
  col : Int,
  abs_col : Bool,
  abs_row : Bool,
) -> String raise XlsxError {
  let col_text = column_number_to_name(col)
  if row <= 0 {
    raise InvalidCellRef(value="\{col}:\{row}")
  }
  let row_text = row.to_string()
  let sb = StringBuilder::new()
  if abs_col {
    sb.write_char('$')
  }
  sb.write_view(col_text)
  if abs_row {
    sb.write_char('$')
  }
  sb.write_view(row_text)
  sb.to_string()
}

///|
fn duplicate_sqref_for_row(
  row : Int,
  target_row : Int,
  sqref : StringView,
) -> Array[String] raise XlsxError {
  let refs : Array[String] = []
  for part in sqref.split(" ") {
    let text = part.trim()
    if text == "" {
      continue
    }
    let (start_ref, end_ref) = if text.contains(":") {
      let sep = match text.find(":") {
        Some(pos) => pos
        None => raise InvalidCellRef(value=text.to_string())
      }
      let start_ref = text[:sep] catch {
          _ => raise InvalidCellRef(value=text.to_string())
        }
      let end_ref = text[sep + 1:] catch {
          _ => raise InvalidCellRef(value=text.to_string())
        }
      (start_ref, end_ref)
    } else {
      (text, text)
    }
    let (row1, col1, abs_col1, abs_row1) = parse_cell_ref_with_abs(start_ref)
    let (row2, col2, abs_col2, abs_row2) = parse_cell_ref_with_abs(end_ref)
    if row1 == row2 && row1 == row {
      let from_ref = format_cell_ref_with_abs(
        target_row, col1, abs_col1, abs_row1,
      )
      let to_ref = format_cell_ref_with_abs(
        target_row, col2, abs_col2, abs_row2,
      )
      refs.push("\{from_ref}:\{to_ref}")
    }
  }
  refs
}

///|

///|
fn duplicate_xml_sqref(
  xml : StringView,
  row : Int,
  target_row : Int,
) -> String? raise XlsxError {
  let tag_text = match tag_attributes_in(xml, "conditionalFormatting") {
    Some(value) => value
    None =>
      match tag_attributes_in(xml, "dataValidation") {
        Some(value) => value
        None => return None
      }
  }
  let sqref = match attr_value(tag_text, "sqref") {
    Some(value) => value
    None => return None
  }
  let refs = duplicate_sqref_for_row(row, target_row, sqref)
  if refs.length() == 0 {
    return None
  }
  let joined = refs.join(" ")
  replace_attr_value_in_open_tag(xml, "sqref", joined)
}

///|
fn Worksheet::duplicate_conditional_formats(
  self : Worksheet,
  row : Int,
  target_row : Int,
) -> Unit raise XlsxError {
  let copies : Array[String] = []
  for xml in self.conditional_formats {
    match duplicate_xml_sqref(xml, row, target_row) {
      Some(value) => copies.push(value)
      None => ()
    }
  }
  if copies.length() > 0 {
    self.conditional_formats.append(copies[:])
  }
}

///|
fn Worksheet::duplicate_data_validations(
  self : Worksheet,
  row : Int,
  target_row : Int,
) -> Unit raise XlsxError {
  let copies : Array[String] = []
  for xml in self.data_validations {
    match duplicate_xml_sqref(xml, row, target_row) {
      Some(value) => copies.push(value)
      None => ()
    }
  }
  if copies.length() > 0 {
    self.data_validations.append(copies[:])
  }
}

///|
fn Worksheet::duplicate_merge_cells(
  self : Worksheet,
  row : Int,
  target_row : Int,
) -> Unit raise XlsxError {
  let mut source_row = row
  if row > target_row {
    source_row = row + 1
  }
  for range_ref in self.merged_cells {
    let (min_row, _min_col, max_row, _max_col) = parse_range_ref(range_ref)
    if min_row < target_row && target_row < max_row {
      return
    }
  }
  for range_ref in self.merged_cells {
    let (min_row, min_col, max_row, max_col) = parse_range_ref(range_ref)
    if min_row == max_row && min_row == source_row {
      let from_ref = cell_ref_from(target_row, min_col)
      let to_ref = cell_ref_from(target_row, max_col)
      self.merge_cells("\{from_ref}:\{to_ref}")
    }
  }
}

///|
pub fn Worksheet::duplicate_row(
  self : Worksheet,
  row : Int,
) -> Unit raise XlsxError {
  self.duplicate_row_to(row, row + 1)
}

///|
pub fn Worksheet::duplicate_row_to(
  self : Worksheet,
  row : Int,
  target_row : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  self.invalidate_cell_index()
  if row <= 0 {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  if target_row <= 0 || row == target_row {
    raise InvalidSheetOperation(msg="duplicate row target must be different")
  }
  let row_cells : Array[Cell] = []
  for cell in self.cells {
    if cell.row == row {
      row_cells.push(cell)
    }
  }
  let row_dim = self.row_dimensions.get(row)
  self.insert_rows(target_row, 1)
  for cell in row_cells {
    let reference = cell_ref_from(target_row, cell.col)
    self.cells.push({
      reference,
      row: target_row,
      col: cell.col,
      value: cell.value,
      value_type: cell.value_type,
      rich_text: cell.rich_text,
      formula: cell.formula,
      formula_type: cell.formula_type,
      formula_ref: cell.formula_ref,
      formula_shared_index: cell.formula_shared_index,
      style_id: cell.style_id,
    })
  }
  match row_dim {
    Some(dim) => self.set_row_dimension(target_row, dim)
    None => self.row_dimensions.remove(target_row)
  }
  self.duplicate_conditional_formats(row, target_row)
  self.duplicate_data_validations(row, target_row)
  self.duplicate_merge_cells(row, target_row)
}

///|
pub fn Worksheet::insert_cols(
  self : Worksheet,
  col : Int,
  count : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  self.invalidate_cell_index()
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  if count <= 0 {
    raise InvalidSheetOperation(msg="column count must be positive")
  }
  for i, cell in self.cells {
    if cell.col >= col {
      let new_col = cell.col + count
      let reference = cell_ref_from(cell.row, new_col)
      self.cells[i] = {
        reference,
        row: cell.row,
        col: new_col,
        value: cell.value,
        value_type: cell.value_type,
        rich_text: cell.rich_text,
        formula: cell.formula,
        formula_type: cell.formula_type,
        formula_ref: cell.formula_ref,
        formula_shared_index: cell.formula_shared_index,
        style_id: cell.style_id,
      }
    }
  }
  let updated_merges : Array[String] = []
  for range_ref in self.merged_cells {
    updated_merges.push(adjust_range_after_col_insert(range_ref, col, count))
  }
  self.merged_cells.clear()
  self.merged_cells.append(updated_merges[:])
  let updated_links : Array[Hyperlink] = []
  for link in self.hyperlinks {
    let reference = adjust_hyperlink_ref_after_col_insert(
      link.reference,
      col,
      count,
    )
    updated_links.push({
      reference,
      target: link.target,
      link_type: link.link_type,
      display: link.display,
      tooltip: link.tooltip,
    })
  }
  self.hyperlinks.clear()
  self.hyperlinks.append(updated_links[:])
  match self.auto_filter {
    Some(filter) =>
      self.auto_filter = Some(
        adjust_auto_filter_after_col_insert(filter, col, count),
      )
    None => ()
  }
  let updated_tables : Array[Table] = []
  for table in self.tables {
    updated_tables.push(adjust_table_after_col_insert(table, col, count))
  }
  self.tables.clear()
  self.tables.append(updated_tables[:])
  let updated_sparklines : Array[SparklineGroup] = []
  for group in self.sparkline_groups {
    let adjusted = adjust_sparkline_group_after_col_insert(group, col, count)
    if adjusted.sparklines.length() > 0 {
      updated_sparklines.push(adjusted)
    }
  }
  self.sparkline_groups.clear()
  self.sparkline_groups.append(updated_sparklines[:])
  let updated_images : Array[Image] = []
  for image in self.images {
    let reference = adjust_cell_after_col_insert(image.reference, col, count)
    updated_images.push(image_with_reference(image, reference))
  }
  self.images.clear()
  self.images.append(updated_images[:])
  let updated_charts : Array[Chart] = []
  for chart in self.charts {
    let reference = adjust_cell_after_col_insert(chart.reference, col, count)
    updated_charts.push(chart_with_reference(chart, reference))
  }
  self.charts.clear()
  self.charts.append(updated_charts[:])
  let updated_cols : Map[Int, ColDimension] = {}
  for col_index, dim in self.col_dimensions {
    let new_col = if col_index >= col { col_index + count } else { col_index }
    updated_cols[new_col] = dim
  }
  self.col_dimensions.clear()
  for col_index, dim in updated_cols {
    self.col_dimensions[col_index] = dim
  }
  let break_start = col - 1
  let updated_breaks = adjust_page_breaks_after_insert(
    self.col_breaks,
    break_start,
    count,
  )
  self.col_breaks.clear()
  self.col_breaks.append(updated_breaks[:])
}

///|
pub fn Worksheet::remove_cols(
  self : Worksheet,
  col : Int,
  count : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  self.invalidate_cell_index()
  if col <= 0 {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  if count <= 0 {
    raise InvalidSheetOperation(msg="column count must be positive")
  }
  let end_col = col + count - 1
  let updated_cells : Array[Cell] = []
  for cell in self.cells {
    if cell.col < col {
      updated_cells.push(cell)
      continue
    }
    if cell.col <= end_col {
      continue
    }
    let new_col = cell.col - count
    let reference = cell_ref_from(cell.row, new_col)
    updated_cells.push({
      reference,
      row: cell.row,
      col: new_col,
      value: cell.value,
      value_type: cell.value_type,
      rich_text: cell.rich_text,
      formula: cell.formula,
      formula_type: cell.formula_type,
      formula_ref: cell.formula_ref,
      formula_shared_index: cell.formula_shared_index,
      style_id: cell.style_id,
    })
  }
  self.cells.clear()
  self.cells.append(updated_cells[:])
  let updated_merges : Array[String] = []
  for range_ref in self.merged_cells {
    match adjust_range_after_col_remove(range_ref, col, count) {
      Some(value) => updated_merges.push(value)
      None => ()
    }
  }
  self.merged_cells.clear()
  self.merged_cells.append(updated_merges[:])
  let updated_links : Array[Hyperlink] = []
  for link in self.hyperlinks {
    match adjust_hyperlink_ref_after_col_remove(link.reference, col, count) {
      Some(reference) =>
        updated_links.push({
          reference,
          target: link.target,
          link_type: link.link_type,
          display: link.display,
          tooltip: link.tooltip,
        })
      None => ()
    }
  }
  self.hyperlinks.clear()
  self.hyperlinks.append(updated_links[:])
  match self.auto_filter {
    Some(filter) =>
      match adjust_auto_filter_after_col_remove(filter, col, count) {
        Some(updated) => self.auto_filter = Some(updated)
        None => self.auto_filter = None
      }
    None => ()
  }
  let updated_tables : Array[Table] = []
  for table in self.tables {
    match adjust_table_after_col_remove(table, col, count) {
      Some(value) => updated_tables.push(value)
      None => ()
    }
  }
  self.tables.clear()
  self.tables.append(updated_tables[:])
  let updated_sparklines : Array[SparklineGroup] = []
  for group in self.sparkline_groups {
    let adjusted = adjust_sparkline_group_after_col_remove(group, col, count)
    if adjusted.sparklines.length() > 0 {
      updated_sparklines.push(adjusted)
    }
  }
  self.sparkline_groups.clear()
  self.sparkline_groups.append(updated_sparklines[:])
  let updated_images : Array[Image] = []
  for image in self.images {
    match adjust_cell_after_col_remove(image.reference, col, count) {
      Some(reference) =>
        updated_images.push(image_with_reference(image, reference))
      None => ()
    }
  }
  self.images.clear()
  self.images.append(updated_images[:])
  let updated_charts : Array[Chart] = []
  for chart in self.charts {
    match adjust_cell_after_col_remove(chart.reference, col, count) {
      Some(reference) =>
        updated_charts.push(chart_with_reference(chart, reference))
      None => ()
    }
  }
  self.charts.clear()
  self.charts.append(updated_charts[:])
  let updated_cols : Map[Int, ColDimension] = {}
  for col_index, dim in self.col_dimensions {
    if col_index < col {
      updated_cols[col_index] = dim
    } else if col_index > end_col {
      updated_cols[col_index - count] = dim
    }
  }
  self.col_dimensions.clear()
  for col_index, dim in updated_cols {
    self.col_dimensions[col_index] = dim
  }
  let break_start = col - 1
  let updated_breaks = adjust_page_breaks_after_remove(
    self.col_breaks,
    break_start,
    count,
  )
  self.col_breaks.clear()
  self.col_breaks.append(updated_breaks[:])
}

///|
/// Remove a single column (1-based) and shift columns left.
pub fn Worksheet::remove_col(
  self : Worksheet,
  col : Int,
) -> Unit raise XlsxError {
  self.remove_cols(col, 1)
}

///|
fn adjust_bounds_for_insert(
  min : Int,
  max : Int,
  start : Int,
  count : Int,
) -> (Int, Int) {
  if start <= min {
    (min + count, max + count)
  } else if start <= max {
    (min, max + count)
  } else {
    (min, max)
  }
}

///|
fn adjust_bounds_for_remove(
  min : Int,
  max : Int,
  start : Int,
  count : Int,
) -> (Int, Int)? {
  let end = start + count - 1
  if end < min {
    return Some((min - count, max - count))
  }
  if start > max {
    return Some((min, max))
  }
  let removed_before = if start < min { min - start } else { 0 }
  let overlap_start = if start > min { start } else { min }
  let overlap_end = if end < max { end } else { max }
  let removed_inside = overlap_end - overlap_start + 1
  let new_min = min - removed_before
  let new_max = max - removed_before - removed_inside
  if new_max < new_min {
    None
  } else {
    Some((new_min, new_max))
  }
}

///|
fn adjust_page_breaks_after_insert(
  breaks : Array[PageBreak],
  start : Int,
  count : Int,
) -> Array[PageBreak] {
  let updated : Array[PageBreak] = []
  for brk in breaks {
    let new_id = if brk.id >= start { brk.id + count } else { brk.id }
    updated.push({ id: new_id, min: brk.min, max: brk.max, manual: brk.manual })
  }
  updated
}

///|
fn adjust_page_breaks_after_remove(
  breaks : Array[PageBreak],
  start : Int,
  count : Int,
) -> Array[PageBreak] {
  let updated : Array[PageBreak] = []
  let end = start + count - 1
  for brk in breaks {
    if brk.id < start {
      updated.push(brk)
      continue
    }
    if brk.id > end {
      updated.push({
        id: brk.id - count,
        min: brk.min,
        max: brk.max,
        manual: brk.manual,
      })
    }
  }
  updated
}

///|
fn adjust_range_after_row_insert(
  range_ref : String,
  row : Int,
  count : Int,
) -> String raise XlsxError {
  let (min_row, min_col, max_row, max_col) = parse_range_ref(range_ref)
  let (new_min_row, new_max_row) = adjust_bounds_for_insert(
    min_row, max_row, row, count,
  )
  let start_ref = cell_ref_from(new_min_row, min_col)
  let end_ref = cell_ref_from(new_max_row, max_col)
  "\{start_ref}:\{end_ref}"
}

///|
fn adjust_range_after_row_remove(
  range_ref : String,
  row : Int,
  count : Int,
) -> String? raise XlsxError {
  let (min_row, min_col, max_row, max_col) = parse_range_ref(range_ref)
  match adjust_bounds_for_remove(min_row, max_row, row, count) {
    Some((new_min_row, new_max_row)) => {
      let start_ref = cell_ref_from(new_min_row, min_col)
      let end_ref = cell_ref_from(new_max_row, max_col)
      Some("\{start_ref}:\{end_ref}")
    }
    None => None
  }
}

///|
fn adjust_range_after_col_insert(
  range_ref : String,
  col : Int,
  count : Int,
) -> String raise XlsxError {
  let (min_row, min_col, max_row, max_col) = parse_range_ref(range_ref)
  let (new_min_col, new_max_col) = adjust_bounds_for_insert(
    min_col, max_col, col, count,
  )
  let start_ref = cell_ref_from(min_row, new_min_col)
  let end_ref = cell_ref_from(max_row, new_max_col)
  "\{start_ref}:\{end_ref}"
}

///|
fn adjust_range_after_col_remove(
  range_ref : String,
  col : Int,
  count : Int,
) -> String? raise XlsxError {
  let (min_row, min_col, max_row, max_col) = parse_range_ref(range_ref)
  match adjust_bounds_for_remove(min_col, max_col, col, count) {
    Some((new_min_col, new_max_col)) => {
      let start_ref = cell_ref_from(min_row, new_min_col)
      let end_ref = cell_ref_from(max_row, new_max_col)
      Some("\{start_ref}:\{end_ref}")
    }
    None => None
  }
}

///|
fn adjust_auto_filter_after_row_insert(
  filter : AutoFilter,
  row : Int,
  count : Int,
) -> AutoFilter raise XlsxError {
  let range_ref = adjust_range_after_row_insert(filter.range_ref, row, count)
  let copied = clone_auto_filter(filter)
  { range_ref, columns: copied.columns }
}

///|
fn adjust_auto_filter_after_row_remove(
  filter : AutoFilter,
  row : Int,
  count : Int,
) -> AutoFilter? raise XlsxError {
  match adjust_range_after_row_remove(filter.range_ref, row, count) {
    Some(range_ref) => {
      let copied = clone_auto_filter(filter)
      Some({ range_ref, columns: copied.columns })
    }
    None => None
  }
}

///|
fn adjust_auto_filter_after_col_insert(
  filter : AutoFilter,
  col : Int,
  count : Int,
) -> AutoFilter raise XlsxError {
  let range_ref = adjust_range_after_col_insert(filter.range_ref, col, count)
  let columns : Array[AutoFilterColumn] = []
  for entry in filter.columns {
    let updated_col = if entry.col >= col {
      entry.col + count
    } else {
      entry.col
    }
    columns.push({
      col: updated_col,
      filters: entry.filters,
      custom_filters: entry.custom_filters,
    })
  }
  { range_ref, columns }
}

///|
fn adjust_auto_filter_after_col_remove(
  filter : AutoFilter,
  col : Int,
  count : Int,
) -> AutoFilter? raise XlsxError {
  let end = col + count - 1
  match adjust_range_after_col_remove(filter.range_ref, col, count) {
    Some(range_ref) => {
      let columns : Array[AutoFilterColumn] = []
      for entry in filter.columns {
        if entry.col >= col && entry.col <= end {
          continue
        }
        let updated_col = if entry.col > end {
          entry.col - count
        } else {
          entry.col
        }
        columns.push({
          col: updated_col,
          filters: entry.filters,
          custom_filters: entry.custom_filters,
        })
      }
      Some({ range_ref, columns })
    }
    None => None
  }
}

///|
fn adjust_hyperlink_ref_after_row_insert(
  reference : String,
  row : Int,
  count : Int,
) -> String raise XlsxError {
  if reference.contains(":") {
    adjust_range_after_row_insert(reference, row, count)
  } else {
    adjust_cell_after_row_insert(reference, row, count)
  }
}

///|
fn adjust_hyperlink_ref_after_row_remove(
  reference : String,
  row : Int,
  count : Int,
) -> String? raise XlsxError {
  if reference.contains(":") {
    adjust_range_after_row_remove(reference, row, count)
  } else {
    adjust_cell_after_row_remove(reference, row, count)
  }
}

///|
fn adjust_hyperlink_ref_after_col_insert(
  reference : String,
  col : Int,
  count : Int,
) -> String raise XlsxError {
  if reference.contains(":") {
    adjust_range_after_col_insert(reference, col, count)
  } else {
    adjust_cell_after_col_insert(reference, col, count)
  }
}

///|
fn adjust_hyperlink_ref_after_col_remove(
  reference : String,
  col : Int,
  count : Int,
) -> String? raise XlsxError {
  if reference.contains(":") {
    adjust_range_after_col_remove(reference, col, count)
  } else {
    adjust_cell_after_col_remove(reference, col, count)
  }
}

///|
fn adjust_cell_after_row_insert(
  reference : String,
  row : Int,
  count : Int,
) -> String raise XlsxError {
  let (cell_row, cell_col) = cell_ref_to_rc(reference)
  let new_row = if cell_row >= row { cell_row + count } else { cell_row }
  cell_ref_from(new_row, cell_col)
}

///|
fn adjust_cell_after_row_remove(
  reference : String,
  row : Int,
  count : Int,
) -> String? raise XlsxError {
  let (cell_row, cell_col) = cell_ref_to_rc(reference)
  let end_row = row + count - 1
  if cell_row < row {
    Some(cell_ref_from(cell_row, cell_col))
  } else if cell_row <= end_row {
    None
  } else {
    Some(cell_ref_from(cell_row - count, cell_col))
  }
}

///|
fn adjust_cell_after_col_insert(
  reference : String,
  col : Int,
  count : Int,
) -> String raise XlsxError {
  let (cell_row, cell_col) = cell_ref_to_rc(reference)
  let new_col = if cell_col >= col { cell_col + count } else { cell_col }
  cell_ref_from(cell_row, new_col)
}

///|
fn adjust_cell_after_col_remove(
  reference : String,
  col : Int,
  count : Int,
) -> String? raise XlsxError {
  let (cell_row, cell_col) = cell_ref_to_rc(reference)
  let end_col = col + count - 1
  if cell_col < col {
    Some(cell_ref_from(cell_row, cell_col))
  } else if cell_col <= end_col {
    None
  } else {
    Some(cell_ref_from(cell_row, cell_col - count))
  }
}

///|
fn clone_table_columns(columns : ArrayView[String]) -> Array[String] {
  let out : Array[String] = []
  for column in columns {
    out.push(column)
  }
  out
}

///|
fn table_default_column_name(index : Int) -> String {
  "Column\{index}"
}

///|
fn adjust_table_after_row_insert(
  table : Table,
  row : Int,
  count : Int,
) -> Table raise XlsxError {
  let range_ref = adjust_range_after_row_insert(table.range_ref, row, count)
  {
    id: table.id,
    name: table.name,
    display_name: table.display_name,
    range_ref,
    columns: clone_table_columns(table.columns),
    style_name: table.style_name,
    show_first_column: table.show_first_column,
    show_last_column: table.show_last_column,
    show_row_stripes: table.show_row_stripes,
    show_column_stripes: table.show_column_stripes,
    show_header_row: table.show_header_row,
  }
}

///|
fn adjust_table_after_row_remove(
  table : Table,
  row : Int,
  count : Int,
) -> Table? raise XlsxError {
  match adjust_range_after_row_remove(table.range_ref, row, count) {
    Some(range_ref) =>
      Some({
        id: table.id,
        name: table.name,
        display_name: table.display_name,
        range_ref,
        columns: clone_table_columns(table.columns),
        style_name: table.style_name,
        show_first_column: table.show_first_column,
        show_last_column: table.show_last_column,
        show_row_stripes: table.show_row_stripes,
        show_column_stripes: table.show_column_stripes,
        show_header_row: table.show_header_row,
      })
    None => None
  }
}

///|
fn adjust_table_after_col_insert(
  table : Table,
  col : Int,
  count : Int,
) -> Table raise XlsxError {
  let (min_row, min_col, max_row, max_col) = parse_range_ref(table.range_ref)
  let (new_min_col, new_max_col) = adjust_bounds_for_insert(
    min_col, max_col, col, count,
  )
  let columns = clone_table_columns(table.columns)
  if col > min_col && col <= max_col {
    let insert_index = col - min_col
    let base = columns.length() + 1
    let mut i = 0
    while i < count {
      columns.insert(insert_index + i, table_default_column_name(base + i))
      i = i + 1
    }
  }
  let start_ref = cell_ref_from(min_row, new_min_col)
  let end_ref = cell_ref_from(max_row, new_max_col)
  {
    id: table.id,
    name: table.name,
    display_name: table.display_name,
    range_ref: "\{start_ref}:\{end_ref}",
    columns,
    style_name: table.style_name,
    show_first_column: table.show_first_column,
    show_last_column: table.show_last_column,
    show_row_stripes: table.show_row_stripes,
    show_column_stripes: table.show_column_stripes,
    show_header_row: table.show_header_row,
  }
}

///|
fn adjust_table_after_col_remove(
  table : Table,
  col : Int,
  count : Int,
) -> Table? raise XlsxError {
  let (min_row, min_col, max_row, max_col) = parse_range_ref(table.range_ref)
  match adjust_bounds_for_remove(min_col, max_col, col, count) {
    Some((new_min_col, new_max_col)) => {
      let columns = clone_table_columns(table.columns)
      let end_col = col + count - 1
      if !(end_col < min_col || col > max_col) {
        let overlap_start = if col > min_col { col } else { min_col }
        let overlap_end = if end_col < max_col { end_col } else { max_col }
        let remove_count = overlap_end - overlap_start + 1
        let remove_index = overlap_start - min_col
        let mut i = 0
        while i < remove_count {
          ignore(columns.remove(remove_index))
          i = i + 1
        }
      }
      let start_ref = cell_ref_from(min_row, new_min_col)
      let end_ref = cell_ref_from(max_row, new_max_col)
      Some({
        id: table.id,
        name: table.name,
        display_name: table.display_name,
        range_ref: "\{start_ref}:\{end_ref}",
        columns,
        style_name: table.style_name,
        show_first_column: table.show_first_column,
        show_last_column: table.show_last_column,
        show_row_stripes: table.show_row_stripes,
        show_column_stripes: table.show_column_stripes,
        show_header_row: table.show_header_row,
      })
    }
    None => None
  }
}

///|
fn adjust_sparkline_group_after_row_insert(
  group : SparklineGroup,
  row : Int,
  count : Int,
) -> SparklineGroup raise XlsxError {
  let updated : Array[Sparkline] = []
  for sparkline in group.sparklines {
    let range_ref = adjust_range_after_row_insert(
      sparkline.range_ref,
      row,
      count,
    )
    let location = adjust_cell_after_row_insert(sparkline.location, row, count)
    updated.push({ range_ref, location })
  }
  {
    sparkline_type: group.sparkline_type,
    sparklines: updated,
    options: group.options,
  }
}

///|
fn adjust_sparkline_group_after_row_remove(
  group : SparklineGroup,
  row : Int,
  count : Int,
) -> SparklineGroup raise XlsxError {
  let updated : Array[Sparkline] = []
  for sparkline in group.sparklines {
    let range_ref = adjust_range_after_row_remove(
      sparkline.range_ref,
      row,
      count,
    )
    let location = adjust_cell_after_row_remove(sparkline.location, row, count)
    match (range_ref, location) {
      (Some(range_ref), Some(location)) => updated.push({ range_ref, location })
      _ => ()
    }
  }
  {
    sparkline_type: group.sparkline_type,
    sparklines: updated,
    options: group.options,
  }
}

///|
fn adjust_sparkline_group_after_col_insert(
  group : SparklineGroup,
  col : Int,
  count : Int,
) -> SparklineGroup raise XlsxError {
  let updated : Array[Sparkline] = []
  for sparkline in group.sparklines {
    let range_ref = adjust_range_after_col_insert(
      sparkline.range_ref,
      col,
      count,
    )
    let location = adjust_cell_after_col_insert(sparkline.location, col, count)
    updated.push({ range_ref, location })
  }
  {
    sparkline_type: group.sparkline_type,
    sparklines: updated,
    options: group.options,
  }
}

///|
fn adjust_sparkline_group_after_col_remove(
  group : SparklineGroup,
  col : Int,
  count : Int,
) -> SparklineGroup raise XlsxError {
  let updated : Array[Sparkline] = []
  for sparkline in group.sparklines {
    let range_ref = adjust_range_after_col_remove(
      sparkline.range_ref,
      col,
      count,
    )
    let location = adjust_cell_after_col_remove(sparkline.location, col, count)
    match (range_ref, location) {
      (Some(range_ref), Some(location)) => updated.push({ range_ref, location })
      _ => ()
    }
  }
  {
    sparkline_type: group.sparkline_type,
    sparklines: updated,
    options: group.options,
  }
}

///|
fn compare_cell(a : Cell, b : Cell) -> Int {
  if a.row != b.row {
    a.row - b.row
  } else {
    a.col - b.col
  }
}

///|
fn sort_cells(cells : Array[Cell]) -> Unit {
  let mut i = 1
  while i < cells.length() {
    let key = cells[i]
    let mut j = i - 1
    loop true {
      false => ()
      true => {
        if j < 0 || compare_cell(cells[j], key) <= 0 {
          continue false
        }
        cells[j + 1] = cells[j]
        j = j - 1
        continue true
      }
    }
    cells[j + 1] = key
    i = i + 1
  }
}
