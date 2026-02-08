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
  let slice = path_str[start:end] catch { _ => return 0 }
  @strconv.parse_int(slice.to_string(), base=10) catch {
    _ => 0
  }
}

///|
fn resolve_rel_target(
  target : StringView,
  base_folder : StringView,
) -> String raise XlsxError {
  let target_str = target.to_string()
  if target_str.has_prefix("/") {
    let rest = target_str[1:] catch {
        _ => raise InvalidXml(msg="relationship target invalid")
      }
    rest.to_string()
  } else if target_str.has_prefix("../") {
    let rest = target_str[3:] catch {
        _ => raise InvalidXml(msg="relationship target invalid")
      }
    "xl/" + rest.to_string()
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
}

///|
fn resolve_workbook_rel_target(target : StringView) -> String raise XlsxError {
  let target_str = target.to_string()
  if target_str.has_prefix("/") {
    let rest = target_str[1:] catch {
        _ => raise InvalidXml(msg="relationship target invalid")
      }
    rest.to_string()
  } else if target_str.has_prefix("../") {
    let rest = target_str[3:] catch {
        _ => raise InvalidXml(msg="relationship target invalid")
      }
    "xl/" + rest.to_string()
  } else if target_str.has_prefix("xl/") {
    target_str
  } else {
    "xl/" + target_str
  }
}
