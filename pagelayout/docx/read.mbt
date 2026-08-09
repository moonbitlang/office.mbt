///|
// The DOCX frontend: a .docx package in, engine blocks + section
// geometry out. Deliberately its own narrow parse rather than a reuse of
// docx2html's reader, whose semantic model drops the properties layout
// depends on (color, line spacing, space before/after, exact half-point
// sizes, and w:sectPr page geometry).

///|
/// OOXML namespace URIs normalized to the `w:`-prefixed names this
/// package matches on. Both transitional and strict WML are mapped.
fn namespace_map() -> Map[String, String] {
  {
    "http://schemas.openxmlformats.org/wordprocessingml/2006/main": "w",
    "http://purl.oclc.org/ooxml/wordprocessingml/main": "w",
    // the _rels parts use their own (default-prefixed) namespace
    "http://schemas.openxmlformats.org/package/2006/relationships": "rel",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships": "r",
    "http://purl.oclc.org/ooxml/officeDocument/relationships": "r",
    "http://schemas.openxmlformats.org/drawingml/2006/main": "a",
    "http://purl.oclc.org/ooxml/drawingml/main": "a",
    // inline/anchored drawings and the picture shape they wrap
    "http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing": "wp",
    "http://purl.oclc.org/ooxml/drawingml/wordprocessingDrawing": "wp",
    "http://schemas.openxmlformats.org/drawingml/2006/picture": "pic",
    "http://purl.oclc.org/ooxml/drawingml/picture": "pic",
    "http://purl.oclc.org/ooxml/drawingml/main": "a",
  }
}

///|
/// A document ready for the layout engine.
pub(all) struct DocxDocument {
  blocks : Array[@paginate.Block]
  section : @paginate.SectionProps
  /// Running header and footer, laid out on every page. Empty unless
  /// the package was read through `read_docx`, which can resolve the
  /// relationship ids in `furniture_refs` to actual parts.
  furniture : @paginate.PageFurniture
  /// The header/footer relationship ids the section named.
  furniture_refs : FurnitureRefs
  /// Block-level content this milestone does not lay out (tables,
  /// content controls), one entry per occurrence in document order.
  /// Non-empty means the render is incomplete — callers should say so
  /// rather than presenting the output as the whole document.
  unsupported : Array[String]
}

///|
/// Read `w:t`, `w:tab`, and `w:br` out of one `w:r`, honoring
/// `xml:space="preserve"`.
fn run_text(run : @xml.XmlElement) -> String {
  let sb = StringBuilder()
  for child in run.children {
    guard child is XmlElement(el) else { continue }
    match el.name {
      "w:t" =>
        for node in el.children {
          guard node is XmlText(text) else { continue }
          sb.write_string(text)
        }
      "w:tab" => sb.write_string("\t")
      "w:br" =>
        // textWrapping is the default and may also be written explicitly
        // (Word does so whenever w:clear is present); page and column
        // breaks are block level and handled by the paragraph walker
        match el.attributes.get("w:type") {
          None | Some("textWrapping") => sb.write_string("\n")
          Some(_) => ()
        }
      _ => ()
    }
  }
  sb.to_string()
}

///|
/// Elements that wrap runs without contributing formatting of their own:
/// tracked insertions, content controls, smart tags, and simple fields.
/// Their runs are part of the paragraph and must not be dropped.
fn is_run_container(name : String) -> Bool {
  name
  is ("w:ins"
  | "w:sdt"
  | "w:sdtContent"
  | "w:smartTag"
  | "w:fldSimple"
  | "w:hyperlink")
}

