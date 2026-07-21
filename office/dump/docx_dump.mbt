///|
/// DOCX dump: walks the annotated reader's document tree into canonical
/// docx.batch/2 ops (paragraphs, runs, links, images, notes, tables),
/// with residual records for everything the op vocabulary cannot
/// express. Image payloads ride as content-addressed inline assets; the
/// op's image path IS the asset id, which replay resolves from the
/// envelope. Comments stay coverage residuals in this slice.
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
/// Shared state threaded through the DOCX walk: the content-addressed
/// asset store, residuals, the note bodies keyed by note id, and the
/// note ids the body actually referenced (for orphan disclosure).
priv struct DocxDumpContext {
  assets : Map[String, DumpAsset]
  total_asset_bytes : Ref[Int]
  residual : Array[DumpResidual]
  footnote_bodies : Map[String, Array[@document.DocumentElement]]
  endnote_bodies : Map[String, Array[@document.DocumentElement]]
  used_notes : Set[String]
}

///|
/// Captures an image payload as a content-addressed inline asset,
/// returning the asset id, or None when the payload exceeds the
/// allowance (the caller residualizes — an op cannot reference an asset
/// the envelope does not carry). Dedup is checked before the allowance:
/// an already-carried payload adds no bytes. A duplicate declaring a
/// different content type keeps the first entry and is disclosed.
fn docx_capture_asset(
  ctx : DocxDumpContext,
  data : Bytes,
  content_type : String,
  block : Int,
) -> String? {
  let id = "sha256-" + sha256_hex_bytes(data)
  match ctx.assets.get(id) {
    Some(existing) => {
      if existing.content_type != content_type {
        ctx.residual.push(
          docx_residual(
            "docx.image_content_type_conflict",
            "block",
            docx_location(block),
            "image declares content type \{content_type} but the carried asset is \{existing.content_type}",
          ),
        )
      }
      Some(id)
    }
    None =>
      if data.length() <= dump_max_asset_bytes &&
        ctx.total_asset_bytes.val + data.length() <= dump_max_total_asset_bytes {
        ctx.total_asset_bytes.val += data.length()
        ctx.assets[id] = {
          content_type,
          size: data.length(),
          data: @base64.encode(data),
        }
        Some(id)
      } else {
        None
      }
  }
}

///|
/// Builds the run-position image spec for one reader image, capturing
/// its payload as an asset. The emitted path is the asset id, so the
/// content type must always be explicit (an asset id has no extension
/// for the parser to infer from).
fn docx_image_spec(
  ctx : DocxDumpContext,
  image : @document.Image,
  block : Int,
) -> Json? {
  // the batch parser and the writer take exactly this set; the reader
  // passes any declared part type through (TIFF/EMF/WMF/SVG included),
  // so gate here — the payload is still carried as an asset
  if !(image.content_type is ("image/png" | "image/jpeg" | "image/gif")) {
    let carried = docx_capture_asset(ctx, image.data, image.content_type, block)
    ctx.residual.push({
      code: "docx.image_content_type_unsupported",
      severity: "dropped",
      scope: "block",
      location: docx_location(block),
      asset: carried,
      detail: "image content type '\{bounded_reason(image.content_type)}' is outside the writable set (png, jpeg, gif); the payload is carried as an asset",
    })
    return None
  }
  match docx_capture_asset(ctx, image.data, image.content_type, block) {
    Some(id) => {
      // a dedup hit keeps the FIRST occurrence's content type; the op
      // must carry the CARRIED type or the re-dumped stream would
      // diverge from this one (the declared difference is disclosed by
      // docx_capture_asset)
      let carried_type = match ctx.assets.get(id) {
        Some(asset) => asset.content_type
        None => image.content_type
      }
      let spec : Map[String, Json] = {
        "path": Json::string(id),
        "content_type": Json::string(carried_type),
      }
      match image.alt_text {
        // the parser runs the attribute contract on alt: non-empty,
        // no control characters — gate and disclose
        Some(alt) if docx_attribute_ok(alt) => spec["alt"] = Json::string(alt)
        Some(alt) if alt != "" =>
          ctx.residual.push(
            docx_residual(
              "docx.image_alt_dropped",
              "block",
              docx_location(block),
              "image alt text holds characters the writer cannot serialize",
            ),
          )
        _ => ()
      }
      Some(Json::object({ "image": Json::object(spec) }))
    }
    None => {
      ctx.residual.push(
        docx_residual(
          "docx.image_oversized",
          "block",
          docx_location(block),
          "image payload (\{image.data.length()} bytes) exceeds the inline asset allowance and is not carried",
        ),
      )
      None
    }
  }
}

