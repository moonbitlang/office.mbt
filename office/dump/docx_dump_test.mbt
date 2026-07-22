///|
/// Assembles docx bytes from a batch script exactly the way the `docx
/// batch` command does: build the body with the given image payloads,
/// map comment and note ops to writer specs, and write the annotated
/// package.
fn docx_assemble(ops : Array[Json], images : Map[String, Bytes]) -> Bytes raise {
  let parsed = @docx_batch.parse_batch(
    Json::object({
      "schema": Json::string("docx.batch/2"),
      "ops": Json::array(ops),
    }),
  )
  let body = parsed.build_body(images)
  let comments = []
  for comment in parsed.build_comments() {
    match (comment.reply_to(), comment.from_block(), comment.to_block()) {
      (Some(parent), _, _) =>
        comments.push(
          @word.comment_reply(
            author=comment.author(),
            initials?=comment.initials(),
            date?=comment.date(),
            reply_to=parent,
            done?=comment.done(),
            comment.body(),
          ),
        )
      (None, Some(from), Some(to)) =>
        comments.push(
          @word.comment_spec(
            author=comment.author(),
            initials?=comment.initials(),
            date?=comment.date(),
            from~,
            to~,
            done?=comment.done(),
            comment.body(),
          ),
        )
      _ => fail("comment without anchor or reply target")
    }
  }
  let footnotes = []
  for note in parsed.build_footnotes() {
    footnotes.push(@word.note_spec(note.body()))
  }
  let endnotes = []
  for note in parsed.build_endnotes() {
    endnotes.push(@word.note_spec(note.body()))
  }
  @word.write_docx_with_annotations(body, comments~, footnotes~, endnotes~)
}

///|
/// Re-dumps the ops through the real batch build path and asserts the op
/// stream is a fixpoint: parse → build → write bytes → read → dump, with
/// the envelope's assets injected as the image payloads.
fn docx_fixpoint_ops(envelope : @dump.DumpEnvelope) -> Array[Json] raise {
  let images : Map[String, Bytes] = {}
  for id, asset in envelope.assets {
    images[id] = @b64.decode(asset.data)
  }
  let bytes = docx_assemble(envelope.ops, images)
  let annotated = @word.read_docx_annotated(bytes[:])
  let redump = @dump.dump_docx_document(
    annotated,
    source_file="fixpoint.docx",
    source_bytes=bytes.length(),
  )
  redump.ops
}

///|
test "docx paragraphs and runs dump and fixpoint" {
  let body : Array[@document.DocumentElement] = [
    @document.paragraph(
      [
        @document.run(
          [@document.text("Quarterly Report")],
          properties=@document.run_properties(is_bold=true),
        ),
      ],
      properties=@document.paragraph_properties(
        style_id=Some("Heading1"),
        alignment=Some("center"),
      ),
    ),
    @document.paragraph([
      @document.run([@document.text("Plain intro with a ")]),
      @document.Hyperlink(
        children=[@document.run([@document.text("link")])],
        href=Some("https://example.com/"),
        anchor=None,
        target_frame=None,
      ),
      @document.run(
        [@document.text(" and emphasis")],
        properties=@document.run_properties(is_italic=true),
      ),
    ]),
  ]
  let bytes = @word.write_docx(body)
  let annotated = @word.read_docx_annotated(bytes[:])
  let envelope = @dump.dump_docx_document(
    annotated,
    source_file="para.docx",
    source_bytes=bytes.length(),
  )
  assert_eq(envelope.format, "docx")
  assert_eq(envelope.batch_schema, "docx.batch/2")
  assert_eq(envelope.ops.length(), 2)
  let document = envelope.to_json_document().stringify()
  assert_true(document.contains("\"op\":\"paragraph\""))
  assert_true(document.contains("\"style\":\"Heading1\""))
  assert_true(document.contains("\"align\":\"center\""))
  assert_true(document.contains("\"bold\":true"))
  assert_true(document.contains("\"italic\":true"))
  assert_true(document.contains("\"href\":\"https://example.com/\""))
  // the writer always emits a default section; that is disclosed, and
  // nothing else about this body is lossy
  for entry in envelope.residual {
    assert_eq(entry.code, "docx.sections_not_dumped")
  }
  assert_eq(
    Json::array(envelope.ops).stringify(),
    Json::array(docx_fixpoint_ops(envelope)).stringify(),
  )
}

