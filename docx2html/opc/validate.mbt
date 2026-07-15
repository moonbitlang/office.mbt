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
const DEFAULT_MAX_ZIP_ENTRY_NAME_CHARS : Int = 65_535

///|
const DEFAULT_MAX_ZIP_TOTAL_ENTRY_NAME_CHARS : Int = 4 * 1024 * 1024

///|
/// ECMA-376 Part 2 §7.3.6 caps the Central Directory File Header—not merely
/// its File Name field. The four-byte ZIP signature is outside that size; the
/// remaining fixed fields consume 42 bytes before File Name, Extra, and File
/// Comment data.
const MAX_OPC_CENTRAL_DIRECTORY_FILE_HEADER_BYTES : Int = 65_535

///|
const MAX_OPC_ZIP_ENTRY_NAME_BYTES_WITHOUT_METADATA : Int = 65_493

///|
/// The resource guard that stopped structural validation. This status is kept
/// separate from rendered findings so attacker-controlled part names cannot
/// forge or hide resource exhaustion by changing diagnostic text.
pub(all) enum DocxValidationResourceLimit {
  ZipEntries
  ZipEntryUncompressedBytes
  ZipTotalUncompressedBytes
  ZipEntryNameCharacters
  ZipTotalEntryNameCharacters
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
    ZipEntryNameCharacters => "zip-entry-name-characters"
    ZipTotalEntryNameCharacters => "zip-total-entry-name-characters"
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
  max_zip_entry_name_chars : Int
  max_zip_total_entry_name_chars : Int
  mut zip_entry_name_chars : Int
  xml_budget : @xml.XmlReadBudget
  mut truncated : Bool
  mut resource_limit : DocxValidationResourceLimit?
  mut main_document_part : String?
}

