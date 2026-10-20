///|
fn draw_background(
  context : SlideContext,
  background : @slide.Background,
  width : Double,
  height : Double,
  ops : Array[@pagelayout.GraphicOp],
) -> Unit raise {
  match background {
    Properties(properties) => {
      if properties.effects is Some(effects) &&
        effects != @oxml.EffectList::empty() {
        raise Unsupported("background effects in \{context.part}")
      }
      if properties.fill is Some(fill) {
        paint_rectangle(context, ops, 0, 0, width, height, fill, None)
      }
    }
    StyleReference(index, placeholder) => {
      guard context.theme is Some(theme) &&
        theme.extension
        .iter()
        .find_first(element => element.name.local_name == "fmtScheme")
        is Some(format) else {
        raise InvalidPresentation(
          "background style without a theme format scheme",
        )
      }
      let list_name = if index >= 1001 {
        "bgFillStyleLst"
      } else {
        "fillStyleLst"
      }
      let offset = if index >= 1001 { index - 1001 } else { index - 1 }
      guard child(format, list_name)
        .map(element_children)
        .bind(fills => fills.get(offset))
        is Some(fill) else {
        raise InvalidPresentation("background style index \{index} is missing")
      }
      let (resolved, alpha) = color(context, placeholder)
      fn substitute(element : @xml.XmlElement) -> @xml.XmlElement {
        if element.name.uri == @oxml.drawing_ns &&
          element.name.local_name == "schemeClr" &&
          attribute(element, "val") == Some("phClr") {
          let children = element.children.copy()
          children.insert(
            0,
            Element({
              name: @xml.QName::new(@oxml.drawing_ns, "alpha"),
              attributes: [
                (
                  @xml.QName::unqualified("val"),
                  (alpha * 100000.0).to_int().to_string(),
                ),
              ],
              children: [],
            }),
          )
          return {
            name: @xml.QName::new(@oxml.drawing_ns, "srgbClr"),
            attributes: [
              (@xml.QName::unqualified("val"), resolved.to_hex()[1:].to_owned()),
            ],
            children,
          }
        }
        {
          ..element,
          children: element.children.map(node => {
            match node {
              Element(element) => Element(substitute(element))
              _ => node
            }
          }),
        }
      }
      let reader = @xml.XmlReader::new(
        @xml.decode_xml_bytes(Bytes::from_array(xml_bytes(substitute(fill)))),
      )
      guard reader.next() is Some(StartElement(name, attributes)) else {
        raise InvalidPresentation("invalid theme fill")
      }
      let fill = @oxml.parse_fill(reader, name, attributes)
      paint_rectangle(context, ops, 0, 0, width, height, fill, None)
    }
  }
}