///|
/// Every `w:r` of a paragraph in document order, descending through
/// wrapper elements. `w:del` (tracked deletions) is skipped: its content
/// is not displayed.
fn collect_runs(
  el : @xml.XmlElement,
  out : Array[(@xml.XmlElement, String?)],
  simple_field? : String? = None,
) -> Unit {
  for child in el.children {
    guard child is XmlElement(node) else { continue }
    if node.name == "w:r" {
      out.push((node, simple_field))
    } else if node.name == "w:del" {
      continue
    } else if is_run_container(node.name) {
      // a w:fldSimple holds its whole field in one element, so its runs
      // inherit the instruction rather than tracking begin/separate/end
      let inherited = if node.name == "w:fldSimple" {
        match node.attributes.get("w:instr") {
          Some(instr) => Some(instr)
          None => simple_field
        }
      } else {
        simple_field
      }
      collect_runs(node, out, simple_field=inherited)
    }
  }
}

///|
/// Whether this paragraph ends with an explicit page break. Word's usual
/// idiom puts `<w:br w:type="page"/>` at the END of the paragraph that
/// finishes the page, so the break belongs AFTER this paragraph.
fn ends_with_page_break(runs : Array[(@xml.XmlElement, String?)]) -> Bool {
  for entry in runs {
    let (run, _) = entry
    for node in run.children {
      guard node is XmlElement(el) else { continue }
      if el.name == "w:br" && el.attributes.get("w:type") is Some("page") {
        return true
      }
    }
  }
  false
}

///|
/// Returns the block, whether a page break precedes it, and whether one
/// follows it.
/// Inline drawings in a paragraph, in document order.
fn paragraph_images(para : @xml.XmlElement) -> Array[ImageRef] {
  let out : Array[ImageRef] = []
  for drawing in para.descendants_by_tag_name("w:drawing") {
    match read_drawing(drawing) {
      Some(image) => out.push(image)
      None => ()
    }
  }
  out
}

///|
/// Where a run sits relative to a complex field.
priv enum FieldState {
  FieldOutside
  FieldInstruction
  FieldResult
}

