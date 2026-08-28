///|
/// The format-neutral half of preservation-safe DOCX text substitution,
/// shared by the `{{key}}` template merge and the literal edit driver.
///
/// A paragraph becomes ONE stream of rendering-adjacent "pieces"; a
/// scanner over the concatenated piece text returns cross-run spans in
/// piece coordinates; every span is then checked for editability, joined
/// to the byte-fidelity set, and finally rewritten as per-run `<w:t>`
/// replacements on the immutable source snapshot. Only the scanner is
/// syntax-specific — everything below is not, so the two drivers cannot
/// drift in what they consider safe.

///|
/// One text-bearing run segment inside a scan region.
priv struct DocxPiece {
  // "" when the piece is not rewritable (bare text, opaque-run text,
  // complex-field descendants, separators)
  run_path : String
  // paragraph-relative parent identity: "" for direct runs, else the
  // hyperlink path segment — matches may not cross parents
  parent : String
  text : String
  rewritable : Bool
}

///|
/// One planned rewrite for a run.
priv struct DocxRunEdit {
  story : String
  part : String
  run_path : String
  paragraph_location : String
  original_text : String
  final_text : String
}

///|
/// One accepted cross-run span together with the text that replaces it.
priv struct DocxSpanRewrite {
  span : @template.TemplateSpan
  replacement : String
}

///|
/// Why a span may not be rewritten, if at all.
priv enum DocxSpanSafety {
  SpanSafe
  SpanUnrewritable
  SpanCrossesParent
}

///|
/// Scans one paragraph into a SINGLE stream of rendering-adjacent
/// pieces. Every piece is either rewritable (a pure text-only run in
/// scope) or not (bare text, opaque-run text, complex-field
/// descendants); true rendering interruptions (tabs, breaks, images,
/// note marks) become separator pieces whose text can never pair, and
/// zero-width elements (bookmarks, comment references) contribute
/// nothing. One scan over the stream keeps full grammar context across
/// every boundary: a span touching any unrewritable piece refuses, so no
/// split shape can silently survive and no counting is needed.
fn docx_paragraph_pieces(
  paragraph_path : String,
  children : Array[@document.DocumentElement],
) -> Array[DocxPiece] {
  let pieces : Array[DocxPiece] = []
  let separator = () => {
    pieces.push({ run_path: "", parent: "", text: "\n", rewritable: false, })
  }
  let opaque_text = (value : String) => {
    pieces.push({ run_path: "", parent: "", text: value, rewritable: false, })
  }
  // descendant collector for content nested inside opaque runs (complex
  // fields wrap hyperlinks inside runs): text renders adjacently but is
  // never rewritable
  fn collect_opaque(element : @document.DocumentElement) -> Unit {
    match element {
      Text(value) => opaque_text(value)
      BookmarkStart(_) | CommentReference(_) => ()
      Tab | Break(_) | Checkbox(_) => separator()
      NoteReference(..) => separator()
      Run(children~, ..)
      | Hyperlink(children~, ..)
      | Paragraph(children~, ..)
      | Table(children~, ..)
      | TableRow(children~, ..)
      | TableCell(children~, ..) =>
        for child in children {
          collect_opaque(child)
        }
      _ => separator()
    }
  }

  let handle_run = (
    run_children : Array[@document.DocumentElement],
    run_path : String,
    parent : String,
  ) => {
    let mut pure = true
    for child in run_children {
      if !(child is Text(_)) {
        pure = false
        break
      }
    }
    if pure {
      let text = StringBuilder()
      for child in run_children {
        if child is Text(value) {
          text.write_string(value)
        }
      }
      pieces.push({
        run_path,
        parent,
        text: text.to_string(),
        rewritable: true,
      })
    } else {
      for child in run_children {
        match child {
          Text(value) => opaque_text(value)
          BookmarkStart(_) | CommentReference(_) => ()
          Tab | Break(_) | Checkbox(_) => separator()
          NoteReference(..) => separator()
          other => collect_opaque(other)
        }
      }
    }
  }
  let mut runs = 0
  let mut hyperlinks = 0
  for child in children {
    match child {
      Run(children=run_children, ..) => {
        runs += 1
        handle_run(run_children, paragraph_path + "/r[\{runs}]", "")
      }
      Hyperlink(children=link_children, ..) => {
        hyperlinks += 1
        let link_segment = "hyperlink[\{hyperlinks}]"
        let mut link_runs = 0
        for grand in link_children {
          match grand {
            Run(children=run_children, ..) => {
              link_runs += 1
              handle_run(
                run_children,
                paragraph_path + "/" + link_segment + "/r[\{link_runs}]",
                link_segment,
              )
            }
            Text(value) => opaque_text(value)
            BookmarkStart(_) | CommentReference(_) => ()
            _ => separator()
          }
        }
      }
      Text(value) => opaque_text(value)
      BookmarkStart(_) | CommentReference(_) => ()
      _ => separator()
    }
  }
  pieces
}

