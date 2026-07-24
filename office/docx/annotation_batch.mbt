///|
/// D4 — preservation-safe DOCX annotation mutation (#164): a strict
/// `docx.annotation-batch/1` script of comment add / reply / resolve /
/// unresolve ops folded over the D1 source-pinned edit session. Each op
/// is one semantic mutation against a fresh snapshot; the fold reindexes
/// at the archive level (no bytes reinflation), accumulates a union
/// changed-part manifest, and serializes ONCE at the end. The body text
/// is never wholesale-rewritten — only the narrow comment-anchor markers
/// are spliced into the document part — and there are no tracked changes.

///|
pub const SCHEMA_ANNOTATION_BATCH : String = "docx.annotation-batch/1"

///|
pub const SCHEMA_ANNOTATION_RESULT : String = "office.docx.annotation-batch/1"

///|
/// Coarse op-count backstop; the true guard is the cumulative staged-byte
/// ceiling below (transact exposes no cancellation hook to its sync
/// callback, and scheduler-cooperative parsing is deferred to #174).
pub const MAX_ANNOTATION_OPS : Int = 128

///|
/// Absolute ceiling on cumulative staged-archive payload growth across
/// the whole fold — the observable "work" bound.
pub const MAX_ANNOTATION_TOTAL_GROWTH : Int64 = 32L * 1024L * 1024L

///|
/// Largest paragraph ordinal accepted by annotation anchors. This is below the
/// shared selector parser's integer ceiling and keeps the annotation grammar's
/// public bound explicit.
pub const MAX_ANNOTATION_ANCHOR_ORDINAL : Int = 9999999

///|
/// The parser-owned operation discriminator vocabulary, in stable order.
let annotation_operation_names : Array[String] = [
  "comment_add", "comment_reply", "comment_resolve", "comment_unresolve",
]

///|
/// Returns the annotation operation vocabulary accepted by this build.
pub fn annotation_batch_operation_names() -> Array[String] {
  annotation_operation_names.copy()
}

///|
/// The union of every member any op kind accepts — used only to detect a
/// typo'd `op` discriminator as an unknown member before reporting the
/// discriminator missing.
let annotation_op_member_union : Array[String] = [
  "op", "anchor", "author", "initials", "date", "body", "label", "parent", "target",
]

///|
/// Errors raised while parsing a `docx.annotation-batch/1` script.
pub suberror DocxAnnotationParseError {
  DocxAnnotationParseError(String)
} derive(@debug.Debug)

///|
/// A reference to a comment: an existing engine id, or a label minted
/// earlier in the same script.
priv enum CommentRef {
  ById(String)
  ByLabel(String)
} derive(Eq, @debug.Debug)

///|
priv enum AnnotationOp {
  Add(
    anchor_at~ : String,
    anchor_to~ : String,
    author~ : String,
    initials~ : String?,
    date~ : String?,
    body~ : Array[@document.DocumentElement],
    label~ : String?
  )
  Reply(
    parent~ : CommentRef,
    author~ : String,
    initials~ : String?,
    date~ : String?,
    body~ : Array[@document.DocumentElement],
    label~ : String?
  )
  Resolve(target~ : CommentRef, done~ : Bool)
}

///|
/// One applied op's outcome for the report. `anchor` is the resolved
/// canonical start selector for `comment_add` (`/docx/body/p[K]`);
/// `anchor_to` is the canonical end selector when the comment spans a
/// paragraph range, otherwise None. `target` is the referenced comment
/// id for `comment_reply` (its parent) and `comment_resolve` /
/// `comment_unresolve` (the comment acted on). Both selectors are always
/// individually valid — a range is two selectors, never a `..` literal.
pub(all) struct DocxAnnotationOpResult {
  op : String
  comment_id : String
  done : Bool?
  anchor : String?
  anchor_to : String?
  target : String?
} derive(Eq, @debug.Debug)

///|
/// The complete annotation-batch outcome.
pub(all) struct DocxAnnotationReport {
  mut ops_applied : Int
  results : Array[DocxAnnotationOpResult]
  labels : Array[(String, String)]
  changed_parts : Array[String]
  mut changed : Bool
} derive(Eq, @debug.Debug)

///|
/// Result of one strict annotation-batch transaction.
pub struct DocxAnnotationBatchResult {
  report : DocxAnnotationReport
  transaction : @transaction.TransactionReport
}

