///|
/// DOCX dump: walks the annotated reader's document tree into canonical
/// docx.batch/2 ops (paragraphs, runs, links, tables), with residual
/// records for everything the op vocabulary cannot express. Images,
/// footnotes/endnotes, and comments stay coverage residuals in this slice.
///
/// Every emitted op chunk must parse through the real batch parser
/// (dump-time self-check); the replay fixpoint lands with the replay
/// command.

///|
/// The paragraph styles the batch writer accepts. Mirrors the parser's
/// gate; anything else residualizes and the op goes out without a style.
fn docx_writable_style(style : String) -> Bool {
  style
  is ("Normal"
  | "Heading1"
  | "Heading2"
  | "Heading3"
  | "Heading4"
  | "Heading5"
  | "Heading6")
}

///|
fn docx_writable_alignment(align : String) -> Bool {
  align
  is ("left" | "center" | "right" | "both" | "start" | "end" | "distribute")
}

///|
/// The closed ST_HighlightColor set the batch writer accepts.
fn docx_highlight_color(value : String) -> Bool {
  value
  is ("black"
  | "blue"
  | "cyan"
  | "darkBlue"
  | "darkCyan"
  | "darkGray"
  | "darkGreen"
  | "darkMagenta"
  | "darkRed"
  | "darkYellow"
  | "green"
  | "lightGray"
  | "magenta"
  | "red"
  | "white"
  | "yellow")
}

///|
fn docx_location(block : Int) -> Json {
  Json::object({ "block": Json::number(block.to_double()) })
}

///|
fn docx_residual(
  code : String,
  scope : String,
  location : Json,
  detail : String,
) -> DumpResidual {
  { code, severity: "dropped", scope, location, asset: None, detail }
}

///|
/// Whether text survives the batch writer's serialization contract:
/// tabs are fine, raw line breaks / control characters / unpaired
/// surrogates are not.
fn docx_text_serializable(text : String) -> Bool {
  for unit in text {
    let code = unit.to_int()
    if code < 0x20 && unit != '\t' {
      return false
    }
    if (code >= 0xD800 && code <= 0xDFFF) || code == 0xFFFE || code == 0xFFFF {
      return false
    }
  }
  true
}

///|
/// Collects one run's expressible spec. Returns None when the run holds
/// no expressible text (its content residualized entirely).
fn docx_run_spec(
  children : Array[@document.DocumentElement],
  properties : @document.RunProperties,
  block : Int,
  residual : Array[DumpResidual],
) -> Json? {
  let text = StringBuilder::new()
  for child in children {
    match child {
      Text(value) => text.write_string(value)
      Tab => text.write_char('\t')
      Break(_) =>
        residual.push(
          docx_residual(
            "docx.break_dropped",
            "block",
            docx_location(block),
            "an in-run break is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
          ),
        )
      Checkbox(_) =>
        residual.push(
          docx_residual(
            "docx.checkbox_dropped",
            "block",
            docx_location(block),
            "a checkbox control is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
          ),
        )
      // Word nests drawings and note/comment references INSIDE runs, so
      // these arms are the live path for real files
      Image(_) =>
        residual.push(
          docx_residual(
            "docx.images_not_dumped",
            "block",
            docx_location(block),
            "images are not dumped in this slice",
          ),
        )
      NoteReference(note_type~, ..) =>
        residual.push(
          docx_residual(
            "docx.note_reference_dropped",
            "block",
            docx_location(block),
            "a \{note_type} reference is not dumped in this slice",
          ),
        )
      CommentReference(_) =>
        residual.push(
          docx_residual(
            "docx.comment_reference_dropped",
            "block",
            docx_location(block),
            "a comment reference is not dumped in this slice",
          ),
        )
      other =>
        residual.push(
          docx_residual(
            "docx.inline_unsupported",
            "block",
            docx_location(block),
            "run content \{docx_element_name(other)} is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
          ),
        )
    }
  }
  let value = text.to_string()
  if !docx_text_serializable(value) {
    residual.push(
      docx_residual(
        "docx.text_unserializable",
        "block",
        docx_location(block),
        "run text holds characters the batch writer cannot serialize",
      ),
    )
    return None
  }
  if properties.style_id is Some(_) || properties.style_name is Some(_) {
    residual.push(
      docx_residual(
        "docx.run_style_dropped",
        "block",
        docx_location(block),
        "a run character style is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
      ),
    )
  }
  let spec : Map[String, Json] = { "text": Json::string(value) }
  if properties.is_bold {
    spec["bold"] = Json::boolean(true)
  }
  if properties.is_italic {
    spec["italic"] = Json::boolean(true)
  }
  if properties.is_underline {
    spec["underline"] = Json::boolean(true)
  }
  if properties.is_strikethrough {
    spec["strike"] = Json::boolean(true)
  }
  if properties.is_all_caps {
    spec["all_caps"] = Json::boolean(true)
  }
  if properties.is_small_caps {
    spec["small_caps"] = Json::boolean(true)
  }
  match properties.vertical_alignment {
    Superscript => spec["vertical"] = Json::string("superscript")
    Subscript => spec["vertical"] = Json::string("subscript")
    Baseline => ()
  }
  match properties.font {
    Some(font) => spec["font"] = Json::string(font)
    None => ()
  }
  match properties.font_size {
    // the parser's ST_HpsMeasure window; a 0.5pt run reads back as 0 and
    // an oversized one past 1638, either of which the parser rejects —
    // keep the run, disclose the size
    Some(size) =>
      if size >= 1 && size <= 1638 {
        spec["size"] = Json::number(size.to_double())
      } else {
        residual.push(
          docx_residual(
            "docx.font_size_dropped",
            "block",
            docx_location(block),
            "font size \{size}pt is outside the writable range 1..1638",
          ),
        )
      }
    None => ()
  }
  match properties.highlight {
    // the writer takes the closed ST_HighlightColor list; the reader
    // passes any attribute value through, so gate here and disclose
    Some(highlight) =>
      if docx_highlight_color(highlight) {
        spec["highlight"] = Json::string(highlight)
      } else if highlight != "none" {
        residual.push(
          docx_residual(
            "docx.highlight_dropped",
            "block",
            docx_location(block),
            "highlight '\{bounded_reason(highlight)}' is outside the ST_HighlightColor set",
          ),
        )
      }
    None => ()
  }
  Some(Json::object(spec))
}

