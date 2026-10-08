///|
priv struct RunColors {
  theme : Map[String, String]
  styles : Map[String, (String?, Map[String, String])]
  default_styles : Map[String, String]
  resolved_styles : Map[String, Map[String, String?]]
  defaults : Map[String, String]
}

///|
fn RunColors::empty() -> RunColors {
  {
    theme: Map([]),
    styles: Map([]),
    default_styles: Map([]),
    resolved_styles: Map([]),
    defaults: Map([]),
  }
}

///|
fn color_hex(value : String) -> String? {
  if value.length() == 6 &&
    value
    .iter()
    .all(c => {
      (c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F')
    }) {
    Some(value.to_upper())
  } else {
    None
  }
}

///|
fn color_byte(value : String) -> Int? {
  if value.length() != 2 {
    return None
  }
  let mut result = 0
  for c in value.to_upper() {
    let digit = if c >= '0' && c <= '9' {
      c.to_int() - 48
    } else if c >= 'A' && c <= 'F' {
      c.to_int() - 55
    } else {
      return None
    }
    result = result * 16 + digit
  }
  Some(result)
}

///|
// Word changes HSL luminance; tint wins over shade when both are present.
// https://learn.microsoft.com/en-us/openspecs/office_standards/ms-oi29500/8229a077-7fc8-4fba-96cc-c77b6a4fc768
fn transform_theme_color(
  rgb : String,
  tint : String?,
  shade : String?,
) -> String {
  let amount = prefer_color(tint, shade)
  guard amount is Some(amount) && color_byte(amount) is Some(byte) else {
    return rgb
  }
  if byte == 255 {
    return rgb
  }
  let channels = [
    color_byte(rgb[0:2].to_owned()).unwrap().to_double() / 255.0,
    color_byte(rgb[2:4].to_owned()).unwrap().to_double() / 255.0,
    color_byte(rgb[4:6].to_owned()).unwrap().to_double() / 255.0,
  ]
  let high = channels[0].max(channels[1]).max(channels[2])
  let low = channels[0].min(channels[1]).min(channels[2])
  let light = (high + low) / 2.0
  let factor = byte.to_double() / 255.0
  let new_light = if tint is Some(_) {
    1.0 - (1.0 - light) * factor
  } else {
    light * factor
  }
  let old_range = if light <= 0.5 { light * 2.0 } else { (1.0 - light) * 2.0 }
  let new_range = if new_light <= 0.5 {
    new_light * 2.0
  } else {
    (1.0 - new_light) * 2.0
  }
  let scale = if old_range == 0.0 { 0.0 } else { new_range / old_range }
  let hex = "0123456789ABCDEF"
  let out = StringBuilder()
  for channel in channels {
    let n = (((channel - light) * scale + new_light) * 255.0 + 0.000000001)
      .to_int()
      .max(0)
      .min(255)
    out.write_char(hex[n / 16].to_int().unsafe_to_char())
    out.write_char(hex[n % 16].to_int().unsafe_to_char())
  }
  out.to_string()
}

///|
fn RunColors::resolve(
  self : RunColors,
  value : String?,
  theme : String?,
  tint : String?,
  shade : String?,
) -> String? {
  if theme is Some(name) && self.theme.get(name) is Some(rgb) {
    return Some(transform_theme_color(rgb, tint, shade))
  }
  match value {
    Some("auto") => Some("auto")
    Some(value) => color_hex(value)
    None => None
  }
}

///|
fn RunColors::read_node_color(self : RunColors, node : ReaderNode) -> String? {
  self.resolve(
    node.attribute("w:val"),
    node.attribute("w:themeColor"),
    node.attribute("w:themeTint"),
    node.attribute("w:themeShade"),
  )
}

///|
fn RunColors::read_color(self : RunColors, node : XmlElement) -> String? {
  self.resolve(
    node.attributes.get("w:val"),
    node.attributes.get("w:themeColor"),
    node.attributes.get("w:themeTint"),
    node.attributes.get("w:themeShade"),
  )
}

///|
fn RunColors::style_color(
  self : RunColors,
  kind : String,
  id : String?,
) -> String? {
  self.style_value(kind, id, "color")
}

///|
// Resolve each property independently: an absent value continues through basedOn.
fn RunColors::style_value(
  self : RunColors,
  kind : String,
  id : String?,
  property : String,
) -> String? {
  let cache = self.resolved_styles.get_or_default(property, Map([]))
  self.resolved_styles[property] = cache
  let mut current = prefer_color(id, self.default_styles.get(kind))
  let seen : Map[String, Bool] = Map([])
  let mut result : String? = None
  while current is Some(id) {
    let key = style_lookup_key(kind, id)
    if cache.get(key) is Some(cached) {
      result = cached
      break
    }
    if seen.contains(key) {
      break
    }
    seen[key] = true
    match self.styles.get(key) {
      Some((parent, values)) => {
        let value = values.get(property)
        if value is Some(_) {
          result = value
          break
        }
        current = parent
      }
      None => break
    }
  }
  for key, _ in seen {
    cache[key] = result
  }
  result
}

///|
fn read_run_colors(
  zip : ZipArchive,
  relationships : Relationships,
  base_path : String,
  styles_root : XmlElement?,
  xml_budget? : @xml.XmlReadBudget,
) -> RunColors raise DocxError {
  let theme_path = resolve_unique_internal_part(
    zip,
    relationships,
    [
      "http://schemas.openxmlformats.org/officeDocument/2006/relationships/theme",
      "http://purl.oclc.org/ooxml/officeDocument/relationships/theme",
    ],
    base_path,
    "theme",
    reject_multiple_relationships=true,
  )
  let colors = RunColors::empty()
  if theme_path is Some(path) {
    let root = read_xml_part(zip, path, xml_budget?)
    let scheme = root
      .first_or_empty("a:themeElements")
      .first_or_empty("a:clrScheme")
    for
      (name, tag) in [
        ("dark1", "dk1"),
        ("light1", "lt1"),
        ("dark2", "dk2"),
        ("light2", "lt2"),
        ("accent1", "accent1"),
        ("accent2", "accent2"),
        ("accent3", "accent3"),
        ("accent4", "accent4"),
        ("accent5", "accent5"),
        ("accent6", "accent6"),
        ("hyperlink", "hlink"),
        ("followedHyperlink", "folHlink"),
      ] {
      let entry = scheme.first_or_empty("a:" + tag)
      let value = prefer_color(
        entry.first_or_empty("a:srgbClr").attributes.get("val"),
        entry.first_or_empty("a:sysClr").attributes.get("lastClr"),
      )
      if value is Some(value) && color_hex(value) is Some(rgb) {
        colors.theme[name] = rgb
      }
    }
  }
  for
    (slot, name) in [
      ("text1", "dark1"),
      ("background1", "light1"),
      ("text2", "dark2"),
      ("background2", "light2"),
    ] {
    if colors.theme.get(name) is Some(value) {
      colors.theme[slot] = value
    }
  }
  let settings_path = resolve_unique_internal_part(
    zip,
    relationships,
    [
      "http://schemas.openxmlformats.org/officeDocument/2006/relationships/settings",
      "http://purl.oclc.org/ooxml/officeDocument/relationships/settings",
    ],
    base_path,
    "settings",
    reject_multiple_relationships=true,
  )
  if settings_path is Some(path) {
    let mapping = read_xml_part(zip, path, xml_budget?).first_or_empty(
      "w:clrSchemeMapping",
    )
    let palette = colors.theme.copy()
    for
      (slot, attribute) in [
        ("text1", "t1"),
        ("background1", "bg1"),
        ("text2", "t2"),
        ("background2", "bg2"),
        ("accent1", "accent1"),
        ("accent2", "accent2"),
        ("accent3", "accent3"),
        ("accent4", "accent4"),
        ("accent5", "accent5"),
        ("accent6", "accent6"),
        ("hyperlink", "hyperlink"),
        ("followedHyperlink", "followedHyperlink"),
      ] {
      if mapping.attributes.get("w:" + attribute) is Some(name) &&
        palette.get(name) is Some(value) {
        colors.theme[slot] = value
      }
    }
  }
  guard styles_root is Some(root) else { return colors }
  for style in root.elements_by_tag_name("w:style") {
    let kind = style.attributes.get_or_default("w:type", "")
    let id = style.attributes.get_or_default("w:styleId", "")
    let key = style_lookup_key(kind, id)
    if id != "" && !colors.styles.contains(key) {
      colors.styles[key] = (
        style.first_or_empty("w:basedOn").attributes.get("w:val"),
        colors.read_style_values(style.first_or_empty("w:rPr")),
      )
      if style.attributes.get("w:default") is Some("1" | "true" | "on") &&
        !colors.default_styles.contains(kind) {
        colors.default_styles[kind] = id
      }
    }
  }
  {
    ..colors,
    defaults: colors.read_style_values(
      root
      .first_or_empty("w:docDefaults")
      .first_or_empty("w:rPrDefault")
      .first_or_empty("w:rPr"),
    ),
  }
}

///|
fn prefer_color(first : String?, fallback : String?) -> String? {
  match first {
    Some(_) => first
    None => fallback
  }
}

///|
fn RunColors::read_style_values(
  self : RunColors,
  rpr : XmlElement,
) -> Map[String, String] {
  let values : Map[String, String] = Map([])
  if self.read_color(rpr.first_or_empty("w:color")) is Some(color) {
    values["color"] = color
  }
  if read_highlight(rpr.first_or_empty("w:highlight").attributes.get("w:val"))
    is Some(highlight) {
    values["highlight"] = highlight
  }
  for property in ["sz", "szCs"] {
    let raw = rpr.first_or_empty("w:" + property).attributes.get("w:val")
    if read_font_size(raw) is Some(_) && raw is Some(value) {
      values[property] = value
    }
  }
  values
}
