///|
/// Accepting and rejecting the tracked changes an existing DOCX already
/// carries, through the same preservation-safe D1 edit session the literal
/// edit and the template merge use. `office outline` reports the revisions;
/// this resolves them.
///
/// The four OOXML resolutions, which is the whole semantic content of the
/// feature:
///
/// | action       | XML effect                                        |
/// | ------------ | ------------------------------------------------- |
/// | accept w:ins | unwrap the element, keep its runs                 |
/// | reject w:ins | remove the element AND its content                |
/// | accept w:del | remove the element AND its content                |
/// | reject w:del | unwrap it, and turn each w:delText back into w:t   |
///
/// Every edit is expressed in ORIGINAL-part coordinates against the immutable
/// transaction snapshot, and the splice layer sorts and overlap-checks them
/// before anything is materialized. Nothing here therefore depends on
/// applying revisions in reverse document order: an implementation that
/// mutated a string in place would have to, but no edit here can shift the
/// offsets of another. Overlap is still possible in principle — a revision
/// nested inside another revision — so that case is refused explicitly rather
/// than left to produce a splice-level diagnostic.
///
/// Strict by default: a selection that reaches a construct outside the
/// resolvable set, a nested revision, two operations disagreeing about the
/// same revision, and an operation that selects nothing all refuse
/// publication with a bounded report, and nothing is published on any
/// refusal.

///|
/// One revision the script selected, resolved to the part it lives in.
priv struct DocxRevisionTarget {
  span : @word.RevisionSpan
  part : String
  location : String
  // The action every operation that selected it agreed on.
  accept : Bool
}

///|
/// The canonical report location for a revision: the story-qualified path of
/// the projection node that contains it, degrading to the story itself when
/// the revision sits directly at story level.
fn docx_revision_location(span : @word.RevisionSpan) -> String {
  match span.container_path() {
    Some(path) => "/docx" + span.story() + "/" + path
    None => "/docx" + span.story()
  }
}

///|
/// A one-line description of a revision, for findings an agent reads.
fn docx_revision_detail(span : @word.RevisionSpan) -> String {
  let out = StringBuilder::new()
  out.write_string("w:" + span.kind())
  match span.id() {
    Some(id) => out.write_string(" id=\"" + id + "\"")
    None => ()
  }
  match span.author() {
    Some(author) => out.write_string(" author=\"" + author + "\"")
    None => ()
  }
  out.to_string()
}

///|
/// Whether one operation's selector picks this revision. The spelled fields
/// are CONJUNCTIVE, and `all` is the explicit no-filter form.
///
/// Unsupported constructs are matched by exactly the same rule. That is
/// deliberate: a property revision by Reviewer IS one of "everything by
/// Reviewer", so the selection has to reach it and refuse, instead of quietly
/// resolving the rest and leaving the document still under review.
fn docx_revision_selects(
  op : DocxRevisionOp,
  span : @word.RevisionSpan,
) -> Bool {
  if op.all {
    return true
  }
  match op.id {
    Some(value) => if span.id() != Some(value) { return false }
    None => ()
  }
  match op.author {
    Some(value) => if span.author() != Some(value) { return false }
    None => ()
  }
  match op.kind {
    Some(value) => if span.kind() != value { return false }
    None => ()
  }
  true
}

///|
/// Whether the resolver can own this element's bytes.
///
/// Two independent gates. `supported` comes from the scanner and excludes
/// property revisions, moves, and every `*PrChange`. The container gate then
/// requires the revision to sit directly inside a paragraph or a hyperlink,
/// which is where a RUN-level revision lives. The schema also allows `w:ins`
/// around a whole `w:tr` or around block content; removing one of those can
/// empty a table of its rows, which is not a valid document, so those are
/// refused as well rather than published and hoped for.
fn docx_revision_resolvable(
  span : @word.RevisionSpan,
  accept~ : Bool,
) -> String? {
  if !span.supported() {
    return Some(
      "w:" +
      span.kind() +
      " is a property, move, or structure revision, which this build does not resolve",
    )
  }
  guard span.container_path() is Some(path) else {
    return Some("the revision is not inside any paragraph")
  }
  let segment = match path.rev_find("/") {
    Some(cut) => path[cut + 1:].to_owned()
    None => path
  }
  let kind = match segment.find("[") {
    Some(cut) => segment[0:cut].to_owned()
    None => segment
  }
  guard kind is ("p" | "hyperlink") else {
    return Some(
      "the revision wraps block or row content (inside " +
      kind +
      "), not runs inside a paragraph",
    )
  }
  // A well-formed element either self-closes or closes; an unterminated one
  // has no usable extent and must never be spliced by guessed offsets.
  if span.content_start() is Some(_) && span.close_tag_start() is None {
    return Some("the revision element never closes in the source part")
  }
  // Unwrapping drops the start tag, and with it any namespace prefix that tag
  // bound. Word binds every prefix on w:document, but a document assembled
  // part-by-part can bind one here, and its former children would be left
  // pointing at nothing. Removal takes the whole subtree, so it stays safe.
  if (span.kind() == "ins") == accept &&
    span.content_start() is Some(_) &&
    span.declares_namespaces() {
    return Some(
      "the revision element binds a namespace prefix its content uses; unwrapping it would leave that prefix unbound",
    )
  }
  None
}

