// The span-addressed formatting planner (F2a). Selection reuses find's
// own enumeration in text mode, so what formatting acts on is EXACTLY
// what find reported — but NOT find's verdict: `actionable` is the
// identity-REPLACEMENT judgment, and a hyperlink-boundary span that
// cannot be replaced is still perfectly formattable. Formatting's
// verdict is the formatting planner's own refusal, raised while
// planning.

///|
/// One selected span, as the receipt reports it.
pub struct DocxFormatSpan {
  path : String
  para_id : String?
  anchor_status : String
  start : Int
  end : Int
  text : String
  source_runs : Array[String]
}

///|
/// The paragraph the span belongs to, body-relative.
pub fn DocxFormatSpan::path(self : DocxFormatSpan) -> String {
  self.path
}

///|
/// The paragraph's canonical anchor paraId, when it carries one.
pub fn DocxFormatSpan::para_id(self : DocxFormatSpan) -> String? {
  self.para_id
}

///|
/// The paragraph's anchor status (`unique`, `missing`, `invalid`,
/// `duplicate`).
pub fn DocxFormatSpan::anchor_status(self : DocxFormatSpan) -> String {
  self.anchor_status
}

///|
/// The span's paragraph-local UTF-16 start offset.
pub fn DocxFormatSpan::start(self : DocxFormatSpan) -> Int {
  self.start
}

///|
/// The span's paragraph-local UTF-16 end offset, exclusive.
pub fn DocxFormatSpan::end(self : DocxFormatSpan) -> Int {
  self.end
}

///|
/// The projected text the span selects.
pub fn DocxFormatSpan::text(self : DocxFormatSpan) -> String {
  self.text
}

///|
/// The runs the span drew from BEFORE the edit — a snapshot, because a
/// split changes what runs exist.
pub fn DocxFormatSpan::source_runs(self : DocxFormatSpan) -> Array[String] {
  self.source_runs.copy()
}

///|
/// One affected paragraph: its identity, the projection it must STILL
/// read afterwards (formatting never moves text), and what the plan did
/// to its runs.
pub struct DocxFormatAffected {
  path : String
  expected : String
  para_id : String?
  anchor_status : String
  runs_changed : Int
  runs_already_satisfied : Int
  splits : Int
}

///|
/// The paragraph's body-relative path.
pub fn DocxFormatAffected::path(self : DocxFormatAffected) -> String {
  self.path
}

///|
/// The projection the paragraph must still read after the edit.
pub fn DocxFormatAffected::expected(self : DocxFormatAffected) -> String {
  self.expected
}

///|
/// The paragraph's canonical anchor paraId, when it carries one.
pub fn DocxFormatAffected::para_id(self : DocxFormatAffected) -> String? {
  self.para_id
}

///|
/// The paragraph's anchor status.
pub fn DocxFormatAffected::anchor_status(self : DocxFormatAffected) -> String {
  self.anchor_status
}

///|
/// How many of the paragraph's runs the plan rewrites.
pub fn DocxFormatAffected::runs_changed(self : DocxFormatAffected) -> Int {
  self.runs_changed
}

///|
/// How many of the paragraph's touched runs already held the request.
pub fn DocxFormatAffected::runs_already_satisfied(
  self : DocxFormatAffected,
) -> Int {
  self.runs_already_satisfied
}

///|
/// How many of the paragraph's runs the plan clone-splits.
pub fn DocxFormatAffected::splits(self : DocxFormatAffected) -> Int {
  self.splits
}

///|
/// What a planned formatting batch will do.
pub struct DocxFormatReceipt {
  mode : String
  selected : Array[Int]
  spans : Array[DocxFormatSpan]
  affected : Array[DocxFormatAffected]
  runs_changed : Int
  runs_already_satisfied : Int
  splits : Int
  byte_edits : Int
}

///|
/// `text` or `range` — which selector produced the spans.
pub fn DocxFormatReceipt::mode(self : DocxFormatReceipt) -> String {
  self.mode
}

///|
/// The candidate ordinals this plan formats, in document order. Empty
/// in range mode, which addresses coordinates rather than candidates.
pub fn DocxFormatReceipt::selected(self : DocxFormatReceipt) -> Array[Int] {
  self.selected.copy()
}

