// Builder side of the OPC primitives (the read/validation side lives in
// validate.mbt): assemble a package from parts, content types, and
// relationships, fail-closed. Defense in depth: the add-time checks give
// early errors, the struct's state is private, and `build()` re-validates
// EVERYTHING from the authoritative part list anyway — name shape,
// reserved/duplicate names, coverage, override targets, relationship
// sources AND targets, and metadata well-formedness — so no sequence of
// calls (or future code path) can emit a package `docx validate` would
// reject.
//
// Follow-up (flagged, not this PR): docx/embedded_style_map.mbt hand-emits
// the same Types/Relationships XML; migrate it onto these emitters.

///|
/// A package that cannot be built as specified. The message is
/// caller-facing and names the offending part/relationship.
pub(all) suberror PackageBuildError {
  PackageBuildError(String)
} derive(Eq)

///|
pub impl Show for PackageBuildError with fn output(self, logger) {
  match self {
    PackageBuildError(message) => logger.write_string(message)
  }
}

///|
priv struct PackageRelationship {
  id : String
  relationship_type : String
  target : String
  external : Bool
}

///|
/// Assembles an OPC package. State is private — mutate only through the
/// `add_*` methods. `build()` emits `[Content_Types].xml`, then every
/// relationships part, then the parts in insertion order.
pub struct PackageBuilder {
  priv parts : Array[(String, Bytes)]
  priv defaults : StableStringMap[String]
  priv overrides : StableStringMap[String]
  priv relationships : StableStringMap[Array[PackageRelationship]]
}

///|
/// An empty builder: no parts, no content types, no relationships.
pub fn PackageBuilder::new() -> PackageBuilder {
  {
    parts: [],
    defaults: SortedMap([]),
    overrides: SortedMap([]),
    relationships: SortedMap([]),
  }
}

///|
/// Adds a part by logical OPC name (`word/document.xml`, no leading slash).
/// The builder maps non-ASCII scalars to their ASCII ZIP item spelling at
/// serialization time. Malformed, reserved (builder-emitted), or duplicate
/// names raise.
pub fn PackageBuilder::add_part(
  self : PackageBuilder,
  name : String,
  data : Bytes,
) -> Unit raise PackageBuildError {
  check_part_name(name)
  for entry in self.parts {
    let (existing, _) = entry
    if existing == name {
      raise PackageBuildError("duplicate part name: \{name}")
    } else if builder_part_identity(existing) == builder_part_identity(name) {
      raise PackageBuildError(
        "duplicate part name after case normalization: \{existing} and \{name}",
      )
    }
  }
  self.parts.push((name, data))
}

///|
/// Registers an extension default (`xml` → content type).
pub fn PackageBuilder::add_default(
  self : PackageBuilder,
  extension : String,
  content_type : String,
) -> Unit raise PackageBuildError {
  check_metadata("Default extension", extension)
  check_metadata("Default content type", content_type)
  self.defaults[extension.to_lower()] = content_type
}

///|
/// Registers a content-type override. `part_name` is pack-form and must
/// start with `/` (`/word/document.xml`).
pub fn PackageBuilder::add_override(
  self : PackageBuilder,
  part_name : String,
  content_type : String,
) -> Unit raise PackageBuildError {
  if !part_name.has_prefix("/") {
    raise PackageBuildError(
      "override PartName must start with '/': \{part_name}",
    )
  }
  if normalize_override_part_name(part_name) != Some(part_name) {
    raise PackageBuildError(
      "override PartName is not a canonical logical part name: \{part_name}",
    )
  }
  check_metadata("Override PartName", part_name)
  check_metadata("Override content type", content_type)
  let key = builder_part_identity(part_name)
  for existing, _ in self.overrides {
    if builder_part_identity(existing) == key && existing != part_name {
      raise PackageBuildError(
        "duplicate Override PartName after case normalization: \{existing} and \{part_name}",
      )
    }
  }
  self.overrides[part_name] = content_type
}

