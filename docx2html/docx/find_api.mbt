// The read-only match surface (N2a). One candidate per literal hit, with
// the coordinates a partial edit would consume and an explicit statement
// of whether that edit would be permitted.
//
// The point of shipping this BEFORE the mutation is that an agent cannot
// look at a rendered document. `find` is how it sees what an edit would
// touch, and -- more importantly -- what it would refuse and why.

///|
/// One candidate the literal matcher found in a story.
///
/// `actionable` is not a second opinion about editability. It is the
/// PLANNER's own answer: each candidate is offered to
/// `plan_paragraph_text_edits` as an identity replacement, which runs
/// every structural check and plans no bytes. So a candidate reported
/// actionable here is one the mutation surface accepts, by construction
/// rather than by a parallel classifier that could drift out of step.
pub struct DocxMatch {
  ordinal : Int
  story : String
  path : String
  start : Int
  end : Int
  text : String
  context_before : String
  context_after : String
  runs : Array[String]
  run_kinds : Array[String]
  actionable : Bool
  reason : String
}

///|
/// Position among all candidates in document order, from 1.
pub fn DocxMatch::ordinal(self : DocxMatch) -> Int {
  self.ordinal
}

///|
/// The story the candidate sits in. `"body"` in v1; the field is
/// reserved so header, footer and note stories can join without a
/// schema break.
pub fn DocxMatch::story(self : DocxMatch) -> String {
  self.story
}

///|
/// The candidate's paragraph, as a body-relative scanner path.
pub fn DocxMatch::path(self : DocxMatch) -> String {
  self.path
}

///|
/// Paragraph-relative UTF-16 start of the match, over the PROJECTION --
/// the text a reader sees, not the bytes.
pub fn DocxMatch::start(self : DocxMatch) -> Int {
  self.start
}

///|
/// Paragraph-relative UTF-16 end, exclusive.
pub fn DocxMatch::end(self : DocxMatch) -> Int {
  self.end
}

///|
/// The matched projection text.
pub fn DocxMatch::text(self : DocxMatch) -> String {
  self.text
}

///|
/// Bounded projection text immediately before the match.
pub fn DocxMatch::context_before(self : DocxMatch) -> String {
  self.context_before
}

///|
/// Bounded projection text immediately after the match.
pub fn DocxMatch::context_after(self : DocxMatch) -> String {
  self.context_after
}

///|
/// The runs the match draws from, as body-relative paths, in document
/// order. A match crossing run boundaries names each one.
pub fn DocxMatch::runs(self : DocxMatch) -> Array[String] {
  self.runs
}

///|
/// The source kinds the match draws from, deduplicated and in document
/// order: `text`, `tab`, `no-break-hyphen`, `soft-hyphen`, `symbol`.
/// A match reading as ordinary prose can still be carried by an atom,
/// and an agent that assumes otherwise will address the wrong thing.
pub fn DocxMatch::run_kinds(self : DocxMatch) -> Array[String] {
  self.run_kinds
}

///|
/// Whether a partial edit over this exact range would be permitted.
pub fn DocxMatch::actionable(self : DocxMatch) -> Bool {
  self.actionable
}

///|
/// Why the candidate is not actionable; empty when it is.
///
/// The vocabulary names the construct rather than the mechanism, since
/// what an agent needs is what to do instead: `field-region`,
/// `hyperlink-boundary`, `tracked-region`, `sdt-content`,
/// `alternate-content`, `textbox`, `cdata`, `visible-barrier`,
/// `suppressed-region`, `multi-physical-paragraph`, `non-scalar-boundary`,
/// `ambiguous-boundary`, `unsupported-source`, `checkbox-control`,
/// `duplicate-source`, `cross-paragraph-reuse`, `no-synthesis-carrier`,
/// `refused-field`, `malformed-field`, `field-instruction`, `internal`.
pub fn DocxMatch::reason(self : DocxMatch) -> String {
  self.reason
}

