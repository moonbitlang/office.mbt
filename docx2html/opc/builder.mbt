// Builder side of the OPC primitives (the read/validation side lives in
// validate.mbt): assemble a package from parts, content types, and
// relationships, fail-closed. `build` re-checks what validation checks —
// part-name shape, duplicate names, content-type coverage, override and
// internal-relationship targets — so a builder misuse raises instead of
// producing a package `docx validate` would reject.
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
/// One relationship row as the builder will emit it (readonly).
pub struct PackageRelationship {
  id : String
  relationship_type : String
  target : String
}

///|
/// Assembles an OPC package. Parts keep insertion order; `build` emits
/// `[Content_Types].xml` first, then `_rels/.rels`, then each part followed
/// by its own relationships part.
pub struct PackageBuilder {
  parts : Array[(String, Bytes)]
  part_names : Set[String]
  defaults : Map[String, String]
  overrides : Map[String, String]
  relationships : Map[String, Array[PackageRelationship]]
}

///|
/// An empty builder: no parts, no content types, no relationships.
pub fn PackageBuilder::new() -> PackageBuilder {
  {
    parts: [],
    part_names: Set([]),
    defaults: Map([]),
    overrides: Map([]),
    relationships: Map([]),
  }
}

///|
/// Adds a part. The name is archive-form (`word/document.xml`, no leading
/// slash); malformed or duplicate names raise.
pub fn PackageBuilder::add_part(
  self : PackageBuilder,
  name : String,
  data : Bytes,
) -> Unit raise PackageBuildError {
  let problems : Array[String] = []
  check_entry_name(name, problems)
  if problems.length() > 0 {
    raise PackageBuildError("invalid part name '\{name}': \{problems[0]}")
  }
  if self.part_names.contains(name) {
    raise PackageBuildError("duplicate part name: \{name}")
  }
  self.part_names.add(name)
  self.parts.push((name, data))
}

///|
/// Registers an extension default (`xml` → content type).
pub fn PackageBuilder::add_default(
  self : PackageBuilder,
  extension : String,
  content_type : String,
) -> Unit {
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
  self.overrides[part_name] = content_type
}

///|
/// Adds a relationship. `source~` is the part the relationship belongs to
/// (`""` = the package root `_rels/.rels`); `target` is source-relative (or
/// pack-absolute with a leading `/`).
pub fn PackageBuilder::add_relationship(
  self : PackageBuilder,
  id : String,
  relationship_type : String,
  target : String,
  source? : String = "",
) -> Unit {
  let rels = match self.relationships.get(source) {
    Some(existing) => existing
    None => {
      let fresh : Array[PackageRelationship] = []
      self.relationships[source] = fresh
      fresh
    }
  }
  rels.push({ id, relationship_type, target })
}

///|
/// Emits the package bytes, fail-closed: every part must be covered by a
/// default or override, overrides must name added parts, and internal
/// relationship targets must resolve to added parts.
pub fn PackageBuilder::build(
  self : PackageBuilder,
) -> Bytes raise PackageBuildError {
  // Coverage and target checks against the FINAL part list (including the
  // rels parts this builder itself will emit, which the `rels` default must
  // cover).
  let emitted_rels : Array[String] = []
  for source, _ in self.relationships {
    emitted_rels.push(
      if source == "" {
        ROOT_RELS_PART
      } else {
        rels_part_for(source)
      },
    )
  }
  for part_name, _ in self.overrides {
    let archive_name = part_name[1:].to_owned()
    if !self.part_names.contains(archive_name) {
      raise PackageBuildError(
        "override names a part that was not added: \{part_name}",
      )
    }
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
      let resolved = resolve_target(base, relationship.target)
      if !self.part_names.contains(resolved) {
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
    archive.add(
      name,
      @utf8.encode(relationships_xml(rels)),
      compression=Deflate,
    )
  }
  for entry in self.parts {
    let (name, data) = entry
    archive.add(name, data, compression=Deflate)
  }
  @mbtzip.write(archive) catch {
    err =>
      raise PackageBuildError("could not assemble the archive: \{repr(err)}")
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
  if self.overrides.contains("/" + name) {
    return
  }
  if part_extension(name) is Some(ext) && self.defaults.contains(ext) {
    return
  }
  raise PackageBuildError(
    "no content type for part '\{name}': add a Default for its extension or an Override",
  )
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
  // write_xml_string already emits the XML declaration.
  @xml.write_xml_string(@xml.xml_element("Types", children~), namespaces={
    "": "http://schemas.openxmlformats.org/package/2006/content-types",
  })
}

///|
fn relationships_xml(rels : Array[PackageRelationship]) -> String {
  let children : Array[@xml.XmlNode] = []
  for relationship in rels {
    children.push(
      XmlElement(
        @xml.xml_element("Relationship", attributes={
          "Id": relationship.id,
          "Type": relationship.relationship_type,
          "Target": relationship.target,
        }),
      ),
    )
  }
  @xml.write_xml_string(@xml.xml_element("Relationships", children~), namespaces={
    "": "http://schemas.openxmlformats.org/package/2006/relationships",
  })
}
