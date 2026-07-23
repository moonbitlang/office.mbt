// Shared fresh-DOCX authoring: turns a parsed docx.batch/2 script plus its
// preloaded image bytes into a written package. Centralizes the batch ->
// writer mapping (body build + comment/note spec construction) so the office
// CLI, the standalone `docx batch` CLI, and any other caller share ONE
// implementation instead of drifting copies. Serialization is bounded by the
// optional `limits`, so an over-budget package is refused as a typed
// WriteResourceLimit before the archive payloads are materialized.

///|
/// Builds a fresh DOCX from an already-parsed `docx.batch/2` script and the
/// image bytes its `image_paths()` referenced. Body/comment/note construction
/// errors surface as `Unsupported` carrying the script op address; a bounded
/// serialization ceiling breach surfaces as `WriteResourceLimit`. Nothing is
/// written — the caller publishes the returned bytes through its own
/// transaction/atomic-write boundary.
pub fn author_docx_bytes(
  script : @batch.BatchScript,
  images : Map[String, Bytes],
  limits? : @opc.PackageLimits,
) -> Bytes raise DocxError {
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