///|
fn read_paragraph(
  para : @xml.XmlElement,
  sheet : StyleSheet,
  theme : ThemeFonts,
  numbering? : @numbering.Numbering = @numbering.Numbering::empty(),
  counters? : @numbering.Counters = @numbering.Counters::new(),
  default_tab_pt? : Double = 36.0,
) -> (@paginate.Block, Bool, Bool) {
  let (direct_para, style_id) = match para.first("w:pPr") {
    Some(ppr) => read_para_props(ppr)
    None => (ParaProps::empty(), None)
  }
  let resolved_para = sheet.resolve_para(style_id, direct_para)
  let runs : Array[@paragraph.RunInput] = []
  let source_runs : Array[(@xml.XmlElement, String?)] = []
  collect_runs(para, source_runs)
  // Word writes a field as either a self-contained w:fldSimple or a
  // complex run sequence: fldChar begin, instrText, fldChar separate,
  // the cached result, fldChar end. Tracking that state lets the result
  // runs be marked with the instruction that produced them, so the
  // layout can substitute a real value for the cached one.
  let mut instruction = ""
  let mut state = FieldOutside
  for entry in source_runs {
    let (run, simple_field) = entry
    for child in run.children {
      guard child is XmlElement(el) else { continue }
      match (el.name, el.attributes.get("w:fldCharType")) {
        ("w:fldChar", Some("begin")) => {
          state = FieldInstruction
          instruction = ""
        }
        ("w:fldChar", Some("separate")) => state = FieldResult
        ("w:fldChar", Some("end")) => state = FieldOutside
        ("w:instrText", _) =>
          for node in el.children {
            guard node is XmlText(part) else { continue }
            instruction = instruction + part
          }
        _ => ()
      }
    }
    // the instruction itself is not displayed
    if state is FieldInstruction {
      continue
    }
    let text = run_text(run)
    if text.length() == 0 {
      continue
    }
    let (direct_run, char_style_id) = match run.first("w:rPr") {
      Some(rpr) =>
        (
          read_run_props(rpr, theme~),
          rpr.first("w:rStyle").bind(el2 => el2.attributes.get("w:val")),
        )
      None => (RunProps::empty(), None)
    }
    let style = sheet.resolve_run(style_id, char_style_id, direct_run).resolve()
    let field = if state is FieldResult {
      @paragraph.field_kind(instruction)
    } else {
      match simple_field {
        Some(instr) => @paragraph.field_kind(instr)
        None => NotAField
      }
    }
    runs.push({ text, style, field })
  }
  // an empty paragraph still occupies a line, styled by its paragraph
  // mark's run properties (w:pPr/w:rPr)
  if runs.is_empty() {
    let mark = match para.first("w:pPr") {
      Some(ppr) =>
        match ppr.first("w:rPr") {
          Some(rpr) => read_run_props(rpr, theme~)
          None => RunProps::empty()
        }
      None => RunProps::empty()
    }
    runs.push({
      text: "",
      style: sheet.resolve_run(style_id, None, mark).resolve(),
      field: NotAField,
    })
  }
  let mut style = resolved_para.resolve(default_tab_pt~)
  // a numbered paragraph takes its indents from the numbering level
  // unless the paragraph overrides them, and carries a label run
  match (resolved_para.num_id, resolved_para.num_level) {
    // numId 0 is OOXML's "numbering removed" sentinel (ECMA-376
    // 17.9.18) — Word writes it to cancel numbering a style applied, so
    // it must not produce a label
    (Some(0), _) => ()
    (Some(num_id), level_or_none) => {
      let depth = level_or_none.unwrap_or(0)
      let level = numbering.level(num_id, depth)
      // Only indents written on the paragraph itself override the level.
      // Testing the resolved value would let Word's stock ListParagraph
      // style (w:ind left=720) suppress every level's indent and flatten
      // the whole nesting hierarchy to one depth.
      if direct_para.indent_left is None {
        match level.indent_left {
          Some(v) => style = { ..style, indent_left_pt: v.to_pt() }
          None => ()
        }
      }
      if direct_para.indent_first is None {
        match level.indent_hanging {
          Some(v) => style = { ..style, indent_first_pt: -v.to_pt() }
          None =>
            match level.indent_first {
              Some(v) => style = { ..style, indent_first_pt: v.to_pt() }
              None => ()
            }
        }
      }
      match counters.advance(numbering, num_id, depth) {
        Some(label) => {
          // Word styles a marker from the level's own w:rPr over the
          // paragraph mark's, not from the first body run — otherwise a
          // hyperlink or struck-through first run bleeds into the number.
          let mark = match para.first("w:pPr") {
            Some(ppr) =>
              match ppr.first("w:rPr") {
                Some(rpr) => read_run_props(rpr, theme~)
                None => RunProps::empty()
              }
            None => RunProps::empty()
          }
          let mut marker_style = sheet
            .resolve_run(style_id, None, mark)
            .resolve()
          match level.font_family {
            Some(family) => marker_style = { ..marker_style, family, }
            None => ()
          }
          let separator = match level.suffix {
            SuffNothing => ""
            SuffSpace => " "
            // now that tabs advance to a stop, w:suff="tab" aligns the
            // item text to the level's indent as Word does
            SuffTab => "\t"
          }
          runs.insert(0, {
            text: label + separator,
            style: marker_style,
            field: NotAField,
          })
        }
        None => ()
      }
    }
    (None, _) => ()
  }
  let block = @paginate.Block::paragraph(
    { runs, style },
    keep_lines=resolved_para.keep_lines.unwrap_or(false),
    keep_next=resolved_para.keep_next.unwrap_or(false),
    widow_control=resolved_para.widow_control.unwrap_or(true),
  )
  (
    block,
    resolved_para.page_break_before.unwrap_or(false),
    ends_with_page_break(source_runs),
  )
}