///|
fn docx_element_name(element : @document.DocumentElement) -> String {
  match element {
    Document(..) => "a nested document"
    Paragraph(..) => "a nested paragraph"
    Run(..) => "a nested run"
    Text(_) => "bare text"
    Tab => "a tab"
    Checkbox(_) => "a checkbox"
    Hyperlink(..) => "a nested hyperlink"
    NoteReference(..) => "a footnote/endnote reference"
    CommentReference(_) => "a comment reference"
    Image(_) => "an image"
    Table(..) => "a nested table"
    TableRow(..) => "a table row"
    TableCell(..) => "a table cell"
    Break(_) => "a break"
    BookmarkStart(_) => "a bookmark"
  }
}

///|
/// Walks one paragraph's inline children into run/link specs, pushing
/// residuals for inexpressible content. `allow_links` is false inside
/// hyperlinks (the batch grammar does not nest them).
fn docx_inline_specs(
  children : Array[@document.DocumentElement],
  block : Int,
  runs : Array[Json],
  residual : Array[DumpResidual],
  allow_links~ : Bool,
) -> Unit {
  for child in children {
    match child {
      Run(children~, properties~) =>
        match docx_run_spec(children, properties, block, residual) {
          Some(spec) => runs.push(spec)
          None => ()
        }
      Text(value) =>
        // bare text outside a run: wrap as a plain run
        match
          docx_run_spec(
            [@document.text(value)],
            @document.run_properties(),
            block,
            residual,
          ) {
          Some(spec) => runs.push(spec)
          None => ()
        }
      Hyperlink(children~, href~, anchor~, target_frame~) =>
        if allow_links {
          let link_runs : Array[Json] = []
          docx_inline_specs(
            children,
            block,
            link_runs,
            residual,
            allow_links=false,
          )
          if href is None && anchor is None {
            // the reader yields a target-less hyperlink when the
            // relationship does not resolve; the writer requires href or
            // anchor, so keep the text as plain runs and disclose
            for spec in link_runs {
              runs.push(spec)
            }
            residual.push(
              docx_residual(
                "docx.link_unresolved",
                "block",
                docx_location(block),
                "a hyperlink without a resolvable target keeps its text as plain runs",
              ),
            )
          } else if link_runs.length() > 0 {
            let link : Map[String, Json] = {}
            match href {
              Some(value) => link["href"] = Json::string(value)
              None => ()
            }
            match anchor {
              Some(value) => link["anchor"] = Json::string(value)
              None => ()
            }
            match target_frame {
              Some(value) => link["target_frame"] = Json::string(value)
              None => ()
            }
            link["runs"] = Json::array(link_runs)
            runs.push(Json::object({ "link": Json::object(link) }))
          } else {
            residual.push(
              docx_residual(
                "docx.link_dropped",
                "block",
                docx_location(block),
                "a hyperlink with no expressible content is dropped",
              ),
            )
          }
        } else {
          residual.push(
            docx_residual(
              "docx.link_dropped",
              "block",
              docx_location(block),
              "a nested hyperlink is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
            ),
          )
        }
      Image(_) =>
        residual.push(
          docx_residual(
            "docx.images_not_dumped",
            "block",
            docx_location(block),
            "images are not dumped in this slice",
          ),
        )
      NoteReference(note_type~, ..) =>
        residual.push(
          docx_residual(
            "docx.note_reference_dropped",
            "block",
            docx_location(block),
            "a \{note_type} reference is not dumped in this slice",
          ),
        )
      CommentReference(_) =>
        residual.push(
          docx_residual(
            "docx.comment_reference_dropped",
            "block",
            docx_location(block),
            "a comment reference is not dumped in this slice",
          ),
        )
      BookmarkStart(_) =>
        residual.push(
          docx_residual(
            "docx.bookmark_dropped",
            "block",
            docx_location(block),
            "a bookmark is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
          ),
        )
      Tab | Break(_) | Checkbox(_) =>
        // bare inline outside a run: reuse the run walk for the residual
        // (or the tab) by wrapping it as an anonymous run
        match
          docx_run_spec([child], @document.run_properties(), block, residual) {
          Some(spec) => runs.push(spec)
          None => ()
        }
      other =>
        residual.push(
          docx_residual(
            "docx.inline_unsupported",
            "block",
            docx_location(block),
            "paragraph content \{docx_element_name(other)} is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
          ),
        )
    }
  }
}