///|
/// The selected spans.
pub fn DocxFormatReceipt::spans(
  self : DocxFormatReceipt,
) -> Array[DocxFormatSpan] {
  self.spans.copy()
}

///|
/// The affected paragraphs with their unchanged projections.
pub fn DocxFormatReceipt::affected(
  self : DocxFormatReceipt,
) -> Array[DocxFormatAffected] {
  self.affected.copy()
}

///|
/// How many runs the plan rewrites.
pub fn DocxFormatReceipt::runs_changed(self : DocxFormatReceipt) -> Int {
  self.runs_changed
}

///|
/// How many touched runs already held every requested property — the
/// no-op accounting a `changed=false` report rests on.
pub fn DocxFormatReceipt::runs_already_satisfied(
  self : DocxFormatReceipt,
) -> Int {
  self.runs_already_satisfied
}

///|
/// How many runs the plan clone-splits.
pub fn DocxFormatReceipt::splits(self : DocxFormatReceipt) -> Int {
  self.splits
}

///|
/// How many byte edits the plan carries. Zero means the document
/// already held the request everywhere it was asked.
pub fn DocxFormatReceipt::byte_edits(self : DocxFormatReceipt) -> Int {
  self.byte_edits
}

///|
/// Plan absolute direct formatting over spans of the body story.
///
/// Exactly one selector: `text` (find's literal enumeration, with
/// `within` restricting the subtree and `nth` selecting one candidate
/// by ordinal) or `range` (paragraph-local UTF-16 coordinates inside
/// the single paragraph `within` names). Selection happens BEFORE
/// formatting actionability, and any refusal aborts the whole batch —
/// formatting never silently skips what it selected.
///
/// `DocxMatch::actionable` is deliberately NOT consulted: it is the
/// identity-replacement verdict, and a span crossing a hyperlink
/// boundary is unreplaceable yet formattable. The formatting planner
/// raises its own refusals instead.
///
/// Zero candidates plans nothing and returns an empty receipt; whether
/// that is an error is the caller's policy, not this engine's fact.
///
/// The returned plan is pinned to the annotated read's retained bytes,
/// so applying it to any other snapshot refuses as stale.
pub fn plan_docx_format(
  annotated : DocxAnnotatedResult,
  story : DocxStoryPartSource,
  format~ : DocxDirectFormat,
  text? : String,
  within? : String,
  nth? : Int,
  range? : (Int, Int),
) -> (@splice.SplicePlan, DocxFormatReceipt) raise DocxError {
  let part = story.part()
  guard !(text is Some(_) && range is Some(_)) else {
    raise Unsupported(
      message="format takes exactly one selector: a text needle or an explicit range",
    )
  }
  guard text is Some(_) || range is Some(_) else {
    raise Unsupported(
      message="format takes exactly one selector: a text needle or an explicit range",
    )
  }
  guard !(range is Some(_) && nth is Some(_)) else {
    raise Unsupported(
      message="nth selects among text candidates; an explicit range addresses one span already",
    )
  }
  guard annotated.reader_projections.get(part) is Some(projection) else {
    raise Unsupported(
      message="format requires a mutation-safe read with a retained projection for '\{part}'",
    )
  }
  guard annotated.reader_projection_sources.get(part) is Some(bytes) else {
    raise Unsupported(
      message="the mutation-safe read retained no source bytes for '\{part}'",
    )
  }
  let paragraph_paths = find_path_map(projection.scan, "p")
  let elements = projection.scan.elements()
  let index_by_path : Map[String, Int] = Map([])
  let path_by_index : Map[Int, String] = Map([])
  for paragraph_index, paragraph in projection.paragraphs {
    guard paragraph.sources.length() > 0 else { continue }
    let SourceElementId(head) = paragraph.sources[0].source
    if paragraph_paths.get(elements[head].byte_start) is Some(path) {
      index_by_path[path] = paragraph_index
      path_by_index[paragraph_index] = path
    }
  }
  // Selection.
  let mode = if range is Some(_) { "range" } else { "text" }
  let ordinals : Array[Int] = []
  let spans : Array[DocxFormatSpan] = []
  match range {
    Some((start, end)) => {
      guard within is Some(scope) else {
        raise Unsupported(
          message="an explicit range needs the paragraph it addresses (--in)",
        )
      }
      guard index_by_path.get(scope) is Some(paragraph_index) else {
        raise Unsupported(
          message="the scope '\{scope}' does not name a paragraph of this story",
        )
      }
      let paragraph = projection.paragraphs[paragraph_index]
      let projected = find_paragraph_projection(paragraph)
      guard start >= 0 && start < end && end <= projected.length() else {
        raise Unsupported(
          message="the range \{start}:\{end} is outside the paragraph's \{projected.length()} unit(s)",
        )
      }
      let anchors = docx_paragraph_anchor_index(annotated, story)
      let judgment = anchors.anchor_of_paragraph(paragraph_index)
      spans.push({
        path: scope,
        para_id: match judgment {
          Some(found) => found.para_id()
          None => None
        },
        anchor_status: match judgment {
          Some(found) => found.status()
          None => "missing"
        },
        start,
        end,
        text: find_slice(projected, start, end),
        source_runs: docx_format_source_runs(
          projection, paragraph_index, start, end, scope,
        ),
      })
    }
    None => {
      guard text is Some(needle) else {
        raise Unsupported(message="format needs a text needle")
      }
      let found = find_docx_matches(
        annotated,
        story,
        needle~,
        within?,
        limit=1000,
      )
      if found.truncated() {
        raise Unsupported(
          message="\{found.total()} candidates for the needle exceed the 1000-candidate ceiling; narrow the scope with a subtree restriction or a longer needle",
        )
      }
      let matches = found.matches()
      let selected : Array[DocxMatch] = []
      match nth {
        Some(ordinal) => {
          guard ordinal >= 1 && ordinal <= matches.length() else {
            raise Unsupported(
              message="nth selects candidate \{ordinal}, but the document has \{matches.length()} candidate(s)",
            )
          }
          selected.push(matches[ordinal - 1])
        }
        None =>
          for hit in matches {
            selected.push(hit)
          }
      }
      for hit in selected {
        ordinals.push(hit.ordinal())
        spans.push({
          path: hit.path(),
          para_id: hit.para_id(),
          anchor_status: hit.anchor_status(),
          start: hit.start(),
          end: hit.end(),
          text: hit.text(),
          source_runs: hit.runs(),
        })
      }
    }
  }
  // One batch per paragraph, in document order: the formatting planner
  // validates the batch as a whole — ordering, overlap, and every
  // structural gate — which is the point of batching.
  let plan = @splice.SplicePlan::new()
  plan.pin_part(part, bytes)
  let affected : Array[DocxFormatAffected] = []
  let mut runs_changed = 0
  let mut runs_already_satisfied = 0
  let mut splits = 0
  let mut byte_edits = 0
  let mut cursor = 0
  while cursor < spans.length() {
    let path = spans[cursor].path
    let mut stop = cursor
    while stop < spans.length() && spans[stop].path == path {
      stop = stop + 1
    }
    guard index_by_path.get(path) is Some(paragraph_index) else {
      raise Unsupported(
        message="selected paragraph '\{path}' did not resolve to a projection paragraph",
      )
    }
    let requested : Array[ParagraphFormatSpan] = []
    for at in cursor..<stop {
      requested.push({ start: spans[at].start, end: spans[at].end, })
    }
    let (edits, receipt) = plan_paragraph_format_edits(
      projection, bytes, paragraph_index, requested, format,
    )
    for edit in edits {
      plan.edit_part(
        part,
        @splice.span_edit(
          start=edit.byte_start,
          end=edit.byte_end,
          @utf8.encode(edit.replacement),
        ),
      )
    }
    byte_edits = byte_edits + edits.length()
    runs_changed = runs_changed + receipt.runs_changed
    runs_already_satisfied = runs_already_satisfied +
      receipt.runs_already_satisfied
    splits = splits + receipt.splits
    affected.push({
      path,
      expected: receipt.expected_projection,
      para_id: spans[cursor].para_id,
      anchor_status: spans[cursor].anchor_status,
      runs_changed: receipt.runs_changed,
      runs_already_satisfied: receipt.runs_already_satisfied,
      splits: receipt.splits,
    })
    cursor = stop
  }
  (
    plan,
    {
      mode,
      selected: ordinals,
      spans,
      affected,
      runs_changed,
      runs_already_satisfied,
      splits,
      byte_edits,
    },
  )
}

