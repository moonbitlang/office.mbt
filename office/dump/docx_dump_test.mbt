///|
/// Re-dumps the ops through the real batch build path and asserts the op
/// stream is a fixpoint: parse → build body → write bytes → read → dump.
fn docx_fixpoint_ops(envelope : @dump.DumpEnvelope) -> Array[Json] raise {
  let script = Json::object({
    "schema": Json::string("docx.batch/2"),
    "ops": Json::array(envelope.ops),
  })
  let parsed = @docx_batch.parse_batch(script)
  let body = parsed.build_body({})
  let bytes = @word.write_docx(body)
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
