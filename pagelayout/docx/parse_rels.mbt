///|
// Relationship resolution. `w:headerReference r:id="rId35"` names a
// relationship, not a part, so the target has to come from
// `word/_rels/document.xml.rels`. The same mechanism is how a package
// may legitimately place its main document somewhere other than
// `word/document.xml`.

///|
/// Relationship targets by id, for one source part.
pub struct Relationships {
  targets : Map[String, String]
  types : Map[String, String]
}

///|
/// No relationships — every lookup misses, so callers fall back.
pub fn Relationships::empty() -> Relationships {
  { targets: Map([]), types: Map([]), }
}

///|
/// Parse a `_rels` part.
pub fn read_relationships(root : @xml.XmlElement) -> Relationships {
  let rels = Relationships::empty()
  for node in root.elements_by_tag_name("rel:Relationship") {
    guard node.attributes.get("Id") is Some(id) else { continue }
    match node.attributes.get("Target") {
      Some(target) => rels.targets[id] = target
      None => ()
    }
    match node.attributes.get("Type") {
      Some(kind) => rels.types[id] = kind
      None => ()
    }
  }
  rels
}

///|
/// Resolve a relationship id to a package part name, relative to the
/// directory holding the source part. Absolute targets (a leading `/`)
/// are package-rooted; external targets are not parts at all.
pub fn Relationships::part(
  self : Relationships,
  id : String,
  base_dir : String,
) -> String? {
  guard self.targets.get(id) is Some(target) else { return None }
  if target.length() == 0 || target.contains("://") {
    return None
  }
  if target[0] == '/' {
    return Some(target[1:].to_owned())
  }
  Some(base_dir + target)
}

///|
/// The first relationship whose type ends with `suffix` (relationship
/// types differ between the transitional and strict namespaces, so only
/// the last segment is matched).
pub fn Relationships::first_of_type(
  self : Relationships,
  suffix : String,
  base_dir : String,
) -> String? {
  for id, kind in self.types {
    if kind.has_suffix(suffix) {
      return self.part(id, base_dir)
    }
  }
  None
}