///|
/// Positive-width coverage: a span touches piece `index` only when it
/// covers at least one code unit of it.
fn docx_piece_covered_width(
  pieces : Array[DocxPiece],
  span : @template.TemplateSpan,
  index : Int,
) -> Int {
  if span.start_segment > index || index > span.end_segment {
    0
  } else {
    let local_start = if index == span.start_segment {
      span.start_offset
    } else {
      0
    }
    let local_end = if index == span.end_segment {
      span.end_offset
    } else {
      pieces[index].text.length()
    }
    if local_end > local_start {
      local_end - local_start
    } else {
      0
    }
  }
}

///|
/// Whether a span may be rewritten at all: it must cover only rewritable
/// pieces, and it must stay inside one parent (a span straddling a
/// hyperlink boundary would have to move text into or out of the link).
fn docx_span_safety(
  pieces : Array[DocxPiece],
  span : @template.TemplateSpan,
) -> DocxSpanSafety {
  let mut unrewritable = false
  let mut crosses = false
  let mut anchor_parent : String? = None
  let mut cursor = span.start_segment
  while cursor <= span.end_segment && cursor < pieces.length() {
    if docx_piece_covered_width(pieces, span, cursor) > 0 {
      if !pieces[cursor].rewritable {
        unrewritable = true
      } else {
        match anchor_parent {
          None => anchor_parent = Some(pieces[cursor].parent)
          Some(parent) => if pieces[cursor].parent != parent { crosses = true }
        }
      }
    }
    cursor += 1
  }
  if unrewritable {
    SpanUnrewritable
  } else if crosses {
    SpanCrossesParent
  } else {
    SpanSafe
  }
}

///|
/// Joins every run a span touches to the byte-fidelity set: covered runs
/// plus interior zero-width runs the span crosses (the reader drops
/// in-run pictures, leaving an empty run the model cannot distinguish
/// from a truly empty one; only the byte-fidelity gate can see the
/// difference), excluding the canonical uncovered end piece.
fn docx_collect_span_checks(
  pieces : Array[DocxPiece],
  span : @template.TemplateSpan,
  story~ : String,
  part~ : String,
  location~ : String,
  out : Array[DocxRunEdit],
) -> Unit {
  let mut cursor = span.start_segment
  while cursor <= span.end_segment && cursor < pieces.length() {
    let piece = pieces[cursor]
    let width = docx_piece_covered_width(pieces, span, cursor)
    let interior_empty = width == 0 &&
      piece.rewritable &&
      !(cursor == span.end_segment && span.end_offset == 0)
    if (width > 0 && piece.rewritable) || interior_empty {
      out.push({
        story,
        part,
        run_path: piece.run_path,
        paragraph_location: location,
        original_text: piece.text,
        final_text: piece.text,
      })
    }
    cursor += 1
  }
}

///|
/// The linear code-unit position of a span endpoint over the pieces'
/// concatenated text, used only to detect overlapping accepted spans.
fn docx_piece_position(
  pieces : Array[DocxPiece],
  segment : Int,
  offset : Int,
) -> Int {
  let mut total = 0
  for index in 0..<segment.min(pieces.length()) {
    total += pieces[index].text.length()
  }
  total + offset
}

///|
/// Rebuilds each rewritable piece's final text from the spans that cover
/// it: a span contributes its replacement only in its START piece and
/// erases its covered range everywhere else, so a cross-run match keeps
/// the formatting of the run it started in. Pieces whose text is
/// unchanged produce no edit.
fn docx_plan_span_rewrites(
  pieces : Array[DocxPiece],
  rewrites : Array[DocxSpanRewrite],
  story~ : String,
  part~ : String,
  location~ : String,
  out : Array[DocxRunEdit],
) -> Unit {
  for index, piece in pieces {
    if !piece.rewritable {
      continue
    }
    let original = piece.text
    let length = original.length()
    let piece_edits : Array[(Int, Int, String)] = []
    for rewrite in rewrites {
      let span = rewrite.span
      if docx_piece_covered_width(pieces, span, index) > 0 ||
        (span.start_segment == index && span.start_offset == 0 && length == 0) {
        let local_start = if span.start_segment == index {
          span.start_offset
        } else {
          0
        }
        let local_end = if span.end_segment == index {
          span.end_offset
        } else {
          length
        }
        let replacement = if span.start_segment == index {
          rewrite.replacement
        } else {
          ""
        }
        piece_edits.push((local_start, local_end, replacement))
      }
    }
    if piece_edits.length() == 0 {
      continue
    }
    piece_edits.sort_by((a, b) => a.0 - b.0)
    let builder = StringBuilder()
    let mut cursor = 0
    for edit in piece_edits {
      let (local_start, local_end, replacement) = edit
      builder.write_string(original[cursor:local_start].to_owned())
      builder.write_string(replacement)
      cursor = local_end
    }
    builder.write_string(original[cursor:length].to_owned())
    let final_text = builder.to_string()
    if final_text != original {
      out.push({
        story,
        part,
        run_path: piece.run_path,
        paragraph_location: location,
        original_text: original,
        final_text,
      })
    }
  }
}