///|
/// The runs a span draws from, by body-relative path — the snapshot the
/// receipt reports, taken BEFORE any split changes what runs exist.
fn docx_format_source_runs(
  projection : ReaderProjection,
  paragraph_index : Int,
  start : Int,
  end : Int,
  paragraph_path : String,
) -> Array[String] {
  let run_paths = find_path_map(projection.scan, "r")
  let elements = projection.scan.elements()
  let paragraph = projection.paragraphs[paragraph_index]
  let base = paragraph.projection_start
  let out : Array[String] = []
  for contribution in paragraph.contributions {
    guard contribution.kind is ProjectedText(_) else { continue }
    let local_start = contribution.projection_start - base
    let local_end = contribution.projection_end - base
    guard local_start < end && local_end > start else { continue }
    guard contribution.run_source is Some(SourceElementId(run_identity)) else {
      continue
    }
    let path = match run_paths.get(elements[run_identity].byte_start) {
      Some(found) => found
      None => paragraph_path
    }
    if !out.contains(path) {
      out.push(path)
    }
  }
  out
}

///|
/// The readback's direct-format judgment: does every run whose
/// projected text lies inside `[start, end)` of paragraph `path` carry
/// every requested property EXPLICITLY?
///
/// This is the check the projection cannot make — the projection is
/// unchanged by formatting, so only the runs themselves can say whether
/// the edit landed. Returns None when satisfied, or the first
/// discrepancy's description. `None` for a missing paragraph is not
/// possible: an unresolvable path is itself a discrepancy.
pub fn docx_paragraph_direct_format(
  annotated : DocxAnnotatedResult,
  story : DocxStoryPartSource,
  path~ : String,
  start~ : Int,
  end~ : Int,
  format~ : DocxDirectFormat,
) -> String? raise DocxError {
  let part = story.part()
  guard annotated.reader_projections.get(part) is Some(projection) else {
    return Some("the re-read retained no projection for '\{part}'")
  }
  guard annotated.reader_projection_sources.get(part) is Some(bytes) else {
    return Some("the re-read retained no source bytes for '\{part}'")
  }
  let paragraph_paths = find_path_map(projection.scan, "p")
  let elements = projection.scan.elements()
  let mut target = -1
  for paragraph_index, paragraph in projection.paragraphs {
    guard paragraph.sources.length() > 0 else { continue }
    let SourceElementId(head) = paragraph.sources[0].source
    if paragraph_paths.get(elements[head].byte_start) == Some(path) {
      target = paragraph_index
    }
  }
  guard target >= 0 else {
    return Some("the path '\{path}' names no paragraph after the edit")
  }
  let paragraph = projection.paragraphs[target]
  let base = paragraph.projection_start
  // Every run holding selected text must carry the properties; a run
  // whose text lies only OUTSIDE the span is none of this check's
  // business.
  let judged : Array[Int] = []
  for run in paragraph.runs {
    let SourceElementId(run_identity) = run.source
    let mut holds_selected = false
    for contribution in paragraph.contributions {
      guard contribution.kind is ProjectedText(_) else { continue }
      guard contribution.run_source == Some(run.source) else { continue }
      let local_start = contribution.projection_start - base
      let local_end = contribution.projection_end - base
      if local_start < end && local_end > start && local_end > local_start {
        holds_selected = true
      }
    }
    guard holds_selected else { continue }
    guard !judged.contains(run_identity) else { continue }
    judged.push(run_identity)
    let run_element = elements[run_identity]
    let (prefix, extension_prefixes) = format_surgery_run_binding(
      bytes,
      elements,
      run_element,
      "readback of '\{path}'",
    )
    let slice = bytes[run_element.byte_start:run_element.byte_end]
    // A refusal during readback is itself a discrepancy: the run can no
    // longer be judged, which is exactly what a readback must catch.
    let verdict = verify_run_format(
      slice,
      prefix~,
      extension_prefixes~,
      format~,
    ) catch {
      Unsupported(message~) => Some(message)
      error => raise error
    }
    if verdict is Some(discrepancy) {
      return Some(discrepancy)
    }
  }
  if judged.length() == 0 {
    return Some(
      "the range \{start}:\{end} of '\{path}' holds no run after the edit",
    )
  }
  None
}
