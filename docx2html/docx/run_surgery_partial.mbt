///|
/// N0c2 partial token-boundary surgery, increments B1+B2a+B2b: batch-shaped
/// edits in paragraph-local UTF-16 projection coordinates, resolved to
/// source bytes through the token map so bytes outside the declared edit
/// union are never rewritten and entity spellings outside the union are
/// never canonicalized. B2a admits ranges crossing `w:t` and editable-atom
/// boundaries; B2b extends them ACROSS RUNS within one physical paragraph:
/// the replacement lands at the first consumed projecting contribution (a
/// mapped `w:t`, or a synthesized `w:t` replacing the first consumed atom,
/// carrying the first consumed run's formatting by construction),
/// fully-covered middle `w:t` elements are emptied in place, fully-covered
/// atoms are deleted whole, the end `w:t` keeps its tail, and every run
/// shell, `rPr`, wrapper, and transparent seam in between survives
/// byte-identical. Every run the interval involves — including atomless
/// runs visible only through their zero-width run-open contributions — is
/// gated for field state before any placement.
///
/// B3 generalizes composition. The refusal vocabulary below is the stable
/// N0c2 taxonomy; these increments raise the subset they can reach.
///
/// Constructed only by the whitebox suites that drive
/// `plan_paragraph_text_edits`, which the library build does not compile --
/// hence the suppression, matching how the rest of this file's staged N0c2
/// declarations are handled.
#warnings("-struct_never_constructed")
priv struct ParagraphTextEdit {
  start : Int
  end : Int
  replacement : String
}

///|
/// Stable refusal classes for partial surgery. One renderer produces the
/// user-facing message so every class keeps a stable reason and no class
/// ever echoes document or replacement content.
priv enum PartialSurgeryRefusal {
  InvalidParagraph
  InvalidRange
  UnorderedEdits
  LogicalOverlap
  MultiPhysicalParagraph
  NonScalarBoundary
  AmbiguousBoundary
  CDataContext
  VisibleBarrier
  SuppressedRegion
  // Projecting-restricted regions: text that MATCHES but must not be
  // MUTATED. Complex-field cached results, `w:ins`, `w:sdt`,
  // `mc:Fallback` and textbox content refuse by ancestry or region;
  // hyperlinks refuse only when an edit CROSSES a boundary.
  RestrictedRegion
  PartialFieldInstruction
  PartialMalformedField
  RefusedField
  PartialCheckboxControl
  DuplicateSource
  CrossParagraphSourceReuse
  UnsupportedTextSource
  NoSynthesisCarrier
  InvalidReplacement
  PartialBudgetExceeded
  InternalPlanConflict
} derive(Show)

///|
fn partial_surgery_refusal_reason(kind : PartialSurgeryRefusal) -> String {
  match kind {
    InvalidParagraph => "the addressed paragraph does not exist"
    InvalidRange => "an edit range is outside the paragraph projection"
    UnorderedEdits => "edits must be ordered by ascending start offset"
    LogicalOverlap => "edit ranges overlap in projection coordinates"
    MultiPhysicalParagraph =>
      "the logical paragraph joins multiple physical paragraphs"
    NonScalarBoundary =>
      "an edit endpoint does not fall on a scalar source boundary"
    AmbiguousBoundary => "an edit boundary does not resolve to a unique carrier"
    CDataContext => "the addressed text draws from a CDATA section"
    VisibleBarrier => "the edit range crosses visible non-text content"
    SuppressedRegion => "the edit range crosses suppressed content"
    // "touches", not "crosses": a wholly INTERIOR edit in a tracked
    // insertion, a content control, a fallback branch or a textbox
    // refuses just as an edge-crossing one does.
    RestrictedRegion => "the edit range touches a restricted region"
    PartialFieldInstruction =>
      "the addressed text carries field instruction machinery"
    PartialMalformedField => "the addressed text sits in a malformed field"
    RefusedField => "the addressed text sits in a field the classifier refused"
    PartialCheckboxControl =>
      "the addressed text sits inside a checkbox content control"
    DuplicateSource => "the addressed element is projected more than once"
    CrossParagraphSourceReuse =>
      "the addressed run also contributes to another paragraph"
    UnsupportedTextSource =>
      "the addressed content is not a mapped ordinary text element"
    NoSynthesisCarrier => "no unique carrier exists for synthesized text"
    InvalidReplacement => "the replacement text cannot be represented in XML"
    PartialBudgetExceeded => "partial surgery exceeded its planning budget"
    InternalPlanConflict => "internal partial-surgery plan conflict"
  }
}

///|
fn partial_surgery_refuse(
  kind : PartialSurgeryRefusal,
  context : String,
) -> DocxError {
  Unsupported(
    message="partial surgery [\{kind}]: \{partial_surgery_refusal_reason(kind)} (\{context})",
  )
}

///|
/// How one logical edit was realized.
priv enum PartialSurgeryPlacement {
  InsideText
  AtomSynthesis
  RunSynthesis
  LogicalNoOp
} derive(Show)

///|
priv struct PartialSurgeryLogicalEdit {
  ordinal : Int
  start : Int
  end : Int
  replacement : String
  placement : PartialSurgeryPlacement
}

///|
/// The aggregate receipt for one planned batch. `expected_projection` is the
/// paragraph's projection after the batch — the exact string the oracle holds
/// the re-read document to. No per-edit byte-edit count is promised: several
/// logical edits can share one `xml:space` edit.
priv struct PartialSurgeryReceipt {
  paragraph_index : Int
  before_projection : String
  expected_projection : String
  logical_edits : Array[PartialSurgeryLogicalEdit]
  byte_edit_count : Int
  touched_source_count : Int
}

