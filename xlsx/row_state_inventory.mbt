///|
/// The engine-owned row-addressed state inventory: one authoritative
/// enumeration of every worksheet feature that lives at (or spans) row
/// positions, with how row INSERTION treats it. Consumers that must not
/// move content wrongly (template repetition preflight) read this instead
/// of maintaining a parallel hand-list that drifts from the writer.

///|
/// How `insert_rows`/`duplicate_row_to` treat a class today.
pub(all) enum RowStateHandling {
  /// Insertion adjusts the stored positions (staged, atomic — #136).
  ShiftedByInsert
  /// Written back unchanged; positions do NOT follow an insertion.
  StaticOnWrite
  /// Read into the model but never emitted by the writer.
  DroppedByWriter
} derive(Eq, @debug.Debug)

///|
/// The row extent a class occupies.
pub(all) enum RowStateExtent {
  /// Parsed positions; the highest 1-based row addressed.
  RowsUpTo(Int)
  /// Present but not row-interpretable (opaque markup, unparsable refs) —
  /// treat as touching every row.
  WholeSheet
  /// Present but carries no row semantics (view / pane presentation state).
  Positionless
} derive(Eq, @debug.Debug)

///|
pub(all) enum RowStateClass {
  Cells
  RowDimensions
  MergedRanges
  ConditionalFormats
  DataValidations
  HyperlinkAnchors
  /// Hyperlinks whose `location` names an internal destination — the
  /// anchor shifts but the TARGET text never does, so insertion can
  /// silently retarget them.
  InternalLinkTargets
  AutoFilterRange
  TableRanges
  SparklineAnchors
  ImageAnchors
  ChartAnchors
  ShapeAnchors
  FormControlAnchors
  SlicerAnchors
  CommentAnchors
  IgnoredErrorRanges
  RowPageBreaks
  CellValueMetadata
  DimensionRef
  PreservedDrawingAnchors
  VmlContent
  UnknownExtensions
  ViewState
  /// Workbook-level entry: defined names (ANY scope) whose refers_to
  /// carries references QUALIFIED to this sheet — exactly the refs the
  /// insertion staging rewrites. Appended by
  /// `Workbook::sheet_row_state_inventory`, never by the worksheet.
  DefinedNameReferences
  /// Workbook-level entry: names SCOPED to this sheet whose refers_to
  /// carries no qualified reference to it — the adjuster leaves their
  /// text untouched, so an insertion silently changes what unqualified
  /// context resolves them to.
  SheetScopedNamesUnadjusted
} derive(Eq, @debug.Debug)

///|
pub struct RowStateEntry {
  class : RowStateClass
  extent : RowStateExtent
  handling : RowStateHandling
} derive(Eq, @debug.Debug)

///|
/// Highest 1-based row of a cell or range reference, None when unparsable.
fn reference_max_row(reference : String) -> Int? {
  match (try? parse_range_ref(reference)) {
    Ok((_, _, max_row, _)) => Some(max_row)
    Err(_) => None
  }
}

///|
/// Highest row across a space-separated sqref list; None on any
/// unparsable component (callers degrade to WholeSheet).
fn sqref_max_row(sqref : String) -> Int? {
  let mut best = 0
  for token in sqref.split(" ") {
    if token.length() == 0 {
      continue
    }
    match reference_max_row(token.to_owned()) {
      Some(row) => if row > best { best = row }
      None => return None
    }
  }
  if best == 0 {
    None
  } else {
    Some(best)
  }
}

///|
/// Folds one anchor reference into a running (present, parsed-max,
/// any-unparsable) accumulator.
priv struct ExtentAccumulator {
  mut present : Bool
  mut max_row : Int
  mut opaque : Bool
}

///|
fn ExtentAccumulator::new() -> ExtentAccumulator {
  { present: false, max_row: 0, opaque: false }
}

///|
fn ExtentAccumulator::add_reference(
  self : ExtentAccumulator,
  reference : String,
) -> Unit {
  self.present = true
  match reference_max_row(reference) {
    Some(row) => if row > self.max_row { self.max_row = row }
    None => self.opaque = true
  }
}

///|
fn ExtentAccumulator::add_sqref(
  self : ExtentAccumulator,
  sqref : String,
) -> Unit {
  self.present = true
  match sqref_max_row(sqref) {
    Some(row) => if row > self.max_row { self.max_row = row }
    None => self.opaque = true
  }
}

