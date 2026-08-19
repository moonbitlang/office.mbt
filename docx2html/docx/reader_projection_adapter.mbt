// The adapter (#434 PR 5): pure restructuring of one joined read into the
// reader-native projection. It groups contributions into paragraphs and
// runs and assigns identities, spans, and UTF-16 intervals; it never
// decides what is text-like -- the reader's effects already did.
//
// The walk mirrors the erase order exactly: a paragraph's children
// accumulate into the shared pending buffer, the paragraph CLOSE flushes
// the buffer as one logical paragraph (so flow-level content before a
// paragraph joins it, the way the erased partition behaves), and extras
// are walked in the outer context as the siblings they erase into.

///|
priv struct ReaderProjectionBuilder {
  scan : StoryScan
  budget : ReaderProjectionBudget
  paragraphs : Array[ReaderProjectionParagraph]
  /// Contributions accumulated toward the next paragraph flush.
  pending : Array[ReaderProjectionContribution]
  /// Physical runs observed since the last flush, in first-appearance
  /// order. Registered structurally on run entry so atomless runs stay
  /// addressable.
  pending_runs : Array[ReaderProjectionRun]
  /// The open enclosures, outermost first: paragraph frames, runs, and
  /// BLOCK BOUNDARIES (table family, extras re-homing). Boundaries stop
  /// both frame arming and run visibility, mirroring the legacy walker's
  /// per-level inline state.
  enclosures : Array[ReaderProjectionEnclosure]
  /// The field-carrier event stream, in walk order.
  field_carriers : Array[ReaderOrderFieldCarrierEvent]
  mut refusal : ReaderProjectionRefusal?
}

///|
priv enum ReaderProjectionEnclosure {
  EnclosingParagraph(ReaderProjectionParagraphFrame)
  EnclosingRun(SourceElementId)
  BlockBoundary
}

///|
priv struct ReaderProjectionParagraphFrame {
  inputs : Array[ReaderParagraphInput]
  mut armed : Bool
  cursor : ReaderProjectionCarrierCursor
}

///|
/// Projects one read's items over its story scan. `items` must come from
/// reading a JOINED story: any node without a physical identity refuses.
fn project_reader_items(
  source_part : String,
  scan : StoryScan,
  items : Array[ReaderItem],
  budget? : ReaderProjectionBudget,
) -> ReaderProjectionBuildResult raise DocxError {
  project_reader_item_segments(source_part, scan, [items], budget?)
}

///|
/// The multi-segment core: every segment's items walk through ONE shared
/// builder with a segment boundary between them, so ownership is checked
/// per segment while coordinates and carrier events stay continuous
/// across the whole part.
fn project_reader_item_segments(
  source_part : String,
  scan : StoryScan,
  segments : Array[Array[ReaderItem]],
  budget? : ReaderProjectionBudget,
) -> ReaderProjectionBuildResult raise DocxError {
  let budget = match budget {
    Some(value) => value
    None => reader_projection_budget(scan)
  }
  let builder : ReaderProjectionBuilder = {
    scan,
    budget,
    paragraphs: [],
    pending: [],
    pending_runs: [],
    enclosures: [],
    field_carriers: [],
    refusal: None,
  }
  for items in segments {
    builder.walk_items(items)
    match builder.refusal {
      Some(refusal) => return ProjectionRefused(refusal)
      None => ()
    }
    builder.finish_segment()
    match builder.refusal {
      Some(refusal) => return ProjectionRefused(refusal)
      None => ()
    }
  }
  let projection : ReaderProjection = {
    source_part,
    scan,
    paragraphs: builder.paragraphs,
    field_carriers: builder.field_carriers,
    field_index: empty_reader_order_field_index(),
  }
  assign_reader_projection_coordinates(projection)
  Projected(projection)
}

///|
/// The segment boundary: whatever remains pending was never owned by a
/// paragraph in THIS segment. Zero-width markers vanish unaddressed,
/// visible content is a refusal, and observed-but-unflushed runs must
/// not leak into the next segment's first paragraph.
fn ReaderProjectionBuilder::finish_segment(
  self : ReaderProjectionBuilder,
) -> Unit {
  for contribution in self.pending {
    let visible = match contribution.kind {
      ProjectedText(_) => contribution.value.length() > 0
      VisibleNonText => true
      Transparent | SuppressedContent => false
    }
    if visible {
      self.refusal = Some(
        UnownedVisibleContribution(source=contribution.source),
      )
      return
    }
  }
  self.pending.clear()
  self.pending_runs.clear()
}

///|
/// The run a contribution at the current position sits in: the enclosure
/// stack's top, when it is a run. A paragraph frame or block boundary on
/// top means the position is outside every run at its level, exactly as
/// each legacy inline state starts with no current run.
fn ReaderProjectionBuilder::current_run(
  self : ReaderProjectionBuilder,
) -> SourceElementId? {
  match self.enclosures.last() {
    Some(EnclosingRun(id)) => Some(id)
    _ => None
  }
}