///|
/// The resolution driver. Selection, validation, and emission are three
/// separate passes over the SAME immutable snapshot, so no finding can be
/// discovered after an edit for it has already been queued.
async fn transact_docx_revisions(
  options : @transaction.TransactionOptions,
  ops : Array[DocxRevisionOp],
  allow_unmatched~ : Bool,
) -> DocxEditResult {
  let collected : Ref[DocxEditReport?] = Ref(None)
  let report = transact_docx(options, session => {
    let results = ops.map(op => {
      (
        {
          op: if op.accept {
            "accept_revision"
          } else {
            "reject_revision"
          },
          find: "",
          replace: "",
          occurrence: None,
          at: None,
          selector_id: op.id,
          selector_author: op.author,
          selector_type: op.kind,
          selector_all: op.all,
          matched: 0,
          replacements: 0,
          resolved: 0,
        } : DocxEditOpResult)
    })
    let report : DocxEditReport = {
      ops_applied: ops.length(),
      replacements: 0,
      revisions_resolved: 0,
      results,
      unmatched: [],
      unmatched_total: 0,
      unsupported: [],
      unsupported_total: 0,
      conflicts: [],
      conflicts_total: 0,
      locations: [],
      locations_truncated: false,
      stories_scanned: [],
      changed: false,
    }
    let note_unsupported = (location : String, detail : String) => {
      report.unsupported_total += 1
      if report.unsupported.length() < docx_edit_finding_limit {
        report.unsupported.push({ location, detail })
      }
    }
    let note_conflict = (location : String, detail : String) => {
      report.conflicts_total += 1
      if report.conflicts.length() < docx_edit_finding_limit {
        report.conflicts.push({ location, detail })
      }
    }
    let annotated = session.annotated()
    // Stories whose parts this build rewrites, exactly the set the literal
    // edit owns. A revision in any other scanned story (a footnote, an
    // endnote, a comment) is reported as unsupported rather than skipped.
    let parts_by_story : Map[String, String] = Map([])
    parts_by_story["/body"] = annotated.main_story_source().part()
    for index, source in annotated.header_story_sources() {
      parts_by_story["/header[\{index + 1}]"] = source.part()
    }
    for index, source in annotated.footer_story_sources() {
      parts_by_story["/footer[\{index + 1}]"] = source.part()
    }
    report.stories_scanned.push("/body")
    for index, _ in annotated.header_story_sources() {
      report.stories_scanned.push("/header[\{index + 1}]")
    }
    for index, _ in annotated.footer_story_sources() {
      report.stories_scanned.push("/footer[\{index + 1}]")
    }
    let spans = annotated.revision_spans()

    // Pass 1 — selection. A revision selected by two operations that
    // disagree about the action has no defined outcome and refuses; two
    // operations agreeing resolve it once and both report it.
    let targets : Array[DocxRevisionTarget] = []
    let selected : Array[Bool] = Array::make(spans.length(), false)
    for index, span in spans {
      let location = docx_revision_location(span)
      let mut action : Bool? = None
      for op_index, op in ops {
        if !docx_revision_selects(op, span) {
          continue
        }
        results[op_index].matched += 1
        match action {
          None => action = Some(op.accept)
          Some(previous) =>
            if previous != op.accept {
              note_conflict(
                location,
                "accept_revision and reject_revision both select " +
                docx_revision_detail(span),
              )
            }
        }
      }
      match action {
        None => continue
        Some(accept) => {
          selected[index] = true
          match docx_revision_resolvable(span, accept~) {
            Some(reason) => {
              note_unsupported(
                location,
                docx_revision_detail(span) + ": " + reason,
              )
              continue
            }
            None => ()
          }
          match parts_by_story.get(span.story()) {
            Some(part) => targets.push({ span, part, location, accept })
            None =>
              note_unsupported(
                location,
                docx_revision_detail(span) +
                ": revisions in " +
                span.story() +
                " stories are not resolvable in this build",
              )
          }
        }
      }
    }

    // Pass 2 — nesting. Resolving an outer revision rewrites bytes that an
    // inner one also owns, so the two edits would overlap. Word does emit
    // `w:ins` wrapping `w:del` (text inserted, then deleted by someone
    // else); the caller must resolve the inner revision first.
    for index, span in spans {
      if !selected[index] {
        continue
      }
      for other_index, other in spans {
        if other_index == index || other.story() != span.story() {
          continue
        }
        if other.byte_start() >= span.byte_start() &&
          other.byte_end() <= span.byte_end() {
          note_conflict(
            docx_revision_location(span),
            docx_revision_detail(span) +
            " contains " +
            docx_revision_detail(other) +
            "; resolve the inner revision first",
          )
        }
      }
    }
    for index, entry in results {
      if entry.matched == 0 {
        report.unmatched_total += 1
        if report.unmatched.length() < docx_edit_finding_limit {
          report.unmatched.push({
            location: "ops[\{index}]",
            detail: "the selector matched no tracked change",
          })
        }
      }
    }
    let blocked = report.blocked(allow_unmatched)

    // Pass 3 — emission, as ONE plan. Unwrapping is two edits that are only
    // jointly well-formed: removing an open tag without its matching close
    // tag is malformed XML, and the session validates every queued plan
    // against the candidate part. Queueing the halves separately would
    // therefore refuse on a document that is perfectly resolvable, so all
    // edits for all targets become valid together or not at all.
    if !blocked && !targets.is_empty() {
      let plan = @splice.SplicePlan::new()
      let pinned : Set[String] = Set([])
      let queue = (part : String, start : Int, end : Int, replacement : Bytes) => {
        if !pinned.contains(part) {
          guard session.archive.get(part) is Some(source) else {
            raise docx_failure(
              "office.docx.missing_part",
              "source DOCX does not contain part '" + part + "'",
            )
          }
          plan.pin_part(part, source) catch {
            error => raise mapped_plan_failure(error)
          }
          pinned.add(part)
        }
        let edit = @splice.span_edit(start~, end~, replacement) catch {
          error => raise mapped_plan_failure(error)
        }
        plan.edit_part(part, edit) catch {
          error => raise mapped_plan_failure(error)
        }
      }
      for target in targets {
        let span = target.span
        let unwrap = (span.kind() == "ins") == target.accept
        match (span.content_start(), span.close_tag_start()) {
          (Some(content_start), Some(close_tag_start)) =>
            if unwrap {
              queue(target.part, span.byte_start(), content_start, b"")
              queue(target.part, close_tag_start, span.byte_end(), b"")
              // Restoring deleted text is the only resolution that rewrites
              // anything rather than deleting: each `w:delText` becomes a
              // `w:t` by overwriting its LOCAL NAME in both tags, which
              // keeps the source prefix, `xml:space`, and every other byte.
              for edit in span.name_edits() {
                queue(
                  target.part,
                  edit.start(),
                  edit.end(),
                  @utf8.encode(edit.replacement()),
                )
              }
            } else {
              queue(target.part, span.byte_start(), span.byte_end(), b"")
            }
          // The self-closing form holds no content, so unwrapping it and
          // removing it are the same edit.
          _ => queue(target.part, span.byte_start(), span.byte_end(), b"")
        }
        report.revisions_resolved += 1
        report.changed = true
        for op_index, op in ops {
          if docx_revision_selects(op, span) {
            results[op_index].resolved += 1
          }
        }
        if report.locations.length() < docx_edit_finding_limit {
          report.locations.push({
            location: target.location,
            detail: (if target.accept { "accept " } else { "reject " }) +
            docx_revision_detail(span),
          })
        } else {
          report.locations_truncated = true
        }
      }
      session.queue_plan(plan)
    }
    collected.val = Some(report)
    if blocked {
      raise docx_failure(
        "office.docx.edit_refused", "strict revision findings refuse publication",
      )
    }
  }) catch {
    error =>
      match collected.val {
        Some(edit) if edit.blocked(allow_unmatched) =>
          raise DocxEditRefused(edit)
        _ => raise error
      }
  }
  guard collected.val is Some(edit) else {
    raise docx_failure(
      "office.docx.edit_internal", "the revision resolution produced no report",
    )
  }
  { report: edit, transaction: report }
}
