///|
/// `docx annotate add <input> <output> --at <path> [--to <path>]
/// (--text <t> --author <a> [--initials i] [--date iso] | --json <file>)`
/// — adds one comment to an EXISTING document by L0 byte-span surgery:
/// anchor markers splice into the original main-part bytes at
/// scanner-derived offsets, the definition into the comments part
/// (created and wired when absent), and every untouched byte stays.
/// Metadata ownership is BRANCH-EXCLUSIVE: with `--text` the flags own
/// it; with `--json` the docx.annotate/1 envelope owns ALL of it and
/// the metadata flags are rejected. Publication follows the batch
/// contract: the output must not exist, the write is atomic, and every
/// failure leaves ZERO output.
async fn run_annotate_add(matches : @argparse.Matches) -> Unit {
  let input = required_value(matches, "input")
  let output = required_value(matches, "output")
  // in==out is rejected STRUCTURALLY, not by string comparison: the
  // output must not exist while the input must — one path naming both
  // (including case-folded aliases on case-insensitive filesystems)
  // trips the existence check below before anything is read.
  if @afs.exists(output) {
    raise @cli.CliError(
      "docx: refusing to write '\{output}': it already exists (annotate writes a NEW file; it never edits in place)",
    )
  }
  let at_flag = required_value(matches, "at")
  let to_flag = first_value(matches, "to")
  // Branch-exclusive comment source.
  let text_flag = first_value(matches, "text")
  let json_flag = first_value(matches, "json")
  let author_flag = first_value(matches, "author")
  let initials_flag = first_value(matches, "initials")
  let date_flag = first_value(matches, "date")
  let spec = match (text_flag, json_flag) {
    (Some(_), Some(_)) =>
      raise @cli.CliError(
        "error: --text and --json are mutually exclusive (exactly one is required)",
      )
    (None, None) =>
      raise @cli.CliError("error: exactly one of --text or --json is required")
    (Some(text), None) => {
      let author = match author_flag {
        Some(author) => author
        None =>
          raise @cli.CliError(
            "error: --author is required with --text (the flags own the metadata on this branch)",
          )
      }
      @docx2html.comment_spec(
        author~,
        initials?=initials_flag,
        date?=date_flag,
        from=0,
        to=0,
        [@docx2html.paragraph([@docx2html.run([@docx2html.text(text)])])],
      ) catch {
        err => raise @cli.CliError("error: \{docx_error_message(err)}")
      }
    }
    (None, Some(envelope_path)) => {
      // The envelope owns ALL metadata: no precedence, no merging.
      if author_flag is Some(_) ||
        initials_flag is Some(_) ||
        date_flag is Some(_) {
        raise @cli.CliError(
          "error: --author/--initials/--date are rejected with --json (the envelope owns all metadata)",
        )
      }
      let envelope_text = @afs.read_file(envelope_path).text()
      @batch.check_script_text(envelope_text) catch {
        BatchError(message) => raise @cli.CliError("error: \{message}")
      }
      let envelope_json = @json.parse(envelope_text) catch {
        err =>
          raise @cli.CliError(
            "error: the envelope is not valid JSON: \{repr(err)}",
          )
      }
      let envelope = @batch.parse_annotate(envelope_json) catch {
        BatchError(message) => raise @cli.CliError("error: \{message}")
      }
      let body = envelope.build_body() catch {
        BatchError(message) => raise @cli.CliError("error: \{message}")
      }
      @docx2html.comment_spec(
        author=envelope.author(),
        initials?=envelope.initials(),
        date?=envelope.date(),
        from=0,
        to=0,
        body,
      ) catch {
        err => raise @cli.CliError("error: \{docx_error_message(err)}")
      }
    }
  }
  let original = @afs.read_file(input).binary()
  let annotated = @docx2html.read_docx_annotated(original) catch {
    err =>
      raise @cli.CliError(
        "docx: could not read '\{input}': \{docx_error_message(err)}",
      )
  }
  // Sidecars this tooling cannot keep consistent make mutation unsafe.
  let sidecars = annotated.annotation_sidecars()
  if sidecars.length() > 0 {
    raise @cli.CliError(
      "docx: refusing to annotate '\{input}': it carries annotation sidecar parts this tool cannot keep consistent (\{sidecars.join(", ")})",
    )
  }
  // Unrepairable annotation state (ambiguous or duplicate ids, markers
  // with no id) would make the mutation's meaning unverifiable.
  for warning in annotated.annotations().warnings() {
    if warning.find("ambiguous") is Some(_) ||
      warning.find("duplicate") is Some(_) ||
      warning.find("has no w:id") is Some(_) {
      raise @cli.CliError(
        "docx: refusing to annotate '\{input}': its annotation state is not repairable (\{warning})",
      )
    }
  }
  // Anchors: BODY-story paragraph paths, ordinal-only.
  let at_relative = body_paragraph_relative_path(at_flag)
  let to_relative = match to_flag {
    Some(to_path) => body_paragraph_relative_path(to_path)
    None => at_relative
  }
  guard annotated.body_paragraph_span(at_relative) is Some(at_span) else {
    raise @cli.CliError(
      "error: --at '\{at_flag}' does not name a body paragraph in '\{input}'",
    )
  }
  guard annotated.body_paragraph_span(to_relative) is Some(to_span) else {
    raise @cli.CliError(
      "error: --to does not name a body paragraph in '\{input}'",
    )
  }
  if to_span.byte_start() < at_span.byte_start() {
    raise @cli.CliError(
      "error: --to precedes --at in the document (the range is inclusive and must be ordered)",
    )
  }
  // Dense id allocation over EVERY id the index knows — definitions and
  // markers across all stories (the index unions both).
  let used_ids : Set[String] = Set([])
  let mut max_numeric = -1
  for comment in annotated.annotations().comments() {
    used_ids.add(comment.id())
    match parse_comment_id(comment.id()) {
      Some(value) => if value > max_numeric { max_numeric = value }
      None => ()
    }
  }
  let mut candidate = max_numeric + 1
  while used_ids.contains(candidate.to_string()) {
    candidate += 1
  }
  let new_id = candidate.to_string()
  // Build the fragments (self-contained per the L0 locked rule).
  let (start_fragment, end_fragment) = @docx_impl.comment_anchor_fragments(
    id=new_id,
  )
  let definition = @docx_impl.comment_definition_fragment(spec, id=new_id) catch {
    err => raise @cli.CliError("error: \{docx_error_message(err)}")
  }
  let main_part = annotated.main_story_part()
  let archive = @mbtzip.read(original) catch {
    err => raise @cli.CliError("docx: could not open '\{input}': \{repr(err)}")
  }
  guard archive.get(main_part) is Some(main_bytes) else {
    raise @cli.CliError("docx: '\{input}' is missing its main part")
  }
  let plan = @splice.SplicePlan::new()
  if at_relative == to_relative {
    add_paragraph_edits(
      plan,
      main_part,
      main_bytes,
      at_span,
      Some(start_fragment),
      Some(end_fragment),
    )
  } else {
    add_paragraph_edits(
      plan,
      main_part,
      main_bytes,
      at_span,
      Some(start_fragment),
      None,
    )
    add_paragraph_edits(
      plan,
      main_part,
      main_bytes,
      to_span,
      None,
      Some(end_fragment),
    )
  }
  // The definition: splice into the existing comments part, or create
  // and wire a new one (the L0 mutated-part matrix's add row).
  match annotated.comments_part() {
    Some(comments_part) => {
      guard annotated.story_root_span("/comments") is Some(root) else {
        raise @cli.CliError(
          "docx: refusing to annotate '\{input}': its comments part could not be scanned",
        )
      }
      match root.close_tag_start() {
        Some(insert_at) =>
          plan.edit_part(
            comments_part,
            @splice.span_edit(
              start=insert_at,
              end=insert_at,
              @utf8.encode(definition),
            ),
          )
        None =>
          raise @cli.CliError(
            "docx: refusing to annotate '\{input}': its comments part has a self-closing root this tool does not rewrite",
          )
      }
    }
    None => {
      let comments_part_name = "word/comments.xml"
      let part_text = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>" +
        "<w:comments xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\">" +
        definition +
        "</w:comments>"
      plan.add_part(comments_part_name, @utf8.encode(part_text)) catch {
        err => raise @cli.CliError("error: \{docx_error_message(err)}")
      }
      // Wire it: a relationship on the MAIN part and a content-type
      // Override — both span edits located structurally.
      let rels_part = rels_part_for(main_part)
      guard archive.get(rels_part) is Some(rels_bytes) else {
        raise @cli.CliError(
          "docx: '\{input}' is missing '\{rels_part}'; cannot wire the comments part",
        )
      }
      let rels_text = @utf8.decode(rels_bytes, ignore_bom=true) catch {
        _ => raise @cli.CliError("docx: '\{rels_part}' is not UTF-8; refusing")
      }
      guard rels_text.find("</Relationships>") is Some(rels_at) else {
        raise @cli.CliError(
          "docx: could not locate the close of '\{rels_part}' (unconventional relationships markup); refusing",
        )
      }
      let mut rel_ordinal = 1
      while rels_text.find("Id=\"rIdAnnotate\{rel_ordinal}\"") is Some(_) {
        rel_ordinal += 1
      }
      plan.edit_part(
        rels_part,
        @splice.span_edit(
          start=rels_at,
          end=rels_at,
          @utf8.encode(
            "<Relationship Id=\"rIdAnnotate\{rel_ordinal}\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"comments.xml\"/>",
          ),
        ),
      )
      guard archive.get("[Content_Types].xml") is Some(types_bytes) else {
        raise @cli.CliError("docx: '\{input}' is missing [Content_Types].xml")
      }
      let types_text = @utf8.decode(types_bytes, ignore_bom=true) catch {
        _ =>
          raise @cli.CliError(
            "docx: [Content_Types].xml is not UTF-8; refusing",
          )
      }
      guard types_text.find("</Types>") is Some(types_at) else {
        raise @cli.CliError(
          "docx: could not locate the close of [Content_Types].xml; refusing",
        )
      }
      plan.edit_part(
        "[Content_Types].xml",
        @splice.span_edit(
          start=types_at,
          end=types_at,
          @utf8.encode(
            "<Override PartName=\"/\{comments_part_name}\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml\"/>",
          ),
        ),
      )
    }
  }
  let spliced = @splice.splice_docx(original, plan) catch {
    err => raise @cli.CliError("error: \{docx_error_message(err)}")
  }
  // Belt 1: the structural validator.
  let findings = @opc.validate_docx_package(spliced)
  if findings.length() > 0 {
    raise @cli.CliError(
      "docx: internal error — the annotated package failed validation: \{findings[0]}",
    )
  }
  // Belt 2: the mutation must READ BACK — the new comment, anchored at
  // the requested paragraph, with no new unrepairable state.
  let verify = @docx2html.read_docx_annotated(spliced) catch {
    err =>
      raise @cli.CliError(
        "docx: internal error — the annotated package does not read back: \{docx_error_message(err)}",
      )
  }
  let mut verified = false
  for comment in verify.annotations().comments() {
    if comment.id() == new_id && comment.defined() {
      for anchor in comment.anchors() {
        if anchor.start() is Some(start_path) &&
          start_path == "/body/" + at_relative {
          verified = true
        }
      }
    }
  }
  if !verified {
    raise @cli.CliError(
      "docx: internal error — the new comment did not read back anchored at '/body/\{at_relative}'; nothing was written",
    )
  }
  write_atomically(output, spliced)
  println("annotated \{output} (comment \{new_id} on /body/\{at_relative})")
}

