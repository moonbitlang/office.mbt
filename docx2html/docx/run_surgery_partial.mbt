///|
/// N0c2 partial token-boundary surgery, increment B1: batch-shaped edits
/// whose every logical range lies inside ONE mapped ordinary `w:t` of one
/// physical paragraph. Ranges are paragraph-local UTF-16 offsets into the
/// paragraph's reader projection; the token map resolves them to source
/// bytes, so bytes outside the declared edit union are never rewritten and
/// entity spellings outside the union are never canonicalized.
///
/// Later increments extend the same batch shape: B2a crosses `w:t` and atom
/// boundaries inside one run, B2b crosses runs, B3 generalizes multi-edit
/// composition. The refusal vocabulary below is the stable N0c2 taxonomy;
/// this increment raises the subset it can reach.
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
    RestrictedRegion => "the edit range crosses a restricted region"
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
/// One host `w:t` and the wt-local logical edits that landed in it.
priv struct PartialSurgeryHost {
  source_identity : Int
  contribution_value : String
  local_edits : Array[(Int, Int, String)]
}

///|
/// Plan a batch of partial text edits inside one physical paragraph.
///
/// Refusal precedence is deterministic: request shape/order/overlap, then
/// paragraph ownership, then structural restrictions on each host, then
/// endpoint resolution, then interval barriers, then replacement validity,
/// then internal byte-plan validation. On refusal nothing is returned.
fn plan_paragraph_text_edits(
  projection : ReaderProjection,
  source : BytesView,
  paragraph_index : Int,
  requested : Array[ParagraphTextEdit],
) -> (Array[RunSurgeryEdit], PartialSurgeryReceipt) raise DocxError {
  // 1. Request shape.
  guard paragraph_index >= 0 && paragraph_index < projection.paragraphs.length() else {
    raise partial_surgery_refuse(
      InvalidParagraph,
      "paragraph \{paragraph_index}",
    )
  }
  let paragraph = projection.paragraphs[paragraph_index]
  let width = paragraph.projection_end - paragraph.projection_start
  let mut previous_end = 0
  let mut previous_start = -1
  for ordinal, edit in requested {
    guard edit.start >= 0 && edit.start <= edit.end && edit.end <= width else {
      raise partial_surgery_refuse(
        InvalidRange,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    guard edit.start >= previous_start &&
      (
        edit.start > previous_start ||
        ordinal == 0 ||
        edit.start == previous_end
      ) else {
      raise partial_surgery_refuse(
        UnorderedEdits,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    if ordinal > 0 && edit.start < previous_end {
      raise partial_surgery_refuse(
        LogicalOverlap,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    previous_start = edit.start
    previous_end = edit.end
  }
  // 2. Paragraph ownership: one physical source, and no host run shared with
  // another logical paragraph (checked per host below).
  guard paragraph.sources.length() == 1 else {
    raise partial_surgery_refuse(
      MultiPhysicalParagraph,
      "paragraph \{paragraph_index} has \{paragraph.sources.length()} physical sources",
    )
  }
  let elements = projection.scan.elements()
  // Locate each edit's host contribution and validate its structure. Hosts
  // are keyed by source identity so several edits in one `w:t` share one
  // post-batch xml:space decision.
  let hosts : Array[PartialSurgeryHost] = []
  let logical_edits : Array[PartialSurgeryLogicalEdit] = []
  for ordinal, edit in requested {
    let mut host_contribution : ReaderProjectionContribution? = None
    let mut host_candidates = 0
    for contribution in paragraph.contributions {
      let c_start = contribution.projection_start - paragraph.projection_start
      let c_end = contribution.projection_end - paragraph.projection_start
      guard contribution.kind is ProjectedText(FromText) else {
        // 5. Interval barriers. Inside one mapped `w:t` no other
        // contribution can sit STRICTLY inside the range (coordinates are
        // assigned by accumulation), so any hit here is crossing.
        if contribution.projection_start == contribution.projection_end &&
          c_start > edit.start &&
          c_start < edit.end {
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
            _ => ()
          }
        }
        continue
      }
      if c_start <= edit.start && edit.end <= c_end {
        host_candidates += 1
        if host_contribution is None {
          host_contribution = Some(contribution)
        }
      }
    }
    guard host_contribution is Some(host) else {
      raise partial_surgery_refuse(
        UnsupportedTextSource,
        "edit \{ordinal} in paragraph \{paragraph_index} has no single mapped text host (cross-contribution ranges are a later increment)",
      )
    }
    if host_candidates > 1 {
      // Only zero-width edits at a boundary shared by two text hosts can
      // reach this: refuse rather than pick.
      raise partial_surgery_refuse(
        AmbiguousBoundary,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    // 3. Structural restrictions on the host.
    match host.field_region {
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
    guard host.run_source is Some(host_run_source) else {
      raise partial_surgery_refuse(
        UnsupportedTextSource,
        "edit \{ordinal} in paragraph \{paragraph_index} has no owning run",
      )
    }
    let mut host_run : ReaderProjectionRun? = None
    for run in paragraph.runs {
      if run.source == host_run_source {
        host_run = Some(run)
      }
    }
    guard host_run is Some(run) else {
      raise partial_surgery_refuse(
        InternalPlanConflict,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
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
    let SourceElementId(host_identity) = host.source
    let host_element = elements[host_identity]
    if run_surgery_inside_checkbox_control(elements, host_element) {
      raise partial_surgery_refuse(
        PartialCheckboxControl,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    // The same element projected through two contributions cannot be edited
    // through either.
    let mut projections_of_host = 0
    for contribution in paragraph.contributions {
      if contribution.source == host.source &&
        contribution.kind is ProjectedText(_) {
        projections_of_host += 1
      }
    }
    if projections_of_host > 1 {
      raise partial_surgery_refuse(
        DuplicateSource,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    // A host run shared with another logical paragraph makes the plan
    // incomplete for one of them.
    for index, other in projection.paragraphs {
      if index != paragraph_index {
        for candidate in other.runs {
          if candidate.source == host_run_source {
            raise partial_surgery_refuse(
              CrossParagraphSourceReuse,
              "edit \{ordinal} in paragraph \{paragraph_index} reuses a run of paragraph \{index}",
            )
          }
        }
      }
    }
    guard is_wml_uri(host_element.uri) && host_element.local_name == "t" else {
      raise partial_surgery_refuse(
        UnsupportedTextSource,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    guard host_element.text_map is Some(map) else {
      // Self-closing `<w:t/>` has no interior byte positions; converting its
      // `/>` is a later increment's synthesis concern.
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
    let host_local_start = edit.start -
      (host.projection_start - paragraph.projection_start)
    let host_local_end = edit.end -
      (host.projection_start - paragraph.projection_start)
    // 4. Endpoint resolution through the token map.
    guard map.byte_offset_at(host_local_start) is Some(_) &&
      map.byte_offset_at(host_local_end) is Some(_) else {
      raise partial_surgery_refuse(
        NonScalarBoundary,
        "edit \{ordinal} in paragraph \{paragraph_index}",
      )
    }
    // Logical no-ops are decided on the PROJECTION, before any lexical
    // rewriting, so replacing a reference-spelled character with itself
    // never canonicalizes its spelling.
    let replaced = host.value
      .view(start_offset=host_local_start, end_offset=host_local_end)
      .to_owned()
    if replaced == edit.replacement {
      logical_edits.push({
        ordinal,
        start: edit.start,
        end: edit.end,
        replacement: edit.replacement,
        placement: LogicalNoOp,
      })
      continue
    }
    logical_edits.push({
      ordinal,
      start: edit.start,
      end: edit.end,
      replacement: edit.replacement,
      placement: InsideText,
    })
    let mut host_record : PartialSurgeryHost? = None
    for record in hosts {
      if record.source_identity == host_identity {
        host_record = Some(record)
      }
    }
    match host_record {
      Some(record) =>
        record.local_edits.push(
          (host_local_start, host_local_end, edit.replacement),
        )
      None =>
        hosts.push({
          source_identity: host_identity,
          contribution_value: host.value,
          local_edits: [(host_local_start, host_local_end, edit.replacement)],
        })
    }
  }
  // 6. Replacement validity, byte planning per host.
  let edits : Array[RunSurgeryEdit] = []
  for host in hosts {
    let SourceElementId(_) = SourceElementId(host.source_identity)
    let element = elements[host.source_identity]
    guard element.text_map is Some(map) else {
      raise partial_surgery_refuse(InternalPlanConflict, "host lost its map")
    }
    // The post-batch content of this `w:t` decides xml:space once.
    let after = StringBuilder::new()
    let mut cursor = 0
    for local in host.local_edits {
      let (local_start, local_end, replacement) = local
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
        if wants_space {
          edits.push({
            byte_start: from,
            byte_end: to,
            replacement: "xml:space=\"preserve\"",
          })
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
    // Content splices. Equal-offset pure insertions were concatenated by
    // construction (ordered, non-overlapping logical edits become ordered
    // wt-local edits); the splice layer's (start, consuming) tiebreak
    // handles an insertion abutting a consuming edit deterministically.
    let mut pending_insertion_at = -1
    let mut pending_insertion = ""
    for local in host.local_edits {
      let (local_start, local_end, replacement) = local
      guard map.byte_offset_at(local_start) is Some(byte_from) &&
        map.byte_offset_at(local_end) is Some(byte_to) else {
        raise partial_surgery_refuse(
          InternalPlanConflict,
          "endpoint resolution changed between passes",
        )
      }
      let escaped = run_surgery_escape(replacement) catch {
        Unsupported(message~) =>
          raise partial_surgery_refuse(InvalidReplacement, message)
        error => raise error
      }
      if byte_from == byte_to {
        // Concatenate same-offset pure insertions in request order rather
        // than relying on any downstream ordering of identical keys.
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
  edits.sort_by_key(edit => edit.byte_start)
  // 7. Internal validation: our own byte plan must be non-overlapping.
  let mut last_end = -1
  let mut last_start = -1
  for edit in edits {
    if edit.byte_start < last_end ||
      (
        edit.byte_start == last_start &&
        edit.byte_end > edit.byte_start &&
        last_end > last_start
      ) {
      raise partial_surgery_refuse(
        InternalPlanConflict,
        "byte edits overlap in paragraph \{paragraph_index}",
      )
    }
    last_start = edit.byte_start
    last_end = edit.byte_end
  }
  // Receipt: the exact post-batch paragraph projection.
  let before = StringBuilder::new()
  for contribution in paragraph.contributions {
    before.write_string(contribution.value)
  }
  let before_projection = before.to_string()
  let expected = StringBuilder::new()
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
    touched_source_count: hosts.length(),
  }
  (edits, receipt)
}