///|
/// One touched `w:t` and every wt-local content part any edit contributed
/// to it: the start host's replacement part, an emptied middle's whole
/// range, an end host's consumed head. One element accumulates parts from
/// several edits; its xml:space is decided once from the post-batch whole.
priv struct PartialSurgeryHost {
  source_identity : Int
  contribution_value : String
  // (local_start, local_end, replacement, request_sequence): the sequence
  // makes every sort stable in request order — Array::sort_by_key is
  // documented unstable, so ties must never depend on it.
  local_edits : Array[(Int, Int, String, Int)]
}

///|
/// One projecting contribution with paragraph-local coordinates.
priv struct PartialProjectingPart {
  contribution : ReaderProjectionContribution
  local_start : Int
  local_end : Int
  is_text : Bool
}

///|
/// Plan a batch of partial text edits inside one physical paragraph.
///
/// Refusal precedence is deterministic and BATCH-WIDE: every phase runs to
/// completion over the whole request before the next phase begins, so a
/// later edit's earlier-phase defect always wins over an earlier edit's
/// later-phase defect. Phases: request shape (ranges, then ordering, then
/// overlap), paragraph ownership, structural restrictions (interval walk,
/// run gates, host gates), endpoint resolution, replacement validity, then
/// internal byte-plan validation. On refusal nothing is returned.
fn plan_paragraph_text_edits(
  projection : ReaderProjection,
  source : BytesView,
  paragraph_index : Int,
  requested : Array[ParagraphTextEdit],
) -> (Array[RunSurgeryEdit], PartialSurgeryReceipt) raise DocxError {
  // Phase 1a: every range is valid.
  guard paragraph_index >= 0 && paragraph_index < projection.paragraphs.length() else {
    raise partial_surgery_refuse(
      InvalidParagraph,
      "paragraph \{paragraph_index}",
    )
  }
  let paragraph = projection.paragraphs[paragraph_index]
  let width = paragraph.projection_end - paragraph.projection_start
  for ordinal, edit in requested {
    guard edit.start >= 0 && edit.start <= edit.end && edit.end <= width else {
      raise partial_surgery_refuse(
        InvalidRange,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
  }
  // Phase 1b: the batch is ordered by ascending start.
  for ordinal, edit in requested {
    if ordinal > 0 && edit.start < requested[ordinal - 1].start {
      raise partial_surgery_refuse(
        UnorderedEdits,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
  }
  // Phase 1c: ranges do not overlap (abutting is legal; an insertion at a
  // preceding consuming edit's start must be requested FIRST).
  for ordinal, edit in requested {
    if ordinal > 0 && edit.start < requested[ordinal - 1].end {
      raise partial_surgery_refuse(
        LogicalOverlap,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
  }
  // Phase 2: paragraph ownership — one physical source.
  guard paragraph.sources.length() == 1 else {
    raise partial_surgery_refuse(
      MultiPhysicalParagraph,
      "paragraph \{paragraph_index} has \{paragraph.sources.length()} physical sources",
    )
  }
  let elements = projection.scan.elements()
  // The ordered projecting contributions, with paragraph-local spans, and
  // the paragraph projection they concatenate to.
  let parts : Array[PartialProjectingPart] = []
  let before = StringBuilder()
  for contribution in paragraph.contributions {
    before.write_string(contribution.value)
    guard contribution.kind is ProjectedText(text_kind) else { continue }
    parts.push({
      contribution,
      local_start: contribution.projection_start - paragraph.projection_start,
      local_end: contribution.projection_end - paragraph.projection_start,
      is_text: text_kind is FromText,
    })
  }
  let before_projection = before.to_string()
  // Phase 3: structural restrictions, batch-wide. Each edit resolves to an
  // anchor (text host, first consumed atom, or a unique zero-width
  // carrier), the set of contributions it consumes, and the run they must
  // all share. Barriers strictly inside the interval refuse; transparent
  // seams pass and are never touched.
  let touched : Array[PartialSurgeryHost] = []
  let atom_deletions : Array[Int] = []
  // (run identity, anchor, consumed, replacement, request ordinal,
  //  anchor atom identity)
  let syntheses : Array[(Int, Int, Int, String, Int, Int)] = []
  let logical_edits : Array[PartialSurgeryLogicalEdit] = []
  let involved_elements : Array[Int] = []
  // (element identity, wt-local offset): no-op endpoints that phase 4 must
  // still resolve through the token map.
  let noop_endpoint_checks : Array[(Int, Int)] = []
  fn touch_wt(
    identity : Int,
    value : String,
    local_from : Int,
    local_to : Int,
    replacement : String,
    sequence : Int,
  ) -> Unit {
    let mut record : PartialSurgeryHost? = None
    for host in touched {
      if host.source_identity == identity {
        record = Some(host)
      }
    }
    match record {
      Some(host) =>
        host.local_edits.push((local_from, local_to, replacement, sequence))
      None =>
        touched.push({
          source_identity: identity,
          contribution_value: value,
          local_edits: [(local_from, local_to, replacement, sequence)],
        })
    }
  }

  fn require_supported_run(
    run : ReaderProjectionRun,
    ordinal : Int,
  ) -> Unit raise DocxError {
    match run.field_region {
      FieldInstruction =>
        raise partial_surgery_refuse(
          PartialFieldInstruction,
          "edit \{ordinal} in paragraph \{paragraph_index}",
        )
      MalformedField =>
        raise partial_surgery_refuse(
          PartialMalformedField,
          "edit \{ordinal} in paragraph \{paragraph_index}",
        )
      _ => ()
    }
    if run.field_refusal is Some(_) {
      raise partial_surgery_refuse(
        RefusedField,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    // AFTER the classifier's refusal, matching N0c1: a refused field's
    // boundaries are unreliable, which outranks "the next recalculation
    // discards this", and a truncated field's result run carries both.
    if run.field_region is FieldResult {
      raise partial_surgery_refuse(
        RestrictedRegion,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
  }

  fn require_supported_contribution(
    contribution : ReaderProjectionContribution,
    ordinal : Int,
  ) -> Unit raise DocxError {
    match contribution.field_region {
      FieldInstruction =>
        raise partial_surgery_refuse(
          PartialFieldInstruction,
          "edit \{ordinal} in paragraph \{paragraph_index}",
        )
      MalformedField =>
        raise partial_surgery_refuse(
          PartialMalformedField,
          "edit \{ordinal} in paragraph \{paragraph_index}",
        )
      FieldResult =>
        raise partial_surgery_refuse(
          RestrictedRegion,
          "edit \{ordinal} in paragraph \{paragraph_index}",
        )
      _ => ()
    }
  }

  fn require_singly_projected(
    contribution : ReaderProjectionContribution,
    ordinal : Int,
  ) -> Unit raise DocxError {
    let mut count = 0
    for part in parts {
      if part.contribution.source == contribution.source {
        count += 1
      }
    }
    if count > 1 {
      raise partial_surgery_refuse(
        DuplicateSource,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
  }

  fn resolve_run(
    run_source : SourceElementId?,
    ordinal : Int,
  ) -> ReaderProjectionRun raise DocxError {
    guard run_source is Some(source_id) else {
      raise partial_surgery_refuse(
        UnsupportedTextSource,
        "edit \{ordinal} in paragraph \{paragraph_index} has no owning run",
      )
    }
    let mut found : ReaderProjectionRun? = None
    for run in paragraph.runs {
      if run.source == source_id {
        found = Some(run)
      }
    }
    guard found is Some(run) else {
      raise partial_surgery_refuse(
        InternalPlanConflict,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    run
  }

  fn require_host_element(
    identity : Int,
    ordinal : Int,
  ) -> Unit raise DocxError {
    let element = elements[identity]
    if run_surgery_inside_checkbox_control(elements, element) {
      raise partial_surgery_refuse(
        PartialCheckboxControl,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    // After the checkbox case, so the more specific refusal keeps
    // precedence over the general one. This covers text hosts, atoms,
    // validated no-ops and atomless-run synthesis alike, because every
    // one of them arrives here by identity.
    if run_surgery_restricted_ancestor(elements, element) is Some(_) {
      raise partial_surgery_refuse(
        RestrictedRegion,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    for index, other in projection.paragraphs {
      if index != paragraph_index {
        for candidate in other.runs {
          for part in parts {
            if part.contribution.source == SourceElementId(identity) &&
              part.contribution.run_source == Some(candidate.source) {
              raise partial_surgery_refuse(
                CrossParagraphSourceReuse,
                "edit \{ordinal} in paragraph \{paragraph_index} reuses a run of paragraph \{index}",
              )
            }
          }
        }
      }
    }
  }

  for ordinal, edit in requested {
    // Barriers strictly inside the interval, walked in source order.
    for contribution in paragraph.contributions {
      let position = contribution.projection_start - paragraph.projection_start
      if contribution.projection_start == contribution.projection_end &&
        position > edit.start &&
        position < edit.end {
        match contribution.kind {
          VisibleNonText =>
            raise partial_surgery_refuse(
              VisibleBarrier,
              "edit \{ordinal} in paragraph \{paragraph_index}",
            )
          SuppressedContent =>
            raise partial_surgery_refuse(
              SuppressedRegion,
              "edit \{ordinal} in paragraph \{paragraph_index}",
            )
          // An empty drawing or embedded object reaches the projection as
          // a Transparent boundary, but the inventory calls it a hard
          // barrier: a range may not span one.
          Transparent => {
            let SourceElementId(seam_identity) = contribution.source
            if run_surgery_is_hard_barrier_container(elements[seam_identity]) {
              raise partial_surgery_refuse(
                VisibleBarrier,
                "edit \{ordinal} in paragraph \{paragraph_index}",
              )
            }
          }
          _ => ()
        }
      }
    }
    // Hyperlink boundaries. A CONSUMING edit must sit entirely inside
    // one hyperlink or entirely outside every hyperlink; spanning the
    // edge would drag unlinked text into the link or leave linked text
    // outside it, because the replacement lands at a single carrier.
    //
    // Checked AFTER the barrier pass above, so a range that crosses
    // suppressed or visible content still reports THAT rather than this.
    // An insertion has one position and cannot span an edge, so it is
    // not considered here; its carrier resolution already decides where
    // a boundary position belongs.
    if edit.start < edit.end {
      let mut anchor : Int?? = None
      for part in parts {
        if part.local_start < edit.end && part.local_end > edit.start {
          let SourceElementId(identity) = part.contribution.source
          let link = run_surgery_hyperlink_ancestor(
            elements,
            elements[identity],
          )
          match anchor {
            None => anchor = Some(link)
            Some(first) =>
              if first != link {
                raise partial_surgery_refuse(
                  RestrictedRegion,
                  "edit \{ordinal} in paragraph \{paragraph_index}",
                )
              }
          }
        }
      }
    }
    // Duplicate projection: any element projected twice cannot be edited.
    for part in parts {
      if part.local_start < edit.end && part.local_end > edit.start {
        let mut count = 0
        for other in parts {
          if other.contribution.source == part.contribution.source {
            count += 1
          }
        }
        if count > 1 {
          raise partial_surgery_refuse(
            DuplicateSource,
            "edit \{ordinal} in paragraph \{paragraph_index}",
          )
        }
      }
    }
    if edit.start == edit.end {
      // Pure insertion. An interior position of a mapped `w:t` is its own
      // unique carrier; a shared boundary needs exactly one candidate. An
      // EMPTY insertion is a validated no-op: the carrier resolves and
      // every structural gate runs before byte planning is suppressed.
      let mut interior : PartialProjectingPart? = None
      for part in parts {
        if part.local_start < edit.start && edit.start < part.local_end {
          interior = Some(part)
        }
      }
      match interior {
        Some(part) => {
          guard part.is_text else {
            // Inside an atom's projection (a multi-unit symbol): not a
            // scalar source boundary.
            raise partial_surgery_refuse(
              NonScalarBoundary,
              "edit \{ordinal} in paragraph \{paragraph_index}",
            )
          }
          let run = resolve_run(part.contribution.run_source, ordinal)
          require_supported_run(run, ordinal)
          require_supported_contribution(part.contribution, ordinal)
          require_singly_projected(part.contribution, ordinal)
          let SourceElementId(identity) = part.contribution.source
          require_host_element(identity, ordinal)
          let element = elements[identity]
          guard is_wml_uri(element.uri) && element.local_name == "t" else {
            raise partial_surgery_refuse(
              UnsupportedTextSource,
              "edit \{ordinal} in paragraph \{paragraph_index}",
            )
          }
          guard element.text_map is Some(map) else {
            raise partial_surgery_refuse(
              UnsupportedTextSource,
              "edit \{ordinal} in paragraph \{paragraph_index} addresses a self-closing text element",
            )
          }
          if map.contains_cdata {
            raise partial_surgery_refuse(
              CDataContext,
              "edit \{ordinal} in paragraph \{paragraph_index}",
            )
          }
          involved_elements.push(identity)
          if edit.replacement == "" {
            noop_endpoint_checks.push((identity, edit.start - part.local_start))
            logical_edits.push({
              ordinal,
              start: edit.start,
              end: edit.end,
              replacement: edit.replacement,
              placement: LogicalNoOp,
            })
            continue
          }
          touch_wt(
            identity,
            part.contribution.value,
            edit.start - part.local_start,
            edit.start - part.local_start,
            edit.replacement,
            ordinal,
          )
          logical_edits.push({
            ordinal,
            start: edit.start,
            end: edit.end,
            replacement: edit.replacement,
            placement: InsideText,
          })
        }
        None => {
          // Boundary candidates: text edges, atom edges, and — when the
          // paragraph projects nothing at this position — a unique
          // atomless run.
          let text_candidates : Array[PartialProjectingPart] = []
          let atom_candidates : Array[(PartialProjectingPart, Bool)] = []
          for part in parts {
            if part.is_text {
              if part.local_start == edit.start || part.local_end == edit.start {
                text_candidates.push(part)
              }
            } else if part.local_start == edit.start {
              atom_candidates.push((part, true))
            } else if part.local_end == edit.start {
              atom_candidates.push((part, false))
            }
          }
          let total = text_candidates.length() + atom_candidates.length()
          if total == 0 {
            // No projecting carrier at this boundary. A paragraph that
            // projects NOTHING has exactly one unambiguous insertion
            // position, so a single atomless run there is a unique
            // carrier: synthesize into it after any `rPr`, the placement
            // N0c1 established. With projecting content elsewhere an
            // atomless run has no coordinates of its own, so no offset can
            // name it and the refusal stands.
            // `parts` holds PROJECTING content only, so a run carrying
            // just a break or another visible non-text atom would
            // otherwise look like an empty paragraph and take synthesized
            // text — but the offset cannot say whether the text belongs
            // before or after that zero-width barrier, and whole-run
            // surgery refuses VisibleNonText outright.
            let mut occupied = false
            for contribution in paragraph.contributions {
              match contribution.kind {
                VisibleNonText | SuppressedContent => occupied = true
                Transparent => {
                  let SourceElementId(seam_identity) = contribution.source
                  if run_surgery_is_hard_barrier_container(
                      elements[seam_identity],
                    ) {
                    occupied = true
                  }
                }
                _ => ()
              }
            }
            guard parts.length() == 0 &&
              !occupied &&
              paragraph.runs.length() == 1 else {
              raise partial_surgery_refuse(
                NoSynthesisCarrier,
                "edit \{ordinal} in paragraph \{paragraph_index}",
              )
            }
            let carrier = paragraph.runs[0]
            require_supported_run(carrier, ordinal)
            // require_host_element detects cross-paragraph reuse through
            // the projecting parts, and this path HAS none — so the check
            // has to be made directly against the carrier. The reader
            // tolerates a nested `w:p`, whose two logical paragraphs share
            // the outer run: synthesizing into the empty one would write
            // into the other paragraph's text while the receipt described
            // this one.
            for index, other in projection.paragraphs {
              if index != paragraph_index {
                for candidate in other.runs {
                  if candidate.source == carrier.source {
                    raise partial_surgery_refuse(
                      CrossParagraphSourceReuse,
                      "edit \{ordinal} in paragraph \{paragraph_index} would synthesize into a run of paragraph \{index}",
                    )
                  }
                }
              }
            }
            let SourceElementId(carrier_identity) = carrier.source
            require_host_element(carrier_identity, ordinal)
            if edit.replacement == "" {
              logical_edits.push({
                ordinal,
                start: edit.start,
                end: edit.end,
                replacement: edit.replacement,
                placement: LogicalNoOp,
              })
              continue
            }
            let carrier_element = elements[carrier_identity]
            let at = run_surgery_first_content_position(
              elements, carrier_element,
            )
            involved_elements.push(carrier_identity)
            syntheses.push(
              (
                carrier_identity,
                at,
                at,
                edit.replacement,
                ordinal,
                carrier_identity,
              ),
            )
            logical_edits.push({
              ordinal,
              start: edit.start,
              end: edit.end,
              replacement: edit.replacement,
              placement: RunSynthesis,
            })
            continue
          }
          if total > 1 {
            // Candidates that are all the SAME physical element (projected
            // more than once) are the duplicate-projection defect, not an
            // ambiguous boundary.
            let mut distinct = 0
            let mut previous : SourceElementId? = None
            for candidate in text_candidates {
              if previous is None ||
                previous != Some(candidate.contribution.source) {
                distinct += 1
              }
              previous = Some(candidate.contribution.source)
            }
            for candidate in atom_candidates {
              if previous is None ||
                previous != Some(candidate.0.contribution.source) {
                distinct += 1
              }
              previous = Some(candidate.0.contribution.source)
            }
            if distinct == 1 {
              raise partial_surgery_refuse(
                DuplicateSource,
                "edit \{ordinal} in paragraph \{paragraph_index}",
              )
            }
            raise partial_surgery_refuse(
              AmbiguousBoundary,
              "edit \{ordinal} in paragraph \{paragraph_index}",
            )
          }
          match text_candidates {
            [part] => {
              guard part.contribution.kind is ProjectedText(FromText) else {
                raise partial_surgery_refuse(
                  InternalPlanConflict,
                  "edit \{ordinal} in paragraph \{paragraph_index}",
                )
              }
              let run = resolve_run(part.contribution.run_source, ordinal)
              require_supported_run(run, ordinal)
              require_supported_contribution(part.contribution, ordinal)
              require_singly_projected(part.contribution, ordinal)
              let SourceElementId(identity) = part.contribution.source
              require_host_element(identity, ordinal)
              let element = elements[identity]
              guard is_wml_uri(element.uri) && element.local_name == "t" else {
                raise partial_surgery_refuse(
                  UnsupportedTextSource,
                  "edit \{ordinal} in paragraph \{paragraph_index}",
                )
              }
              guard element.text_map is Some(map) else {
                raise partial_surgery_refuse(
                  UnsupportedTextSource,
                  "edit \{ordinal} in paragraph \{paragraph_index} addresses a self-closing text element",
                )
              }
              if map.contains_cdata {
                raise partial_surgery_refuse(
                  CDataContext,
                  "edit \{ordinal} in paragraph \{paragraph_index}",
                )
              }
              involved_elements.push(identity)
              if edit.replacement == "" {
                noop_endpoint_checks.push(
                  (identity, edit.start - part.local_start),
                )
                logical_edits.push({
                  ordinal,
                  start: edit.start,
                  end: edit.end,
                  replacement: edit.replacement,
                  placement: LogicalNoOp,
                })
                continue
              }
              touch_wt(
                identity,
                part.contribution.value,
                edit.start - part.local_start,
                edit.start - part.local_start,
                edit.replacement,
                ordinal,
              )
              logical_edits.push({
                ordinal,
                start: edit.start,
                end: edit.end,
                replacement: edit.replacement,
                placement: InsideText,
              })
            }
            _ =>
              match atom_candidates {
                [(part, before_atom)] => {
                  let run = resolve_run(part.contribution.run_source, ordinal)
                  require_supported_run(run, ordinal)
                  require_supported_contribution(part.contribution, ordinal)
                  require_singly_projected(part.contribution, ordinal)
                  let SourceElementId(identity) = part.contribution.source
                  require_host_element(identity, ordinal)
                  let atom_element = elements[identity]
                  let SourceElementId(run_identity) = run.source
                  let at = if before_atom {
                    atom_element.byte_start
                  } else {
                    atom_element.byte_end
                  }
                  involved_elements.push(identity)
                  if edit.replacement == "" {
                    // An empty insertion beside an atom validates its
                    // carrier and synthesizes nothing.
                    logical_edits.push({
                      ordinal,
                      start: edit.start,
                      end: edit.end,
                      replacement: edit.replacement,
                      placement: LogicalNoOp,
                    })
                    continue
                  }
                  syntheses.push(
                    (run_identity, at, at, edit.replacement, ordinal, identity),
                  )
                  logical_edits.push({
                    ordinal,
                    start: edit.start,
                    end: edit.end,
                    replacement: edit.replacement,
                    placement: AtomSynthesis,
                  })
                }
                _ =>
                  raise partial_surgery_refuse(
                    InternalPlanConflict,
                    "edit \{ordinal} in paragraph \{paragraph_index}",
                  )
              }
          }
        }
      }
      continue
    }
    // Consuming edit: the intersecting projecting contributions, in order.
    let intersecting : Array[PartialProjectingPart] = []
    for part in parts {
      if part.local_start < edit.end && part.local_end > edit.start {
        intersecting.push(part)
      }
    }
    guard intersecting.length() > 0 else {
      raise partial_surgery_refuse(
        InternalPlanConflict,
        "edit \{ordinal} in paragraph \{paragraph_index} covers no projecting content",
      )
    }
    // Every intersecting projecting contribution must have an owning run:
    // a direct paragraph-child `w:t` the tolerant reader admits has no run
    // shell to carry formatting or field state, so it is not a partial-
    // surgery host.
    for part in intersecting {
      if part.contribution.run_source is None {
        raise partial_surgery_refuse(
          UnsupportedTextSource,
          "edit \{ordinal} in paragraph \{paragraph_index} draws from content outside any run",
        )
      }
    }
    // Gate EVERY run the interval involves, derived from PHYSICAL SPANS:
    // registration indices follow first appearance, and the reader
    // tolerates nested runs, so a nested `<w:r/>` sitting between two of
    // an outer run's texts registers AFTER the outer run — an index range
    // cannot see it. The physical byte window spanned by the intersecting
    // contributions can: every run whose element span overlaps it is
    // structurally involved, contribution or not, and carries field state
    // of its own.
    let mut window_start = -1
    let mut window_end = -1
    for part in intersecting {
      let span = part.contribution.source_span
      if window_start < 0 || span.byte_start < window_start {
        window_start = span.byte_start
      }
      if span.byte_end > window_end {
        window_end = span.byte_end
      }
    }
    guard window_start >= 0 else {
      raise partial_surgery_refuse(
        InternalPlanConflict,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    for candidate in paragraph.runs {
      let SourceElementId(candidate_identity) = candidate.source
      let candidate_element = elements[candidate_identity]
      if candidate_element.byte_start < window_end &&
        candidate_element.byte_end > window_start {
        require_supported_run(candidate, ordinal)
      }
    }
    let run = resolve_run(intersecting[0].contribution.run_source, ordinal)
    // Atoms and non-text sources may only be wholly covered.
    for part in intersecting {
      require_supported_contribution(part.contribution, ordinal)
      if !part.is_text &&
        (edit.start > part.local_start || edit.end < part.local_end) {
        raise partial_surgery_refuse(
          NonScalarBoundary,
          "edit \{ordinal} in paragraph \{paragraph_index} splits an atom",
        )
      }
    }
    // Validate every consumed element's structure FIRST: a logical no-op
    // suppresses byte planning, never validation (replacing CDATA text
    // with itself is still a CDATA refusal, and B1's phase precedence
    // demands structural defects surface before anything is skipped).
    for part in intersecting {
      let SourceElementId(identity) = part.contribution.source
      require_host_element(identity, ordinal)
      let element = elements[identity]
      // A non-text part is consumed by its WHOLE element span, in every
      // branch below: replaced, deleted, or synthesised over. The reader
      // reached it without walking inside, so a nested subtree is
      // invisible to the projection and to the ancestry checks alike.
      //
      // The guard sits HERE rather than at each consuming branch,
      // because guarding branches is how the last two rounds missed a
      // shape: this loop is the one place every consumed element passes
      // through, and it runs before the no-op exit, so a self-replacement
      // is validated too.
      if !part.is_text &&
        run_surgery_consumed_span_has_children(elements, element) {
        raise partial_surgery_refuse(
          UnsupportedTextSource,
          "edit \{ordinal} in paragraph \{paragraph_index}",
        )
      }
      if part.is_text {
        guard is_wml_uri(element.uri) && element.local_name == "t" else {
          raise partial_surgery_refuse(
            UnsupportedTextSource,
            "edit \{ordinal} in paragraph \{paragraph_index}",
          )
        }
        guard element.text_map is Some(map) else {
          raise partial_surgery_refuse(
            UnsupportedTextSource,
            "edit \{ordinal} in paragraph \{paragraph_index} addresses a self-closing text element",
          )
        }
        if map.contains_cdata {
          raise partial_surgery_refuse(
            CDataContext,
            "edit \{ordinal} in paragraph \{paragraph_index}",
          )
        }
      }
      involved_elements.push(identity)
    }
    // Logical no-op, decided on the projection before any lexical work —
    // but its endpoints must still resolve, so they join phase 4. This
    // covers atom-only ranges too: replacing a tab with a tab is as much
    // a no-op as replacing text with itself.
    let replaced = before_projection
      .view(start_offset=edit.start, end_offset=edit.end)
      .to_owned()
    if replaced == edit.replacement {
      let head = intersecting[0]
      if head.is_text {
        let SourceElementId(identity) = head.contribution.source
        noop_endpoint_checks.push((identity, edit.start - head.local_start))
      }
      let tail = intersecting[intersecting.length() - 1]
      if tail.is_text {
        let SourceElementId(identity) = tail.contribution.source
        noop_endpoint_checks.push((identity, edit.end - tail.local_start))
      }
      logical_edits.push({
        ordinal,
        start: edit.start,
        end: edit.end,
        replacement: edit.replacement,
        placement: LogicalNoOp,
      })
      continue
    }
    let first = intersecting[0]
    let last = intersecting[intersecting.length() - 1]
    if first.is_text {
      // The start-side w:t hosts the replacement, consuming from the edit
      // start (or its own start when the edit begins at its boundary — the
      // right-hand w:t wins there by construction, since a predecessor
      // ending at the offset does not intersect) to its end or the edit's.
      let SourceElementId(identity) = first.contribution.source
      let from = edit.start - first.local_start
      let to = if edit.end < first.local_end {
        edit.end - first.local_start
      } else {
        first.local_end - first.local_start
      }
      touch_wt(
        identity,
        first.contribution.value,
        from,
        to,
        edit.replacement,
        ordinal,
      )
      logical_edits.push({
        ordinal,
        start: edit.start,
        end: edit.end,
        replacement: edit.replacement,
        placement: InsideText,
      })
    } else {
      // The first consumed content is an atom: synthesize in its run,
      // replacing the atom in the same edit — unless the replacement is
      // empty, in which case the atoms are simply deleted.
      let SourceElementId(identity) = first.contribution.source
      let atom_element = elements[identity]
      let SourceElementId(run_identity) = run.source
      if edit.replacement == "" {
        atom_deletions.push(identity)
        logical_edits.push({
          ordinal,
          start: edit.start,
          end: edit.end,
          replacement: edit.replacement,
          placement: InsideText,
        })
      } else {
        syntheses.push(
          (
            run_identity,
            atom_element.byte_start,
            atom_element.byte_end,
            edit.replacement,
            ordinal,
            identity,
          ),
        )
        logical_edits.push({
          ordinal,
          start: edit.start,
          end: edit.end,
          replacement: edit.replacement,
          placement: AtomSynthesis,
        })
      }
    }
    // Middle and end contributions: emptied, deleted, or trimmed.
    for index, part in intersecting {
      if index == 0 {
        continue
      }
      let SourceElementId(identity) = part.contribution.source
      let fully_covered = edit.end >= part.local_end
      if part.is_text {
        let to = if fully_covered {
          part.local_end - part.local_start
        } else {
          edit.end - part.local_start
        }
        touch_wt(identity, part.contribution.value, 0, to, "", ordinal)
      } else {
        // Partial atom coverage was refused above; the last atom is whole.
        let _ = last
        atom_deletions.push(identity)
      }
    }
  }
  // Phase 4: endpoint resolution, batch-wide — every wt-local offset any
  // edit produced must resolve through its host's token map, including the
  // endpoints of validated no-ops.
  for check in noop_endpoint_checks {
    let (identity, local_offset) = check
    guard elements[identity].text_map is Some(map) else {
      raise partial_surgery_refuse(InternalPlanConflict, "host lost its map")
    }
    guard map.byte_offset_at(local_offset) is Some(_) else {
      raise partial_surgery_refuse(
        NonScalarBoundary,
        "paragraph \{paragraph_index}",
      )
    }
  }
  for host in touched {
    guard elements[host.source_identity].text_map is Some(map) else {
      raise partial_surgery_refuse(InternalPlanConflict, "host lost its map")
    }
    for local_edit in host.local_edits {
      let (local_start, local_end, _, _) = local_edit
      guard map.byte_offset_at(local_start) is Some(_) &&
        map.byte_offset_at(local_end) is Some(_) else {
        raise partial_surgery_refuse(
          NonScalarBoundary,
          "paragraph \{paragraph_index}",
        )
      }
    }
  }
  // Phase 5: replacement validity, batch-wide.
  for host in touched {
    for local_edit in host.local_edits {
      let (_, _, replacement, _) = local_edit
      (run_surgery_escape(replacement) |> ignore) catch {
        Unsupported(message~) =>
          raise partial_surgery_refuse(InvalidReplacement, message)
        error => raise error
      }
    }
  }
  for synthesis in syntheses {
    let (_, _, _, replacement, _, _) = synthesis
    (run_surgery_escape(replacement) |> ignore) catch {
      Unsupported(message~) =>
        raise partial_surgery_refuse(InvalidReplacement, message)
      error => raise error
    }
  }
  // Phase 6: byte planning.
  let edits : Array[RunSurgeryEdit] = []
  for host in touched {
    let element = elements[host.source_identity]
    guard element.text_map is Some(map) else {
      raise partial_surgery_refuse(InternalPlanConflict, "host lost its map")
    }
    host.local_edits.sort_by_key(local_edit => {
      (
        local_edit.0,
        if local_edit.1 > local_edit.0 {
          1
        } else {
          0
        },
        local_edit.3,
      )
    })
    // The post-batch content of this `w:t` decides xml:space once.
    let after = StringBuilder()
    let mut cursor = 0
    for local_edit in host.local_edits {
      let (local_start, local_end, replacement, _) = local_edit
      after.write_string(
        host.contribution_value
        .view(start_offset=cursor, end_offset=local_start)
        .to_owned(),
      )
      after.write_string(replacement)
      cursor = local_end
    }
    after.write_string(
      host.contribution_value.view(start_offset=cursor).to_owned(),
    )
    let final_content = after.to_string()
    let wants_space = run_surgery_needs_space_preserve(final_content)
    let existing = run_surgery_space_declaration(source, element)
    // The N0c1 policy verbatim: replace an existing declaration wholesale
    // when preservation is needed (it may say `default`); never touch it
    // when preservation is not needed; never edit an untouched `w:t`.
    match existing {
      Some((from, to)) =>
        // An existing `preserve` is left byte-identical; only a `default`
        // (or any other value) is replaced. A value that cannot be
        // decoded refuses: rewriting bytes whose meaning is unknown is
        // exactly what this surgery must not do.
        if wants_space {
          match run_surgery_space_declaration_is_preserve(source, (from, to)) {
            Some(true) => ()
            Some(false) =>
              edits.push({
                byte_start: from,
                byte_end: to,
                replacement: "xml:space=\"preserve\"",
              })
            None =>
              raise partial_surgery_refuse(
                UnsupportedTextSource,
                "paragraph \{paragraph_index}",
              )
          }
        }
      None =>
        if wants_space {
          edits.push({
            byte_start: element.content_start - 1,
            byte_end: element.content_start - 1,
            replacement: " xml:space=\"preserve\"",
          })
        }
    }
    // Content splices. Equal-offset pure insertions are concatenated in
    // request order rather than relying on any downstream ordering of
    // identical keys.
    let mut pending_insertion_at = -1
    let mut pending_insertion = ""
    for local_edit in host.local_edits {
      let (local_start, local_end, replacement, _) = local_edit
      guard map.byte_offset_at(local_start) is Some(byte_from) &&
        map.byte_offset_at(local_end) is Some(byte_to) else {
        raise partial_surgery_refuse(
          InternalPlanConflict,
          "endpoint resolution changed between phases",
        )
      }
      let escaped = run_surgery_escape(replacement) catch {
        _ =>
          raise partial_surgery_refuse(
            InternalPlanConflict,
            "replacement validity changed between phases",
          )
      }
      if byte_from == byte_to {
        if pending_insertion_at == byte_from {
          pending_insertion = pending_insertion + escaped
          continue
        }
        if pending_insertion_at >= 0 {
          edits.push({
            byte_start: pending_insertion_at,
            byte_end: pending_insertion_at,
            replacement: pending_insertion,
          })
        }
        pending_insertion_at = byte_from
        pending_insertion = escaped
        continue
      }
      if pending_insertion_at >= 0 {
        edits.push({
          byte_start: pending_insertion_at,
          byte_end: pending_insertion_at,
          replacement: pending_insertion,
        })
        pending_insertion_at = -1
        pending_insertion = ""
      }
      edits.push({
        byte_start: byte_from,
        byte_end: byte_to,
        replacement: escaped,
      })
    }
    if pending_insertion_at >= 0 {
      edits.push({
        byte_start: pending_insertion_at,
        byte_end: pending_insertion_at,
        replacement: pending_insertion,
      })
    }
  }
  for identity in atom_deletions {
    let element = elements[identity]
    edits.push({
      byte_start: element.byte_start,
      byte_end: element.byte_end,
      replacement: "",
    })
  }
  // Syntheses sharing one carrier AND one anchor are ONE element: two
  // insertions at the same position both rewrite the same `/>` or land at
  // the same offset, so emitting them separately would collide in phase 7
  // instead of composing. Replacements concatenate in request order, the
  // same rule equal-offset insertions into a `w:t` follow.
  let coalesced : Array[(Int, Int, Int, String, Int, Int)] = []
  for synthesis in syntheses {
    let (run_identity, anchor, consumed, replacement, ordinal, carrier) = synthesis
    let mut merged = false
    for index, existing in coalesced {
      let (
        other_run,
        other_anchor,
        other_consumed,
        other_text,
        other_ordinal,
        other_carrier,
      ) = existing
      if other_run == run_identity &&
        other_anchor == anchor &&
        other_consumed == consumed {
        coalesced[index] = (
          other_run,
          other_anchor,
          other_consumed,
          other_text + replacement,
          other_ordinal,
          other_carrier,
        )
        merged = true
        break
      }
    }
    if !merged {
      coalesced.push(
        (run_identity, anchor, consumed, replacement, ordinal, carrier),
      )
    }
  }
  for synthesis in coalesced {
    let (run_identity, anchor, consumed, replacement, _, _) = synthesis
    let run_element = elements[run_identity]
    let prefix = run_surgery_qualified_prefix(source, run_element)
    let escaped = run_surgery_escape(replacement) catch {
      _ =>
        raise partial_surgery_refuse(
          InternalPlanConflict,
          "replacement validity changed between phases",
        )
    }
    edits.push(
      run_surgery_synthesise_text(
        run_element,
        prefix,
        escaped,
        replacement,
        anchor~,
        consumed~,
      ),
    )
  }
  // A zero-width edit at a consuming edit's start must splice FIRST; the
  // sort key says so explicitly instead of leaning on an unstable sort's
  // accidental order (the trap run_surgery.mbt documents).
  let ordered : Array[(RunSurgeryEdit, Int)] = []
  for index, edit in edits {
    ordered.push((edit, index))
  }
  ordered.sort_by_key(entry => {
    (
      entry.0.byte_start,
      if entry.0.byte_end > entry.0.byte_start {
        1
      } else {
        0
      },
      entry.1,
    )
  })
  edits.clear()
  for entry in ordered {
    edits.push(entry.0)
  }
  // Phase 7: internal validation — the byte plan must be non-overlapping.
  let mut last_end = -1
  for edit in edits {
    if edit.byte_start < last_end {
      raise partial_surgery_refuse(
        InternalPlanConflict,
        "byte edits overlap in paragraph \{paragraph_index}",
      )
    }
    last_end = edit.byte_end
  }
  let _ = involved_elements
  // Receipt: the exact post-batch paragraph projection.
  let expected = StringBuilder()
  let mut cursor = 0
  for edit in requested {
    expected.write_string(
      before_projection
      .view(start_offset=cursor, end_offset=edit.start)
      .to_owned(),
    )
    expected.write_string(edit.replacement)
    cursor = edit.end
  }
  expected.write_string(before_projection.view(start_offset=cursor).to_owned())
  let receipt : PartialSurgeryReceipt = {
    paragraph_index,
    before_projection,
    expected_projection: expected.to_string(),
    logical_edits,
    byte_edit_count: edits.length(),
    touched_source_count: distinct_touched_sources(
      touched, atom_deletions, syntheses,
    ),
  }
  (edits, receipt)
}

///|
/// The number of DISTINCT source elements the plan touches: `w:t` hosts,
/// deleted atoms, and the atoms synthesis consumed or anchored beside —
/// counted once each regardless of how many logical edits involved them.
fn distinct_touched_sources(
  touched : Array[PartialSurgeryHost],
  atom_deletions : Array[Int],
  syntheses : Array[(Int, Int, Int, String, Int, Int)],
) -> Int {
  let seen : Array[Int] = []
  fn note(identity : Int) -> Unit {
    if !seen.contains(identity) {
      seen.push(identity)
    }
  }

  for host in touched {
    note(host.source_identity)
  }
  for identity in atom_deletions {
    note(identity)
  }
  for synthesis in syntheses {
    note(synthesis.5)
  }
  seen.length()
}
