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
  /// The innermost-first stack of open physical runs.
  run_stack : Array[SourceElementId]
  /// Open enclosing paragraphs. An ARMED frame participates in the next
  /// flush: the legacy walker keeps the outer physical paragraph in the
  /// accumulating logical paragraph and re-ensures it after each nested
  /// block, so the outer appears in the FIRST flush of each direct child
  /// subtree and in its own closing flush.
  paragraph_frames : Array[ReaderProjectionParagraphFrame]
  mut refusal : ReaderProjectionRefusal?
}

///|
priv struct ReaderProjectionParagraphFrame {
  inputs : Array[ReaderParagraphInput]
  mut armed : Bool
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
    run_stack: [],
    paragraph_frames: [],
    refusal: None,
  }
  builder.walk_items(items)
  match builder.refusal {
    Some(refusal) => return ProjectionRefused(refusal)
    None => ()
  }
  // whatever remains pending was never owned by a paragraph: zero-width
  // markers vanish unaddressed, visible content is a refusal
  for contribution in builder.pending {
    let visible = match contribution.kind {
      ProjectedText(_) => contribution.value.length() > 0
      VisibleNonText => true
      Transparent | SuppressedContent => false
    }
    if visible {
      return ProjectionRefused(
        UnownedVisibleContribution(source=contribution.source),
      )
    }
  }
  let projection : ReaderProjection = {
    source_part,
    scan,
    paragraphs: builder.paragraphs,
  }
  assign_reader_projection_coordinates(projection)
  Projected(projection)
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
  self.pending.push({
    kind,
    value,
    source: id,
    run_source: match self.run_stack.last() {
      Some(run) => Some(run)
      None => None
    },
    source_span,
    projection_start: 0,
    projection_end: 0,
    logical_run_index: -1,
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
            let frame : ReaderProjectionParagraphFrame = { inputs, armed: true }
            self.paragraph_frames.push(frame)
            for child in children {
              if self.refusal is Some(_) {
                break
              }
              // the enclosing paragraph participates in the FIRST flush of
              // each direct child subtree, exactly as the legacy walker
              // re-ensures the outer source after each nested block
              frame.armed = true
              self.walk_items([child])
            }
            ignore(self.paragraph_frames.pop())
            self.flush_paragraph(inputs)
            // extras erase as siblings AFTER the paragraph: walked in the
            // outer context so their paragraphs stand on their own
            self.walk_items(extras)
          }
          ReaderRun(children~, properties=_) => {
            guard self.identity_of(tree.source) is Some(id) else { return }
            self.register_run(id)
            self.run_stack.push(id)
            self.walk_items(children)
            ignore(self.run_stack.pop())
            // a run whose nested block flushed mid-run was re-registered
            // by the flush while it was still on the stack; nothing more
            // to do here
          }
          ReaderHyperlink(children~, ..) => self.walk_items(children)
          ReaderTable(children~, properties=_) => self.walk_items(children)
          ReaderTableRow(children~, is_header=_) => self.walk_items(children)
          ReaderTableCell(children~, ..) => self.walk_items(children)
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
  for frame in self.paragraph_frames {
    if frame.armed {
      for input in frame.inputs {
        guard self.identity_of(input.paragraph) is Some(id) else { return }
        sources.push({ source: id, source_span: self.element_span(id) })
      }
      frame.armed = false
    }
  }
  for input in inputs {
    guard self.identity_of(input.paragraph) is Some(id) else { return }
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
  // runs still open across the flush participate in the NEXT paragraph too
  for id in self.run_stack {
    self.register_run(id)
  }
}
