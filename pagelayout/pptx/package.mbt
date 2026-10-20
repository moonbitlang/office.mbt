///|
fn xml_bytes(root : @xml.XmlElement) -> FixedArray[Byte] raise {
  let writer = @xml.XmlWriter::new()
  let ctx = @oxml.WriteCtx::with_well_known_prefixes()
  let bindings : Map[String, String] = Map([])
  fn bind(uri : String) {
    if uri == "" || bindings.contains(uri) {
      return
    }
    let prefix = match uri {
      value if value == @oxml.presentation_ns => "p"
      value if value == @oxml.drawing_ns => "a"
      value if value == @oxml.office_relationships_ns => "r"
      "http://www.w3.org/XML/1998/namespace" => "xml"
      _ => "ns\{bindings.length()}"
    }
    bindings[uri] = prefix
    writer.bind_namespace(prefix, uri)
    ctx.bind_namespace(prefix, uri)
  }
  fn collect(element : @xml.XmlElement) {
    bind(element.name.uri)
    for pair in element.attributes {
      bind(pair.0.uri)
    }
    for child in element_children(element) {
      collect(child)
    }
  }
  collect(root)
  writer.start_element(root.name)
  for uri, prefix in bindings {
    writer.namespace_attr(prefix, uri)
  }
  for pair in root.attributes {
    writer.attribute(pair.0, pair.1)
  }
  for node in root.children {
    match node {
      Element(element) => @oxml.write_xml_element(writer, ctx, element)
      Text(text) => writer.text(text)
      CData(text) => writer.cdata(text)
    }
  }
  writer.end_element()
  @utf8.encode(writer.to_string()).to_fixedarray()
}

///|
/// Read package data once. The same font-embedding exporter defect as the
/// unqualified relationships also occurs on its fntdata content-type entry.
/// Normalization is confined to that entry, in memory, before strict parsing.
fn open_package(bytes : Bytes) -> @opc.Package raise {
  let archive = @zip.read(bytes)
  guard archive.get("[Content_Types].xml") is Some(source) else {
    raise InvalidPresentation("missing [Content_Types].xml")
  }
  let source = source.to_owned().to_fixedarray()
  let types = @opc.ContentTypes::parse(source) catch {
    MalformedPackage(_) as original => {
      let root = parse_root(source)
      let content_types_ns = "http://schemas.openxmlformats.org/package/2006/content-types"
      guard root.name.uri == content_types_ns && root.name.local_name == "Types" else {
        raise original
      }
      let mut changed = false
      let children : Array[@xml.XmlNode] = []
      for node in root.children {
        match node {
          Element(element) if element.name.uri == "" &&
            element.name.local_name == "Default" &&
            attribute(element, "Extension") == Some("fntdata") &&
            attribute(element, "ContentType") == Some("application/x-fontdata") => {
            changed = true
            children.push(
              Element({
                ..element,
                name: @xml.QName::new(content_types_ns, "Default"),
              }),
            )
          }
          _ => children.push(node)
        }
      }
      guard changed else { raise original }
      @opc.ContentTypes::parse(xml_bytes({ ..root, children, }))
    }
    error => raise error
  }
  let pkg = @opc.Package::new()
  pkg.set_content_types(types)
  for entry in archive.entries() {
    if entry.name().has_suffix("/") {
      continue
    }
    let name = "/" + entry.name()
    pkg.add_part(
      @opc.Part::new(
        name,
        types.resolve(name).unwrap_or(""),
        entry.data().to_owned().to_fixedarray(),
      ),
    )
  }
  pkg
}
