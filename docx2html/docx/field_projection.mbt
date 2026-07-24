// N0b3 — source-pinned, story-wide complex-field classification over the
// provisional N0b2 reader order. A contribution retains only its innermost
// field identity; parent links on field records recover ancestry without
// copying a potentially deep stack onto every projected atom.

///|
#warnings("-unused_value")
priv enum ReaderOrderFieldRegion {
  OutsideField
  FieldInstruction
  FieldResult
  MalformedField
} derive(Debug, Eq)

///|
#warnings("-unused_value")
priv enum ReaderOrderFieldBoundarySide {
  BeforeCarrier
  AfterCarrier
} derive(Debug, Eq)

///|
#warnings("-unused_field")
priv struct ReaderOrderFieldBoundary {
  carrier_identity : Int
  side : ReaderOrderFieldBoundarySide
}

///|
#warnings("-unused_field")
priv struct ReaderOrderFieldInterval {
  start : ReaderOrderFieldBoundary
  mut end : ReaderOrderFieldBoundary?
}

///|
#warnings("-unused_field")
priv struct ReaderOrderField {
  identity : Int
  story_identity : Int
  parent_identity : Int?
  begin_marker_identity : Int
  begin_carrier_identity : Int
  instruction : ReaderOrderFieldInterval
  mut separate_marker_identity : Int?
  mut separate_carrier_identity : Int?
  mut result : ReaderOrderFieldInterval?
  mut end_marker_identity : Int?
  mut end_carrier_identity : Int?
  instruction_text : StringBuilder
  mut refusal_identity : Int?
}

///|
#warnings("-unused_value")
priv enum ReaderOrderFieldRefusalKind {
  AmbiguousCarrier
  UnknownTransition
  UnmatchedSeparate
  UnmatchedEnd
  DuplicateSeparate
  RepeatedMarker
  TruncatedField
} derive(Debug, Eq)

///|
#warnings("-unused_field")
priv struct ReaderOrderFieldRefusal {
  identity : Int
  kind : ReaderOrderFieldRefusalKind
  story_identity : Int
  carrier_identity : Int
  marker_identity : Int?
  field_identity : Int?
  source_span : ReaderOrderSourceSpan
}

///|
#warnings("-unused_field")
priv struct ReaderOrderFieldIndex {
  fields : Array[ReaderOrderField]
  refusals : Array[ReaderOrderFieldRefusal]
}

///|
fn empty_reader_order_field_index() -> ReaderOrderFieldIndex {
  { fields: [], refusals: [] }
}

///|
priv struct ReaderOrderFieldBudget {
  mut work_left : Int
  mut transitions_left : Int
  mut retained_state_left : Int
  mut instruction_chars_left : Int
  max_field_depth : Int
}

///|
let max_reader_order_field_work : Int = 16_000_000

///|
let max_reader_order_field_transitions : Int = 1_000_000

///|
let max_reader_order_field_retained_state : Int = 8_000_000

///|
let max_reader_order_field_instruction_chars : Int = 64 * 1024 * 1024

///|
let max_reader_order_field_depth : Int = 256

///|
fn reader_order_field_budget(
  max_work? : Int = max_reader_order_field_work,
  max_transitions? : Int = max_reader_order_field_transitions,
  max_retained_state? : Int = max_reader_order_field_retained_state,
  max_instruction_chars? : Int = max_reader_order_field_instruction_chars,
  max_field_depth? : Int = max_reader_order_field_depth,
) -> ReaderOrderFieldBudget raise DocxError {
  guard max_work >= 0 &&
    max_transitions >= 0 &&
    max_retained_state >= 0 &&
    max_instruction_chars >= 0 &&
    max_field_depth >= 0 else {
    raise Unsupported(
      message="reader-order field budget limits must be non-negative",
    )
  }
  {
    work_left: max_work,
    transitions_left: max_transitions,
    retained_state_left: max_retained_state,
    instruction_chars_left: max_instruction_chars,
    max_field_depth,
  }
}

///|
fn ReaderOrderFieldBudget::charge_work(
  self : ReaderOrderFieldBudget,
) -> Unit raise DocxError {
  guard self.work_left > 0 else {
    raise @core.docx_xml_resource_limit_error(DocxXmlTokens)
  }
  self.work_left -= 1
}