///|
/// Builds the batch params for one paragraph (shared by paragraph ops and
/// table-cell paragraphs).
fn docx_paragraph_params(
  children : Array[@document.DocumentElement],
  properties : @document.ParagraphProperties,
  block : Int,
  residual : Array[DumpResidual],
) -> Map[String, Json] {
  let params : Map[String, Json] = {}
  match properties.style_id {
    Some(style) =>
      if docx_writable_style(style) {
        params["style"] = Json::string(style)
      } else {
        residual.push(
          docx_residual(
            "docx.paragraph_style_dropped",
            "block",
            docx_location(block),
            "paragraph style '\{style}' is outside the writable set (Normal, Heading1..Heading6)",
          ),
        )
      }
    None =>
      // a name without an id cannot round-trip either
      if properties.style_name is Some(_) {
        residual.push(
          docx_residual(
            "docx.paragraph_style_dropped",
            "block",
            docx_location(block),
            "a named paragraph style without a style id is not expressible",
          ),
        )
      }
  }
  match properties.alignment {
    Some(align) =>
      if docx_writable_alignment(align) {
        params["align"] = Json::string(align)
      } else {
        residual.push(
          docx_residual(
            "docx.alignment_dropped",
            "block",
            docx_location(block),
            "paragraph alignment '\{align}' is outside the writable set",
          ),
        )
      }
    None => ()
  }
  match properties.numbering {
    Some(numbering) =>
      if numbering.level >= 1 && numbering.level <= 9 {
        params["list"] = Json::object({
          "ordered": Json::boolean(numbering.is_ordered),
          "level": Json::number(numbering.level.to_double()),
        })
      } else {
        residual.push(
          docx_residual(
            "docx.numbering_dropped",
            "block",
            docx_location(block),
            "list level \{numbering.level} is outside the writable range 1..9",
          ),
        )
      }
    None => ()
  }
  if properties.indent.start is Some(_) ||
    properties.indent.end is Some(_) ||
    properties.indent.first_line is Some(_) ||
    properties.indent.hanging is Some(_) {
    residual.push(
      docx_residual(
        "docx.paragraph_indent_dropped",
        "block",
        docx_location(block),
        "paragraph indentation is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
      ),
    )
  }
  let runs : Array[Json] = []
  docx_inline_specs(children, block, runs, residual, allow_links=true)
  if runs.length() == 0 {
    params["text"] = Json::string("")
  } else {
    params["runs"] = Json::array(runs)
  }
  params
}