///|
/// Adds a relationship. `source~` is the part the relationship belongs to
/// (`""` = the package root `_rels/.rels`); `target` is source-relative (or
/// pack-absolute with a leading `/`). Ids must be unique per source.
/// `external~` marks a `TargetMode="External"` relationship (e.g. a
/// hyperlink URL); external targets are emitted verbatim and exempt from
/// the internal-target resolution check.
pub fn PackageBuilder::add_relationship(
  self : PackageBuilder,
  id : String,
  relationship_type : String,
  target : String,
  source? : String = "",
  external? : Bool = false,
) -> Unit raise PackageBuildError {
  check_metadata("relationship Id", id)
  check_metadata("relationship Type", relationship_type)
  check_metadata("relationship Target", target)
  let rels = match self.relationships.get(source) {
    Some(existing) => existing
    None => {
      let fresh : Array[PackageRelationship] = []
      self.relationships[source] = fresh
      fresh
    }
  }
  for existing in rels {
    if existing.id == id {
      raise PackageBuildError(
        "duplicate relationship Id '\{id}' for source '\{source}'",
      )
    }
  }
  rels.push({ id, relationship_type, target, external })
}

///|
/// Emits the package bytes. Everything is re-validated here from the
/// authoritative state: part names (shape, reserved, duplicates — including
/// collisions with the builder's own emitted rels parts), content-type
/// coverage for every emitted entry, override targets, relationship sources
/// AND internal targets, and metadata well-formedness. Output is
/// deterministic for a given call sequence.
pub fn PackageBuilder::build(
  self : PackageBuilder,
) -> Bytes raise PackageBuildError {
  // Authoritative name set, revalidated from scratch.
  let part_names : StableStringMap[String] = SortedMap([])
  for entry in self.parts {
    let (name, _) = entry
    check_part_name(name)
    let key = builder_part_identity(name)
    match part_names.get(key) {
      Some(existing) if existing == name =>
        raise PackageBuildError("duplicate part name: \{name}")
      Some(existing) =>
        raise PackageBuildError(
          "duplicate part name after case normalization: \{existing} and \{name}",
        )
      None => part_names[key] = name
    }
  }
  // Generated entries are builder-owned; a collision with an explicit part
  // would emit duplicate zip entries (Archive::add appends blindly), which
  // is exactly what validation rejects.
  let emitted_rels : Array[String] = []
  let emitted_rels_by_key : StableStringMap[String] = SortedMap([])
  for source, rels in self.relationships {
    // Every non-root source must be an added part, or its rels part would
    // be an orphan describing nothing.
    if source != "" && !part_names.contains(builder_part_identity(source)) {
      raise PackageBuildError(
        "relationships declared for source '\{source}', which was not added as a part",
      )
    }
    let seen_ids : StableStringSet = SortedSet([])
    for relationship in rels {
      check_metadata("relationship Id", relationship.id)
      check_metadata("relationship Type", relationship.relationship_type)
      check_metadata("relationship Target", relationship.target)
      if seen_ids.contains(relationship.id) {
        raise PackageBuildError(
          "duplicate relationship Id '\{relationship.id}' for source '\{source}'",
        )
      }
      seen_ids.add(relationship.id)
    }
    let name = if source == "" { ROOT_RELS_PART } else { rels_part_for(source) }
    let name_key = builder_part_identity(name)
    if part_names.contains(name_key) {
      raise PackageBuildError(
        "part name collides with the builder-emitted relationships part: \{name}",
      )
    }
    match emitted_rels_by_key.get(name_key) {
      Some(existing) =>
        raise PackageBuildError(
          "builder-emitted relationships parts are case-equivalent: \{existing} and \{name}",
        )
      None => emitted_rels_by_key[name_key] = name
    }
    emitted_rels.push(name)
  }
  let override_names : StableStringMap[String] = SortedMap([])
  for part_name, content_type in self.overrides {
    check_metadata("Override PartName", part_name)
    check_metadata("Override content type", content_type)
    guard part_name.has_prefix("/") else {
      raise PackageBuildError(
        "override PartName must start with '/': \{part_name}",
      )
    }
    if normalize_override_part_name(part_name) != Some(part_name) {
      raise PackageBuildError(
        "override PartName is not a canonical logical part name: \{part_name}",
      )
    }
    let override_key = builder_part_identity(part_name)
    match override_names.get(override_key) {
      Some(existing) if existing != part_name =>
        raise PackageBuildError(
          "duplicate Override PartName after case normalization: \{existing} and \{part_name}",
        )
      _ => override_names[override_key] = part_name
    }
    let archive_name = part_name[1:].to_owned()
    if !part_names.contains(builder_part_identity(archive_name)) {
      raise PackageBuildError(
        "override names a part that was not added: \{part_name}",
      )
    }
  }
  for extension, content_type in self.defaults {
    check_metadata("Default extension", extension)
    check_metadata("Default content type", content_type)
  }
  for entry in self.parts {
    let (name, _) = entry
    self.check_coverage(name)
  }
  for name in emitted_rels {
    self.check_coverage(name)
  }
  for source, rels in self.relationships {
    let base = split_part_dir(source)
    for relationship in rels {
      if relationship.external {
        continue
      }
      guard resolve_part_target(base, relationship.target) is Some(resolved) else {
        raise PackageBuildError(
          "relationship \{relationship.id} of '\{source}' has an invalid internal target: \{relationship.target}",
        )
      }
      if !part_names.contains(builder_part_identity(resolved)) {
        raise PackageBuildError(
          "relationship \{relationship.id} of '\{source}' targets a part that was not added: \{relationship.target} (resolved \{resolved})",
        )
      }
    }
  }
  let archive = @mbtzip.Archive::new()
  archive.add(
    CONTENT_TYPES_PART,
    @utf8.encode(self.content_types_xml()),
    compression=Deflate,
  )
  for source, rels in self.relationships {
    let name = if source == "" { ROOT_RELS_PART } else { rels_part_for(source) }
    let zip_name = zip_item_name_from_logical_part_name(name).unwrap()
    archive.add(
      zip_name,
      @utf8.encode(relationships_xml(rels)),
      compression=Deflate,
    )
  }
  for entry in self.parts {
    let (name, data) = entry
    let zip_name = zip_item_name_from_logical_part_name(name).unwrap()
    archive.add(zip_name, data, compression=Deflate)
  }
  @mbtzip.write(archive) catch {
    err =>
      raise PackageBuildError("could not assemble the archive: \{repr(err)}")
  }
}

