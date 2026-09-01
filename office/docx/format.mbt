// `office format` — the transactional span-formatting verb (F2b).
//
// The engine plans; this file makes the plan a TRANSACTION: a shared
// mutation preflight the whole DOCX surface has been missing, a
// three-check readback (the paragraph still projects what it did, the
// selected spans carry the request explicitly, and nothing else about
// their formatting moved), and atomic publication with nothing written
// on any refusal.

///|
/// What one formatting transaction did.
pub struct DocxFormatReport {
  priv mode : String
  priv requested_text : String?
  priv requested_within : String?
  priv requested_nth : Int?
  priv requested_range : (Int, Int)?
  priv resolved_within : String?
  priv selected : Array[Int]
  priv spans : Array[@word.DocxFormatSpan]
  priv affected : Array[@word.DocxFormatAffected]
  priv runs_changed : Int
  priv runs_already_satisfied : Int
  priv splits : Int
  priv byte_edits : Int
}

///|
/// `text` or `range` — which selector produced the spans.
pub fn DocxFormatReport::mode(self : DocxFormatReport) -> String {
  self.mode
}

///|
/// The needle the caller asked for, in text mode.
pub fn DocxFormatReport::requested_text(self : DocxFormatReport) -> String? {
  self.requested_text
}

///|
/// The scope the caller asked for, as SPELLED.
pub fn DocxFormatReport::requested_within(self : DocxFormatReport) -> String? {
  self.requested_within
}

///|
/// The ordinal the caller selected, if any.
pub fn DocxFormatReport::requested_nth(self : DocxFormatReport) -> Int? {
  self.requested_nth
}

///|
/// The explicit range the caller addressed, in range mode.
pub fn DocxFormatReport::requested_range(
  self : DocxFormatReport,
) -> (Int, Int)? {
  self.requested_range
}

///|
/// The scan path a stable `p[id="…"]` scope resolved to; None when the
/// scope was ordinal or absent — the receipt names both spellings so an
/// agent can re-anchor.
pub fn DocxFormatReport::resolved_within(self : DocxFormatReport) -> String? {
  self.resolved_within
}

///|
/// The candidate ordinals formatted, in document order.
pub fn DocxFormatReport::selected(self : DocxFormatReport) -> Array[Int] {
  self.selected.copy()
}

///|
/// The selected spans.
pub fn DocxFormatReport::spans(
  self : DocxFormatReport,
) -> Array[@word.DocxFormatSpan] {
  self.spans.map(@word.DocxFormatSpan::copy)
}

///|
/// The affected paragraphs, with the projections they must still read.
pub fn DocxFormatReport::affected(
  self : DocxFormatReport,
) -> Array[@word.DocxFormatAffected] {
  self.affected.copy()
}

///|
/// The paragraphs this transaction touched, by path.
pub fn DocxFormatReport::affected_paths(
  self : DocxFormatReport,
) -> Array[String] {
  self.affected.map(entry => entry.path())
}

///|
/// How many runs were rewritten.
pub fn DocxFormatReport::runs_changed(self : DocxFormatReport) -> Int {
  self.runs_changed
}

///|
/// How many touched runs already held every requested property.
pub fn DocxFormatReport::runs_already_satisfied(self : DocxFormatReport) -> Int {
  self.runs_already_satisfied
}

///|
/// How many runs were clone-split.
pub fn DocxFormatReport::splits(self : DocxFormatReport) -> Int {
  self.splits
}

///|
/// How many byte edits the plan carried. Zero means the document
/// already held the request everywhere it was asked.
pub fn DocxFormatReport::byte_edits(self : DocxFormatReport) -> Int {
  self.byte_edits
}

///|
pub struct DocxFormatResult {
  report : DocxFormatReport
  transaction : @transaction.TransactionReport
}

///|
pub fn DocxFormatResult::report(self : DocxFormatResult) -> DocxFormatReport {
  self.report
}

///|
pub fn DocxFormatResult::transaction(
  self : DocxFormatResult,
) -> @transaction.TransactionReport {
  self.transaction
}