///|
/// Convert a parsed `w:document` root plus its stylesheet into engine
/// blocks and section geometry.
pub fn read_document(
  document : @xml.XmlElement,
  sheet : StyleSheet,
  theme? : ThemeFonts = ThemeFonts::empty(),
  numbering? : @numbering.Numbering = @numbering.Numbering::empty(),
  resolve_image? : (String) -> (Bytes, String)? = _ => None,
  default_tab_pt? : Double = 36.0,
) -> DocxDocument {
  // list counters run for the whole document, in reading order
  let counters = @numbering.Counters::new()
  let blocks : Array[@paginate.Block] = []
  let unsupported : Array[String] = []
  let mut refs = FurnitureRefs::empty()
  let body = document.first_or_empty("w:body")
  let mut section = @paginate.SectionProps::default()
  for child in body.children {
    guard child is XmlElement(el) else { continue }
    match el.name {
      "w:p" => {
        let (block, breaks_before, breaks_after) = read_paragraph(
          el,
          sheet,
          theme,
          numbering~,
          counters~,
          default_tab_pt~,
        )
        if breaks_before && blocks.length() > 0 {
          blocks.push(PageBreak)
        }
        blocks.push(block)
        // a paragraph's inline drawings follow it as their own blocks;
        // true inline-with-text placement needs a run kind the paragraph
        // model does not have
        for image in paragraph_images(el) {
          match resolve_image(image.relationship) {
            Some(media) => {
              let (data, mime) = media
              blocks.push(
                @paginate.Block::image(
                  image.width.to_pt(),
                  image.height.to_pt(),
                  data,
                  mime,
                ),
              )
            }
            None => unsupported.push("image")
          }
        }
        if breaks_after {
          blocks.push(PageBreak)
        }
      }
      // the body-level sectPr carries the final section's geometry
      "w:sectPr" => {
        section = read_section_props(el)
        refs = read_furniture_refs(el)
      }
      "w:tbl" =>
        blocks.push(
          @paginate.Block::table(
            read_table(el, sheet, theme~, numbering~, counters~),
          ),
        )
      // block content this milestone does not lay out yet. Recording it
      // keeps the omission visible instead of silently losing text.
      "w:sdt" => unsupported.push("content control")
      _ => ()
    }
  }
  {
    blocks,
    section,
    furniture: @paginate.PageFurniture::none(),
    // read_document cannot open package parts, so it reports the ids the
    // section named and read_docx resolves them
    furniture_refs: refs,
    unsupported,
  }
}