///|
/// Part-name policy: canonical logical PartName syntax plus builder specifics
/// — no trailing slash (a "directory" is not a part) and no
/// builder-owned names (`[Content_Types].xml` and anything shaped like a
/// relationships part: the builder emits all relationships itself).
fn check_part_name(name : String) -> Unit raise PackageBuildError {
  if name == "" || name.has_prefix("/") || name.has_suffix("/") {
    raise PackageBuildError(
      "invalid part name '\{name}': expected a non-empty logical part name without a leading or trailing slash",
    )
  }
  let key = builder_part_identity(name)
  if key == builder_part_identity(CONTENT_TYPES_PART) ||
    key == builder_part_identity(ROOT_RELS_PART) ||
    is_rels_part(key) {
    raise PackageBuildError(
      "reserved part name '\{name}': the builder emits content types and relationships itself",
    )
  }
  for segment in name.split("/") {
    if !is_valid_part_segment(segment) {
      raise PackageBuildError(
        "invalid part name '\{name}': not a canonical OPC logical PartName",
      )
    }
  }
}

///|
fn builder_part_identity(name : String) -> String {
  part_name_key(name)
}

///|
/// Metadata strings are emitted into XML attributes: they must be
/// non-empty and free of XML-1.0-illegal control characters (the escaper
/// passes those through, and the SDK rejects the result).
fn check_metadata(
  what : String,
  value : String,
) -> Unit raise PackageBuildError {
  if value == "" {
    raise PackageBuildError("\{what} must not be empty")
  }
  for unit in value {
    let code = unit.to_int()
    if code < 0x20 && !(unit is ('\t' | '\n' | '\r')) {
      raise PackageBuildError(
        "\{what} contains an XML-illegal control character (code \{code})",
      )
    }
  }
}