///|
/// Arms every enclosing paragraph frame reachable through inline
/// containers -- stopping at the first block boundary -- so those frames
/// participate in the first flush of the block item about to be walked.
/// This is the legacy walker re-ensuring the outer source before each
/// `consume_inline_block_output`.
fn ReaderProjectionBuilder::arm_enclosing_frames(
  self : ReaderProjectionBuilder,
) -> Unit {
  for index = self.enclosures.length() - 1; index >= 0; index = index - 1 {
    match self.enclosures[index] {
      EnclosingParagraph(frame) => frame.armed = true
      EnclosingRun(_) => ()
      BlockBoundary => return
    }
  }
}

///|
/// Re-registers the runs of the CURRENT segment -- the enclosures above
/// the last block boundary -- into the pending runs, outermost first: the
/// legacy walker reopens its level's active runs after a flush or on
/// returning from a nested block.
fn ReaderProjectionBuilder::reopen_segment_runs(
  self : ReaderProjectionBuilder,
) -> Unit raise DocxError {
  let mut segment_start = 0
  for index, enclosure in self.enclosures {
    if enclosure is BlockBoundary {
      segment_start = index + 1
    }
  }
  for index in segment_start..<self.enclosures.length() {
    match self.enclosures[index] {
      EnclosingRun(id) => self.register_run(id)
      _ => ()
    }
  }
}

///|
fn reader_item_source(item : ReaderItem) -> ReaderNode {
  match item {
    New(tree) => tree.source
    Trace(effect) =>
      match effect {
        ProjectsText(source~, ..) => source
        ProjectsVisibleNonText(source~) => source
        TransparentBoundary(source~) => source
        Suppressed(source~) => source
      }
  }
}

///|
/// The authoritative ordered carrier events of one paragraph: every
/// direct physical child of every input, in document order -- exactly
/// what the legacy walker emits before visiting each carrier. The item
/// walk only decides WHEN each event fires (a cursor advances on item
/// position hints, so a nested paragraph's group interleaves at its
/// carrier's position); item sources never decide the SET or ORDER,
/// because field synthesis re-sources items at the field-begin carrier.
priv struct ReaderProjectionCarrierCursor {
  events : Array[ReaderOrderFieldCarrierEvent]
  positions : Map[Int, Int]
  mut next : Int
}

///|
fn ReaderProjectionBuilder::carrier_cursor(
  self : ReaderProjectionBuilder,
  inputs : Array[ReaderParagraphInput],
) -> ReaderProjectionCarrierCursor raise DocxError {
  // the events enumerate the PHYSICAL direct children of every input
  // paragraph, from the scan: the legacy walk events every direct child
  // it visits, including constructs the tolerant parse erased outright
  // (a no-fallback MC block leaves no DOM child at all). The cooked item
  // walk only times when the cursor fires.
  let elements = self.scan.elements()
  let events : Array[ReaderOrderFieldCarrierEvent] = []
  let positions : Map[Int, Int] = Map([])
  for input in inputs {
    match input.paragraph.source_element_id {
      Some(SourceElementId(paragraph_identity)) => {
        let mut child = elements[paragraph_identity].first_child_index
        while child != -1 {
          self.budget.charge_retained()
          positions[child] = events.length()
          events.push({ paragraph_identity, carrier_identity: child })
          child = elements[child].next_sibling_index
        }
      }
      None => ()
    }
  }
  { events, positions, next: 0 }
}

///|
/// Fires every event up to and including the carrier this item's source
/// sits under, when that carrier lies ahead of the cursor. A synthetic
/// source pointing at an earlier carrier advances nothing; the close
/// flush drains whatever remains.
fn ReaderProjectionBuilder::advance_carrier_cursor(
  self : ReaderProjectionBuilder,
  cursor : ReaderProjectionCarrierCursor,
  item : ReaderItem,
) -> Unit raise DocxError {
  guard reader_item_source(item).source_element_id
    is Some(SourceElementId(source_index)) else {
    return
  }
  self.advance_carrier_cursor_by_source(cursor, source_index)
}

///|
fn ReaderProjectionBuilder::advance_carrier_cursor_by_source(
  self : ReaderProjectionBuilder,
  cursor : ReaderProjectionCarrierCursor,
  source_index : Int,
) -> Unit raise DocxError {
  let elements = self.scan.elements()
  if source_index < 0 || source_index >= elements.length() {
    return
  }
  let mut current = source_index
  let mut target : Int? = None
  while current >= 0 {
    self.budget.charge_visit()
    match cursor.positions.get(current) {
      Some(position) => {
        target = Some(position)
        break
      }
      None => ()
    }
    current = elements[current].parent_index
  }
  match target {
    Some(position) =>
      while cursor.next <= position {
        self.budget.charge_retained()
        self.field_carriers.push(cursor.events[cursor.next])
        cursor.next = cursor.next + 1
      }
    None => ()
  }
}

