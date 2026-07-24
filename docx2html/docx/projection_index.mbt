// N0b: private, reader-exact physical paragraph/run projection indexing.
// It consumes annotation_scan's namespace-resolved event stream and N0a's
// lexical w:t map; no mutation surface is exposed here.

///|
#warnings("-unused_constructor-unused_value")
priv enum ProjectionClass {
  EditableText
  ProjectingAtom
  TransparentSeam
  HardBarrier
  RestrictedRegion
  SuppressedRegion
} derive(Eq)

///|
priv enum ProjectionAncestry {
  ProjectionRoot
  ProjectionAncestor(String, ProjectionAncestry)
} derive(Debug)

///|
#warnings("-unused_field")
priv struct ProjectionPiece {
  class : ProjectionClass
  reason : String?
  part : String
  paragraph_path : String
  run_path : String?
  projection_start : Int
  projection_end : Int
  byte_start : Int
  byte_end : Int
  ancestry : ProjectionAncestry
  text_map : WtContentMap?
}

///|
#warnings("-unused_field")
priv struct PhysicalRunProjection {
  path : String
  byte_start : Int
  byte_end : Int
  projection_start : Int
  mut projection_end : Int
}

///|
#warnings("-unused_field")
priv struct PhysicalParagraphProjection {
  part : String
  physical_path : String
  reader_parent : Int
  mut logical_path : String?
  byte_start : Int
  byte_end : Int
  output : StringBuilder
  mut length : Int
  pieces : Array[ProjectionPiece]
  runs : Array[PhysicalRunProjection]
  mut tracked_deleted_mark : Bool
  textbox : Bool
  mut first_ppr : Int
  mut first_rpr : Int
}

///|
#warnings("-unused_field")
priv struct LogicalParagraphProjection {
  path : String
  projection : String
  physical_paths : Array[String]
  restricted : Bool
}

///|
#warnings("-unused_field")
priv struct StoryProjectionIndex {
  physical_paragraphs : Array[PhysicalParagraphProjection]
  logical_paragraphs : Array[LogicalParagraphProjection]
}

///|
priv suberror ProjectionIndexError {
  ProjectionIndexError(String)
}

///|
priv struct ProjectionElementState {
  paragraph : Int
  run : Int
  restriction : String?
  suppressed : Bool
  blocked : Bool
  properties : Bool
  textbox : Bool
  ancestry : ProjectionAncestry
  mut sdt_content_seen : Bool
  checkbox_owners : Array[Int]
  mut checkbox_text_replaced : Bool
  mut checkbox_fallback_address : String?
  mut fallback_seen : Bool
}

///|
priv struct ProjectionCursor {
  paragraphs : Array[PhysicalParagraphProjection]
  paragraph : Int
  run : Int
  element : ScannedElement
  ancestry : ProjectionAncestry
  fields : Array[(Bool, String)]
}

///|
fn projection_error(address : String, message : String) -> ProjectionIndexError {
  ProjectionIndexError("\{address}: \{message}")
}

///|
fn ScannedElement::is_wml(self : ScannedElement, name : String) -> Bool {
  is_wml_uri(self.uri) && self.local_name == name
}

///|
fn field_restriction(fields : Array[(Bool, String)]) -> String? {
  for at = fields.length() - 1; at >= 0; at = at - 1 {
    return Some(
      if fields[at].0 {
        "complex-field-result"
      } else {
        "complex-field-instruction"
      },
    )
  }
  None
}

///|
fn field_ancestry(
  fields : Array[(Bool, String)],
  inherited : ProjectionAncestry,
) -> ProjectionAncestry {
  let mut result = inherited
  for field in fields {
    result = ProjectionAncestor(
      if field.0 {
        "complex-field-result"
      } else {
        "complex-field-instruction"
      },
      result,
    )
  }
  result
}

///|
fn effective_restriction(
  inherited : String?,
  fields : Array[(Bool, String)],
) -> String? {
  match inherited {
    Some(_) => inherited
    None => field_restriction(fields)
  }
}

///|
fn ancestor_label(element : ScannedElement) -> String? {
  if is_wml_uri(element.uri) {
    match element.local_name {
      "hyperlink" => Some("hyperlink")
      "ins" => Some("insertion")
      "del" => Some("deletion")
      "sdt" => Some("sdt")
      "drawing" | "object" | "pict" => Some("drawing")
      "txbxContent" => Some("textbox")
      "fldSimple" => Some("simple-field")
      _ => None
    }
  } else if element.uri == MC_URI {
    match element.local_name {
      "AlternateContent" => Some("alternate-content")
      "Choice" => Some("alternate-choice")
      "Fallback" => Some("alternate-fallback")
      _ => None
    }
  } else {
    None
  }
}