///|
/// Read a `.docx` archive into engine input. Requires
/// `word/document.xml`; `word/styles.xml` is optional.
pub fn read_docx(docx : Bytes) -> DocxDocument raise {
  // bound the inflate itself: the XML budget below only applies once a
  // part is already in memory, so an unbounded read would let a zip bomb
  // through before any limit is consulted
  let archive = @zip.read_limited(
    docx,
    max_package_bytes=256 * 1024 * 1024,
    max_entries=8192,
    max_entry_uncompressed_bytes=64 * 1024 * 1024,
    max_total_uncompressed_bytes=512 * 1024 * 1024,
    max_total_preserved_source_bytes=512 * 1024 * 1024,
  )
  guard archive.get("word/document.xml") is Some(document_part) else {
    raise @core.DocxError::MissingPart(
      message="word/document.xml is not present in the package",
    )
  }
  let ns = namespace_map()
  let document = @xml.read_xml_bytes_limited(
    document_part,
    default_budget(),
    namespace_map=ns,
  )
  // the theme supplies the families that docDefaults references by name
  let theme = match archive.get("word/theme/theme1.xml") {
    Some(theme_part) =>
      read_theme(
        @xml.read_xml_bytes_limited(
          theme_part,
          default_budget(),
          namespace_map=ns,
        ),
      )
    None => ThemeFonts::empty()
  }
  // w:defaultTabStop sets the interval tabs fall back to past the last
  // explicit stop
  let mut even_and_odd = false
  let default_tab_pt = match archive.get("word/settings.xml") {
    Some(part) => {
      let settings = @xml.read_xml_bytes_limited(
        part,
        default_budget(),
        namespace_map=ns,
      )
      // the even/odd switch is document-wide, not per section
      even_and_odd = match settings.first("w:evenAndOddHeaders") {
        Some(el) => parse_toggle(el)
        None => false
      }
      match settings.first("w:defaultTabStop") {
        Some(el) =>
          match parse_twips(el.attributes.get("w:val")) {
            Some(v) => @pagelayout.Twips(v).to_pt()
            None => 36.0
          }
        None => 36.0
      }
    }
    None => 36.0
  }
  let numbering = match archive.get("word/numbering.xml") {
    Some(part) =>
      read_numbering(
        @xml.read_xml_bytes_limited(part, default_budget(), namespace_map=ns),
      )
    None => @numbering.Numbering::empty()
  }
  let sheet = match archive.get("word/styles.xml") {
    Some(styles_part) =>
      read_stylesheet(
        @xml.read_xml_bytes_limited(
          styles_part,
          default_budget(),
          namespace_map=ns,
        ),
        theme~,
      )
    None => StyleSheet::empty()
  }
  let rels_for_images = match archive.get("word/_rels/document.xml.rels") {
    Some(part) =>
      read_relationships(
        @xml.read_xml_bytes_limited(part, default_budget(), namespace_map=ns),
      )
    None => Relationships::empty()
  }
  fn resolve_image(id : String) -> (Bytes, String)? {
    guard rels_for_images.part(id, "word/") is Some(path) else { return None }
    guard media_type(path) is Some(mime) else { return None }
    guard archive.get(path) is Some(bytes) else { return None }
    Some((bytes.to_owned(), mime))
  }

  let parsed = read_document(
    document,
    sheet,
    theme~,
    numbering~,
    resolve_image~,
    default_tab_pt~,
  )
  // resolve the section's header/footer relationship ids to parts and
  // lay their bodies out as furniture
  let rels = rels_for_images
  fn furniture_blocks(id : String?) -> Array[@paginate.Block] raise {
    guard id is Some(value) else { return [] }
    guard rels.part(value, "word/") is Some(path) else { return [] }
    guard archive.get(path) is Some(part) else { return [] }
    let root = @xml.read_xml_bytes_limited(
      part,
      default_budget(),
      namespace_map=ns,
    )
    // a header/footer part's root is w:hdr or w:ftr, with the same body
    // content a w:body holds
    let blocks : Array[@paginate.Block] = []
    for child in root.children {
      guard child is XmlElement(el) else { continue }
      match el.name {
        "w:p" => {
          let (block, _, _) = read_paragraph(el, sheet, theme, numbering~)
          blocks.push(block)
        }
        // Word commonly builds a header from a table, to place text at
        // both margins on one line
        "w:tbl" =>
          blocks.push(
            @paginate.Block::table(read_table(el, sheet, theme~, numbering~)),
          )
        _ => ()
      }
    }
    blocks
  }

  // the even/odd switch lives in settings.xml, which read_document cannot
  // open, so it is merged in here
  let refs = { ..parsed.furniture_refs, even_and_odd, }
  let furniture = @paginate.PageFurniture::{
    header: furniture_blocks(refs.header_default),
    footer: furniture_blocks(refs.footer_default),
    first_header: furniture_blocks(refs.header_first),
    first_footer: furniture_blocks(refs.footer_first),
    even_header: furniture_blocks(refs.header_even),
    even_footer: furniture_blocks(refs.footer_even),
    title_page: refs.title_page,
    even_and_odd: refs.even_and_odd,
  }
  { ..parsed, furniture, }
}

///|
/// Resource ceilings for parsing one part: generous for real documents,
/// bounded so a malformed package cannot exhaust memory.
fn default_budget() -> @xml.XmlReadBudget {
  @xml.xml_read_budget(
    max_source_units=64 * 1024 * 1024,
    max_tokens=8 * 1024 * 1024,
    max_materialized_chars=64 * 1024 * 1024,
    max_token_chars=4 * 1024 * 1024,
  )
}

