// The addressed run-replacement boundary (#462 A1): the ONE public seam
// through which a shipped surface reaches N0c1. The reader-native
// projection, its contribution types, and the raw byte edits stay
// private; what crosses the boundary is a source-pinned SplicePlan plus
// a small receipt. The resolver trusts only the retained projection --
// its own scan resolves the address, its run records decide ownership --
// so the annotation index never becomes a mutation authority.

///|
/// What an addressed run replacement planned: the story part, the
/// address that named the run, the reader-visible text the caller
/// expected (and the plan replaces), and how many byte edits carry it.
pub struct RunTextReceipt {
  priv story_part : String
  priv at_relative : String
  priv replaced_text : String
  priv edit_count : Int
}

///|
pub fn RunTextReceipt::story_part(self : RunTextReceipt) -> String {
  self.story_part
}

///|
pub fn RunTextReceipt::at_relative(self : RunTextReceipt) -> String {
  self.at_relative
}

///|
pub fn RunTextReceipt::replaced_text(self : RunTextReceipt) -> String {
  self.replaced_text
}

///|
pub fn RunTextReceipt::edit_count(self : RunTextReceipt) -> Int {
  self.edit_count
}

///|
/// Plans the replacement of one addressed run's whole text with `text`.
///
/// `story` must be a story part source the annotated result itself
/// exposed, and the result must come from a MUTATION-SAFE read: only
/// those retain the classified projection this planner consumes.
/// `at_relative` is the story-relative ordinal run path (`p[3]/r[2]`),
/// resolved against the projection's own physical scan. `expect` is
/// REQUIRED and must equal the run's reader-visible text: addresses are
/// snapshot-relative, and a stale expectation refuses rather than
/// editing whatever now sits at the path.
///
/// Every failure is a typed refusal; nothing falls back. The returned
/// plan is pinned to the exact source bytes it was computed against.
pub fn plan_run_text_replacement_archive(
  annotated : DocxAnnotatedResult,
  archive : @mbtzip.Archive,
  story : DocxStoryPartSource,
  at_relative~ : String,
  expect~ : String,
  text~ : String,
) -> (@splice.SplicePlan, RunTextReceipt) raise DocxError {
  plan_run_text_replacement_zip(
    annotated,
    open_zip_archive(archive),
    story,
    at_relative~,
    expect~,
    text~,
  )
}

///|
fn plan_run_text_replacement_zip(
  annotated : DocxAnnotatedResult,
  zip : ZipArchive,
  story : DocxStoryPartSource,
  at_relative~ : String,
  expect~ : String,
  text~ : String,
) -> (@splice.SplicePlan, RunTextReceipt) raise DocxError {
  let part = story.part()
  guard annotated.reader_projections.get(part) is Some(projection) else {
    raise Unsupported(
      message="run replacement requires a mutation-safe read with a retained projection for '\{part}'",
    )
  }
  // Resolve the address against the projection's OWN scan. Scanner
  // ordinal paths are unique per story; a duplicate would mean the scan
  // itself is inconsistent, which must refuse, not pick.
  let mut addressed_start = -1
  let mut run_nodes = 0
  for node in projection.scan.nodes() {
    if node.kind == "r" {
      run_nodes += 1
      if node.path == at_relative {
        if addressed_start >= 0 {
          raise Unsupported(
            message="'\{at_relative}' names more than one run in '\{part}'",
          )
        }
        addressed_start = node.byte_start
      }
    }
  }
  if addressed_start < 0 {
    raise Unsupported(
      message="'\{at_relative}' does not name a run in '\{part}' (\{run_nodes} runs are addressable)",
    )
  }
  // Map the physical run to exactly one projection paragraph/run. The
  // planner re-checks cross-paragraph reuse; refusing here keeps the
  // boundary's own contract total.
  let elements = projection.scan.elements()
  let mut located : (Int, Int)? = None
  for paragraph_index, paragraph in projection.paragraphs {
    for run_index, run in paragraph.runs {
      let SourceElementId(identity) = run.source
      if elements[identity].byte_start == addressed_start {
        if located is Some(_) {
          raise Unsupported(
            message="'\{at_relative}' maps to more than one projected run in '\{part}'",
          )
        }
        located = Some((paragraph_index, run_index))
      }
    }
  }
  guard located is Some((paragraph_index, run_index)) else {
    raise Unsupported(
      message="'\{at_relative}' names a run the mutation projection does not own in '\{part}'",
    )
  }
  // The stale-address gate: the run's reader-visible text must be what
  // the caller believes it is. Neither side's content is echoed into
  // the error -- refusal reasons must not leak document text into logs.
  let target = projection.paragraphs[paragraph_index].runs[run_index].source
  let visible = StringBuilder::new()
  for contribution in projection.paragraphs[paragraph_index].contributions {
    if contribution.run_source == Some(target) {
      visible.write_string(contribution.value)
    }
  }
  if visible.to_string() != expect {
    raise Unsupported(
      message="the run at '\{at_relative}' in '\{part}' does not carry the expected text; re-read the document and retry with a fresh address",
    )
  }
  guard zip.read_bytes(part) is Some(bytes) else {
    raise MissingPart(message="missing DOCX part: " + part)
  }
  let edits = plan_whole_run_replacement(
    projection, bytes, paragraph_index, run_index, text,
  )
  let plan = @splice.SplicePlan::new()
  plan.pin_part(part, bytes)
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
  (
    plan,
    {
      story_part: part,
      at_relative,
      replaced_text: expect,
      edit_count: edits.length(),
    },
  )
}
