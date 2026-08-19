// Field classification over the reader-native projection (#434 PR 6b):
// the ONE field state machine runs over exactly what it consumes -- each
// contribution's source identity and owning physical paragraph, the
// carrier event stream, and the scan itself -- through annotation slots,
// and the three field annotations are copied back per contribution. No
// facade: neither projection fabricates the other's contribution type.

///|
/// The physical paragraph owning a source, for carrier resolution: the
/// nearest `w:p` ancestor. Content outside every paragraph gets a sentinel
/// no parent index can equal, so its carrier resolves to `None` exactly as
/// the legacy walker's flow-level contributions do.
fn reader_projection_owning_paragraph(
  elements : Array[ScannedElement],
  source_identity : Int,
  budget : ReaderOrderFieldBudget,
) -> Int raise DocxError {
  let mut current = elements[source_identity].parent_index
  while current >= 0 {
    budget.charge_work()
    let element = elements[current]
    if is_wml_uri(element.uri) && element.local_name == "p" {
      return current
    }
    current = element.parent_index
  }
  -2
}

///|
/// Classifies complex fields over a reader-native projection: one slot
/// per contribution, the machine run once, annotations copied back and
/// the index stored. A separate post-adapter step, exactly as the legacy
/// pipeline separates the walk from classification.
fn classify_reader_projection_fields(
  projection : ReaderProjection,
  budget? : ReaderOrderFieldBudget,
) -> Unit raise DocxError {
  let budget = match budget {
    Some(value) => value
    None => reader_order_field_budget()
  }
  let elements = projection.scan.elements()
  let slots : Array[ReaderFieldSlot] = []
  let sources : Array[ReaderProjectionContribution] = []
  for paragraph in projection.paragraphs {
    budget.charge_work()
    for contribution in paragraph.contributions {
      budget.charge_work()
      let SourceElementId(source_identity) = contribution.source
      slots.push({
        source_identity,
        paragraph_identity: reader_projection_owning_paragraph(
          elements, source_identity, budget,
        ),
        field_identity: None,
        field_region: OutsideField,
        field_refusal: None,
      })
      sources.push(contribution)
    }
  }
  let index = classify_reader_field_slots(
    elements,
    projection.field_carriers,
    slots,
    budget,
  )
  for at, slot in slots {
    budget.charge_work()
    let contribution = sources[at]
    contribution.field_identity = slot.field_identity
    contribution.field_region = slot.field_region
    contribution.field_refusal = slot.field_refusal
  }
  projection.field_index = index
}