///|
fn ReaderOrderFieldBudget::charge_transition(
  self : ReaderOrderFieldBudget,
) -> Unit raise DocxError {
  guard self.transitions_left > 0 else {
    raise @core.docx_xml_resource_limit_error(DocxXmlTokens)
  }
  self.transitions_left -= 1
}

///|
fn ReaderOrderFieldBudget::charge_retained(
  self : ReaderOrderFieldBudget,
) -> Unit raise DocxError {
  guard self.retained_state_left > 0 else {
    raise @core.docx_xml_resource_limit_error(DocxXmlTokens)
  }
  self.retained_state_left -= 1
}

///|
fn ReaderOrderFieldBudget::charge_instruction(
  self : ReaderOrderFieldBudget,
  chars : Int,
) -> Unit raise DocxError {
  guard chars >= 0 && chars <= self.instruction_chars_left else {
    raise @core.docx_xml_resource_limit_error(DocxXmlMaterializedCharacters)
  }
  self.instruction_chars_left -= chars
}

///|
fn ReaderOrderFieldBudget::check_field_depth(
  self : ReaderOrderFieldBudget,
  depth : Int,
) -> Unit raise DocxError {
  guard depth > 0 && depth <= self.max_field_depth else {
    raise @core.docx_xml_resource_limit_error(DocxXmlNestingDepth)
  }
}

///|
priv struct ReaderOrderCarrierSummary {
  marker_identity : Int?
  marker_count : Int
}

///|
priv struct ReaderOrderCarrierClass {
  field_identity : Int?
  region : ReaderOrderFieldRegion
  refusal_identity : Int?
}

///|
priv struct ReaderOrderFieldStoryState {
  identity : Int
  stack : Array[Int]
  mut failed_refusal : Int?
}

///|
fn reader_order_field_story_identity(
  elements : Array[ScannedElement],
  paragraph_identity : Int,
  budget : ReaderOrderFieldBudget,
) -> Int raise DocxError {
  if elements.is_empty() {
    return 0
  }
  let root = elements[0]
  let mut current = paragraph_identity
  while current > 0 {
    budget.charge_work()
    let element = elements[current]
    if is_wml_uri(element.uri) && element.local_name == "txbxContent" {
      return current
    }
    if element.parent_index == 0 && is_wml_uri(element.uri) {
      let is_story_container = match root.local_name {
        "document" => element.local_name == "body"
        "footnotes" => element.local_name == "footnote"
        "endnotes" => element.local_name == "endnote"
        "comments" => element.local_name == "comment"
        _ => false
      }
      if is_wml_uri(root.uri) && is_story_container {
        return current
      }
    }
    current = element.parent_index
  }
  // A header/footer/body root, a standalone note/comment container, or a
  // malformed root that BodyReader still traverses is one story. Arbitrary
  // nested elements merely named body/comment/etc. never create a reset.
  0
}

///|
fn scan_reader_order_field_carrier(
  elements : Array[ScannedElement],
  identity : Int,
  instruction_target : StringBuilder?,
  budget : ReaderOrderFieldBudget,
) -> ReaderOrderCarrierSummary raise DocxError {
  let mut marker_identity : Int? = None
  let mut marker_count = 0
  fn visit(current : Int) -> Unit raise DocxError {
    budget.charge_work()
    let element = elements[current]
    if is_wml_uri(element.uri) {
      if element.local_name == "fldChar" {
        marker_count += 1
        if marker_identity is None {
          marker_identity = Some(current)
        }
      } else if element.local_name == "instrText" {
        match (instruction_target, element.text_map) {
          (Some(instruction), Some(mapped)) => {
            budget.charge_instruction(mapped.projection.length())
            instruction.write_string(mapped.projection)
          }
          _ => ()
        }
      }
    }
    let mut child = element.first_child_index
    while child >= 0 {
      visit(child)
      child = elements[child].next_sibling_index
    }
  }
  visit(identity)
  { marker_identity, marker_count }
}

///|
fn collect_reader_order_carrier_sources(
  elements : Array[ScannedElement],
  identity : Int,
  carrier_identity : Int,
  source_carriers : Map[Int, Int],
  budget : ReaderOrderFieldBudget,
) -> Unit raise DocxError {
  budget.charge_work()
  budget.charge_retained()
  source_carriers[identity] = carrier_identity
  let mut child = elements[identity].first_child_index
  while child >= 0 {
    collect_reader_order_carrier_sources(
      elements, child, carrier_identity, source_carriers, budget,
    )
    child = elements[child].next_sibling_index
  }
}