///|
/// The conditions under which this toolkit does not edit a DOCX at all:
/// the package carries a digital signature, the document enforces
/// editing protection, or the document records revisions this toolkit
/// cannot write.
///
/// It runs BEFORE anything is planned, on the request rather than on
/// its outcome. A caller who asks to modify a signed document is told
/// no whether or not the edit would have matched anything: a refusal
/// that depended on whether a match happened to be found would make the
/// same request succeed on one document and fail on another for reasons
/// that have nothing to do with the package's protections, and would
/// make this toolkit plan edits to documents it has already decided not
/// to touch.
pub fn docx_mutation_preflight(
  archive : @zip.Archive,
  tracking_waived? : Bool = false,
) -> Unit raise @transaction.TransactionError {
  // Signatures are identified by CONTENT TYPE, not by where they are
  // stored: OPC lets a package name its signature parts freely, so a
  // path prefix would both miss a signature kept elsewhere and refuse
  // an unsigned package that merely has an origin part.
  // Part names are OPC identities, not ZIP strings: the same part may
  // be stored under a different case than the name that reaches it.
  let parts = docx_package_parts(archive)
  if docx_package_declares_signature(archive, parts) {
    raise @transaction.transaction_failure(
      "office.docx.signed_package", "this package carries a digital signature, which any edit would invalidate",
    )
  }
  let settings_name = match docx_settings_part(archive, parts) {
    Found(name) => name
    // A document with no settings part declares no protections.
    Absent => return
    Ambiguous =>
      raise @transaction.transaction_failure(
        "office.docx.settings_ambiguous", "this package names more than one settings part, so its editing protections cannot be checked",
      )
  }
  // A settings part the package promises but does not contain is a
  // broken package, which the strict validation that opens the session
  // refuses on its own terms.
  guard docx_part_bytes(archive, parts, settings_name) is Some(settings) else {
    return
  }
  // A settings part that cannot be READ cannot be cleared: a preflight
  // that cannot see its own evidence refuses rather than proceeds.
  // Both projections from ONE bounded parse: the tree markup
  // compatibility leaves for a consumer that understands no application
  // namespace — which is what this toolkit is — and the raw tree it was
  // selected from.
  let (raw, root) = @xml.read_xml_bytes_strict_mce_with_roots_limited(
    settings,
    candidate_xml_budget(),
    // This toolkit UNDERSTANDS WML — a `MustUnderstand` naming it, or a
    // choice requiring it, reads the way it does in Word. Anything else
    // named by MustUnderstand keeps the unreadable refusal.
    [DOCX_WML_NAMESPACE, DOCX_STRICT_WML_NAMESPACE],
  ) catch {
    _ =>
      raise @transaction.transaction_failure(
        "office.docx.settings_unreadable", "this document's settings part could not be read, so its editing protections cannot be checked",
      )
  }
  guard root.name == "{\{DOCX_WML_NAMESPACE}}settings" ||
    root.name == "{\{DOCX_STRICT_WML_NAMESPACE}}settings" else {
    raise @transaction.transaction_failure(
      "office.docx.settings_unreadable", "this document's settings part is not a WML settings part, so its editing protections cannot be checked",
    )
  }
  // What this toolkit's reader would act on, and what it would pass
  // over: a protection declared in a branch that is passed over is a
  // protection this preflight cannot resolve, not one it may ignore.
  let effective = docx_settings_children(root)
  // Everything ANY consumer might read at the settings level. Judged as
  // one set: branches that agree decide the question, and disagreement
  // anywhere — with the effective reading or between alternatives — is
  // a protection that depends on who opens the document.
  let suppressed = docx_settings_possible(raw)
  match
    docx_settings_flag(
      effective,
      "documentProtection",
      "enforcement",
      absent_means_on=false,
    ) {
    Enabled =>
      raise @transaction.transaction_failure(
        "office.docx.protected_document", "this document enforces editing protection; unprotect it before editing",
      )
    Ambiguous =>
      raise @transaction.transaction_failure(
        "office.docx.settings_ambiguous", "this document's editing protection is declared more than once, or with a value outside the schema, so it cannot be read as enforced or not",
      )
    Disabled | Missing =>
      if docx_settings_flag(
          suppressed,
          "documentProtection",
          "enforcement",
          absent_means_on=false,
        )
        is (Enabled | Ambiguous) {
        raise @transaction.transaction_failure(
          "office.docx.settings_ambiguous", "this document's editing protection is declared inside compatibility alternatives this toolkit does not resolve",
        )
      }
  }
  // Write protection that carries a password is enforcement too, and it
  // is a different element from `documentProtection`.
  if docx_write_protection_enforced(effective) ||
    docx_write_protection_enforced(suppressed) {
    raise @transaction.transaction_failure(
      "office.docx.protected_document", "this document is write protected; remove the write protection before editing",
    )
  }
  // The tracking condition exists because this toolkit's SEMANTIC verbs
  // cannot write revision marks, so their edits would land unrecorded in
  // a document that asked for every change to be recorded. Two callers
  // waive it, and only it:
  //
  // - resolving revisions REMOVES the markup the document carries, and
  // - `office raw` is byte surgery the caller directs, which makes no
  //   semantic claim about the document.
  //
  // Both are also the only ways this toolkit can clear the flag; without
  // the waiver a tracked document would be one nothing here can ever
  // edit again. A signature or an enforced protection refuses every
  // verb, waiver or not.
  if tracking_waived {
    return
  }
  match
    docx_settings_flag(effective, "trackRevisions", "val", absent_means_on=true) {
    Enabled =>
      raise @transaction.transaction_failure(
        "office.docx.track_revisions", "this document records revisions; editing it would write an untracked change",
      )
    Ambiguous =>
      raise @transaction.transaction_failure(
        "office.docx.settings_ambiguous", "this document's revision tracking is declared more than once, or with a value outside the schema, so it cannot be read as on or off",
      )
    Disabled | Missing =>
      if docx_settings_flag(
          suppressed,
          "trackRevisions",
          "val",
          absent_means_on=true,
        )
        is (Enabled | Ambiguous) {
        raise @transaction.transaction_failure(
          "office.docx.settings_ambiguous", "this document's revision tracking is declared inside compatibility alternatives this toolkit does not resolve",
        )
      }
  }
}

///|
/// The OPC content type that says a part IS a digital signature. The
/// origin and certificate parts of a signature are scaffolding and may
/// exist in a package nobody has signed.
const DOCX_SIGNATURE_CONTENT_TYPE : String = "application/vnd.openxmlformats-package.digital-signature-xmlsignature+xml"

///|
const DOCX_CONTENT_TYPES_ROOT : String = "{http://schemas.openxmlformats.org/package/2006/content-types}Types"

///|
const DOCX_CONTENT_TYPES_DEFAULT : String = "{http://schemas.openxmlformats.org/package/2006/content-types}Default"

///|
const DOCX_CONTENT_TYPES_OVERRIDE : String = "{http://schemas.openxmlformats.org/package/2006/content-types}Override"

///|
/// Every part of the package, by OPC identity: its logical name and the
/// ZIP entry that stores it, keyed by the case-insensitive part key.
///
/// A relationship names a PART, and two spellings that differ only in
/// case name the same one. Looking an entry up by its exact ZIP string
/// would miss a settings part the strict validation and Word both
/// resolve, and would let an enforced protection through unread.
fn docx_package_parts(archive : @zip.Archive) -> Map[String, (String, String)] {
  let parts : Map[String, (String, String)] = Map([])
  for entry in archive.entries() {
    guard @opc.logical_part_name_from_zip_item_name(entry.name())
      is Some(logical) else {
      continue
    }
    let key = @opc.part_name_key(logical)
    // Two entries that share a part key are a package the strict
    // validation refuses as a duplicate part before any edit is
    // published, so which of them this reads does not decide anything.
    if parts.get(key) is None {
      parts[key] = (logical, entry.name())
    }
  }
  parts
}

///|
/// One part's bytes, by logical name.
fn docx_part_bytes(
  archive : @zip.Archive,
  parts : Map[String, (String, String)],
  logical : String,
) -> BytesView? {
  guard parts.get(@opc.part_name_key(logical)) is Some(entry) else {
    return None
  }
  archive.get(entry.1)
}