///|
/// Parses a `--at`/`--to` flag: a BODY-story paragraph path
/// ("/body/p[2]", "/body/tbl[1]/tr[2]/tc[1]/p[1]"), ordinal selectors
/// only, and returns the scanner-relative form.
fn body_paragraph_relative_path(path : String) -> String raise @cli.CliError {
  let parsed = @paths.parse_path(path) catch {
    err => raise CliError("error: \{path}: \{err}")
  }
  guard parsed.root is Body else {
    raise CliError(
      "error: '\{path}' is not a body path (annotate anchors to BODY-story paragraphs only)",
    )
  }
  if parsed.steps.length() == 0 {
    raise CliError("error: '\{path}' names the body, not a paragraph")
  }
  let mut relative = ""
  for index, step in parsed.steps {
    guard step.selector is Ordinal(ordinal) else {
      raise CliError(
        "error: '\{path}': body paragraphs address by ordinal ([n]), not [@id=...]",
      )
    }
    if index == parsed.steps.length() - 1 && step.kind != "p" {
      raise CliError(
        "error: '\{path}' must end at a paragraph (p[n]); got '\{step.kind}'",
      )
    }
    if relative != "" {
      relative += "/"
    }
    relative += "\{step.kind}[\{ordinal}]"
  }
  relative
}