///|
fn ProjectionCursor::append(
  self : ProjectionCursor,
  class : ProjectionClass,
  reason : String?,
  projection : String,
  text_map? : WtContentMap,
) -> Unit {
  let paragraph = self.paragraphs[self.paragraph]
  let start = paragraph.length
  paragraph.output.write_string(projection)
  paragraph.length += projection.length()
  paragraph.pieces.push({
    class,
    reason,
    part: paragraph.part,
    paragraph_path: paragraph.physical_path,
    run_path: if self.run >= 0 {
      Some(paragraph.runs[self.run].path)
    } else {
      None
    },
    projection_start: start,
    projection_end: paragraph.length,
    byte_start: self.element.byte_start,
    byte_end: self.element.byte_end,
    ancestry: field_ancestry(self.fields, self.ancestry),
    text_map,
  })
  if self.run >= 0 {
    paragraph.runs[self.run].projection_end = paragraph.length
  }
}

///|
fn ProjectionCursor::marker(
  self : ProjectionCursor,
  class : ProjectionClass,
  reason : String,
) -> Unit {
  self.append(class, Some(reason), "")
}

///|
fn ProjectionCursor::address(self : ProjectionCursor) -> String {
  let paragraph = self.paragraphs[self.paragraph]
  let path = if self.run >= 0 {
    paragraph.runs[self.run].path
  } else {
    paragraph.physical_path
  }
  "\{paragraph.part}#\{path}"
}

///|
fn atom_class(editable : Bool, restriction : String?) -> ProjectionClass {
  match restriction {
    Some(_) => RestrictedRegion
    None => if editable { EditableText } else { ProjectingAtom }
  }
}

///|
fn projection_nodes(scan : StoryScan) -> Map[Int, ScannedNode] {
  let result : Map[Int, ScannedNode] = Map([])
  for node in scan.nodes() {
    if node.kind is ("p" | "r") {
      result[node.byte_start] = node
    }
  }
  result
}

///|
fn nearest_special(
  elements : Array[ScannedElement],
  from : Int,
  kind : String,
) -> Int {
  let mut at = from
  while at >= 0 {
    let matches = match kind {
      "sdt" => elements[at].is_wml("sdt")
      "alternate" =>
        elements[at].uri == MC_URI &&
        elements[at].local_name == "AlternateContent"
      "run" => elements[at].is_wml("r")
      _ => false
    }
    if matches {
      return at
    }
    at = elements[at].parent_index
  }
  -1
}

///|
fn nearest_paragraph_child(elements : Array[ScannedElement], from : Int) -> Int {
  let mut at = from
  while at >= 0 {
    let parent = elements[at].parent_index
    if parent >= 0 && elements[parent].is_wml("p") {
      return at
    }
    at = parent
  }
  -1
}

///|
fn pending_checkbox_owner(
  owners : Array[Int],
  states : Array[ProjectionElementState],
) -> Int {
  for at = owners.length() - 1; at >= 0; at = at - 1 {
    if !states[owners[at]].checkbox_text_replaced {
      return owners[at]
    }
  }
  -1
}

///|
fn apply_field_marker(
  marker : String,
  fields : Array[(Bool, String)],
  seen_carriers : Map[Int, Bool],
  carrier : Int,
  address : String,
) -> Unit raise ProjectionIndexError {
  guard carrier >= 0 && !seen_carriers.contains(carrier) else {
    raise projection_error(
      address, "ambiguous field markers in one paragraph child",
    )
  }
  seen_carriers[carrier] = true
  match marker {
    "begin" => fields.push((false, address))
    "separate" => {
      guard fields.last() is Some((false, _)) else {
        raise projection_error(address, "invalid complex-field separator")
      }
      fields[fields.length() - 1] = (true, address)
    }
    "end" => {
      guard fields.pop() is Some(_) else {
        raise projection_error(address, "a complex-field end has no open begin")
      }
    }
    _ => raise projection_error(address, "unknown complex-field marker type")
  }
}

///|
fn transparent_wml(name : String) -> Bool {
  name
  is ("proofErr"
  | "bookmarkStart"
  | "bookmarkEnd"
  | "commentRangeStart"
  | "commentRangeEnd"
  | "lastRenderedPageBreak"
  | "annotationRef"
  | "sectPr")
}

