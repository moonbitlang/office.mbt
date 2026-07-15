// Portable structural validation of a docx OPC package — the tier behind
// `docx validate` (native AND wasm; the .NET OpenXML SDK schema tier is a
// separate native-only development gate). Checks are package-structural,
// not schema-deep:
//
//   1. The archive opens, entry names are unique and well-formed, and each
//      entry's data matches its stored CRC-32 (the inflate path tolerates
//      corruption the CRC exposes — raw central-directory entries are used
//      because the map-backed reader wrapper silently drops duplicates).
//   2. `[Content_Types].xml` exists, parses as strict DTD-free XML, and covers
//      every part via an extension default or an exact override; overrides
//      point at parts that exist.
//   3. `_rels/.rels` exists, parses, and names an officeDocument
//      relationship whose target exists (the main document part is found by
//      FOLLOWING that relationship — never a hardcoded `word/document.xml`).
//   4. The selected part has the DOCX main content type and parses as strict
//      XML with a WordprocessingML `document` root whose namespace matches the
//      transitional or Strict officeDocument relationship dialect.
//   5. Every part's own relationships (`dir/_rels/name.rels`), when
//      present, parse and their internal targets resolve to existing parts.
//
// Returns findings as agent-readable strings; empty means structurally
// valid. Deliberately does NOT validate WordprocessingML content — that is
// the SDK tier's job.

///|
const CONTENT_TYPES_PART : String = "[Content_Types].xml"

///|
const ROOT_RELS_PART : String = "_rels/.rels"

///|
const PACKAGE_RELATIONSHIPS_NAMESPACE : String = "http://schemas.openxmlformats.org/package/2006/relationships"

///|
const CONTENT_TYPES_ROOT : String = "{http://schemas.openxmlformats.org/package/2006/content-types}Types"

///|
const RELATIONSHIPS_CONTENT_TYPE : String = "application/vnd.openxmlformats-package.relationships+xml"

///|
const CONTENT_TYPES_DEFAULT : String = "{http://schemas.openxmlformats.org/package/2006/content-types}Default"

///|
const CONTENT_TYPES_OVERRIDE : String = "{http://schemas.openxmlformats.org/package/2006/content-types}Override"

///|
const TRANSITIONAL_OFFICE_DOCUMENT_RELATIONSHIP : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"

///|
const STRICT_OFFICE_DOCUMENT_RELATIONSHIP : String = "http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument"

///|
const TRANSITIONAL_DOCUMENT_ROOT : String = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}document"

///|
const STRICT_DOCUMENT_ROOT : String = "{http://purl.oclc.org/ooxml/wordprocessingml/main}document"

///|
const DOCX_MAIN_CONTENT_TYPE : String = "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"

///|
const DEFAULT_MAX_FINDINGS : Int = 1024

///|
const DEFAULT_MAX_FINDING_CHARS : Int = 2048

///|
const DEFAULT_MAX_XML_SOURCE_UNITS : Int = 16 * 1024 * 1024

///|
const DEFAULT_MAX_XML_TOKENS : Int = 262_144

///|
const DEFAULT_MAX_XML_MATERIALIZED_CHARS : Int = 8 * 1024 * 1024

///|
const DEFAULT_MAX_XML_TOKEN_CHARS : Int = 4 * 1024 * 1024

///|
const DEFAULT_MAX_ZIP_ENTRIES : Int = 4096

///|
const DEFAULT_MAX_ZIP_ENTRY_UNCOMPRESSED_BYTES : Int = 32 * 1024 * 1024

///|
const DEFAULT_MAX_ZIP_TOTAL_UNCOMPRESSED_BYTES : Int = 128 * 1024 * 1024

///|
/// The resource guard that stopped structural validation. This status is kept
/// separate from rendered findings so attacker-controlled part names cannot
/// forge or hide resource exhaustion by changing diagnostic text.
pub(all) enum DocxValidationResourceLimit {
  ZipEntries
  ZipEntryUncompressedBytes
  ZipTotalUncompressedBytes
  XmlSourceUnits
  XmlTokens
  XmlTokenLength
  XmlMaterializedCharacters
  XmlNestingDepth
}

///|
/// Returns the stable machine name for this resource guard.
pub fn DocxValidationResourceLimit::name(
  self : DocxValidationResourceLimit,
) -> String {
  match self {
    ZipEntries => "zip-entry-count"
    ZipEntryUncompressedBytes => "zip-entry-uncompressed-bytes"
    ZipTotalUncompressedBytes => "zip-total-uncompressed-bytes"
    XmlSourceUnits => "xml-source-units"
    XmlTokens => "xml-tokens"
    XmlTokenLength => "xml-token-length"
    XmlMaterializedCharacters => "xml-materialized-characters"
    XmlNestingDepth => "xml-nesting-depth"
  }
}

///|
/// A bounded structural-validation result. Findings remain suitable for
/// humans; `resource_limit` is the authoritative machine classification.
pub struct DocxValidationReport {
  priv findings : Array[String]
  priv findings_truncated : Bool
  priv resource_limit : DocxValidationResourceLimit?
  priv main_document_part : String?
}

