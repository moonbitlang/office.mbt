///|
fn sample_document() -> @document.DocumentElement {
  @document.document([
    @document.paragraph(
      [
        @document.run(
          [@document.text("Bold "), @document.text("title")],
          properties=@document.run_properties(
            is_bold=true,
            font=Some("Arial"),
            font_size=Some(32),
          ),
        ),
      ],
      properties=@document.paragraph_properties(
        style_id=Some("Heading1"),
        style_name=Some("Heading 1"),
      ),
    ),
    @document.paragraph([
      @document.hyperlink(
        [@document.run([@document.text("a link")])],
        href=Some("https://example.com"),
      ),
    ]),
    @document.table([
      @document.table_row(
        [
          @document.table_cell([
            @document.paragraph([@document.run([@document.text("cell one")])]),
          ]),
          @document.table_cell(
            [
              @document.paragraph([
                @document.image("image/png", b"\x89PNG", alt_text=Some("dot")),
              ]),
            ],
            col_span=2,
          ),
        ],
        is_header=true,
      ),
    ]),
  ])
}

///|
test "text view tags every paragraph with its full path" {
  debug_inspect(
    @inspect.text_lines(sample_document()),
    content=(
      #|[
      #|  "[/body/p[1]] Bold title",
      #|  "[/body/p[2]] a link",
      #|  "[/body/tbl[1]/tr[1]/tc[1]/p[1]] cell one",
      #|  "[/body/tbl[1]/tr[1]/tc[2]/p[1]] ",
      #|]
    ),
  )
}

///|
test "element payload for the body lists addressable children" {
  json_inspect(
    @inspect.element(sample_document(), file="sample.docx", path="/body"),
    content={
      "schema": "docx.element/1",
      "file": "sample.docx",
      "path": "/body",
      "kind": "body",
      "children": [
        { "kind": "p", "path": "/body/p[1]" },
        { "kind": "p", "path": "/body/p[2]" },
        { "kind": "tbl", "path": "/body/tbl[1]" },
      ],
    },
  )
}

///|
test "element payload for a styled paragraph and its run" {
  json_inspect(
    @inspect.element(sample_document(), file="sample.docx", path="/body/p[1]"),
    content={
      "schema": "docx.element/1",
      "file": "sample.docx",
      "path": "/body/p[1]",
      "kind": "p",
      "text": "Bold title",
      "style_id": "Heading1",
      "style_name": "Heading 1",
      "children": [{ "kind": "r", "path": "/body/p[1]/r[1]" }],
    },
  )
  json_inspect(
    @inspect.element(
      sample_document(),
      file="sample.docx",
      path="/body/p[1]/r[1]",
    ),
    content={
      "schema": "docx.element/1",
      "file": "sample.docx",
      "path": "/body/p[1]/r[1]",
      "kind": "r",
      "text": "Bold title",
      "bold": true,
      "font": "Arial",
      "font_size": 32,
      "children": [],
    },
  )
}

///|
test "element payload for table parts, hyperlink, and image" {
  json_inspect(
    @inspect.element(
      sample_document(),
      file="s.docx",
      path="/body/tbl[1]/tr[1]",
    ),
    content={
      "schema": "docx.element/1",
      "file": "s.docx",
      "path": "/body/tbl[1]/tr[1]",
      "kind": "tr",
      "header": true,
      "children": [
        { "kind": "tc", "path": "/body/tbl[1]/tr[1]/tc[1]" },
        { "kind": "tc", "path": "/body/tbl[1]/tr[1]/tc[2]" },
      ],
    },
  )
  json_inspect(
    @inspect.element(
      sample_document(),
      file="s.docx",
      path="/body/tbl[1]/tr[1]/tc[2]",
    ),
    content={
      "schema": "docx.element/1",
      "file": "s.docx",
      "path": "/body/tbl[1]/tr[1]/tc[2]",
      "kind": "tc",
      "col_span": 2,
      "children": [{ "kind": "p", "path": "/body/tbl[1]/tr[1]/tc[2]/p[1]" }],
    },
  )
  json_inspect(
    @inspect.element(
      sample_document(),
      file="s.docx",
      path="/body/p[2]/hyperlink[1]",
    ),
    content={
      "schema": "docx.element/1",
      "file": "s.docx",
      "path": "/body/p[2]/hyperlink[1]",
      "kind": "hyperlink",
      "text": "a link",
      "href": "https://example.com",
      "children": [{ "kind": "r", "path": "/body/p[2]/hyperlink[1]/r[1]" }],
    },
  )
  json_inspect(
    @inspect.element(
      sample_document(),
      file="s.docx",
      path="/body/tbl[1]/tr[1]/tc[2]/p[1]/image[1]",
    ),
    content={
      "schema": "docx.element/1",
      "file": "s.docx",
      "path": "/body/tbl[1]/tr[1]/tc[2]/p[1]/image[1]",
      "kind": "image",
      "content_type": "image/png",
      "bytes": 4,
      "alt_text": "dot",
      "children": [],
    },
  )
}