///|
/// The main part's relationships entry ("word/document.xml" ->
/// "word/_rels/document.xml.rels").
fn rels_part_for(part : String) -> String {
  match part.rev_find("/") {
    Some(slash) => {
      let dir = part.view(end_offset=slash).to_owned()
      let base = part.view(start_offset=slash + 1).to_owned()
      "\{dir}/_rels/\{base}.rels"
    }
    None => "_rels/\{part}.rels"
  }
}

///|
/// Strict non-negative decimal comment-id parse (for max+1 allocation).
fn parse_comment_id(text : String) -> Int? {
  if text.length() == 0 || text.length() > 9 {
    return None
  }
  let mut value = 0
  for unit in text {
    let code = unit.to_int()
    if code < '0'.to_int() || code > '9'.to_int() {
      return None
    }
    value = value * 10 + (code - '0'.to_int())
  }
  Some(value)
}

///|
/// Queues the marker edits for one anchored paragraph: fragments land
/// at content_start/close_tag_start, and a SELF-CLOSING paragraph is
/// rewritten by its own extent to the open form (attributes and prefix
/// preserved verbatim from the original bytes).
fn add_paragraph_edits(
  plan : @splice.SplicePlan,
  part : String,
  part_bytes : Bytes,
  span : @docx_impl.NodeSpan,
  leading : String?,
  trailing : String?,
) -> Unit raise @cli.CliError {
  if span.self_closing() {
    // "<name attrs/>" becomes "<name attrs>" + fragments + "</name>".
    let slice = part_bytes[span.byte_start():span.byte_end()]
    let mut name_end = 1
    while name_end < slice.length() &&
          slice[name_end] != b' ' &&
          slice[name_end] != b'/' &&
          slice[name_end] != b'>' &&
          slice[name_end] != b'\t' &&
          slice[name_end] != b'\r' &&
          slice[name_end] != b'\n' {
      name_end += 1
    }
    let replacement = Buffer()
    replacement.write_bytesview(slice[0:slice.length() - 2])
    replacement.write_bytes(b">")
    match leading {
      Some(fragment) => replacement.write_bytes(@utf8.encode(fragment))
      None => ()
    }
    match trailing {
      Some(fragment) => replacement.write_bytes(@utf8.encode(fragment))
      None => ()
    }
    replacement.write_bytes(b"</")
    replacement.write_bytesview(slice[1:name_end])
    replacement.write_bytes(b">")
    plan.edit_part(
      part,
      @splice.span_edit(
        start=span.byte_start(),
        end=span.byte_end(),
        replacement.contents(),
      ) catch {
        err => raise CliError("error: \{docx_error_message(err)}")
      },
    )
    return
  }
  guard span.content_start() is Some(content_start) else {
    raise CliError("docx: internal error — an open paragraph without offsets")
  }
  guard span.close_tag_start() is Some(close_start) else {
    raise CliError("docx: internal error — an open paragraph without offsets")
  }
  match leading {
    Some(fragment) =>
      plan.edit_part(
        part,
        @splice.span_edit(
          start=content_start,
          end=content_start,
          @utf8.encode(fragment),
        ) catch {
          err => raise CliError("error: \{docx_error_message(err)}")
        },
      )
    None => ()
  }
  match trailing {
    Some(fragment) =>
      plan.edit_part(
        part,
        @splice.span_edit(
          start=close_start,
          end=close_start,
          @utf8.encode(fragment),
        ) catch {
          err => raise CliError("error: \{docx_error_message(err)}")
        },
      )
    None => ()
  }
}