///|
/// Returns a defensive copy of the bounded human-readable findings.
pub fn DocxValidationReport::findings(
  self : DocxValidationReport,
) -> Array[String] {
  self.findings.copy()
}

///|
/// Reports whether validation stopped at the caller's finding-count ceiling.
pub fn DocxValidationReport::findings_truncated(
  self : DocxValidationReport,
) -> Bool {
  self.findings_truncated
}

///|
/// Returns the ZIP or XML resource guard that stopped validation, when present.
pub fn DocxValidationReport::resource_limit(
  self : DocxValidationReport,
) -> DocxValidationResourceLimit? {
  self.resource_limit
}

///|
/// Returns the exact physical archive entry selected by the validated
/// package-root officeDocument relationship. Callers that subsequently parse
/// the package should pin their reader to this identity so validation and
/// interpretation cannot diverge.
pub fn DocxValidationReport::main_document_part(
  self : DocxValidationReport,
) -> String? {
  self.main_document_part
}

///|
priv struct FindingCollector {
  findings : Array[String]
  max_findings : Int
  max_message_chars : Int
  xml_budget : @xml.XmlReadBudget
  mut truncated : Bool
  mut resource_limit : DocxValidationResourceLimit?
  mut main_document_part : String?
}

///|
fn FindingCollector::new_with_xml_limits(
  max_findings : Int,
  max_message_chars : Int,
  max_xml_source_units : Int,
  max_xml_tokens : Int,
  max_xml_materialized_chars : Int,
  max_xml_token_chars : Int,
) -> FindingCollector {
  {
    findings: [],
    max_findings: if max_findings > 0 {
      max_findings
    } else {
      0
    },
    max_message_chars: if max_message_chars > 0 {
      max_message_chars
    } else {
      0
    },
    xml_budget: @xml.xml_read_budget(
      max_source_units=if max_xml_source_units > 0 {
        max_xml_source_units
      } else {
        0
      },
      max_tokens=if max_xml_tokens > 0 { max_xml_tokens } else { 0 },
      max_materialized_chars=if max_xml_materialized_chars > 0 {
        max_xml_materialized_chars
      } else {
        0
      },
      max_token_chars=if max_xml_token_chars > 0 {
        max_xml_token_chars
      } else {
        0
      },
    ),
    truncated: false,
    resource_limit: None,
    main_document_part: None,
  }
}

///|
fn xml_validation_resource_limit(
  error : @core.DocxError,
) -> DocxValidationResourceLimit? {
  match error {
    InvalidXml(message~) =>
      match message {
        "XML source budget exceeded" => Some(XmlSourceUnits)
        "XML token budget exceeded" => Some(XmlTokens)
        "XML token length budget exceeded" => Some(XmlTokenLength)
        "XML materialized character budget exceeded" =>
          Some(XmlMaterializedCharacters)
        "XML nesting too deep" => Some(XmlNestingDepth)
        _ => None
      }
    _ => None
  }
}

///|
fn zip_validation_resource_limit(kind : String) -> DocxValidationResourceLimit? {
  match kind {
    "entry_count" => Some(ZipEntries)
    "entry_uncompressed_bytes" => Some(ZipEntryUncompressedBytes)
    "total_uncompressed_bytes" => Some(ZipTotalUncompressedBytes)
    _ => None
  }
}

///|
fn FindingCollector::mark_zip_resource_limit(
  self : FindingCollector,
  kind : String,
) -> Unit {
  if self.resource_limit is None {
    self.resource_limit = zip_validation_resource_limit(kind)
  }
}

///|
fn FindingCollector::mark_resource_limit(
  self : FindingCollector,
  error : @core.DocxError,
) -> Unit {
  if self.resource_limit is None {
    self.resource_limit = xml_validation_resource_limit(error)
  }
}

///|
fn FindingCollector::report(self : FindingCollector) -> DocxValidationReport {
  {
    findings: self.findings,
    findings_truncated: self.truncated,
    resource_limit: self.resource_limit,
    main_document_part: self.main_document_part,
  }
}

///|
fn valid_finding_text(text : String, limit : Int) -> Bool {
  let mut offset = 0
  let mut scalars = 0
  while offset < text.length() {
    let unit = text[offset]
    if unit.is_leading_surrogate() {
      if offset + 1 >= text.length() ||
        !text[offset + 1].is_trailing_surrogate() {
        return false
      }
      offset = offset + 2
    } else if unit.is_trailing_surrogate() {
      return false
    } else {
      offset = offset + 1
    }
    scalars = scalars + 1
    if scalars > limit {
      return false
    }
  }
  true
}

