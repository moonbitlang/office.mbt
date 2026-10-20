///|
/// Some exporters append embedded-font relationships without inheriting the
/// .rels namespace. Accept that specific defect in this read-only projection;
/// keep every other relationship subject to the OPC parser's strict contract.
fn relationships(
  pkg : @opc.Package,
  source : String,
) -> @opc.Relationships raise {
  pkg.relationships_for(source) catch {
    MalformedPackage(_) as original => {
      guard pkg.part_by_name(@opc.rels_path_for(source)) is Some(part) else {
        raise original
      }
      let root = parse_root(part.bytes())
      guard root.name.uri == @opc.relationships_ns &&
        root.name.local_name == "Relationships" else {
        raise original
      }
      let mut changed = false
      let children : Array[@xml.XmlNode] = []
      for node in root.children {
        match node {
          Element(element) if element.name.uri == "" &&
            element.name.local_name == "Relationship" &&
            attribute(element, "Type") ==
            Some(@oxml.office_relationships_ns + "/font") => {
            changed = true
            children.push(
              Element({
                ..element,
                name: @xml.QName::new(@opc.relationships_ns, "Relationship"),
              }),
            )
          }
          _ => children.push(node)
        }
      }
      guard changed else { raise original }
      @opc.Relationships::parse(source, xml_bytes({ ..root, children, }))
    }
    error => raise error
  }
}