///|
fn FindingCollector::new_with_xml_limits(
  max_findings : Int,
  max_message_chars : Int,
  max_zip_entry_name_chars : Int,
  max_zip_total_entry_name_chars : Int,
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
    max_zip_entry_name_chars: if max_zip_entry_name_chars > 0 {
      max_zip_entry_name_chars
    } else {
      0
    },
    max_zip_total_entry_name_chars: if max_zip_total_entry_name_chars > 0 {
      max_zip_total_entry_name_chars
    } else {
      0
    },
    zip_entry_name_chars: 0,
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
fn FindingCollector::consume_zip_entry_name(
  self : FindingCollector,
  name : String,
) -> Bool {
  let length = name.length()
  if length > self.max_zip_entry_name_chars {
    if self.resource_limit is None {
      self.resource_limit = Some(ZipEntryNameCharacters)
    }
    self.add("ZIP entry name exceeds the character budget: \{self.text(name)}")
    self.stop()
    return false
  }
  if length > self.max_zip_total_entry_name_chars - self.zip_entry_name_chars {
    if self.resource_limit is None {
      self.resource_limit = Some(ZipTotalEntryNameCharacters)
    }
    self.add("ZIP entry names exceed the aggregate character budget")
    self.stop()
    return false
  }
  self.zip_entry_name_chars = self.zip_entry_name_chars + length
  true
}

///|
fn xml_validation_resource_limit(
  error : @core.DocxError,
) -> DocxValidationResourceLimit? {
  match error {
    ResourceLimit(limit~, ..) =>
      match limit {
        DocxXmlSourceUnits => Some(XmlSourceUnits)
        DocxXmlTokens => Some(XmlTokens)
        DocxXmlTokenLength => Some(XmlTokenLength)
        DocxXmlMaterializedCharacters => Some(XmlMaterializedCharacters)
        DocxXmlNestingDepth => Some(XmlNestingDepth)
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
  max_zip_entry_name_chars? : Int = DEFAULT_MAX_ZIP_ENTRY_NAME_CHARS,
  max_zip_total_entry_name_chars? : Int = DEFAULT_MAX_ZIP_TOTAL_ENTRY_NAME_CHARS,
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
    max_zip_entry_name_chars~,
    max_zip_total_entry_name_chars~,
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
  max_zip_entry_name_chars? : Int = DEFAULT_MAX_ZIP_ENTRY_NAME_CHARS,
  max_zip_total_entry_name_chars? : Int = DEFAULT_MAX_ZIP_TOTAL_ENTRY_NAME_CHARS,
  max_xml_source_units? : Int = DEFAULT_MAX_XML_SOURCE_UNITS,
  max_xml_tokens? : Int = DEFAULT_MAX_XML_TOKENS,
  max_xml_materialized_chars? : Int = DEFAULT_MAX_XML_MATERIALIZED_CHARS,
  max_xml_token_chars? : Int = DEFAULT_MAX_XML_TOKEN_CHARS,
) -> DocxValidationReport {
  let findings = FindingCollector::new_with_xml_limits(
    max_findings, max_message_chars, max_zip_entry_name_chars, max_zip_total_entry_name_chars,
    max_xml_source_units, max_xml_tokens, max_xml_materialized_chars, max_xml_token_chars,
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
  max_zip_entry_name_chars? : Int = DEFAULT_MAX_ZIP_ENTRY_NAME_CHARS,
  max_zip_total_entry_name_chars? : Int = DEFAULT_MAX_ZIP_TOTAL_ENTRY_NAME_CHARS,
  max_xml_source_units? : Int = DEFAULT_MAX_XML_SOURCE_UNITS,
  max_xml_tokens? : Int = DEFAULT_MAX_XML_TOKENS,
  max_xml_materialized_chars? : Int = DEFAULT_MAX_XML_MATERIALIZED_CHARS,
  max_xml_token_chars? : Int = DEFAULT_MAX_XML_TOKEN_CHARS,
) -> (Array[String], Bool) {
  let report = validate_docx_archive_report_limited(
    archive,
    max_findings~,
    max_message_chars~,
    max_zip_entry_name_chars~,
    max_zip_total_entry_name_chars~,
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
  max_zip_entry_name_chars? : Int = DEFAULT_MAX_ZIP_ENTRY_NAME_CHARS,
  max_zip_total_entry_name_chars? : Int = DEFAULT_MAX_ZIP_TOTAL_ENTRY_NAME_CHARS,
  max_xml_source_units? : Int = DEFAULT_MAX_XML_SOURCE_UNITS,
  max_xml_tokens? : Int = DEFAULT_MAX_XML_TOKENS,
  max_xml_materialized_chars? : Int = DEFAULT_MAX_XML_MATERIALIZED_CHARS,
  max_xml_token_chars? : Int = DEFAULT_MAX_XML_TOKEN_CHARS,
) -> DocxValidationReport {
  let findings = FindingCollector::new_with_xml_limits(
    max_findings, max_message_chars, max_zip_entry_name_chars, max_zip_total_entry_name_chars,
    max_xml_source_units, max_xml_tokens, max_xml_materialized_chars, max_xml_token_chars,
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
  let part_names = PartNameRegistry::new()
  let seen : StableStringSet = SortedSet([])
  for entry in archive.entries() {
    if findings.full() {
      findings.stop()
      return
    }
    let name = entry.name()
    if !findings.consume_zip_entry_name(name) {
      return
    }
    if entry.central_directory_file_header_size() >
      MAX_OPC_CENTRAL_DIRECTORY_FILE_HEADER_BYTES {
      findings.add(
        "central-directory file header exceeds the OPC \{MAX_OPC_CENTRAL_DIRECTORY_FILE_HEADER_BYTES}-byte limit: \{findings.text(name)}",
      )
    }
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
          if logical != CONTENT_TYPES_PART {
            match part_names.register(logical, name) {
              Some(Equivalent(existing)) if existing != name =>
                findings.add(
                  "duplicate entry name: \{findings.text(name)} (logically equivalent to \{findings.text(existing)})",
                )
              Some(Derivable(existing)) =>
                findings.add(
                  "part name is derivable from another part name: \{findings.text(existing)} and \{findings.text(name)}",
                )
              _ => ()
            }
          }
          match canonical_names.get(key) {
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
  if name == CONTENT_TYPES_PART {
    return Some(CONTENT_TYPES_PART)
  }
  if part_name_key(name) == part_name_key(CONTENT_TYPES_PART) {
    findings.add(
      "reserved content-types entry must use exact spelling '[Content_Types].xml': \{findings.text(name)}",
    )
    return None
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
fn is_media_type_token_char(character : Char) -> Bool {
  character.is_ascii_alphabetic() ||
  character.is_ascii_digit() ||
  character == '!' ||
  character == '#' ||
  character == '$' ||
  character == '%' ||
  character == '&' ||
  character.to_int() == 0x27 ||
  character == '*' ||
  character == '+' ||
  character == '-' ||
  character == '.' ||
  character == '^' ||
  character == '_' ||
  character == '`' ||
  character == '|' ||
  character == '~'
}

///|
fn is_media_type_quoted_char(character : Char) -> Bool {
  let code = character.to_int()
  character == '\t' ||
  character == ' ' ||
  code == 0x21 ||
  (code >= 0x23 && code <= 0x5b) ||
  (code >= 0x5d && code <= 0x7e) ||
  (code >= 0x80 && code <= 0xff)
}

///|
fn is_media_type_quoted_pair_char(character : Char) -> Bool {
  let code = character.to_int()
  character == '\t' ||
  character == ' ' ||
  (code >= 0x21 && code <= 0x7e) ||
  (code >= 0x80 && code <= 0xff)
}

///|
/// RFC 7230 token and quoted-string rules, composed as the RFC 7231 media-type
/// grammar required by OPC. Optional whitespace surrounds semicolons only;
/// parameter names, `=`, and values remain contiguous.
fn is_valid_media_type(value : String) -> Bool {
  let characters = value.to_array()
  let mut index = 0
  while index < characters.length() &&
        is_media_type_token_char(characters[index]) {
    index += 1
  }
  if index == 0 || index >= characters.length() || characters[index] != '/' {
    return false
  }
  index += 1
  let subtype_start = index
  while index < characters.length() &&
        is_media_type_token_char(characters[index]) {
    index += 1
  }
  if index == subtype_start {
    return false
  }
  while index < characters.length() {
    while index < characters.length() &&
          (characters[index] == ' ' || characters[index] == '\t') {
      index += 1
    }
    if index >= characters.length() || characters[index] != ';' {
      return false
    }
    index += 1
    while index < characters.length() &&
          (characters[index] == ' ' || characters[index] == '\t') {
      index += 1
    }
    let parameter_start = index
    while index < characters.length() &&
          is_media_type_token_char(characters[index]) {
      index += 1
    }
    if index == parameter_start ||
      index >= characters.length() ||
      characters[index] != '=' {
      return false
    }
    index += 1
    if index >= characters.length() {
      return false
    }
    if characters[index] == '"' {
      index += 1
      let mut closed = false
      while index < characters.length() {
        let character = characters[index]
        if character == '"' {
          closed = true
          index += 1
          break
        }
        if character == '\\' {
          index += 1
          if index >= characters.length() ||
            !is_media_type_quoted_pair_char(characters[index]) {
            return false
          }
        } else if !is_media_type_quoted_char(character) {
          return false
        }
        index += 1
      }
      if !closed {
        return false
      }
    } else {
      let value_start = index
      while index < characters.length() &&
            is_media_type_token_char(characters[index]) {
        index += 1
      }
      if index == value_start {
        return false
      }
    }
  }
  true
}

///|
/// ECMA-376 Part 2 `ST_Extension`. A percent sign is legal only as a complete
/// percent-encoded byte; dots and non-ASCII characters are not extension data.
fn is_valid_content_type_extension(value : String) -> Bool {
  if value == "" {
    return false
  }
  let characters = value.to_array()
  let mut index = 0
  while index < characters.length() {
    let character = characters[index]
    if character.is_ascii_alphabetic() ||
      character.is_ascii_digit() ||
      character
      is ('!'
      | '$'
      | '&'
      | '('
      | ')'
      | '*'
      | '+'
      | ','
      | ':'
      | '='
      | '@'
      | '-'
      | '_'
      | '~') ||
      character.to_int() == 0x27 {
      index += 1
    } else if character == '%' &&
      index + 2 < characters.length() &&
      opc_ascii_hex_digit(characters[index + 1]) &&
      opc_ascii_hex_digit(characters[index + 2]) {
      index += 3
    } else {
      return false
    }
  }
  true
}

///|
fn unexpected_xml_attribute(
  element : @xml.XmlElement,
  allowed : ArrayView[String],
) -> String? {
  for name, _ in element.attributes {
    if !allowed.any(expected => expected == name) {
      return Some(name)
    }
  }
  None
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
  let mut valid = true
  match unexpected_xml_attribute(root, []) {
    Some(attribute) => {
      findings.add(
        "\{CONTENT_TYPES_PART}: Types has undeclared attribute: \{findings.text(attribute)}",
      )
      valid = false
    }
    None => ()
  }
  let defaults : StableStringMap[String] = SortedMap([])
  let overrides : StableStringMap[String] = SortedMap([])
  let seen_defaults : StableStringSet = SortedSet([])
  let seen_overrides : StableStringSet = SortedSet([])
  for node in root.children {
    if findings.full() {
      findings.stop()
      valid = false
      break
    }
    match node {
      XmlText(text) =>
        if text.trim() != "" {
          findings.add("\{CONTENT_TYPES_PART}: Types contains unexpected text")
          valid = false
        }
      XmlElement(element) =>
        match element.name {
          CONTENT_TYPES_DEFAULT => {
            let mut element_valid = true
            match
              unexpected_xml_attribute(element, ["Extension", "ContentType"]) {
              Some(attribute) => {
                findings.add(
                  "\{CONTENT_TYPES_PART}: Default has undeclared attribute: \{findings.text(attribute)}",
                )
                element_valid = false
                valid = false
              }
              None => ()
            }
            if !element.children.is_empty() {
              findings.add(
                "\{CONTENT_TYPES_PART}: Default element is not empty",
              )
              element_valid = false
              valid = false
            }
            match
              (
                element.attributes.get("Extension"),
                element.attributes.get("ContentType"),
              ) {
              (Some(extension), Some(content_type)) => {
                let extension_valid = is_valid_content_type_extension(extension)
                if !extension_valid {
                  findings.add(
                    "\{CONTENT_TYPES_PART}: Default has invalid Extension: \{findings.text(extension)}",
                  )
                  valid = false
                }
                let content_type_valid = is_valid_media_type(content_type)
                if !content_type_valid {
                  findings.add(
                    "\{CONTENT_TYPES_PART}: Default has invalid ContentType: \{findings.text(content_type)}",
                  )
                  valid = false
                }
                if extension_valid {
                  let key = extension.to_lower()
                  let duplicate = seen_defaults.contains(key)
                  if duplicate {
                    findings.add(
                      "\{CONTENT_TYPES_PART}: duplicate Default Extension after case normalization: \{findings.text(key)}",
                    )
                    valid = false
                  } else {
                    seen_defaults.add(key)
                    if element_valid && content_type_valid {
                      defaults[key] = content_type
                    }
                  }
                }
              }
              _ => {
                findings.add(
                  "\{CONTENT_TYPES_PART}: Default missing Extension or ContentType",
                )
                valid = false
              }
            }
          }
          CONTENT_TYPES_OVERRIDE => {
            let mut element_valid = true
            match
              unexpected_xml_attribute(element, ["PartName", "ContentType"]) {
              Some(attribute) => {
                findings.add(
                  "\{CONTENT_TYPES_PART}: Override has undeclared attribute: \{findings.text(attribute)}",
                )
                element_valid = false
                valid = false
              }
              None => ()
            }
            if !element.children.is_empty() {
              findings.add(
                "\{CONTENT_TYPES_PART}: Override element is not empty",
              )
              element_valid = false
              valid = false
            }
            match
              (
                element.attributes.get("PartName"),
                element.attributes.get("ContentType"),
              ) {
              (Some(part_name), Some(content_type)) => {
                let content_type_valid = is_valid_media_type(content_type)
                if !content_type_valid {
                  findings.add(
                    "\{CONTENT_TYPES_PART}: Override has invalid ContentType: \{findings.text(content_type)}",
                  )
                  valid = false
                }
                if part_name.has_prefix("/") {
                  match normalize_override_part_name(part_name) {
                    Some(key) => {
                      let collision_key = part_name_key(key)
                      let duplicate = seen_overrides.contains(collision_key)
                      if duplicate {
                        findings.add(
                          "\{CONTENT_TYPES_PART}: duplicate Override PartName after path normalization: \{findings.text(key)}",
                        )
                        valid = false
                      } else {
                        seen_overrides.add(collision_key)
                      }
                      if key != part_name {
                        findings.add(
                          "\{CONTENT_TYPES_PART}: Override PartName is not canonical: \{findings.text(part_name)}",
                        )
                        element_valid = false
                        valid = false
                      }
                      let target = key[1:].to_owned()
                      if part_name_key(target) ==
                        part_name_key(CONTENT_TYPES_PART) {
                        findings.add(
                          "\{CONTENT_TYPES_PART}: Override names the reserved content-types stream",
                        )
                        element_valid = false
                        valid = false
                      } else if !contains_part(canonical_names, target) {
                        findings.add(
                          "\{CONTENT_TYPES_PART}: Override names a missing part: \{findings.text(key)}",
                        )
                        element_valid = false
                        valid = false
                      }
                      if element_valid && content_type_valid && !duplicate {
                        overrides[collision_key] = content_type
                      }
                    }
                    None => {
                      findings.add(
                        "\{CONTENT_TYPES_PART}: Override PartName is invalid: \{findings.text(part_name)}",
                      )
                      valid = false
                    }
                  }
                } else {
                  findings.add(
                    "\{CONTENT_TYPES_PART}: Override PartName must start with '/': \{findings.text(part_name)}",
                  )
                  valid = false
                }
              }
              _ => {
                findings.add(
                  "\{CONTENT_TYPES_PART}: Override missing PartName or ContentType",
                )
                valid = false
              }
            }
          }
          _ => {
            let child_name = local_name(element.name)
            if child_name == "Default" || child_name == "Override" {
              findings.add(
                "\{CONTENT_TYPES_PART}: \{findings.text(child_name)} element is outside the OPC content-types namespace",
              )
            } else {
              findings.add(
                "\{CONTENT_TYPES_PART}: Types contains unexpected element: \{findings.text(element.name)}",
              )
            }
            valid = false
          }
        }
    }
  }
  if valid {
    Some({ defaults, overrides })
  } else {
    None
  }
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
fn xml_ncname_start(character : Char) -> Bool {
  let value = character.to_int()
  character.is_ascii_alphabetic() ||
  character == '_' ||
  (value >= 0x00c0 && value <= 0x00d6) ||
  (value >= 0x00d8 && value <= 0x00f6) ||
  (value >= 0x00f8 && value <= 0x02ff) ||
  (value >= 0x0370 && value <= 0x037d) ||
  (value >= 0x037f && value <= 0x1fff) ||
  (value >= 0x200c && value <= 0x200d) ||
  (value >= 0x2070 && value <= 0x218f) ||
  (value >= 0x2c00 && value <= 0x2fef) ||
  (value >= 0x3001 && value <= 0xd7ff) ||
  (value >= 0xf900 && value <= 0xfdcf) ||
  (value >= 0xfdf0 && value <= 0xfffd) ||
  (value >= 0x10000 && value <= 0xeffff)
}

///|
fn xml_ncname_character(character : Char) -> Bool {
  let value = character.to_int()
  xml_ncname_start(character) ||
  character.is_ascii_digit() ||
  character == '-' ||
  character == '.' ||
  value == 0x00b7 ||
  (value >= 0x0300 && value <= 0x036f) ||
  (value >= 0x203f && value <= 0x2040)
}

///|
fn is_valid_relationship_id(id : String) -> Bool {
  let characters = id.to_array()
  if characters.length() == 0 || !xml_ncname_start(characters[0]) {
    return false
  }
  for index in 1..<characters.length() {
    if !xml_ncname_character(characters[index]) {
      return false
    }
  }
  true
}

///|
/// Returns whether a name has the reserved Relationships-part shape. The
/// package-root `_rels/.rels` is valid, while a nested `dir/_rels/.rels`
/// remains reserved but cannot identify a source part.
fn is_rels_part(name : String) -> Bool {
  let segments = name.split("/").collect()
  segments.length() >= 2 &&
  part_name_key(segments[segments.length() - 2]) == "_rels" &&
  part_name_key(segments[segments.length() - 1]).has_suffix(".rels")
}

///|
/// Derives the source described by a valid Relationships part. Earlier
/// `_rels` segments belong to the source PartName: for example,
/// `word/_rels/_rels/data.bin.rels` describes `word/_rels/data.bin`.
fn relationship_source_part(name : String) -> String? {
  let key = part_name_key(name)
  if key == ROOT_RELS_PART {
    return Some("")
  }
  if !is_rels_part(name) {
    return None
  }
  let segments = name.split("/").collect()
  let filename = segments[segments.length() - 1]
  if filename.length() <= 5 {
    return None
  }
  let source_name = filename[:filename.length() - 5].to_owned()
  let output = StringBuilder::new(size_hint=name.length())
  for index in 0..<(segments.length() - 2) {
    if index > 0 {
      output.write_char('/') |> ignore
    }
    output.write_string(segments[index].to_owned()) |> ignore
  }
  if segments.length() > 2 {
    output.write_char('/') |> ignore
  }
  output.write_string(source_name) |> ignore
  Some(output.to_string())
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
      match parse_relationships_part(root_rels_name, bytes, findings) {
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
              Some(resolved) =>
                if is_rels_part(resolved) {
                  findings.add(
                    "relationship target must not be a Relationships part: \{ROOT_RELS_PART} -> \{findings.text(target)}",
                  )
                } else {
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
    if canonical_name == ROOT_RELS_PART {
      continue
    }
    if !is_rels_part(logical_name) {
      continue
    }
    guard relationship_source_part(logical_name) is Some(source) else {
      findings.add("invalid Relationships part name: \{findings.text(name)}")
      continue
    }
    if !contains_part(canonical_names, source) {
      findings.add(
        "relationship part \{findings.text(name)} describes missing source part: \{findings.text(source)}",
      )
    }
    check_relationship_content_type(name, logical_name, content_types, findings)
    match parse_relationships_part(name, bytes, findings) {
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
                if is_rels_part(resolved) {
                  findings.add(
                    "relationship target must not be a Relationships part: \{findings.text(name)} -> \{findings.text(target)}",
                  )
                } else if !contains_part(canonical_names, resolved) {
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
  let mut valid_part = true
  for attribute, _ in root.attributes {
    findings.add(
      "\{findings.text(part_name)}: Relationships has undeclared attribute: \{findings.text(attribute)}",
    )
    valid_part = false
  }
  let ids : StableStringSet = SortedSet([])
  let relationships : Array[(String, String, String, Bool)] = []
  for node in root.children {
    if findings.full() {
      findings.stop()
      valid_part = false
      break
    }
    guard node is XmlElement(element) else {
      guard node is XmlText(text) else { continue }
      if text.trim() != "" {
        findings.add(
          "\{findings.text(part_name)}: Relationships contains unexpected text",
        )
        valid_part = false
      }
      continue
    }
    if element.name != relationship_name {
      if local_name(element.name) == "Relationship" {
        findings.add(
          "\{findings.text(part_name)}: Relationship element is outside the OPC package relationships namespace",
        )
      } else {
        findings.add(
          "\{findings.text(part_name)}: Relationships contains unexpected element: \{findings.text(element.name)}",
        )
      }
      valid_part = false
      continue
    }
    let mut valid = true
    for attribute, _ in element.attributes {
      if attribute != "Id" &&
        attribute != "Type" &&
        attribute != "Target" &&
        attribute != "TargetMode" {
        findings.add(
          "\{findings.text(part_name)}: Relationship has undeclared attribute: \{findings.text(attribute)}",
        )
        valid = false
      }
    }
    for child in element.children {
      match child {
        XmlElement(_) => {
          findings.add(
            "\{findings.text(part_name)}: Relationship contains a child element",
          )
          valid = false
        }
        XmlText(text) =>
          if text.trim() != "" {
            findings.add(
              "\{findings.text(part_name)}: Relationship contains unexpected text",
            )
            valid = false
          }
      }
    }
    let id = @xml.collapse_xml_schema_whitespace(
      element.attributes.get("Id").unwrap_or(""),
    )
    if id == "" {
      findings.add(
        "\{findings.text(part_name)}: Relationship missing a non-empty Id",
      )
      valid = false
    } else if !is_valid_relationship_id(id) {
      findings.add(
        "\{findings.text(part_name)}: Relationship Id is not an XML NCName: \{findings.text(id)}",
      )
      valid = false
    } else if ids.contains(id) {
      findings.add(
        "\{findings.text(part_name)}: duplicate Relationship Id: \{findings.text(id)}",
      )
      valid = false
    } else {
      ids.add(id)
    }
    let rel_type = @xml.collapse_xml_schema_whitespace(
      element.attributes.get("Type").unwrap_or(""),
    )
    if rel_type == "" {
      findings.add(
        "\{findings.text(part_name)}: Relationship missing a non-empty Type",
      )
      valid = false
    } else if !is_absolute_relationship_type(rel_type) {
      findings.add(
        "\{findings.text(part_name)}: Relationship Type is not an absolute IRI without a fragment: \{findings.text(rel_type)}",
      )
      valid = false
    }
    let target = @xml.collapse_xml_schema_whitespace(
      element.attributes.get("Target").unwrap_or(""),
    )
    if target == "" {
      findings.add(
        "\{findings.text(part_name)}: Relationship missing a non-empty Target",
      )
      valid = false
    }
    let external = match element.attributes.get("TargetMode") {
      None | Some("Internal") => Some(false)
      Some("External") => Some(true)
      Some(mode) => {
        findings.add(
          "\{findings.text(part_name)}: Relationship has invalid TargetMode: \{findings.text(mode)}",
        )
        valid = false
        None
      }
    }
    match external {
      Some(true) if target != "" &&
        !is_valid_external_relationship_target(target) => {
        findings.add(
          "\{findings.text(part_name)}: external Relationship Target is not a valid IRI reference: \{findings.text(target)}",
        )
        valid = false
      }
      _ => ()
    }
    match external {
      Some(value) =>
        if valid {
          relationships.push((id, rel_type, target, value))
        } else {
          valid_part = false
        }
      None => ()
    }
    if !valid {
      valid_part = false
    }
  }
  if valid_part {
    for relationship in relationships {
      let (id, rel_type, target, external) = relationship
      visit(id, rel_type, target, external)
    }
  }
}

///|
fn rels_base_dir(rels_name : String) -> String {
  match relationship_source_part(rels_name) {
    Some(source) =>
      match source.rev_find("/") {
        Some(index) => source[:index].to_owned()
        None => ""
      }
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
        "malformed XML in \{findings.text(name)}: \{findings.text(err.description())}",
      )
      return None
    }
  }
  Some(root)
}

///|
/// Relationships parts have a distinct OPC contract: before their schema is
/// evaluated, ECMA-376 Part 3 processing runs with an empty markup
/// configuration and only the package Relationships namespace understood.
fn parse_relationships_part(
  name : String,
  bytes : BytesView,
  findings : FindingCollector,
) -> @xml.XmlElement? {
  let root = read_opc_relationships_xml_limited(bytes, findings.xml_budget) catch {
    InvalidXml(message="XML source is not valid UTF-8") => {
      findings.add("part is not valid UTF-8: \{findings.text(name)}")
      return None
    }
    err => {
      findings.mark_resource_limit(err)
      findings.add(
        "malformed XML in \{findings.text(name)}: \{findings.text(err.description())}",
      )
      return None
    }
  }
  Some(root)
}

///|
/// Strictly parses one OPC Relationships part and applies Markup
/// Compatibility with only the package Relationships namespace understood.
/// Schema validation remains the caller's responsibility.
pub fn read_opc_relationships_xml_limited(
  source : BytesView,
  budget : @xml.XmlReadBudget,
) -> @xml.XmlElement raise @core.DocxError {
  @xml.read_xml_bytes_strict_mce_limited(source, budget, [
    PACKAGE_RELATIONSHIPS_NAMESPACE,
  ])
}

///|
/// Parses one OPC Relationships part and also reports the expanded QName of
/// its raw document element. The effective root may have been selected through
/// MCE; byte-preserving mutation must only splice it when both identities are
/// the package Relationships root.
pub fn read_opc_relationships_xml_with_source_root_limited(
  source : BytesView,
  budget : @xml.XmlReadBudget,
) -> (String, @xml.XmlElement) raise @core.DocxError {
  @xml.read_xml_bytes_strict_mce_with_source_root_limited(source, budget, [
    PACKAGE_RELATIONSHIPS_NAMESPACE,
  ])
}

///|
/// Strictly parses one already-decoded OPC Relationships part, verifies its
/// XML encoding declaration, and applies Markup Compatibility with only the
/// package Relationships namespace understood. Schema validation remains the
/// caller's responsibility.
pub fn read_opc_relationships_string_encoded_limited(
  source : String,
  source_encoding : @xml.XmlSourceEncoding,
  budget : @xml.XmlReadBudget,
) -> @xml.XmlElement raise @core.DocxError {
  @xml.read_xml_string_strict_mce_encoded_limited(
    source,
    source_encoding,
    budget,
    [PACKAGE_RELATIONSHIPS_NAMESPACE],
  )
}