///|
/// The projection text of one paragraph, which is the coordinate space
/// every offset in a `DocxMatch` is expressed in.
///
/// NOTE ON `substring`: the deprecation suggesting `str[:]` is NOT taken
/// anywhere in this file, deliberately. `str[:]` TRAPS when a boundary
/// lands on a trailing surrogate, where `substring` returns the string.
/// Match boundaries here are arbitrary UTF-16 offsets over
/// attacker-supplied documents, so taking that replacement would turn
/// "reports an odd range" into "crashes while reading" -- a denial of
/// service in a reader of untrusted input. A split boundary is instead
/// reported as a non-actionable candidate, because the planner refuses
/// it as a non-scalar boundary.
fn find_paragraph_projection(paragraph : ReaderProjectionParagraph) -> String {
  let text = StringBuilder()
  for contribution in paragraph.contributions {
    text.write_string(contribution.value)
  }
  text.to_string()
}

///|
/// The scanner path of the element at `byte_start`, for a node kind.
fn find_node_path(scan : StoryScan, kind : String, byte_start : Int) -> String? {
  for node in scan.nodes() {
    if node.kind == kind && node.byte_start == byte_start {
      return Some(node.path)
    }
  }
  None
}

///|
/// The reader's own name for a projected atom's source.
fn find_source_kind(kind : ReaderProjectionContributionKind) -> String? {
  match kind {
    ProjectedText(FromText) => Some("text")
    ProjectedText(FromTab) => Some("tab")
    ProjectedText(FromNoBreakHyphen) => Some("no-break-hyphen")
    ProjectedText(FromSoftHyphen) => Some("soft-hyphen")
    ProjectedText(FromSymbol) => Some("symbol")
    _ => None
  }
}

///|
/// Read the refusal's own public slug out of its message.
///
/// The planner embeds it in a `<reason:...>` marker, rendered from the
/// CLASS by `partial_surgery_refusal_slug`. Find therefore holds no copy
/// of the taxonomy: a class added there appears here without this file
/// changing, and cannot drift out of step.
fn find_reason_for(message : String) -> String {
  let marker = "<reason:"
  guard message.find(marker) is Some(at) else { return "unsupported" }
  let from = at + marker.length()
  let rest = message.substring(start=from)
  guard rest.find(">") is Some(to) else { return "unsupported" }
  rest.substring(start=0, end=to)
}

///|
/// Refine a restricted refusal into the construct an agent can act on.
///
/// `RestrictedRegion` is one class to the mutation surface, deliberately:
/// its callers match on a stable taxonomy. A READER wants the construct,
/// because the remedy differs -- resolve the revision, edit the bound
/// data, flatten the field. So find looks at the same ancestry the
/// planner did and names what it finds.
fn find_restricted_construct(
  elements : Array[ScannedElement],
  paragraph : ReaderProjectionParagraph,
  start : Int,
  end : Int,
) -> String {
  let base = paragraph.projection_start
  let mut link : Int?? = None
  let mut crossing = false
  let mut named : String? = None
  for contribution in paragraph.contributions {
    let from = contribution.projection_start - base
    let to = contribution.projection_end - base
    if from >= end ||
      to <= start ||
      (contribution.kind is ProjectedText(_)) == false {
      continue
    }
    let SourceElementId(identity) = contribution.source
    let element = elements[identity]
    if named is None &&
      run_surgery_restricted_ancestor(elements, element) is Some(construct) {
      named = Some(
        match construct {
          TrackedInsertion => "tracked-region"
          ContentControl => "sdt-content"
          TextBoxContent => "textbox"
          FallbackContent => "alternate-content"
        },
      )
    }
    let here = run_surgery_hyperlink_ancestor(elements, element)
    match link {
      None => link = Some(here)
      Some(first) => if first != here { crossing = true }
    }
  }
  // A field's cached result is a REGION rather than an ancestry, so it
  // is asked separately -- and it outranks the others, because it is the
  // one whose loss no re-read can detect.
  for contribution in paragraph.contributions {
    let from = contribution.projection_start - base
    let to = contribution.projection_end - base
    if from < end && to > start && contribution.field_region is FieldResult {
      return "field-region"
    }
  }
  match named {
    Some(construct) => construct
    None => if crossing { "hyperlink-boundary" } else { "restricted-region" }
  }
}

