// N0b2 — a bounded, private reader-order view over N0b1's physical source
// identities. This layer deliberately stops before field classification,
// SDT/Markup Compatibility transforms, final logical paths, and UTF-16
// intervals. Later N0b slices consume these ordered physical contributors.

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
/// One provisional reader-visible atom or zero-width boundary. Its identity
/// always indexes `ReaderOrderProjection.source_elements`; byte spans are
/// physical source coordinates only. No logical or projection interval is
/// assigned in N0b2.
#warnings("-unused_field")
priv struct ReaderOrderContribution {
  kind : ProvisionalContributionKind
  value : String
  source_identity : Int
  paragraph_identity : Int
  run_identity : Int?
  source_span : ReaderOrderSourceSpan
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
}

///|
/// Private N0b2 result. `source_part` identifies the OPC part, while every
/// other coordinate remains an exact N0b1 identity or physical byte span.
#warnings("-unused_field")
priv struct ReaderOrderProjection {
  source_part : String
  source_elements : Array[ScannedElement]
  paragraphs : Array[ReaderOrderParagraph]
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
priv struct ReaderOrderWalker {
  elements : Array[ScannedElement]
  projection_visible : Array[Bool]
  budget : ReaderOrderBudget
  paragraphs : Array[ReaderOrderParagraph]
}

///|
const READER_ORDER_VML_URI : String = "urn:schemas-microsoft-com:vml"

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
  } else {
    None
  }
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
/// Mirrors the `read_children`/`read_element` wrappers that can flatten rows,
/// cells, or unexpected body elements into a table's immediate logical
/// children. The returned identities name the physical elements that emitted
/// those logical children; suppressed revisions and deleted rows emit nothing.
fn collect_reader_order_body_outputs(
  elements : Array[ScannedElement],
  parent_identity : Int,
  output : Array[(Int, ReaderOrderBodyOutputKind)],
  depth : Int,
  budget : ReaderOrderBudget,
) -> Unit raise DocxError {
  guard parent_identity >= 0 && parent_identity < elements.length() else {
    return
  }
  let mut child = elements[parent_identity].first_child_index
  while child >= 0 {
    let element = elements[child]
    budget.charge_visit(depth)
    if element.deleted_table_row ||
      is_suppressed_container(element.uri, element.local_name) {
      ()
    } else if is_wml_uri(element.uri) &&
      element.local_name == "p" &&
      reader_order_is_deleted_body_paragraph(elements, child, depth, budget) {
      ()
    } else if reader_order_is_body_flattening_container(element) {
      collect_reader_order_body_outputs(
        elements,
        child,
        output,
        depth + 1,
        budget,
      )
    } else {
      match reader_order_body_output_kind(element) {
        Some(kind) => output.push((child, kind))
        None => ()
      }
    }
    child = element.next_sibling_index
  }
}

