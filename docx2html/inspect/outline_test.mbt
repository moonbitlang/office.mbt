///|
test "outline of an empty document has zeroed counts and empty inventories" {
  json_inspect(@inspect.outline(@document.document([]), file="empty.docx"), content={
    "schema": "docx.outline/1",
    "file": "empty.docx",
    "counts": {
      "paragraphs": 0,
      "tables": 0,
      "images": 0,
      "hyperlinks": 0,
      "bookmarks": 0,
      "footnotes": 0,
      "endnotes": 0,
      "comments": 0,
      "headers": 0,
      "footers": 0,
      "sections": 0,
    },
    "headings": [],
    "styles_in_use": [],
    "images": [],
    "sections": [],
    "messages": [],
  })
}

///|
test "outline counts body content including inside table cells" {
  let doc = @document.document(
    [
      @document.paragraph(
        [@document.run([@document.text("Report")])],
        properties=@document.paragraph_properties(
          style_id=Some("Heading1"),
          style_name=Some("Heading 1"),
        ),
      ),
      @document.paragraph([
        @document.hyperlink(
          [@document.run([@document.text("link")])],
          href=Some("https://example.com"),
        ),
        @document.bookmark_start("anchor"),
      ]),
      @document.table([
        @document.table_row([
          @document.table_cell([
            @document.paragraph([@document.run([@document.text("cell")])]),
            @document.paragraph([
              @document.image("image/png", b"\x89PNG!", alt_text=Some("dot")),
            ]),
          ]),
        ]),
      ]),
    ],
    notes=[
      @document.note("footnote", "1", [
        @document.paragraph([@document.run([@document.text("note body")])]),
      ]),
      @document.note("endnote", "2", []),
    ],
    comments=[@document.comment("c1", [], author_name="Reviewer")],
  )
  let payload = @inspect.outline(doc, file="report.docx", messages=[
    @core.warning("An unrecognised element was ignored: w:sdt"),
  ])
  json_inspect(payload, content={
    "schema": "docx.outline/1",
    "file": "report.docx",
    "counts": {
      "paragraphs": 4,
      "tables": 1,
      "images": 1,
      "hyperlinks": 1,
      "bookmarks": 1,
      "footnotes": 1,
      "endnotes": 1,
      "comments": 1,
      "headers": 0,
      "footers": 0,
      "sections": 0,
    },
    "headings": [
      {
        "level": 1,
        "text": "Report",
        "style_id": "Heading1",
        "style_name": "Heading 1",
      },
    ],
    "styles_in_use": [
      { "kind": "paragraph", "id": "Heading1", "name": "Heading 1" },
    ],
    "images": [{ "content_type": "image/png", "bytes": 5 }],
    "sections": [],
    "messages": [
      {
        "severity": "warning",
        "text": "An unrecognised element was ignored: w:sdt",
      },
    ],
  })
}

///|
test "heading detection follows the Mammoth default style-map convention" {
  fn styled_paragraph(
    label : String,
    style_id : String?,
    style_name : String?,
  ) -> @document.DocumentElement {
    @document.paragraph(
      [@document.run([@document.text(label)])],
      properties=@document.paragraph_properties(style_id~, style_name~),
    )
  }

  let doc = @document.document([
    styled_paragraph("by id", Some("Heading3"), None),
    styled_paragraph("by name", None, Some("Heading 2")),
    styled_paragraph("shouty name", None, Some("HEADING 3")),
    styled_paragraph("lowercase name", None, Some("heading 6")),
    styled_paragraph("bare heading id", Some("Heading"), None),
    styled_paragraph("bare heading name", None, Some("Heading")),
    styled_paragraph(
      "digit name beats bare id",
      Some("Heading"),
      Some("Heading 3"),
    ),
    styled_paragraph(
      "digit id beats digit name",
      Some("Heading2"),
      Some("Heading 5"),
    ),
    styled_paragraph("beyond mammoth", Some("Heading7"), None),
    styled_paragraph("two digits", Some("Heading10"), Some("Heading 10")),
    styled_paragraph("not a heading", Some("BodyText"), Some("Body Text")),
    styled_paragraph("name needs the space", None, Some("Heading2")),
    styled_paragraph("", Some("Heading1"), None),
  ])
  let payload = @inspect.outline(doc, file="headings.docx")
  guard payload is Object(fields) && fields.get("headings") is Some(headings)
  json_inspect(headings, content=[
    { "level": 3, "text": "by id", "style_id": "Heading3" },
    { "level": 2, "text": "by name", "style_name": "Heading 2" },
    { "level": 3, "text": "shouty name", "style_name": "HEADING 3" },
    { "level": 6, "text": "lowercase name", "style_name": "heading 6" },
    { "level": 1, "text": "bare heading id", "style_id": "Heading" },
    { "level": 1, "text": "bare heading name", "style_name": "Heading" },
    {
      "level": 3,
      "text": "digit name beats bare id",
      "style_id": "Heading",
      "style_name": "Heading 3",
    },
    {
      "level": 2,
      "text": "digit id beats digit name",
      "style_id": "Heading2",
      "style_name": "Heading 5",
    },
  ])
}

///|
test "field hyperlinks count one span per wrapped run" {
  // The reader wraps each run of a complex-field HYPERLINK in its own
  // Hyperlink node (the HTML pipeline merges adjacent ones on render). The
  // outline counts parsed link SPANS — pinned here so the documented caveat
  // (count can exceed rendered <a> elements) stays true to the code.
  let href = Some("https://example.com/x")
  let doc = @document.document([
    @document.paragraph([
      @document.run([@document.hyperlink([@document.text("part one")], href~)]),
      @document.run([@document.hyperlink([@document.text("part two")], href~)]),
    ]),
  ])
  let payload = @inspect.outline(doc, file="fields.docx")
  guard payload is Object(fields) && fields.get("counts") is Some(counts)
  guard counts is Object(count_fields) &&
    count_fields.get("hyperlinks") is Some(hyperlinks)
  json_inspect(hyperlinks, content=2)
}

///|
test "styles_in_use dedupes by kind and records first-use order" {
  let heading = @document.paragraph_properties(style_id=Some("Heading1"))
  let doc = @document.document([
    @document.paragraph(
      [
        @document.run(
          [@document.text("styled run")],
          properties=@document.run_properties(style_name=Some("Strong")),
        ),
      ],
      properties=heading,
    ),
    @document.paragraph([], properties=heading),
    @document.table(
      [],
      properties=@document.table_properties(style_id=Some("TableGrid")),
    ),
  ])
  let payload = @inspect.outline(doc, file="styles.docx")
  guard payload is Object(fields) && fields.get("styles_in_use") is Some(styles)
  json_inspect(styles, content=[
    { "kind": "paragraph", "id": "Heading1" },
    { "kind": "run", "name": "Strong" },
    { "kind": "table", "id": "TableGrid" },
  ])
}

///|
test "reader errors surface with error severity" {
  let payload = @inspect.outline(@document.document([]), file="bad.docx", messages=[
    @core.error("broken relationship"),
  ])
  guard payload is Object(fields) && fields.get("messages") is Some(messages)
  json_inspect(messages, content=[
    { "severity": "error", "text": "broken relationship" },
  ])
}
