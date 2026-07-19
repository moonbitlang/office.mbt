///|
/// An opaque, validated drawing anchor retained because the semantic XLSX API
/// does not model its direct object payload yet.
priv struct PreservedDrawingAnchor {
  order : Int
  xml : String
}

///|
/// A relationship needed by an opaque drawing anchor or one of its retained
/// package parts. `target_part` is the normalized source-package path for an
/// internal target and absent for an external target.
priv struct PreservedDrawingRelationship {
  id : String
  rel_type : String
  target : String
  external : Bool
  target_part : String?
}

///|
/// One internal OPC part in the transitive relationship closure of an opaque
/// drawing anchor.
priv struct PreservedDrawingPart {
  source_path : String
  data : Bytes
  content_type : String
  relationships : Array[PreservedDrawingRelationship]
}

///|
/// An isolated output part used by an opaque drawing anchor. Rehoming retained
/// parts under a writer-owned directory prevents hostile or stale source paths
/// from replacing generated workbook parts.
priv struct PreservedDrawingWritePart {
  path : String
  data : Bytes
  content_type : String
  relationships : Array[PreservedDrawingRelationship]
}

///|
/// The complete write-time projection for one worksheet drawing.
priv struct PreservedDrawingWritePlan {
  anchors : Array[PreservedDrawingAnchor]
  drawing_relationships : Array[PreservedDrawingRelationship]
  parts : Array[PreservedDrawingWritePart]
  relationship_ids : Array[String]
  object_ids : Array[String]
}

///|
fn Worksheet::allocate_drawing_order(self : Worksheet) -> Int raise XlsxError {
  if self.next_drawing_order == 0x7fff_ffff {
    raise InvalidSheetOperation(msg="drawing order exhausted")
  }
  let order = self.next_drawing_order
  self.next_drawing_order = order + 1
  order
}

///|
fn preserved_drawing_relationships_from_xml(
  xml : StringView,
  source_part : StringView,
  part_names : Map[String, String],
  budget? : ReadBudget,
  cancelled? : () -> Bool = () => false,
) -> Array[PreservedDrawingRelationship] raise XlsxError {
  match budget {
    Some(value) => {
      value.checkpoint()
      value.charge_work(xml.length())
    }
    None => ()
  }
  let parsed = @ooxml.parse_package_relationships(xml, cancelled~) catch {
    InvalidXml(msg~) => raise InvalidXml(msg~)
    ReadCancelled => raise ReadCancelled
  }
  match budget {
    Some(value) => value.charge_items(parsed.length())
    None => ()
  }
  let relationships : Array[PreservedDrawingRelationship] = []
  for record in parsed {
    let target_part = if record.external {
      None
    } else {
      Some(
        logical_archive_part_path(
          actual_relationship_target_path(
            source_part,
            record.target,
            part_names,
            cancelled~,
          ),
        ),
      )
    }
    relationships.push({
      id: record.id,
      rel_type: record.rel_type,
      target: record.target,
      external: record.external,
      target_part,
    })
  }
  relationships
}

///|
fn opaque_drawing_relationship_ids(
  anchor_xml : StringView,
  cancelled? : () -> Bool = () => false,
) -> Array[String] raise XlsxError {
  // Canonical drawing anchors retain only supported core element namespaces;
  // supply their root bindings so every relationship attribute can be
  // enumerated by expanded name even though the retained substring no longer
  // contains the original wsDr start tag.
  let wrapped = "<root xmlns:xdr=\"" +
    transitional_spreadsheet_drawing_namespace +
    "\" xmlns:a=\"" +
    transitional_drawing_main_namespace +
    "\" xmlns:c=\"" +
    transitional_drawing_chart_namespace +
    "\" xmlns:sle=\"" +
    drawing_slicer_namespace +
    "\" xmlns:r=\"" +
    transitional_relationship_attribute_namespace +
    "\">" +
    anchor_xml.to_owned() +
    "</root>"
  let scanner = @ooxml.XmlStartTagScanner::new(wrapped, cancelled~)
  let ids : Array[String] = []
  let seen : Set[String] = Set([])
  while workbook_scanner_next(scanner) {
    for
      namespace_uri in [
        transitional_relationship_attribute_namespace, strict_relationship_attribute_namespace,
      ] {
      let values = scanner.attribute_values_in_namespace(namespace_uri) catch {
        InvalidXml(msg~) => raise InvalidXml(msg~)
        ReadCancelled => raise ReadCancelled
      }
      for value in values {
        if !seen.contains(value) {
          seen.add(value)
          ids.push(value)
        }
      }
    }
  }
  ids
}

