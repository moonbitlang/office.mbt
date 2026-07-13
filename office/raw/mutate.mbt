///|
priv struct RawSpanEdit {
  start : Int
  end : Int
  replacement : Bytes
  ordinal : Int
}

///|
fn checked_fragment_bytes(xml : String) -> Bytes raise RawError {
  if !raw_text_is_well_formed(xml) {
    raise raw_error(
      "office.raw.invalid_fragment", "XML fragment contains an isolated UTF-16 surrogate",
    )
  }
  let trimmed = xml.trim()
  if trimmed.has_prefix("<?xml ") ||
    trimmed.has_prefix("<?xml\t") ||
    trimmed.has_prefix("<?xml\r") ||
    trimmed.has_prefix("<?xml\n") {
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
  let mut root_index = -1
  for index, node in document.nodes {
    if node.parent == -1 {
      roots = roots + 1
      root_index = index
    }
  }
  if roots != 1 {
    raise raw_error(
      "office.raw.invalid_fragment", "XML fragment must contain exactly one self-contained element",
    )
  }
  let root = document.nodes[root_index]
  for byte in document.bytes[:root.start] {
    if !raw_byte_is_space(byte) {
      raise raw_error(
        "office.raw.invalid_fragment", "XML fragment may contain only whitespace outside its single element",
      )
    }
  }
  for byte in document.bytes[root.end:] {
    if !raw_byte_is_space(byte) {
      raise raw_error(
        "office.raw.invalid_fragment", "XML fragment may contain only whitespace outside its single element",
      )
    }
  }
  let root_has_default_namespace = root.declarations.any(declaration => {
    declaration.prefix == ""
  })
  if root_has_default_namespace {
    return bytes
  }
  // A standalone fragment with no default declaration gives every unprefixed
  // element the empty namespace. Make that semantic explicit before splicing
  // so the destination element's inherited default namespace cannot silently
  // change the fragment's expanded names.
  let output = Buffer()
  output.write_bytesview(bytes[:root.tag_insert_offset])
  output.write_bytes(b" xmlns=\"\"")
  output.write_bytesview(bytes[root.tag_insert_offset:])
  let normalized = output.contents()
  ignore(scan_raw_xml("<fragment>", normalized))
  normalized
}

///|
fn checked_document_bytes(xml : String) -> Bytes raise RawError {
  if !raw_text_is_well_formed(xml) {
    raise raw_error(
      "office.raw.invalid_xml", "replacement XML contains an isolated UTF-16 surrogate",
    )
  }
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
      '\t' => output.write_string("&#x9;") |> ignore
      '\n' => output.write_string("&#xA;") |> ignore
      '\r' => output.write_string("&#xD;") |> ignore
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
  if source.length() == 0 ||
    !raw_text_within_scalar_limit(source, raw_max_name_length * 2 + 1) {
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
fn checked_raw_result_size(
  part : String,
  current : Int,
  removed : Int,
  inserted : Int,
) -> Int raise RawError {
  if removed < 0 || removed > current || inserted < 0 {
    raise raw_error(
      "office.raw.overlapping_edits",
      "raw XML edit size accounting failed for '/\{part}'",
    )
  }
  let retained = current - removed
  if inserted > raw_max_edit_part_bytes - retained {
    raise raw_error(
      "office.raw.resource_limit",
      "raw XML edit result for '/\{part}' exceeds the \{raw_max_edit_part_bytes}-byte limit",
      details=Json::object({
        "kind": Json::string("xml_result_bytes"),
        "limit": Json::number(raw_max_edit_part_bytes.to_double()),
        "actual": Json::number((raw_max_edit_part_bytes + 1).to_double()),
      }),
    )
  }
  retained + inserted
}

///|
fn preflight_raw_edit_size(
  part : String,
  document : RawXmlDocument,
  selected : ArrayView[Int],
  action : RawAction,
  fragment : Bytes?,
  attribute_name : RawExpandedName?,
  escaped_attribute_value : Bytes?,
) -> Unit raise RawError {
  let mut projected = document.bytes.length()
  for node_index in selected {
    let node = document.nodes[node_index]
    let (removed, inserted) = match action {
      Append | Prepend => {
        let child_length = fragment.unwrap().length()
        if node.self_closing {
          let closing_length = @utf8.encode("</" + node.raw_name + ">").length()
          (
            node.end - node.start,
            node.tag_insert_offset -
            node.start +
            1 +
            child_length +
            closing_length,
          )
        } else {
          (0, child_length)
        }
      }
      InsertBefore | InsertAfter => (0, fragment.unwrap().length())
      Replace => (node.end - node.start, fragment.unwrap().length())
      Remove => (node.end - node.start, 0)
      SetAttribute => {
        let name = attribute_name.unwrap()
        let value_length = escaped_attribute_value.unwrap().length()
        let mut existing : (Int, Int)? = None
        for attribute in node.attributes {
          if attribute.expanded == name.expanded {
            existing = Some(
              (attribute.value_end - attribute.value_start, value_length),
            )
            break
          }
        }
        match existing {
          Some(size) => size
          None => {
            let source_name = raw_attribute_source_name(
              document, node_index, name,
            )
            (0, 4 + @utf8.encode(source_name).length() + value_length)
          }
        }
      }
    }
    projected = checked_raw_result_size(part, projected, removed, inserted)
  }
}

///|
fn raw_element_edit(
  document : RawXmlDocument,
  node_index : Int,
  action : RawAction,
  fragment : Bytes?,
  attribute_name : RawExpandedName?,
  escaped_attribute_value : Bytes?,
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
      let escaped = escaped_attribute_value.unwrap()
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
      let insertion_buffer = Buffer()
      insertion_buffer.write_bytes(@utf8.encode(" " + source_name + "=\""))
      insertion_buffer.write_bytes(escaped)
      insertion_buffer.write_byte(b'"')
      let insertion = insertion_buffer.contents()
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
  let mut result_size = document.bytes.length()
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
    result_size = checked_raw_result_size(
      part,
      result_size,
      edit.end - edit.start,
      edit.replacement.length(),
    )
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
  if result.length() != result_size {
    raise raw_error(
      "office.raw.invalid_xml", "raw XML edit result size did not match its bounded preflight",
    )
  }
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
  ignore(open_raw_package_for_format(format, bytes)) catch {
    RawError(code~, message~, details~) =>
      raise raw_error(
        "office.raw.validation_failed",
        "raw mutation failed the complete bounded raw-package validation: \{message}",
        details=match details {
          Some(value) => value
          None => Json::object({ "cause": Json::string(code) })
        },
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
  (part, self.part_bytes(part))
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
  let namespaces = edit_path_namespaces(format, request, document)
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
  let escaped_attribute_value = match request.value {
    Some(value) => Some(@utf8.encode(raw_escape_attribute(value)))
    None => None
  }
  preflight_raw_edit_size(
    part,
    document,
    selected,
    request.action,
    fragment,
    attribute_name,
    escaped_attribute_value,
  )
  let edits : Array[RawSpanEdit] = []
  for ordinal, node_index in selected {
    edits.push(
      raw_element_edit(
        document,
        node_index,
        request.action,
        fragment,
        attribute_name,
        escaped_attribute_value,
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