///|
fn ExtentAccumulator::entry(
  self : ExtentAccumulator,
  class : RowStateClass,
  handling : RowStateHandling,
  into : Array[RowStateEntry],
) -> Unit {
  if !self.present {
    return
  }
  let extent = if self.opaque || self.max_row == 0 {
    WholeSheet
  } else {
    RowsUpTo(self.max_row)
  }
  into.push({ class, extent, handling })
}

///|
/// The value of an attribute in a raw feature XML string, or None. Used
/// for sqref extraction from stored conditional-format / data-validation
/// markup without materializing the full parse.
fn raw_attr_sqref(xml : String) -> String? {
  match (try? attr_value(xml, "sqref")) {
    Ok(Some(value)) => Some(unescape_xml_text(value))
    _ => None
  }
}

///|
/// Every row-addressed feature PRESENT on this worksheet, with extent and
/// insertion handling. Absent classes are omitted. Sheet-scoped defined
/// names live on the workbook — use `Workbook::sheet_row_state_inventory`
/// for the complete picture.
pub fn Worksheet::row_state_inventory(self : Worksheet) -> Array[RowStateEntry] {
  let entries : Array[RowStateEntry] = []
  if self.cells.length() > 0 {
    let mut max_row = 0
    for cell in self.cells {
      if cell.row > max_row {
        max_row = cell.row
      }
    }
    entries.push({
      class: Cells,
      extent: RowsUpTo(max_row),
      handling: ShiftedByInsert,
    })
  }
  if self.row_dimensions.size() > 0 {
    let mut max_row = 0
    for row, _ in self.row_dimensions {
      if row > max_row {
        max_row = row
      }
    }
    entries.push({
      class: RowDimensions,
      extent: RowsUpTo(max_row),
      handling: ShiftedByInsert,
    })
  }
  let merges = ExtentAccumulator::new()
  for range in self.merged_cells {
    merges.add_reference(range)
  }
  merges.entry(MergedRanges, ShiftedByInsert, entries)
  let cf = ExtentAccumulator::new()
  for xml in self.conditional_formats {
    cf.present = true
    match raw_attr_sqref(xml) {
      Some(sqref) => cf.add_sqref(sqref)
      None => cf.opaque = true
    }
  }
  cf.entry(ConditionalFormats, ShiftedByInsert, entries)
  let dv = ExtentAccumulator::new()
  for xml in self.data_validations {
    dv.present = true
    match raw_attr_sqref(xml) {
      Some(sqref) => dv.add_sqref(sqref)
      None => dv.opaque = true
    }
  }
  dv.entry(DataValidations, ShiftedByInsert, entries)
  let links = ExtentAccumulator::new()
  let mut internal_targets = false
  for link in self.hyperlinks {
    links.add_reference(link.reference)
    if link.location is Some(_) {
      internal_targets = true
    }
  }
  links.entry(HyperlinkAnchors, ShiftedByInsert, entries)
  if internal_targets {
    entries.push({
      class: InternalLinkTargets,
      extent: WholeSheet,
      handling: StaticOnWrite,
    })
  }
  match self.auto_filter {
    Some(filter) => {
      let acc = ExtentAccumulator::new()
      acc.add_reference(filter.range_ref)
      acc.entry(AutoFilterRange, ShiftedByInsert, entries)
    }
    None => ()
  }
  let tables = ExtentAccumulator::new()
  for table in self.tables {
    tables.add_reference(table.range_ref)
  }
  tables.entry(TableRanges, ShiftedByInsert, entries)
  let sparks = ExtentAccumulator::new()
  for group in self.sparkline_groups {
    for sparkline in group.sparklines {
      sparks.add_reference(sparkline.location)
      // insertion shifts the source range too (worksheet.mbt:5678);
      // sheet-qualified or otherwise unparsable sources degrade the
      // class to WholeSheet via the accumulator
      sparks.add_reference(sparkline.range_ref)
    }
  }
  sparks.entry(SparklineAnchors, ShiftedByInsert, entries)
  let images = ExtentAccumulator::new()
  for image in self.images {
    images.add_reference(image.reference)
  }
  images.entry(ImageAnchors, ShiftedByInsert, entries)
  let charts = ExtentAccumulator::new()
  for chart in self.charts {
    charts.add_reference(chart.reference)
  }
  charts.entry(ChartAnchors, ShiftedByInsert, entries)
  let shapes = ExtentAccumulator::new()
  for shape in self.shapes {
    shapes.add_reference(shape.cell)
  }
  shapes.entry(ShapeAnchors, StaticOnWrite, entries)
  let controls = ExtentAccumulator::new()
  for control in self.form_controls {
    controls.add_reference(control.cell)
  }
  controls.entry(FormControlAnchors, StaticOnWrite, entries)
  let slicers = ExtentAccumulator::new()
  for slicer in self.slicers {
    slicers.add_reference(slicer.cell)
  }
  slicers.entry(SlicerAnchors, StaticOnWrite, entries)
  let comments = ExtentAccumulator::new()
  for comment in self.comments {
    comments.add_reference(comment.cell)
  }
  comments.entry(CommentAnchors, StaticOnWrite, entries)
  let ignored = ExtentAccumulator::new()
  for item in self.ignored_errors {
    ignored.add_sqref(item.sqref)
  }
  ignored.entry(IgnoredErrorRanges, StaticOnWrite, entries)
  if self.row_breaks.length() > 0 {
    // row-break ids are 0-based (id = row - 1, #136); report the 1-based
    // row below the break, capped to the grid
    let mut max_row = 0
    for brk in self.row_breaks {
      let row = if brk.id >= cell_ref_max_rows {
        cell_ref_max_rows
      } else {
        brk.id + 1
      }
      if row > max_row {
        max_row = row
      }
    }
    entries.push({
      class: RowPageBreaks,
      extent: RowsUpTo(max_row),
      handling: ShiftedByInsert,
    })
  }
  let vm = ExtentAccumulator::new()
  for reference, _ in self.cell_vm {
    vm.add_reference(reference)
  }
  vm.entry(CellValueMetadata, DroppedByWriter, entries)
  match self.dimension_ref {
    Some(reference) => {
      let acc = ExtentAccumulator::new()
      acc.add_reference(reference)
      acc.entry(DimensionRef, StaticOnWrite, entries)
    }
    None => ()
  }
  if self.preserved_drawing_anchors.length() > 0 ||
    self.preserved_drawing_parts.length() > 0 {
    entries.push({
      class: PreservedDrawingAnchors,
      extent: WholeSheet,
      handling: StaticOnWrite,
    })
  }
  if self.vml_drawing_xml is Some(_) || self.vml_drawing_hf_xml is Some(_) {
    entries.push({
      class: VmlContent,
      extent: WholeSheet,
      handling: StaticOnWrite,
    })
  }
  if self.unknown_ext_blocks.length() > 0 {
    entries.push({
      class: UnknownExtensions,
      extent: WholeSheet,
      handling: StaticOnWrite,
    })
  }
  if self.sheet_views.length() > 0 {
    entries.push({
      class: ViewState,
      extent: Positionless,
      handling: StaticOnWrite,
    })
  }
  entries
}