///|
fn bounded_finding_text(text : String, limit : Int) -> String {
  if limit <= 0 {
    return ""
  }
  if valid_finding_text(text, limit) {
    return text
  }
  if !valid_finding_text(text, 0x7fffffff) {
    return bounded_finding_text("<invalid UTF-16>", limit)
  }
  let output = StringBuilder::new()
  let mut count = 0
  let content_limit = if limit > 1 { limit - 1 } else { 0 }
  for character in text {
    if count == content_limit {
      output.write_string("…") |> ignore
      break
    }
    output.write_char(character) |> ignore
    count = count + 1
  }
  output.to_string()
}

///|
fn FindingCollector::text(self : FindingCollector, text : String) -> String {
  bounded_finding_text(text, self.max_message_chars)
}

///|
fn FindingCollector::add(self : FindingCollector, message : String) -> Unit {
  if self.findings.length() >= self.max_findings {
    self.truncated = true
    return
  }
  self.findings.push(bounded_finding_text(message, self.max_message_chars))
}

///|
fn FindingCollector::full(self : FindingCollector) -> Bool {
  self.findings.length() >= self.max_findings
}

///|
fn FindingCollector::stop(self : FindingCollector) -> Unit {
  self.truncated = true
}

///|
fn default_findings(result : (Array[String], Bool)) -> Array[String] {
  let (findings, truncated) = result
  if truncated {
    if findings.length() == DEFAULT_MAX_FINDINGS {
      let _ = findings.pop()
    }
    findings.push("additional validation findings were omitted")
  }
  findings
}

///|
/// Validates docx package structure. Returns bounded findings; empty = valid.
pub fn validate_docx_package(data : BytesView) -> Array[String] {
  default_findings(
    validate_docx_package_limited(
      data,
      max_findings=DEFAULT_MAX_FINDINGS,
      max_message_chars=DEFAULT_MAX_FINDING_CHARS,
    ),
  )
}

///|
/// Validates package bytes while bounding findings as they are produced.
/// `truncated=true` means validation stopped after filling the caller's cap.
pub fn validate_docx_package_limited(
  data : BytesView,
  max_findings~ : Int,
  max_message_chars~ : Int,
  max_zip_entries? : Int = DEFAULT_MAX_ZIP_ENTRIES,
  max_zip_entry_uncompressed_bytes? : Int = DEFAULT_MAX_ZIP_ENTRY_UNCOMPRESSED_BYTES,
  max_zip_total_uncompressed_bytes? : Int = DEFAULT_MAX_ZIP_TOTAL_UNCOMPRESSED_BYTES,
  max_xml_source_units? : Int = DEFAULT_MAX_XML_SOURCE_UNITS,
  max_xml_tokens? : Int = DEFAULT_MAX_XML_TOKENS,
  max_xml_materialized_chars? : Int = DEFAULT_MAX_XML_MATERIALIZED_CHARS,
  max_xml_token_chars? : Int = DEFAULT_MAX_XML_TOKEN_CHARS,
) -> (Array[String], Bool) {
  let report = validate_docx_package_report_limited(
    data,
    max_findings~,
    max_message_chars~,
    max_zip_entries~,
    max_zip_entry_uncompressed_bytes~,
    max_zip_total_uncompressed_bytes~,
    max_xml_source_units~,
    max_xml_tokens~,
    max_xml_materialized_chars~,
    max_xml_token_chars~,
  )
  (report.findings, report.findings_truncated)
}

///|
/// The typed counterpart to `validate_docx_package_limited`. Resource status
/// is captured from the ZIP/XML error before any attacker-controlled text is
/// interpolated or truncated into a finding.
pub fn validate_docx_package_report_limited(
  data : BytesView,
  max_findings~ : Int,
  max_message_chars~ : Int,
  max_zip_entries? : Int = DEFAULT_MAX_ZIP_ENTRIES,
  max_zip_entry_uncompressed_bytes? : Int = DEFAULT_MAX_ZIP_ENTRY_UNCOMPRESSED_BYTES,
  max_zip_total_uncompressed_bytes? : Int = DEFAULT_MAX_ZIP_TOTAL_UNCOMPRESSED_BYTES,
  max_xml_source_units? : Int = DEFAULT_MAX_XML_SOURCE_UNITS,
  max_xml_tokens? : Int = DEFAULT_MAX_XML_TOKENS,
  max_xml_materialized_chars? : Int = DEFAULT_MAX_XML_MATERIALIZED_CHARS,
  max_xml_token_chars? : Int = DEFAULT_MAX_XML_TOKEN_CHARS,
) -> DocxValidationReport {
  let findings = FindingCollector::new_with_xml_limits(
    max_findings, max_message_chars, max_xml_source_units, max_xml_tokens, max_xml_materialized_chars,
    max_xml_token_chars,
  )
  let archive = @mbtzip.read_limited(
    data,
    max_entries=if max_zip_entries > 0 { max_zip_entries } else { 0 },
    max_entry_uncompressed_bytes=if max_zip_entry_uncompressed_bytes > 0 {
      max_zip_entry_uncompressed_bytes
    } else {
      0
    },
    max_total_uncompressed_bytes=if max_zip_total_uncompressed_bytes > 0 {
      max_zip_total_uncompressed_bytes
    } else {
      0
    },
  ) catch {
    ResourceLimitExceeded(kind~, limit=_, actual=_) as err => {
      findings.mark_zip_resource_limit(kind)
      findings.add("invalid ZIP archive: \{findings.text(repr(err))}")
      return findings.report()
    }
    err => {
      findings.add("invalid ZIP archive: \{findings.text(repr(err))}")
      return findings.report()
    }
  }
  validate_docx_archive_into(archive, findings)
  findings.report()
}