///|
/// Whether the package carries a DISCOVERABLE digital signature.
///
/// OPC signature discovery is a walk, not a scan: the package relates to
/// a signature ORIGIN part, and the origin relates to each signature.
/// A part that merely carries the signature content type without being
/// reachable that way is not a signature any consumer would find, and
/// refusing over it would refuse a document nothing has signed. Both
/// halves are required — reachable, and carrying the type — because
/// either alone describes scaffolding.
///
/// A content-types part that cannot be read at all is left to the strict
/// package validation that runs a moment later, which refuses on any
/// finding; this preflight only decides about packages that parse.
fn docx_package_declares_signature(
  archive : @zip.Archive,
  parts : Map[String, (String, String)],
) -> Bool {
  let origins = docx_relationship_targets(archive, parts, "", [
    DOCX_SIGNATURE_ORIGIN_RELATIONSHIP,
  ])
  guard !origins.is_empty() else { return false }
  // Conditions CONJOIN across the chain: an origin reachable only when a
  // namespace is supported, whose signature relationship is reachable
  // only when it is not, is a path no consumer walks.
  let signatures : Array[String] = []
  for origin in origins {
    for
      target in docx_relationship_targets(archive, parts, origin.part, [
        DOCX_SIGNATURE_RELATIONSHIP,
      ]) {
      let mut reachable = false
      for before in origin.conditions {
        for condition in target.conditions {
          let joined = before.copy()
          for capability in condition {
            joined.push(capability)
          }
          if docx_capabilities_satisfiable(joined) {
            reachable = true
          }
        }
      }
      if reachable {
        signatures.push(target.part)
      }
    }
  }
  guard !signatures.is_empty() else { return false }
  let (defaults, overrides) = docx_content_types(archive)
  for signature in signatures {
    guard parts.get(@opc.part_name_key(signature)) is Some(entry) else {
      continue
    }
    let (logical, _) = entry
    if docx_effective_content_type(defaults, overrides, logical)
      is Some(content_type) &&
      docx_is_signature_content_type(content_type) {
      return true
    }
  }
  false
}

///|
/// The package's content-type declarations: Defaults by lowercased
/// extension, Overrides by part key. Both are recorded whole, because a
/// part's type is its Override when it has one and the Default for its
/// extension ONLY otherwise.
fn docx_content_types(
  archive : @zip.Archive,
) -> (Map[String, String], Map[String, String]) {
  let defaults : Map[String, String] = Map([])
  let overrides : Map[String, String] = Map([])
  // The content-types part's name is reserved with an exact spelling,
  // which the strict validation that opens the session enforces.
  guard archive.get("[Content_Types].xml") is Some(types) else {
    return (defaults, overrides)
  }
  let root = @xml.read_xml_bytes_strict_limited(types, candidate_xml_budget()) catch {
    _ => return (defaults, overrides)
  }
  guard root.name == DOCX_CONTENT_TYPES_ROOT else {
    return (defaults, overrides)
  }
  for node in root.children {
    guard node is XmlElement(element) else { continue }
    if element.name == DOCX_CONTENT_TYPES_DEFAULT {
      guard element.attributes.get("ContentType") is Some(content_type) &&
        element.attributes.get("Extension") is Some(extension) else {
        continue
      }
      let key = extension.to_lower()
      if defaults.get(key) is None {
        defaults[key] = content_type
      }
    } else if element.name == DOCX_CONTENT_TYPES_OVERRIDE {
      guard element.attributes.get("ContentType") is Some(content_type) &&
        element.attributes.get("PartName") is Some(part_name) else {
        continue
      }
      let key = @opc.part_name_key(part_name)
      if overrides.get(key) is None {
        overrides[key] = content_type
      }
    }
  }
  (defaults, overrides)
}

///|
/// One part's content type: its Override, or the Default for its
/// extension.
fn docx_effective_content_type(
  defaults : Map[String, String],
  overrides : Map[String, String],
  logical : String,
) -> String? {
  match overrides.get(@opc.part_name_key("/" + logical)) {
    Some(content_type) => Some(content_type)
    None =>
      match docx_part_extension(logical) {
        Some(extension) => defaults.get(extension)
        None => None
      }
  }
}

///|
/// A media type comparison that ignores what RFC 2045 says is not part
/// of the type: case, surrounding space, and any parameters.
fn docx_is_signature_content_type(declared : String) -> Bool {
  let value = match declared.find(";") {
    Some(semicolon) => declared[:semicolon].to_owned()
    None => declared
  }
  value.trim(chars=" \t\r\n").to_lower() == DOCX_SIGNATURE_CONTENT_TYPE
}