///|
/// The parsed, validated script.
pub struct AnnotationBatch {
  priv ops : Array[AnnotationOp]
}

///|
/// Rejects any object member outside the allowed set — misspelled fields
/// must fail loudly, not be silently ignored (codex #216).
fn annotation_reject_unknown(
  fields : Map[String, Json],
  allowed : Array[String],
  context : String,
) -> Unit raise DocxAnnotationParseError {
  for key, _ in fields {
    if !allowed.contains(key) {
      raise annotation_parse_error(
        context + " has unknown member \"" + key + "\"",
      )
    }
  }
}

///|
fn annotation_parse_error(message : String) -> DocxAnnotationParseError {
  DocxAnnotationParseError(message)
}

///|
/// Validates one `/docx/body/p[K]` anchor selector and returns its
/// story-relative `p[K]` form. Uses office.parse_selector for canonical
/// error parity, then requires exactly body + one 1-based positional
/// paragraph.
fn annotation_anchor(
  selector : String,
  field : String,
) -> String raise DocxAnnotationParseError {
  let parsed = @office.parse_selector(selector) catch {
    _ =>
      raise annotation_parse_error(
        field + " is not a canonical selector: " + selector,
      )
  }
  guard parsed.document_format() is Docx else {
    raise annotation_parse_error(
      field + " must be a /docx selector: " + selector,
    )
  }
  let segments = parsed.segments()
  guard segments.length() == 2 && segments[0].name == "body" else {
    raise annotation_parse_error(
      field + " must be a single body paragraph /docx/body/p[K]: " + selector,
    )
  }
  guard segments[1].name == "p" else {
    raise annotation_parse_error(
      field + " must address a paragraph (p): " + selector,
    )
  }
  let rendered = parsed.render()
  guard rendered == selector else {
    raise annotation_parse_error(
      field + " must use canonical selector spelling; expected " + rendered,
    )
  }
  guard rendered.has_prefix("/docx/body/p[") && rendered.has_suffix("]") else {
    raise annotation_parse_error(
      field + " must be /docx/body/p[K]: " + selector,
    )
  }
  guard segments[1].position() is Some(ordinal) else {
    raise annotation_parse_error(
      field + " must use a positional paragraph selector /docx/body/p[K]",
    )
  }
  guard ordinal <= MAX_ANNOTATION_ANCHOR_ORDINAL else {
    raise annotation_parse_error(field + " paragraph index is out of range")
  }
  "p[" + ordinal.to_string() + "]"
}

///|
/// Parses a comment body: a non-empty array of non-empty paragraph
/// strings, each becoming one plain text paragraph. comment_spec
/// re-validates the plain-content rule.
fn annotation_body(
  value : Json,
) -> Array[@document.DocumentElement] raise DocxAnnotationParseError {
  guard value is Array(items) else {
    raise annotation_parse_error("body must be an array of paragraph strings")
  }
  if items.length() == 0 {
    raise annotation_parse_error("body must have at least one paragraph")
  }
  let body : Array[@document.DocumentElement] = []
  for item in items {
    guard item is String(text) else {
      raise annotation_parse_error("each body paragraph must be a string")
    }
    if text.length() == 0 {
      raise annotation_parse_error("body paragraphs must not be empty")
    }
    body.push(@document.paragraph([@document.run([@document.text(text)])]))
  }
  body
}

///|
fn annotation_string_field(
  fields : Map[String, Json],
  key : String,
  op : String,
) -> String raise DocxAnnotationParseError {
  match fields.get(key) {
    Some(String(value)) if value.length() > 0 => value
    _ =>
      raise annotation_parse_error(
        op + " needs a non-empty string \"" + key + "\"",
      )
  }
}

///|
fn annotation_optional_string(
  fields : Map[String, Json],
  key : String,
  op : String,
) -> String? raise DocxAnnotationParseError {
  match fields.get(key) {
    None => None
    Some(String(value)) if value.length() > 0 => Some(value)
    _ =>
      raise annotation_parse_error(
        op + " \"" + key + "\" must be a non-empty string when present",
      )
  }
}