///|
/// Validates an already materialized DOCX archive without reading or inflating
/// the package again. The caller retains ownership; validation is read-only.
pub fn validate_docx_archive(archive : @mbtzip.Archive) -> Array[String] {
  default_findings(
    validate_docx_archive_limited(
      archive,
      max_findings=DEFAULT_MAX_FINDINGS,
      max_message_chars=DEFAULT_MAX_FINDING_CHARS,
    ),
  )
}

///|
/// Archive-backed validation with a hard finding count and per-message scalar
/// ceiling applied during production rather than after an unbounded array is
/// built.
pub fn validate_docx_archive_limited(
  archive : @mbtzip.Archive,
  max_findings~ : Int,
  max_message_chars~ : Int,
  max_xml_source_units? : Int = DEFAULT_MAX_XML_SOURCE_UNITS,
  max_xml_tokens? : Int = DEFAULT_MAX_XML_TOKENS,
  max_xml_materialized_chars? : Int = DEFAULT_MAX_XML_MATERIALIZED_CHARS,
  max_xml_token_chars? : Int = DEFAULT_MAX_XML_TOKEN_CHARS,
) -> (Array[String], Bool) {
  let report = validate_docx_archive_report_limited(
    archive,
    max_findings~,
    max_message_chars~,
    max_xml_source_units~,
    max_xml_tokens~,
    max_xml_materialized_chars~,
    max_xml_token_chars~,
  )
  (report.findings, report.findings_truncated)
}

///|
/// Archive-backed validation with typed resource-exhaustion status preserved
/// independently of bounded human findings.
pub fn validate_docx_archive_report_limited(
  archive : @mbtzip.Archive,
  max_findings~ : Int,
  max_message_chars~ : Int,
  max_xml_source_units? : Int = DEFAULT_MAX_XML_SOURCE_UNITS,
  max_xml_tokens? : Int = DEFAULT_MAX_XML_TOKENS,
  max_xml_materialized_chars? : Int = DEFAULT_MAX_XML_MATERIALIZED_CHARS,
  max_xml_token_chars? : Int = DEFAULT_MAX_XML_TOKEN_CHARS,
) -> DocxValidationReport {
  let findings = FindingCollector::new_with_xml_limits(
    max_findings, max_message_chars, max_xml_source_units, max_xml_tokens, max_xml_materialized_chars,
    max_xml_token_chars,
  )
  validate_docx_archive_into(archive, findings)
  findings.report()
}

///|
fn validate_docx_archive_into(
  archive : @mbtzip.Archive,
  findings : FindingCollector,
) -> Unit {
  // Raw entry sweep: names + CRC integrity, before any part-level logic.
  let parts : StableStringMap[BytesView] = SortedMap([])
  let canonical_names : StableStringMap[String] = SortedMap([])
  let logical_names : StableStringMap[String] = SortedMap([])
  let seen : StableStringSet = SortedSet([])
  for entry in archive.entries() {
    if findings.full() {
      findings.stop()
      return
    }
    let name = entry.name()
    if seen.contains(name) {
      findings.add("duplicate entry name: \{findings.text(name)}")
    } else {
      seen.add(name)
    }
    let logical_name = check_entry_name(name, findings)
    if entry.crc32() != @mbtzip.crc32(entry.data()) {
      findings.add(
        "entry data does not match its stored CRC-32: \{findings.text(name)}",
      )
    }
    if !name.has_suffix("/") {
      match logical_name {
        Some(logical) => {
          let key = part_name_key(logical)
          match canonical_names.get(key) {
            Some(existing) if existing != name =>
              findings.add(
                "duplicate entry name: \{findings.text(name)} (logically equivalent to \{findings.text(existing)})",
              )
            Some(_) => ()
            None => canonical_names[key] = name
          }
          logical_names[name] = logical
          parts[name] = entry.data()
        }
        None => ()
      }
    }
  }
  let content_types = check_content_types(parts, canonical_names, findings)
  check_relationships(
    parts, canonical_names, logical_names, content_types, findings,
  )
  match content_types {
    Some(types) =>
      check_content_type_coverage(parts, logical_names, types, findings)
    None => ()
  }
}

///|
fn actual_part_name(
  canonical_names : StableStringMap[String],
  requested : String,
) -> String? {
  canonical_names.get(part_name_key(requested))
}

