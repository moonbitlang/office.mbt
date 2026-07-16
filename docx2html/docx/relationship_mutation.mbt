///|
/// Strictly parses a Relationships part for a byte-preserving mutation under
/// the caller's cumulative budget. Semantic readers may consume the effective
/// MCE projection, but a writer that replaces or splices the raw part must not
/// silently discard consumer-specific branches. Resource failures retain their
/// typed XML error; malformed or compatibility-dependent input fails closed.
fn read_mutation_relationships(
  part : String,
  bytes : BytesView,
  xml_budget : @xml.XmlReadBudget,
) -> XmlElement raise DocxError {
  let (raw_root, root) = @opc.read_opc_relationships_xml_with_roots_limited(
    bytes, xml_budget,
  ) catch {
    ResourceLimit(..) as error => raise error
    InvalidXml(message~) => {
      if message == "XML source is not valid UTF-8" {
        raise Unsupported(message="'\{part}' is not UTF-8; refusing")
      }
      raise Unsupported(message="'\{part}' is not well-formed XML; refusing")
    }
    _ => raise Unsupported(message="'\{part}' is not well-formed XML; refusing")
  }
  if root.name != PACKAGE_RELATIONSHIPS_ROOT {
    raise Unsupported(
      message="'\{part}' has root '\{root.name}', expected '\{PACKAGE_RELATIONSHIPS_ROOT}'; refusing",
    )
  }
  if raw_root.name != PACKAGE_RELATIONSHIPS_ROOT {
    raise Unsupported(
      message="'\{part}' selects its Relationships root through Markup Compatibility; byte-preserving mutation is unsupported; refusing",
    )
  }
  if relationship_tree_contains_mce_markup(raw_root) {
    raise Unsupported(
      message="'\{part}' contains Markup Compatibility branches or directives; byte-preserving relationship mutation is unsupported; refusing",
    )
  }
  root
}

///|
/// A direct insertion or whole-part rewrite becomes visible beside a different
/// set of preserved children for each MCE-aware consumer. Refuse that edit when
/// the raw tree contains active MCE markup; an unused namespace declaration is
/// represented in the XMLNS namespace and is intentionally harmless.
fn relationship_tree_contains_mce_markup(element : XmlElement) -> Bool {
  let mce_prefix = "{\{MC_NAMESPACE}}"
  if element.name.has_prefix(mce_prefix) {
    return true
  }
  for name, _ in element.attributes {
    if name.has_prefix(mce_prefix) {
      return true
    }
  }
  for child in element.children {
    match child {
      XmlElement(inner) =>
        if relationship_tree_contains_mce_markup(inner) {
          return true
        }
      XmlText(_) => ()
    }
  }
  false
}
