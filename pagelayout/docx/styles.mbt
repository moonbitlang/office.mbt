///|
// The style cascade. OOXML resolves formatting as
//   docDefaults → default style for the type → basedOn chain (root first)
//   → the style itself → direct formatting on the element
// and this package is the only place in the repo that implements it —
// docx2html keeps style ids and display names but no formatting.

///|
/// One style's own formatting plus its `basedOn` parent, if any.
struct StyleEntry {
  based_on : String?
  run : RunProps
  para : ParaProps
}

///|
/// Parsed `word/styles.xml`: the document defaults plus one entry per
/// paragraph/character style, keyed by style id.
pub struct StyleSheet {
  default_run : RunProps
  default_para : ParaProps
  paragraph_styles : Map[String, StyleEntry]
  character_styles : Map[String, StyleEntry]
  table_styles : Map[String, StyleEntry]
  default_paragraph_style : String?
}

///|
/// An empty sheet: every document has one even when styles.xml is absent.
pub fn StyleSheet::empty() -> StyleSheet {
  {
    default_run: RunProps::empty(),
    default_para: ParaProps::empty(),
    paragraph_styles: Map([]),
    table_styles: Map([]),
    character_styles: Map([]),
    default_paragraph_style: None,
  }
}

///|
fn read_style_entry(style : @xml.XmlElement, theme : ThemeFonts) -> StyleEntry {
  let based_on = match style.first("w:basedOn") {
    Some(el) => el.attributes.get("w:val")
    None => None
  }
  let run = match style.first("w:rPr") {
    Some(rpr) => read_run_props(rpr, theme~)
    None => RunProps::empty()
  }
  let para = match style.first("w:pPr") {
    Some(ppr) => {
      let (props, _) = read_para_props(ppr)
      props
    }
    None => ParaProps::empty()
  }
  { based_on, run, para }
}

///|
/// Parse a `w:styles` root element.
pub fn read_stylesheet(
  root : @xml.XmlElement,
  theme? : ThemeFonts = ThemeFonts::empty(),
) -> StyleSheet {
  let sheet = StyleSheet::empty()
  let mut default_run = RunProps::empty()
  let mut default_para = ParaProps::empty()
  match root.first("w:docDefaults") {
    Some(defaults) => {
      match defaults.first("w:rPrDefault") {
        Some(d) =>
          match d.first("w:rPr") {
            Some(rpr) => default_run = read_run_props(rpr, theme~)
            None => ()
          }
        None => ()
      }
      match defaults.first("w:pPrDefault") {
        Some(d) =>
          match d.first("w:pPr") {
            Some(ppr) => {
              let (props, _) = read_para_props(ppr)
              default_para = props
            }
            None => ()
          }
        None => ()
      }
    }
    None => ()
  }
  let mut default_paragraph_style : String? = None
  for style in root.elements_by_tag_name("w:style") {
    let id = match style.attributes.get("w:styleId") {
      Some(v) => v
      None => continue
    }
    let kind = style.attributes.get("w:type").unwrap_or("paragraph")
    let entry = read_style_entry(style, theme)
    match kind {
      "paragraph" => {
        if !sheet.paragraph_styles.contains(id) {
          sheet.paragraph_styles[id] = entry
        }
        if style.attributes.get("w:default") is Some(flag) &&
          flag != "0" &&
          flag != "false" &&
          default_paragraph_style is None {
          default_paragraph_style = Some(id)
        }
      }
      "character" =>
        if !sheet.character_styles.contains(id) {
          sheet.character_styles[id] = entry
        }
      "table" =>
        if !sheet.table_styles.contains(id) {
          sheet.table_styles[id] = entry
        }
      _ => ()
    }
  }
  { ..sheet, default_run, default_para, default_paragraph_style }
}

///|
/// A sheet whose cascade base carries a table style's formatting.
///
/// OOXML places a table's style between the document defaults and the
/// paragraph/character styles of the text inside its cells. Rather than
/// threading a table-style parameter through every resolver, the style's
/// run and paragraph chains are merged onto `default_run` and
/// `default_para` — the bases every cascade starts from — so cell
/// content resolved against the returned sheet gets that ordering, and
/// paragraph, character and direct formatting still override it.
///
/// Two limits, one scoped and one shared with the whole cascade:
/// conditional formats (`w:tblStylePr` for first rows and the like) are
/// not consulted — this is the whole-table formatting only — and toggle
/// properties merge last-wins rather than by ECMA-376 §17.7.3's XOR,
/// like every other layer (see the known-gaps note in read.mbt).
///
/// An unknown or absent id returns the sheet unchanged.
pub fn StyleSheet::for_table(
  self : StyleSheet,
  style_id : String?,
) -> StyleSheet {
  guard style_id is Some(id) else { return self }
  guard self.table_styles.contains(id) else { return self }
  let mut run_base = self.default_run
  let mut para_base = self.default_para
  for name in chain(self.table_styles, id) {
    guard! self.table_styles.get(name) is Some(entry)
    run_base = run_base.merge(entry.run)
    para_base = para_base.merge(entry.para)
  }
  { ..self, default_run: run_base, default_para: para_base }
}

///|
/// Walk a `basedOn` chain from `id` to its root, returning the ids from
/// root to leaf. Cycles are cut where they close, so a malformed
/// styles.xml cannot hang the frontend.
fn chain(styles : Map[String, StyleEntry], id : String) -> Array[String] {
  let seen : Map[String, Unit] = Map([])
  let reversed : Array[String] = []
  let mut current = Some(id)
  while current is Some(name) {
    if seen.contains(name) {
      break
    }
    guard styles.get(name) is Some(entry) else { break }
    seen[name] = ()
    reversed.push(name)
    current = entry.based_on
  }
  let ordered : Array[String] = []
  for i in 0..<reversed.length() {
    ordered.push(reversed[reversed.length() - 1 - i])
  }
  ordered
}

///|
/// Character formatting for a run: docDefaults → the paragraph style's
/// run formatting → the character style chain → direct `w:rPr`.
pub fn StyleSheet::resolve_run(
  self : StyleSheet,
  para_style_id : String?,
  char_style_id : String?,
  direct : RunProps,
) -> RunProps {
  let mut props = self.default_run
  // a w:pStyle naming a style that styles.xml does not define must not
  // suppress the document default
  let para_id = match para_style_id {
    Some(id) if self.paragraph_styles.contains(id) => Some(id)
    _ => self.default_paragraph_style
  }
  match para_id {
    Some(id) =>
      for name in chain(self.paragraph_styles, id) {
        guard! self.paragraph_styles.get(name) is Some(entry)
        props = props.merge(entry.run)
      }
    None => ()
  }
  match char_style_id {
    Some(id) =>
      for name in chain(self.character_styles, id) {
        guard! self.character_styles.get(name) is Some(entry)
        props = props.merge(entry.run)
      }
    None => ()
  }
  props.merge(direct)
}

///|
/// Paragraph formatting: docDefaults → the style chain → direct `w:pPr`.
pub fn StyleSheet::resolve_para(
  self : StyleSheet,
  style_id : String?,
  direct : ParaProps,
) -> ParaProps {
  let mut props = self.default_para
  let id = match style_id {
    Some(v) if self.paragraph_styles.contains(v) => Some(v)
    _ => self.default_paragraph_style
  }
  match id {
    Some(name) =>
      for entry_id in chain(self.paragraph_styles, name) {
        guard! self.paragraph_styles.get(entry_id) is Some(entry)
        props = props.merge(entry.para)
      }
    None => ()
  }
  props.merge(direct)
}