///|
/// Builds the batch params for one table block.
fn docx_table_params(
  children : Array[@document.DocumentElement],
  properties : @document.TableProperties,
  block : Int,
  residual : Array[DumpResidual],
) -> Map[String, Json]? {
  if properties.style_id is Some(_) || properties.style_name is Some(_) {
    residual.push(
      docx_residual(
        "docx.table_style_dropped",
        "block",
        docx_location(block),
        "a table style is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
      ),
    )
  }
  let emitted : Array[(Array[(Map[String, Json], Int, Int)], Bool)] = []
  for child in children {
    match child {
      TableRow(children~, is_header~) => {
        let cells : Array[(Map[String, Json], Int, Int)] = []
        for cell in children {
          match cell {
            TableCell(children~, col_span~, row_span~) => {
              let paragraphs : Array[Json] = []
              for cell_block in children {
                match cell_block {
                  Paragraph(children~, properties~) =>
                    paragraphs.push(
                      Json::object(
                        docx_paragraph_params(
                          children, properties, block, residual,
                        ),
                      ),
                    )
                  Table(..) =>
                    residual.push(
                      docx_residual(
                        "docx.nested_table_dropped",
                        "block",
                        docx_location(block),
                        "a table nested in a cell is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
                      ),
                    )
                  other =>
                    residual.push(
                      docx_residual(
                        "docx.block_unsupported",
                        "block",
                        docx_location(block),
                        "cell content \{docx_element_name(other)} is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
                      ),
                    )
                }
              }
              let cell_spec : Map[String, Json] = {}
              if paragraphs.length() == 0 {
                cell_spec["text"] = Json::string("")
              } else {
                cell_spec["paragraphs"] = Json::array(paragraphs)
              }
              cells.push((cell_spec, col_span, row_span))
            }
            other =>
              residual.push(
                docx_residual(
                  "docx.block_unsupported",
                  "block",
                  docx_location(block),
                  "row content \{docx_element_name(other)} is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
                ),
              )
          }
        }
        if cells.length() == 0 {
          // the batch parser rejects a row with no cells; dropping the
          // degenerate row keeps the rest of the table replayable
          residual.push(
            docx_residual(
              "docx.empty_row_dropped",
              "block",
              docx_location(block),
              "a table row with no cells is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
            ),
          )
        } else {
          emitted.push((cells, is_header))
        }
      }
      other =>
        residual.push(
          docx_residual(
            "docx.block_unsupported",
            "block",
            docx_location(block),
            "table content \{docx_element_name(other)} is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
          ),
        )
    }
  }
  if emitted.length() == 0 {
    // the batch parser rejects an empty rows array; the table must
    // residualize rather than abort the dump in the self-check
    residual.push(
      docx_residual(
        "docx.empty_table_dropped",
        "block",
        docx_location(block),
        "a table with no expressible rows is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
      ),
    )
    return None
  }
  // header_rows counts LEADING header rows among the rows actually
  // emitted; a header row after body rows keeps only its content
  let rows : Array[Json] = []
  let mut header_rows = 0
  let mut in_leading_headers = true
  for row_index, entry in emitted {
    let (cells, is_header) = entry
    if is_header {
      if in_leading_headers {
        header_rows += 1
      } else {
        residual.push(
          docx_residual(
            "docx.header_rows_not_leading",
            "block",
            docx_location(block),
            "a header row after body rows keeps only its content; header_rows covers leading rows",
          ),
        )
      }
    } else {
      in_leading_headers = false
    }
    // spans are bounded by the writer (col_span <= 63 grid columns,
    // row_span <= the rows below this one); the reader passes raw file
    // values through, so gate here and disclose the geometry loss
    let row_cells : Array[Json] = []
    for cell in cells {
      let (spec, col_span, row_span) = cell
      if col_span > 1 && col_span <= 63 {
        spec["col_span"] = Json::number(col_span.to_double())
      } else if col_span > 63 || col_span < 1 {
        residual.push(
          docx_residual(
            "docx.cell_span_dropped",
            "block",
            docx_location(block),
            "column span \{col_span} is outside the writable range 1..63",
          ),
        )
      }
      let row_span_cap = emitted.length() - row_index
      if row_span > 1 && row_span <= row_span_cap {
        spec["row_span"] = Json::number(row_span.to_double())
      } else if row_span > row_span_cap || row_span < 1 {
        residual.push(
          docx_residual(
            "docx.cell_span_dropped",
            "block",
            docx_location(block),
            "row span \{row_span} exceeds the rows available below its row",
          ),
        )
      }
      row_cells.push(Json::object(spec))
    }
    rows.push(Json::array(row_cells))
  }
  let params : Map[String, Json] = { "rows": Json::array(rows) }
  if header_rows > 0 {
    params["header_rows"] = Json::number(header_rows.to_double())
  }
  Some(params)
}