///|
/// Read a `.docx` and paginate it in one step.
pub fn render_docx(docx : Bytes) -> @pagelayout.PageModel raise {
  let doc = read_docx(docx)
  @paginate.paginate(doc.blocks, section=doc.section, furniture=doc.furniture)
}

///|
// Known gaps, all surfaced by review and deliberately left for later
// milestones rather than half-implemented:
//
//   * Content controls (`w:sdt`) at block level are not laid out; each
//     occurrence is recorded in `DocxDocument::unsupported` so a caller
//     can say the render is incomplete instead of presenting it as the
//     whole document. Tables are laid out, but nested tables (a `w:tbl`
//     inside a `w:tc`) are not yet.
//   * `w:tab` reaches the engine as U+0009 but there is no tab-stop
//     model, so tab-aligned layouts collapse. For the same reason a list
//     level's `w:suff="tab"` renders as a space; the hanging indent
//     already positions the text, so only the label-to-text gap differs.
//   * Only the body-level `w:sectPr` is honored; paragraph-level section
//     breaks do not change page geometry mid-document.
//   * Part names are the conventional `word/...` paths rather than
//     resolved through `_rels/.rels`, so a package that places its main
//     document elsewhere is reported as missing.
//   * Toggle properties merge last-wins through the style chain; ECMA-376
//     §17.7.3 combines toggles set at multiple *style* levels by XOR.

///|
/// `w:headerReference`/`w:footerReference` entries from a `w:sectPr`:
/// the relationship id naming each part. Only the `default` variant is
/// carried today; `first` and `even` need per-page furniture selection,
/// which pagination does not model yet.
pub(all) struct FurnitureRefs {
  header_default : String?
  footer_default : String?
  /// The `w:type="first"` variants, used on page one when the section
  /// sets `w:titlePg` — a title page with no running head, or a different
  /// one. Word ignores these references entirely without that flag, so
  /// both halves are read and the flag decides.
  header_first : String?
  footer_first : String?
  /// The `w:type="even"` variants, used on even-numbered pages when
  /// `w:evenAndOddHeaders` is set in settings.xml. Word ignores these
  /// without that setting, so the references and the flag are read
  /// separately and combined at layout time.
  header_even : String?
  footer_even : String?
  /// `w:titlePg`: whether page one takes the first-page variants.
  title_page : Bool
  /// `w:evenAndOddHeaders` from settings.xml, not from `w:sectPr`.
  even_and_odd : Bool
} derive(Eq, Debug, ToJson)

///|
/// No header or footer referenced.
pub fn FurnitureRefs::empty() -> FurnitureRefs {
  {
    header_default: None,
    footer_default: None,
    header_first: None,
    footer_first: None,
    header_even: None,
    footer_even: None,
    title_page: false,
    even_and_odd: false,
  }
}

///|
/// Read the header/footer references of a `w:sectPr`.
pub fn read_furniture_refs(sectpr : @xml.XmlElement) -> FurnitureRefs {
  let mut refs = FurnitureRefs::empty()
  for child in sectpr.children {
    guard child is XmlElement(el) else { continue }
    if el.name == "w:titlePg" {
      refs = { ..refs, title_page: parse_toggle(el) }
      continue
    }
    let kind = el.attributes.get("w:type").unwrap_or("default")
    match (el.name, kind, el.attributes.get("r:id")) {
      ("w:headerReference", "default", Some(v)) =>
        refs = { ..refs, header_default: Some(v) }
      ("w:footerReference", "default", Some(v)) =>
        refs = { ..refs, footer_default: Some(v) }
      ("w:headerReference", "first", Some(v)) =>
        refs = { ..refs, header_first: Some(v) }
      ("w:footerReference", "first", Some(v)) =>
        refs = { ..refs, footer_first: Some(v) }
      ("w:headerReference", "even", Some(v)) =>
        refs = { ..refs, header_even: Some(v) }
      ("w:footerReference", "even", Some(v)) =>
        refs = { ..refs, footer_even: Some(v) }
      _ => ()
    }
  }
  refs
}