///|
/// Parses a tagged comment reference: `{"comment_id": "..."}` or
/// `{"label": "..."}`, exactly one.
fn annotation_ref(
  value : Json,
  field : String,
) -> CommentRef raise DocxAnnotationParseError {
  guard value is Object(entries) else {
    raise annotation_parse_error(
      field + " must be {\"comment_id\": ...} or {\"label\": ...}",
    )
  }
  annotation_reject_unknown(entries, ["comment_id", "label"], field)
  let has_id = entries.contains("comment_id")
  let has_label = entries.contains("label")
  if has_id && has_label {
    raise annotation_parse_error(field + " sets both comment_id and label")
  }
  if has_id {
    match entries.get("comment_id") {
      Some(String(id)) if id.length() > 0 => ById(id)
      _ =>
        raise annotation_parse_error(
          field + " comment_id must be a non-empty string",
        )
    }
  } else if has_label {
    match entries.get("label") {
      Some(String(label)) if label.length() > 0 => ByLabel(label)
      _ =>
        raise annotation_parse_error(
          field + " label must be a non-empty string",
        )
    }
  } else {
    raise annotation_parse_error(field + " needs comment_id or label")
  }
}

///|
/// Parses and validates a `docx.annotation-batch/1` document.
pub fn parse_annotation_batch(
  text : String,
) -> AnnotationBatch raise DocxAnnotationParseError {
  let document = @json.parse(text) catch {
    _ => raise annotation_parse_error("annotation script is not valid JSON")
  }
  guard document is Object(fields) else {
    raise annotation_parse_error("annotation script must be a JSON object")
  }
  annotation_reject_unknown(fields, ["schema", "ops"], "the annotation script")
  guard fields.get("schema") is Some(String(schema)) else {
    raise annotation_parse_error(
      "annotation script needs \"schema\": \"" + SCHEMA_ANNOTATION_BATCH + "\"",
    )
  }
  guard schema == SCHEMA_ANNOTATION_BATCH else {
    raise annotation_parse_error(
      "unsupported annotation schema \"" + schema + "\"",
    )
  }
  guard fields.get("ops") is Some(Array(op_items)) else {
    raise annotation_parse_error("annotation script needs an \"ops\" array")
  }
  if op_items.length() > MAX_ANNOTATION_OPS {
    raise annotation_parse_error(
      "ops carries \{op_items.length()} entries; the limit is \{MAX_ANNOTATION_OPS}",
    )
  }
  let labels_seen : Set[String] = Set::new()
  fn check_label(label : String?) -> Unit raise DocxAnnotationParseError {
    match label {
      Some(name) => {
        if !@template.template_key_ok(name) {
          raise annotation_parse_error(
            "label \"" + name + "\" is outside the key grammar",
          )
        }
        if labels_seen.contains(name) {
          raise annotation_parse_error("duplicate label \"" + name + "\"")
        }
        labels_seen.add(name)
      }
      None => ()
    }
  }

  fn check_ref(ref : CommentRef) -> Unit raise DocxAnnotationParseError {
    // forward references are forbidden: a label must be minted by an
    // EARLIER op (already in labels_seen at parse time)
    match ref {
      ByLabel(name) =>
        if !labels_seen.contains(name) {
          raise annotation_parse_error(
            "reference to label \"" + name + "\" before it is defined",
          )
        }
      ById(_) => ()
    }
  }

  let ops : Array[AnnotationOp] = []
  for index, op_item in op_items {
    guard op_item is Object(op) else {
      raise annotation_parse_error("ops[\{index}] must be an object")
    }
    // The "op" discriminator selects the per-kind member allowlist. When it
    // is absent, a typo'd discriminator (e.g. "opp") is itself an unknown
    // member, so check against the union of every op member first — the
    // strict "unknown member" contract must hold before reporting a missing
    // op, otherwise a misspelled key masquerades as a plain omission.
    guard op.get("op") is Some(String(kind)) && kind.length() > 0 else {
      annotation_reject_unknown(op, annotation_op_member_union, "ops[\{index}]")
      raise annotation_parse_error(
        "ops[\{index}] needs a non-empty string \"op\"",
      )
    }
    if !annotation_operation_names.contains(kind) {
      raise annotation_parse_error("unknown op \"" + kind + "\"")
    }
    match kind {
      "comment_add" => {
        annotation_reject_unknown(
          op,
          ["op", "anchor", "author", "initials", "date", "body", "label"],
          "comment_add",
        )
        guard op.get("anchor") is Some(Object(anchor)) else {
          raise annotation_parse_error("comment_add needs an \"anchor\" object")
        }
        annotation_reject_unknown(anchor, ["at", "to"], "comment_add anchor")
        let at = annotation_string_field(anchor, "at", "comment_add anchor")
        let anchor_at = annotation_anchor(at, "comment_add anchor.at")
        let anchor_to = match anchor.get("to") {
          None => anchor_at
          Some(String(to)) if to.length() > 0 =>
            annotation_anchor(to, "comment_add anchor.to")
          _ =>
            raise annotation_parse_error(
              "comment_add anchor.to must be a non-empty selector when present",
            )
        }
        let author = annotation_string_field(op, "author", "comment_add")
        let initials = annotation_optional_string(op, "initials", "comment_add")
        let date = annotation_optional_string(op, "date", "comment_add")
        guard op.get("body") is Some(body_json) else {
          raise annotation_parse_error("comment_add needs a \"body\"")
        }
        let body = annotation_body(body_json)
        let label = annotation_optional_string(op, "label", "comment_add")
        check_label(label)
        ops.push(
          Add(anchor_at~, anchor_to~, author~, initials~, date~, body~, label~),
        )
      }
      "comment_reply" => {
        annotation_reject_unknown(
          op,
          ["op", "parent", "author", "initials", "date", "body", "label"],
          "comment_reply",
        )
        guard op.get("parent") is Some(parent_json) else {
          raise annotation_parse_error("comment_reply needs a \"parent\"")
        }
        let parent = annotation_ref(parent_json, "comment_reply parent")
        check_ref(parent)
        let author = annotation_string_field(op, "author", "comment_reply")
        let initials = annotation_optional_string(
          op, "initials", "comment_reply",
        )
        let date = annotation_optional_string(op, "date", "comment_reply")
        guard op.get("body") is Some(body_json) else {
          raise annotation_parse_error("comment_reply needs a \"body\"")
        }
        let body = annotation_body(body_json)
        let label = annotation_optional_string(op, "label", "comment_reply")
        check_label(label)
        ops.push(Reply(parent~, author~, initials~, date~, body~, label~))
      }
      "comment_resolve" | "comment_unresolve" => {
        annotation_reject_unknown(op, ["op", "target"], kind)
        guard op.get("target") is Some(target_json) else {
          raise annotation_parse_error(kind + " needs a \"target\"")
        }
        let target = annotation_ref(target_json, kind + " target")
        check_ref(target)
        ops.push(Resolve(target~, done=kind == "comment_resolve"))
      }
      other => raise annotation_parse_error("unknown op \"" + other + "\"")
    }
  }
  { ops, }
}

