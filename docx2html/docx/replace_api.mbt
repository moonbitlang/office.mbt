// The literal find-and-replace planner (N2b). One match model: this
// consumes `find_docx_matches`' own enumeration, so what replace acts on
// is EXACTLY what find reported — same ordinals, same verdicts. A
// separate matcher here would eventually disagree with find, and an
// agent that previews with find must never be surprised by replace.

///|
/// What a planned replacement will do, and what the document must read
/// afterwards.
pub struct DocxReplaceReceipt {
  selected : Array[Int]
  replaced : Int
  affected : Array[DocxReplaceAffected]
  matches : Array[DocxMatch]
}

///|
/// One affected paragraph: its path, and the full projection text it
/// must carry after the splice.
///
/// The expectation is the WHOLE paragraph projection, precomputed at
/// plan time — never a substring probe, because the replacement text may
/// pre-exist elsewhere in the same paragraph and a substring check would
/// pass on a splice that landed in the wrong place.
pub struct DocxReplaceAffected {
  path : String
  expected : String
  // The paragraph's anchor judgment, copied from its selected matches
  // (same paragraph, same judgment). A planned paragraph is never
  // `multi_physical` — the planner refuses those — but it can carry a
  // duplicate or missing anchor and still be ordinal-editable.
  para_id : String?
  anchor_status : String
}

///|
/// The selected candidates themselves — the same entries `find` would
/// report, so a dry-run can print the matches payload the roadmap
/// promises rather than a summary that hides ranges and runs.
pub fn DocxReplaceReceipt::matches(
  self : DocxReplaceReceipt,
) -> Array[DocxMatch] {
  self.matches
}

///|
/// The candidate ordinals this plan replaces, in document order.
pub fn DocxReplaceReceipt::selected(self : DocxReplaceReceipt) -> Array[Int] {
  self.selected
}

///|
/// How many replacements the plan performs.
pub fn DocxReplaceReceipt::replaced(self : DocxReplaceReceipt) -> Int {
  self.replaced
}

///|
/// The affected paragraphs with their expected post-edit projections.
pub fn DocxReplaceReceipt::affected(
  self : DocxReplaceReceipt,
) -> Array[DocxReplaceAffected] {
  self.affected
}

///|
/// The paragraph's body-relative path.
pub fn DocxReplaceAffected::path(self : DocxReplaceAffected) -> String {
  self.path
}

///|
/// The paragraph's canonical anchor paraId, when the source carries one
/// (the anchor judgment copied from its selected matches).
pub fn DocxReplaceAffected::para_id(self : DocxReplaceAffected) -> String? {
  self.para_id
}

///|
/// The paragraph's anchor status (`unique`, `missing`, `invalid`,
/// `duplicate`), copied from its selected matches. Never
/// `multi_physical`: the planner refuses those.
pub fn DocxReplaceAffected::anchor_status(self : DocxReplaceAffected) -> String {
  self.anchor_status
}

///|
/// The full projection text the paragraph must read after the edit.
pub fn DocxReplaceAffected::expected(self : DocxReplaceAffected) -> String {
  self.expected
}

