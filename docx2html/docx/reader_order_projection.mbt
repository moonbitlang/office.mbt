// A bounded, private reader-order view over N0b1's physical source identities,
// with story-wide complex-field classification, the reader's content-control
// and Markup Compatibility transforms, and final logical paths and UTF-16
// projection intervals. N0c consumes these ordered physical contributors,
// their source-pinned field provenance, and the `p[i]/r[j]` addresses that
// let an edit name a run.

///|
#warnings("-unused_field")
priv struct ReaderOrderSourceSpan {
  byte_start : Int
  byte_end : Int
}

///|
#warnings("-unused_value")
priv enum ProvisionalContributionKind {
  TextAtom
  TabAtom
  NoBreakHyphenAtom
  SoftHyphenAtom
  SymbolAtom
  TransparentSeam
  HardBarrier
} derive(Debug)

///|
/// One reader-visible atom or zero-width boundary. Its identity always indexes
/// `ReaderOrderProjection.source_elements`; `source_span` is a physical byte
/// range, while `projection_start`/`projection_end` locate it in the reader's
/// story and `logical_run_index` names its run.
#warnings("-unused_field-unused_mut")
priv struct ReaderOrderContribution {
  kind : ProvisionalContributionKind
  value : String
  source_identity : Int
  paragraph_identity : Int
  run_identity : Int?
  source_span : ReaderOrderSourceSpan
  mut field_identity : Int?
  mut field_region : ReaderOrderFieldRegion
  mut field_refusal : Int?
  /// Half-open interval this contribution occupies in the reader's story
  /// text, in UTF-16 code units. Assigned only after every transform and
  /// suppression decision, because a contribution the checkbox transform
  /// blanked contributes nothing and must occupy an empty interval even
  /// though its source span still names real bytes.
  ///
  /// Zero-width contributions -- seams and barriers -- get an empty interval
  /// at the position they sit, which is what makes them usable as insertion
  /// points.
  mut projection_start : Int
  mut projection_end : Int
  /// Index of this contribution's run within its reader paragraph, by order of
  /// first appearance, or -1 when it belongs to no run. With the paragraph's
  /// own index this is the `p[i]/r[j]` address surgery will edit through.
  mut logical_run_index : Int
}

///|
#warnings("-unused_field")
priv struct ReaderOrderRunSource {
  identity : Int
  source_span : ReaderOrderSourceSpan
}

///|
/// One physical paragraph contributing to a reader paragraph. Deleted
/// paragraph-mark prefixes remain separate entries here even though their
/// contents are joined into the terminal paragraph by BodyReader.
#warnings("-unused_field")
priv struct ReaderOrderParagraphSource {
  identity : Int
  source_span : ReaderOrderSourceSpan
  runs : Array[ReaderOrderRunSource]
}

///|
#warnings("-unused_field")
priv struct ReaderOrderParagraph {
  from_text_box : Bool
  sources : Array[ReaderOrderParagraphSource]
  contributions : Array[ReaderOrderContribution]
  /// Position of this paragraph in the reader's story, and the interval it
  /// occupies there. Both assigned by `assign_reader_order_logical_coordinates`.
  mut logical_index : Int
  mut projection_start : Int
  mut projection_end : Int
}

///|
/// One direct physical paragraph child observed at the same point where
/// BodyReader begins interpreting that carrier. Keeping this event stream on
/// the N0b2 walk preserves recursive block order for N0b3 without reconstructing
/// it from the completed paragraph segments. Each event follows a charged N0b2
/// node visit, so the reader-order visit budget also bounds retained events.
priv struct ReaderOrderFieldCarrierEvent {
  paragraph_identity : Int
  carrier_identity : Int
}

///|
/// Private result. `source_part` identifies the OPC part. Physical coordinates
/// are exact source identities and byte spans; logical ones are the paragraph
/// index, run index and UTF-16 story interval assigned once every transform
/// has run.
#warnings("-unused_field")
priv struct ReaderOrderProjection {
  source_part : String
  source_elements : Array[ScannedElement]
  paragraphs : Array[ReaderOrderParagraph]
  field_carriers : Array[ReaderOrderFieldCarrierEvent]
  mut field_index : ReaderOrderFieldIndex
}

///|
/// Cumulative N0b2 limits. Traversal work is charged on every visit, including
/// the reader's separate textbox pass; repeated visits therefore cannot evade
/// the bound. `retained_contributors_left` covers output records and pending
/// deleted-paragraph prefixes.
priv struct ReaderOrderBudget {
  mut node_visits_left : Int
  mut projected_chars_left : Int
  mut retained_contributors_left : Int
  max_depth : Int
}

///|
let max_reader_order_node_visits : Int = 4_000_000

///|
let max_reader_order_projected_chars : Int = 64 * 1024 * 1024