///|
fn normalized_drawing_object_id(value : StringView) -> String {
  if value == "" {
    return ""
  }
  let mut first_nonzero = 0
  let mut index = 0
  while index < value.length() {
    let unit = value[index]
    if unit < ('0' : UInt16) || unit > ('9' : UInt16) {
      return value.to_owned()
    }
    if unit == ('0' : UInt16) && first_nonzero == index {
      first_nonzero = first_nonzero + 1
    }
    index = index + 1
  }
  if first_nonzero == value.length() {
    "0"
  } else {
    value[first_nonzero:].to_owned()
  }
}

///|
/// Reserve every numeric drawing object identifier used inside an opaque
/// anchor. Leading zeroes are normalized because `ST_DrawingElementId` is a
/// number even though it is represented as XML text.
fn opaque_drawing_object_ids(
  anchors : ArrayView[PreservedDrawingAnchor],
) -> Array[String] raise XlsxError {
  let ids : Array[String] = []
  let seen : Set[String] = Set([])
  for anchor in anchors {
    let wrapped = "<root xmlns:xdr=\"" +
      transitional_spreadsheet_drawing_namespace +
      "\" xmlns:a=\"" +
      transitional_drawing_main_namespace +
      "\" xmlns:c=\"" +
      transitional_drawing_chart_namespace +
      "\" xmlns:sle=\"" +
      drawing_slicer_namespace +
      "\" xmlns:r=\"" +
      transitional_relationship_attribute_namespace +
      "\">" +
      anchor.xml +
      "</root>"
    let scanner = @ooxml.XmlStartTagScanner::new(wrapped)
    while workbook_scanner_next(scanner) {
      if scanner.namespace_uri() != transitional_spreadsheet_drawing_namespace ||
        scanner.local_name() != "cNvPr" {
        continue
      }
      match workbook_scanner_attribute(scanner, "", "id") {
        Some(value) => {
          let key = normalized_drawing_object_id(value)
          if key != "" && !seen.contains(key) {
            seen.add(key)
            ids.push(key)
          }
        }
        None => ()
      }
    }
  }
  ids
}

///|
fn remap_preserved_drawing_relationship(
  relationship : PreservedDrawingRelationship,
  output_paths : Map[String, String],
) -> PreservedDrawingRelationship raise XlsxError {
  if relationship.external {
    return relationship
  }
  let source_target = match relationship.target_part {
    Some(value) => value
    None =>
      raise InvalidSheetOperation(
        msg="preserved drawing relationship target missing",
      )
  }
  let output_target = match
    output_paths.get(@ooxml.package_part_name_key(source_target)) {
    Some(value) => value
    None =>
      raise InvalidSheetOperation(
        msg="preserved drawing relationship closure incomplete",
      )
  }
  {
    ..relationship
    // A package-absolute target is valid OPC and avoids depending on the
    // source part's former directory depth after isolation.
    ,
    target: "/" + output_target,
    target_part: Some(output_target),
  }
}

///|
fn preserved_drawing_write_plan(
  sheet : Worksheet,
  sheet_id : Int,
) -> PreservedDrawingWritePlan raise XlsxError {
  let output_paths : Map[String, String] = Map([])
  for index, part in sheet.preserved_drawing_parts {
    let key = @ooxml.package_part_name_key(part.source_path)
    if output_paths.contains(key) {
      raise InvalidSheetOperation(msg="duplicate preserved drawing part")
    }
    output_paths[key] = "xl/preservedDrawingParts/drawing\{sheet_id}/part\{index + 1}.bin"
  }
  let parts : Array[PreservedDrawingWritePart] = []
  for part in sheet.preserved_drawing_parts {
    let path = output_paths
      .get(@ooxml.package_part_name_key(part.source_path))
      .unwrap()
    let relationships : Array[PreservedDrawingRelationship] = []
    for relationship in part.relationships {
      relationships.push(
        remap_preserved_drawing_relationship(relationship, output_paths),
      )
    }
    parts.push({
      path,
      data: part.data,
      content_type: part.content_type,
      relationships,
    })
  }
  let drawing_relationships : Array[PreservedDrawingRelationship] = []
  let relationship_ids : Array[String] = []
  let relationship_ids_seen : Set[String] = Set([])
  for relationship in sheet.preserved_drawing_relationships {
    if relationship_ids_seen.contains(relationship.id) {
      raise InvalidSheetOperation(
        msg="duplicate preserved drawing relationship id",
      )
    }
    relationship_ids_seen.add(relationship.id)
    relationship_ids.push(relationship.id)
    drawing_relationships.push(
      remap_preserved_drawing_relationship(relationship, output_paths),
    )
  }
  {
    anchors: sheet.preserved_drawing_anchors.copy(),
    drawing_relationships,
    parts,
    relationship_ids,
    object_ids: opaque_drawing_object_ids(sheet.preserved_drawing_anchors),
  }
}