///|
test "docx tables dump with spans and header rows" {
  let cell = (text : String) => {
    @document.TableCell(
      children=[@document.paragraph([@document.run([@document.text(text)])])],
      col_span=1,
      row_span=1,
    )
  }
  let body : Array[@document.DocumentElement] = [
    @document.Table(
      children=[
        @document.TableRow(children=[cell("H1"), cell("H2")], is_header=true),
        @document.TableRow(
          children=[
            @document.TableCell(
              children=[
                @document.paragraph([@document.run([@document.text("wide")])]),
              ],
              col_span=2,
              row_span=1,
            ),
          ],
          is_header=false,
        ),
      ],
      properties=@document.TableProperties::{ style_id: None, style_name: None },
    ),
  ]
  let bytes = @word.write_docx(body)
  let annotated = @word.read_docx_annotated(bytes[:])
  let envelope = @dump.dump_docx_document(
    annotated,
    source_file="table.docx",
    source_bytes=bytes.length(),
  )
  assert_eq(envelope.ops.length(), 1)
  let document = envelope.to_json_document().stringify()
  assert_true(document.contains("\"op\":\"table\""))
  assert_true(document.contains("\"header_rows\":1"))
  assert_true(document.contains("\"col_span\":2"))
  assert_eq(
    Json::array(envelope.ops).stringify(),
    Json::array(docx_fixpoint_ops(envelope)).stringify(),
  )
}

///|
test "docx tab text survives the round trip" {
  let body : Array[@document.DocumentElement] = [
    @document.paragraph([
      @document.run([
        @document.text("before"),
        @document.tab(),
        @document.text("after"),
      ]),
    ]),
  ]
  let bytes = @word.write_docx(body)
  let annotated = @word.read_docx_annotated(bytes[:])
  let envelope = @dump.dump_docx_document(
    annotated,
    source_file="tab.docx",
    source_bytes=bytes.length(),
  )
  let document = envelope.to_json_document().stringify()
  assert_true(document.contains("before\\tafter"))
  for entry in envelope.residual {
    assert_eq(entry.code, "docx.sections_not_dumped")
  }
  assert_eq(
    Json::array(envelope.ops).stringify(),
    Json::array(docx_fixpoint_ops(envelope)).stringify(),
  )
}

///|
test "docx images ride as assets and survive the fixpoint" {
  let payload : Bytes = b"\x89\x50\x4e\x47\x0d\x0a\x1a\x0a\x00\x00\x00\x0d\x49\x48\x44\x52\x00\x00\x00\x01\x00\x00\x00\x01\x08\x06\x00\x00\x00\x1f\x15\xc4\x89\x00\x00\x00\x0d\x49\x44\x41\x54\x78\x9c\x63\xf8\xcf\xc0\xf0\x1f\x00\x05\x00\x01\xff\x89\x99\x3d\x1d\x00\x00\x00\x00\x49\x45\x4e\x44\xae\x42\x60\x82"
  let body : Array[@document.DocumentElement] = [
    @document.paragraph([
      @document.run(
        [@document.text("logo: ")],
        properties=@document.run_properties(is_bold=true),
      ),
      @document.run([
        @document.Image(@document.Image::{
          content_type: "image/png",
          alt_text: Some("the logo"),
          data: payload,
        }),
      ]),
    ]),
  ]
  let bytes = @word.write_docx(body)
  let annotated = @word.read_docx_annotated(bytes[:])
  let d1 = @dump.dump_docx_document(
    annotated,
    source_file="img.docx",
    source_bytes=bytes.length(),
  )
  let document = d1.to_json_document().stringify()
  assert_true(document.contains("\"image\":"))
  assert_true(document.contains("sha256-"))
  assert_true(document.contains("the logo"))
  assert_eq(d1.assets.size(), 1)
  assert_false(document.contains("docx.images_not_dumped"))
  let d2_ops = docx_fixpoint_ops(d1)
  assert_eq(Json::array(d1.ops).stringify(), Json::array(d2_ops).stringify())
}