///|
/// Joins one out-of-scope story's rendered text into a single string so
/// a needle split across runs is detected exactly like an unsplit one.
/// Paragraph boundaries and opaque children insert separators, so a
/// match can never straddle them.
fn docx_story_joined_text(body : Array[@document.DocumentElement]) -> String {
  let joined = StringBuilder()
  fn walk(element : @document.DocumentElement) -> Unit {
    match element {
      Text(value) => joined.write_string(value)
      Paragraph(children~, ..) => {
        joined.write_char('\n')
        for child in children {
          walk(child)
        }
      }
      Run(children~, ..)
      | Hyperlink(children~, ..)
      | Table(children~, ..)
      | TableRow(children~, ..)
      | TableCell(children~, ..) =>
        for child in children {
          walk(child)
        }
      // zero-width elements render nothing and must not separate
      BookmarkStart(_) | CommentReference(_) => ()
      _ => joined.write_char('\n')
    }
  }

  for element in body {
    walk(element)
  }
  joined.to_string()
}

///|
/// The byte-fidelity gate over the full touch set: every run ANY span
/// touches must store bytes that decode to exactly its model text.
/// `unsupported` receives (location, detail) for each violation so each
/// driver keeps its own bounded finding shape.
fn docx_fidelity_check_runs(
  checks : Array[DocxRunEdit],
  session : DocxEditSession,
  annotated : @word.DocxAnnotatedResult,
  unsupported : (String, String) -> Unit,
) -> Unit {
  let checked : Set[String] = Set([])
  for check in checks {
    let check_key = check.part + "\u{0}" + check.run_path
    if checked.contains(check_key) {
      continue
    }
    checked.add(check_key)
    guard annotated.story_run_span(check.story, check.run_path) is Some(span) else {
      unsupported(
        check.paragraph_location,
        "a matched run has no byte span in the source snapshot",
      )
      continue
    }
    guard (span.content_start(), span.close_tag_start())
      is (Some(content_start), Some(close_tag_start)) else {
      // a self-closing empty run stores no content at all: nothing can
      // hide in it, and there is nothing to verify
      continue
    }
    guard session.archive.get(check.part) is Some(part_bytes) else {
      unsupported(
        check.paragraph_location,
        "the source part bytes for a matched run are unavailable",
      )
      continue
    }
    let region = @utf8.decode(part_bytes[content_start:close_tag_start]) catch {
      _ => {
        unsupported(
          check.paragraph_location,
          "stored run content is not decodable text",
        )
        continue
      }
    }
    match docx_decode_text_region(region) {
      Some(decoded) if decoded == check.original_text => ()
      _ =>
        unsupported(
          check.paragraph_location,
          "stored run content does not round-trip to its model text",
        )
    }
  }
}

///|
/// Emits the planned run rewrites as byte-span edits on the immutable
/// source snapshot. `blocked` is re-consulted before every queue so a
/// refused pass never mutates, and `on_change` records that the
/// transaction is no longer a no-op.
fn docx_emit_run_edits(
  edits : Array[DocxRunEdit],
  session : DocxEditSession,
  annotated : @word.DocxAnnotatedResult,
  blocked : () -> Bool,
  on_change : () -> Unit,
) -> Unit raise {
  for edit in edits {
    guard annotated.story_run_span(edit.story, edit.run_path) is Some(span) else {
      // already disclosed by the fidelity pass
      continue
    }
    guard (span.content_start(), span.close_tag_start())
      is (Some(content_start), Some(close_tag_start)) else {
      // an empty self-closing run cannot receive a content rewrite; a
      // non-empty final text for one is a planner bug surfaced by the
      // whole-transaction validators, and an empty final is a no-op
      continue
    }
    if blocked() {
      continue
    }
    if edit.final_text == "" {
      session.queue_span_edit(
        edit.part,
        start=span.byte_start(),
        end=span.byte_end(),
        b"",
      )
    } else {
      let replacement = "<w:t xml:space=\"preserve\">" +
        docx_escape_text(edit.final_text) +
        "</w:t>"
      session.queue_span_edit(
        edit.part,
        start=content_start,
        end=close_tag_start,
        @utf8.encode(replacement),
      )
    }
    on_change()
  }
}
