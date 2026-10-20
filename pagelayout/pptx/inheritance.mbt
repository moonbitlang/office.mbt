///|
/// Merge property elements without changing either source tree. Fill choices
/// replace one another, while attributes (including explicit false/zero) win
/// individually. Repeated paragraphs and runs are never merged.
fn merge_properties(
  base : @xml.XmlElement?,
  own : @xml.XmlElement,
) -> @xml.XmlElement {
  guard base is Some(base) else { return own }
  let attributes = base.attributes.filter(pair => {
    !own.attributes.iter().any(other => other.0 == pair.0)
  })
  attributes.append(own.attributes)
  fn key(element : @xml.XmlElement) -> String {
    let property_name = match element.name.local_name {
      "noFill"
      | "solidFill"
      | "gradFill"
      | "pattFill"
      | "blipFill"
      | "grpFill" => "fill-choice"
      "buNone" | "buChar" | "buAutoNum" | "buBlip" => "bullet-choice"
      _ => element.name.local_name
    }
    element.name.uri + "|" + property_name
  }
  let children = base.children.filter(node => {
    match node {
      Element(element) =>
        !element_children(own).iter().any(other => key(other) == key(element))
      _ => false
    }
  })
  for node in own.children {
    match node {
      Element(element) if element.name.local_name == "defRPr" ||
        element.name.local_name == "xfrm" =>
        children.push(
          Element(
            merge_properties(child(base, element.name.local_name), element),
          ),
        )
      _ => children.push(node)
    }
  }
  { ..own, attributes, children, }
}

///|
fn raw_shapes(root : @xml.XmlElement) -> Array[@xml.XmlElement] {
  child(root, "cSld")
  .bind(common => child(common, "spTree"))
  .map(element_children)
  .unwrap_or([])
}

///|
fn raw_placeholder(shape : @xml.XmlElement) -> @xml.XmlElement? {
  element_children(shape)
  .iter()
  .filter_map(nonvisual => {
    child(nonvisual, "nvPr").bind(properties => child(properties, "ph"))
  })
  .next()
}

///|
fn parent_placeholder(
  root : @xml.XmlElement?,
  shape : @xml.XmlElement,
  master~ : Bool,
) -> @xml.XmlElement? {
  guard root is Some(root) && raw_placeholder(shape) is Some(placeholder) else {
    return None
  }
  let candidates = raw_shapes(root)
  if !master {
    let index = attribute(placeholder, "idx").unwrap_or("0")
    return candidates
      .iter()
      .find_first(candidate => {
        raw_placeholder(candidate)
        .map(other => attribute(other, "idx").unwrap_or("0") == index)
        .unwrap_or(false)
      })
  }
  let kind = attribute(placeholder, "type").unwrap_or("body")
  candidates
  .iter()
  .find_first(candidate => {
    raw_placeholder(candidate)
    .map(other => attribute(other, "type").unwrap_or("body") == kind)
    .unwrap_or(false)
  })
}

///|
fn paragraph_defaults(
  styles : Array[@xml.XmlElement],
  level : Int32,
) -> @xml.XmlElement? {
  let mut result = None
  for style in styles {
    if child(style, "defPPr") is Some(properties) {
      result = Some(merge_properties(result, properties))
    }
    if child(style, "lvl\{level + 1}pPr") is Some(properties) {
      result = Some(merge_properties(result, properties))
    }
  }
  result
}

///|
fn resolved_body(
  body : @xml.XmlElement,
  parents : Array[@xml.XmlElement],
  styles : Array[@xml.XmlElement],
) -> @xml.XmlElement raise {
  let mut body_properties = None
  let styles = styles.copy()
  for parent in parents {
    if child(parent, "bodyPr") is Some(properties) {
      body_properties = Some(merge_properties(body_properties, properties))
    }
    if child(parent, "lstStyle") is Some(style) {
      styles.push(style)
    }
  }
  if child(body, "lstStyle") is Some(style) {
    styles.push(style)
  }
  let children : Array[@xml.XmlNode] = []
  if child(body, "bodyPr") is None && body_properties is Some(properties) {
    children.push(Element(properties))
  }
  for node in body.children {
    guard node is Element(element) else {
      children.push(node)
      continue
    }
    if element.name.local_name == "bodyPr" {
      children.push(Element(merge_properties(body_properties, element)))
    } else if element.name.local_name == "p" {
      let own = child(element, "pPr")
      let level = own
        .bind(properties => attribute(properties, "lvl"))
        .map(value => @string.parse_int(value))
        .unwrap_or(0)
      guard level >= 0 && level <= 8 else {
        raise InvalidPresentation("paragraph level outside 0–8")
      }
      let inherited = paragraph_defaults(styles, level)
      let properties = match own {
        Some(properties) => Some(merge_properties(inherited, properties))
        None => inherited
      }
      let run_defaults = properties.bind(properties => {
        child(properties, "defRPr")
      })
      let content : Array[@xml.XmlNode] = []
      if properties is Some(properties) {
        content.push(
          Element({
            ..properties,
            name: @xml.QName::new(@oxml.drawing_ns, "pPr"),
          }),
        )
      }
      for node in element.children {
        match node {
          Element(run) if run.name.local_name == "r" ||
            run.name.local_name == "fld" ||
            run.name.local_name == "br" => {
            let own = child(run, "rPr")
            let resolved = match own {
              Some(own) => Some(merge_properties(run_defaults, own))
              None =>
                run_defaults.map(defaults => {
                  ..defaults,
                  name: @xml.QName::new(@oxml.drawing_ns, "rPr"),
                })
            }
            let run_children = run.children.filter(node => {
              match node {
                Element(properties) => properties.name.local_name != "rPr"
                _ => true
              }
            })
            if resolved is Some(properties) {
              run_children.insert(0, Element(properties))
            }
            content.push(Element({ ..run, children: run_children, }))
          }
          Element(properties) if properties.name.local_name == "endParaRPr" =>
            content.push(Element(merge_properties(run_defaults, properties)))
          Element(properties) if properties.name.local_name == "pPr" => ()
          _ => content.push(node)
        }
      }
      if child(element, "endParaRPr") is None && run_defaults is Some(defaults) {
        content.push(
          Element({
            ..defaults,
            name: @xml.QName::new(@oxml.drawing_ns, "endParaRPr"),
          }),
        )
      }
      children.push(Element({ ..element, children: content, }))
    } else {
      children.push(node)
    }
  }
  { ..body, children, }
}