///|
fn reader_order_field_refusal_span(
  elements : Array[ScannedElement],
  marker_identity : Int?,
  carrier_identity : Int,
) -> ReaderOrderSourceSpan {
  match marker_identity {
    Some(identity) => reader_order_element_span(elements[identity])
    None => reader_order_element_span(elements[carrier_identity])
  }
}

///|
fn add_reader_order_field_refusal(
  index : ReaderOrderFieldIndex,
  state : ReaderOrderFieldStoryState,
  kind : ReaderOrderFieldRefusalKind,
  carrier_identity : Int,
  marker_identity : Int?,
  field_identity : Int?,
  elements : Array[ScannedElement],
  budget : ReaderOrderFieldBudget,
) -> Int raise DocxError {
  budget.charge_retained()
  let identity = index.refusals.length()
  index.refusals.push({
    identity,
    kind,
    story_identity: state.identity,
    carrier_identity,
    marker_identity,
    field_identity,
    source_span: if kind is AmbiguousCarrier {
      reader_order_element_span(elements[carrier_identity])
    } else {
      reader_order_field_refusal_span(
        elements, marker_identity, carrier_identity,
      )
    },
  })
  identity
}

///|
fn mark_reader_order_open_fields_failed(
  index : ReaderOrderFieldIndex,
  state : ReaderOrderFieldStoryState,
  refusal_identity : Int,
) -> Unit {
  for field_identity in state.stack {
    let field = index.fields[field_identity]
    if field.refusal_identity is None {
      field.refusal_identity = Some(refusal_identity)
    }
  }
  state.stack.clear()
  state.failed_refusal = Some(refusal_identity)
}

///|
fn reader_order_field_class_for_failed_story(
  state : ReaderOrderFieldStoryState,
) -> ReaderOrderCarrierClass {
  {
    field_identity: None,
    region: MalformedField,
    refusal_identity: state.failed_refusal,
  }
}

///|
fn reader_order_current_field_class(
  index : ReaderOrderFieldIndex,
  state : ReaderOrderFieldStoryState,
) -> ReaderOrderCarrierClass {
  match state.stack.last() {
    Some(field_identity) => {
      let field = index.fields[field_identity]
      {
        field_identity: Some(field_identity),
        region: if field.result is Some(_) {
          FieldResult
        } else {
          FieldInstruction
        },
        refusal_identity: field.refusal_identity,
      }
    }
    None =>
      { field_identity: None, region: OutsideField, refusal_identity: None }
  }
}

///|
fn fail_reader_order_field_story(
  index : ReaderOrderFieldIndex,
  state : ReaderOrderFieldStoryState,
  kind : ReaderOrderFieldRefusalKind,
  carrier_identity : Int,
  marker_identity : Int?,
  field_identity : Int?,
  elements : Array[ScannedElement],
  budget : ReaderOrderFieldBudget,
) -> ReaderOrderCarrierClass raise DocxError {
  let refusal = add_reader_order_field_refusal(
    index, state, kind, carrier_identity, marker_identity, field_identity, elements,
    budget,
  )
  mark_reader_order_open_fields_failed(index, state, refusal)
  { field_identity, region: MalformedField, refusal_identity: Some(refusal) }
}