///|
test "docx footnotes dump their bodies and survive the fixpoint" {
  let script_ops : Array[Json] = [
    Json::object({
      "op": Json::string("paragraph"),
      "params": Json::object({
        "runs": Json::array([
          Json::object({ "text": Json::string("claim") }),
          Json::object({
            "footnote": Json::object({
              "paragraphs": Json::array([
                Json::object({
                  "runs": Json::array([
                    Json::object({
                      "text": Json::string("supporting source"),
                      "italic": Json::boolean(true),
                    }),
                  ]),
                }),
              ]),
            }),
          }),
        ]),
      }),
    }),
  ]
  let bytes = docx_assemble(script_ops, {})
  let annotated = @word.read_docx_annotated(bytes[:])
  let d1 = @dump.dump_docx_document(
    annotated,
    source_file="fn.docx",
    source_bytes=bytes.length(),
  )
  let document = d1.to_json_document().stringify()
  assert_true(document.contains("\"footnote\":"))
  assert_true(document.contains("supporting source"))
  assert_false(document.contains("docx.note_body_missing"))
  assert_false(document.contains("docx.note_orphaned"))
  let d2_ops = docx_fixpoint_ops(d1)
  assert_eq(Json::array(d1.ops).stringify(), Json::array(d2_ops).stringify())
}

///|
test "docx comments anchor, thread, and survive the fixpoint" {
  let script_ops : Array[Json] = [
    Json::object({
      "op": Json::string("paragraph"),
      "params": Json::object({ "text": Json::string("first block") }),
    }),
    Json::object({
      "op": Json::string("paragraph"),
      "params": Json::object({ "text": Json::string("second block") }),
    }),
    Json::object({
      "op": Json::string("comment"),
      "params": Json::object({
        "on": Json::number(0),
        "author": Json::string("Reviewer"),
        "initials": Json::string("RV"),
        "date": Json::string("2026-07-22T10:00:00Z"),
        "done": Json::boolean(false),
        "text": Json::string("please check"),
      }),
    }),
    Json::object({
      "op": Json::string("comment"),
      "params": Json::object({
        "reply_to": Json::number(2),
        "author": Json::string("Author"),
        "text": Json::string("checked"),
      }),
    }),
  ]
  let bytes = docx_assemble(script_ops, {})
  let annotated = @word.read_docx_annotated(bytes[:])
  let d1 = @dump.dump_docx_document(
    annotated,
    source_file="cm.docx",
    source_bytes=bytes.length(),
  )
  let document = d1.to_json_document().stringify()
  let mut comment_ops = 0
  for op in d1.ops {
    if op.stringify().contains("\"op\":\"comment\"") {
      comment_ops += 1
    }
  }
  assert_eq(comment_ops, 2)
  assert_true(document.contains("please check"))
  assert_true(document.contains("checked"))
  assert_true(document.contains("\"reply_to\":"))
  assert_true(document.contains("Reviewer"))
  // the date must ride in the OP, not merely appear in a residual detail
  assert_true(document.contains("\"date\":\"2026-07-22T10:00:00Z\""))
  assert_false(document.contains("docx.comment_metadata_dropped"))
  assert_false(document.contains("docx.comment_dropped"))
  assert_false(document.contains("docx.comments_not_dumped"))
  let d2_ops = docx_fixpoint_ops(d1)
  assert_eq(Json::array(d1.ops).stringify(), Json::array(d2_ops).stringify())
}