///|
fn hard_wml(name : String) -> Bool {
  name
  is ("br"
  | "cr"
  | "ptab"
  | "footnoteReference"
  | "endnoteReference"
  | "footnoteRef"
  | "endnoteRef"
  | "commentReference")
}

///|
fn known_container(element : ScannedElement) -> Bool {
  (
    is_wml_uri(element.uri) &&
    element.local_name
    is ("p"
    | "r"
    | "pPr"
    | "rPr"
    | "sdt"
    | "sdtPr"
    | "sdtContent"
    | "ins"
    | "hyperlink"
    | "smartTag")
  ) ||
  (
    element.uri == MC_URI &&
    element.local_name is ("AlternateContent" | "Fallback" | "Choice")
  )
}

///|
fn logical_parent(path : String) -> String {
  match path.rev_find("/p[") {
    Some(at) => path[:at].to_owned()
    None => ""
  }
}

///|
fn build_logical_paragraphs(
  physical : Array[PhysicalParagraphProjection],
) -> Array[LogicalParagraphProjection] {
  let pending : Map[Int, Array[Int]] = Map([])
  let ordinals : Map[String, Int] = Map([])
  let logical : Array[LogicalParagraphProjection] = []
  for index, paragraph in physical {
    let parent = logical_parent(paragraph.physical_path)
    if paragraph.tracked_deleted_mark {
      pending.get_or_init(paragraph.reader_parent, fn() { [] }).push(index)
      continue
    }
    let ordinal = ordinals.get_or_default(parent, 0) + 1
    ordinals[parent] = ordinal
    let path = if parent == "" {
      "p[\{ordinal}]"
    } else {
      "\{parent}/p[\{ordinal}]"
    }
    let grouped = pending.get_or_default(paragraph.reader_parent, [])
    let output = StringBuilder()
    let paths : Array[String] = []
    for physical_index in grouped {
      output.write_string(physical[physical_index].output.to_string())
      paths.push(physical[physical_index].physical_path)
      physical[physical_index].logical_path = Some(path)
    }
    pending.remove(paragraph.reader_parent)
    output.write_string(paragraph.output.to_string())
    paths.push(paragraph.physical_path)
    physical[index].logical_path = Some(path)
    logical.push({
      path,
      projection: output.to_string(),
      physical_paths: paths,
      restricted: paths.length() > 1 || paragraph.textbox,
    })
  }
  logical
}