///|
/// The legacy walk emits a carrier event BEFORE visiting the carrier. A
/// block item reached through a synthetic wrapper (a field-synthesized
/// hyperlink sourced at the begin carrier) must therefore advance every
/// enclosing paragraph's cursor from its OWN physical source before its
/// group fires -- the item-level hint saw only the wrapper's source.
/// Scoped through inline enclosures up to the first block boundary: a
/// nested table's cell paragraphs never advance an outer-level cursor.
fn ReaderProjectionBuilder::advance_enclosing_cursors(
  self : ReaderProjectionBuilder,
  source : ReaderNode,
) -> Unit raise DocxError {
  guard source.source_element_id is Some(SourceElementId(source_index)) else {
    return
  }
  for index = self.enclosures.length() - 1; index >= 0; index = index - 1 {
    match self.enclosures[index] {
      EnclosingParagraph(frame) =>
        self.advance_carrier_cursor_by_source(frame.cursor, source_index)
      EnclosingRun(_) => ()
      BlockBoundary => return
    }
  }
}

///|
fn ReaderProjectionBuilder::drain_carrier_cursor(
  self : ReaderProjectionBuilder,
  cursor : ReaderProjectionCarrierCursor,
) -> Unit raise DocxError {
  while cursor.next < cursor.events.length() {
    self.budget.charge_retained()
    self.field_carriers.push(cursor.events[cursor.next])
    cursor.next = cursor.next + 1
  }
}

///|
fn ReaderProjectionBuilder::identity_of(
  self : ReaderProjectionBuilder,
  node : ReaderNode,
) -> SourceElementId? {
  match node.source_element_id {
    Some(SourceElementId(index) as id) => {
      if index < 0 || index >= self.scan.elements().length() {
        if self.refusal is None {
          self.refusal = Some(SourceIdentityOutOfRange(id))
        }
        return None
      }
      Some(id)
    }
    None => {
      if self.refusal is None {
        self.refusal = Some(MissingSourceIdentity(node_name=node.name()))
      }
      None
    }
  }
}

///|
fn ReaderProjectionBuilder::atom_span(
  self : ReaderProjectionBuilder,
  id : SourceElementId,
) -> ReaderOrderSourceSpan {
  let SourceElementId(index) = id
  reader_order_atom_span(self.scan.elements()[index])
}

///|
fn ReaderProjectionBuilder::element_span(
  self : ReaderProjectionBuilder,
  id : SourceElementId,
) -> ReaderOrderSourceSpan {
  let SourceElementId(index) = id
  reader_order_element_span(self.scan.elements()[index])
}

///|
fn ReaderProjectionBuilder::push_effect(
  self : ReaderProjectionBuilder,
  effect : ReaderEffect,
) -> Unit raise DocxError {
  self.budget.charge_contribution()
  let (kind, value, source_node) = match effect {
    ProjectsText(source~, kind~, value~) => (ProjectedText(kind), value, source)
    ProjectsVisibleNonText(source~) => (VisibleNonText, "", source)
    TransparentBoundary(source~) => (Transparent, "", source)
    Suppressed(source~) => (SuppressedContent, "", source)
  }
  guard self.identity_of(source_node) is Some(id) else { return }
  let source_span = match kind {
    ProjectedText(_) => self.atom_span(id)
    _ => self.element_span(id)
  }
  let run_source = self.current_run()
  match run_source {
    // an attributed run is always in its paragraph's run records, even
    // when its structural registration was drained by an earlier flush
    Some(run) => self.register_run(run)
    None => ()
  }
  self.pending.push({
    kind,
    value,
    source: id,
    run_source,
    source_span,
    projection_start: 0,
    projection_end: 0,
    logical_run_index: -1,
    field_identity: None,
    field_region: OutsideField,
    field_refusal: None,
  })
}

///|
fn ReaderProjectionBuilder::register_run(
  self : ReaderProjectionBuilder,
  id : SourceElementId,
) -> Unit raise DocxError {
  // a physical run must BE a run element: a synthesized field-checkbox
  // run whose carrier is a tolerated non-run container (a hyperlink or a
  // control holding the begin marker) has no run-shaped address
  let SourceElementId(index) = id
  let element = self.scan.elements()[index]
  if !(is_wml_uri(element.uri) && element.local_name == "r") {
    if self.refusal is None {
      self.refusal = Some(
        SourceShapeMismatch(
          source=id,
          expected="w:r",
          actual=element.local_name,
        ),
      )
    }
    return
  }
  for run in self.pending_runs {
    if run.source == id {
      return
    }
  }
  self.budget.charge_retained()
  self.pending_runs.push({
    source: id,
    source_span: self.element_span(id),
    logical_index: -1,
  })
}