///|
/// List every literal candidate for `needle`, in document order.
///
/// This is a READ. Zero matches is an empty list and not a refusal --
/// only a mutation fails closed on finding nothing. What can still
/// refuse is the request itself: an empty needle names every position,
/// and a story with no retained projection cannot be searched.
///
/// `within` restricts to a subtree by body-relative path prefix, so
/// `p[3]` takes one paragraph and `tbl[1]` takes a whole table.
pub fn find_docx_matches(
  annotated : DocxAnnotatedResult,
  story : DocxStoryPartSource,
  needle~ : String,
  within? : String,
  context? : Int = 24,
) -> Array[DocxMatch] raise DocxError {
  guard needle != "" else {
    raise Unsupported(
      message="find needs a non-empty needle; an empty one matches every position",
    )
  }
  let part = story.part()
  guard annotated.reader_projections.get(part) is Some(projection) else {
    raise Unsupported(
      message="find requires a mutation-safe read with a retained projection for '\{part}'",
    )
  }
  guard annotated.reader_projection_sources.get(part) is Some(bytes) else {
    raise Unsupported(
      message="the mutation-safe read retained no source bytes for '\{part}'",
    )
  }
  let elements = projection.scan.elements()
  let matches : Array[DocxMatch] = []
  let mut ordinal = 0
  for paragraph_index, paragraph in projection.paragraphs {
    // The paragraph's own path. A logical paragraph joined from several
    // physical ones is named by its FIRST source; the planner refuses to
    // edit it anyway, and the candidate still deserves to be listed with
    // a reason rather than hidden.
    guard paragraph.sources.length() > 0 else { continue }
    let SourceElementId(head) = paragraph.sources[0].source
    guard find_node_path(projection.scan, "p", elements[head].byte_start)
      is Some(path) else {
      continue
    }
    if within is Some(prefix) && !path.has_prefix(prefix) {
      continue
    }
    let text = find_paragraph_projection(paragraph)
    // Non-overlapping, left to right, so two candidates never claim the
    // same character and an agent can act on them independently.
    let mut cursor = 0
    while cursor <= text.length() - needle.length() {
      guard text.substring(start=cursor).has_prefix(needle) else {
        cursor = cursor + 1
        continue
      }
      let start = cursor
      let end = cursor + needle.length()
      ordinal = ordinal + 1
      // The planner's OWN verdict: an identity replacement validates
      // everything and plans nothing.
      let mut actionable = true
      let mut reason = ""
      try
        ignore(
          plan_paragraph_text_edits(projection, bytes, paragraph_index, [
            { start, end, replacement: needle },
          ]),
        )
      catch {
        Unsupported(message~) => {
          actionable = false
          reason = find_reason_for(message)
          if reason == "restricted-region" {
            reason = find_restricted_construct(elements, paragraph, start, end)
          }
        }
        _ => {
          actionable = false
          reason = "unsupported"
        }
      } noraise {
        _ => ()
      }
      // The runs and source kinds the match actually draws from.
      let runs : Array[String] = []
      let kinds : Array[String] = []
      let base = paragraph.projection_start
      for contribution in paragraph.contributions {
        let from = contribution.projection_start - base
        let to = contribution.projection_end - base
        if from >= end || to <= start {
          continue
        }
        if find_source_kind(contribution.kind) is Some(kind) &&
          !kinds.contains(kind) {
          kinds.push(kind)
        }
        if contribution.run_source is Some(SourceElementId(run_identity)) {
          if find_node_path(
              projection.scan,
              "r",
              elements[run_identity].byte_start,
            )
            is Some(run_path) &&
            !runs.contains(run_path) {
            runs.push(run_path)
          }
        }
      }
      let before_from = if start > context { start - context } else { 0 }
      let after_to = if end + context < text.length() {
        end + context
      } else {
        text.length()
      }
      matches.push({
        ordinal,
        story: "body",
        path,
        start,
        end,
        text: text.substring(start~, end~),
        context_before: text.substring(start=before_from, end=start),
        context_after: text.substring(start=end, end=after_to),
        runs,
        run_kinds: kinds,
        actionable,
        reason,
      })
      cursor = end
    }
  }
  matches
}