///|
fn reader_order_projection_visibility(
  scan : StoryScan,
  budget : ReaderOrderBudget,
) -> Array[Bool] raise DocxError {
  let elements = scan.elements()
  let visible = Array::make(elements.length(), false)
  let identity_by_start : Map[Int, Int] = Map([])
  for element in elements {
    budget.charge_visit(1)
    identity_by_start[element.byte_start] = element.identity
  }
  for node in scan.nodes() {
    budget.charge_visit(1)
    match identity_by_start.get(node.byte_start) {
      Some(identity) => visible[identity] = true
      None => ()
    }
  }
  let inside_deleted_revision = Array::make(elements.length(), false)
  let deleted_row_ancestor = Array::make(elements.length(), -1)
  for element in elements {
    budget.charge_visit(1)
    let parent = element.parent_index
    if parent >= 0 && parent < elements.length() {
      let parent_element = elements[parent]
      inside_deleted_revision[element.identity] = (
          is_wml_uri(parent_element.uri) && parent_element.local_name == "del"
        ) ||
        inside_deleted_revision[parent]
      deleted_row_ancestor[element.identity] = if parent_element.deleted_table_row {
        parent
      } else {
        deleted_row_ancestor[parent]
      }
    }
  }
  // BodyReader abandons vMerge collapsing for the whole table when its
  // flattened children contain a non-row, or one row contains a non-cell.
  // The streaming N0b1 scanner has already retracted continuation cells by
  // that point, so source-retaining N0b2 reconstructs those subtrees here.
  let fail_open_table = Array::make(elements.length(), false)
  for table in elements {
    budget.charge_visit(1)
    if is_wml_uri(table.uri) && table.local_name == "tbl" {
      let rows : Array[(Int, ReaderOrderBodyOutputKind)] = []
      collect_reader_order_body_outputs(
        elements,
        table.identity,
        rows,
        1,
        budget,
      )
      for row in rows {
        let (row_identity, row_kind) = row
        if !(row_kind is ReaderOrderTableRow) {
          fail_open_table[table.identity] = true
        } else {
          let cells : Array[(Int, ReaderOrderBodyOutputKind)] = []
          collect_reader_order_body_outputs(
            elements, row_identity, cells, 2, budget,
          )
          for cell in cells {
            let (_, cell_kind) = cell
            if !(cell_kind is ReaderOrderTableCell) {
              fail_open_table[table.identity] = true
            }
          }
        }
      }
    }
  }
  // Recompute continuation visibility from the retained physical table
  // properties. A whole outer cell can have been suppressed before its
  // nested table was scanned, so the original projection checkpoints alone
  // cannot describe that nested table's independent merge semantics.
  let merged_by_vmerge = Array::make(elements.length(), false)
  for table in elements {
    budget.charge_visit(1)
    if is_wml_uri(table.uri) &&
      table.local_name == "tbl" &&
      !fail_open_table[table.identity] {
      let open_columns : Set[Int] = Set([])
      let rows : Array[(Int, ReaderOrderBodyOutputKind)] = []
      collect_reader_order_body_outputs(
        elements,
        table.identity,
        rows,
        1,
        budget,
      )
      for row in rows {
        let (row_identity, row_kind) = row
        if row_kind is ReaderOrderTableRow {
          let mut column = 0
          let cells : Array[(Int, ReaderOrderBodyOutputKind)] = []
          collect_reader_order_body_outputs(
            elements, row_identity, cells, 2, budget,
          )
          for cell in cells {
            let (cell_identity, cell_kind) = cell
            if cell_kind is ReaderOrderTableCell {
              let cell_element = elements[cell_identity]
              if cell_element.table_cell_vmerge_continue &&
                open_columns.contains(column) {
                merged_by_vmerge[cell_identity] = true
              } else {
                open_columns.add(column)
              }
              column += cell_element.table_cell_grid_span
            }
          }
        }
      }
    }
  }
  let merged_cell_ancestor = Array::make(elements.length(), -1)
  for element in elements {
    budget.charge_visit(1)
    let parent = element.parent_index
    if parent >= 0 && parent < elements.length() {
      merged_cell_ancestor[element.identity] = if merged_by_vmerge[parent] {
        parent
      } else {
        merged_cell_ancestor[parent]
      }
    }
    if merged_by_vmerge[element.identity] ||
      merged_cell_ancestor[element.identity] >= 0 {
      visible[element.identity] = false
    }
  }
  // Undo every streaming retraction that the reader-order reconstruction no
  // longer considers merged. This covers malformed fail-open tables and
  // continuations whose apparent origin lived under a BodyReader-ignored
  // wrapper, while leaving deleted/merged ancestor suppression intact.
  for element in elements {
    budget.charge_visit(1)
    if element.retracted_by_vmerge &&
      !merged_by_vmerge[element.identity] &&
      merged_cell_ancestor[element.identity] < 0 &&
      deleted_row_ancestor[element.identity] < 0 &&
      !inside_deleted_revision[element.identity] {
      restore_reader_projection_subtree(
        elements,
        visible,
        merged_by_vmerge,
        element.identity,
        1,
        budget,
      )
    }
  }
  // The reader's primary inline pass suppresses w:del, but its independent
  // paragraph-extras pass still descends through that physical subtree and
  // emits any textbox content it finds.
  for element in elements {
    budget.charge_visit(1)
    if is_wml_uri(element.uri) &&
      element.local_name == "txbxContent" &&
      inside_deleted_revision[element.identity] &&
      deleted_row_ancestor[element.identity] < 0 {
      if merged_cell_ancestor[element.identity] < 0 {
        restore_reader_projection_subtree(
          elements,
          visible,
          merged_by_vmerge,
          element.identity,
          1,
          budget,
        )
      }
    }
  }
  visible
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
fn ReaderOrderWalker::is_projection_visible(
  self : ReaderOrderWalker,
  identity : Int,
) -> Bool {
  identity >= 0 &&
  identity < self.projection_visible.length() &&
  self.projection_visible[identity]
}

///|
fn ReaderOrderWalker::first_wml_child(
  self : ReaderOrderWalker,
  parent_identity : Int,
  local_name : String,
  child_depth : Int,
) -> Int? raise DocxError {
  let mut child = self.elements[parent_identity].first_child_index
  while child >= 0 {
    let element = self.elements[child]
    self.budget.charge_visit(child_depth)
    if is_wml_uri(element.uri) && element.local_name == local_name {
      return Some(child)
    }
    child = element.next_sibling_index
  }
  None
}

///|
fn ReaderOrderWalker::is_deleted_paragraph_mark(
  self : ReaderOrderWalker,
  paragraph_identity : Int,
  paragraph_depth : Int,
) -> Bool raise DocxError {
  match self.first_wml_child(paragraph_identity, "pPr", paragraph_depth + 1) {
    Some(properties) =>
      match self.first_wml_child(properties, "rPr", paragraph_depth + 2) {
        Some(run_properties) =>
          self.first_wml_child(run_properties, "del", paragraph_depth + 3)
          is Some(_)
        None => false
      }
    None => false
  }
}

///|
fn ReaderOrderWalker::add_contribution(
  self : ReaderOrderWalker,
  paragraph : ReaderOrderParagraph,
  kind : ProvisionalContributionKind,
  value : String,
  source_identity : Int,
  paragraph_identity : Int,
  run_identity : Int?,
  source_span : ReaderOrderSourceSpan,
) -> Unit raise DocxError {
  self.budget.charge_text(value.length())
  self.budget.charge_contributor()
  paragraph.contributions.push({
    kind,
    value,
    source_identity,
    paragraph_identity,
    run_identity,
    source_span,
  })
}

///|
fn ReaderOrderWalker::walk(self : ReaderOrderWalker) -> Unit raise DocxError {
  if self.elements.is_empty() {
    return
  }
  self.budget.charge_visit(1)
  self.walk_structural_element(self.elements[0].identity, 1, false)
}

///|
fn ReaderOrderWalker::walk_flow_children(
  self : ReaderOrderWalker,
  parent_identity : Int,
  parent_depth : Int,
  from_text_box : Bool,
) -> Unit raise DocxError {
  let pending : Array[PendingDeletedParagraph] = []
  let mut child = self.elements[parent_identity].first_child_index
  while child >= 0 {
    let element = self.elements[child]
    let depth = parent_depth + 1
    self.budget.charge_visit(depth)
    if is_wml_uri(element.uri) &&
      element.local_name == "p" &&
      self.is_projection_visible(child) {
      if self.is_deleted_paragraph_mark(child, depth) {
        self.budget.charge_contributor()
        pending.push({ identity: child, depth })
      } else {
        let contributors : Array[PendingDeletedParagraph] = []
        contributors.append(pending)
        contributors.push({ identity: child, depth })
        self.emit_paragraph(contributors, from_text_box)
        pending.clear()
        // BodyReader's extra pass only scans the terminal paragraph. Textboxes
        // physically nested in a deleted-prefix paragraph remain discarded.
        self.walk_paragraph_extras(child, depth)
      }
    } else {
      self.walk_structural_element(child, depth, from_text_box)
    }
    child = element.next_sibling_index
  }
}

///|
fn ReaderOrderWalker::walk_structural_element(
  self : ReaderOrderWalker,
  identity : Int,
  depth : Int,
  from_text_box : Bool,
) -> Unit raise DocxError {
  let element = self.elements[identity]
  if is_wml_uri(element.uri) {
    match element.local_name {
      "document" =>
        match self.first_wml_child(identity, "body", depth + 1) {
          Some(body) => self.walk_flow_children(body, depth + 1, from_text_box)
          None => ()
        }
      "body" | "hdr" | "ftr" | "footnotes" | "endnotes" | "comments" =>
        self.walk_flow_children(identity, depth, from_text_box)
      "footnote" | "endnote" | "comment" =>
        if self.is_projection_visible(identity) {
          self.walk_flow_children(identity, depth, from_text_box)
        }
      "p" =>
        if self.is_projection_visible(identity) &&
          !self.is_deleted_paragraph_mark(identity, depth) {
          self.emit_paragraph([{ identity, depth }], from_text_box)
          self.walk_paragraph_extras(identity, depth)
        }
      "tbl" | "tr" | "tc" =>
        if self.is_projection_visible(identity) {
          self.walk_flow_children(identity, depth, from_text_box)
        }
      "hyperlink" | "drawing" | "object" | "ins" | "smartTag" =>
        self.walk_flow_children(identity, depth, from_text_box)
      // Branch/SDT selection belongs to N0b4. Do not silently pick a branch
      // or content node while constructing the provisional N0b2 order.
      "sdt" | "sdtContent" | "txbxContent" => ()
      _ => ()
    }
  } else if reader_order_is_vml_flattening_container(element) {
    self.walk_flow_children(identity, depth, from_text_box)
  } else {
    ()
  }
}

///|
fn ReaderOrderWalker::emit_paragraph(
  self : ReaderOrderWalker,
  contributors : Array[PendingDeletedParagraph],
  from_text_box : Bool,
) -> Unit raise DocxError {
  self.budget.charge_contributor()
  let paragraph : ReaderOrderParagraph = {
    from_text_box,
    sources: [],
    contributions: [],
  }
  for contributor in contributors {
    let element = self.elements[contributor.identity]
    self.budget.charge_contributor()
    let source : ReaderOrderParagraphSource = {
      identity: contributor.identity,
      source_span: reader_order_element_span(element),
      runs: [],
    }
    paragraph.sources.push(source)
    self.walk_inline_children(
      contributor.identity,
      contributor.depth,
      paragraph,
      source,
      None,
    )
  }
  self.paragraphs.push(paragraph)
}

///|
fn ReaderOrderWalker::walk_inline_children(
  self : ReaderOrderWalker,
  parent_identity : Int,
  parent_depth : Int,
  paragraph : ReaderOrderParagraph,
  paragraph_source : ReaderOrderParagraphSource,
  current_run : Int?,
) -> Unit raise DocxError {
  let mut child = self.elements[parent_identity].first_child_index
  while child >= 0 {
    let element = self.elements[child]
    let depth = parent_depth + 1
    self.budget.charge_visit(depth)
    self.walk_inline_element(
      child, depth, paragraph, paragraph_source, current_run,
    )
    child = element.next_sibling_index
  }
}

///|
fn ReaderOrderWalker::walk_inline_element(
  self : ReaderOrderWalker,
  identity : Int,
  depth : Int,
  paragraph : ReaderOrderParagraph,
  paragraph_source : ReaderOrderParagraphSource,
  current_run : Int?,
) -> Unit raise DocxError {
  let element = self.elements[identity]
  let paragraph_identity = paragraph_source.identity
  let add = fn(
    kind : ProvisionalContributionKind,
    value : String,
    span : ReaderOrderSourceSpan,
  ) -> Unit raise DocxError {
    self.add_contribution(
      paragraph, kind, value, identity, paragraph_identity, current_run, span,
    )
  }
  if !is_wml_uri(element.uri) {
    if reader_order_is_vml_flattening_container(element) {
      add(TransparentSeam, "", reader_order_element_span(element))
      self.walk_inline_children(
        identity, depth, paragraph, paragraph_source, current_run,
      )
    } else {
      add(HardBarrier, "", reader_order_element_span(element))
    }
    return
  }
  match element.local_name {
    "r" =>
      if self.is_projection_visible(identity) {
        self.budget.charge_contributor()
        paragraph_source.runs.push({
          identity,
          source_span: reader_order_element_span(element),
        })
        self.add_contribution(
          paragraph,
          TransparentSeam,
          "",
          identity,
          paragraph_identity,
          Some(identity),
          reader_order_element_span(element),
        )
        self.walk_inline_children(
          identity,
          depth,
          paragraph,
          paragraph_source,
          Some(identity),
        )
      }
    "t" => {
      let value = match element.text_map {
        Some(mapped) => mapped.projection
        None => ""
      }
      add(TextAtom, value, reader_order_atom_span(element))
    }
    "tab" => add(TabAtom, "\t", reader_order_element_span(element))
    "noBreakHyphen" =>
      add(NoBreakHyphenAtom, "\u{2011}", reader_order_element_span(element))
    "softHyphen" =>
      add(SoftHyphenAtom, "\u{00AD}", reader_order_element_span(element))
    "sym" =>
      match
        symbol_to_unicode(
          element.symbol_font.unwrap_or(""),
          element.symbol_char.unwrap_or(""),
        ) {
        Some(value) =>
          add(SymbolAtom, value, reader_order_element_span(element))
        None => add(HardBarrier, "", reader_order_element_span(element))
      }
    "hyperlink" | "drawing" | "object" | "ins" | "smartTag" => {
      add(TransparentSeam, "", reader_order_element_span(element))
      self.walk_inline_children(
        identity, depth, paragraph, paragraph_source, current_run,
      )
    }
    "pPr"
    | "rPr"
    | "proofErr"
    | "bookmarkStart"
    | "bookmarkEnd"
    | "commentRangeStart"
    | "commentRangeEnd"
    | "lastRenderedPageBreak"
    | "annotationRef" =>
      add(TransparentSeam, "", reader_order_element_span(element))
    // These nodes either emit a non-text reader element, are suppressed, or
    // require one of the later transforms. They remain explicit barriers so a
    // future matcher cannot silently glue text across them.
    "br"
    | "cr"
    | "ptab"
    | "footnoteReference"
    | "endnoteReference"
    | "commentReference"
    | "footnoteRef"
    | "endnoteRef"
    | "pict"
    | "del"
    | "fldChar"
    | "fldSimple"
    | "instrText"
    | "sdt"
    | "sdtContent"
    | "txbxContent" => add(HardBarrier, "", reader_order_element_span(element))
    _ => add(HardBarrier, "", reader_order_element_span(element))
  }
}

///|
/// Mirrors BodyReader's second paragraph pass for textboxes, but deliberately
/// does not perform the N0b4 AlternateContent or SDT transforms.
fn ReaderOrderWalker::walk_paragraph_extras(
  self : ReaderOrderWalker,
  parent_identity : Int,
  parent_depth : Int,
) -> Unit raise DocxError {
  let mut child = self.elements[parent_identity].first_child_index
  while child >= 0 {
    let element = self.elements[child]
    let depth = parent_depth + 1
    self.budget.charge_visit(depth)
    if is_wml_uri(element.uri) {
      match element.local_name {
        "pict" => self.walk_pict_extras(child, depth)
        "txbxContent" => self.walk_flow_children(child, depth, true)
        // BodyReader suppresses deleted inline atoms, then independently
        // recurses through the physical paragraph to discover textboxes.
        "del" => self.walk_paragraph_extras(child, depth)
        "sdt" | "sdtContent" => ()
        _ => self.walk_paragraph_extras(child, depth)
      }
    } else if element.uri == MC_URI && element.local_name == "AlternateContent" {
      ()
    } else {
      self.walk_paragraph_extras(child, depth)
    }
    child = element.next_sibling_index
  }
}

///|
fn ReaderOrderWalker::walk_pict_extras(
  self : ReaderOrderWalker,
  parent_identity : Int,
  parent_depth : Int,
) -> Unit raise DocxError {
  let mut child = self.elements[parent_identity].first_child_index
  while child >= 0 {
    let element = self.elements[child]
    let depth = parent_depth + 1
    self.budget.charge_visit(depth)
    if is_wml_uri(element.uri) && element.local_name == "txbxContent" {
      self.walk_flow_children(child, depth, true)
    } else if is_wml_uri(element.uri) && element.local_name == "pict" {
      self.walk_pict_extras(child, depth)
    } else if reader_order_is_vml_flattening_container(element) {
      self.walk_pict_extras(child, depth)
    } else if element.uri == MC_URI && element.local_name == "AlternateContent" {
      ()
    } else if is_wml_uri(element.uri) &&
      element.local_name
      is ("p"
      | "tbl"
      | "tr"
      | "tc"
      | "hyperlink"
      | "drawing"
      | "object"
      | "ins"
      | "smartTag") {
      self.walk_structural_element(child, depth, true)
    }
    child = element.next_sibling_index
  }
}

///|
/// Builds the private N0b2 view from an already-retained N0b1 source tree.
fn project_reader_order_from_source_tree(
  source_part : String,
  source_tree : StoryScan,
  budget? : ReaderOrderBudget,
) -> ReaderOrderProjection raise DocxError {
  let budget = match budget {
    Some(value) => value
    None => reader_order_budget()
  }
  let walker : ReaderOrderWalker = {
    elements: source_tree.elements(),
    projection_visible: reader_order_projection_visibility(source_tree, budget),
    budget,
    paragraphs: [],
  }
  walker.walk()
  {
    source_part,
    source_elements: walker.elements,
    paragraphs: walker.paragraphs,
  }
}

///|
/// Convenience entry point that retains N0b1 identities and immediately
/// derives N0b2 order under independent cumulative budgets.
#warnings("-unused_value")
fn scan_reader_order_projection(
  source_part : String,
  part : BytesView,
  source_budget? : ProjectionSourceBudget,
  reader_budget? : ReaderOrderBudget,
) -> ReaderOrderProjection raise DocxError {
  let source_tree = scan_projection_source_tree(part, budget?=source_budget)
  project_reader_order_from_source_tree(
    source_part,
    source_tree,
    budget?=reader_budget,
  )
}