///|
/// A part name's extension, lowercased, from its final segment.
fn docx_part_extension(name : String) -> String? {
  guard name.rev_find(".") is Some(dot) else { return None }
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

///|
const DOCX_PACKAGE_RELATIONSHIPS_NAMESPACE : String = "http://schemas.openxmlformats.org/package/2006/relationships"

///|
/// The package's signature relationships: the origin the package points
/// at, and the signatures the origin points at.
const DOCX_SIGNATURE_ORIGIN_RELATIONSHIP : String = "http://schemas.openxmlformats.org/package/2006/relationships/digital-signature/origin"

///|
const DOCX_SIGNATURE_RELATIONSHIP : String = "http://schemas.openxmlformats.org/package/2006/relationships/digital-signature/signature"

///|
/// The relationship element, in the two spellings the readers emit: the
/// expanded name, and the mapped prefix a namespace map produces.
const DOCX_PACKAGE_RELATIONSHIP_ELEMENT : String = "{http://schemas.openxmlformats.org/package/2006/relationships}Relationship"

///|
const DOCX_OFFICE_DOCUMENT_RELATIONSHIP : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument"

///|
const DOCX_STRICT_OFFICE_DOCUMENT_RELATIONSHIP : String = "http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument"

///|
const DOCX_SETTINGS_RELATIONSHIP : String = "http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings"

///|
const DOCX_STRICT_SETTINGS_RELATIONSHIP : String = "http://purl.oclc.org/ooxml/officeDocument/relationships/settings"

///|
/// The settings part's name, found by FOLLOWING relationships from the
/// package root: the main document part is whatever the root
/// `officeDocument` relationship names, and the settings part is
/// whatever that part's own settings relationship names. Neither is
/// `word/…` by rule — OPC part names are the package's to choose, and a
/// `word/settings.xml` nothing refers to is not this document's
/// settings.
fn docx_settings_part(
  archive : @zip.Archive,
  parts : Map[String, (String, String)],
) -> DocxPartLookup {
  // Several main document parts — including one hidden in a
  // compatibility branch the strict validation's effective reading does
  // not take — leave no single settings answer, and are refused rather
  // than resolved. Conditions CONJOIN across the hops: a settings part
  // reachable only by a consumer no single capability assignment
  // describes is reachable by nobody.
  let (main_lookup, main_conditions) = docx_relationship_target_under(
    archive,
    parts,
    "",
    [
      DOCX_OFFICE_DOCUMENT_RELATIONSHIP,
      DOCX_STRICT_OFFICE_DOCUMENT_RELATIONSHIP,
    ],
    [[]],
  )
  let document = match main_lookup {
    Found(name) => name
    Absent => return Absent
    Ambiguous => return Ambiguous
  }
  let (settings_lookup, _) = docx_relationship_target_under(
    archive,
    parts,
    document,
    [DOCX_SETTINGS_RELATIONSHIP, DOCX_STRICT_SETTINGS_RELATIONSHIP],
    main_conditions,
  )
  settings_lookup
}

///|
/// What following a relationship found.
priv enum DocxPartLookup {
  Absent
  Found(String)
  Ambiguous
}

///|
/// One part a relationship walk could reach, with the consumer
/// capabilities each PATH to it demands. Two paths to one part keep
/// their conditions side by side: reachable under either.
priv struct DocxPossiblePart {
  part : String
  conditions : Array[Array[DocxCapability]]
}

///|
/// Every INTERNAL part named by `source`'s relationships of one of
/// `types`, resolved against `source`'s own location, deduplicated by
/// part identity, each with the capability conditions of its paths.
fn docx_relationship_targets(
  archive : @zip.Archive,
  parts : Map[String, (String, String)],
  source : String,
  types : Array[String],
) -> Array[DocxPossiblePart] {
  let rels_name = @opc.relationships_part_name_for_source(source)
  guard docx_part_bytes(archive, parts, rels_name) is Some(bytes) else {
    return []
  }
  // The RAW tree, walked through every branch: a relationship inside an
  // `mc:Choice` is one some consumer resolves, and a preflight that read
  // only its own projection would miss a settings part — or a signature
  // chain — that Word follows.
  let (root, _effective) = @opc.read_opc_relationships_xml_with_roots_limited(
    bytes,
    candidate_xml_budget(),
  ) catch {
    _ => return []
  }
  let base = match source.rev_find("/") {
    Some(slash) => source[:slash].to_owned()
    None => ""
  }
  let by_key : Map[String, DocxPossiblePart] = Map([])
  let order : Array[String] = []
  // Every OPC consumer understands the relationships vocabulary itself,
  // so a choice requiring only it decides its alternate, and an element
  // outside it is looked through only where a `ProcessContent` says a
  // consumer would. A part whose ROOT is compatibility markup resolves
  // to a different root per consumer, so every possible root is walked.
  for possible_root in docx_mce_possible_roots(root) {
    for
      entry in docx_mce_possible(possible_root, [
        DOCX_PACKAGE_RELATIONSHIPS_NAMESPACE,
      ]) {
      let (relationship, condition) = entry
      guard relationship.name
        is (DOCX_PACKAGE_RELATIONSHIP_ELEMENT | "relationships:Relationship") else {
        continue
      }
      let kind = @xml.collapse_xml_schema_whitespace(
        relationship.attributes.get_or_default("Type", ""),
      )
      guard types.contains(kind) else { continue }
      // An EXTERNAL target names something outside the package, which is
      // not a part and cannot be read.
      let mode = @xml.collapse_xml_schema_whitespace(
        relationship.attributes.get_or_default("TargetMode", "Internal"),
      )
      guard mode == "Internal" else { continue }
      let target = @xml.collapse_xml_schema_whitespace(
        relationship.attributes.get_or_default("Target", ""),
      )
      guard @opc.resolve_part_target(base, target) is Some(part) else {
        continue
      }
      // Two targets that differ only in case name ONE part.
      let key = @opc.part_name_key(part)
      match by_key.get(key) {
        Some(known) =>
          // A bounded number of alternative paths is plenty: past it,
          // treat the part as reachable outright.
          if known.conditions.length() < 8 {
            known.conditions.push(condition)
          }
        None => {
          by_key[key] = { part, conditions: [condition], }
          order.push(key)
        }
      }
    }
  }
  let resolved : Array[DocxPossiblePart] = []
  for key in order {
    guard by_key.get(key) is Some(entry) else { continue }
    resolved.push(entry)
  }
  resolved
}

///|
/// The single part of `types` reachable from `source` under `prior`
/// conditions: `Absent`, `Found` with the combined conditions of its
/// paths, or `Ambiguous` when several DISTINCT parts are each reachable
/// by some consumer — which no later gate would catch.
fn docx_relationship_target_under(
  archive : @zip.Archive,
  parts : Map[String, (String, String)],
  source : String,
  types : Array[String],
  prior : Array[Array[DocxCapability]],
) -> (DocxPartLookup, Array[Array[DocxCapability]]) {
  let reachable : Array[DocxPossiblePart] = []
  for candidate in docx_relationship_targets(archive, parts, source, types) {
    let combined : Array[Array[DocxCapability]] = []
    for before in prior {
      for condition in candidate.conditions {
        let joined = before.copy()
        for capability in condition {
          joined.push(capability)
        }
        if docx_capabilities_satisfiable(joined) && combined.length() < 8 {
          combined.push(joined)
        }
      }
    }
    if !combined.is_empty() {
      reachable.push({ part: candidate.part, conditions: combined, })
    }
  }
  match reachable {
    [] => (Absent, [])
    [only] => (Found(only.part), only.conditions)
    // Several relationships of the same type naming different parts is
    // legal OPC and meaningless WML: nothing downstream would refuse it,
    // so the preflight must.
    _ => (Ambiguous, [])
  }
}

///|
const DOCX_WML_NAMESPACE : String = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"

///|
const DOCX_STRICT_WML_NAMESPACE : String = "http://purl.oclc.org/ooxml/wordprocessingml/main"

///|
/// What a settings flag says.
priv enum DocxSettingsFlag {
  Missing
  Disabled
  Enabled
  Ambiguous
}

///|
/// The settings a consumer acts on: the element children of the part's
/// root, after markup compatibility has had its say.
///
/// A setting is a CHILD of `w:settings`. Compatibility markup is the one
/// thing that can stand between the two, and the reader above has
/// already resolved it — selecting fallbacks, dropping ignorable content
/// the document did not ask to have processed, and promoting the content
/// it did.
fn docx_settings_children(root : @xml.XmlElement) -> Array[@xml.XmlElement] {
  let children : Array[@xml.XmlElement] = []
  for node in root.children {
    guard node is XmlElement(child) else { continue }
    children.push(child)
  }
  children
}

///|

///|
const DOCX_XMLNS_NAMESPACE : String = "http://www.w3.org/2000/xmlns/"

///|
/// The settings a DIFFERENT consumer might act on: every element that
/// could sit at the settings-child level under SOME resolution of the
/// part's compatibility markup.
fn docx_settings_possible(raw : @xml.XmlElement) -> Array[@xml.XmlElement] {
  // A settings part whose ROOT is compatibility markup resolves to a
  // different root per consumer: every possible settings root's
  // children are possible settings.
  let collected : Array[@xml.XmlElement] = []
  for root in docx_mce_possible_roots(raw) {
    guard root.name == "{\{DOCX_WML_NAMESPACE}}settings" ||
      root.name == "{\{DOCX_STRICT_WML_NAMESPACE}}settings" else {
      continue
    }
    for
      entry in docx_mce_possible(root, [
        DOCX_WML_NAMESPACE,
        DOCX_STRICT_WML_NAMESPACE,
      ]) {
      collected.push(entry.0)
    }
  }
  collected
}

///|
/// Every element that could be the ROOT a consumer reads: the part's
/// own root, or — when the root is an alternate — a branch's root,
/// recursively.
fn docx_mce_possible_roots(raw : @xml.XmlElement) -> Array[@xml.XmlElement] {
  let roots : Array[@xml.XmlElement] = []
  fn collect(element : @xml.XmlElement) -> Unit {
    if element.name == "{\{DOCX_MC_NAMESPACE}}AlternateContent" {
      for branch_node in element.children {
        guard branch_node is XmlElement(branch) else { continue }
        guard branch.name == "{\{DOCX_MC_NAMESPACE}}Choice" ||
          branch.name == "{\{DOCX_MC_NAMESPACE}}Fallback" else {
          continue
        }
        for node in branch.children {
          guard node is XmlElement(candidate) else { continue }
          collect(candidate)
        }
      }
    } else {
      roots.push(element)
    }
  }

  collect(raw)
  roots
}

///|
/// One consumer-capability constraint: the namespace must (or must not)
/// be supported for this path to be taken.
priv struct DocxCapability {
  uri : String
  supported : Bool
}

///|
/// Whether one consumer could satisfy every constraint at once.
fn docx_capabilities_satisfiable(condition : Array[DocxCapability]) -> Bool {
  let assignments : Map[String, Bool] = Map([])
  for capability in condition {
    match assignments.get(capability.uri) {
      Some(known) => if known != capability.supported { return false }
      None => assignments[capability.uri] = capability.supported
    }
  }
  true
}

///|
/// Every element that could sit at CHILD level of `raw` under some
/// consumer's resolution of its compatibility markup.
///
/// This walk models what other consumers do, where `understood` is what
/// EVERY consumer of this vocabulary understands. So it takes every
/// branch of every alternate — but a choice requiring only understood
/// namespaces decides its alternate, since every consumer stops there,
/// and the branches after it are unreachable. An element named by an
/// in-scope `mc:ProcessContent` is looked through, because a consumer
/// that finds it ignorable processes its content at this level; an
/// ignorable element nobody asked to process is dropped whole by one
/// consumer and kept whole by the rest, so its content is never at this
/// level. Understood-namespace elements are never looked through.
/// Re-declaring a namespace ignorable RESETS inherited process-content
/// rules for it (ECMA-376 Part 3), which the per-namespace generations
/// carry; matching is by map lookup, so a part with many rules and many
/// foreign children costs their sum rather than their product.
fn docx_mce_possible(
  raw : @xml.XmlElement,
  understood : Array[String],
) -> Array[(@xml.XmlElement, Array[DocxCapability])] {
  let possible : Array[(@xml.XmlElement, Array[DocxCapability])] = []
  // The capability constraints of the path to the element being walked:
  // a choice branch requires its namespaces supported, and the branches
  // after a SINGLE-requirement choice require it unsupported. (An
  // unsatisfied multi-requirement choice constrains by disjunction,
  // which is over-approximated as no constraint: more paths are treated
  // reachable, never fewer.)
  let condition : Array[DocxCapability] = []
  let scope : Map[String, String] = Map([])
  let process_exact : Map[String, Int] = Map([])
  let process_wildcard : Map[String, Int] = Map([])
  let generations : Map[String, Int] = Map([])
  fn count_up(counts : Map[String, Int], key : String) -> Unit {
    counts[key] = counts.get(key).unwrap_or(0) + 1
  }

  fn count_down(counts : Map[String, Int], key : String) -> Unit {
    match counts.get(key) {
      Some(count) if count > 1 => counts[key] = count - 1
      Some(_) => counts.remove(key)
      None => ()
    }
  }

  fn declarations(element : @xml.XmlElement) -> Array[(String, String?)] {
    let undo : Array[(String, String?)] = []
    for attribute in element.attributes {
      guard attribute.0.has_prefix("{\{DOCX_XMLNS_NAMESPACE}}") else {
        continue
      }
      let local = attribute.0
        .substring(start=DOCX_XMLNS_NAMESPACE.length() + 2)
        .to_string()
      let prefix = if local == "xmlns" { "" } else { local }
      undo.push((prefix, scope.get(prefix)))
      scope[prefix] = attribute.1
    }
    undo
  }

  fn restore(undo : Array[(String, String?)]) -> Unit {
    // In REVERSE: two entries about the same key must put back the
    // older state last.
    for offset in 0..<undo.length() {
      let entry = undo[undo.length() - offset - 1]
      match entry.1 {
        Some(previous) => scope[entry.0] = previous
        None => scope.remove(entry.0)
      }
    }
  }

  // The directives an element carries, applied in the order the spec
  // gives them meaning: `Ignorable` opens a new generation for each of
  // its namespaces, retiring inherited rules; the element's own
  // `ProcessContent` then declares rules in the new generation.
  fn directives(
    element : @xml.XmlElement,
  ) -> (Array[(String, Int?)], Array[(Bool, String)]) {
    let generation_undo : Array[(String, Int?)] = []
    match element.attributes.get("{\{DOCX_MC_NAMESPACE}}Ignorable") {
      Some(value) =>
        for token in docx_split_tokens(value) {
          guard scope.get(token) is Some(uri) else { continue }
          let previous = generations.get(uri)
          generation_undo.push((uri, previous))
          generations[uri] = previous.unwrap_or(0) + 1
        }
      None => ()
    }
    let added : Array[(Bool, String)] = []
    match element.attributes.get("{\{DOCX_MC_NAMESPACE}}ProcessContent") {
      Some(value) =>
        for token in docx_split_tokens(value) {
          let (uri, local) = match token.find(":") {
            Some(colon) => {
              let prefix = token.substring(start=0, end=colon).to_string()
              let local = token.substring(start=colon + 1).to_string()
              match scope.get(prefix) {
                Some(uri) => (uri, local)
                None => continue
              }
            }
            None =>
              match scope.get("") {
                Some(uri) => (uri, token.to_string())
                None => continue
              }
          }
          let generation = generations.get(uri).unwrap_or(0)
          if local == "*" {
            let key = "\{generation}\u{1}\{uri}"
            count_up(process_wildcard, key)
            added.push((true, key))
          } else {
            let key = "\{generation}\u{1}{\{uri}}\{local}"
            count_up(process_exact, key)
            added.push((false, key))
          }
        }
      None => ()
    }
    (generation_undo, added)
  }

  fn undo_directives(
    generation_undo : Array[(String, Int?)],
    added : Array[(Bool, String)],
  ) -> Unit {
    for entry in added {
      if entry.0 {
        count_down(process_wildcard, entry.1)
      } else {
        count_down(process_exact, entry.1)
      }
    }
    // In REVERSE: `Ignorable="v v2"` may bind one URI twice, and the
    // older generation must be what survives the undo.
    for offset in 0..<generation_undo.length() {
      let entry = generation_undo[generation_undo.length() - offset - 1]
      match entry.1 {
        Some(previous) => generations[entry.0] = previous
        None => generations.remove(entry.0)
      }
    }
  }

  fn element_uri(name : String) -> String {
    guard name.has_prefix("{") else { return "" }
    match name.find("}") {
      Some(close) => name.substring(start=1, end=close).to_string()
      None => ""
    }
  }

  fn matches_process_content(name : String) -> Bool {
    let uri = element_uri(name)
    let generation = generations.get(uri).unwrap_or(0)
    process_exact.get("\{generation}\u{1}\{name}") is Some(_) ||
    process_wildcard.get("\{generation}\u{1}\{uri}") is Some(_)
  }

  // The namespaces a choice requires, resolved where it sits; None for
  // a choice with no requirement to read.
  fn choice_requires(choice : @xml.XmlElement) -> Array[String]? {
    let requires = match choice.attributes.get("Requires") {
      Some(value) => value
      None =>
        match choice.attributes.get("{\{DOCX_MC_NAMESPACE}}Requires") {
          Some(value) => value
          None => return None
        }
    }
    let uris : Array[String] = []
    for token in docx_split_tokens(requires) {
      guard scope.get(token) is Some(uri) else { return None }
      uris.push(uri)
    }
    if uris.is_empty() {
      return None
    }
    Some(uris)
  }

  // Every prefix a choice requires resolves to an understood namespace
  // exactly when every consumer of this vocabulary satisfies it.
  fn choice_decides(choice : @xml.XmlElement) -> Bool {
    match choice_requires(choice) {
      Some(uris) => {
        for uri in uris {
          guard understood.contains(uri) else { return false }
        }
        true
      }
      None => false
    }
  }

  fn level(container : @xml.XmlElement) -> Unit {
    for node in container.children {
      guard node is XmlElement(child) else { continue }
      let undo = declarations(child)
      let (generation_undo, added) = directives(child)
      if child.name == "{\{DOCX_MC_NAMESPACE}}AlternateContent" {
        let mut decided = false
        // What reaching each later branch says about the consumer: every
        // single-requirement choice passed over required its namespace
        // UNSUPPORTED.
        let passed_over : Array[DocxCapability] = []
        for branch_node in child.children {
          guard branch_node is XmlElement(branch) else { continue }
          guard !decided else { break }
          let branch_undo = declarations(branch)
          let (branch_generation_undo, branch_added) = directives(branch)
          let mut pushed = 0
          for capability in passed_over {
            condition.push(capability)
            pushed += 1
          }
          if branch.name == "{\{DOCX_MC_NAMESPACE}}Choice" {
            let requires = choice_requires(branch)
            match requires {
              Some(uris) =>
                for uri in uris {
                  if !understood.contains(uri) {
                    condition.push({ uri, supported: true, })
                    pushed += 1
                  }
                }
              None => ()
            }
            level(branch)
            if choice_decides(branch) {
              decided = true
            }
            match requires {
              Some([only]) =>
                if !understood.contains(only) {
                  passed_over.push({ uri: only, supported: false, })
                }
              _ => ()
            }
          } else if branch.name == "{\{DOCX_MC_NAMESPACE}}Fallback" {
            level(branch)
          }
          for _ in 0..<pushed {
            condition.pop() |> ignore
          }
          undo_directives(branch_generation_undo, branch_added)
          restore(branch_undo)
        }
      } else {
        if docx_capabilities_satisfiable(condition) {
          possible.push((child, condition.copy()))
        }
        if !understood.contains(element_uri(child.name)) &&
          matches_process_content(child.name) {
          level(child)
        }
      }
      undo_directives(generation_undo, added)
      restore(undo)
    }
  }

  let root_undo = declarations(raw)
  let (root_generation_undo, root_added) = directives(raw)
  level(raw)
  undo_directives(root_generation_undo, root_added)
  restore(root_undo)
  possible
}

///|
/// XML-whitespace-separated tokens of an attribute value.
fn docx_split_tokens(value : String) -> Array[String] {
  let tokens : Array[String] = []
  let mut start = -1
  for offset in 0..<=value.length() {
    let boundary = offset == value.length() ||
      value[offset] is (' ' | '\t' | '\n' | '\r')
    if boundary {
      if start >= 0 {
        tokens.push(value.substring(start~, end=offset).to_string())
        start = -1
      }
    } else if start < 0 {
      start = offset
    }
  }
  tokens
}

///|
/// One WML on/off flag, read from a list of settings elements.
///
/// The answer is about EXPANDED names: `<w:trackRevisions x:val="false"/>`
/// carries no WML `w:val` at all and therefore means on, whatever a
/// local-name reading would say. Occurrences that disagree are reported
/// rather than resolved, because a preflight that picks a winner is
/// guessing about a document it is refusing to guess about.
fn docx_settings_flag(
  elements : Array[@xml.XmlElement],
  local : String,
  attribute : String,
  absent_means_on~ : Bool,
) -> DocxSettingsFlag {
  let mut verdict : DocxSettingsFlag = Missing
  fn observe(state : DocxSettingsFlag) -> Unit {
    verdict = match (verdict, state) {
      (Missing, seen) => seen
      (_, Ambiguous) | (Ambiguous, _) => Ambiguous
      (Enabled, Enabled) => Enabled
      (Disabled, Disabled) => Disabled
      _ => Ambiguous
    }
  }

  for element in elements {
    guard element.name == "{\{DOCX_WML_NAMESPACE}}\{local}" ||
      element.name == "{\{DOCX_STRICT_WML_NAMESPACE}}\{local}" else {
      continue
    }
    let values : Array[String] = []
    for dialect in [DOCX_WML_NAMESPACE, DOCX_STRICT_WML_NAMESPACE] {
      if element.attributes.get("{\{dialect}}\{attribute}") is Some(value) {
        let text = @xml.collapse_xml_schema_whitespace(value)
        if !values.contains(text) {
          values.push(text)
        }
      }
    }
    if values.length() > 1 {
      observe(Ambiguous)
    } else if values.is_empty() {
      observe(if absent_means_on { Enabled } else { Disabled })
    } else {
      observe(docx_on_off(values[0]))
    }
  }
  verdict
}

///|
const DOCX_MC_NAMESPACE : String = "http://schemas.openxmlformats.org/markup-compatibility/2006"

///|
/// Whether the document's write protection is ENFORCED rather than
/// merely recommended.
///
/// `<w:writeProtection w:recommended="1"/>` is advice Word lets a reader
/// dismiss, so refusing it would refuse documents anyone can edit.
/// Everything else the element can say is enforcement: the password
/// attributes in either generation's spelling, and the bare element,
/// which asks for write protection without recommending anything.
fn docx_write_protection_enforced(elements : Array[@xml.XmlElement]) -> Bool {
  for element in elements {
    guard element.name == "{\{DOCX_WML_NAMESPACE}}writeProtection" ||
      element.name == "{\{DOCX_STRICT_WML_NAMESPACE}}writeProtection" else {
      continue
    }
    let mut recommended_only = false
    for attribute in element.attributes {
      for dialect in [DOCX_WML_NAMESPACE, DOCX_STRICT_WML_NAMESPACE] {
        if attribute.0 == "{\{dialect}}recommended" {
          recommended_only = true
        } else if attribute.0.has_prefix("{\{dialect}}") {
          return true
        }
      }
    }
    if !recommended_only {
      return true
    }
  }
  false
}

///|
/// One `ST_OnOff` value. Anything the schema does not define is neither
/// on nor off, and a preflight does not invent a meaning for it.
fn docx_on_off(value : String) -> DocxSettingsFlag {
  match value {
    "true" | "1" | "on" => Enabled
    "false" | "0" | "off" => Disabled
    _ => Ambiguous
  }
}

///|
/// Plans and queues one formatting batch over the session snapshot.
pub fn DocxEditSession::queue_format(
  self : DocxEditSession,
  format~ : @word.DocxDirectFormat,
  text? : String,
  within? : String,
  nth? : Int,
  range? : (Int, Int),
) -> (@word.DocxFormatReceipt, String?) raise @transaction.TransactionError {
  // A stable `p[id="…"]` scope resolves against THIS transaction's
  // snapshot, with the same typed refusals the read surfaces give.
  let resolved_within : String? = match within {
    Some(scope) => Some(resolve_stable_replace_scope(self, scope))
    None => None
  }
  let (plan, receipt) = @word.plan_docx_format(
    self.annotated,
    self.annotated.main_story_source(),
    format~,
    text?,
    within?=resolved_within,
    nth?,
    range?,
  ) catch {
    error => raise mapped_plan_failure(error)
  }
  self.queue_plan(plan)
  (
    receipt,
    match (within, resolved_within) {
      (Some(requested), Some(resolved)) if requested != resolved =>
        Some(resolved)
      _ => None
    },
  )
}

///|
/// What the plan saw before it acted, kept so the readback judges the
/// edit against the document that was planned against rather than
/// against whatever the candidate happens to say.
///
/// Formatting never moves text, so the projection check alone would
/// pass on a document where nothing happened — and the direct-format
/// check alone would pass on one where far too much did. Together with
/// preservation they say: the paragraph still reads the same, the
/// selected spans carry the request EXPLICITLY, and no other formatting
/// in the paragraph changed.
priv struct FormatReadbackSnapshot {
  before : @word.DocxAnnotatedResult
  affected : Array[@word.DocxFormatAffected]
  spans : Array[@word.DocxFormatSpan]
}

///|
/// The three-check readback, as a validator.
fn format_readback_validator(
  snapshot : Ref[FormatReadbackSnapshot?],
  format : @word.DocxDirectFormat,
) -> @transaction.TransactionValidator raise @transaction.TransactionError {
  @transaction.transaction_validator("office-docx-format-readback", (
    candidate_format,
    _bytes,
    archive,
  ) => format_readback_findings(snapshot, format, candidate_format, archive))
}

///|
/// The three checks themselves, named rather than anonymous so the tests
/// can put a DOCTORED candidate in front of the very judgment the
/// transaction runs, instead of in front of a copy of it.
fn format_readback_findings(
  snapshot : Ref[FormatReadbackSnapshot?],
  format : @word.DocxDirectFormat,
  candidate_format : @office.DocumentFormat,
  archive : @zip.Archive,
) -> Array[@transaction.ValidationFinding] raise {
  let findings : Array[@transaction.ValidationFinding] = []
  if candidate_format != Docx {
    findings.push(
      @transaction.validation_finding(
        "docx.format.wrong_format", "format readback received a non-DOCX candidate",
      ),
    )
    return findings
  }
  let annotated = @word.read_docx_annotated_archive_limited(
    archive,
    candidate_xml_budget(),
  ) catch {
    error => {
      findings.push(
        @transaction.validation_finding(
          "docx.format.readback_unreadable",
          docx_validator_message(
            "candidate could not be re-read for the format readback: \{docx_error_message(error)}",
          ),
        ),
      )
      return findings
    }
  }
  // A validator that cannot see what it is judging must never pass:
  // the snapshot is captured inside the session, and its ABSENCE is
  // a finding rather than an empty comparison.
  guard snapshot.val is Some(captured) else {
    findings.push(
      @transaction.validation_finding(
        "docx.format.readback_uncaptured",
        docx_validator_message(
          "the format readback has no plan-time snapshot to compare against",
        ),
      ),
    )
    return findings
  }
  let story = annotated.main_story_source()
  // (1) Every affected paragraph still projects what it did. Every
  // question about this story is asked in ONE batch: resolving a
  // paragraph path costs a pass over the story, so asking per paragraph
  // would cost the document once per formatted paragraph.
  let projections = @word.docx_paragraphs_projection(
    annotated,
    story,
    paths=captured.affected.map(entry => entry.path()),
  )
  for position, entry in captured.affected {
    match projections[position] {
      Some(actual) =>
        if actual != entry.expected() {
          findings.push(
            @transaction.validation_finding(
              "docx.format.readback_mismatch",
              docx_validator_message(
                "paragraph \{entry.path()} reads back differently than the plan expected",
              ),
            ),
          )
        }
      None =>
        findings.push(
          @transaction.validation_finding(
            "docx.format.readback_missing",
            docx_validator_message(
              "paragraph \{entry.path()} no longer resolves in the candidate",
            ),
          ),
        )
    }
  }
  // The spans of each affected paragraph, grouped once.
  let by_paragraph : Map[String, Array[(Int, Int)]] = Map([])
  for span in captured.spans {
    let ranges = match by_paragraph.get(span.path()) {
      Some(existing) => existing
      None => {
        let created : Array[(Int, Int)] = []
        by_paragraph[span.path()] = created
        created
      }
    }
    ranges.push((span.start(), span.end()))
  }
  // The batch every span-level question is asked in, in one order.
  let requests : Array[(String, Array[(Int, Int)])] = []
  for entry in by_paragraph {
    requests.push(entry)
  }
  // (2) The selected spans carry the request EXPLICITLY.
  let formatted = @word.docx_paragraphs_direct_format(
    annotated,
    story,
    requests~,
    format~,
  ) catch {
    error =>
      requests.map(_ => {
        Some("could not be judged: \{docx_error_message(error)}")
      })
  }
  for position, request in requests {
    if formatted[position] is Some(discrepancy) {
      findings.push(
        @transaction.validation_finding(
          "docx.format.readback_unformatted",
          docx_validator_message(
            "paragraph \{request.0} does not carry the requested formatting: \{discrepancy}",
          ),
        ),
      )
    }
  }
  // Every paragraph judged one way must be judged the other: a
  // paragraph in `affected` with no spans would go unformatted-checked,
  // and a span whose paragraph is not affected would go
  // unprojection-checked.
  let affected_paths : Map[String, Bool] = Map([])
  for entry in captured.affected {
    if affected_paths.get(entry.path()) is Some(_) {
      findings.push(
        @transaction.validation_finding(
          "docx.format.readback_inconsistent",
          docx_validator_message(
            "paragraph \{entry.path()} appears twice in the plan's affected list",
          ),
        ),
      )
    }
    affected_paths[entry.path()] = true
  }
  for entry in by_paragraph {
    if affected_paths.get(entry.0) is None {
      findings.push(
        @transaction.validation_finding(
          "docx.format.readback_inconsistent",
          docx_validator_message(
            "paragraph \{entry.0} carries selected spans but the plan did not report it as affected",
          ),
        ),
      )
    }
  }
  for path in affected_paths {
    if by_paragraph.get(path.0) is None {
      findings.push(
        @transaction.validation_finding(
          "docx.format.readback_inconsistent",
          docx_validator_message(
            "paragraph \{path.0} was reported as affected but carries no selected span",
          ),
        ),
      )
    }
  }
  // (3) Nothing else about the paragraph's formatting moved.
  let original = captured.before
  let original_story = original.main_story_source()
  let preserved = @word.docx_paragraphs_format_preserved(
    original,
    original_story,
    annotated,
    story,
    requests~,
    format~,
  ) catch {
    error =>
      requests.map(_ => {
        Some("could not be compared: \{docx_error_message(error)}")
      })
  }
  for position, request in requests {
    if preserved[position] is Some(discrepancy) {
      findings.push(
        @transaction.validation_finding(
          "docx.format.readback_collateral",
          docx_validator_message(
            "paragraph \{request.0} changed formatting nobody asked for: \{discrepancy}",
          ),
        ),
      )
    }
  }
  findings
}

///|
/// One complete formatting transaction.
///
/// The policy points live HERE, not in the engine, because they are
/// caller policy about outcomes rather than facts about documents:
///
/// - the shared mutation preflight refuses a signed, protected, or
///   revision-tracking document before anything is planned;
/// - `expect` asserts the SELECTED span count; a mismatch refuses
///   before anything is published;
/// - zero selected without `allow_zero` refuses;
/// - a semantic no-op still runs every refusal and every readback, and
///   reports `changed=false` from the transaction rather than guessing;
/// - `preflight` lets the caller refuse over the REPORT it is about to
///   receive, before validation and publication.
pub async fn transact_docx_format(
  options : @transaction.TransactionOptions,
  format~ : @word.DocxDirectFormat,
  text? : String,
  within? : String,
  nth? : Int,
  range? : (Int, Int),
  expect? : Int,
  allow_zero? : Bool = false,
  preflight? : (DocxFormatReport) -> Unit raise,
) -> DocxFormatResult {
  let collected : Ref[DocxFormatReport?] = Ref(None)
  let snapshot : Ref[FormatReadbackSnapshot?] = Ref(None)
  let readback = format_readback_validator(snapshot, format)
  let transaction = transact_docx(
    options,
    session => {
      let before = session.annotated
      let (receipt, resolved_within) = session.queue_format(
        format~,
        text?,
        within?,
        nth?,
        range?,
      )
      // `expect` is checked FIRST, so `--expect 0` can hold: an
      // explicit assertion of zero is a satisfiable claim.
      let selected_count = receipt.spans().length()
      match expect {
        Some(count) =>
          if selected_count != count {
            raise @transaction.transaction_failure(
              "office.format.expect_mismatch",
              "expected \{count} span(s) but \{selected_count} were selected",
            )
          }
        None =>
          if selected_count == 0 && !allow_zero {
            raise @transaction.transaction_failure(
              "office.format.no_match", "no span was selected; pass allow-zero to treat that as success, or expect 0 to assert it",
            )
          }
      }
      snapshot.val = Some({
        before,
        affected: receipt.affected(),
        spans: receipt.spans(),
      })
      let report : DocxFormatReport = {
        mode: receipt.mode(),
        requested_text: receipt.requested_text(),
        requested_within: within,
        requested_nth: receipt.requested_nth(),
        requested_range: receipt.requested_range(),
        resolved_within,
        selected: receipt.selected(),
        spans: receipt.spans(),
        affected: receipt.affected(),
        runs_changed: receipt.runs_changed(),
        runs_already_satisfied: receipt.runs_already_satisfied(),
        splits: receipt.splits(),
        byte_edits: receipt.byte_edits(),
      }
      match preflight {
        Some(check) => check(report)
        None => ()
      }
      collected.val = Some(report)
    },
    validators=[readback],
  )
  guard collected.val is Some(report) else {
    raise docx_failure(
      "office.docx.edit_internal", "the format transaction returned no report",
    )
  }
  { report, transaction, }
}