///|
fn annotate_command() -> @argparse.Command {
  Command(
    "annotate",
    about="Annotate an EXISTING document by byte-preserving surgery",
    subcommand_required=true,
    subcommands=[
      Command(
        "add",
        about="Add one comment anchored to body paragraph(s)",
        options=[
          OptionArg(
            "at",
            long="at",
            about="Anchor paragraph path (/body/p[2] or a table-cell paragraph path). Required.",
          ),
          OptionArg(
            "to",
            long="to",
            about="Range end paragraph path (same story, not before --at).",
          ),
          OptionArg(
            "text",
            long="text",
            about="Plain comment text (one paragraph); metadata comes from the flags.",
          ),
          OptionArg(
            "json",
            long="json",
            about="Path to a docx.annotate/1 envelope FILE owning ALL metadata; the metadata flags are rejected.",
          ),
          OptionArg(
            "author",
            long="author",
            about="Comment author (required with --text).",
          ),
          OptionArg(
            "initials",
            long="initials",
            about="Author initials (optional, --text branch only).",
          ),
          OptionArg(
            "date",
            long="date",
            about="xsd:dateTime timestamp (optional, --text branch only).",
          ),
        ],
        positionals=[
          PositionArg(
            "input",
            about="Existing .docx to annotate (never modified).",
            num_args=ValueRange(lower=1, upper=1),
          ),
          PositionArg(
            "output",
            about="Output .docx path (must not exist).",
            num_args=ValueRange(lower=1, upper=1),
          ),
        ],
      ),
    ],
  )
}