///|
#warnings("-unused_value")
fn build_story_projection_index(
  part_name : String,
  part : BytesView,
  token_budget : TokenMapBudget,
) -> StoryProjectionIndex raise {
  @xml.read_xml_bytes_strict_limited(
    part,
    local_input_linear_xml_budget(part),
    namespace_map=office_namespace_map(),
  )
  |> ignore
  let scan = scan_story(part, retain_elements=true)
  let elements = scan.elements()
  let nodes = projection_nodes(scan)
  let paragraphs : Array[PhysicalParagraphProjection] = []
  let states : Array[ProjectionElementState] = []
  let fields : Array[(Bool, String)] = []
  let seen_field_carriers : Map[Int, Bool] = Map([])
  let checkbox_sdts : Set[Int] = Set([])
  for element in elements {
    let properties = element.parent_index
    let owner = if properties >= 0 {
      elements[properties].parent_index
    } else {
      -1
    }
    if element.uri == "http://schemas.microsoft.com/office/word/2010/wordml" &&
      element.local_name == "checkbox" &&
      properties >= 0 &&
      elements[properties].is_wml("sdtPr") &&
      owner >= 0 &&
      elements[owner].is_wml("sdt") {
      checkbox_sdts.add(owner)
    }
  }
  for element_index, element in elements {
    let parent = element.parent_index
    let wml = is_wml_uri(element.uri)
    let mut paragraph = if parent >= 0 { states[parent].paragraph } else { -1 }
    let mut run = if parent >= 0 { states[parent].run } else { -1 }
    let mut restriction = if parent >= 0 {
      states[parent].restriction
    } else {
      None
    }
    let mut suppressed = parent >= 0 && states[parent].suppressed
    let mut blocked = parent >= 0 && states[parent].blocked
    let properties = is_property_container(element.uri, element.local_name) ||
      (parent >= 0 && states[parent].properties)
    let textbox = element.is_wml("txbxContent") ||
      (parent >= 0 && states[parent].textbox)
    let inherited_ancestry = if parent >= 0 {
      states[parent].ancestry
    } else {
      ProjectionRoot
    }
    let ancestry = match ancestor_label(element) {
      Some(label) => ProjectionAncestor(label, inherited_ancestry)
      None => inherited_ancestry
    }
    let mut checkbox_owners = if parent >= 0 {
      states[parent].checkbox_owners
    } else {
      []
    }
    if element.is_wml("p") && !suppressed {
      match nodes.get(element.byte_start) {
        Some(node) if node.kind == "p" => {
          paragraph = paragraphs.length()
          run = -1
          blocked = false
          if textbox {
            restriction = Some("textbox")
          }
          paragraphs.push({
            part: part_name,
            physical_path: node.path,
            reader_parent: parent,
            logical_path: None,
            byte_start: element.byte_start,
            byte_end: element.byte_end,
            output: StringBuilder(),
            length: 0,
            pieces: [],
            runs: [],
            tracked_deleted_mark: false,
            textbox,
            first_ppr: -1,
            first_rpr: -1,
          })
        }
        _ => suppressed = true
      }
    }
    let mut run_started = false
    if element.is_wml("r") && paragraph >= 0 && !suppressed && !blocked {
      match nodes.get(element.byte_start) {
        Some(node) if node.kind == "r" => {
          let work = paragraphs[paragraph]
          run = work.runs.length()
          work.runs.push({
            path: node.path,
            byte_start: element.byte_start,
            byte_end: element.byte_end,
            projection_start: work.length,
            projection_end: work.length,
          })
          run_started = true
        }
        _ => ()
      }
    }
    let cursor : ProjectionCursor = {
      paragraphs,
      paragraph,
      run,
      element,
      ancestry,
      fields,
    }
    if run_started {
      cursor.marker(TransparentSeam, "run-boundary")
    }
    if element.is_wml("pPr") &&
      paragraph >= 0 &&
      parent >= 0 &&
      elements[parent].is_wml("p") &&
      paragraphs[paragraph].first_ppr < 0 {
      paragraphs[paragraph].first_ppr = element_index
    }
    if element.is_wml("rPr") &&
      paragraph >= 0 &&
      parent >= 0 &&
      parent == paragraphs[paragraph].first_ppr &&
      paragraphs[paragraph].first_rpr < 0 {
      paragraphs[paragraph].first_rpr = element_index
    }
    if element.is_wml("del") &&
      paragraph >= 0 &&
      parent >= 0 &&
      parent == paragraphs[paragraph].first_rpr {
      paragraphs[paragraph].tracked_deleted_mark = true
    }
    if element.is_wml("sdtContent") {
      let owner = if parent >= 0 && elements[parent].is_wml("sdt") {
        parent
      } else {
        -1
      }
      if owner >= 0 {
        if states[owner].sdt_content_seen {
          suppressed = true
        } else {
          states[owner].sdt_content_seen = true
          if checkbox_sdts.contains(owner) {
            checkbox_owners = checkbox_owners + [owner]
          } else {
            restriction = Some("sdt")
          }
        }
      }
    }
    if element.uri == MC_URI && element.local_name == "Choice" {
      suppressed = true
    }
    if element.uri == MC_URI && element.local_name == "Fallback" {
      let owner = nearest_special(elements, parent, "alternate")
      if owner >= 0 && states[owner].fallback_seen {
        suppressed = true
      } else {
        if owner >= 0 {
          states[owner].fallback_seen = true
        }
        restriction = Some("alternate-fallback")
      }
    }
    if wml && element.local_name is ("ins" | "hyperlink") {
      restriction = Some(
        if element.local_name == "ins" {
          "insertion"
        } else {
          "hyperlink"
        },
      )
    }
    if element.is_wml("del") && !properties {
      if paragraph >= 0 && !suppressed {
        cursor.marker(SuppressedRegion, "deletion")
      }
      suppressed = true
    }
    let active = paragraph >= 0 && !suppressed && !blocked
    if element.is_wml("fldChar") && paragraph >= 0 {
      guard element.field_char_type is Some(marker) else {
        raise projection_error(
          cursor.address(),
          "a complex-field marker has no w:fldCharType",
        )
      }
      apply_field_marker(
        marker,
        fields,
        seen_field_carriers,
        nearest_paragraph_child(elements, element_index),
        cursor.address(),
      )
      cursor.marker(RestrictedRegion, "complex-field-marker")
    } else if element.is_wml("t") && active && !properties {
      let mapped = map_wt_content(
        part,
        element.content_start,
        element.content_end,
        token_budget,
      )
      let checkbox_owner = pending_checkbox_owner(checkbox_owners, states)
      if checkbox_owner >= 0 &&
        !states[checkbox_owner].checkbox_text_replaced &&
        mapped.projection.length() > 0 {
        states[checkbox_owner].checkbox_text_replaced = true
        cursor.append(
          SuppressedRegion,
          Some("checkbox-sdt-text"),
          "",
          text_map=mapped,
        )
      } else {
        if !checkbox_owners.is_empty() && restriction is None {
          restriction = Some("checkbox-sdt-remainder")
        }
        let restricted = effective_restriction(restriction, fields)
        cursor.append(
          atom_class(true, restricted),
          restricted,
          mapped.projection,
          text_map=mapped,
        )
      }
    } else if wml &&
      element.local_name is ("tab" | "noBreakHyphen" | "softHyphen" | "sym") &&
      active &&
      !properties {
      let projected = match element.local_name {
        "tab" => Some("\t")
        "noBreakHyphen" => Some("\u{2011}")
        "softHyphen" => Some("\u{00AD}")
        _ =>
          symbol_to_unicode(
            element.symbol_font.unwrap_or(""),
            element.symbol_char.unwrap_or(""),
          )
      }
      match projected {
        Some(value) => {
          let checkbox_owner = pending_checkbox_owner(checkbox_owners, states)
          if element.local_name != "tab" &&
            checkbox_owner >= 0 &&
            !states[checkbox_owner].checkbox_text_replaced &&
            value.length() > 0 {
            states[checkbox_owner].checkbox_text_replaced = true
            cursor.append(SuppressedRegion, Some("checkbox-sdt-text"), "")
          } else {
            let restricted = effective_restriction(
              if !checkbox_owners.is_empty() && restriction is None {
                Some("checkbox-sdt-remainder")
              } else {
                restriction
              },
              fields,
            )
            cursor.append(atom_class(false, restricted), restricted, value)
            if element.local_name == "tab" {
              for owner in checkbox_owners {
                if !states[owner].checkbox_text_replaced {
                  states[owner].checkbox_fallback_address = Some(
                    cursor.address(),
                  )
                }
              }
            }
          }
        }
        None => cursor.marker(HardBarrier, "unsupported-symbol")
      }
      blocked = true
    } else if wml &&
      transparent_wml(element.local_name) &&
      active &&
      !properties {
      cursor.marker(TransparentSeam, element.local_name)
      // The reader treats these as empty markers, not recursive containers.
      // Suppress hostile descendants while leaving later siblings untouched.
      suppressed = true
    } else if wml &&
      (hard_wml(element.local_name) || element.local_name == "fldSimple") &&
      active {
      cursor.marker(HardBarrier, element.local_name)
      suppressed = true
    } else if wml && element.local_name == "instrText" && active {
      cursor.marker(SuppressedRegion, "field-instruction")
      suppressed = true
    } else if wml &&
      element.local_name is ("drawing" | "object" | "pict" | "txbxContent") &&
      paragraph >= 0 &&
      !suppressed {
      if !blocked {
        cursor.marker(
          HardBarrier,
          if element.local_name == "txbxContent" {
            "textbox"
          } else {
            element.local_name
          },
        )
      }
      blocked = true
    } else if paragraph >= 0 &&
      !suppressed &&
      !blocked &&
      !properties &&
      !known_container(element) {
      cursor.marker(HardBarrier, "unrecognized:\{element.local_name}")
      suppressed = true
    }
    states.push({
      paragraph,
      run,
      restriction,
      suppressed,
      blocked,
      properties,
      textbox,
      ancestry,
      sdt_content_seen: false,
      checkbox_owners,
      checkbox_text_replaced: false,
      checkbox_fallback_address: None,
      fallback_seen: false,
    })
  }
  match fields.last() {
    Some((_, address)) =>
      raise projection_error(address, "complex field remains open at story end")
    None => ()
  }
  for state in states {
    if !state.checkbox_text_replaced &&
      state.checkbox_fallback_address is Some(address) {
      raise projection_error(
        address, "a checkbox SDT has projecting content but no reader text replacement target",
      )
    }
  }
  {
    physical_paragraphs: paragraphs,
    logical_paragraphs: build_logical_paragraphs(paragraphs),
  }
}