///|
/// Total payload bytes across an archive's file entries (checked Int64) —
/// the observable quantity the fold's decreasing budget accounts on.
fn annotation_archive_payload_bytes(archive : @zip.Archive) -> Int64 {
  let mut total = 0L
  for entry in archive.entries() {
    total = total + entry.data().length().to_int64()
  }
  total
}

///|
/// Merges a strict `docx.annotation-batch/1` script into an existing DOCX
/// through the shared transaction boundary. Comment ops fold over the D1
/// edit session one snapshot at a time; only the final archive is
/// serialized. Strict findings refuse with `DocxAnnotationRefused` and
/// nothing is published.
pub async fn transact_docx_annotations(
  options : @transaction.TransactionOptions,
  batch : AnnotationBatch,
) -> DocxAnnotationBatchResult {
  let collected : Ref[DocxAnnotationReport?] = Ref::new(None)
  let report = @transaction.transact(
    options,
    (format, _original, archive, budget) => {
      if format != Docx {
        raise docx_failure(
          "office.docx.wrong_format",
          "annotation transaction received a \{format.name()} package",
        )
      }
      let result : DocxAnnotationReport = {
        ops_applied: 0,
        results: [],
        labels: [],
        changed_parts: [],
        changed: false,
      }
      // An empty script is a valid no-op: reuse the source bytes exactly
      // rather than round-tripping the archive through a candidate package.
      if batch.ops.is_empty() {
        collected.val = Some(result)
        return @transaction.transaction_reuse_original()
      }
      let base_allowance = budget.max_splice_materialized_bytes()
      let original_bytes = annotation_archive_payload_bytes(archive)
      let union : Set[String] = Set::new()
      let minted : Map[String, String] = {}
      let mut current = archive
      fn resolve_ref(ref : CommentRef) -> String raise {
        match ref {
          ById(id) => id
          ByLabel(label) =>
            match minted.get(label) {
              Some(id) => id
              None =>
                raise docx_failure(
                  "office.docx.annotation_label_unresolved",
                  "label '\{label}' was not minted by an earlier op",
                )
            }
        }
      }

      for op in batch.ops {
        // decreasing budget: the ceiling for this stage is the base
        // splice allowance minus the growth already retained in `current`
        let grown = annotation_archive_payload_bytes(current) - original_bytes
        if grown > MAX_ANNOTATION_TOTAL_GROWTH {
          raise docx_failure(
            "office.docx.annotation_growth_exceeded", "the annotation batch would grow the package beyond the ceiling",
          )
        }
        let remaining = base_allowance.to_int64() - grown
        if remaining <= 0L {
          raise docx_failure(
            "office.docx.annotation_growth_exceeded", "the annotation batch exhausts the splice materialization budget",
          )
        }
        let remaining_int = if remaining > base_allowance.to_int64() {
          base_allowance
        } else {
          remaining.to_int()
        }
        let session = open_edit_session(current, budget)
        let op_result = match op {
          Add(anchor_at~, anchor_to~, author~, initials~, date~, body~, label~) => {
            let spec = @word.comment_spec(
              author~,
              initials?,
              date?,
              from=0,
              to=0,
              body,
            ) catch {
              _ =>
                raise docx_failure(
                  "office.docx.annotation_unsupported", "the comment_add spec was refused (author, date, or body)",
                )
            }
            let id = session.queue_comment_addition(
              at_relative=anchor_at,
              to_relative=anchor_to,
              spec,
            )
            match label {
              Some(name) => minted[name] = id
              None => ()
            }
            // both are individually valid canonical selectors; a range is
            // surfaced as two selectors, never a "p[K]..p[M]" literal
            let anchor = "/docx/body/" + anchor_at
            let anchor_to = if anchor_at == anchor_to {
              None
            } else {
              Some("/docx/body/" + anchor_to)
            }
            (
              {
                op: "comment_add",
                comment_id: id,
                done: None,
                anchor: Some(anchor),
                anchor_to,
                target: None,
              } : DocxAnnotationOpResult)
          }
          Reply(parent~, author~, initials~, date~, body~, label~) => {
            let parent_id = resolve_ref(parent)
            let spec = @word.comment_spec(
              author~,
              initials?,
              date?,
              from=0,
              to=0,
              body,
            ) catch {
              _ =>
                raise docx_failure(
                  "office.docx.annotation_unsupported", "the comment_reply spec was refused (author, date, or body)",
                )
            }
            let id = session.queue_comment_reply(parent_id~, spec)
            match label {
              Some(name) => minted[name] = id
              None => ()
            }
            (
              {
                op: "comment_reply",
                comment_id: id,
                done: None,
                anchor: None,
                anchor_to: None,
                target: Some(parent_id),
              } : DocxAnnotationOpResult)
          }
          Resolve(target~, done~) => {
            let comment_id = resolve_ref(target)
            session.queue_comment_resolution(comment_id~, done~)
            let kind = if done {
              "comment_resolve"
            } else {
              "comment_unresolve"
            }
            (
              {
                op: kind,
                comment_id,
                done: Some(done),
                anchor: None,
                anchor_to: None,
                target: Some(comment_id),
              } : DocxAnnotationOpResult)
          }
        }
        let (staged, declared) = session.stage_to_archive(
          remaining_materialized_bytes=remaining_int,
        )
        for part in declared {
          union.add(part)
        }
        current = staged
        result.results.push(op_result)
        result.ops_applied += 1
      }
      for label, id in minted {
        result.labels.push((label, id))
      }
      result.labels.sort()
      for part in union {
        result.changed_parts.push(part)
      }
      result.changed_parts.sort()
      result.changed = result.changed_parts.length() > 0
      collected.val = Some(result)
      // serialize the fully-folded archive ONCE under the candidate ceiling
      let bytes = @zip.write_limited(
        current,
        max_output_bytes=budget.max_candidate_package_bytes(),
      ) catch {
        _ =>
          raise docx_failure(
            "office.docx.annotation_output_limit", "the annotated package exceeds the output ceiling",
          )
      }
      @transaction.transaction_mutation_with_manifest(
        bytes,
        result.changed_parts,
      )
    },
    validators=[package_validator()],
    identifier=package_identifier(),
  )
  guard collected.val is Some(result) else {
    raise docx_failure(
      "office.docx.annotation_internal", "the annotation batch produced no report",
    )
  }
  { report: result, transaction: report }
}
