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
fn package_content_type_is_xml(value : StringView) -> Bool {
  let lower = value.to_owned().to_lower()
  let media_type = match lower.find(";") {
    Some(index) => lower[:index].trim()
    None => lower.trim()
  }
  media_type == "application/xml" ||
  media_type == "text/xml" ||
  media_type.has_suffix("+xml")
}

///|
fn package_validation_content_types(
  archive : @zip.Archive,
) -> @ooxml.PackageContentTypes? {
  match archive.get("[Content_Types].xml") {
    Some(data) =>
      Some(@ooxml.parse_package_content_types(decode_package_part(data))) catch {
        _ => None
      }
    None => None
  }
}

///|
/// Applies the same aggregate XML-byte and markup-token policy as the complete
/// workbook reader before package validation starts decoding or scanning
/// package plumbing. XML identity follows the package content-type manifest,
/// with conventional XML-like suffixes retained as a fail-closed fallback.
/// Counting every XML package part makes the validation boundary deterministic
/// and prevents many individually-small parts from bypassing the aggregate read
/// policy.
fn enforce_package_validation_xml_limits(
  archive : @zip.Archive,
  limits : ReadLimits,
) -> Unit raise XlsxError {
  let mut total_xml_bytes = 0
  let mut markup_tokens = 0
  let content_types = package_validation_content_types(archive)
  for entry in archive.entries() {
    let declared_xml = match content_types {
      Some(index) => {
        let declared = index.content_type_for(entry.name()) catch { _ => None }
        match declared {
          Some(value) => package_content_type_is_xml(value)
          None => false
        }
      }
      None => false
    }
    if !is_xml_package_part(entry.name()) && !declared_xml {
      continue
    }
    let data = entry.data()
    if data.length() > limits.max_xml_part_bytes {
      raise ResourceLimitExceeded(
        kind="xml_part_bytes",
        limit=limits.max_xml_part_bytes,
        actual=data.length(),
      )
    }
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
  preflight_archive_relationship_limits(archive, limits)
  validate_ooxml_archive(archive)
}

///|
fn validate_ooxml_archive(
  archive : @zip.Archive,
) -> Array[String] raise XlsxError {
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
    // Process one relationship at a time. The aggregate token preflight above
    // bounds scan work, while avoiding a second target array proportional to
    // attacker-controlled relationship count.
    for_each_relationship_start_tag(rels_xml, scanner => {
      let target_opt = relationship_scanner_attribute_view(scanner, "Target") catch {
        _ => None
      }
      match target_opt {
        Some(target) => {
          let mode_opt = relationship_scanner_attribute_view(
            scanner, "TargetMode",
          ) catch {
            _ => None
          }
          let external = match mode_opt {
            Some(mode) => mode == "External"
            None => false
          }
          if !external {
            let resolved = resolve_part_path(base, target)
            if resolved != "" && !parts.contains(resolved) {
              let source_text = package_diagnostic_excerpt(name, 160)
              let target_text = package_diagnostic_excerpt(target, 160)
              let resolved_text = package_diagnostic_excerpt(resolved, 160)
              if !push_package_problem(
                  problems,
                  "relationship in \{source_text} points to a missing part: \{target_text} -> \{resolved_text}",
                ) {
                return false
              }
            }
          }
        }
        None => ()
      }
      true
    })
    if problems.length() == max_package_validation_findings {
      return problems
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
fn package_diagnostic_excerpt(value : StringView, maximum : Int) -> String {
  if value.length() <= maximum {
    value.to_owned()
  } else {
    value[:maximum].to_owned() + "…"
  }
}

///|
fn resolve_part_path(base : StringView, target : StringView) -> String {
  let segments : Array[StringView] = []
  fn consume(value : StringView) -> Bool {
    for segment in value.split("/") {
      if segment == "" || segment == "." {
        continue
      }
      if segment == ".." {
        if segments.length() == 0 {
          return false
        }
        ignore(segments.pop())
      } else {
        segments.push(segment)
      }
    }
    true
  }
  if target.has_prefix("/") {
    if !consume(target[1:]) {
      return ""
    }
  } else if !consume(base) || !consume(target) {
    return ""
  }
  let result = StringBuilder::new()
  for index, segment in segments {
    if index > 0 {
      result.write_char('/')
    }
    result.write_view(segment)
  }
  result.to_string()
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