///|
fn collect_preserved_drawing_parts(
  initial_paths : ArrayView[String],
  archive : @zip.Archive,
  part_names : Map[String, String],
  content_types : @ooxml.PackageContentTypes,
  decode : (BytesView) -> String raise XlsxError,
  budget? : ReadBudget,
  cancelled? : () -> Bool = () => false,
) -> Array[PreservedDrawingPart] raise XlsxError {
  let parts : Array[PreservedDrawingPart] = []
  let queue : Array[String] = []
  queue.append(initial_paths)
  let seen : Set[String] = Set([])
  let mut cursor = 0
  while cursor < queue.length() {
    match budget {
      Some(value) => value.checkpoint()
      None => ()
    }
    let source_path = queue[cursor]
    cursor = cursor + 1
    let key = @ooxml.package_part_name_key(source_path)
    if seen.contains(key) {
      continue
    }
    seen.add(key)
    let actual_path = actual_archive_part_path(part_names, source_path)
    let data = match archive.get(actual_path) {
      Some(value) => value.to_owned()
      None => raise MissingPart(path=actual_path)
    }
    let content_type = declared_part_content_type(
      content_types,
      source_path,
      "preserved drawing part",
      cancelled~,
    )
    let relationships = match
      load_optional_relationship_part(
        archive,
        content_types,
        actual_relationship_part_path(actual_path, part_names),
        "preserved drawing relationships",
        cancelled~,
      ) {
      Some(bytes) =>
        preserved_drawing_relationships_from_xml(
          decode(bytes),
          source_path,
          part_names,
          budget?,
          cancelled~,
        )
      None => []
    }
    for relationship in relationships {
      match relationship.target_part {
        Some(target_part) => queue.push(target_part)
        None => ()
      }
    }
    match budget {
      Some(value) => value.charge_items(1)
      None => ()
    }
    parts.push({ source_path, data, content_type, relationships })
  }
  parts
}

///|
fn preserved_unsupported_drawing_state(
  anchors : ArrayView[DrawingAnchor],
  drawing_rels_xml : StringView,
  drawing_part : StringView,
  archive : @zip.Archive,
  part_names : Map[String, String],
  content_types : @ooxml.PackageContentTypes,
  decode : (BytesView) -> String raise XlsxError,
  budget? : ReadBudget,
  cancelled? : () -> Bool = () => false,
) -> (
  Array[PreservedDrawingAnchor],
  Array[PreservedDrawingRelationship],
  Array[PreservedDrawingPart],
) raise XlsxError {
  let opaque_anchors : Array[PreservedDrawingAnchor] = []
  let required_ids : Array[String] = []
  let required_ids_seen : Set[String] = Set([])
  for anchor in anchors {
    if !anchor.unsupported {
      continue
    }
    opaque_anchors.push({ order: anchor.order, xml: anchor.xml })
    for id in opaque_drawing_relationship_ids(anchor.xml, cancelled~) {
      if !required_ids_seen.contains(id) {
        required_ids_seen.add(id)
        required_ids.push(id)
      }
    }
  }
  if opaque_anchors.length() == 0 || required_ids.length() == 0 {
    return (opaque_anchors, [], [])
  }
  if drawing_rels_xml == "" {
    raise InvalidXml(msg="unsupported drawing relationship missing")
  }
  let all_relationships = preserved_drawing_relationships_from_xml(
    drawing_rels_xml,
    drawing_part,
    part_names,
    budget?,
    cancelled~,
  )
  let relationship_indices : Map[String, Int] = Map([])
  for index, relationship in all_relationships {
    relationship_indices[relationship.id] = index
  }
  let direct_relationships : Array[PreservedDrawingRelationship] = []
  let initial_paths : Array[String] = []
  let initial_seen : Set[String] = Set([])
  for id in required_ids {
    let relationship = match relationship_indices.get(id) {
      Some(index) => all_relationships[index]
      None => raise InvalidXml(msg="unsupported drawing relationship missing")
    }
    direct_relationships.push(relationship)
    match relationship.target_part {
      Some(path) => {
        let key = @ooxml.package_part_name_key(path)
        if !initial_seen.contains(key) {
          initial_seen.add(key)
          initial_paths.push(path)
        }
      }
      None => ()
    }
  }
  let parts = collect_preserved_drawing_parts(
    initial_paths,
    archive,
    part_names,
    content_types,
    decode,
    budget?,
    cancelled~,
  )
  (opaque_anchors, direct_relationships, parts)
}
