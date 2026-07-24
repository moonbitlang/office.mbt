// Shared fresh-DOCX authoring: turns a parsed docx.batch/2 script plus its
// preloaded image bytes into a written package, centralizing the batch ->
// writer mapping (body build + comment/note spec construction). The office
// fresh-authoring surface (office/docx) uses this; the standalone `docx batch`
// CLI still carries its own inline copy (adopting this is a tracked follow-up,
// deferred to avoid churning its separate cram/acceptance suite). Serialization
// is bounded by the optional `limits`, so an over-budget package is refused as
// a typed WriteResourceLimit before the archive payloads are materialized.

///|
/// Maximum distinct media parts a fresh-authoring script may emit (one per
/// image OCCURRENCE, not per unique asset), and the aggregate emitted-media
/// byte ceiling summed over occurrences. Enforced BEFORE the writer graph is
/// built, so a script that references one asset thousands of times is refused
/// as a typed media limit rather than after materializing every part.
pub const MAX_AUTHORED_MEDIA_PARTS : Int = 1000

///|
/// Maximum aggregate emitted-media bytes, summed over image occurrences rather
/// than unique assets.
pub const MAX_AUTHORED_MEDIA_BYTES : Int64 = 64L * 1024L * 1024L

///|
/// Builds a fresh DOCX from an already-parsed `docx.batch/2` script and the
/// image bytes its `image_paths()` referenced. Body/comment/note construction
/// errors surface as `Unsupported` carrying the script op address; a bounded
/// serialization or emitted-media ceiling breach surfaces as
/// `WriteResourceLimit`. Nothing is written — the caller publishes the returned
/// bytes through its own transaction/atomic-write boundary.
pub fn author_docx_bytes(
  script : @batch.BatchScript,
  images : Map[String, Bytes],
  limits? : @opc.PackageLimits,
) -> Bytes raise DocxError {
  // Emitted-media preflight, BEFORE build_body materializes per-occurrence
  // document nodes / relationships / media metadata.
  let occurrences = script.image_occurrences()
  if occurrences.length() > MAX_AUTHORED_MEDIA_PARTS {
    raise WriteResourceLimit(
      kind="media_parts",
      limit=MAX_AUTHORED_MEDIA_PARTS.to_int64(),
      actual=occurrences.length().to_int64(),
      message="the authoring script emits \{occurrences.length()} media parts; the limit is \{MAX_AUTHORED_MEDIA_PARTS}",
    )
  }
  let mut media_bytes = 0L
  for path in occurrences {
    media_bytes = media_bytes +
      (match images.get(path) {
        Some(bytes) => bytes.length()
        None => 0
      }).to_int64()
    if media_bytes > MAX_AUTHORED_MEDIA_BYTES {
      raise WriteResourceLimit(
        kind="media_bytes",
        limit=MAX_AUTHORED_MEDIA_BYTES,
        actual=media_bytes,
        message="the authoring script's emitted media exceeds the \{MAX_AUTHORED_MEDIA_BYTES}-byte ceiling",
      )
    }
  }
  let body = script.build_body(images) catch {
    @batch.BatchError(message) => raise Unsupported(message~)
  }
  let comments = []
  let batch_comments = script.build_comments() catch {
    @batch.BatchError(message) => raise Unsupported(message~)
  }
  for comment in batch_comments {
    let spec = match
      (comment.reply_to(), comment.from_block(), comment.to_block()) {
      (Some(parent), _, _) =>
        comment_reply(
          author=comment.author(),
          initials?=comment.initials(),
          date?=comment.date(),
          reply_to=parent,
          done?=comment.done(),
          comment.body(),
        ) catch {
          err =>
            raise Unsupported(message="\{comment.at()}: \{err.description()}")
        }
      (None, Some(from), Some(to)) =>
        comment_spec(
          author=comment.author(),
          initials?=comment.initials(),
          date?=comment.date(),
          from~,
          to~,
          done?=comment.done(),
          comment.body(),
        ) catch {
          err =>
            raise Unsupported(message="\{comment.at()}: \{err.description()}")
        }
      _ =>
        raise Unsupported(
          message="\{comment.at()}: comment has neither an anchor nor a reply target",
        )
    }
    comments.push(spec)
  }
  let footnotes = []
  for
    note in (script.build_footnotes() catch {
      @batch.BatchError(message) => raise Unsupported(message~)
    }) {
    footnotes.push(
      note_spec(note.body()) catch {
        err => raise Unsupported(message="\{note.at()}: \{err.description()}")
      },
    )
  }
  let endnotes = []
  for
    note in (script.build_endnotes() catch {
      @batch.BatchError(message) => raise Unsupported(message~)
    }) {
    endnotes.push(
      note_spec(note.body()) catch {
        err => raise Unsupported(message="\{note.at()}: \{err.description()}")
      },
    )
  }
  write_docx_with_annotations(body, comments~, footnotes~, endnotes~, limits?)
}
