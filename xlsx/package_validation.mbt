///|
/// Checks the structural invariants an OOXML (xlsx) package must satisfy
/// for Microsoft Excel to open it without a repair prompt, returning the
/// list of problems found (empty when the package is well-formed). These
/// are the package-level rules the OOXML schema validator does not fully
/// cover and that are the common causes of Excel's "we found a problem"
/// dialog:
///
///  - the archive is a readable zip
///  - `[Content_Types].xml` and the root `_rels/.rels` exist
///  - every part is covered by a Default (by extension) or an Override
///    content type
///  - every relationship target (except external ones) resolves to a
///    part that exists in the package
///  - no duplicate part names, and part names are well-formed
///  - the relationship-discovered workbook and its relationships part exist
///
/// This is a fast, dependency-free complement to the Microsoft OpenXML
/// SDK validator: it runs entirely in MoonBit, so it can be asserted on
/// every workbook a test generates.
///
/// `main_part` is the normalized target of the package's root
/// `officeDocument` relationship. Direct callers may omit it for the canonical
/// `xl/workbook.xml` layout.
pub fn validate_ooxml_package(
  bytes : BytesView,
  main_part? : String = "xl/workbook.xml",
) -> Array[String] {
  let problems : Array[String] = []
  let archive = @zip.read(bytes) catch {
    err => {
      problems.push("archive is not a readable zip: \{repr(err)}")
      return problems
    }
  }
  let parts : Map[String, Int] = Map([])
  for entry in archive.entries() {
    let name = entry.name()
    parts[name] = parts.get(name).unwrap_or(0) + 1
    if name.contains("\\") {
      problems.push("part name uses a backslash: \{name}")
    }
    if name.has_prefix("/") {
      problems.push("part name has a leading slash: \{name}")
    }
  }
  for name, count in parts {
    if count > 1 {
      problems.push("duplicate part: \{name} (\{count} entries)")
    }
  }

  // Required core parts. Callers such as `bobzhang/office` pass the
  // relationship-discovered workbook; direct callers get the canonical path.
  let main_rels_part = relationships_part_for(main_part)
  for
    required in [
      "[Content_Types].xml", "_rels/.rels", main_part, main_rels_part,
    ] {
    if !parts.contains(required) {
      problems.push("missing required part: \{required}")
    }
  }

  // content-type coverage
  match archive.get("[Content_Types].xml") {
    Some(data) => {
      let ct = decode_package_part(data)
      let (defaults, overrides) = parse_content_types(ct)
      for entry in archive.entries() {
        let name = entry.name()
        if name == "[Content_Types].xml" {
          continue
        }
        let has_override = overrides.contains("/" + name)
        let has_default = match part_extension(name) {
          Some(ext) => defaults.contains(ext.to_lower())
          None => false
        }
        if !has_override && !has_default {
          problems.push("part has no declared content type: \{name}")
        }
      }
    }
    None => ()
  }

  // relationship target integrity
  for entry in archive.entries() {
    let name = entry.name()
    if !name.has_suffix(".rels") {
      continue
    }
    let base = rels_base_dir(name)
    let rels_xml = decode_package_part(entry.data())
    for rel in parse_rel_targets(rels_xml) {
      let (target, external) = rel
      if external {
        continue
      }
      let resolved = resolve_part_path(base, target)
      if resolved != "" && !parts.contains(resolved) {
        problems.push(
          "relationship in \{name} points to a missing part: \{target} -> \{resolved}",
        )
      }
    }
  }
  problems
}

///|
fn relationships_part_for(part : String) -> String {
  match part.rev_find("/") {
    Some(slash) => "\{part[:slash]}/_rels/\{part[slash + 1:]}.rels"
    None => "_rels/\{part}.rels"
  }
}

///|
/// Decodes a package part as UTF-8, tolerating a leading BOM. Used only
/// for the ASCII-structured package plumbing (content types, rels).
fn decode_package_part(data : Bytes) -> String {
  @encoding/utf8.decode(data) catch {
    _ => ""
  }
}

///|
/// Returns the lowercase-ready file extension of a part name, or `None`.
fn part_extension(name : String) -> String? {
  match name.rev_find(".") {
    Some(dot) =>
      match name.rev_find("/") {
        Some(slash) =>
          if slash > dot {
            None
          } else {
            Some(name[dot + 1:].to_owned())
          }
        None => Some(name[dot + 1:].to_owned())
      }
    None => None
  }
}