///|
let max_reader_order_retained_contributors : Int = 3_000_000

///|
let max_reader_order_depth : Int = 256

///|
fn reader_order_budget(
  max_node_visits? : Int = max_reader_order_node_visits,
  max_projected_chars? : Int = max_reader_order_projected_chars,
  max_retained_contributors? : Int = max_reader_order_retained_contributors,
  max_depth? : Int = max_reader_order_depth,
) -> ReaderOrderBudget raise DocxError {
  guard max_node_visits >= 0 &&
    max_projected_chars >= 0 &&
    max_retained_contributors >= 0 &&
    max_depth >= 0 else {
    raise Unsupported(
      message="reader-order projection budget limits must be non-negative",
    )
  }
  {
    node_visits_left: max_node_visits,
    projected_chars_left: max_projected_chars,
    retained_contributors_left: max_retained_contributors,
    max_depth,
  }
}

///|
fn ReaderOrderBudget::charge_visit(
  self : ReaderOrderBudget,
  depth : Int,
) -> Unit raise DocxError {
  guard self.node_visits_left > 0 else {
    raise @core.docx_xml_resource_limit_error(DocxXmlTokens)
  }
  guard depth > 0 && depth <= self.max_depth else {
    raise @core.docx_xml_resource_limit_error(DocxXmlNestingDepth)
  }
  self.node_visits_left -= 1
}

///|
fn ReaderOrderBudget::charge_text(
  self : ReaderOrderBudget,
  chars : Int,
) -> Unit raise DocxError {
  guard chars >= 0 && chars <= self.projected_chars_left else {
    raise @core.docx_xml_resource_limit_error(DocxXmlMaterializedCharacters)
  }
  self.projected_chars_left -= chars
}

///|
fn ReaderOrderBudget::charge_contributor(
  self : ReaderOrderBudget,
) -> Unit raise DocxError {
  guard self.retained_contributors_left > 0 else {
    raise @core.docx_xml_resource_limit_error(DocxXmlTokens)
  }
  self.retained_contributors_left -= 1
}

///|
priv struct PendingDeletedParagraph {
  identity : Int
  depth : Int
}

///|
/// Mutable inline projection state for one physical paragraph. Tolerant
/// BodyReader inputs can contain block elements below wrappers that normally
/// carry inline content. A nested block closes the current reader paragraph,
/// so the state retains completed segments while traversal resumes in a fresh
/// segment backed by the same outer physical paragraph/run.
priv struct ReaderOrderInlineState {
  mut current : ReaderOrderParagraph
  mut source_by_identity : Map[Int, ReaderOrderParagraphSource]
  completed : Array[ReaderOrderParagraph]
  active_runs : Array[Int]
  from_text_box : Bool
}

///|
const READER_ORDER_VML_URI : String = "urn:schemas-microsoft-com:vml"

///|
const READER_ORDER_TRANSITIONAL_WORDPROCESSING_DRAWING_URI : String = "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing"

///|
const READER_ORDER_STRICT_WORDPROCESSING_DRAWING_URI : String = "http://purl.oclc.org/ooxml/drawingml/wordprocessingDrawing"

///|
fn reader_order_element_span(element : ScannedElement) -> ReaderOrderSourceSpan {
  { byte_start: element.byte_start, byte_end: element.byte_end }
}

///|
fn reader_order_atom_span(element : ScannedElement) -> ReaderOrderSourceSpan {
  if is_wml_uri(element.uri) &&
    element.local_name == "t" &&
    element.text_map is Some(_) {
    { byte_start: element.content_start, byte_end: element.content_end }
  } else {
    reader_order_element_span(element)
  }
}

///|
priv enum ReaderOrderBodyOutputKind {
  ReaderOrderTableRow
  ReaderOrderTableCell
  ReaderOrderOther
}

///|
fn reader_order_body_output_kind(
  element : ScannedElement,
  reader_image_outputs : Array[Bool],
) -> ReaderOrderBodyOutputKind? {
  if is_wml_uri(element.uri) {
    match element.local_name {
      "tr" => Some(ReaderOrderTableRow)
      "tc" => Some(ReaderOrderTableCell)
      "p"
      | "r"
      | "t"
      | "tab"
      | "noBreakHyphen"
      | "softHyphen"
      | "footnoteReference"
      | "endnoteReference"
      | "commentReference"
      | "tbl" => Some(ReaderOrderOther)
      "sym" =>
        if symbol_to_unicode(
            element.symbol_font.unwrap_or(""),
            element.symbol_char.unwrap_or(""),
          )
          is Some(_) {
          Some(ReaderOrderOther)
        } else {
          None
        }
      "br" =>
        if element.break_type
          is (None | Some("textWrapping") | Some("page") | Some("column")) {
          Some(ReaderOrderOther)
        } else {
          None
        }
      "bookmarkStart" =>
        if element.bookmark_name == Some("_GoBack") {
          None
        } else {
          Some(ReaderOrderOther)
        }
      "hyperlink" =>
        if (element.hyperlink_relationship_id is Some(id) && id != "") ||
          (element.hyperlink_anchor is Some(anchor) && anchor != "") {
          Some(ReaderOrderOther)
        } else {
          None
        }
      _ => None
    }
  } else if reader_order_is_image_output_element(element) &&
    element.identity >= 0 &&
    element.identity < reader_image_outputs.length() &&
    reader_image_outputs[element.identity] {
    Some(ReaderOrderOther)
  } else {
    None
  }
}

