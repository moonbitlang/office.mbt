///|
let max_package_validation_findings = 256

///|
let package_validation_omission_message = "additional package findings were omitted after the bounded validator limit"

///|
fn push_package_problem(problems : Array[String], problem : String) -> Bool {
  if problems.length() < max_package_validation_findings - 1 {
    problems.push(problem)
    true
  } else {
    if problems.length() == max_package_validation_findings - 1 {
      problems.push(package_validation_omission_message)
    }
    false
  }
}

///|
/// Applies the same aggregate XML-byte and markup-token policy as the complete
/// workbook reader before package validation starts decoding or scanning
/// package plumbing. Counting every XML-like package part makes the validation
/// boundary deterministic and prevents many individually-small relationship
/// parts from bypassing the aggregate read policy.
fn enforce_package_validation_xml_limits(
  archive : @zip.Archive,
  limits : ReadLimits,
) -> Unit raise XlsxError {
  let mut total_xml_bytes = 0
  let mut markup_tokens = 0
  for entry in archive.entries() {
    if !is_xml_package_part(entry.name()) {
      continue
    }
    let data = entry.data()
    if data.length() > limits.max_total_xml_bytes - total_xml_bytes {
      raise ResourceLimitExceeded(
        kind="total_xml_bytes",
        limit=limits.max_total_xml_bytes,
        actual=bounded_actual_above_limit(limits.max_total_xml_bytes),
      )
    }
    total_xml_bytes = total_xml_bytes + data.length()
    for byte in data {
      if byte == b'<' {
        if markup_tokens >= limits.max_xml_markup_tokens {
          raise ResourceLimitExceeded(
            kind="xml_markup_tokens",
            limit=limits.max_xml_markup_tokens,
            actual=bounded_actual_above_limit(limits.max_xml_markup_tokens),
          )
        }
        markup_tokens = markup_tokens + 1
      }
    }
  }
}

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
///  - the core workbook parts are present
///
/// This is a fast, dependency-free complement to the Microsoft OpenXML
/// SDK validator: it runs entirely in MoonBit, so it can be asserted on
/// every workbook a test generates. An unreadable ZIP is returned as a stable
/// finding; resource-policy violations raise `ResourceLimitExceeded`. Findings
/// are capped at 256 while scanning, with a final omission marker when more
/// defects exist, so diagnostics cannot become an attacker-sized second tree.
pub fn validate_ooxml_package(
  bytes : BytesView,
  limits? : ReadLimits = ReadLimits::new(),
) -> Array[String] raise XlsxError {
  let archive = read_limited_archive(bytes, limits) catch {
    InvalidPackage(_) => return ["archive is not a readable zip"]
    error => raise error
  }
  validate_ooxml_bounded_archive(archive, limits~) catch {
    InvalidPackage(_) => ["archive is not a readable zip"]
    error => raise error
  }
}

///|
/// Validates an already-inflated OOXML package without decompressing it again.
/// The same pristine bounded-provenance contract as `read_bounded_archive`
/// applies.
pub fn validate_ooxml_bounded_archive(
  archive : @zip.Archive,
  limits? : ReadLimits = ReadLimits::new(),
) -> Array[String] raise XlsxError {
  require_bounded_archive(archive, limits)
  enforce_package_validation_xml_limits(archive, limits)
  validate_ooxml_archive(archive)
}

///|
fn validate_ooxml_archive(archive : @zip.Archive) -> Array[String] {
  let problems : Array[String] = []
  let parts : Map[String, Int] = Map([])
  for entry in archive.entries() {
    let name = entry.name()
    parts[name] = parts.get(name).unwrap_or(0) + 1
    if name.contains("\\") {
      if !push_package_problem(problems, "part name uses a backslash: \{name}") {
        return problems
      }
    }
    if name.has_prefix("/") {
      if !push_package_problem(
          problems,
          "part name has a leading slash: \{name}",
        ) {
        return problems
      }
    }
  }
  for name, count in parts {
    if count > 1 {
      if !push_package_problem(
          problems,
          "duplicate part: \{name} (\{count} entries)",
        ) {
        return problems
      }
    }
  }

  // required core parts
  for
    required in [
      "[Content_Types].xml", "_rels/.rels", "xl/workbook.xml", "xl/_rels/workbook.xml.rels",
    ] {
    if !parts.contains(required) {
      if !push_package_problem(problems, "missing required part: \{required}") {
        return problems
      }
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
          if !push_package_problem(
              problems,
              "part has no declared content type: \{name}",
            ) {
            return problems
          }
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
    let mut first = true
    // Process one relationship at a time. The aggregate token preflight above
    // bounds scan work, while avoiding a second target array proportional to
    // attacker-controlled relationship count.
    for chunk in rels_xml.split("<Relationship ") {
      if first {
        first = false
        continue
      }
      let end = match chunk.find(">") {
        Some(pos) => pos
        None => continue
      }
      let tag = chunk[:end]
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
      if external {
        continue
      }
      let resolved = resolve_part_path(base, target)
      if resolved != "" && !parts.contains(resolved) {
        if !push_package_problem(
            problems,
            "relationship in \{name} points to a missing part: \{target} -> \{resolved}",
          ) {
          return problems
        }
      }
    }
  }
  problems
}

///|
/// Decodes a package part as UTF-8, tolerating a leading BOM. Used only
/// for the ASCII-structured package plumbing (content types, rels).
fn decode_package_part(data : BytesView) -> String {
  @encoding/utf8.decode(data, ignore_bom=true) catch {
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
    let end = match chunk.find(">") {
      Some(pos) => pos
      None => continue
    }
    let ext = attr_value(chunk[:end], "Extension") catch { _ => None }
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
    let end = match chunk.find(">") {
      Some(pos) => pos
      None => continue
    }
    let part = attr_value(chunk[:end], "PartName") catch { _ => None }
    match part {
      Some(part) => overrides[part] = true
      None => ()
    }
  }
  (defaults, overrides)
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
}
