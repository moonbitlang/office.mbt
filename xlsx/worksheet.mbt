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
    parts.push(part.to_owned())
  }
  if parts.length() != 2 {
    raise InvalidCellRef(value=range_ref.to_owned())
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
/// Writes `value` into the cell at `reference` (A1 notation, e.g. `"B2"`) as a
/// raw string, overwriting any existing content while preserving the cell's
/// style. For numeric or boolean values use `set_cell_value`; for dates and
/// times use `Workbook::set_cell_time`; for formulas use `set_cell_formula`.
///
/// Raises `XlsxError` if `reference` is not a valid A1 cell reference, or
/// `StreamModeConflict` if the worksheet is currently driven by a stream
/// writer.
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
/// Returns the raw string value of the cell at `reference` (A1 notation), or
/// `None` if the cell has never been set. Numbers and booleans are returned in
/// their stored string form; use `get_cell_value_raw` to recover the typed
/// `CellValue` instead.
///
/// Raises `XlsxError` if `reference` is not a valid A1 cell reference.
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
/// Writes a typed `CellValue` (number, string, boolean, …) into the cell at
/// `reference` (A1 notation), overwriting existing content while preserving the
/// cell's style. Prefer this over `set_cell` when the value should be stored as
/// a number or boolean rather than as text (so Excel treats it numerically).
///
/// Raises `XlsxError` if `reference` is not a valid A1 cell reference, or
/// `StreamModeConflict` if the worksheet is currently driven by a stream
/// writer.
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
/// Returns the typed `CellValue` stored at `reference` (A1 notation), or `None`
/// if the cell has never been set. Unlike `get_cell`, this preserves the value
/// type (number vs. text vs. boolean) rather than coercing to a string.
///
/// Raises `XlsxError` if `reference` is not a valid A1 cell reference.
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
fn Worksheet::get_cell_type(
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
/// The A1 references of every cell on this sheet that carries a **non-empty**
/// formula, in stored order. A small primitive for tools that need to visit
/// the formula cells (e.g. a formula lint) without scanning the whole grid —
/// the set of formula cells is usually far smaller than the used range.
///
/// A shared-formula *slave* stores an empty formula string (the master holds
/// the text) and is not independently evaluable, so it is excluded — visiting
/// one would only mislead a caller that evaluates the formula.
pub fn Worksheet::formula_refs(self : Worksheet) -> Array[String] {
  let refs = []
  for cell in self.cells {
    match cell.formula {
      Some(formula) if formula != "" => refs.push(cell.reference)
      _ => ()
    }
  }
  refs
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
        location: if link_type == Location {
          Some(target)
        } else {
          None
        },
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
      location: if link_type == Location {
        Some(target)
      } else {
        None
      },
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
/// Returns the cell references of hyperlinks in the worksheet, mirroring
/// Excelize's `GetHyperLinkCells`. Omitting `link_type` returns every
/// hyperlink; `External` and `Location` filter by hyperlink kind; `Unset`
/// (Excelize's "None") returns no references.
pub fn Worksheet::get_hyperlink_cells(
  self : Worksheet,
  link_type? : HyperlinkType,
) -> Array[String] {
  let references : Array[String] = []
  match link_type {
    None =>
      for link in self.hyperlinks {
        references.push(link.reference)
      }
    Some(Unset) => ()
    // Excelize filters External by r:id presence and Location by the
    // location attribute independently, so an external link that also
    // carries a location fragment matches both filters.
    Some(Location) =>
      for link in self.hyperlinks {
        if link.link_type == Location || link.location is Some(_) {
          references.push(link.reference)
        }
      }
    Some(wanted) =>
      for link in self.hyperlinks {
        if link.link_type == wanted {
          references.push(link.reference)
        }
      }
  }
  references
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
  self.hyperlinks.append(updated)
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
    author_id: comment.author_id,
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
  self.comments.append(updated)
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
/// Merges the rectangular range `range_ref` (e.g. `"A1:C3"`) into a single
/// region; the top-left cell's value is displayed across the whole range. The
/// range is normalized, so `"C3:A1"` and `"A1:C3"` are equivalent.
///
/// Raises `XlsxError` if `range_ref` is not a valid range reference.
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
  let target = name.to_owned()
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
  self.tables.append(updated)
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
pub fn Worksheet::delete_pivot_table(
  self : Worksheet,
  name : StringView,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let target = name.to_owned()
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
  let value = extension.to_owned()
  let trimmed = match value.strip_prefix(".") {
    Some(rest) => rest.to_owned()
    None => value
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
  fn trim_leading_dot(value : StringView) -> String {
    let parts = Array::from_iter(value.split("."))
    let rest : Array[String] = []
    for i, part in parts {
      if i > 0 {
        rest.push(part.to_owned())
      }
    }
    rest.join(".")
  }
  let raw = extension.to_owned()
  if !raw.has_prefix(".") || raw.length() <= 1 {
    raise UnsupportedFeature(msg=unsupported_msg.to_owned())
  }
  let trimmed = trim_leading_dot(raw)
  trimmed.to_lower()
}

///|
fn check_header_footer_image_size(
  value : StringView,
  field_name : StringView,
) -> Unit raise XlsxError {
  if value.to_owned() == "" {
    raise InvalidHeaderFooter(msg="\{field_name.to_owned()} empty")
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
  fn default_col_width_from_props(props : SheetPropsOptions) -> Int {
    match props.default_col_width {
      Some(w) => convert_col_width_to_pixels(w)
      None => {
        let base = props.base_col_width.unwrap_or(default_sheet_base_col_width)
        convert_col_width_to_pixels(Double::from_int(base))
      }
    }
  }
  match self.col_dimensions.get(col) {
    Some(dim) =>
      if dim.hidden {
        0
      } else {
        match dim.width {
          Some(width) => convert_col_width_to_pixels(width)
          None => {
            let props = sheet_props_with_defaults(self.sheet_props)
            default_col_width_from_props(props)
          }
        }
      }
    None => {
      let props = sheet_props_with_defaults(self.sheet_props)
      default_col_width_from_props(props)
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
  match options.file {
    Some(_) =>
      raise InvalidHeaderFooter(
        msg="header/footer image file path requires add_header_footer_image_from_file",
      )
    None => ()
  }
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
  self.header_footer_images.append(updated)
}

///|
#cfg(target="native")
async fn Worksheet::add_header_footer_image_from_file(
  self : Worksheet,
  options : HeaderFooterImageOptions,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let path = match options.file {
    Some(value) => value
    None =>
      raise InvalidHeaderFooter(msg="header/footer image file path missing")
  }
  let data = read_file_bytes(path) catch {
    err =>
      raise InvalidHeaderFooter(
        msg="read header/footer image failed: \{repr(err)}",
      )
  }
  self.add_header_footer_image(
    HeaderFooterImageOptions::new(
      options.position,
      data,
      options.extension,
      is_footer=options.is_footer,
      first_page=options.first_page,
      width=options.width,
      height=options.height,
    ),
  )
}

///|
fn Worksheet::add_picture_from_bytes(
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
fn Worksheet::add_picture_from_bytes_with_options(
  self : Worksheet,
  reference : String,
  data : Bytes,
  extension : String,
  options : GraphicOptions,
) -> Unit raise XlsxError {
  let offset_x = options.offset_x.unwrap_or(0)
  let offset_y = options.offset_y.unwrap_or(0)
  let scale_x = options.scale_x.unwrap_or(1.0)
  let scale_y = options.scale_y.unwrap_or(1.0)
  let hyperlink = options.hyperlink.unwrap_or("")
  let hyperlink_type = options.hyperlink_type.unwrap_or(Unset)
  let name = options.name.unwrap_or("")
  let alt_text = options.alt_text.unwrap_or("")
  let lock_aspect_ratio = options.lock_aspect_ratio.unwrap_or(false)
  let auto_fit = options.auto_fit.unwrap_or(false)
  let auto_fit_ignore_aspect = options.auto_fit_ignore_aspect.unwrap_or(false)
  let print_object = options.print_object.unwrap_or(true)
  let locked = options.locked.unwrap_or(true)
  let positioning = options.positioning.unwrap_or(OneCell)
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
#cfg(target="native")
async fn Worksheet::add_picture(
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
    err => raise InvalidSheetOperation(msg="read picture failed: \{repr(err)}")
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
#cfg(target="native")
async fn Worksheet::add_picture_with_options(
  self : Worksheet,
  reference : String,
  path : String,
  options : GraphicOptions,
) -> Unit raise XlsxError {
  let offset_x = options.offset_x.unwrap_or(0)
  let offset_y = options.offset_y.unwrap_or(0)
  let scale_x = options.scale_x.unwrap_or(1.0)
  let scale_y = options.scale_y.unwrap_or(1.0)
  let hyperlink = options.hyperlink.unwrap_or("")
  let hyperlink_type = options.hyperlink_type.unwrap_or(Unset)
  let name = options.name.unwrap_or("")
  let alt_text = options.alt_text.unwrap_or("")
  let lock_aspect_ratio = options.lock_aspect_ratio.unwrap_or(false)
  let auto_fit = options.auto_fit.unwrap_or(false)
  let auto_fit_ignore_aspect = options.auto_fit_ignore_aspect.unwrap_or(false)
  let print_object = options.print_object.unwrap_or(true)
  let locked = options.locked.unwrap_or(true)
  let positioning = options.positioning.unwrap_or(OneCell)
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
  let (img_w_px, img_h_px) = match image_dimensions_px(data, ext.to_lower()) {
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
fn Worksheet::get_pictures(
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
fn Worksheet::get_picture_cells(
  self : Worksheet,
) -> Array[String] raise XlsxError {
  let cells : Array[String] = []
  let seen : Map[String, Bool] = Map([])
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
fn Worksheet::delete_picture(
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
  self.images.append(updated)
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
  self.charts.append(updated)
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
fn Worksheet::get_form_controls(self : Worksheet) -> ArrayView[FormControl] {
  self.form_controls
}

///|
fn Worksheet::delete_form_control(
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
fn Worksheet::get_slicers(self : Worksheet) -> ArrayView[Slicer] {
  self.slicers
}

///|
fn Worksheet::delete_slicer(
  self : Worksheet,
  name : StringView,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  let target = name.to_owned()
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
fn Worksheet::add_data_validation_xml(self : Worksheet, xml : String) -> Unit {
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
  self.data_validations.append(updated)
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
  let parts = Array::from_iter(rule_xml.split(close_tag))
  if parts.length() <= 1 {
    raise InvalidXml(msg="cfRule tag invalid")
  }
  let before = parts[0].to_owned()
  let tail : Array[String] = []
  for i, part in parts {
    if i > 0 {
      tail.push(part.to_owned())
    }
  }
  let after = close_tag + tail.join(close_tag)
  "\{before}<extLst><ext uri=\"\{ext_uri_conditional_formatting_rule_id}\" xmlns:x14=\"\{ns_spreadsheet_x14}\"><x14:id>\{escape_xml_text(id)}</x14:id></ext></extLst>\{after}"
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
  let formats : Map[String, Array[ConditionalFormatOptions]] = Map([])
  for xml in self.conditional_formats {
    let (sqref, opts) = parse_conditional_format_xml(xml, self.x14_data_bars)
    match formats.get(sqref) {
      Some(existing) => {
        existing.append(opts)
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
  let updated : Array[(String, String)] = []
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
      Some(value) => updated.push((value, next_sqref))
      None => raise InvalidXml(msg="conditionalFormatting sqref update failed")
    }
  }
  self.conditional_formats.clear()
  for item in updated {
    let (xml, _sqref) = item
    self.conditional_formats.push(xml)
  }
  if self.x14_data_bars.length() > 0 {
    let prior : Map[String, X14DataBarProps] = Map([])
    for id, props in self.x14_data_bars {
      prior[id] = props
    }
    let referenced : Map[String, X14DataBarProps] = Map([])
    for item in updated {
      let (xml, sqref) = item
      let mut first = true
      for chunk in xml.split("<x14:id>") {
        if first {
          first = false
          continue
        }
        let text = chunk.to_owned()
        let end = match text.find("</x14:id>") {
          Some(pos) => pos
          None => continue
        }
        let id = unescape_xml_text(text[:end])
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
fn Worksheet::get_cell_value_raw_rc(
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
/// Writes `values` across row `row` (1-based) starting at column A, one raw
/// string per cell. Cells beyond `values` are left unchanged. For a single
/// typed cell use `set_cell_value`; to build very large sheets efficiently use
/// the stream writer (`Workbook::new_stream_writer`).
///
/// Raises `XlsxError` if `row` is less than 1, or — when `values` is non-empty
/// — `StreamModeConflict` if the worksheet is driven by a stream writer.
pub fn Worksheet::set_row(
  self : Worksheet,
  row : Int,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  // Preflight the whole write so it is all-or-nothing: writing incrementally
  // and only discovering an out-of-grid coordinate partway (row past the grid,
  // or more values than columns) would leave the row half-populated.
  if row <= 0 || row > cell_ref_max_rows {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  if values.length() > cell_ref_max_cols {
    raise InvalidCellRef(value="\{values.length()}:\{row}")
  }
  for i, value in values {
    self.set_cell_rc(row, i + 1, value)
  }
}

///|
/// Returns the raw string values of row `row` (1-based) from column A through
/// the last populated cell. Empty cells within that span are returned as empty
/// strings. Returns an empty array for a row with no cells.
///
/// Raises `XlsxError` if `row` is less than 1.
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
/// Writes `values` down column `col` (1-based) starting at row 1, one raw
/// string per cell. Cells beyond `values` are left unchanged.
///
/// Raises `XlsxError` if `col` is less than 1, or — when `values` is non-empty
/// — `StreamModeConflict` if the worksheet is driven by a stream writer.
pub fn Worksheet::set_col(
  self : Worksheet,
  col : Int,
  values : ArrayView[String],
) -> Unit raise XlsxError {
  // Preflight (see set_row): all-or-nothing, never a half-written column.
  if col <= 0 || col > cell_ref_max_cols {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  if values.length() > cell_ref_max_rows {
    raise InvalidCellRef(value="\{col}:\{values.length()}")
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
) -> Unit raise XlsxError {
  // The single choke point for every row-dimension write (heights, visibility,
  // outline levels, styles, and the stream writer): reject an out-of-grid key so
  // no `<row r>` beyond the sheet's rows is ever stored or serialized.
  if row < 1 || row > cell_ref_max_rows {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
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
) -> Unit raise XlsxError {
  if col < 1 || col > cell_ref_max_cols {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
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
fn Worksheet::row_outline_level(
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
fn Worksheet::set_row_style_range(
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
  // Preflight the upper bound so the range write is all-or-nothing.
  if end > cell_ref_max_rows {
    raise InvalidCellRef(value="\{0}:\{end}")
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
fn Worksheet::get_row_style(
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
fn Worksheet::set_col_outline_level(
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
fn Worksheet::set_col_style(
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
fn Worksheet::insert_rows(
  self : Worksheet,
  row : Int,
  count : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if row <= 0 || row > cell_ref_max_rows {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  if count <= 0 {
    raise InvalidSheetOperation(msg="row count must be positive")
  }
  // A count larger than the grid is meaningless and, more importantly, would let
  // `existing_row + count` wrap `Int` and slip past the upper-bound checks below.
  if count > cell_ref_max_rows {
    raise InvalidSheetOperation(
      msg="row count \{count} exceeds the sheet's \{cell_ref_max_rows} rows",
    )
  }
  // Transactional: stage every shifted collection into locals first — cell,
  // merge, hyperlink, filter, table, sparkline, image, and chart references
  // shift through `cell_ref_from`/range adjusters that raise once a coordinate
  // leaves the grid, and the two numerically-shifted collections (row
  // dimensions, page breaks) are bound-checked explicitly below. Nothing on
  // `self` is mutated until every stage succeeds, so an overflowing insert
  // raises and leaves the worksheet unchanged instead of half-shifted.
  let updated_cells : Array[Cell] = []
  for cell in self.cells {
    if cell.row >= row {
      let new_row = cell.row + count
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
    } else {
      updated_cells.push(cell)
    }
  }
  let updated_merges : Array[String] = []
  for range_ref in self.merged_cells {
    updated_merges.push(adjust_range_after_row_insert(range_ref, row, count))
  }
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
      location: link.location,
      display: link.display,
      tooltip: link.tooltip,
    })
  }
  let updated_filter = match self.auto_filter {
    Some(filter) =>
      Some(adjust_auto_filter_after_row_insert(filter, row, count))
    None => None
  }
  let updated_tables : Array[Table] = []
  for table in self.tables {
    updated_tables.push(adjust_table_after_row_insert(table, row, count))
  }
  let updated_sparklines : Array[SparklineGroup] = []
  for group in self.sparkline_groups {
    let adjusted = adjust_sparkline_group_after_row_insert(group, row, count)
    if adjusted.sparklines.length() > 0 {
      updated_sparklines.push(adjusted)
    }
  }
  let updated_images : Array[Image] = []
  for image in self.images {
    let reference = adjust_cell_after_row_insert(image.reference, row, count)
    updated_images.push(image_with_reference(image, reference))
  }
  let updated_charts : Array[Chart] = []
  for chart in self.charts {
    let reference = adjust_cell_after_row_insert(chart.reference, row, count)
    updated_charts.push(chart_with_reference(chart, reference))
  }
  let updated_rows : Map[Int, RowDimension] = Map([])
  for row_index, dim in self.row_dimensions {
    let new_row = if row_index >= row {
      // Overflow-safe: a stored dimension key can be arbitrarily large (the
      // dimension setters do not bound it), so validate BEFORE the addition.
      if row_index > cell_ref_max_rows - count {
        raise InvalidCellRef(value="\{0}:\{row_index}")
      }
      row_index + count
    } else {
      row_index
    }
    updated_rows[new_row] = dim
  }
  let break_start = row - 1
  // Break ids are 0-based (id = row - 1), so a shifted id must stay strictly
  // below the row maximum. Check the original ids overflow-safely, before
  // adjust_page_breaks_after_insert performs `id + count`.
  for brk in self.row_breaks {
    if brk.id >= break_start && brk.id > cell_ref_max_rows - 1 - count {
      raise InvalidCellRef(value="\{0}:\{brk.id}")
    }
  }
  let updated_breaks = adjust_page_breaks_after_insert(
    self.row_breaks,
    break_start,
    count,
  )
  // Commit: every stage above succeeded, so applying the staged state cannot
  // fail partway.
  self.invalidate_cell_index()
  self.cells.clear()
  self.cells.append(updated_cells)
  self.merged_cells.clear()
  self.merged_cells.append(updated_merges)
  self.hyperlinks.clear()
  self.hyperlinks.append(updated_links)
  self.auto_filter = updated_filter
  self.tables.clear()
  self.tables.append(updated_tables)
  self.sparkline_groups.clear()
  self.sparkline_groups.append(updated_sparklines)
  self.images.clear()
  self.images.append(updated_images)
  self.charts.clear()
  self.charts.append(updated_charts)
  self.row_dimensions.clear()
  for row_index, dim in updated_rows {
    self.row_dimensions[row_index] = dim
  }
  self.row_breaks.clear()
  self.row_breaks.append(updated_breaks)
}

///|
fn Worksheet::remove_rows(
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
  // Bound both the start and the count so `row + count - 1` cannot wrap `Int`
  // (a start or count beyond the grid removes nothing meaningful anyway).
  if row > cell_ref_max_rows {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  if count > cell_ref_max_rows {
    raise InvalidSheetOperation(
      msg="row count \{count} exceeds the sheet's \{cell_ref_max_rows} rows",
    )
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
  self.cells.append(updated_cells)
  let updated_merges : Array[String] = []
  for range_ref in self.merged_cells {
    match adjust_range_after_row_remove(range_ref, row, count) {
      Some(value) => updated_merges.push(value)
      None => ()
    }
  }
  self.merged_cells.clear()
  self.merged_cells.append(updated_merges)
  let updated_links : Array[Hyperlink] = []
  for link in self.hyperlinks {
    match adjust_hyperlink_ref_after_row_remove(link.reference, row, count) {
      Some(reference) =>
        updated_links.push({
          reference,
          target: link.target,
          link_type: link.link_type,
          location: link.location,
          display: link.display,
          tooltip: link.tooltip,
        })
      None => ()
    }
  }
  self.hyperlinks.clear()
  self.hyperlinks.append(updated_links)
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
  self.tables.append(updated_tables)
  let updated_sparklines : Array[SparklineGroup] = []
  for group in self.sparkline_groups {
    let adjusted = adjust_sparkline_group_after_row_remove(group, row, count)
    if adjusted.sparklines.length() > 0 {
      updated_sparklines.push(adjusted)
    }
  }
  self.sparkline_groups.clear()
  self.sparkline_groups.append(updated_sparklines)
  let updated_images : Array[Image] = []
  for image in self.images {
    match adjust_cell_after_row_remove(image.reference, row, count) {
      Some(reference) =>
        updated_images.push(image_with_reference(image, reference))
      None => ()
    }
  }
  self.images.clear()
  self.images.append(updated_images)
  let updated_charts : Array[Chart] = []
  for chart in self.charts {
    match adjust_cell_after_row_remove(chart.reference, row, count) {
      Some(reference) =>
        updated_charts.push(chart_with_reference(chart, reference))
      None => ()
    }
  }
  self.charts.clear()
  self.charts.append(updated_charts)
  let updated_rows : Map[Int, RowDimension] = Map([])
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
  self.row_breaks.append(updated_breaks)
}

///|
fn parse_cell_ref_with_abs(
  reference : StringView,
) -> (Int, Int, Bool, Bool) raise XlsxError {
  parse_cell_ref_parts(reference)
}

///|
fn format_cell_ref_with_abs(
  row : Int,
  col : Int,
  abs_col : Bool,
  abs_row : Bool,
) -> String raise XlsxError {
  let col_text = column_number_to_name(col)
  if row <= 0 || row > cell_ref_max_rows {
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
  fn split_sqref_range(text : StringView) -> (String, String) {
    let left = StringBuilder::new()
    let right = StringBuilder::new()
    let mut seen_sep = false
    for ch in text {
      if !seen_sep && ch == ':' {
        seen_sep = true
      } else if seen_sep {
        right.write_char(ch)
      } else {
        left.write_char(ch)
      }
    }
    if seen_sep {
      (left.to_string(), right.to_string())
    } else {
      let cell = text.to_owned()
      (cell, cell)
    }
  }
  let refs : Array[String] = []
  for text in xml_whitespace_tokens(sqref) {
    let (start_ref, end_ref) = split_sqref_range(text)
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
    self.conditional_formats.append(copies)
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
    self.data_validations.append(copies)
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
fn Worksheet::duplicate_row_to(
  self : Worksheet,
  row : Int,
  target_row : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  self.invalidate_cell_index()
  if row <= 0 || row > cell_ref_max_rows {
    raise InvalidCellRef(value="\{0}:\{row}")
  }
  if target_row <= 0 || row == target_row {
    raise InvalidSheetOperation(msg="duplicate row target must be different")
  }
  // The copy lands at `target_row`, so it must be an in-grid row (otherwise the
  // duplicate would write an out-of-grid reference like A1048577).
  if target_row > cell_ref_max_rows {
    raise InvalidCellRef(value="\{0}:\{target_row}")
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
fn Worksheet::insert_cols(
  self : Worksheet,
  col : Int,
  count : Int,
) -> Unit raise XlsxError {
  self.ensure_stream_idle()
  if col <= 0 || col > cell_ref_max_cols {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  if count <= 0 {
    raise InvalidSheetOperation(msg="column count must be positive")
  }
  // A count larger than the grid would let `existing_col + count` wrap `Int`.
  if count > cell_ref_max_cols {
    raise InvalidSheetOperation(
      msg="column count \{count} exceeds the sheet's \{cell_ref_max_cols} columns",
    )
  }
  // Transactional (see insert_rows): stage everything into locals — reference
  // shifts raise once a coordinate leaves the grid, column dimensions and page
  // breaks are bound-checked explicitly — and commit only once every stage has
  // succeeded, so an overflowing insert leaves the worksheet unchanged.
  let updated_cells : Array[Cell] = []
  for cell in self.cells {
    if cell.col >= col {
      let new_col = cell.col + count
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
    } else {
      updated_cells.push(cell)
    }
  }
  let updated_merges : Array[String] = []
  for range_ref in self.merged_cells {
    updated_merges.push(adjust_range_after_col_insert(range_ref, col, count))
  }
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
      location: link.location,
      display: link.display,
      tooltip: link.tooltip,
    })
  }
  let updated_filter = match self.auto_filter {
    Some(filter) =>
      Some(adjust_auto_filter_after_col_insert(filter, col, count))
    None => None
  }
  let updated_tables : Array[Table] = []
  for table in self.tables {
    updated_tables.push(adjust_table_after_col_insert(table, col, count))
  }
  let updated_sparklines : Array[SparklineGroup] = []
  for group in self.sparkline_groups {
    let adjusted = adjust_sparkline_group_after_col_insert(group, col, count)
    if adjusted.sparklines.length() > 0 {
      updated_sparklines.push(adjusted)
    }
  }
  let updated_images : Array[Image] = []
  for image in self.images {
    let reference = adjust_cell_after_col_insert(image.reference, col, count)
    updated_images.push(image_with_reference(image, reference))
  }
  let updated_charts : Array[Chart] = []
  for chart in self.charts {
    let reference = adjust_cell_after_col_insert(chart.reference, col, count)
    updated_charts.push(chart_with_reference(chart, reference))
  }
  let updated_cols : Map[Int, ColDimension] = Map([])
  for col_index, dim in self.col_dimensions {
    let new_col = if col_index >= col {
      // Overflow-safe (see insert_rows): stored keys are not bounded by their
      // setters, so validate before the addition.
      if col_index > cell_ref_max_cols - count {
        raise InvalidCellRef(value="\{col_index}:\{0}")
      }
      col_index + count
    } else {
      col_index
    }
    updated_cols[new_col] = dim
  }
  let break_start = col - 1
  // 0-based ids (see insert_rows): validate overflow-safely before the shift.
  for brk in self.col_breaks {
    if brk.id >= break_start && brk.id > cell_ref_max_cols - 1 - count {
      raise InvalidCellRef(value="\{brk.id}:\{0}")
    }
  }
  let updated_breaks = adjust_page_breaks_after_insert(
    self.col_breaks,
    break_start,
    count,
  )
  // Commit.
  self.invalidate_cell_index()
  self.cells.clear()
  self.cells.append(updated_cells)
  self.merged_cells.clear()
  self.merged_cells.append(updated_merges)
  self.hyperlinks.clear()
  self.hyperlinks.append(updated_links)
  self.auto_filter = updated_filter
  self.tables.clear()
  self.tables.append(updated_tables)
  self.sparkline_groups.clear()
  self.sparkline_groups.append(updated_sparklines)
  self.images.clear()
  self.images.append(updated_images)
  self.charts.clear()
  self.charts.append(updated_charts)
  self.col_dimensions.clear()
  for col_index, dim in updated_cols {
    self.col_dimensions[col_index] = dim
  }
  self.col_breaks.clear()
  self.col_breaks.append(updated_breaks)
}

///|
fn Worksheet::remove_cols(
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
  // Bound both the start and the count so `col + count - 1` cannot wrap `Int`.
  if col > cell_ref_max_cols {
    raise InvalidCellRef(value="\{col}:\{0}")
  }
  if count > cell_ref_max_cols {
    raise InvalidSheetOperation(
      msg="column count \{count} exceeds the sheet's \{cell_ref_max_cols} columns",
    )
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
  self.cells.append(updated_cells)
  let updated_merges : Array[String] = []
  for range_ref in self.merged_cells {
    match adjust_range_after_col_remove(range_ref, col, count) {
      Some(value) => updated_merges.push(value)
      None => ()
    }
  }
  self.merged_cells.clear()
  self.merged_cells.append(updated_merges)
  let updated_links : Array[Hyperlink] = []
  for link in self.hyperlinks {
    match adjust_hyperlink_ref_after_col_remove(link.reference, col, count) {
      Some(reference) =>
        updated_links.push({
          reference,
          target: link.target,
          link_type: link.link_type,
          location: link.location,
          display: link.display,
          tooltip: link.tooltip,
        })
      None => ()
    }
  }
  self.hyperlinks.clear()
  self.hyperlinks.append(updated_links)
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
  self.tables.append(updated_tables)
  let updated_sparklines : Array[SparklineGroup] = []
  for group in self.sparkline_groups {
    let adjusted = adjust_sparkline_group_after_col_remove(group, col, count)
    if adjusted.sparklines.length() > 0 {
      updated_sparklines.push(adjusted)
    }
  }
  self.sparkline_groups.clear()
  self.sparkline_groups.append(updated_sparklines)
  let updated_images : Array[Image] = []
  for image in self.images {
    match adjust_cell_after_col_remove(image.reference, col, count) {
      Some(reference) =>
        updated_images.push(image_with_reference(image, reference))
      None => ()
    }
  }
  self.images.clear()
  self.images.append(updated_images)
  let updated_charts : Array[Chart] = []
  for chart in self.charts {
    match adjust_cell_after_col_remove(chart.reference, col, count) {
      Some(reference) =>
        updated_charts.push(chart_with_reference(chart, reference))
      None => ()
    }
  }
  self.charts.clear()
  self.charts.append(updated_charts)
  let updated_cols : Map[Int, ColDimension] = Map([])
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
  self.col_breaks.append(updated_breaks)
}

///|
fn adjust_bounds_for_insert(
  raw_min : Int,
  raw_max : Int,
  start : Int,
  count : Int,
) -> (Int, Int) {
  // Order-aware: a defined-name range can be stored reversed (e.g. `$A$5:$A$1`).
  // Normalize to [min, max] before shifting so the result stays in-grid rather
  // than producing a bogus endpoint.
  let min = if raw_min <= raw_max { raw_min } else { raw_max }
  let max = if raw_min <= raw_max { raw_max } else { raw_min }
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
  raw_min : Int,
  raw_max : Int,
  start : Int,
  count : Int,
) -> (Int, Int)? {
  // Order-aware (see adjust_bounds_for_insert): normalize a reversed range so a
  // removal never yields a negative/out-of-order endpoint.
  let min = if raw_min <= raw_max { raw_min } else { raw_max }
  let max = if raw_min <= raw_max { raw_max } else { raw_min }
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
    range: range_ref,
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
        range: range_ref,
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
    range: "\{start_ref}:\{end_ref}",
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
        range: "\{start_ref}:\{end_ref}",
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
    for state = true {
      if !state {
        break
      }
      if j < 0 || compare_cell(cells[j], key) <= 0 {
        continue false
      }
      cells[j + 1] = cells[j]
      j = j - 1
      continue true
    }
    cells[j + 1] = key
    i = i + 1
  }
}

///|
test "worksheet wb: missing-cell getters return None" {
  let sheet = Worksheet::new("Sheet1")
  debug_inspect(sheet.get_cell_rich_text("Z99"), content="None")
  debug_inspect(sheet.get_cell_formula("Z99"), content="None")
  debug_inspect(sheet.get_cell_style("Z99"), content="None")
  debug_inspect(sheet.get_cell_style_rc(99, 26), content="None")
}

///|
test "worksheet wb: set_state updates worksheet visibility state" {
  let sheet = Worksheet::new("Sheet1")
  debug_inspect(sheet.state(), content="Visible")
  sheet.state = Hidden
  debug_inspect(sheet.state(), content="Hidden")
  sheet.state = VeryHidden
  debug_inspect(sheet.state(), content="VeryHidden")
}

///|
test "worksheet wb: sparkline and validation guard errors" {
  let sheet = Worksheet::new("Sheet1")
  let empty_inputs : Result[Unit, Error] = Ok(sheet.add_sparkline_group([], [])) catch {
    e => Err(e)
  }
  debug_inspect(
    empty_inputs,
    content=(
      #|Err(InvalidSparkline(msg="sparkline inputs empty"))
    ),
  )
  let empty_list : Result[Unit, Error] = Ok(
    sheet.add_data_validation_list("A1", []),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    empty_list,
    content=(
      #|Err(UnsupportedFeature(msg="empty validation list"))
    ),
  )
}

///|
test "worksheet wb: delete_slicer empty/missing/remove branches" {
  let sheet = Worksheet::new("Sheet1")
  let empty_name : Result[Unit, Error] = Ok(sheet.delete_slicer("")) catch {
    e => Err(e)
  }
  debug_inspect(
    empty_name,
    content=(
      #|Err(InvalidSheetOperation(msg="slicer name empty"))
    ),
  )
  let missing : Result[Unit, Error] = Ok(sheet.delete_slicer("Missing")) catch {
    e => Err(e)
  }
  debug_inspect(
    missing,
    content=(
      #|Err(InvalidSheetOperation(msg="slicer not found"))
    ),
  )

  let region = Slicer::new("Region") catch {
    err => fail("slicer init failed: \{repr(err)}")
  }
  let typ = Slicer::new("Type") catch {
    err => fail("slicer init failed: \{repr(err)}")
  }
  sheet.add_slicer(region)
  sheet.add_slicer(typ)
  sheet.delete_slicer("Region")
  let slicers = sheet.get_slicers()
  inspect(slicers.length(), content="1")
  inspect(slicers[0].name, content="Type")
}

///|
test "worksheet wb: data validation append/clear/error branches" {
  let sheet = Worksheet::new("Sheet1")
  let dv = DataValidation::new(true)
  dv.set_sqref("A1")
  dv.set_drop_list(["Yes"])
  sheet.add_data_validation_xml(data_validation_xml(dv))
  inspect(sheet.get_data_validations().length(), content="1")
  sheet.delete_data_validation()
  inspect(sheet.get_data_validations().length(), content="0")

  let dropped = Worksheet::new("Sheet1")
  let dv_drop = DataValidation::new(true)
  dv_drop.set_sqref("B2")
  dv_drop.set_drop_list(["No"])
  dropped.add_data_validation_xml(data_validation_xml(dv_drop))
  dropped.delete_data_validation(sqrefs=["B2"])
  inspect(dropped.get_data_validations().length(), content="0")

  let missing_tag = Worksheet::new("Sheet1")
  missing_tag.add_data_validation_xml("<foo/>")
  let missing_tag_result : Result[Unit, Error] = Ok(
    missing_tag.delete_data_validation(sqrefs=["A1"]),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    missing_tag_result,
    content=(
      #|Err(InvalidXml(msg="data validation tag missing"))
    ),
  )

  let missing_sqref = Worksheet::new("Sheet1")
  missing_sqref.add_data_validation_xml(
    "<dataValidation type=\"list\"><formula1>\"Y\"</formula1></dataValidation>",
  )
  let missing_sqref_result : Result[Unit, Error] = Ok(
    missing_sqref.delete_data_validation(sqrefs=["A1"]),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    missing_sqref_result,
    content=(
      #|Err(InvalidXml(msg="data validation sqref missing"))
    ),
  )
}

///|
test "worksheet wb: pivot-table wrapper and picture/header-footer guards" {
  let sheet = Worksheet::new("Sheet1")
  ignore(
    sheet.add_pivot_table_xml(
      "<pivotTableDefinition/>",
      "<pivotCacheDefinition/>",
      name="Pivot1",
    ),
  )
  inspect(sheet.pivot_tables().length(), content="1")

  sheet.add_image("A1", [1], ".png", "image/png")
  inspect(sheet.get_pictures("A1").length(), content="1")

  let dot_extension : Result[Unit, Error] = Ok(
    sheet.add_image("A1", [1], ".", "image/png"),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    dot_extension,
    content=(
      #|Err(UnsupportedFeature(msg="image extension missing"))
    ),
  )
  let empty_extension : Result[Unit, Error] = Ok(
    sheet.add_image("A1", [1], "", "image/png"),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    empty_extension,
    content=(
      #|Err(UnsupportedFeature(msg="image extension missing"))
    ),
  )
  let invalid_scale : Result[Unit, Error] = Ok(
    sheet.add_image("A1", [1], ".png", "image/png", scale_x=0.0),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    invalid_scale,
    content=(
      #|Err(InvalidSheetOperation(msg="picture scale must be > 0"))
    ),
  )

  let missing_width : Result[Unit, Error] = Ok(
    sheet.add_header_footer_image(
      HeaderFooterImageOptions::new(Left, [1], ".png", width="", height="8pt"),
    ),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    missing_width,
    content=(
      #|Err(InvalidHeaderFooter(msg="header/footer width empty"))
    ),
  )
  let missing_height : Result[Unit, Error] = Ok(
    sheet.add_header_footer_image(
      HeaderFooterImageOptions::new(Left, [1], ".png", width="9pt", height=""),
    ),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    missing_height,
    content=(
      #|Err(InvalidHeaderFooter(msg="header/footer height empty"))
    ),
  )
}

///|
test "worksheet wb: add_picture_from_bytes_with_options default branches" {
  let sheet = Worksheet::new("Sheet1")
  sheet.add_picture_from_bytes_with_options(
    "B2",
    [1, 2, 3],
    ".png",
    GraphicOptions::new(),
  )
  let pictures = sheet.get_pictures("B2")
  inspect(pictures.length(), content="1")
  let image = pictures[0]
  inspect(image.offset_x, content="0")
  inspect(image.offset_y, content="0")
  inspect(image.scale_x == 1.0, content="true")
  inspect(image.scale_y == 1.0, content="true")
  inspect(image.hyperlink == "", content="true")
  debug_inspect(image.hyperlink_type, content="Unset")
  inspect(image.name == "", content="true")
  inspect(image.alt_text == "", content="true")
  inspect(image.lock_aspect_ratio, content="false")
  inspect(image.print_object, content="true")
  inspect(image.locked, content="true")
  debug_inspect(image.positioning, content="OneCell")
}

///|
test "worksheet wb: picture option Some branches and guard errors" {
  let sheet = Worksheet::new("Sheet1")
  let opts = GraphicOptions::with_values(
    auto_fit=true,
    auto_fit_ignore_aspect=true,
  )
  sheet.add_picture_from_bytes_with_options("C3", [1, 2, 3], ".png", opts)
  inspect(sheet.get_pictures("C3").length(), content="1")

  let empty_vml : Result[Unit, Error] = Ok(sheet.add_vml_drawing_hf_xml("")) catch {
    e => Err(e)
  }
  debug_inspect(
    empty_vml,
    content=(
      #|Err(InvalidVmlDrawing(msg="vml drawing hf xml empty"))
    ),
  )
  let empty_options : Result[Unit, Error] = Ok(
    sheet.set_conditional_format("A1", []),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    empty_options,
    content=(
      #|Err(InvalidConditionalFormat(msg="options empty"))
    ),
  )
}

///|
test "worksheet wb: autofit merged anchor sums merged row/col spans" {
  let sheet = Worksheet::new("Sheet1")
  sheet.merge_cells("A1:B2")
  sheet.set_col_width(1, 10.0)
  sheet.set_col_width(2, 20.0)
  sheet.set_row_height(1, 10.0)
  sheet.set_row_height(2, 20.0)
  sheet.add_picture_from_bytes(
    "A1",
    [1, 2, 3],
    ".png",
    auto_fit=true,
    auto_fit_ignore_aspect=true,
  )
  let pictures = sheet.get_pictures("A1")
  inspect(pictures.length(), content="1")
  let image = pictures[0]
  inspect(image.width_emu, content="2286000")
  inspect(image.height_emu, content="342900")
}

///|
test "worksheet wb: autofit hits hidden/zero/outline pixel branches" {
  let hidden = Worksheet::new("Hidden")
  hidden.set_col_visible(1, false)
  hidden.set_row_visible(1, false)
  hidden.add_picture_from_bytes(
    "A1",
    [1],
    ".png",
    auto_fit=true,
    auto_fit_ignore_aspect=true,
  )
  let hidden_image = hidden.get_pictures("A1")[0]
  inspect(hidden_image.width_emu, content="0")
  inspect(hidden_image.height_emu, content="0")

  let zero = Worksheet::new("Zero")
  zero.set_col_width(1, 0.0)
  zero.set_row_height(1, 0.0)
  zero.add_picture_from_bytes(
    "A1",
    [1],
    ".png",
    auto_fit=true,
    auto_fit_ignore_aspect=true,
  )
  let zero_image = zero.get_pictures("A1")[0]
  inspect(zero_image.width_emu, content="0")
  inspect(zero_image.height_emu, content="0")

  let outline = Worksheet::new("Outline")
  outline.set_col_outline_level(1, 1)
  outline.set_row_outline_level(1, 1)
  outline.add_picture_from_bytes(
    "A1",
    [1],
    ".png",
    auto_fit=true,
    auto_fit_ignore_aspect=true,
  )
  let outline_image = outline.get_pictures("A1")[0]
  inspect(outline_image.width_emu, content="609600")
  inspect(outline_image.height_emu, content="171450")
}

///|
test "worksheet wb: chart option guards and reference helper copies" {
  let sheet = Worksheet::new("Sheet1")
  sheet.add_picture_from_bytes("A1", [1], ".png")

  let opts = ChartOptions::new(Col)
  opts.series.push(ChartSeries::new("Sheet1!$A$1:$A$2", "Sheet1!$B$1:$B$2"))
  opts.format = GraphicOptions::with_values(scale_x=1.25, scale_y=0.75)
  sheet.add_chart_with_options("B2", opts)
  inspect(sheet.charts().length(), content="1")

  let shifted_image = image_with_reference(sheet.get_pictures("A1")[0], "D5")
  inspect(shifted_image.reference, content="D5")
  let shifted_chart = chart_with_reference(sheet.charts()[0], "E6")
  inspect(shifted_chart.reference, content="E6")

  let bad_offset_opts = ChartOptions::new(Col)
  bad_offset_opts.format = GraphicOptions::with_values(
    offset_x=-1,
    offset_y=0,
    scale_x=1.0,
    scale_y=1.0,
  )
  let bad_offset : Result[Unit, Error] = Ok(
    sheet.add_chart_with_options("C3", bad_offset_opts),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    bad_offset,
    content=(
      #|Err(InvalidSheetOperation(msg="chart offset must be >= 0"))
    ),
  )

  let bad_scale_opts = ChartOptions::new(Col)
  bad_scale_opts.format = GraphicOptions::with_values(scale_x=0.0, scale_y=1.0)
  let bad_scale : Result[Unit, Error] = Ok(
    sheet.add_chart_with_options("C3", bad_scale_opts),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    bad_scale,
    content=(
      #|Err(InvalidSheetOperation(msg="chart scale must be > 0"))
    ),
  )
}

///|
test "worksheet wb: conditional format helper edge branches" {
  inspect(pad_left_dec(1234, 2), content="1234")
  let existing_ext = "<cfRule type=\"expression\"><extLst></extLst></cfRule>"
  debug_inspect(
    inject_x14_id_ext_lst_into_cf_rule(existing_ext, "id1"),
    content=(
      #|"<cfRule type=\"expression\"><extLst></extLst></cfRule>"
    ),
  )
  let invalid_rule : Result[String, Error] = Ok(
    inject_x14_id_ext_lst_into_cf_rule("<cfRule/>", "id1"),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    invalid_rule,
    content=(
      #|Err(InvalidXml(msg="cfRule tag invalid"))
    ),
  )
}

///|
test "worksheet wb: conditional/data-validation update-failure and x14 fallback paths" {
  let dv_update_fail = Worksheet::new("Sheet1")
  dv_update_fail.add_data_validation_xml(
    "<?xml version=\"1.0\"?><dataValidation type=\"list\" sqref=\"A1\"><formula1>\"Y\"</formula1></dataValidation>",
  )
  let dv_update_result : Result[Unit, Error] = Ok(
    dv_update_fail.delete_data_validation(sqrefs=["A2"]),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    dv_update_result,
    content=(
      #|Err(InvalidXml(msg="data validation sqref update failed"))
    ),
  )

  let cf_merge = Worksheet::new("Sheet1")
  cf_merge.add_conditional_format_xml(
    "<conditionalFormatting sqref=\"A1\"><cfRule type=\"expression\" priority=\"1\"><formula>1=1</formula></cfRule></conditionalFormatting>",
  )
  cf_merge.add_conditional_format_xml(
    "<conditionalFormatting sqref=\"A1\"><cfRule type=\"expression\" priority=\"2\"><formula>2=2</formula></cfRule></conditionalFormatting>",
  )
  let merged = cf_merge.get_conditional_formats()
  let merged_opts = match merged.get("A1") {
    Some(value) => value
    None => fail("missing merged conditional formats")
  }
  inspect(merged_opts.length(), content="2")

  let cf_missing_tag = Worksheet::new("Sheet1")
  cf_missing_tag.add_conditional_format_xml("<foo/>")
  let missing_tag_result : Result[Unit, Error] = Ok(
    cf_missing_tag.unset_conditional_format("A1"),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    missing_tag_result,
    content=(
      #|Err(InvalidXml(msg="conditionalFormatting tag missing"))
    ),
  )

  let cf_missing_sqref = Worksheet::new("Sheet1")
  cf_missing_sqref.add_conditional_format_xml(
    "<conditionalFormatting><cfRule type=\"expression\" priority=\"1\"><formula>1=1</formula></cfRule></conditionalFormatting>",
  )
  let missing_sqref_result : Result[Unit, Error] = Ok(
    cf_missing_sqref.unset_conditional_format("A1"),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    missing_sqref_result,
    content=(
      #|Err(InvalidXml(msg="conditionalFormatting sqref missing"))
    ),
  )

  let cf_update_fail = Worksheet::new("Sheet1")
  cf_update_fail.add_conditional_format_xml(
    "<?xml version=\"1.0\"?><conditionalFormatting sqref=\"A1\"><cfRule type=\"expression\" priority=\"1\"><formula>1=1</formula></cfRule></conditionalFormatting>",
  )
  let update_fail_result : Result[Unit, Error] = Ok(
    cf_update_fail.unset_conditional_format("A2"),
  ) catch {
    e => Err(e)
  }
  debug_inspect(
    update_fail_result,
    content=(
      #|Err(InvalidXml(msg="conditionalFormatting sqref update failed"))
    ),
  )

  let x14_prune = Worksheet::new("Sheet1")
  x14_prune.add_conditional_format_xml(
    "<conditionalFormatting sqref=\"A1\"><cfRule type=\"expression\" priority=\"1\"><x14:id>unknown</x14:id><formula>1=1</formula></cfRule></conditionalFormatting>",
  )
  x14_prune.add_conditional_format_xml(
    "<conditionalFormatting sqref=\"B1\"><cfRule type=\"expression\" priority=\"2\"><x14:id>broken<formula>2=2</formula></cfRule></conditionalFormatting>",
  )
  x14_prune.x14_data_bars["known"] = {
    sqref: "A1",
    bar_direction: "",
    bar_solid: false,
    bar_border_color: "",
  }
  x14_prune.unset_conditional_format("C1")
  inspect(x14_prune.x14_data_bars.length(), content="0")
}

///|
test "worksheet wb: rc cell api update branches and row/col basic guards" {
  let sheet = Worksheet::new("Sheet1")
  sheet.set_cell_style_rc(2, 2, 7)
  sheet.set_cell_value_rc(2, 2, Numeric(7.0))
  sheet.set_cell_value_rc(2, 2, String("txt"))
  sheet.set_cell_formula_rc(2, 2, "1+1", value="2")
  debug_inspect(sheet.get_cell_rc(2, 2), content="Some(\"2\")")
  debug_inspect(sheet.get_cell_formula("B2"), content="Some(\"1+1\")")
  inspect(sheet.get_cell_value_raw_rc(2, 2) is Some(_), content="true")
  debug_inspect(sheet.get_cell_rc(9, 9), content="None")
  debug_inspect(sheet.get_cell_value_raw_rc(9, 9), content="None")

  let bad_get_rc : Result[String?, Error] = Ok(sheet.get_cell_rc(0, 1)) catch {
    e => Err(e)
  }
  inspect(bad_get_rc is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_get_raw_rc : Result[CellValue?, Error] = Ok(
    sheet.get_cell_value_raw_rc(0, 1),
  ) catch {
    e => Err(e)
  }
  inspect(bad_get_raw_rc is Err(XlsxError::InvalidCellRef(_)), content="true")

  let bad_set_row : Result[Unit, Error] = Ok(sheet.set_row(0, ["A"])) catch {
    e => Err(e)
  }
  inspect(bad_set_row is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_set_col : Result[Unit, Error] = Ok(sheet.set_col(0, ["A"])) catch {
    e => Err(e)
  }
  inspect(bad_set_col is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_get_col : Result[Array[String], Error] = Ok(sheet.get_col(0)) catch {
    e => Err(e)
  }
  inspect(bad_get_col is Err(XlsxError::InvalidCellRef(_)), content="true")
}

///|
test "worksheet wb: row/col dimension guard and default branches" {
  let sheet = Worksheet::new("Sheet1")

  debug_inspect(sheet.get_row_height(5), content="None")
  inspect(sheet.row_visible(5), content="true")
  inspect(sheet.row_outline_level(5), content="0")
  debug_inspect(sheet.get_row_style(5), content="None")
  debug_inspect(sheet.get_col_width(5), content="None")
  inspect(sheet.col_visible(5), content="true")
  inspect(sheet.col_outline_level(5), content="0")
  debug_inspect(sheet.get_col_style(5), content="None")

  let bad_set_row_height_rc : Result[Unit, Error] = Ok(
    sheet.set_row_height(0, 1.0),
  ) catch {
    e => Err(e)
  }
  inspect(
    bad_set_row_height_rc is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_set_row_height_neg : Result[Unit, Error] = Ok(
    sheet.set_row_height(1, -1.0),
  ) catch {
    e => Err(e)
  }
  inspect(
    bad_set_row_height_neg is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  let bad_get_row_height : Result[Double?, Error] = Ok(sheet.get_row_height(0)) catch {
    e => Err(e)
  }
  inspect(
    bad_get_row_height is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_set_row_visible : Result[Unit, Error] = Ok(
    sheet.set_row_visible(0, true),
  ) catch {
    e => Err(e)
  }
  inspect(
    bad_set_row_visible is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_row_visible : Result[Bool, Error] = Ok(sheet.row_visible(0)) catch {
    e => Err(e)
  }
  inspect(bad_row_visible is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_set_row_outline_row : Result[Unit, Error] = Ok(
    sheet.set_row_outline_level(0, 1),
  ) catch {
    e => Err(e)
  }
  inspect(
    bad_set_row_outline_row is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_set_row_outline_level : Result[Unit, Error] = Ok(
    sheet.set_row_outline_level(1, 8),
  ) catch {
    e => Err(e)
  }
  inspect(
    bad_set_row_outline_level is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  let bad_row_outline_level : Result[Int, Error] = Ok(
    sheet.row_outline_level(0),
  ) catch {
    e => Err(e)
  }
  inspect(
    bad_row_outline_level is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_row_style_range_bounds : Result[Unit, Error] = Ok(
    sheet.set_row_style_range(0, 1, 1),
  ) catch {
    e => Err(e)
  }
  inspect(
    bad_row_style_range_bounds is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_row_style_range_order : Result[Unit, Error] = Ok(
    sheet.set_row_style_range(2, 1, 1),
  ) catch {
    e => Err(e)
  }
  inspect(
    bad_row_style_range_order is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  let bad_get_row_style : Result[Int?, Error] = Ok(sheet.get_row_style(0)) catch {
    e => Err(e)
  }
  inspect(
    bad_get_row_style is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )

  let bad_set_col_width_rc : Result[Unit, Error] = Ok(
    sheet.set_col_width(0, 1.0),
  ) catch {
    e => Err(e)
  }
  inspect(
    bad_set_col_width_rc is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_set_col_width_neg : Result[Unit, Error] = Ok(
    sheet.set_col_width(1, -1.0),
  ) catch {
    e => Err(e)
  }
  inspect(
    bad_set_col_width_neg is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  let bad_get_col_width : Result[Double?, Error] = Ok(sheet.get_col_width(0)) catch {
    e => Err(e)
  }
  inspect(
    bad_get_col_width is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_set_col_visible : Result[Unit, Error] = Ok(
    sheet.set_col_visible(0, true),
  ) catch {
    e => Err(e)
  }
  inspect(
    bad_set_col_visible is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_col_visible : Result[Bool, Error] = Ok(sheet.col_visible(0)) catch {
    e => Err(e)
  }
  inspect(bad_col_visible is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_set_col_outline_col : Result[Unit, Error] = Ok(
    sheet.set_col_outline_level(0, 1),
  ) catch {
    e => Err(e)
  }
  inspect(
    bad_set_col_outline_col is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_set_col_outline_level : Result[Unit, Error] = Ok(
    sheet.set_col_outline_level(1, 8),
  ) catch {
    e => Err(e)
  }
  inspect(
    bad_set_col_outline_level is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  let bad_col_outline_level : Result[Int, Error] = Ok(
    sheet.col_outline_level(0),
  ) catch {
    e => Err(e)
  }
  inspect(
    bad_col_outline_level is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_set_col_style : Result[Unit, Error] = Ok(sheet.set_col_style(0, 1)) catch {
    e => Err(e)
  }
  inspect(
    bad_set_col_style is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )
  let bad_get_col_style : Result[Int?, Error] = Ok(sheet.get_col_style(0)) catch {
    e => Err(e)
  }
  inspect(
    bad_get_col_style is Err(XlsxError::InvalidCellRef(_)),
    content="true",
  )

  sheet.set_row_style(2, 1)
  debug_inspect(sheet.get_row_style(2), content="Some(1)")
  sheet.set_row_style(2, 0)
  debug_inspect(sheet.get_row_style(2), content="None")
  sheet.set_col_style(2, 1)
  debug_inspect(sheet.get_col_style(2), content="Some(1)")
  sheet.set_col_style(2, 0)
  debug_inspect(sheet.get_col_style(2), content="None")

  let defaults = Worksheet::new("Defaults")
  defaults.set_sheet_props(
    Some(
      SheetPropsOptions::with_values(
        default_col_width=12.5,
        default_row_height=18.0,
      ),
    ),
  )
  defaults.set_col_outline_level(3, 1)
  defaults.set_row_outline_level(3, 1)
  defaults.add_picture_from_bytes(
    "C3",
    [1],
    ".png",
    auto_fit=true,
    auto_fit_ignore_aspect=true,
  )
  let image = defaults.get_pictures("C3")[0]
  inspect(image.width_emu, content="952500")
  inspect(image.height_emu, content="209550")
}

///|
test "worksheet wb: row insert/remove structural guard and adjustment branches" {
  let sheet = Worksheet::new("Sheet1")
  let bad_insert_row : Result[Unit, Error] = Ok(sheet.insert_rows(0, 1)) catch {
    e => Err(e)
  }
  inspect(bad_insert_row is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_insert_count : Result[Unit, Error] = Ok(sheet.insert_rows(1, 0)) catch {
    e => Err(e)
  }
  inspect(
    bad_insert_count is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  let bad_remove_row : Result[Unit, Error] = Ok(sheet.remove_rows(0, 1)) catch {
    e => Err(e)
  }
  inspect(bad_remove_row is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_remove_count : Result[Unit, Error] = Ok(sheet.remove_rows(1, 0)) catch {
    e => Err(e)
  }
  inspect(
    bad_remove_count is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )

  sheet.set_auto_filter("A1:B4", [])
  sheet.set_cell("A1", "head")
  sheet.set_cell("A3", "value")
  sheet.set_row_height(1, 12.0)
  sheet.add_picture_from_bytes("C3", [1], ".png")
  let chart = ChartOptions::new(Col)
  chart.series.push(ChartSeries::new("Sheet1!$A$1:$A$2", "Sheet1!$B$1:$B$2"))
  sheet.add_chart_with_options("D3", chart)
  sheet.insert_rows(2, 1)
  inspect(sheet.get_pictures("C4").length(), content="1")
  inspect(sheet.charts()[0].reference, content="D4")
  match sheet.auto_filter {
    Some(filter) => inspect(filter.range_ref, content="A1:B5")
    None => fail("missing auto filter after row insert")
  }

  sheet.remove_rows(2, 1)
  inspect(sheet.get_pictures("C3").length(), content="1")
  inspect(sheet.charts()[0].reference, content="D3")
  debug_inspect(sheet.get_row_height(1), content="Some(12)")
  match sheet.auto_filter {
    Some(filter) => inspect(filter.range_ref, content="A1:B4")
    None => fail("missing auto filter after row remove")
  }

  let drop = Worksheet::new("Drop")
  drop.merge_cells("A2:A2")
  ignore(drop.add_table("C2:D2", "DropTable", ["C", "D"]))
  drop.remove_rows(2, 1)
  inspect(drop.merged_cells().length(), content="0")
  inspect(drop.tables().length(), content="0")

  sheet.set_cell("A5", "tail")
  sheet.remove_rows(5, 1)
  debug_inspect(sheet.get_cell("A5"), content="None")
}

///|
test "worksheet wb: duplicate-row helper edge branches" {
  let (row, col, abs_col, abs_row) = parse_cell_ref_with_abs("$B$3")
  inspect(row, content="3")
  inspect(col, content="2")
  inspect(abs_col, content="true")
  inspect(abs_row, content="true")
  let bad_no_col : Result[(Int, Int, Bool, Bool), Error] = Ok(
    parse_cell_ref_with_abs("1A"),
  ) catch {
    e => Err(e)
  }
  inspect(bad_no_col is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_invalid_char : Result[(Int, Int, Bool, Bool), Error] = Ok(
    parse_cell_ref_with_abs("A1X"),
  ) catch {
    e => Err(e)
  }
  inspect(bad_invalid_char is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_no_row : Result[(Int, Int, Bool, Bool), Error] = Ok(
    parse_cell_ref_with_abs("A"),
  ) catch {
    e => Err(e)
  }
  inspect(bad_no_row is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_zero_row : Result[(Int, Int, Bool, Bool), Error] = Ok(
    parse_cell_ref_with_abs("A0"),
  ) catch {
    e => Err(e)
  }
  inspect(bad_zero_row is Err(XlsxError::InvalidCellRef(_)), content="true")

  inspect(format_cell_ref_with_abs(3, 2, true, true) == "$B$3", content="true")
  let bad_format : Result[String, Error] = Ok(
    format_cell_ref_with_abs(0, 1, false, false),
  ) catch {
    e => Err(e)
  }
  inspect(bad_format is Err(XlsxError::InvalidCellRef(_)), content="true")

  let refs = duplicate_sqref_for_row(1, 2, "  A1:A1   B1:B2  ")
  debug_inspect(refs, content="[\"A2:A2\"]")

  debug_inspect(duplicate_xml_sqref("<foo/>", 1, 2), content="None")
  debug_inspect(
    duplicate_xml_sqref("<dataValidation type=\"list\"></dataValidation>", 1, 2),
    content="None",
  )

  let dv = Worksheet::new("Sheet1")
  dv.add_data_validation_xml("<foo/>")
  dv.duplicate_data_validations(1, 2)
  inspect(dv.data_validations().length(), content="1")

  let merge_early = Worksheet::new("MergeEarly")
  merge_early.merge_cells("A1:A3")
  merge_early.duplicate_merge_cells(1, 2)
  inspect(merge_early.merged_cells().length(), content="1")

  let merge_shift = Worksheet::new("MergeShift")
  merge_shift.merge_cells("A4:B4")
  merge_shift.duplicate_merge_cells(3, 1)
  inspect(merge_shift.merged_cells().contains("A1:B1"), content="true")

  let duplicate = Worksheet::new("Duplicate")
  duplicate.set_row(1, ["A"])
  duplicate.duplicate_row_to(1, 2)
  debug_inspect(duplicate.get_row(2), content="[\"A\"]")
  let bad_target : Result[Unit, Error] = Ok(duplicate.duplicate_row_to(1, 1)) catch {
    e => Err(e)
  }
  inspect(
    bad_target is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
}

///|
test "worksheet wb: col insert/remove structural edge branches" {
  let guard_sheet = Worksheet::new("Guard")
  let bad_insert_col : Result[Unit, Error] = Ok(guard_sheet.insert_cols(0, 1)) catch {
    e => Err(e)
  }
  inspect(bad_insert_col is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_insert_count : Result[Unit, Error] = Ok(guard_sheet.insert_cols(1, 0)) catch {
    e => Err(e)
  }
  inspect(
    bad_insert_count is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )
  let bad_remove_col : Result[Unit, Error] = Ok(guard_sheet.remove_cols(0, 1)) catch {
    e => Err(e)
  }
  inspect(bad_remove_col is Err(XlsxError::InvalidCellRef(_)), content="true")
  let bad_remove_count : Result[Unit, Error] = Ok(guard_sheet.remove_cols(1, 0)) catch {
    e => Err(e)
  }
  inspect(
    bad_remove_count is Err(XlsxError::InvalidSheetOperation(_)),
    content="true",
  )

  let insert = Worksheet::new("Insert")
  insert.auto_filter = Some({
    range_ref: "A1:D4",
    columns: [
      { col: 1, filters: Some(["keep"]), custom_filters: None },
      { col: 3, filters: Some(["shift"]), custom_filters: None },
    ],
  })
  insert.hyperlinks.push({
    reference: "A1:C1",
    target: "https://example.com",
    link_type: External,
    location: None,
    display: None,
    tooltip: None,
  })
  insert.add_picture_from_bytes("C3", [1], ".png")
  let insert_chart = ChartOptions::new(Col)
  insert_chart.series.push(
    ChartSeries::new("Insert!$A$1:$A$2", "Insert!$B$1:$B$2"),
  )
  insert.add_chart_with_options("D3", insert_chart)
  insert.insert_cols(2, 1)
  inspect(insert.get_pictures("D3").length(), content="1")
  inspect(insert.charts()[0].reference, content="E3")
  inspect(insert.hyperlinks()[0].reference, content="A1:D1")
  match insert.auto_filter {
    Some(filter) => {
      inspect(filter.range_ref, content="A1:E4")
      inspect(filter.columns.length(), content="2")
      inspect(filter.columns[0].col, content="1")
      inspect(filter.columns[1].col, content="4")
    }
    None => fail("missing auto filter after col insert")
  }

  let remove = Worksheet::new("Remove")
  remove.set_col_width(1, 9.0)
  remove.set_col_width(4, 11.0)
  remove.merge_cells("B1:B1")
  remove.hyperlinks.push({
    reference: "B1",
    target: "https://drop.example",
    link_type: External,
    location: None,
    display: None,
    tooltip: None,
  })
  remove.hyperlinks.push({
    reference: "A1:C1",
    target: "https://range.example",
    link_type: External,
    location: None,
    display: None,
    tooltip: None,
  })
  remove.auto_filter = Some({
    range_ref: "A1:D4",
    columns: [
      { col: 1, filters: Some(["left"]), custom_filters: None },
      { col: 2, filters: Some(["drop"]), custom_filters: None },
      { col: 4, filters: Some(["right"]), custom_filters: None },
    ],
  })
  ignore(remove.add_table("B1:B2", "DropColTable", ["B"]))
  ignore(remove.add_table("D1:E2", "KeepColTable", ["D", "E"]))
  remove.add_sparkline_group(["B1", "D1"], ["B1:B1", "D1:D1"])
  remove.add_picture_from_bytes("A1", [1], ".png")
  remove.add_picture_from_bytes("B1", [1], ".png")
  let remove_chart_a = ChartOptions::new(Col)
  remove_chart_a.series.push(
    ChartSeries::new("Remove!$A$1:$A$2", "Remove!$B$1:$B$2"),
  )
  remove.add_chart_with_options("A1", remove_chart_a)
  let remove_chart_b = ChartOptions::new(Col)
  remove_chart_b.series.push(
    ChartSeries::new("Remove!$A$1:$A$2", "Remove!$B$1:$B$2"),
  )
  remove.add_chart_with_options("B1", remove_chart_b)
  remove.col_breaks.push({ id: 0, min: 0, max: 16383, manual: true })
  remove.col_breaks.push({ id: 4, min: 0, max: 16383, manual: true })
  remove.remove_cols(2, 1)
  inspect(remove.merged_cells().length(), content="0")
  inspect(remove.hyperlinks().length(), content="1")
  inspect(remove.hyperlinks()[0].reference, content="A1:B1")
  match remove.auto_filter {
    Some(filter) => {
      inspect(filter.range_ref, content="A1:C4")
      inspect(filter.columns.length(), content="2")
      inspect(filter.columns[0].col, content="1")
      inspect(filter.columns[1].col, content="3")
    }
    None => fail("missing auto filter after col remove")
  }
  inspect(remove.tables().length(), content="1")
  inspect(remove.tables()[0].name, content="KeepColTable")
  inspect(remove.tables()[0].range_ref, content="C1:D2")
  inspect(remove.sparkline_groups().length(), content="1")
  inspect(remove.sparkline_groups()[0].sparklines.length(), content="1")
  inspect(remove.sparkline_groups()[0].sparklines[0].location, content="C1")
  inspect(remove.get_pictures("A1").length(), content="1")
  inspect(remove.get_pictures("B1").length(), content="0")
  inspect(remove.charts().length(), content="1")
  inspect(remove.charts()[0].reference, content="A1")
  debug_inspect(remove.get_col_width(1), content="Some(9)")
  debug_inspect(remove.get_col_width(3), content="Some(11)")
  inspect(remove.col_breaks.length(), content="2")
  inspect(remove.col_breaks[0].id, content="0")
  inspect(remove.col_breaks[1].id, content="3")

  let filter_drop = Worksheet::new("FilterDrop")
  filter_drop.auto_filter = Some({
    range_ref: "B1:B2",
    columns: [{ col: 2, filters: Some(["x"]), custom_filters: None }],
  })
  filter_drop.remove_cols(2, 1)
  debug_inspect(filter_drop.auto_filter, content="None")

  let alias_sheet = Worksheet::new("Alias")
  alias_sheet.set_cell("A1", "a")
  alias_sheet.set_cell("B1", "b")
  alias_sheet.set_cell("C1", "c")
  alias_sheet.remove_cols(2, 1)
  debug_inspect(alias_sheet.get_cell("A1"), content="Some(\"a\")")
  debug_inspect(alias_sheet.get_cell("B1"), content="Some(\"c\")")
  debug_inspect(alias_sheet.get_cell("C1"), content="None")
}

///|
test "worksheet wb: row remove residual drop and range-helper branches" {
  let sheet = Worksheet::new("RowDrop")
  sheet.auto_filter = Some({ range_ref: "A2:B2", columns: [] })
  sheet.hyperlinks.push({
    reference: "A1:A3",
    target: "https://rows.example",
    link_type: External,
    location: None,
    display: None,
    tooltip: None,
  })
  sheet.add_sparkline_group(["A2", "A4"], ["A2:A2", "A4:A4"])
  sheet.add_picture_from_bytes("A1", [1], ".png")
  sheet.add_picture_from_bytes("A2", [1], ".png")
  let keep_chart = ChartOptions::new(Col)
  keep_chart.series.push(
    ChartSeries::new("RowDrop!$A$1:$A$2", "RowDrop!$B$1:$B$2"),
  )
  sheet.add_chart_with_options("A1", keep_chart)
  let drop_chart = ChartOptions::new(Col)
  drop_chart.series.push(
    ChartSeries::new("RowDrop!$A$1:$A$2", "RowDrop!$B$1:$B$2"),
  )
  sheet.add_chart_with_options("A2", drop_chart)

  sheet.insert_rows(2, 1)
  inspect(sheet.hyperlinks()[0].reference, content="A1:A4")
  sheet.remove_rows(2, 1)
  inspect(sheet.hyperlinks()[0].reference, content="A1:A3")

  sheet.remove_rows(2, 1)
  debug_inspect(sheet.auto_filter, content="None")
  inspect(sheet.hyperlinks()[0].reference, content="A1:A2")
  inspect(sheet.get_pictures("A1").length(), content="1")
  inspect(sheet.get_pictures("A2").length(), content="0")
  inspect(sheet.charts().length(), content="1")
  inspect(sheet.charts()[0].reference, content="A1")
  inspect(sheet.sparkline_groups().length(), content="1")
  inspect(sheet.sparkline_groups()[0].sparklines.length(), content="1")
  inspect(sheet.sparkline_groups()[0].sparklines[0].location, content="A3")
}
