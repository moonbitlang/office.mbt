///|
/// DOCX replay: rebuilds document bytes from an office.dump/1 envelope by
/// feeding its ops to the real docx batch build path and the real writer —
/// never a second builder. The envelope's content-addressed assets supply
/// the image payloads.

///|
/// Rewrites the note references in a built element tree by the per-kind
/// offsets. Note ids inside one batch script are dense 0-based indexes
/// into THAT script's note arrays; when a chunked stream concatenates
/// bodies and note arrays, every reference from a later chunk must shift
/// by the notes the earlier chunks contributed — without this, chunk 2's
/// references would silently pair with chunk 1's bodies.
fn docx_offset_note_refs(
  element : @document.DocumentElement,
  footnote_offset : Int,
  endnote_offset : Int,
) -> @document.DocumentElement raise ReplayError {
  fn walk(
    node : @document.DocumentElement,
  ) -> @document.DocumentElement raise ReplayError {
    match node {
      NoteReference(note_type~, note_id~) => {
        let offset = match note_type {
          "footnote" => footnote_offset
          "endnote" => endnote_offset
          _ => 0
        }
        if offset == 0 {
          return node
        }
        let mut index = 0
        let mut valid = note_id.length() > 0
        for unit in note_id {
          if unit is ('0'..='9') {
            index = index * 10 + (unit.to_int() - '0'.to_int())
          } else {
            valid = false
            break
          }
        }
        guard valid else {
          raise ReplayFailed(
            "built note reference carries a non-numeric id '\{note_id}'",
          )
        }
        @document.DocumentElement::NoteReference(
          note_type~,
          note_id=(index + offset).to_string(),
        )
      }
      Paragraph(children~, properties~) =>
        Paragraph(children=children.map(walk), properties~)
      Run(children~, properties~) =>
        Run(children=children.map(walk), properties~)
      Hyperlink(children~, href~, anchor~, target_frame~) =>
        Hyperlink(children=children.map(walk), href~, anchor~, target_frame~)
      Table(children~, properties~) =>
        Table(children=children.map(walk), properties~)
      TableRow(children~, is_header~) =>
        TableRow(children=children.map(walk), is_header~)
      TableCell(children~, col_span~, row_span~) =>
        TableCell(children=children.map(walk), col_span~, row_span~)
      other => other
    }
  }

  walk(element)
}