///|
fn classify_reader_order_carrier(
  index : ReaderOrderFieldIndex,
  state : ReaderOrderFieldStoryState,
  summary : ReaderOrderCarrierSummary,
  carrier_identity : Int,
  elements : Array[ScannedElement],
  seen_markers : Map[Int, Int],
  budget : ReaderOrderFieldBudget,
) -> ReaderOrderCarrierClass raise DocxError {
  match state.failed_refusal {
    Some(_) => return reader_order_field_class_for_failed_story(state)
    None => ()
  }
  if summary.marker_count == 0 {
    return reader_order_current_field_class(index, state)
  }
  budget.charge_transition()
  let marker_identity = summary.marker_identity.unwrap_or(carrier_identity)
  if summary.marker_count > 1 {
    return fail_reader_order_field_story(
      index,
      state,
      AmbiguousCarrier,
      carrier_identity,
      Some(marker_identity),
      state.stack.last(),
      elements,
      budget,
    )
  }
  match seen_markers.get(marker_identity) {
    Some(_) =>
      return fail_reader_order_field_story(
        index,
        state,
        RepeatedMarker,
        carrier_identity,
        Some(marker_identity),
        state.stack.last(),
        elements,
        budget,
      )
    None => {
      budget.charge_retained()
      seen_markers[marker_identity] = state.identity
    }
  }
  let transition = elements[marker_identity].field_char_type
  match transition {
    Some("begin") => {
      budget.check_field_depth(state.stack.length() + 1)
      budget.charge_retained()
      let identity = index.fields.length()
      let parent_identity = state.stack.last()
      index.fields.push({
        identity,
        story_identity: state.identity,
        parent_identity,
        begin_marker_identity: marker_identity,
        begin_carrier_identity: carrier_identity,
        instruction: {
          start: { carrier_identity, side: AfterCarrier },
          end: None,
        },
        separate_marker_identity: None,
        separate_carrier_identity: None,
        result: None,
        end_marker_identity: None,
        end_carrier_identity: None,
        instruction_text: StringBuilder(),
        refusal_identity: None,
      })
      state.stack.push(identity)
      {
        field_identity: Some(identity),
        region: FieldInstruction,
        refusal_identity: None,
      }
    }
    Some("separate") =>
      match state.stack.last() {
        Some(field_identity) => {
          let field = index.fields[field_identity]
          if field.result is Some(_) {
            fail_reader_order_field_story(
              index,
              state,
              DuplicateSeparate,
              carrier_identity,
              Some(marker_identity),
              Some(field_identity),
              elements,
              budget,
            )
          } else {
            field.instruction.end = Some({
              carrier_identity,
              side: BeforeCarrier,
            })
            field.separate_marker_identity = Some(marker_identity)
            field.separate_carrier_identity = Some(carrier_identity)
            field.result = Some({
              start: { carrier_identity, side: AfterCarrier },
              end: None,
            })
            {
              field_identity: Some(field_identity),
              region: FieldResult,
              refusal_identity: None,
            }
          }
        }
        None =>
          fail_reader_order_field_story(
            index,
            state,
            UnmatchedSeparate,
            carrier_identity,
            Some(marker_identity),
            None,
            elements,
            budget,
          )
      }
    Some("end") =>
      match state.stack.pop() {
        Some(field_identity) => {
          let field = index.fields[field_identity]
          let region = match field.result {
            Some(result) => {
              result.end = Some({ carrier_identity, side: BeforeCarrier })
              FieldResult
            }
            None => {
              field.instruction.end = Some({
                carrier_identity,
                side: BeforeCarrier,
              })
              FieldInstruction
            }
          }
          field.end_marker_identity = Some(marker_identity)
          field.end_carrier_identity = Some(carrier_identity)
          {
            field_identity: Some(field_identity),
            region,
            refusal_identity: field.refusal_identity,
          }
        }
        None =>
          fail_reader_order_field_story(
            index,
            state,
            UnmatchedEnd,
            carrier_identity,
            Some(marker_identity),
            None,
            elements,
            budget,
          )
      }
    _ =>
      fail_reader_order_field_story(
        index,
        state,
        UnknownTransition,
        carrier_identity,
        Some(marker_identity),
        state.stack.last(),
        elements,
        budget,
      )
  }
}

///|
fn apply_reader_order_carrier_class(
  contributions : Array[ReaderOrderContribution],
  source_carriers : Map[Int, Int],
  classes : Map[Int, ReaderOrderCarrierClass],
  budget : ReaderOrderFieldBudget,
) -> Unit raise DocxError {
  for contribution in contributions {
    budget.charge_work()
    match source_carriers.get(contribution.source_identity) {
      Some(carrier_identity) =>
        match classes.get(carrier_identity) {
          Some(classification) => {
            contribution.field_identity = classification.field_identity
            contribution.field_region = classification.region
            contribution.field_refusal = classification.refusal_identity
          }
          None => ()
        }
      None => ()
    }
  }
}