///|
fn find_part(
  parts : StableStringMap[BytesView],
  canonical_names : StableStringMap[String],
  requested : String,
) -> (String, BytesView)? {
  guard actual_part_name(canonical_names, requested) is Some(actual) else {
    return None
  }
  match parts.get(actual) {
    Some(bytes) => Some((actual, bytes))
    None => None
  }
}

///|
fn contains_part(
  canonical_names : StableStringMap[String],
  requested : String,
) -> Bool {
  actual_part_name(canonical_names, requested) is Some(_)
}

///|
fn check_entry_name(name : String, findings : FindingCollector) -> String? {
  if name == "" {
    findings.add("empty entry name")
    return None
  }
  if name.has_prefix("/") {
    findings.add("entry name must not start with '/': \{findings.text(name)}")
  }
  if name.find("\\") is Some(_) {
    findings.add("entry name contains a backslash: \{findings.text(name)}")
    return None
  }
  // The package content-types stream is reserved package metadata rather than
  // an OPC part name, so its bracketed spelling is the one deliberate Pack-URI
  // exception.
  if part_name_key(name) == part_name_key(CONTENT_TYPES_PART) {
    return Some(CONTENT_TYPES_PART)
  }
  // Explicit ZIP directory records are not OPC parts, but they are valid and
  // preservation-safe package metadata. Validate their path without treating
  // the terminal directory slash as an empty interior segment.
  let item_path = if name.has_suffix("/") && name.length() > 1 {
    name[:name.length() - 1]
  } else {
    name
  }
  match logical_part_name_from_zip_item_name(item_path) {
    Some(logical) => if name.has_suffix("/") { None } else { Some(logical) }
    None => {
      for segment in item_path.split("/") {
        if segment == "" {
          findings.add(
            "entry name contains an empty segment: \{findings.text(name)}",
          )
          return None
        } else if segment == "." || segment == ".." {
          findings.add(
            "entry name contains a '\{segment}' segment: \{findings.text(name)}",
          )
          return None
        }
      }
      findings.add(
        "entry name is not a valid OPC URI path: \{findings.text(name)}",
      )
      None
    }
  }
}

///|
priv struct ContentTypes {
  defaults : StableStringMap[String]
  overrides : StableStringMap[String]
}

///|
fn check_content_types(
  parts : StableStringMap[BytesView],
  canonical_names : StableStringMap[String],
  findings : FindingCollector,
) -> ContentTypes? {
  guard find_part(parts, canonical_names, CONTENT_TYPES_PART)
    is Some((content_types_name, bytes)) else {
    findings.add("missing required part: \{CONTENT_TYPES_PART}")
    return None
  }
  guard parse_xml_part(content_types_name, bytes, findings) is Some(root) else {
    return None
  }
  if root.name != CONTENT_TYPES_ROOT {
    findings.add(
      "\{CONTENT_TYPES_PART}: root element is not in the OPC content-types namespace",
    )
    return None
  }
  let defaults : StableStringMap[String] = SortedMap([])
  let overrides : StableStringMap[String] = SortedMap([])
  for node in root.children {
    if findings.full() {
      findings.stop()
      break
    }
    guard node is XmlElement(element) else { continue }
    match element.name {
      CONTENT_TYPES_DEFAULT =>
        match
          (
            element.attributes.get("Extension"),
            element.attributes.get("ContentType"),
          ) {
          (Some(extension), Some(content_type)) => {
            let key = extension.to_lower()
            if defaults.contains(key) {
              findings.add(
                "\{CONTENT_TYPES_PART}: duplicate Default Extension after case normalization: \{findings.text(key)}",
              )
            } else {
              defaults[key] = content_type
            }
          }
          _ =>
            findings.add(
              "\{CONTENT_TYPES_PART}: Default missing Extension or ContentType",
            )
        }
      CONTENT_TYPES_OVERRIDE =>
        match
          (
            element.attributes.get("PartName"),
            element.attributes.get("ContentType"),
          ) {
          (Some(part_name), Some(content_type)) =>
            // Only a '/'-prefixed PartName can be resolved to an entry; an
            // empty or slash-less one is itself the finding (and slicing it
            // would abort on attacker-supplied input).
            if part_name.has_prefix("/") {
              match normalize_override_part_name(part_name) {
                Some(key) => {
                  let collision_key = part_name_key(key)
                  if overrides.contains(collision_key) {
                    findings.add(
                      "\{CONTENT_TYPES_PART}: duplicate Override PartName after path normalization: \{findings.text(key)}",
                    )
                  } else {
                    overrides[collision_key] = content_type
                  }
                  if key != part_name {
                    findings.add(
                      "\{CONTENT_TYPES_PART}: Override PartName is not canonical: \{findings.text(part_name)}",
                    )
                  }
                  let target = key[1:].to_owned()
                  if !contains_part(canonical_names, target) {
                    findings.add(
                      "\{CONTENT_TYPES_PART}: Override names a missing part: \{findings.text(key)}",
                    )
                  }
                }
                None =>
                  findings.add(
                    "\{CONTENT_TYPES_PART}: Override PartName is invalid: \{findings.text(part_name)}",
                  )
              }
            } else {
              findings.add(
                "\{CONTENT_TYPES_PART}: Override PartName must start with '/': \{findings.text(part_name)}",
              )
            }
          _ =>
            findings.add(
              "\{CONTENT_TYPES_PART}: Override missing PartName or ContentType",
            )
        }
      _ =>
        if local_name(element.name) == "Default" ||
          local_name(element.name) == "Override" {
          findings.add(
            "\{CONTENT_TYPES_PART}: \{findings.text(local_name(element.name))} element is outside the OPC content-types namespace",
          )
        }
    }
  }
  Some({ defaults, overrides })
}

