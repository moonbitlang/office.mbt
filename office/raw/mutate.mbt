///|
priv struct RawSpanEdit {
  start : Int
  end : Int
  replacement : Bytes
  ordinal : Int
}

///|
fn checked_fragment_bytes(xml : String) -> Bytes raise RawError {
  let trimmed = xml.trim()
  if trimmed.has_prefix("<?xml") {
    raise raw_error(
      "office.raw.invalid_fragment", "inserted XML fragments cannot contain an XML declaration",
    )
  }
  let bytes = @utf8.encode(xml)
  if bytes.length() == 0 || bytes.length() > raw_max_fragment_bytes {
    raise raw_error(
      "office.raw.invalid_fragment",
      "XML fragment must contain 1 to \{raw_max_fragment_bytes} UTF-8 bytes",
    )
  }
  let document = scan_raw_xml("<fragment>", bytes)
  let mut roots = 0
  for node in document.nodes {
    if node.parent == -1 {
      roots = roots + 1
    }
  }
  if roots != 1 {
    raise raw_error(
      "office.raw.invalid_fragment", "XML fragment must contain exactly one self-contained element",
    )
  }
  bytes
}

///|
fn checked_document_bytes(xml : String) -> Bytes raise RawError {
  let bytes = @utf8.encode(xml)
  if bytes.length() == 0 || bytes.length() > raw_max_fragment_bytes {
    raise raw_error(
      "office.raw.invalid_xml",
      "replacement XML must contain 1 to \{raw_max_fragment_bytes} UTF-8 bytes",
    )
  }
  ignore(scan_raw_xml("<replacement>", bytes))
  bytes
}

///|
fn raw_escape_attribute(value : String) -> String {
  let output = StringBuilder::new()
  for character in value {
    match character {
      '&' => output.write_string("&amp;") |> ignore
      '<' => output.write_string("&lt;") |> ignore
      '>' => output.write_string("&gt;") |> ignore
      '"' => output.write_string("&quot;") |> ignore
      '\'' => output.write_string("&apos;") |> ignore
      _ => output.write_char(character) |> ignore
    }
  }
  output.to_string()
}

///|
fn parse_raw_attribute_name(
  source : String,
  namespaces : Map[String, String],
) -> RawExpandedName raise RawError {
  if source.length() == 0 || source.length() > raw_max_name_length * 2 + 1 {
    raise raw_error(
      "office.raw.invalid_attribute", "attribute name is empty or exceeds the bounded qualified-name limit",
    )
  }
  let parser = RawPathParser::{ source, offset: 0, namespaces }
  let name = parser.parse_qname() catch {
    RawError(code=_, message~, ..) =>
      raise raw_error("office.raw.invalid_attribute", message)
  }
  if parser.offset != source.length() ||
    name.prefix == "xmlns" ||
    (name.prefix == "" && name.local_name == "xmlns") {
    raise raw_error(
      "office.raw.invalid_attribute", "attribute must be one bounded non-xmlns qualified name",
    )
  }
  name
}

///|
fn raw_attribute_source_name(
  document : RawXmlDocument,
  node_index : Int,
  name : RawExpandedName,
) -> String raise RawError {
  if name.prefix == "" {
    return name.local_name
  }
  let namespaces = raw_effective_namespaces(document, node_index)
  match namespaces.get(name.prefix) {
    Some(uri) if uri == name.uri => return name.prefix + ":" + name.local_name
    _ => ()
  }
  let candidates : Array[String] = []
  for prefix, uri in namespaces {
    if prefix != "" && prefix != "xmlns" && uri == name.uri {
      candidates.push(prefix)
    }
  }
  candidates.sort()
  match candidates {
    [prefix, ..] => prefix + ":" + name.local_name
    [] =>
      raise raw_error(
        "office.raw.unbound_attribute_namespace",
        "selected element has no in-scope prefix for attribute namespace '\{name.uri}'",
      )
  }
}

///|
fn raw_self_closing_with_child(
  document : RawXmlDocument,
  node : RawXmlNode,
  child : Bytes,
) -> Bytes {
  let output = Buffer()
  output.write_bytesview(document.bytes[node.start:node.tag_insert_offset])
  output.write_byte(b'>')
  output.write_bytes(child)
  output.write_bytes(@utf8.encode("</" + node.raw_name + ">"))
  output.contents()
}

///|
fn raw_element_edit(
  document : RawXmlDocument,
  node_index : Int,
  action : RawAction,
  fragment : Bytes?,
  attribute_name : RawExpandedName?,
  attribute_value : String?,
  ordinal : Int,
) -> RawSpanEdit raise RawError {
  let node = document.nodes[node_index]
  match action {
    Append | Prepend => {
      let child = fragment.unwrap()
      if node.self_closing {
        return {
          start: node.start,
          end: node.end,
          replacement: raw_self_closing_with_child(document, node, child),
          ordinal,
        }
      }
      let at = if action is Append {
        node.end_tag_start
      } else {
        node.start_tag_end
      }
      { start: at, end: at, replacement: child, ordinal }
    }
    InsertBefore | InsertAfter => {
      if node.parent < 0 {
        raise raw_error(
          "office.raw.invalid_action",
          "\{action.name()} cannot target the document element",
        )
      }
      let at = if action is InsertBefore { node.start } else { node.end }
      { start: at, end: at, replacement: fragment.unwrap(), ordinal }
    }
    Replace =>
      {
        start: node.start,
        end: node.end,
        replacement: fragment.unwrap(),
        ordinal,
      }
    Remove => {
      if node.parent < 0 {
        raise raw_error(
          "office.raw.invalid_action", "remove cannot target the document element",
        )
      }
      { start: node.start, end: node.end, replacement: b"", ordinal }
    }
    SetAttribute => {
      let name = attribute_name.unwrap()
      let escaped = @utf8.encode(raw_escape_attribute(attribute_value.unwrap()))
      for attribute in node.attributes {
        if attribute.expanded == name.expanded {
          return {
            start: attribute.value_start,
            end: attribute.value_end,
            replacement: escaped,
            ordinal,
          }
        }
      }
      let source_name = raw_attribute_source_name(document, node_index, name)
      let insertion = @utf8.encode(
        " \{source_name}=\"\{raw_escape_attribute(attribute_value.unwrap())}\"",
      )
      {
        start: node.tag_insert_offset,
        end: node.tag_insert_offset,
        replacement: insertion,
        ordinal,
      }
    }
  }
}

