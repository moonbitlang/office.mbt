///|
/// A source or rendering failure with the missing feature named explicitly.
pub suberror RenderError {
  InvalidPresentation(String)
  Unsupported(String)
  MissingFont(String)
}

///|
pub extend RenderError with Show::{to_string, output}

///|
pub impl Show for RenderError with fn output(self, logger) {
  match self {
    InvalidPresentation(message) =>
      logger.write_string("invalid PPTX: " + message)
    Unsupported(message) =>
      logger.write_string("unsupported PPTX rendering: " + message)
    MissingFont(message) =>
      logger.write_string("PPTX font unavailable: " + message)
  }
}

///|
/// Page geometry and fonts always travel together: drawing must use the same
/// catalog that measured the glyphs, including the presentation's embedded faces.
pub struct PresentationLayout {
  model : @pagelayout.PageModel
  fonts : @fonts.FontRegistry
  slide_parts : Array[String]
  font_substitutions : Array[String]
}

///|
priv struct SlideContext {
  pkg : @opc.Package
  part : String
  fonts : @fonts.FontRegistry
  theme : @theme.Theme?
  mapping : @slide_master.ColorMapping?
  model : @pagelayout.PageModel
  font_fallbacks : Map[String, Array[String]]
  kinsoku : KinsokuSettings?
  allow_bundled_fallbacks : Bool
  font_substitutions : Map[String, Unit]
}

///|
priv struct KinsokuSettings {
  language : String
  no_start : String
  no_end : String
}

///|
fn related(
  pkg : @opc.Package,
  source : String,
  rel_type : String,
) -> String? raise {
  let rels = relationships(pkg, source).by_type(rel_type)
  guard rels.length() <= 1 else {
    raise InvalidPresentation("ambiguous relationship \{rel_type} in \{source}")
  }
  rels
  .get(0)
  .bind(rel => {
    if rel.target_mode == Internal {
      Some(@opc.resolve_target(source, rel.target, Internal))
    } else {
      None
    }
  })
}

///|
fn element_children(element : @xml.XmlElement) -> Array[@xml.XmlElement] {
  element.children.filter_map(node => {
    match node {
      Element(child) => Some(child)
      _ => None
    }
  })
}

///|
fn child(element : @xml.XmlElement, local_name : String) -> @xml.XmlElement? {
  element_children(element)
  .iter()
  .find_first(e => e.name.local_name == local_name)
}

///|
fn attribute(element : @xml.XmlElement, name : String) -> String? {
  element.attributes
  .iter()
  .filter_map(pair => {
    if pair.0.local_name == name {
      Some(pair.1)
    } else {
      None
    }
  })
  .next()
}

///|
fn parse_root(bytes : FixedArray[Byte]) -> @xml.XmlElement raise {
  let reader = @xml.XmlReader::new(
    @xml.decode_xml_bytes(Bytes::from_array(bytes)),
  )
  while reader.next() is Some(event) {
    if event is StartElement(name, attributes) {
      return @oxml.collect_subtree(reader, name, attributes)
    }
  }
  raise InvalidPresentation("missing XML root")
}

///|
fn emu(value : @units.Emu) -> Double {
  value.to_pt().value()
}