///|
/// Builds the run-position footnote/endnote spec for one reference,
/// mapping the referenced body's paragraphs recursively. Note bodies are
/// paragraph lists in the batch grammar: nested notes are forbidden and
/// non-paragraph body blocks residualize.
fn docx_note_spec(
  ctx : DocxDumpContext,
  note_type : String,
  note_id : String,
  block : Int,
) -> Json? {
  let bodies = match note_type {
    "footnote" => ctx.footnote_bodies
    "endnote" => ctx.endnote_bodies
    other => {
      ctx.residual.push(
        docx_residual(
          "docx.note_reference_dropped",
          "block",
          docx_location(block),
          "a '\{other}' note reference is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
        ),
      )
      return None
    }
  }
  guard bodies.get(note_id) is Some(body) else {
    ctx.used_notes.add(note_type + ":" + note_id)
    ctx.residual.push(
      docx_residual(
        "docx.note_body_missing",
        "block",
        docx_location(block),
        "a \{note_type} reference points at no stored body and is dropped",
      ),
    )
    return None
  }
  ctx.used_notes.add(note_type + ":" + note_id)
  let paragraphs : Array[Json] = []
  for element in body {
    match element {
      Paragraph(children~, properties~) =>
        paragraphs.push(
          Json::object(
            docx_paragraph_params(
              children,
              properties,
              block,
              ctx,
              in_note_body=true,
              plain=true,
            ),
          ),
        )
      other =>
        ctx.residual.push(
          docx_residual(
            "docx.block_unsupported",
            "block",
            docx_location(block),
            "\{note_type} body content \{docx_element_name(other)} is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
          ),
        )
    }
  }
  let body_spec : Map[String, Json] = {}
  if paragraphs.length() == 0 {
    body_spec["text"] = Json::string("")
  } else {
    body_spec["paragraphs"] = Json::array(paragraphs)
  }
  let outer : Map[String, Json] = {}
  outer[note_type] = Json::object(body_spec)
  Some(Json::object(outer))
}