///|
/// Parses `[Content_Types].xml` into the set of Default extensions
/// (lowercased) and the set of Override part names.
fn parse_content_types(xml : String) -> (Map[String, Bool], Map[String, Bool]) {
  let defaults : Map[String, Bool] = Map([])
  let overrides : Map[String, Bool] = Map([])
  let mut first = true
  for chunk in xml.split("<Default ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find(">") {
      Some(pos) => pos
      None => continue
    }
    let ext = attr_value(text[:end], "Extension") catch { _ => None }
    match ext {
      Some(ext) => defaults[ext.to_lower()] = true
      None => ()
    }
  }
  first = true
  for chunk in xml.split("<Override ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find(">") {
      Some(pos) => pos
      None => continue
    }
    let part = attr_value(text[:end], "PartName") catch { _ => None }
    match part {
      Some(part) => overrides[part] = true
      None => ()
    }
  }
  (defaults, overrides)
}

///|
/// Parses the relationship targets of a `.rels` part, returning each
/// (target, is_external) pair.
fn parse_rel_targets(xml : String) -> Array[(String, Bool)] {
  let result : Array[(String, Bool)] = []
  let mut first = true
  for chunk in xml.split("<Relationship ") {
    if first {
      first = false
      continue
    }
    let text = chunk.to_owned()
    let end = match text.find(">") {
      Some(pos) => pos
      None => continue
    }
    let tag = text[:end]
    let target_opt = attr_value(tag, "Target") catch { _ => None }
    let target = match target_opt {
      Some(value) => value
      None => continue
    }
    let mode_opt = attr_value(tag, "TargetMode") catch { _ => None }
    let external = match mode_opt {
      Some(mode) => mode == "External"
      None => false
    }
    result.push((target, external))
  }
  result
}

///|
/// The base directory a relationship target in `<dir>/_rels/<name>.rels`
/// resolves against: the directory containing the described part. For
/// the root `_rels/.rels` this is the package root ("").
fn rels_base_dir(rels_part : String) -> String {
  match rels_part.rev_find("_rels/") {
    Some(pos) => rels_part[:pos].to_owned()
    None => ""
  }
}

///|
/// Resolves a relationship target against a base directory, applying a
/// leading-slash absolute form and `.`/`..` segments. Returns "" when
/// the path escapes the package root (which the caller treats as
/// unresolvable rather than a definite error).
fn resolve_part_path(base : String, target : String) -> String {
  let combined = if target.has_prefix("/") {
    target[1:].to_owned()
  } else {
    base + target
  }
  let segments : Array[String] = []
  for segment in combined.split("/") {
    let seg = segment.to_owned()
    if seg == "" || seg == "." {
      continue
    }
    if seg == ".." {
      if segments.length() == 0 {
        return ""
      }
      segments.remove(segments.length() - 1) |> ignore
      continue
    }
    segments.push(seg)
  }
  segments.join("/")
}

///|
test "resolve_part_path handles real xlsx relationship shapes" {
  // worksheet rels -> drawing (../ climb)
  inspect(
    resolve_part_path("xl/worksheets/", "../drawings/drawing1.xml"),
    content="xl/drawings/drawing1.xml",
  )
  // workbook rels -> worksheet (plain descend)
  inspect(
    resolve_part_path("xl/", "worksheets/sheet1.xml"),
    content="xl/worksheets/sheet1.xml",
  )
  // root rels -> workbook
  inspect(resolve_part_path("", "xl/workbook.xml"), content="xl/workbook.xml")
  // package-absolute target
  inspect(
    resolve_part_path("xl/worksheets/", "/xl/media/image1.png"),
    content="xl/media/image1.png",
  )
  // ./ no-op segment
  inspect(
    resolve_part_path("xl/", "./theme/theme1.xml"),
    content="xl/theme/theme1.xml",
  )
  // escape-root returns "" (treated as skip, not error)
  inspect(resolve_part_path("", "../outside.xml"), content="")
}

///|
test "rels_base_dir and part_extension" {
  inspect(
    rels_base_dir("xl/worksheets/_rels/sheet1.xml.rels"),
    content="xl/worksheets/",
  )
  inspect(rels_base_dir("_rels/.rels"), content="")
  inspect(rels_base_dir("xl/_rels/workbook.xml.rels"), content="xl/")
  debug_inspect(
    part_extension("xl/worksheets/sheet1.xml"),
    content=(
      #|Some("xml")
    ),
  )
  debug_inspect(
    part_extension("xl/media/image1.PNG"),
    content=(
      #|Some("PNG")
    ),
  )
  debug_inspect(
    part_extension("_rels/.rels"),
    content=(
      #|Some("rels")
    ),
  )
  // no extension after last slash
  debug_inspect(part_extension("xl/theme"), content="None")
  inspect(
    relationships_part_for("custom/workbook.xml"),
    content="custom/_rels/workbook.xml.rels",
  )
  inspect(
    relationships_part_for("workbook.xml"),
    content="_rels/workbook.xml.rels",
  )
}