///|
fn reader_order_is_image_output_element(element : ScannedElement) -> Bool {
  (
    (
      element.uri == READER_ORDER_TRANSITIONAL_WORDPROCESSING_DRAWING_URI ||
      element.uri == READER_ORDER_STRICT_WORDPROCESSING_DRAWING_URI
    ) &&
    element.local_name is ("inline" | "anchor")
  ) ||
  (element.uri == READER_ORDER_VML_URI && element.local_name == "imagedata")
}

///|
fn reader_order_is_vml_flattening_container(element : ScannedElement) -> Bool {
  element.uri == READER_ORDER_VML_URI &&
  element.local_name is ("roundrect" | "shape" | "textbox" | "group" | "rect")
}

///|
fn reader_order_is_body_flattening_container(element : ScannedElement) -> Bool {
  is_transparent_container(element.uri, element.local_name) ||
  (
    is_wml_uri(element.uri) &&
    element.local_name == "hyperlink" &&
    !(element.hyperlink_relationship_id is Some(id) && id != "") &&
    !(element.hyperlink_anchor is Some(anchor) && anchor != "")
  ) ||
  reader_order_is_vml_flattening_container(element)
}

///|
fn reader_order_first_direct_wml_child(
  elements : Array[ScannedElement],
  parent_identity : Int,
  local_name : String,
  depth : Int,
  budget : ReaderOrderBudget,
) -> Int? raise DocxError {
  let mut child = elements[parent_identity].first_child_index
  while child >= 0 {
    let element = elements[child]
    budget.charge_visit(depth)
    if is_wml_uri(element.uri) && element.local_name == local_name {
      return Some(child)
    }
    child = element.next_sibling_index
  }
  None
}

///|
/// The Markup Compatibility counterpart of `reader_order_first_direct_wml_child`.
fn reader_order_first_direct_mc_child(
  elements : Array[ScannedElement],
  parent_identity : Int,
  local_name : String,
  depth : Int,
  budget : ReaderOrderBudget,
) -> Int? raise DocxError {
  let mut child = elements[parent_identity].first_child_index
  while child >= 0 {
    let element = elements[child]
    budget.charge_visit(depth)
    if element.uri == MC_URI && element.local_name == local_name {
      return Some(child)
    }
    child = element.next_sibling_index
  }
  None
}

///|
fn reader_order_is_deleted_body_paragraph(
  elements : Array[ScannedElement],
  paragraph_identity : Int,
  paragraph_depth : Int,
  budget : ReaderOrderBudget,
) -> Bool raise DocxError {
  match
    reader_order_first_direct_wml_child(
      elements,
      paragraph_identity,
      "pPr",
      paragraph_depth + 1,
      budget,
    ) {
    Some(properties) =>
      match
        reader_order_first_direct_wml_child(
          elements,
          properties,
          "rPr",
          paragraph_depth + 2,
          budget,
        ) {
        Some(run_properties) =>
          reader_order_first_direct_wml_child(
            elements,
            run_properties,
            "del",
            paragraph_depth + 3,
            budget,
          )
          is Some(_)
        None => false
      }
    None => false
  }
}

///|
fn restore_reader_projection_subtree(
  elements : Array[ScannedElement],
  visible : Array[Bool],
  merged_by_vmerge : Array[Bool],
  identity : Int,
  depth : Int,
  budget : ReaderOrderBudget,
) -> Unit raise DocxError {
  guard identity >= 0 && identity < elements.length() else { return }
  budget.charge_visit(depth)
  let element = elements[identity]
  if element.deleted_table_row {
    return
  }
  if merged_by_vmerge[identity] {
    return
  }
  if projection_kind(element.uri, element.local_name) is Some(_) {
    visible[identity] = true
  }
  let mut child = element.first_child_index
  while child >= 0 {
    let child_element = elements[child]
    restore_reader_projection_subtree(
      elements,
      visible,
      merged_by_vmerge,
      child,
      depth + 1,
      budget,
    )
    child = child_element.next_sibling_index
  }
}

///|
/// The `"\n\n"` `BodyReader` writes between paragraphs, in UTF-16 units.
let reader_order_paragraph_separator_units : Int = 2
