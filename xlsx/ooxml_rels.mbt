///|
fn parse_relationship_targets(
  xml : StringView,
  rel_type : StringView,
) -> Map[String, String] raise XlsxError {
  @ooxml.parse_relationship_targets(xml, rel_type) catch {
    @ooxml.ParseXmlError::InvalidXml(msg~) => raise InvalidXml(msg~)
  }
}

///|
fn first_relationship_target(targets : Map[String, String]) -> String? {
  for _, target in targets {
    return Some(target)
  }
  None
}

///|
fn rels_path_for(path : StringView, folder : StringView) -> String {
  let path_str = path.to_string()
  let prefix = "xl/\{folder.to_string()}/"
  if path_str.has_prefix(prefix) {
    path_str.replace_all(old=prefix, new="xl/\{folder.to_string()}/_rels/") +
    ".rels"
  } else {
    "xl/\{folder.to_string()}/_rels/" + path_str + ".rels"
  }
}

///|
fn parse_id_from_path(path : StringView, prefix : StringView) -> Int {
  let path_str = path.to_string()
  let prefix_str = prefix.to_string()
  if !path_str.has_prefix(prefix_str) || !path_str.has_suffix(".xml") {
    return 0
  }
  let start = prefix_str.length()
  let end = path_str.length() - 4
  if start > end {
    return 0
  }
  let sb = StringBuilder::new()
  for i, ch in path_str {
    if i >= start && i < end {
      sb.write_view(ch.to_string())
    }
  }
  @strconv.parse_int(sb.to_string(), base=10) catch {
    _ => 0
  }
}

///|
fn drop_first_path_segment(path : StringView) -> String {
  match path.to_string().after("/") {
    Some(rest) => rest.to_string()
    None => path.to_string()
  }
}

///|
fn normalize_rel_part_path(path : StringView) -> String raise XlsxError {
  let segments : Array[String] = []
  for chunk in path.split("/") {
    let segment = chunk.to_string()
    if segment == "" || segment == "." {
      continue
    }
    if segment == ".." {
      if segments.length() == 0 {
        raise InvalidXml(msg="relationship target invalid")
      }
      ignore(segments.pop())
      continue
    }
    segments.push(segment)
  }
  if segments.length() == 0 {
    raise InvalidXml(msg="relationship target invalid")
  }
  segments.join("/")
}

///|
fn resolve_rel_target(
  target : StringView,
  base_folder : StringView,
) -> String raise XlsxError {
  let target_str = target.to_string()
  let raw = if target_str.has_prefix("/") {
    drop_first_path_segment(target_str)
  } else if target_str.has_prefix("../") {
    "xl/" + base_folder.to_string() + "/" + target_str
  } else if target_str.has_prefix("xl/") {
    target_str
  } else {
    let base = base_folder.to_string()
    if base.has_suffix("/") {
      "xl/" + base + target_str
    } else {
      "xl/" + base + "/" + target_str
    }
  }
  let normalized = normalize_rel_part_path(raw)
  if !normalized.has_prefix("xl/") {
    raise InvalidXml(msg="relationship target invalid")
  }
  normalized
}

///|
fn resolve_workbook_rel_target(target : StringView) -> String raise XlsxError {
  let target_str = target.to_string()
  let raw = if target_str.has_prefix("/") {
    drop_first_path_segment(target_str)
  } else if target_str.has_prefix("../") {
    "xl/" + drop_first_path_segment(target_str)
  } else if target_str.has_prefix("xl/") {
    target_str
  } else {
    "xl/" + target_str
  }
  let normalized = normalize_rel_part_path(raw)
  if !normalized.has_prefix("xl/") {
    raise InvalidXml(msg="relationship target invalid")
  }
  normalized
}