///|
/// Mirrors the batch writer's attribute contract: non-empty, no control
/// characters (they cannot survive XML attribute normalization).
fn docx_attribute_ok(text : String) -> Bool {
  if text == "" {
    return false
  }
  for unit in text {
    if unit.to_int() < 0x20 {
      return false
    }
  }
  true
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
/// Builds the run spec for one text segment with the run's formatting
/// flags. Returns None (with a residual) when the text cannot be
/// serialized.
fn docx_segment_spec(
  value : String,
  properties : @document.RunProperties,
  block : Int,
  ctx : DocxDumpContext,
) -> Json? {
  if !docx_text_serializable(value) {
    ctx.residual.push(
      docx_residual(
        "docx.text_unserializable",
        "block",
        docx_location(block),
        "run text holds characters the batch writer cannot serialize",
      ),
    )
    return None
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
    // the parser runs the attribute contract on the font name
    Some(font) =>
      if docx_attribute_ok(font) {
        spec["font"] = Json::string(font)
      } else {
        ctx.residual.push(
          docx_residual(
            "docx.font_dropped",
            "block",
            docx_location(block),
            "font name holds characters the writer cannot serialize",
          ),
        )
      }
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
        ctx.residual.push(
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
        ctx.residual.push(
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
/// Walks one run's children into run-position specs, pushed onto `out`.
/// Word nests drawings and note references INSIDE runs, and their batch
/// specs are run-position siblings, so the accumulated text is flushed
/// around each hoisted spec — order and formatting are both preserved.
/// A run that produced nothing else still emits its (possibly empty)
/// text segment, so empty source runs keep round-tripping.
fn docx_run_specs(
  children : Array[@document.DocumentElement],
  properties : @document.RunProperties,
  block : Int,
  ctx : DocxDumpContext,
  out : Array[Json],
  in_note_body~ : Bool,
  plain~ : Bool,
) -> Unit {
  if properties.style_id is Some(_) || properties.style_name is Some(_) {
    ctx.residual.push(
      docx_residual(
        "docx.run_style_dropped",
        "block",
        docx_location(block),
        "a run character style is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
      ),
    )
  }
  let text = StringBuilder::new()
  let mut pushed = false
  let mut only_references = true
  let flush = (force : Bool) => {
    let value = text.to_string()
    if value != "" || force {
      match docx_segment_spec(value, properties, block, ctx) {
        Some(spec) => {
          out.push(spec)
          pushed = true
        }
        None => ()
      }
    }
    text.reset()
  }
  for child in children {
    match child {
      Text(value) => {
        only_references = false
        text.write_string(value)
      }
      Tab => {
        only_references = false
        text.write_char('\t')
      }
      Image(image) => {
        only_references = false
        flush(false)
        if plain {
          // comment bodies take plain content only
          ctx.residual.push(
            docx_residual(
              "docx.comment_image_dropped",
              "block",
              docx_location(block),
              "an image inside a note or comment body is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
            ),
          )
        } else {
          match docx_image_spec(ctx, image, block) {
            Some(spec) => {
              out.push(spec)
              pushed = true
            }
            None => ()
          }
        }
      }
      NoteReference(note_type~, note_id~) => {
        only_references = false
        flush(false)
        if plain || in_note_body {
          // the batch grammar forbids notes inside note and comment bodies
          ctx.residual.push(
            docx_residual(
              "docx.note_reference_dropped",
              "block",
              docx_location(block),
              "a \{note_type} reference inside a note or comment body is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
            ),
          )
        } else {
          match docx_note_spec(ctx, note_type, note_id, block) {
            Some(spec) => {
              out.push(spec)
              pushed = true
            }
            None => ()
          }
        }
      }
      Break(_) => {
        only_references = false
        ctx.residual.push(
          docx_residual(
            "docx.break_dropped",
            "block",
            docx_location(block),
            "an in-run break is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
          ),
        )
      }
      Checkbox(_) => {
        only_references = false
        ctx.residual.push(
          docx_residual(
            "docx.checkbox_dropped",
            "block",
            docx_location(block),
            "a checkbox control is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
          ),
        )
      }
      CommentReference(_) =>
        // the comment op regenerates its reference run on replay; a
        // reference whose comment is dropped is disclosed by that
        // comment's own residual, and one inside a note or comment body
        // has no op to regenerate it
        if in_note_body || plain {
          ctx.residual.push(
            docx_residual(
              "docx.comment_reference_dropped",
              "block",
              docx_location(block),
              "a comment reference inside a note or comment body is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
            ),
          )
        }
      other => {
        only_references = false
        ctx.residual.push(
          docx_residual(
            "docx.inline_unsupported",
            "block",
            docx_location(block),
            "run content \{docx_element_name(other)} is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
          ),
        )
      }
    }
  }
  // a run holding only comment references (or the writer's reference
  // mark) regenerates on replay; forcing an empty segment for it would
  // grow the paragraph by one run per replay cycle
  flush(!pushed && !(only_references && children.length() > 0))
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
/// Walks one paragraph's inline children into run/link/image/note specs,
/// pushing residuals for inexpressible content. `allow_links` is false
/// inside hyperlinks (the batch grammar does not nest them).
fn docx_inline_specs(
  children : Array[@document.DocumentElement],
  block : Int,
  runs : Array[Json],
  ctx : DocxDumpContext,
  allow_links~ : Bool,
  in_note_body~ : Bool,
  plain~ : Bool,
) -> Unit {
  for child in children {
    match child {
      Run(children~, properties~) =>
        // note and comment bodies open with the writer's childless
        // reference-mark run; it is regenerated on every write, so
        // emitting it would grow the body by one empty run per replay
        if (in_note_body || plain) && children.length() == 0 {
          ()
        } else {
          docx_run_specs(
            children,
            properties,
            block,
            ctx,
            runs,
            in_note_body~,
            plain~,
          )
        }
      Text(value) =>
        // bare text outside a run: wrap as a plain run
        docx_run_specs(
          [@document.text(value)],
          @document.run_properties(),
          block,
          ctx,
          runs,
          in_note_body~,
          plain~,
        )
      Hyperlink(children~, href~, anchor~, target_frame~) =>
        if plain {
          // comment bodies take plain content only: keep the text
          let link_runs : Array[Json] = []
          docx_inline_specs(
            children,
            block,
            link_runs,
            ctx,
            allow_links=false,
            in_note_body~,
            plain~,
          )
          for spec in link_runs {
            runs.push(spec)
          }
          ctx.residual.push(
            docx_residual(
              "docx.link_dropped",
              "block",
              docx_location(block),
              "a hyperlink inside a note or comment body keeps its text as plain runs",
            ),
          )
        } else if allow_links {
          let link_runs : Array[Json] = []
          docx_inline_specs(
            children,
            block,
            link_runs,
            ctx,
            allow_links=false,
            in_note_body~,
            plain~,
          )
          let href_ok = match href {
            Some(value) => docx_attribute_ok(value)
            None => false
          }
          let anchor_ok = match anchor {
            Some(value) => docx_attribute_ok(value)
            None => false
          }
          if !href_ok && !anchor_ok {
            // the reader yields a target-less hyperlink when the
            // relationship does not resolve; the writer requires href or
            // anchor, so keep the text as plain runs and disclose
            for spec in link_runs {
              runs.push(spec)
            }
            ctx.residual.push(
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
              Some(value) if href_ok => link["href"] = Json::string(value)
              _ => ()
            }
            match anchor {
              Some(value) if anchor_ok => link["anchor"] = Json::string(value)
              _ => ()
            }
            match target_frame {
              Some(value) =>
                if docx_attribute_ok(value) {
                  link["target_frame"] = Json::string(value)
                } else {
                  ctx.residual.push(
                    docx_residual(
                      "docx.link_target_frame_dropped",
                      "block",
                      docx_location(block),
                      "link target frame holds characters the writer cannot serialize",
                    ),
                  )
                }
              None => ()
            }
            link["runs"] = Json::array(link_runs)
            runs.push(Json::object({ "link": Json::object(link) }))
          } else {
            ctx.residual.push(
              docx_residual(
                "docx.link_dropped",
                "block",
                docx_location(block),
                "a hyperlink with no expressible content is dropped",
              ),
            )
          }
        } else {
          ctx.residual.push(
            docx_residual(
              "docx.link_dropped",
              "block",
              docx_location(block),
              "a nested hyperlink is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
            ),
          )
        }
      Image(image) =>
        if plain {
          ctx.residual.push(
            docx_residual(
              "docx.comment_image_dropped",
              "block",
              docx_location(block),
              "an image inside a note or comment body is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
            ),
          )
        } else {
          match docx_image_spec(ctx, image, block) {
            Some(spec) => runs.push(spec)
            None => ()
          }
        }
      NoteReference(note_type~, note_id~) =>
        if plain || in_note_body {
          ctx.residual.push(
            docx_residual(
              "docx.note_reference_dropped",
              "block",
              docx_location(block),
              "a \{note_type} reference inside a note or comment body is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
            ),
          )
        } else {
          match docx_note_spec(ctx, note_type, note_id, block) {
            Some(spec) => runs.push(spec)
            None => ()
          }
        }
      CommentReference(_) =>
        ctx.residual.push(
          docx_residual(
            "docx.comment_reference_dropped",
            "block",
            docx_location(block),
            "a comment reference is not dumped in this slice",
          ),
        )
      BookmarkStart(_) =>
        ctx.residual.push(
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
        docx_run_specs(
          [child],
          @document.run_properties(),
          block,
          ctx,
          runs,
          in_note_body~,
          plain~,
        )
      other =>
        ctx.residual.push(
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
/// Builds the batch params for one paragraph (shared by paragraph ops,
/// table-cell paragraphs, and note-body paragraphs).
fn docx_paragraph_params(
  children : Array[@document.DocumentElement],
  properties : @document.ParagraphProperties,
  block : Int,
  ctx : DocxDumpContext,
  in_note_body~ : Bool,
  plain~ : Bool,
) -> Map[String, Json] {
  let params : Map[String, Json] = {}
  match properties.style_id {
    Some(style) =>
      if docx_writable_style(style) {
        params["style"] = Json::string(style)
      } else {
        ctx.residual.push(
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
        ctx.residual.push(
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
        ctx.residual.push(
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
        ctx.residual.push(
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
    ctx.residual.push(
      docx_residual(
        "docx.paragraph_indent_dropped",
        "block",
        docx_location(block),
        "paragraph indentation is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
      ),
    )
  }
  let runs : Array[Json] = []
  docx_inline_specs(
    children,
    block,
    runs,
    ctx,
    allow_links=true,
    in_note_body~,
    plain~,
  )
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
  ctx : DocxDumpContext,
) -> Map[String, Json]? {
  if properties.style_id is Some(_) || properties.style_name is Some(_) {
    ctx.residual.push(
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
                          children,
                          properties,
                          block,
                          ctx,
                          in_note_body=false,
                          plain=false,
                        ),
                      ),
                    )
                  Table(..) =>
                    ctx.residual.push(
                      docx_residual(
                        "docx.nested_table_dropped",
                        "block",
                        docx_location(block),
                        "a table nested in a cell is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
                      ),
                    )
                  other =>
                    ctx.residual.push(
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
              ctx.residual.push(
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
          ctx.residual.push(
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
        ctx.residual.push(
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
    ctx.residual.push(
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
        ctx.residual.push(
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
        ctx.residual.push(
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
        ctx.residual.push(
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
/// docx.batch/2 ops. Body paragraphs and tables become ops; images ride
/// as content-addressed assets referenced by their specs; footnote and
/// endnote bodies are dumped at their references. Comments are disclosed
/// as coverage residuals in this slice; headers, footers, and section
/// properties have no op vocabulary. The replayed document always
/// carries the writer's default section, so section properties are
/// disclosed whenever present.
pub fn dump_docx_document(
  annotated : @docx.DocxAnnotatedResult,
  source_file~ : String,
  source_bytes~ : Int,
  source_sha256? : String? = None,
  cancelled? : () -> Bool = () => false,
) -> DumpEnvelope raise DumpError {
  let package_result = annotated.result()
  let ops : Array[Json] = []
  let footnote_bodies : Map[String, Array[@document.DocumentElement]] = {}
  for entry in annotated.footnote_bodies() {
    let (id, body) = entry
    footnote_bodies[id] = body
  }
  let endnote_bodies : Map[String, Array[@document.DocumentElement]] = {}
  for entry in annotated.endnote_bodies() {
    let (id, body) = entry
    endnote_bodies[id] = body
  }
  let ctx : DocxDumpContext = {
    assets: {},
    total_asset_bytes: Ref::new(0),
    residual: [],
    footnote_bodies,
    endnote_bodies,
    used_notes: Set::new(),
  }
  let residual = ctx.residual
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
  ignore(comments)
  // comment anchors are op-index ranges over PARAGRAPH ops; collect each
  // covering comment's span while walking (the annotation index keys on
  // the story-relative /body/p[K] selector, K counting paragraphs only)
  let comment_spans : Map[String, (Int, Int)] = {}
  let mut paragraph_ordinal = 0
  let annotations = annotated.annotations()
  for block, element in children {
    check_cancelled(cancelled)
    match element {
      Paragraph(children~, properties~) => {
        paragraph_ordinal += 1
        let op_index = ops.length()
        for
          id in annotations.covering_comment_ids(
            "/body/p[\{paragraph_ordinal}]",
          ) {
          match comment_spans.get(id) {
            Some((from, _)) => comment_spans[id] = (from, op_index)
            None => comment_spans[id] = (op_index, op_index)
          }
        }
        ops.push(
          Json::object({
            "op": Json::string("paragraph"),
            "params": Json::object(
              docx_paragraph_params(
                children,
                properties,
                block,
                ctx,
                in_note_body=false,
                plain=false,
              ),
            ),
          }),
        )
      }
      Table(children~, properties~) =>
        match docx_table_params(children, properties, block, ctx) {
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
  // a stored note body no reference reached is silently invisible in the
  // replayed document unless disclosed
  let mut orphaned_notes = 0
  for note in notes {
    if !ctx.used_notes.contains(note.note_type + ":" + note.note_id) {
      orphaned_notes += 1
    }
  }
  if orphaned_notes > 0 {
    residual.push(
      docx_residual(
        "docx.note_orphaned",
        "document",
        document_location,
        "\{orphaned_notes} stored note bodie(s) have no reference in the dumped body and are dropped",
      ),
    )
  }
  dump_docx_comments(
    annotated, ctx, ops, comment_spans, document_location, cancelled,
  )
  docx_self_check_ops(ops, cancelled)
  {
    format: "docx",
    source_file,
    source_bytes,
    source_sha256,
    batch_schema: @docx_batch.SCHEMA_BATCH_V2,
    create_sheet: None,
    ops,
    assets: ctx.assets,
    residual,
    warnings,
  }
}

///|
/// Emits `comment` ops after the body content: roots anchor to the
/// paragraph-op span their annotation covers, replies thread to their
/// parent's op. Multi-pass so a reply always references an earlier op;
/// anything unanchorable, authorless, or orphaned residualizes with the
/// reason disclosed — never silently dropped.
fn dump_docx_comments(
  annotated : @docx.DocxAnnotatedResult,
  ctx : DocxDumpContext,
  ops : Array[Json],
  comment_spans : Map[String, (Int, Int)],
  document_location : Json,
  cancelled : () -> Bool,
) -> Unit raise DumpError {
  let infos = annotated.annotations().comments()
  if infos.length() == 0 {
    return
  }
  // op indexes inside a batch script are chunk-local, so a stream past
  // one chunk cannot carry cross-chunk comment anchors — disclose
  if ops.length() > 10000 - infos.length() {
    ctx.residual.push(
      docx_residual(
        "docx.comments_not_dumped",
        "document",
        document_location,
        "\{infos.length()} comment(s) span a chunked op stream and cannot anchor across scripts",
      ),
    )
    return
  }
  let bodies : Map[String, Array[@document.DocumentElement]] = {}
  for entry in annotated.comment_bodies() {
    let (id, body) = entry
    bodies[id] = body
  }
  let emitted : Map[String, Int] = {}
  let dropped : Set[String] = Set::new()
  let drop = (id : String, reason : String) => {
    dropped.add(id)
    ctx.residual.push(
      docx_residual(
        "docx.comment_dropped",
        "document",
        document_location,
        "comment '\{bounded_reason(id)}' is dropped: " + reason,
      ),
    )
  }
  // multi-pass: a reply can only be emitted after its parent
  for ;; {
    check_cancelled(cancelled)
    let mut progressed = false
    let mut remaining = 0
    for info in infos {
      let id = info.id()
      if emitted.contains(id) || dropped.contains(id) {
        continue
      }
      if !info.defined() {
        drop(id, "the file references it but stores no definition")
        continue
      }
      let author = match info.author() {
        Some(author) if docx_attribute_ok(author) => author
        _ => {
          drop(id, "it carries no writable author attribute")
          continue
        }
      }
      let params : Map[String, Json] = {}
      match info.parent_id() {
        Some(parent) =>
          if dropped.contains(parent) {
            drop(id, "its parent comment was dropped")
            continue
          } else if emitted.get(parent) is Some(parent_op) {
            params["reply_to"] = Json::number(parent_op.to_double())
          } else {
            // parent not emitted yet: retry next round
            remaining += 1
            continue
          }
        None =>
          match comment_spans.get(id) {
            Some(span) => {
              let (from, to) = span
              if from == to {
                params["on"] = Json::number(from.to_double())
              } else {
                params["on"] = Json::object({
                  "from": Json::number(from.to_double()),
                  "to": Json::number(to.to_double()),
                })
              }
            }
            None => {
              drop(id, "its anchor covers no dumped paragraph")
              continue
            }
          }
      }
      params["author"] = Json::string(author)
      match info.initials() {
        Some(initials) if docx_attribute_ok(initials) =>
          params["initials"] = Json::string(initials)
        _ => ()
      }
      match info.date() {
        // the writer validates the full xsd:dateTime grammar (the parser
        // does not), so a free-form date would pass the self-check and
        // break replay; validate against the REAL writer contract by
        // constructing a spec — zero mirror drift
        Some(date) if docx_attribute_ok(date) =>
          match
            (try? @word.comment_spec(author="probe", date~, from=0, to=0, [])) {
            Ok(_) => params["date"] = Json::string(date)
            Err(_) =>
              ctx.residual.push(
                docx_residual(
                  "docx.comment_metadata_dropped",
                  "document",
                  document_location,
                  "comment date '\{bounded_reason(date)}' is not a writable xsd:dateTime and is dropped",
                ),
              )
          }
        _ => ()
      }
      match info.done() {
        Some(done) => params["done"] = Json::boolean(done)
        None => ()
      }
      let paragraphs : Array[Json] = []
      match bodies.get(id) {
        Some(body) =>
          for element in body {
            match element {
              Paragraph(children~, properties~) =>
                paragraphs.push(
                  Json::object(
                    docx_paragraph_params(
                      children,
                      properties,
                      ops.length(),
                      ctx,
                      in_note_body=false,
                      plain=true,
                    ),
                  ),
                )
              other =>
                ctx.residual.push(
                  docx_residual(
                    "docx.block_unsupported",
                    "document",
                    document_location,
                    "comment body content \{docx_element_name(other)} is not expressible in \{@docx_batch.SCHEMA_BATCH_V2}",
                  ),
                )
            }
          }
        None => ()
      }
      if paragraphs.length() == 0 {
        params["text"] = Json::string("")
      } else {
        params["paragraphs"] = Json::array(paragraphs)
      }
      emitted[id] = ops.length()
      ops.push(
        Json::object({
          "op": Json::string("comment"),
          "params": Json::object(params),
        }),
      )
      progressed = true
    }
    if remaining == 0 {
      break
    }
    if !progressed {
      // the leftovers form reply cycles or thread to comments outside
      // the stored set; disclose each
      for info in infos {
        let id = info.id()
        if !emitted.contains(id) && !dropped.contains(id) {
          drop(id, "its reply thread never reaches an emitted parent")
        }
      }
      break
    }
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