///|
/// Assembles document bytes from a docx.batch/2 op stream exactly the way
/// the `docx batch` command does: per chunk, parse through the real batch
/// parser and build the body with the given image payloads; collect
/// comment and note specs; then write the annotated package through the
/// real writer. Shared by replay and the dump-time self-check, so a dump
/// the self-check accepts is exactly a stream this assembly can write.
fn docx_assemble_ops(
  ops : Array[Json],
  images : Map[String, Bytes],
) -> Bytes raise ReplayError {
  let body : Array[@document.DocumentElement] = []
  let comments : Array[@docx.CommentSpec] = []
  let footnotes : Array[@docx.NoteSpec] = []
  let endnotes : Array[@docx.NoteSpec] = []
  for chunk_index, chunk in docx_dump_op_chunks(ops) {
    let script = Json::object({
      "schema": Json::string(@docx_batch.SCHEMA_BATCH_V2),
      "ops": Json::array(chunk),
    })
    let parsed = @docx_batch.parse_batch(script) catch {
      @docx_batch.BatchError(message) =>
        raise ReplayFailed("op chunk \{chunk_index} does not parse: " + message)
    }
    let chunk_body = parsed.build_body(images) catch {
      @docx_batch.BatchError(message) =>
        raise ReplayFailed("op chunk \{chunk_index} does not build: " + message)
    }
    // offsets are captured BEFORE this chunk contributes anything: block
    // indexes in this chunk's comment anchors and note indexes in this
    // chunk's references are chunk-local and shift by what came before
    let block_offset = body.length()
    let footnote_offset = footnotes.length()
    let endnote_offset = endnotes.length()
    let comment_offset = comments.length()
    for element in chunk_body {
      if footnote_offset > 0 || endnote_offset > 0 {
        body.push(
          docx_offset_note_refs(element, footnote_offset, endnote_offset),
        )
      } else {
        body.push(element)
      }
    }
    let batch_footnotes = parsed.build_footnotes() catch {
      @docx_batch.BatchError(message) =>
        raise ReplayFailed(
          "op chunk \{chunk_index} footnotes do not build: " + message,
        )
    }
    for note in batch_footnotes {
      footnotes.push(
        @word.note_spec(note.body()) catch {
          error =>
            raise ReplayFailed(
              "op chunk \{chunk_index} footnote spec rejected: \{to_repr(error)}",
            )
        },
      )
    }
    let batch_endnotes = parsed.build_endnotes() catch {
      @docx_batch.BatchError(message) =>
        raise ReplayFailed(
          "op chunk \{chunk_index} endnotes do not build: " + message,
        )
    }
    for note in batch_endnotes {
      endnotes.push(
        @word.note_spec(note.body()) catch {
          error =>
            raise ReplayFailed(
              "op chunk \{chunk_index} endnote spec rejected: \{to_repr(error)}",
            )
        },
      )
    }
    let batch_comments = parsed.build_comments() catch {
      @docx_batch.BatchError(message) =>
        raise ReplayFailed(
          "op chunk \{chunk_index} comments do not build: " + message,
        )
    }
    for comment in batch_comments {
      let spec = match
        (comment.reply_to(), comment.from_block(), comment.to_block()) {
        (Some(parent), _, _) =>
          @word.comment_reply(
            author=comment.author(),
            initials?=comment.initials(),
            date?=comment.date(),
            reply_to=parent + comment_offset,
            done?=comment.done(),
            comment.body(),
          ) catch {
            error =>
              raise ReplayFailed(
                "op chunk \{chunk_index} comment reply rejected: \{to_repr(error)}",
              )
          }
        (None, Some(from), Some(to)) =>
          @word.comment_spec(
            author=comment.author(),
            initials?=comment.initials(),
            date?=comment.date(),
            from=from + block_offset,
            to=to + block_offset,
            done?=comment.done(),
            comment.body(),
          ) catch {
            error =>
              raise ReplayFailed(
                "op chunk \{chunk_index} comment spec rejected: \{to_repr(error)}",
              )
          }
        _ =>
          raise ReplayFailed(
            "op chunk \{chunk_index} produced a comment with neither anchor nor reply target",
          )
      }
      comments.push(spec)
    }
  }
  @word.write_docx_with_annotations(body, comments~, footnotes~, endnotes~) catch {
    error =>
      raise ReplayFailed("the writer rejected the assembly: \{to_repr(error)}")
  }
}

///|
/// Replays an `office.dump/1` DOCX envelope into document bytes: decode
/// the content-addressed assets, feed the ops through the shared assembly,
/// and return the written package. The batch schema is validated up front
/// so an empty op stream cannot bypass it.
pub fn replay_docx_dump(envelope : DumpEnvelope) -> Bytes raise ReplayError {
  guard envelope.format == "docx" else {
    raise ReplayInvalidFormat(
      "cannot replay a '\{envelope.format}' dump as docx",
    )
  }
  guard envelope.batch_schema == @docx_batch.SCHEMA_BATCH_V2 else {
    raise ReplayInvalidFormat(
      "unsupported batch schema '\{envelope.batch_schema}' (expected \{@docx_batch.SCHEMA_BATCH_V2})",
    )
  }
  let images : Map[String, Bytes] = {}
  for id, asset in envelope.assets {
    images[id] = @base64.decode(asset.data) catch {
      _ => raise ReplayInvalidFormat("asset \{id} payload is not valid base64")
    }
  }
  docx_assemble_ops(envelope.ops, images)
}