///|
fn rels_part_for(part : String) -> String {
  let (dir, file) = match part.rev_find("/") {
    Some(index) => (part[:index].to_owned(), part[index + 1:].to_owned())
    None => ("", part)
  }
  if dir == "" {
    "_rels/\{file}.rels"
  } else {
    "\{dir}/_rels/\{file}.rels"
  }
}

///|
fn split_part_dir(part : String) -> String {
  match part.rev_find("/") {
    Some(index) => part[:index].to_owned()
    None => ""
  }
}

///|
fn PackageBuilder::check_coverage(
  self : PackageBuilder,
  name : String,
) -> Unit raise PackageBuildError {
  if name == CONTENT_TYPES_PART {
    return
  }
  let override_key = builder_part_identity("/" + name)
  for part_name, _ in self.overrides {
    if builder_part_identity(part_name) == override_key {
      return
    }
  }
  if part_extension(name) is Some(ext) && self.defaults.contains(ext) {
    return
  }
  raise PackageBuildError(
    "no content type for part '\{name}': add a Default for its extension or an Override",
  )
}

///|
fn PackageBuilder::content_types_xml(self : PackageBuilder) -> String {
  let children : Array[@xml.XmlNode] = []
  for extension, content_type in self.defaults {
    children.push(
      XmlElement(
        @xml.xml_element("Default", attributes={
          "Extension": extension,
          "ContentType": content_type,
        }),
      ),
    )
  }
  for part_name, content_type in self.overrides {
    children.push(
      XmlElement(
        @xml.xml_element("Override", attributes={
          "PartName": part_name,
          "ContentType": content_type,
        }),
      ),
    )
  }
  // write_xml_string supplies the XML declaration.
  @xml.write_xml_string(@xml.xml_element("Types", children~), namespaces={
    "": "http://schemas.openxmlformats.org/package/2006/content-types",
  })
}

///|
fn relationships_xml(rels : Array[PackageRelationship]) -> String {
  let children : Array[@xml.XmlNode] = []
  for relationship in rels {
    let attributes : Map[String, String] = {
      "Id": relationship.id,
      "Type": relationship.relationship_type,
      "Target": relationship.target,
    }
    if relationship.external {
      attributes["TargetMode"] = "External"
    }
    children.push(XmlElement(@xml.xml_element("Relationship", attributes~)))
  }
  @xml.write_xml_string(@xml.xml_element("Relationships", children~), namespaces={
    "": "http://schemas.openxmlformats.org/package/2006/relationships",
  })
}

///|
/// White-box: reach build()-time validation directly (the public setters
/// already reject these states, and the fields are private outside the
/// package — this pins the authoritative-revalidation layer itself).
test "build revalidates duplicate relationship ids from raw state" {
  let builder : PackageBuilder = {
    parts: [("word/document.xml", b"<d/>")],
    defaults: SortedMap([
      ("rels", "application/vnd.openxmlformats-package.relationships+xml"),
      ("xml", "application/xml"),
    ]),
    overrides: SortedMap([]),
    relationships: SortedMap([
      (
        "",
        [
          {
            id: "rId1",
            relationship_type: "t",
            target: "word/document.xml",
            external: false,
          },
          {
            id: "rId1",
            relationship_type: "t",
            target: "word/document.xml",
            external: false,
          },
        ],
      ),
    ]),
  }
  try builder.build() catch {
    PackageBuildError(message) =>
      inspect(
        message.has_prefix("duplicate relationship Id 'rId1' for source ''"),
        content="true",
      )
  } noraise {
    _ => fail("expected build-time duplicate-id rejection")
  }
}

///|
test "build revalidates part names from raw state" {
  let builder : PackageBuilder = {
    parts: [("word/document.xml", b"<d/>"), ("word/document.xml", b"<d/>")],
    defaults: SortedMap([("xml", "application/xml")]),
    overrides: SortedMap([]),
    relationships: SortedMap([]),
  }
  try builder.build() catch {
    PackageBuildError(message) =>
      inspect(
        message.has_prefix("duplicate part name: word/document.xml"),
        content="true",
      )
  } noraise {
    _ => fail("expected build-time duplicate-part rejection")
  }
}