///|
/// Lay out every slide in presentation order. Source files are never modified.
/// Caller faces take precedence over embedded faces; absent faces fail explicitly
/// instead of silently changing the presentation's typography.
/// `font_fallbacks` supplies ordered, explicit substitutions for missing families
/// or glyphs. Use the returned catalog with `@svg.render_pages` so that the same
/// TrueType or CFF programs are measured and embedded in the output.
pub fn layout_presentation(
  bytes : Bytes,
  fonts? : @fonts.FontRegistry,
  font_fallbacks~ : Map[String, Array[String]] = {},
  allow_bundled_fallbacks~ : Bool = false,
) -> PresentationLayout raise {
  let pkg = open_package(bytes)
  guard related(pkg, @opc.package_root, @opc.rt_office_document) is Some(main) else {
    raise InvalidPresentation("missing office-document relationship")
  }
  let root = parse_root(pkg.require_part(main).bytes())
  guard root.name.uri == @oxml.presentation_ns &&
    root.name.local_name == "presentation" else {
    raise InvalidPresentation("office-document part is not a presentation")
  }
  let fonts = fonts.unwrap_or(@fonts.FontRegistry::new()).clone()
  register_embedded_fonts(pkg, main, root, fonts)
  let model = @pagelayout.PageModel::new()
  let font_substitutions : Map[String, Unit] = Map([])
  let kinsoku = match child(root, "kinsoku") {
    Some(settings) => {
      guard attribute(settings, "lang") is Some(language) &&
        attribute(settings, "invalStChars") is Some(no_start) &&
        attribute(settings, "invalEndChars") is Some(no_end) else {
        raise InvalidPresentation("incomplete presentation kinsoku settings")
      }
      Some(KinsokuSettings::{ language: language.to_lower(), no_start, no_end, })
    }
    None => None
  }
  let parts : Array[String] = []
  let rels = relationships(pkg, main)
  let ids = child(root, "sldIdLst").map(element_children).unwrap_or([])
  guard child(root, "sldSz") is Some(dimensions) else {
    raise InvalidPresentation("missing slide dimensions")
  }
  let width = @string.parse_int64(attribute(dimensions, "cx").unwrap_or("0")).to_double() /
    12700.0
  let height = @string.parse_int64(attribute(dimensions, "cy").unwrap_or("0")).to_double() /
    12700.0
  guard width > 0 && height > 0 else {
    raise InvalidPresentation("invalid slide dimensions")
  }
  for id in ids {
    let r_id = attribute(id, "id").unwrap_or("")
    // sldId has both an unqualified numeric id and a relationship-qualified id.
    let r_id = id.attributes
      .iter()
      .filter_map(pair => {
        if pair.0.local_name == "id" &&
          pair.0.uri == @oxml.office_relationships_ns {
          Some(pair.1)
        } else {
          None
        }
      })
      .next()
      .unwrap_or(r_id)
    guard rels.by_id(r_id) is Some(rel) &&
      rel.rel_type == @opc.rt_slide &&
      rel.target_mode == Internal else {
      raise InvalidPresentation("missing slide relationship \{r_id}")
    }
    let part = @opc.resolve_target(main, rel.target, Internal)
    let slide_root = parse_root(pkg.require_part(part).bytes())
    let layout_part = related(pkg, part, @opc.rt_slide_layout)
    let master_part = match layout_part {
      Some(layout) => related(pkg, layout, @opc.rt_slide_master)
      None => None
    }
    let theme_part = match master_part {
      Some(master) => related(pkg, master, @opc.rt_theme)
      None => related(pkg, main, @opc.rt_theme)
    }
    let theme = match theme_part {
      Some(part) => Some(@theme.Theme::parse(pkg.require_part(part).bytes()))
      None => None
    }
    let mapping = match master_part {
      Some(part) =>
        Some(
          @slide_master.SlideMaster::parse(pkg.require_part(part).bytes()).color_mapping,
        )
      None => None
    }
    let layout_root = match layout_part {
      Some(part) => Some(parse_root(pkg.require_part(part).bytes()))
      None => None
    }
    let master_root = match master_part {
      Some(part) => Some(parse_root(pkg.require_part(part).bytes()))
      None => None
    }
    let slide = resolved_slide(
      slide_root,
      layout_root,
      master_root,
      child(root, "defaultTextStyle"),
    )
    let layout = match layout_root {
      Some(root) => Some(resolved_slide(root, None, master_root, None))
      None => None
    }
    let master = match master_root {
      Some(root) => Some(resolved_slide(root, None, None, None))
      None => None
    }
    let mapping = match slide.clr_map_override {
      Override(mapping) => Some(mapping)
      MasterMapping =>
        match layout.map(layout => layout.clr_map_override) {
          Some(Override(mapping)) => Some(mapping)
          _ => mapping
        }
    }
    let context = SlideContext::{
      pkg,
      part,
      fonts,
      theme,
      mapping,
      model,
      font_fallbacks,
      kinsoku,
      allow_bundled_fallbacks,
      font_substitutions,
    }
    let ops : Array[@pagelayout.GraphicOp] = []
    let background = match slide.background {
      Some(background) => Some(background)
      None =>
        match layout.bind(layout => layout.background) {
          Some(background) => Some(background)
          None => master.bind(master => master.background)
        }
    }
    if background is Some(background) {
      draw_background(context, background, width, height, ops)
    }
    if attribute(slide_root, "showMasterSp") != Some("0") &&
      attribute(slide_root, "showMasterSp") != Some("false") &&
      layout_root.bind(root => attribute(root, "showMasterSp")) != Some("0") &&
      layout_root.bind(root => attribute(root, "showMasterSp")) != Some("false") &&
      master is Some(master) &&
      master_part is Some(part) {
      for shape in master.shapes {
        if !is_placeholder(shape) {
          draw_shape({ ..context, part, }, shape, ops)
        }
      }
    }
    if layout is Some(layout) && layout_part is Some(part) {
      for shape in layout.shapes {
        if !is_placeholder(shape) {
          draw_shape({ ..context, part, }, shape, ops)
        }
      }
    }
    for shape in slide.shapes {
      draw_shape(context, shape, ops)
    }
    model.pages.push({
      width_pt: width,
      height_pt: height,
      items: [Graphic({ x_pt: 0, y_pt: 0, ops, })],
    })
    parts.push(part)
  }
  let substitutions = font_substitutions.keys().to_array()
  substitutions.sort()
  { model, fonts, slide_parts: parts, font_substitutions: substitutions, }
}

///|
fn is_placeholder(shape : @slide.Shape) -> Bool {
  match shape {
    AutoShape(shape) => shape.placeholder is Some(_)
    _ => false
  }
}
