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
    "http://schemas.openxmlformats.org/drawingml/2006/main": "a",
    "http://purl.oclc.org/ooxml/drawingml/main": "a",
  }
}

///|
/// A document ready for the layout engine.
pub(all) struct DocxDocument {
  blocks : Array[@paginate.Block]
  section : @paginate.SectionProps
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
fn collect_runs(el : @xml.XmlElement, out : Array[@xml.XmlElement]) -> Unit {
  for child in el.children {
    guard child is XmlElement(node) else { continue }
    if node.name == "w:r" {
      out.push(node)
    } else if node.name == "w:del" {
      continue
    } else if is_run_container(node.name) {
      collect_runs(node, out)
    }
  }
}

///|
/// Whether this paragraph ends with an explicit page break. Word's usual
/// idiom puts `<w:br w:type="page"/>` at the END of the paragraph that
/// finishes the page, so the break belongs AFTER this paragraph.
fn ends_with_page_break(runs : Array[@xml.XmlElement]) -> Bool {
  for run in runs {
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
fn read_paragraph(
  para : @xml.XmlElement,
  sheet : StyleSheet,
  theme : ThemeFonts,
) -> (@paginate.Block, Bool, Bool) {
  let (direct_para, style_id) = match para.first("w:pPr") {
    Some(ppr) => read_para_props(ppr)
    None => (ParaProps::empty(), None)
  }
  let resolved_para = sheet.resolve_para(style_id, direct_para)
  let runs : Array[@paragraph.RunInput] = []
  let source_runs : Array[@xml.XmlElement] = []
  collect_runs(para, source_runs)
  for run in source_runs {
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
    runs.push({ text, style })
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
    })
  }
  let block = @paginate.Block::paragraph(
    { runs, style: resolved_para.resolve() },
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
) -> DocxDocument {
  let blocks : Array[@paginate.Block] = []
  let unsupported : Array[String] = []
  let body = document.first_or_empty("w:body")
  let mut section = @paginate.SectionProps::default()
  for child in body.children {
    guard child is XmlElement(el) else { continue }
    match el.name {
      "w:p" => {
        let (block, breaks_before, breaks_after) = read_paragraph(
          el, sheet, theme,
        )
        if breaks_before && blocks.length() > 0 {
          blocks.push(PageBreak)
        }
        blocks.push(block)
        if breaks_after {
          blocks.push(PageBreak)
        }
      }
      // the body-level sectPr carries the final section's geometry
      "w:sectPr" => section = read_section_props(el)
      "w:tbl" =>
        blocks.push(@paginate.Block::table(read_table(el, sheet, theme~)))
      // block content this milestone does not lay out yet. Recording it
      // keeps the omission visible instead of silently losing text.
      "w:sdt" => unsupported.push("content control")
      _ => ()
    }
  }
  { blocks, section, unsupported }
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
  read_document(document, sheet, theme~)
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
  @paginate.paginate(doc.blocks, section=doc.section)
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
//   * Numbering (`w:numPr`) is not read, so list markers and the indents
//     numbering.xml supplies for each level are missing.
//   * `w:tab` reaches the engine as U+0009 but there is no tab-stop
//     model, so tab-aligned layouts collapse.
//   * Only the body-level `w:sectPr` is honored; paragraph-level section
//     breaks do not change page geometry mid-document.
//   * Part names are the conventional `word/...` paths rather than
//     resolved through `_rels/.rels`, so a package that places its main
//     document elsewhere is reported as missing.
//   * Toggle properties merge last-wins through the style chain; ECMA-376
//     §17.7.3 combines toggles set at multiple *style* levels by XOR.