///|
fn normalize_override_part_name(part_name : String) -> String? {
  // Callers establish the leading slash. `resolve_target` removes redundant
  // dot segments, giving declarations one collision key while the separate
  // canonicality finding rejects noncanonical spellings.
  match resolve_part_target("", part_name) {
    Some(target) => Some("/" + target)
    None => None
  }
}

///|
fn check_content_type_coverage(
  parts : StableStringMap[BytesView],
  logical_names : StableStringMap[String],
  types : ContentTypes,
  findings : FindingCollector,
) -> Unit {
  for name, _ in parts {
    if findings.full() {
      findings.stop()
      return
    }
    guard logical_names.get(name) is Some(logical_name) else { continue }
    if part_name_key(logical_name) == part_name_key(CONTENT_TYPES_PART) {
      continue
    }
    if types.overrides.contains(part_name_key("/" + logical_name)) {
      continue
    }
    let extension = part_extension(logical_name)
    if extension is Some(ext) && types.defaults.contains(ext) {
      continue
    }
    findings.add("no content type for part: \{findings.text(name)}")
  }
}

///|
fn part_extension(name : String) -> String? {
  match name.rev_find(".") {
    Some(dot) => {
      // The extension must belong to the final path segment.
      let after_slash = match name.rev_find("/") {
        Some(slash) => dot > slash
        None => true
      }
      if after_slash && dot + 1 < name.length() {
        Some(name[dot + 1:].to_owned().to_lower())
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn ContentTypes::for_part(self : ContentTypes, name : String) -> String? {
  match self.overrides.get(part_name_key("/" + name)) {
    Some(value) => Some(value)
    None =>
      match part_extension(name) {
        Some(extension) => self.defaults.get(extension)
        None => None
      }
  }
}

///|
priv enum DocumentDialect {
  Transitional
  Strict
}

///|
fn office_document_dialect(rel_type : String) -> DocumentDialect? {
  match rel_type {
    TRANSITIONAL_OFFICE_DOCUMENT_RELATIONSHIP => Some(Transitional)
    STRICT_OFFICE_DOCUMENT_RELATIONSHIP => Some(Strict)
    _ => None
  }
}

///|
fn check_relationships(
  parts : StableStringMap[BytesView],
  canonical_names : StableStringMap[String],
  logical_names : StableStringMap[String],
  content_types : ContentTypes?,
  findings : FindingCollector,
) -> Unit {
  if findings.full() {
    findings.stop()
    return
  }
  // Root rels: required, every internal target must resolve, and exactly one
  // internal officeDocument relationship must select the main part.
  match find_part(parts, canonical_names, ROOT_RELS_PART) {
    Some((root_rels_name, bytes)) => {
      check_relationship_content_type(
        root_rels_name,
        ROOT_RELS_PART,
        content_types,
        findings,
      )
      match parse_xml_part(root_rels_name, bytes, findings) {
        Some(root) => {
          let main_parts : Array[(String, DocumentDialect)] = []
          for_each_relationship(ROOT_RELS_PART, root, findings, (
            _id,
            rel_type,
            target,
            external,
          ) => {
            let dialect = office_document_dialect(rel_type)
            if external {
              match dialect {
                Some(_) =>
                  findings.add(
                    "\{ROOT_RELS_PART}: officeDocument relationship is not internal",
                  )
                None => ()
              }
              return
            }
            match resolve_part_target("", target) {
              Some(resolved) => {
                if !contains_part(canonical_names, resolved) {
                  findings.add(
                    "relationship target missing: \{ROOT_RELS_PART} -> \{findings.text(target)} (resolved \{findings.text(resolved)})",
                  )
                }
                match dialect {
                  Some(value) => main_parts.push((resolved, value))
                  None => ()
                }
              }
              None => {
                findings.add(
                  "relationship target invalid: \{ROOT_RELS_PART} -> \{findings.text(target)}",
                )
                match dialect {
                  Some(_) =>
                    findings.add(
                      "\{ROOT_RELS_PART}: officeDocument relationship has an invalid target: \{findings.text(target)}",
                    )
                  None => ()
                }
              }
            }
          })
          match main_parts {
            [(part, dialect)] =>
              match find_part(parts, canonical_names, part) {
                Some((actual, bytes)) =>
                  if check_main_part(
                      actual, part, bytes, dialect, content_types, findings,
                    ) {
                    findings.main_document_part = Some(actual)
                  }
                None =>
                  findings.add(
                    "officeDocument relationship targets a missing part: \{findings.text(part)}",
                  )
              }
            [] =>
              findings.add("\{ROOT_RELS_PART}: no officeDocument relationship")
            _ =>
              findings.add(
                "\{ROOT_RELS_PART}: multiple officeDocument relationships",
              )
          }
        }
        None => ()
      }
    }
    None => findings.add("missing required part: \{ROOT_RELS_PART}")
  }
  // Every part's own rels, when present: parse + internal targets resolve.
  for name, bytes in parts {
    if findings.full() {
      findings.stop()
      return
    }
    guard logical_names.get(name) is Some(logical_name) else { continue }
    let canonical_name = part_name_key(logical_name)
    if canonical_name == ROOT_RELS_PART || !is_rels_part(canonical_name) {
      continue
    }
    check_relationship_content_type(name, logical_name, content_types, findings)
    match parse_xml_part(name, bytes, findings) {
      Some(root) => {
        let base = rels_base_dir(logical_name)
        for_each_relationship(name, root, findings, (
          _id,
          _rel_type,
          target,
          external,
        ) => {
          if !external {
            match resolve_part_target(base, target) {
              Some(resolved) =>
                if !contains_part(canonical_names, resolved) {
                  findings.add(
                    "relationship target missing: \{findings.text(name)} -> \{findings.text(target)} (resolved \{findings.text(resolved)})",
                  )
                }
              None =>
                findings.add(
                  "relationship target invalid: \{findings.text(name)} -> \{findings.text(target)}",
                )
            }
          }
        })
      }
      None => ()
    }
  }
}

///|
fn check_relationship_content_type(
  physical_name : String,
  logical_name : String,
  content_types : ContentTypes?,
  findings : FindingCollector,
) -> Unit {
  match content_types {
    Some(types) =>
      match types.for_part(logical_name) {
        Some(value) if value.trim().to_lower() == RELATIONSHIPS_CONTENT_TYPE =>
          ()
        Some(value) =>
          findings.add(
            "relationship part \{findings.text(physical_name)} has content type '\{findings.text(value)}', expected '\{RELATIONSHIPS_CONTENT_TYPE}'",
          )
        None =>
          findings.add(
            "relationship part \{findings.text(physical_name)} has no content type",
          )
      }
    None => ()
  }
}

///|
fn check_main_part(
  physical_name : String,
  logical_name : String,
  bytes : BytesView,
  dialect : DocumentDialect,
  content_types : ContentTypes?,
  findings : FindingCollector,
) -> Bool {
  let mut valid = true
  match content_types {
    Some(types) =>
      match types.for_part(logical_name) {
        Some(value) if value.trim().to_lower() == DOCX_MAIN_CONTENT_TYPE => ()
        Some(value) => {
          findings.add(
            "main part \{findings.text(physical_name)} has content type '\{findings.text(value)}', expected '\{DOCX_MAIN_CONTENT_TYPE}'",
          )
          valid = false
        }
        None => {
          findings.add(
            "main part \{findings.text(physical_name)} has no content type",
          )
          valid = false
        }
      }
    None => valid = false
  }
  match parse_xml_part(physical_name, bytes, findings) {
    Some(root) => {
      let expected = match dialect {
        Transitional => TRANSITIONAL_DOCUMENT_ROOT
        Strict => STRICT_DOCUMENT_ROOT
      }
      if root.name != expected {
        findings.add(
          "main part \{findings.text(physical_name)} root element does not match the officeDocument relationship dialect",
        )
        valid = false
      }
    }
    None => valid = false
  }
  valid
}

///|
fn for_each_relationship(
  part_name : String,
  root : @xml.XmlElement,
  findings : FindingCollector,
  visit : (String, String, String, Bool) -> Unit,
) -> Unit {
  let relationships_name = "{\{PACKAGE_RELATIONSHIPS_NAMESPACE}}Relationships"
  let relationship_name = "{\{PACKAGE_RELATIONSHIPS_NAMESPACE}}Relationship"
  if root.name != relationships_name {
    findings.add(
      "\{findings.text(part_name)}: root element is not in the OPC package relationships namespace",
    )
    return
  }
  let ids : StableStringSet = SortedSet([])
  for node in root.children {
    if findings.full() {
      findings.stop()
      break
    }
    guard node is XmlElement(element) else { continue }
    if element.name != relationship_name {
      if local_name(element.name) == "Relationship" {
        findings.add(
          "\{findings.text(part_name)}: Relationship element is outside the OPC package relationships namespace",
        )
      }
      continue
    }
    let id = element.attributes.get("Id").unwrap_or("")
    if id == "" {
      findings.add(
        "\{findings.text(part_name)}: Relationship missing a non-empty Id",
      )
    } else if ids.contains(id) {
      findings.add(
        "\{findings.text(part_name)}: duplicate Relationship Id: \{findings.text(id)}",
      )
    } else {
      ids.add(id)
    }
    let rel_type = element.attributes.get("Type").unwrap_or("")
    let target = element.attributes.get("Target").unwrap_or("")
    match element.attributes.get("TargetMode") {
      None | Some("Internal") => visit(id, rel_type, target, false)
      Some("External") => visit(id, rel_type, target, true)
      Some(mode) =>
        findings.add(
          "\{findings.text(part_name)}: Relationship has invalid TargetMode: \{findings.text(mode)}",
        )
    }
  }
}

///|
/// `dir/_rels/name.rels` describes `dir/name`; its targets resolve against
/// `dir`.
fn is_rels_part(name : String) -> Bool {
  let canonical = part_name_key(name)
  canonical.has_suffix(".rels") &&
  (canonical.has_prefix("_rels/") || canonical.find("/_rels/") is Some(_))
}

///|
fn rels_base_dir(rels_name : String) -> String {
  // OPC part-name equivalence folds ASCII case. Search the canonical key but
  // slice the original logical name: ASCII folding preserves indices, while
  // retaining the producer's spelling gives downstream diagnostics and edits
  // the most precise identity available.
  match part_name_key(rels_name).find("/_rels/") {
    Some(index) => rels_name[:index].to_owned()
    None => ""
  }
}

///|
/// Returns whether an internal relationship target starts with a URI scheme.
fn target_has_uri_scheme(target : String) -> Bool {
  let mut index = 0
  for character in target {
    if character == ':' {
      return index > 0
    }
    if character == '/' || character == '?' || character == '#' {
      return false
    }
    let valid = if index == 0 {
      character.is_ascii_alphabetic()
    } else {
      character.is_ascii_alphabetic() ||
      character.is_ascii_digit() ||
      character == '+' ||
      character == '-' ||
      character == '.'
    }
    if !valid {
      return false
    }
    index += 1
  }
  false
}

///|
/// RFC 3986 `path-noscheme` forbids a colon in the first relative segment.
/// Prefixing that segment with `./` is the unambiguous spelling and remains
/// valid (`./1:document.xml`).
fn target_has_ambiguous_first_segment_colon(target : String) -> Bool {
  if target.has_prefix("/") {
    return false
  }
  for character in target {
    if character == '/' {
      return false
    }
    if character == ':' {
      return true
    }
  }
  false
}

///|
/// Resolves one internal relationship target against an archive-directory
/// base. Package-rooted targets (`/word/media/x.png`) and relative targets use
/// the same dot-segment normalization. Empty segments, URI schemes,
/// query/fragment text, backslashes, empty results, and any traversal above
/// the package root fail closed instead of being silently clamped.
pub fn resolve_target(base : String, target : String) -> String? {
  if target == "" ||
    target.has_prefix("//") ||
    target.contains("\\") ||
    target.contains("?") ||
    target.contains("#") ||
    target_has_ambiguous_first_segment_colon(target) ||
    target_has_uri_scheme(target) {
    return None
  }
  let segments : Array[String] = []
  if !target.has_prefix("/") && base != "" {
    if base.has_prefix("/") {
      return None
    }
    let normalized_base = if base.has_suffix("/") {
      base[:base.length() - 1]
    } else {
      base
    }
    if normalized_base != "" {
      for segment in normalized_base.split("/") {
        if segment == "" || segment == "." || segment == ".." {
          return None
        }
        segments.push(segment.to_owned())
      }
    }
  }
  let path = if target.has_prefix("/") { target[1:] } else { target }
  for segment in path.split("/") {
    match segment.to_owned() {
      "" => return None
      "." => ()
      ".." =>
        if segments.length() > 0 {
          let _ = segments.pop()
        } else {
          return None
        }
      other => segments.push(other)
    }
  }
  if segments.length() == 0 {
    None
  } else {
    Some(segments.join("/"))
  }
}

///|
/// The parser emits `prefix:Local` for mapped namespaces and Clark notation
/// `{uri}Local` for unmapped ones. Generic structural checks use local names;
/// security-sensitive relationship parsing above requires the exact expanded
/// package-relationships name.
fn local_name(name : String) -> String {
  let after_ns = match name.rev_find("}") {
    Some(index) => name[index + 1:].to_owned()
    None => name
  }
  match after_ns.rev_find(":") {
    Some(index) => after_ns[index + 1:].to_owned()
    None => after_ns
  }
}

///|
fn parse_xml_part(
  name : String,
  bytes : BytesView,
  findings : FindingCollector,
) -> @xml.XmlElement? {
  let root = @xml.read_xml_bytes_strict_limited(bytes, findings.xml_budget) catch {
    InvalidXml(message="XML source is not valid UTF-8") => {
      findings.add("part is not valid UTF-8: \{findings.text(name)}")
      return None
    }
    err => {
      findings.mark_resource_limit(err)
      findings.add(
        "malformed XML in \{findings.text(name)}: \{findings.text(repr(err))}",
      )
      return None
    }
  }
  Some(root)
}