///|
fn apply_raw_span_edits(
  part : String,
  document : RawXmlDocument,
  edits : Array[RawSpanEdit],
) -> Bytes raise RawError {
  edits.sort_by(fn(left, right) {
    if left.start != right.start {
      left.start - right.start
    } else if left.end != right.end {
      left.end - right.end
    } else {
      left.ordinal - right.ordinal
    }
  })
  let mut previous_end = 0
  for edit in edits {
    if edit.start < previous_end ||
      edit.start < 0 ||
      edit.end < edit.start ||
      edit.end > document.bytes.length() {
      raise raw_error(
        "office.raw.overlapping_edits",
        "raw XML edit spans overlap or exceed part '/\{part}'",
      )
    }
    previous_end = edit.end
  }
  let output = Buffer()
  let mut cursor = 0
  for edit in edits {
    output.write_bytesview(document.bytes[cursor:edit.start])
    output.write_bytes(edit.replacement)
    cursor = edit.end
  }
  output.write_bytesview(document.bytes[cursor:])
  let result = output.contents()
  ignore(scan_raw_xml(part, result))
  result
}

///|
fn rebuild_raw_archive(
  pkg : RawPackage,
  part : String,
  replacement : Bytes,
) -> Bytes raise RawError {
  let exact_name = match pkg.names.get(canonical_part_key(part)) {
    Some(name) => name
    None => part
  }
  if !pkg.archive.replace(exact_name, replacement) {
    raise raw_error(
      "office.raw.unknown_part",
      "package does not contain replacement part '/\{part}'",
    )
  }
  let bytes = @zip.write(pkg.archive) catch {
    _ =>
      raise raw_error(
        "office.raw.archive_write_failed", "could not build candidate OOXML archive",
      )
  }
  if bytes.length() > raw_max_package_bytes {
    raise raw_error(
      "office.raw.resource_limit",
      "candidate package exceeds the \{raw_max_package_bytes}-byte limit",
    )
  }
  bytes
}

///|
fn validate_raw_candidate(
  format : @office.DocumentFormat,
  bytes : Bytes,
) -> Unit raise RawError {
  let archive = read_bounded_archive(bytes)
  let _ = @office.detect_archive_format(raw_path_for_format(format), archive) catch {
    error =>
      raise raw_error(
        "office.raw.validation_failed",
        "raw mutation failed portable Office validation: \{error}",
      )
  }
}

///|
fn RawPackage::checked_xml_part(
  self : RawPackage,
  selector : String,
) -> (String, Bytes) raise RawError {
  let part = self.resolve_part(selector)
  let info = self.part_info(part)
  if !info.xml {
    raise raw_error(
      "office.raw.binary_edit_forbidden",
      "raw mutations are limited to existing XML parts; '/\{part}' is binary",
      details=Json::object({ "part": Json::string("/" + part) }),
    )
  }
  (part, self.archive.get(part).unwrap())
}

///|
/// Replaces one existing XML part and returns a pure, validated candidate.
pub fn raw_replace_part(
  format : @office.DocumentFormat,
  data : BytesView,
  part : String,
  xml : String,
) -> RawMutation raise RawError {
  validate_part_selector(part)
  let pkg = open_raw_package_for_format(format, data)
  let (resolved, _) = pkg.checked_xml_part(part)
  let replacement = checked_document_bytes(xml)
  let candidate = rebuild_raw_archive(pkg, resolved, replacement)
  validate_raw_candidate(format, candidate)
  { bytes: candidate, part: resolved, action: "replace-part", match_count: 1 }
}

///|
/// Applies one bounded element edit to an existing XML part and returns a
/// pure, validated candidate. Publication remains the A4 transaction's job.
pub fn raw_edit(
  format : @office.DocumentFormat,
  data : BytesView,
  request : RawEditRequest,
) -> RawMutation raise RawError {
  let pkg = open_raw_package_for_format(format, data)
  let (part, bytes) = pkg.checked_xml_part(request.part)
  let document = scan_raw_xml(part, bytes)
  let namespaces = edit_path_namespaces(format, request)
  let path = parse_raw_path(request.path, namespaces)
  let selected = select_raw_nodes(document, path, request.all)
  let fragment = match request.xml {
    Some(xml) => Some(checked_fragment_bytes(xml))
    None => None
  }
  let attribute_name = match request.attribute {
    Some(value) => Some(parse_raw_attribute_name(value, namespaces))
    None => None
  }
  let edits : Array[RawSpanEdit] = []
  for ordinal, node_index in selected {
    edits.push(
      raw_element_edit(
        document,
        node_index,
        request.action,
        fragment,
        attribute_name,
        request.value,
        ordinal,
      ),
    )
  }
  let replacement = apply_raw_span_edits(part, document, edits)
  let candidate = rebuild_raw_archive(pkg, part, replacement)
  validate_raw_candidate(format, candidate)
  {
    bytes: candidate,
    part,
    action: request.action.name(),
    match_count: selected.length(),
  }
}