///|
test "path indices normalize and count same-kind siblings only" {
  // `p[02]` normalizes to `p[2]`; the hyperlink between the paragraphs does
  // not consume a `p` index.
  json_inspect(
    @inspect.element(sample_document(), file="s.docx", path="/body/p[02]"),
    content={
      "schema": "docx.element/1",
      "file": "s.docx",
      "path": "/body/p[2]",
      "kind": "p",
      "text": "a link",
      "children": [{ "kind": "hyperlink", "path": "/body/p[2]/hyperlink[1]" }],
    },
  )
}

///|
fn expect_path_error(path : String, expected_prefix : String) -> Unit raise {
  try @inspect.element(sample_document(), file="s.docx", path~) catch {
    @inspect.PathError(message) =>
      if !message.has_prefix(expected_prefix) {
        fail("unexpected message: \{message}")
      }
  } noraise {
    _ => fail("expected PathError for \{path}")
  }
}

///|
test "path errors are agent-correctable" {
  expect_path_error(
    "body/p[1]", "invalid path 'body/p[1]': a path starts with '/'",
  )
  expect_path_error(
    "/document/p[1]", "invalid path '/document/p[1]': unknown root",
  )
  expect_path_error("/header[1]/p[1]", "path root '/header[1]' is reserved")
  expect_path_error("/footnotes/note[1]", "path root '/footnotes' is reserved")
  expect_path_error("/body/para[1]", "invalid path segment 'para[1]'")
  expect_path_error("/body/p[0]", "invalid path segment 'p[0]'")
  expect_path_error("/body/p[x]", "invalid path segment 'p[x]'")
  expect_path_error("/body/p", "invalid path segment 'p'")
  expect_path_error(
    "/body/p[9]", "path '/body/p[9]' not found: '/body' has 2 'p' children (wanted index 9)",
  )
  expect_path_error(
    "/body/tbl[1]/tr[1]/tc[1]/image[1]", "path '/body/tbl[1]/tr[1]/tc[1]/image[1]' not found: '/body/tbl[1]/tr[1]/tc[1]' has 0 'image' children",
  )
}

///|
test "resolve_path returns the element itself" {
  let element = @inspect.resolve_path(sample_document(), "/body/tbl[1]")
  guard element is Table(..)
}

///|
test "numbering surfaces on paragraph payloads; text view stays one line" {
  let doc = @document.document([
    @document.paragraph(
      [@document.run([@document.text("item")])],
      properties=@document.paragraph_properties(
        numbering=Some(@document.numbering(true, 1)),
      ),
    ),
    @document.paragraph([@document.run([@document.text("line one\nline two")])]),
  ])
  json_inspect(@inspect.element(doc, file="list.docx", path="/body/p[1]"), content={
    "schema": "docx.element/1",
    "file": "list.docx",
    "path": "/body/p[1]",
    "kind": "p",
    "text": "item",
    "numbering": { "ordered": true, "level": 1 },
    "children": [{ "kind": "r", "path": "/body/p[1]/r[1]" }],
  })
  // A literal newline inside w:t is flattened in the line-oriented view
  // (get still returns the raw text).
  debug_inspect(
    @inspect.text_lines(doc)[1],
    content=(
      #|"[/body/p[2]] line one line two"
    ),
  )
}