///|
/// Plan replacing `needle` with `replacement` in the body story.
///
/// The locked selection semantics, verbatim from the roadmap:
///
/// - Ordinals run over ALL candidates in document order, including
///   restricted ones — the same ordinals `find` reports.
/// - `nth` selects ONE candidate by that ordinal, BEFORE actionability
///   is considered; selecting a restricted candidate is a refusal that
///   names its reason, not a skip.
/// - Without `nth`, every candidate is selected, and ANY restricted
///   candidate in scope refuses — replace never silently skips what
///   find reports.
///
/// Zero candidates plans nothing and returns an empty receipt; whether
/// that is an error belongs to the caller (`--allow-zero` is CLI
/// policy, not engine fact).
///
/// The returned plan is pinned to the annotated read's retained bytes,
/// so applying it to any other snapshot refuses as stale.
pub fn plan_docx_replacements(
  annotated : DocxAnnotatedResult,
  story : DocxStoryPartSource,
  needle~ : String,
  replacement~ : String,
  within? : String,
  nth? : Int,
) -> (@splice.SplicePlan, DocxReplaceReceipt) raise DocxError {
  let part = story.part()
  // The SAME enumeration find shows the caller. The examination ceiling
  // is find's hard limit; a document with more candidates in scope is
  // refused with advice rather than acted on partially, because "I
  // replaced some of them" is exactly the silent-skip this surface
  // promises never to do.
  let found = find_docx_matches(annotated, story, needle~, within?, limit=1000)
  if found.truncated() {
    raise Unsupported(
      message="\{found.total()} candidates for the needle exceed the 1000-candidate ceiling; narrow the scope with a subtree restriction or a longer needle",
    )
  }
  let matches = found.matches()
  // Selection.
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
  // Actionability, AFTER selection: a restricted candidate refuses by
  // ordinal and reason. The first offender is named; the count says
  // whether narrowing to `nth` could help.
  let mut restricted = 0
  let mut first : DocxMatch? = None
  for hit in selected {
    if !hit.actionable() {
      restricted = restricted + 1
      if first is None {
        first = Some(hit)
      }
    }
  }
  if first is Some(offender) {
    raise Unsupported(
      message="candidate \{offender.ordinal()} at \{offender.path()} is not editable (\{offender.reason()}); \{restricted} of \{selected.length()} selected candidate(s) are restricted",
    )
  }
  guard annotated.reader_projections.get(part) is Some(projection) else {
    raise Unsupported(
      message="replace requires a mutation-safe read with a retained projection for '\{part}'",
    )
  }
  guard annotated.reader_projection_sources.get(part) is Some(bytes) else {
    raise Unsupported(
      message="the mutation-safe read retained no source bytes for '\{part}'",
    )
  }
  // Resolve each match's paragraph index through the scan paths — the
  // same identity find used to name it.
  let paragraph_paths = find_path_map(projection.scan, "p")
  let elements = projection.scan.elements()
  let index_by_path : Map[String, Int] = Map([])
  for paragraph_index, paragraph in projection.paragraphs {
    guard paragraph.sources.length() > 0 else { continue }
    let SourceElementId(head) = paragraph.sources[0].source
    if paragraph_paths.get(elements[head].byte_start) is Some(path) {
      index_by_path[path] = paragraph_index
    }
  }
  // One batch per paragraph, in document order: the partial planner
  // validates the batch as a whole (ordering, overlap, every structural
  // gate), which is the point of batching rather than planning one edit
  // at a time against a moving document.
  let plan = @splice.SplicePlan::new()
  plan.pin_part(part, bytes)
  let affected : Array[DocxReplaceAffected] = []
  let ordinals : Array[Int] = []
  let mut replaced = 0
  let mut cursor = 0
  while cursor < selected.length() {
    let path = selected[cursor].path()
    let mut stop = cursor
    while stop < selected.length() && selected[stop].path() == path {
      stop = stop + 1
    }
    guard index_by_path.get(path) is Some(paragraph_index) else {
      raise Unsupported(
        message="candidate paragraph '\{path}' did not resolve to a projection paragraph",
      )
    }
    let edits : Array[ParagraphTextEdit] = []
    for at in cursor..<stop {
      edits.push({
        start: selected[at].start(),
        end: selected[at].end(),
        replacement,
      })
      ordinals.push(selected[at].ordinal())
    }
    let (byte_edits, _) = plan_paragraph_text_edits(
      projection, bytes, paragraph_index, edits,
    )
    for edit in byte_edits {
      plan.edit_part(
        part,
        @splice.span_edit(
          start=edit.byte_start,
          end=edit.byte_end,
          @utf8.encode(edit.replacement),
        ),
      )
    }
    replaced = replaced + (stop - cursor)
    // The paragraph's post-edit projection, spliced right-to-left so
    // earlier offsets stay valid.
    let original = find_paragraph_projection(
      projection.paragraphs[paragraph_index],
    )
    let mut expected = original
    for back in 0..<(stop - cursor) {
      let hit = selected[stop - 1 - back]
      expected = find_slice(expected, 0, hit.start()) +
        replacement +
        find_slice(expected, hit.end(), expected.length())
    }
    affected.push({
      path,
      expected,
      para_id: selected[cursor].para_id(),
      anchor_status: selected[cursor].anchor_status(),
    })
    cursor = stop
  }
  (plan, { selected: ordinals, replaced, affected, matches: selected, })
}

///|
/// One paragraph's full projection text, by its body-relative path.
///
/// This is the readback half of the replace contract: after a splice is
/// applied, the transaction re-reads the candidate and compares each
/// affected paragraph's projection — through THIS accessor — against the
/// receipt's precomputed expectation. `None` means the path names no
/// paragraph in the story, which a readback must treat as a mismatch
/// rather than a pass.
pub fn docx_paragraph_projection(
  annotated : DocxAnnotatedResult,
  story : DocxStoryPartSource,
  path~ : String,
) -> String? {
  docx_paragraphs_projection(annotated, story, paths=[path])[0]
}

///|
/// The projections of many paragraphs of one story, with the path
/// lookup built once for the whole batch: asking per paragraph costs
/// the whole story per question. Answers are returned in the order
/// asked, `None` where the path names no paragraph.
pub fn docx_paragraphs_projection(
  annotated : DocxAnnotatedResult,
  story : DocxStoryPartSource,
  paths~ : Array[String],
) -> Array[String?] {
  guard !paths.is_empty() else { return [] }
  guard annotated.reader_projections.get(story.part()) is Some(projection) else {
    return paths.map(_ => None)
  }
  let index = docx_paragraph_path_index(projection)
  paths.map(path => {
    match index.locate(path) {
      (target, _) if target >= 0 =>
        Some(find_paragraph_projection(projection.paragraphs[target]))
      _ => None
    }
  })
}