///|
/// Dumps an annotated DOCX read into an office.dump/1 envelope of
/// docx.batch/2 ops. Body paragraphs and tables become ops; images,
/// footnotes/endnotes, and comments are disclosed as coverage residuals
/// in this slice; headers, footers, and section properties have no op
/// vocabulary. The replayed document always carries the writer's default
/// section, so section properties are disclosed whenever present.
pub fn dump_docx_document(
  annotated : @docx.DocxAnnotatedResult,
  source_file~ : String,
  source_bytes~ : Int,
  source_sha256? : String? = None,
  cancelled? : () -> Bool = () => false,
) -> DumpEnvelope raise DumpError {
  let package_result = annotated.result()
  let ops : Array[Json] = []
  let residual : Array[DumpResidual] = []
  let warnings : Array[DumpWarning] = []
  let document_location = Json::object({ "part": Json::string("document") })
  for message in package_result.messages {
    warnings.push({
      code: "docx.reader_message",
      message: bounded_reason("\{to_repr(message)}"),
    })
  }
  if package_result.headers.length() > 0 {
    residual.push(
      docx_residual(
        "docx.headers_not_dumped",
        "document",
        document_location,
        "\{package_result.headers.length()} header part(s) are not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
      ),
    )
  }
  if package_result.footers.length() > 0 {
    residual.push(
      docx_residual(
        "docx.footers_not_dumped",
        "document",
        document_location,
        "\{package_result.footers.length()} footer part(s) are not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
      ),
    )
  }
  if package_result.sections.length() > 0 {
    residual.push(
      docx_residual(
        "docx.sections_not_dumped",
        "document",
        document_location,
        "\{package_result.sections.length()} section propert(ies) are replaced by the writer's default section",
      ),
    )
  }
  guard package_result.document is Document(children~, notes~, comments~) else {
    raise DumpUnsupported("the reader returned a non-document root")
  }
  if notes.length() > 0 {
    residual.push(
      docx_residual(
        "docx.notes_not_dumped",
        "document",
        document_location,
        "\{notes.length()} footnote/endnote(s) are not dumped in this slice",
      ),
    )
  }
  if comments.length() > 0 {
    residual.push(
      docx_residual(
        "docx.comments_not_dumped",
        "document",
        document_location,
        "\{comments.length()} comment(s) are not dumped in this slice",
      ),
    )
  }
  for block, element in children {
    check_cancelled(cancelled)
    match element {
      Paragraph(children~, properties~) =>
        ops.push(
          Json::object({
            "op": Json::string("paragraph"),
            "params": Json::object(
              docx_paragraph_params(children, properties, block, residual),
            ),
          }),
        )
      Table(children~, properties~) =>
        match docx_table_params(children, properties, block, residual) {
          Some(params) =>
            ops.push(
              Json::object({
                "op": Json::string("table"),
                "params": Json::object(params),
              }),
            )
          None => ()
        }
      other =>
        residual.push(
          docx_residual(
            "docx.block_unsupported",
            "block",
            docx_location(block),
            "body block \{docx_element_name(other)} is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
          ),
        )
    }
  }
  docx_self_check_ops(ops, cancelled)
  {
    format: "docx",
    source_file,
    source_bytes,
    source_sha256,
    batch_schema: @docx_batch.SCHEMA_BATCH_V2,
    create_sheet: None,
    ops,
    assets: {},
    residual,
    warnings,
  }
}

///|
/// Every produced op chunk must parse through the real docx batch parser,
/// so a dump this check accepts is exactly a script replay can consume.
fn docx_self_check_ops(
  ops : Array[Json],
  cancelled : () -> Bool,
) -> Unit raise DumpError {
  for chunk in docx_dump_op_chunks(ops) {
    check_cancelled(cancelled)
    let script = Json::object({
      "schema": Json::string(@docx_batch.SCHEMA_BATCH_V2),
      "ops": Json::array(chunk),
    })
    match (try? @docx_batch.parse_batch(script)) {
      Ok(_) => ()
      Err(error) =>
        raise DumpSelfCheckFailed("docx op chunk rejected: \{error}")
    }
  }
}

///|
/// Splits the docx op stream into scripts within the parser's op ceiling.
/// Shared by the self-check and (later) replay.
pub fn docx_dump_op_chunks(ops : Array[Json]) -> Array[Array[Json]] {
  let chunks : Array[Array[Json]] = []
  let mut start = 0
  while start < ops.length() {
    let end = if ops.length() - start > 10000 {
      start + 10000
    } else {
      ops.length()
    }
    chunks.push(ops[start:end].to_array())
    start = end
  }
  chunks
}
