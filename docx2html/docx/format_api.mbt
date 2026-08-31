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
  requested_text : String?
  requested_within : String?
  requested_nth : Int?
  requested_range : (Int, Int)?
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
/// The needle the caller asked for, in text mode.
pub fn DocxFormatReceipt::requested_text(self : DocxFormatReceipt) -> String? {
  self.requested_text
}

///|
/// The subtree the caller restricted to, if any — and in range mode,
/// the paragraph it addressed.
pub fn DocxFormatReceipt::requested_within(self : DocxFormatReceipt) -> String? {
  self.requested_within
}

///|
/// The ordinal the caller selected, if any. `None` with one span means
/// "all candidates, and there was one" — a distinction a count alone
/// cannot make.
pub fn DocxFormatReceipt::requested_nth(self : DocxFormatReceipt) -> Int? {
  self.requested_nth
}

///|
/// The explicit range the caller addressed, in range mode.
pub fn DocxFormatReceipt::requested_range(
  self : DocxFormatReceipt,
) -> (Int, Int)? {
  self.requested_range
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
  // v1 is BODY-ONLY in both selector modes. Text mode inherits find's
  // own check, but range mode reaches the projection directly, and a
  // header or footnote formatted through it would carry body
  // addressing metadata that is false.
  guard part == annotated.main_story_source().part() else {
    raise Unsupported(
      message="format edits the body story only in v1; '\{part}' is not the main document part",
    )
  }
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
  // Paths are NOT unique: a tolerated nested paragraph makes two
  // logical paragraphs share one physical head, hence one path. A
  // last-wins map would format one paragraph while the receipt
  // described the other, so collided paths are counted and refused
  // rather than answered for.
  let index_by_path : Map[String, Int] = Map([])
  let claimants : Map[String, Int] = Map([])
  for paragraph_index, paragraph in projection.paragraphs {
    guard paragraph.sources.length() > 0 else { continue }
    let SourceElementId(head) = paragraph.sources[0].source
    if paragraph_paths.get(elements[head].byte_start) is Some(path) {
      claimants[path] = match claimants.get(path) {
        Some(seen) => seen + 1
        None => 1
      }
      if claimants.get(path) == Some(1) {
        index_by_path[path] = paragraph_index
      }
    }
  }
  fn resolve_paragraph(path : String) -> Int raise DocxError {
    guard claimants.get(path) is Some(count) else {
      raise Unsupported(
        message="the paragraph '\{path}' did not resolve to a projection paragraph",
      )
    }
    guard count == 1 else {
      raise Unsupported(
        message="the path '\{path}' names \{count} logical paragraphs (a tolerated nested paragraph shares its head); formatting refuses an ambiguous address",
      )
    }
    guard index_by_path.get(path) is Some(paragraph_index) else {
      raise Unsupported(
        message="the paragraph '\{path}' did not resolve to a projection paragraph",
      )
    }
    paragraph_index
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
      guard claimants.get(scope) is Some(_) else {
        raise Unsupported(
          message="the scope '\{scope}' does not name a paragraph of this story",
        )
      }
      let paragraph_index = resolve_paragraph(scope)
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
    let paragraph_index = resolve_paragraph(path)
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
      requested_text: text,
      requested_within: within,
      requested_nth: nth,
      requested_range: range,
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
  let seen : Map[String, Bool] = Map([])
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
    if seen.get(path) is None {
      seen[path] = true
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
  let mut found = 0
  for paragraph_index, paragraph in projection.paragraphs {
    guard paragraph.sources.length() > 0 else { continue }
    let SourceElementId(head) = paragraph.sources[0].source
    if paragraph_paths.get(elements[head].byte_start) == Some(path) {
      found = found + 1
      if found == 1 {
        target = paragraph_index
      }
    }
  }
  guard target >= 0 else {
    return Some("the path '\{path}' names no paragraph after the edit")
  }
  // A collided path cannot be answered for: the planner refuses these,
  // so seeing one at readback means the document changed shape under
  // the edit.
  guard found == 1 else {
    return Some(
      "the path '\{path}' names \{found} logical paragraphs after the edit",
    )
  }
  let paragraph = projection.paragraphs[target]
  let base = paragraph.projection_start
  // EVERY selected unit must belong to a run: text the tolerant reader
  // admits directly under the paragraph has no run to carry direct
  // formatting, so a range covering it can never be satisfied — and
  // judging only the runs that happen to exist would call that a pass.
  // Index the units a run carries ONCE: scanning every contribution
  // per unit is quadratic, and a paragraph of many small runs is legal.
  let width = paragraph.projection_end - base
  let carrier : Array[Int] = []
  for _ in 0..<width {
    carrier.push(-1)
  }
  for contribution in paragraph.contributions {
    guard contribution.kind is ProjectedText(_) else { continue }
    guard contribution.run_source is Some(SourceElementId(run_identity)) else {
      continue
    }
    let from = contribution.projection_start - base
    let to = contribution.projection_end - base
    for unit in from..<to {
      if unit >= 0 && unit < width {
        carrier[unit] = run_identity
      }
    }
  }
  for unit in start..<end {
    guard unit >= 0 && unit < width && carrier[unit] >= 0 else {
      return Some(
        "unit \{unit} of '\{path}' is not carried by any run, so it cannot hold direct formatting",
      )
    }
  }
  // Every run holding selected text must carry the properties; a run
  // whose text lies only OUTSIDE the span is none of this check's
  // business.
  let judged : Map[Int, Bool] = Map([])
  let mut judged_count = 0
  for unit in start..<end {
    guard unit >= 0 && unit < width else { continue }
    let run_identity = carrier[unit]
    guard run_identity >= 0 else { continue }
    guard judged.get(run_identity) is None else { continue }
    judged[run_identity] = true
    judged_count = judged_count + 1
    let run_element = elements[run_identity]
    let binding = format_surgery_run_binding(
      bytes,
      elements,
      run_element,
      "readback of '\{path}'",
    ) catch {
      Unsupported(message~) => return Some(message)
      error => raise error
    }
    let (prefix, extension_prefixes) = binding
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
  if judged_count == 0 {
    return Some(
      "the range \{start}:\{end} of '\{path}' holds no run after the edit",
    )
  }
  None
}

///|
/// The readback's PRESERVATION judgment: did formatting stay inside the
/// spans it was asked for?
///
/// The positive check cannot answer this. A run outside the union may
/// have carried the property all along, so presence proves nothing —
/// provenance does. The comparison is made PER PROJECTION UNIT rather
/// than per run: splitting changes which runs exist and how their
/// contributions are grouped, but it must never change which properties
/// apply to a given character. Every unit outside the requested spans
/// must therefore carry exactly the run properties it carried before,
/// and the runs that project no text at all (a note reference alone in
/// its run) must keep theirs too, compared in document order.
///
/// `spans` are the paragraph-local ranges the plan was asked to format.
/// Returns None when preserved, or the first discrepancy.
pub fn docx_paragraph_format_preserved(
  before : DocxAnnotatedResult,
  before_story : DocxStoryPartSource,
  after : DocxAnnotatedResult,
  after_story : DocxStoryPartSource,
  path~ : String,
  spans~ : Array[(Int, Int)],
  format~ : DocxDirectFormat,
) -> String? raise DocxError {
  // Inside a span only the REQUESTED properties may differ: an
  // omitted property means untouched, so a plan that dropped an
  // unrelated one while setting bold must be caught even though the
  // positive check passes and the projection is unchanged.
  let touched = docx_format_touched_properties(format)
  guard docx_format_paragraph_provenance(before, before_story, path~)
    is Some((original_units, original_silent, original_mark)) else {
    return Some("the path '\{path}' names no single paragraph before the edit")
  }
  guard docx_format_paragraph_provenance(after, after_story, path~)
    is Some((result_units, result_silent, result_mark)) else {
    return Some("the path '\{path}' names no single paragraph after the edit")
  }
  guard original_mark == result_mark else {
    return Some(
      "the paragraph mark of '\{path}' changed its formatting, though no span selected it",
    )
  }
  guard original_units.length() == result_units.length() else {
    return Some(
      "'\{path}' projected \{original_units.length()} unit(s) before the edit and \{result_units.length()} after",
    )
  }
  for unit in 0..<original_units.length() {
    let mut selected = false
    for span in spans {
      let (from, to) = span
      if from <= unit && unit < to {
        selected = true
      }
    }
    if selected {
      // The properties the request does NOT name must survive.
      guard docx_format_without(original_units[unit], touched) ==
        docx_format_without(result_units[unit], touched) else {
        return Some(
          "unit \{unit} of '\{path}' lost or gained a run property the request never named",
        )
      }
      continue
    }
    guard original_units[unit] == result_units[unit] else {
      return Some(
        "unit \{unit} of '\{path}' lies outside every requested span but its run properties changed",
      )
    }
  }
  guard original_silent.length() == result_silent.length() else {
    return Some(
      "'\{path}' carried \{original_silent.length()} text-less run(s) before the edit and \{result_silent.length()} after",
    )
  }
  for index in 0..<original_silent.length() {
    guard original_silent[index] == result_silent[index] else {
      return Some(
        "a text-less run of '\{path}' changed its run properties, though no span selected it",
      )
    }
  }
  None
}

///|
/// One paragraph's provenance: the run properties that apply to each
/// projection unit, and the properties of the runs that project no text,
/// in document order. `None` when the path names no paragraph, or names
/// more than one (a collided path cannot be answered for).
fn docx_format_paragraph_provenance(
  annotated : DocxAnnotatedResult,
  story : DocxStoryPartSource,
  path~ : String,
) -> (Array[String], Array[String], String)? raise DocxError {
  let part = story.part()
  guard annotated.reader_projections.get(part) is Some(projection) else {
    return None
  }
  guard annotated.reader_projection_sources.get(part) is Some(bytes) else {
    return None
  }
  let paragraph_paths = find_path_map(projection.scan, "p")
  let elements = projection.scan.elements()
  let mut target = -1
  let mut found = 0
  for paragraph_index, paragraph in projection.paragraphs {
    guard paragraph.sources.length() > 0 else { continue }
    let SourceElementId(head) = paragraph.sources[0].source
    if paragraph_paths.get(elements[head].byte_start) == Some(path) {
      found = found + 1
      if found == 1 {
        target = paragraph_index
      }
    }
  }
  guard target >= 0 && found == 1 else { return None }
  let paragraph = projection.paragraphs[target]
  let base = paragraph.projection_start
  let width = paragraph.projection_end - base
  let units : Array[String] = []
  for _ in 0..<width {
    // A unit no run claims — text the tolerant reader admits directly
    // under the paragraph — has no properties to preserve, and says so.
    units.push("")
  }
  for contribution in paragraph.contributions {
    guard contribution.kind is ProjectedText(_) else { continue }
    guard contribution.run_source is Some(run_source) else { continue }
    let SourceElementId(run_identity) = run_source
    let properties = docx_format_run_properties(
      bytes,
      elements,
      elements[run_identity],
    )
    let from = contribution.projection_start - base
    let to = contribution.projection_end - base
    for unit in from..<to {
      if unit >= 0 && unit < width {
        units[unit] = properties
      }
    }
  }
  // Which runs project text, indexed once: scanning every contribution
  // per run is quadratic, and a paragraph of many small runs is legal.
  let projecting : Map[Int, Bool] = Map([])
  for contribution in paragraph.contributions {
    guard contribution.kind is ProjectedText(_) else { continue }
    guard contribution.projection_end > contribution.projection_start else {
      continue
    }
    guard contribution.run_source is Some(SourceElementId(identity)) else {
      continue
    }
    projecting[identity] = true
  }
  // Runs that project no text: a note reference alone in its run still
  // paints, and formatting it would be collateral no span asked for.
  let silent : Array[String] = []
  for run in paragraph.runs {
    let SourceElementId(run_projection_identity) = run.source
    let projects = projecting.get(run_projection_identity) == Some(true)
    guard !projects else { continue }
    let SourceElementId(run_identity) = run.source
    // A run holding only properties and EMPTY text elements paints
    // nothing, and splitting legitimately creates one when a run began
    // with an empty `w:t`. Only a run carrying something else — a note
    // reference, a drawable — is collateral worth comparing.
    let mut paints = false
    let mut child = elements[run_identity].first_child_index
    while child >= 0 {
      let entry = elements[child]
      let is_properties = is_wml_uri(entry.uri) && entry.local_name == "rPr"
      let is_text = is_wml_uri(entry.uri) && entry.local_name == "t"
      if !is_properties && !is_text {
        paints = true
      }
      child = entry.next_sibling_index
    }
    guard paints else { continue }
    silent.push(
      docx_format_run_properties(bytes, elements, elements[run_identity]),
    )
  }
  // The paragraph MARK carries direct formatting of its own, in
  // `w:pPr/w:rPr`. It projects nothing, so no unit or run speaks for
  // it — and no format request in v1 touches it, which makes any
  // change to it collateral.
  let SourceElementId(paragraph_head) = paragraph.sources[0].source
  // EVERY direct pPr in document order: the reader takes the first,
  // the planner refuses none, and a change to any of them is
  // collateral — so a later empty one must not erase an earlier
  // mark's formatting from the comparison.
  let mark_builder = StringBuilder()
  let mut paragraph_child = elements[paragraph_head].first_child_index
  while paragraph_child >= 0 {
    let entry = elements[paragraph_child]
    if is_wml_uri(entry.uri) && entry.local_name == "pPr" {
      mark_builder.write_string("|")
      mark_builder.write_string(
        docx_format_run_properties(bytes, elements, entry),
      )
    }
    paragraph_child = entry.next_sibling_index
  }
  let mark = mark_builder.to_string()
  Some((units, silent, mark))
}

///|
/// A run's properties as spelled: EVERY direct `rPr` child's bytes,
/// joined. Duplicates are a refusal at planning time, but a readback
/// must still see a change in any one of them rather than the last.
fn docx_format_run_properties(
  bytes : BytesView,
  elements : Array[ScannedElement],
  run_element : ScannedElement,
) -> String raise DocxError {
  let builder = StringBuilder()
  let mut child = run_element.first_child_index
  while child >= 0 {
    let entry = elements[child]
    if is_wml_uri(entry.uri) && entry.local_name == "rPr" {
      builder.write_string(
        format_surgery_decode(bytes[entry.byte_start:entry.byte_end]),
      )
    }
    child = entry.next_sibling_index
  }
  builder.to_string()
}

///|
/// The rPr child names a request touches — the ONLY ones that may
/// differ inside a selected span.
fn docx_format_touched_properties(format : DocxDirectFormat) -> Array[String] {
  let touched : Array[String] = []
  if format.bold() is Some(_) {
    touched.push("b")
    touched.push("bCs")
  }
  if format.italic() is Some(_) {
    touched.push("i")
    touched.push("iCs")
  }
  if format.underline() is Some(_) {
    touched.push("u")
  }
  if format.color() is Some(_) {
    touched.push("color")
  }
  touched
}

///|
/// One run's properties with the touched ones removed, as a comparable
/// string: the `rPr` shell and every child the request does NOT name
/// survive verbatim, so a difference anywhere else is still a
/// difference.
fn docx_format_without(
  properties : String,
  touched : Array[String],
) -> String raise DocxError {
  guard properties != "" else { return "" }
  let bytes = @utf8.encode(properties)
  docx_format_filter_region(bytes, 0, bytes.length(), touched)
}

///|
/// Filter one region: text survives, an `rPr` shell is descended into,
/// and any other element is dropped exactly when the request names it.
fn docx_format_filter_region(
  bytes : BytesView,
  from : Int,
  to : Int,
  touched : Array[String],
) -> String raise DocxError {
  let builder = StringBuilder()
  let mut at = from
  while at < to {
    if bytes[at] != b'<' {
      builder.write_string(format_surgery_decode(bytes[at:at + 1]))
      at += 1
      continue
    }
    let name_start = at + 1
    let mut name_end = name_start
    while name_end < to &&
          bytes[name_end] != b'>' &&
          bytes[name_end] != b'/' &&
          !is_xml_ws(bytes[name_end]) {
      name_end += 1
    }
    let qname = format_surgery_decode(bytes[name_start:name_end])
    let (_, property_name) = split_qname(qname)
    // The open tag ends at the first '>' outside a quoted value.
    let mut cursor = name_end
    let mut quote = b'\x00'
    while cursor < to {
      let byte = bytes[cursor]
      if quote != b'\x00' {
        if byte == quote {
          quote = b'\x00'
        }
      } else if byte == b'"' || byte == b'\'' {
        quote = byte
      } else if byte == b'>' {
        break
      }
      cursor += 1
    }
    guard cursor < to else {
      // Unparseable: keep the remainder verbatim rather than lose it.
      builder.write_string(format_surgery_decode(bytes[at:to]))
      return builder.to_string()
    }
    let open_end = cursor + 1
    let self_closing = bytes[cursor - 1] == b'/'
    if self_closing {
      if property_name == "rPr" {
        // `<w:rPr/>` and an rPr the filter empties say the same thing;
        // only its ATTRIBUTES distinguish it from no rPr at all.
        builder.write_string(docx_format_shell(bytes, name_end, cursor - 1, ""))
      } else if touched.contains(property_name) {
        builder.write_string(
          docx_format_touched_residue(
            bytes,
            qname,
            property_name,
            name_end,
            cursor - 1,
          ),
        )
      } else {
        builder.write_string(format_surgery_decode(bytes[at:open_end]))
      }
      at = open_end
      continue
    }
    // Paired element: find its matching close tag by depth over its own
    // qualified name.
    let close_marker = "</\{qname}"
    let open_marker = "<\{qname}"
    let mut depth = 1
    let mut probe = open_end
    let mut content_end = -1
    while probe < to {
      if bytes[probe] == b'<' {
        // A close tag may carry whitespace before its '>', and a
        // LONGER name that merely starts with this one is a different
        // element.
        if docx_format_matches_at(bytes, probe, close_marker) &&
          docx_format_name_ends_at(bytes, probe + close_marker.length(), to) {
          depth -= 1
          if depth == 0 {
            content_end = probe
            break
          }
        } else if docx_format_matches_at(bytes, probe, open_marker) &&
          docx_format_name_ends_at(bytes, probe + open_marker.length(), to) {
          depth += 1
        }
      }
      probe += 1
    }
    guard content_end >= 0 else {
      builder.write_string(format_surgery_decode(bytes[at:to]))
      return builder.to_string()
    }
    // The close tag runs to its own '>', whitespace included.
    let mut close_cursor = content_end + close_marker.length()
    while close_cursor < to && bytes[close_cursor] != b'>' {
      close_cursor += 1
    }
    let element_end = close_cursor + 1
    if property_name == "rPr" {
      // An rPr holding nothing but touched properties says the same as
      // no rPr at all — otherwise a run that GAINED its first property
      // would read as a change to properties nobody named. Its
      // ATTRIBUTES are not part of that equivalence: they survive, so
      // an unrelated change to them is still a change.
      let remaining = docx_format_filter_region(
        bytes, open_end, content_end, touched,
      )
      builder.write_string(
        docx_format_shell(
          bytes,
          name_end,
          open_end - 1,
          remaining.trim(chars=" \t\n\r").to_owned(),
        ),
      )
    } else if touched.contains(property_name) {
      // A property the request names may change the attributes the
      // request AUTHORIZES and nothing else; its other attributes and
      // any content are compared exactly.
      builder.write_string(
        docx_format_touched_residue(
          bytes,
          qname,
          property_name,
          name_end,
          open_end - 1,
        ),
      )
      builder.write_string(
        docx_format_filter_region(bytes, open_end, content_end, touched),
      )
    } else {
      builder.write_string(format_surgery_decode(bytes[at:element_end]))
    }
    at = element_end
  }
  builder.to_string()
}

///|
fn docx_format_matches_at(bytes : BytesView, at : Int, needle : String) -> Bool {
  let units = needle.code_units()
  if at + units.length() > bytes.length() {
    return false
  }
  for index in 0..<units.length() {
    if bytes[at + index].to_int() != units[index].to_int() {
      return false
    }
  }
  true
}

///|
/// A canonical `rPr` shell: its attributes as spelled, with the
/// surviving children between. An attribute-less shell holding nothing
/// renders as "", so an absent rPr, a self-closing one, and one the
/// filter emptied all compare equal — while an attribute keeps the
/// shell visible, because a change to one is a change nobody named.
fn docx_format_shell(
  bytes : BytesView,
  attributes_from : Int,
  attributes_to : Int,
  children : String,
) -> String raise DocxError {
  let attributes = if attributes_to > attributes_from {
    format_surgery_decode(bytes[attributes_from:attributes_to])
    .trim(chars=" \t\n\r")
    .to_owned()
  } else {
    ""
  }
  if attributes == "" && children == "" {
    return ""
  }
  "<rPr \{attributes}>\{children}</rPr>"
}

///|
/// Whether a name ends at this offset — the next byte may not continue
/// an XML name, so `<w:rPrChange` never counts as `<w:rPr`.
fn docx_format_name_ends_at(bytes : BytesView, at : Int, to : Int) -> Bool {
  if at >= to {
    return true
  }
  let byte = bytes[at]
  !((byte >= b'a' && byte <= b'z') ||
  (byte >= b'A' && byte <= b'Z') ||
  (byte >= b'0' && byte <= b'9') ||
  byte == b'_' ||
  byte == b'-' ||
  byte == b'.' ||
  byte == b':')
}

///|
/// What survives of a property the request NAMES: its attributes other
/// than the ones the request authorizes it to change. An element left
/// with none says the same as an absent one, so adding a property is
/// not mistaken for changing something nobody named — while a `w:u`
/// keeping its colour, or a `w:color` keeping an unrelated attribute,
/// still compares exactly.
fn docx_format_touched_residue(
  bytes : BytesView,
  qname : String,
  property_name : String,
  from : Int,
  to : Int,
) -> String raise DocxError {
  // The attributes a request may rewrite: an on/off or underline
  // property owns its `val`; an absolute colour additionally drops the
  // theme linkage that would contradict it.
  let authorized = if property_name == "color" {
    ["val", "themeColor", "themeTint", "themeShade"]
  } else {
    ["val"]
  }
  let kept = StringBuilder()
  let mut at = from
  while at < to {
    if is_xml_ws(bytes[at]) {
      at += 1
      continue
    }
    if bytes[at] == b'/' {
      at += 1
      continue
    }
    let name_start = at
    while at < to && bytes[at] != b'=' && !is_xml_ws(bytes[at]) {
      at += 1
    }
    let attribute = format_surgery_decode(bytes[name_start:at])
    while at < to && bytes[at] != b'"' && bytes[at] != b'\'' {
      at += 1
    }
    guard at < to else { break }
    let quote = bytes[at]
    at += 1
    let value_start = at
    while at < to && bytes[at] != quote {
      at += 1
    }
    let value = format_surgery_decode(bytes[value_start:at])
    at += 1
    let (_, attribute_local) = split_qname(attribute)
    if !authorized.contains(attribute_local) {
      kept.write_string(" \{attribute}=\"\{value}\"")
    }
  }
  let residue = kept.to_string()
  if residue == "" {
    ""
  } else {
    "<\{qname}\{residue}>"
  }
}