///|
fn ReaderProjectionBuilder::walk_items(
  self : ReaderProjectionBuilder,
  items : Array[ReaderItem],
) -> Unit raise DocxError {
  for item in items {
    if self.refusal is Some(_) {
      return
    }
    self.budget.charge_visit()
    match item {
      Trace(effect) => self.push_effect(effect)
      New(tree) => {
        for effect in tree.local_effects {
          self.push_effect(effect)
        }
        match tree.shape {
          ReaderParagraph(inputs~, children~, extras~, properties=_) => {
            // a block item at an inline position: the enclosing frames
            // participate in its first flush, and their cursors pass the
            // carrier containing this paragraph BEFORE its group fires
            self.arm_enclosing_frames()
            self.advance_enclosing_cursors(tree.source)
            let frame : ReaderProjectionParagraphFrame = {
              inputs,
              armed: true,
              cursor: self.carrier_cursor(inputs),
            }
            self.enclosures.push(EnclosingParagraph(frame))
            for child in children {
              if self.refusal is Some(_) {
                break
              }
              self.advance_carrier_cursor(frame.cursor, child)
              self.walk_items([child])
            }
            self.drain_carrier_cursor(frame.cursor)
            ignore(self.enclosures.pop())
            self.flush_paragraph(inputs)
            // extras erase as siblings AFTER the paragraph and re-home
            // block content: walked behind a boundary so nothing leaks
            // across in either direction
            self.enclosures.push(BlockBoundary)
            self.walk_items(extras)
            ignore(self.enclosures.pop())
            self.reopen_segment_runs()
          }
          ReaderRun(children~, properties=_) => {
            guard self.identity_of(tree.source) is Some(id) else { return }
            self.register_run(id)
            self.enclosures.push(EnclosingRun(id))
            self.walk_items(children)
            ignore(self.enclosures.pop())
          }
          ReaderHyperlink(children~, ..) => self.walk_items(children)
          ReaderTable(children~, properties=_) => {
            self.arm_enclosing_frames()
            self.advance_enclosing_cursors(tree.source)
            self.enclosures.push(BlockBoundary)
            self.walk_items(children)
            ignore(self.enclosures.pop())
            // returning to this level restores its active runs, like the
            // legacy reset after consuming a nested block's output
            self.reopen_segment_runs()
          }
          ReaderTableRow(children~, is_header=_) => {
            self.arm_enclosing_frames()
            self.advance_enclosing_cursors(tree.source)
            self.enclosures.push(BlockBoundary)
            self.walk_items(children)
            ignore(self.enclosures.pop())
            self.reopen_segment_runs()
          }
          ReaderTableCell(children~, ..) => {
            self.arm_enclosing_frames()
            self.advance_enclosing_cursors(tree.source)
            self.enclosures.push(BlockBoundary)
            self.walk_items(children)
            ignore(self.enclosures.pop())
            self.reopen_segment_runs()
          }
          ReaderText(_)
          | ReaderTab
          | ReaderCheckbox(_)
          | ReaderNoteReference(..)
          | ReaderCommentReference(_)
          | ReaderImage(_)
          | ReaderBreak(_)
          | ReaderBookmarkStart(_) => ()
        }
      }
    }
  }
}

///|
fn ReaderProjectionBuilder::flush_paragraph(
  self : ReaderProjectionBuilder,
  inputs : Array[ReaderParagraphInput],
) -> Unit raise DocxError {
  self.budget.charge_retained()
  let sources : Array[ReaderProjectionParagraphSource] = []
  for enclosure in self.enclosures {
    match enclosure {
      EnclosingParagraph(frame) =>
        if frame.armed {
          for input in frame.inputs {
            guard self.identity_of(input.paragraph) is Some(id) else { return }
            self.budget.charge_retained()
            sources.push({ source: id, source_span: self.element_span(id) })
          }
          frame.armed = false
        }
      _ => ()
    }
  }
  for input in inputs {
    guard self.identity_of(input.paragraph) is Some(id) else { return }
    self.budget.charge_retained()
    sources.push({ source: id, source_span: self.element_span(id) })
  }
  let contributions : Array[ReaderProjectionContribution] = []
  contributions.append(self.pending)
  self.pending.clear()
  let runs : Array[ReaderProjectionRun] = []
  runs.append(self.pending_runs)
  self.pending_runs.clear()
  self.paragraphs.push({
    sources,
    runs,
    contributions,
    logical_index: -1,
    projection_start: 0,
    projection_end: 0,
  })
  // runs are reopened by the CALLER once the paragraph's entire output --
  // extras included -- has been consumed, matching the legacy walker's
  // reopen-after-consume; reopening here would leak an outer run into the
  // extras' own paragraphs
}