///|
fn resolved_shape(
  shape : @xml.XmlElement,
  layout : @xml.XmlElement?,
  master : @xml.XmlElement?,
  defaults : @xml.XmlElement?,
) -> @xml.XmlElement raise {
  let layout_shape = parent_placeholder(layout, shape, master=false)
  let master_shape = parent_placeholder(
    master,
    layout_shape.unwrap_or(shape),
    master=true,
  )
  let parents = [master_shape, layout_shape].filter_map(value => value)
  let styles : Array[@xml.XmlElement] = []
  if defaults is Some(style) {
    styles.push(style)
  }
  let own_kind = raw_placeholder(shape).bind(placeholder => {
    attribute(placeholder, "type")
  })
  let kind = match own_kind {
    Some(kind) => kind
    None =>
      match
        layout_shape
        .bind(raw_placeholder)
        .bind(placeholder => attribute(placeholder, "type")) {
        Some(kind) => kind
        None =>
          master_shape
          .bind(raw_placeholder)
          .bind(placeholder => attribute(placeholder, "type"))
          .unwrap_or("")
      }
  }
  let style_name = match kind {
    "title" | "ctrTitle" => "titleStyle"
    "body" | "obj" | "subTitle" => "bodyStyle"
    _ => "otherStyle"
  }
  if master
    .bind(root => child(root, "txStyles"))
    .bind(styles => child(styles, style_name))
    is Some(style) {
    styles.push(style)
  }
  let mut shape_properties = None
  for parent in parents {
    if child(parent, "spPr") is Some(properties) {
      shape_properties = Some(merge_properties(shape_properties, properties))
    }
  }
  let children : Array[@xml.XmlNode] = []
  for node in shape.children {
    match node {
      Element(element) if element.name.local_name == "spPr" => {
        children.push(Element(merge_properties(shape_properties, element)))
        shape_properties = None
      }
      Element(element) if element.name.local_name == "txBody" =>
        children.push(
          Element(
            resolved_body(
              element,
              parents.filter_map(parent => child(parent, "txBody")),
              styles,
            ),
          ),
        )
      Element(element) if element.name.local_name == "grpSp" ||
        element.name.local_name == "sp" =>
        children.push(Element(resolved_shape(element, None, master, defaults)))
      _ => children.push(node)
    }
  }
  if shape_properties is Some(properties) {
    children.push(Element(properties))
  }
  { ..shape, children, }
}

///|
fn resolved_slide(
  root : @xml.XmlElement,
  layout : @xml.XmlElement?,
  master : @xml.XmlElement?,
  defaults : @xml.XmlElement?,
) -> @slide.Slide raise {
  let children : Array[@xml.XmlNode] = []
  for node in root.children {
    guard node is Element(common) && common.name.local_name == "cSld" else {
      children.push(node)
      continue
    }
    let common_children : Array[@xml.XmlNode] = []
    for node in common.children {
      guard node is Element(tree) && tree.name.local_name == "spTree" else {
        common_children.push(node)
        continue
      }
      let shapes : Array[@xml.XmlNode] = []
      for node in tree.children {
        match node {
          Element(shape) if shape.name.local_name == "sp" ||
            shape.name.local_name == "grpSp" =>
            shapes.push(
              Element(resolved_shape(shape, layout, master, defaults)),
            )
          _ => shapes.push(node)
        }
      }
      common_children.push(Element({ ..tree, children: shapes, }))
    }
    children.push(Element({ ..common, children: common_children, }))
  }
  @slide.Slide::parse_with_root(
    xml_bytes({ ..root, children, }),
    root.name.local_name,
  )
}