///|
fn finish_reader_order_field_story(
  index : ReaderOrderFieldIndex,
  state : ReaderOrderFieldStoryState,
  elements : Array[ScannedElement],
  budget : ReaderOrderFieldBudget,
) -> Unit raise DocxError {
  if state.failed_refusal is Some(_) {
    return
  }
  for field_identity in state.stack {
    let field = index.fields[field_identity]
    let refusal = add_reader_order_field_refusal(
      index,
      state,
      TruncatedField,
      field.begin_carrier_identity,
      Some(field.begin_marker_identity),
      Some(field_identity),
      elements,
      budget,
    )
    field.refusal_identity = Some(refusal)
  }
  state.stack.clear()
}

///|
fn classify_reader_order_fields(
  projection : ReaderOrderProjection,
  budget? : ReaderOrderFieldBudget,
) -> ReaderOrderFieldIndex raise DocxError {
  let budget = match budget {
    Some(value) => value
    None => reader_order_field_budget()
  }
  let index = empty_reader_order_field_index()
  let contributions_by_paragraph : Map[Int, Array[ReaderOrderContribution]] = Map([],
  )
  for paragraph in projection.paragraphs {
    for contribution in paragraph.contributions {
      budget.charge_work()
      budget.charge_retained()
      match contributions_by_paragraph.get(contribution.paragraph_identity) {
        Some(items) => items.push(contribution)
        None =>
          contributions_by_paragraph[contribution.paragraph_identity] = [
            contribution,
          ]
      }
    }
  }
  let states : Array[ReaderOrderFieldStoryState] = []
  let state_by_story : Map[Int, ReaderOrderFieldStoryState] = Map([])
  let seen_paragraphs : Map[Int, Bool] = Map([])
  let seen_markers : Map[Int, Int] = Map([])
  for paragraph in projection.paragraphs {
    for source in paragraph.sources {
      let paragraph_identity = source.identity
      if seen_paragraphs.contains(paragraph_identity) {
        continue
      }
      budget.charge_retained()
      seen_paragraphs[paragraph_identity] = true
      let story_identity = reader_order_field_story_identity(
        projection.source_elements,
        paragraph_identity,
        budget,
      )
      let state = match state_by_story.get(story_identity) {
        Some(value) => value
        None => {
          budget.charge_retained()
          let value = ReaderOrderFieldStoryState::{
            identity: story_identity,
            stack: [],
            failed_refusal: None,
          }
          states.push(value)
          state_by_story[story_identity] = value
          value
        }
      }
      let classes : Map[Int, ReaderOrderCarrierClass] = Map([])
      let source_carriers : Map[Int, Int] = Map([])
      let mut carrier = projection.source_elements[paragraph_identity].first_child_index
      while carrier >= 0 {
        budget.charge_retained()
        collect_reader_order_carrier_sources(
          projection.source_elements,
          carrier,
          carrier,
          source_carriers,
          budget,
        )
        let summary = match state.failed_refusal {
          Some(_) => { marker_identity: None, marker_count: 0 }
          None => {
            // BodyReader collects all instruction text in the carrier before
            // it interprets the carrier's first descendant field marker.
            let instruction_target = match state.stack.last() {
              Some(field_identity) =>
                if index.fields[field_identity].result is None {
                  Some(index.fields[field_identity].instruction_text)
                } else {
                  None
                }
              None => None
            }
            scan_reader_order_field_carrier(
              projection.source_elements,
              carrier,
              instruction_target,
              budget,
            )
          }
        }
        classes[carrier] = classify_reader_order_carrier(
          index,
          state,
          summary,
          carrier,
          projection.source_elements,
          seen_markers,
          budget,
        )
        carrier = projection.source_elements[carrier].next_sibling_index
      }
      match contributions_by_paragraph.get(paragraph_identity) {
        Some(contributions) =>
          apply_reader_order_carrier_class(
            contributions, source_carriers, classes, budget,
          )
        None => ()
      }
    }
  }
  for state in states {
    finish_reader_order_field_story(
      index,
      state,
      projection.source_elements,
      budget,
    )
  }
  // Refusals discovered at story completion (truncated fields) or after a
  // later malformed carrier also apply to contributions classified earlier.
  // Refresh the cached refusal id from the stable field record once every
  // story has been finalized.
  for paragraph in projection.paragraphs {
    for contribution in paragraph.contributions {
      budget.charge_work()
      match contribution.field_identity {
        Some(field_identity) =>
          contribution.field_refusal = index.fields[field_identity].refusal_identity
        None => ()
      }
    }
  }
  index
}