///|
/// Row bound of one defined-name reference token (the text after a
/// `Sheet!` qualifier, `$` markers included): a parsed max row, no row
/// bound at all (column refs span every row but cannot overflow a row
/// insertion), or opaque.
priv enum DefinedRefRowBound {
  BoundedRows(Int)
  NoRowBound
  OpaqueRef
}

///|
/// Mirrors adjust_ref_after_row_insert EXACTLY: the adjuster shifts only
/// cell:cell ranges, row:row ranges, single cells, and single rows;
/// column refs pass through unchanged and carry no row semantics; every
/// other shape (heterogeneous ranges like A5:B, arbitrary text) passes
/// through unchanged while still LOOKING row-positioned — those are
/// opaque, never bounded-shifted (codex round 2).
fn defined_ref_row_bound(text : String) -> DefinedRefRowBound {
  match text.find(":") {
    Some(pos) => {
      let left = text.substring(start=0, end=pos)
      let right = text.substring(start=pos + 1)
      match (parse_cell_ref(left), parse_cell_ref(right)) {
        (Some((r1, _, _, _)), Some((r2, _, _, _))) =>
          return BoundedRows(if r1 > r2 { r1 } else { r2 })
        _ => ()
      }
      match (parse_row_ref(left), parse_row_ref(right)) {
        (Some((r1, _)), Some((r2, _))) =>
          return BoundedRows(if r1 > r2 { r1 } else { r2 })
        _ => ()
      }
      match (parse_column_ref(left), parse_column_ref(right)) {
        (Some(_), Some(_)) => return NoRowBound
        _ => ()
      }
      OpaqueRef
    }
    None => {
      match parse_cell_ref(text) {
        Some((row, _, _, _)) => return BoundedRows(row)
        None => ()
      }
      match parse_row_ref(text) {
        Some((row, _)) => return BoundedRows(row)
        None => ()
      }
      match parse_column_ref(text) {
        Some(_) => return NoRowBound
        None => ()
      }
      OpaqueRef
    }
  }
}

///|
/// The complete row-addressed inventory for one sheet. Defined names are
/// classified by MIRRORING THE ADJUSTER, not by scope (codex round 1):
/// the probe runs the same qualified-reference scan the insertion
/// staging runs, so a workbook-scoped `Data!$A$1048576` lands in Data's
/// `DefinedNameReferences` (it IS rewritten and can overflow), while a
/// sheet-scoped `$A$9` with no qualifier lands in
/// `SheetScopedNamesUnadjusted` (its text never moves).
pub fn Workbook::sheet_row_state_inventory(
  self : Workbook,
  sheet_name : StringView,
) -> Array[RowStateEntry] raise XlsxError {
  let sheet = self.require_sheet(sheet_name)
  let entries = sheet.row_state_inventory()
  let scope_key = defined_name_scope_key(sheet.name())
  let adjusted = ExtentAccumulator::new()
  let mut unadjusted_scoped = false
  for name in self.defined_names {
    let visited = Ref(0)
    let probe = fn(ref_text : StringView) -> String? raise XlsxError {
      visited.val = visited.val + 1
      let owned = ref_text.to_owned()
      adjusted.present = true
      match defined_ref_row_bound(owned) {
        BoundedRows(row) => if row > adjusted.max_row { adjusted.max_row = row }
        NoRowBound => ()
        OpaqueRef => adjusted.opaque = true
      }
      Some(owned)
    }
    let scan = try? adjust_defined_name_refers_to_for_sheet(
      name.refers_to,
      sheet.name(),
      probe,
    )
    if scan is Err(_) {
      adjusted.present = true
      adjusted.opaque = true
    }
    ignore(visited.val)
    // a sheet-scoped name is static-hazardous whenever ANY of its text
    // sits outside the qualified refs the adjuster rewrites — a partially
    // qualified "Data!$A$5+$B$1048576" keeps its unqualified half static
    // even though the probe visited the first half (codex round 2)
    if defined_name_scope_key(name.scope) == scope_key &&
      name_has_unqualified_content(name.refers_to, sheet.name()) {
      unadjusted_scoped = true
    }
  }
  adjusted.entry(DefinedNameReferences, ShiftedByInsert, entries)
  if unadjusted_scoped {
    entries.push({
      class: SheetScopedNamesUnadjusted,
      extent: WholeSheet,
      handling: StaticOnWrite,
    })
  }
  entries
}

///|
/// Whether any of a name's refers_to text sits OUTSIDE the qualified
/// references the adjuster rewrites for `sheet_name`. Runs the same scan
/// with an empty-substitution probe, strips every re-emitted qualifier,
/// and looks for leftover reference-shaped characters. Conservative:
/// scan errors and constant values (a bare "42") count as unqualified
/// content.
fn name_has_unqualified_content(
  refers_to : String,
  sheet_name : String,
) -> Bool {
  let marked = try? adjust_defined_name_refers_to_for_sheet(
    refers_to,
    sheet_name,
    _ => Some(""),
  )
  guard marked is Ok(scanned) else { return true }
  let plain_prefix = sheet_name + "!"
  let quoted_prefix = "'" + escape_sheet_name(sheet_name) + "'!"
  let mut leftover = scanned
  for prefix in [quoted_prefix, plain_prefix] {
    let pieces : Array[String] = []
    for piece in leftover.split(prefix) {
      pieces.push(piece.to_owned())
    }
    leftover = pieces.join("")
  }
  for unit in leftover {
    if unit is ('A'..='Z' | 'a'..='z' | '0'..='9' | '$') {
      return true
    }
  }
  false
}

///|
/// The first stored cell on this sheet carrying formula state — the
/// STORED presence test (`formula is Some(_)`, empty text included, so
/// shared-formula followers and array members count). `formula_refs()`
/// excludes empty formulas and must not be used for wrong-number gates.
pub fn Worksheet::first_stored_formula_cell(self : Worksheet) -> String? {
  for cell in self.cells {
    if cell.formula is Some(_) {
      return Some(cell.reference)
    }
  }
  None
}

///|
/// Clears the stored `<dimension>` so the writer recomputes it from live
/// geometry (cells, merges, tables, auto-filter). A stored value is
/// otherwise echoed verbatim and goes stale after row insertion.
pub fn Worksheet::clear_dimension_ref(self : Worksheet) -> Unit {
  self.dimension_ref = None
}
