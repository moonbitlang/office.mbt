///|
/// Writes `bytes` to a temp file and validates it with the Microsoft
/// DocumentFormat.OpenXml SDK (via scripts/validate_docx.sh in the
/// workspace root — docx2html tests run with the member directory as cwd),
/// failing with the validator output when the package is not schema-valid.
async fn validate_docx_via_sdk(
  dir : String,
  name : String,
  bytes : Bytes,
) -> Unit {
  let path = "\{dir}/\{name}.docx"
  @afs.write_file(path, bytes, create_mode=CreateOrTruncate) catch {
    err => fail("write \{name} failed: \{err}")
  }
  let (code, stdout, stderr) = @process.collect_output("bash", [
    "-lc",
    "../scripts/validate_docx.sh \"\{path}\"",
  ])
  if code != 0 {
    let out = stdout.text() catch { _ => "<non-utf8 stdout>" }
    let err = stderr.text() catch { _ => "<non-utf8 stderr>" }
    fail(
      "OpenXML SDK validation failed for \{name} (exit=\{code})\nstdout:\n\{out}\nstderr:\n\{err}",
    )
  }
  @afs.remove(path) catch {
    _ => ()
  }
}

///|
/// Creates a fresh scratch directory. The millisecond stamp alone can
/// collide when two workspaces run this test simultaneously, so an
/// exclusive (non-recursive) mkdir retries with a suffix instead of
/// failing on EEXIST.
async fn fresh_scratch_dir() -> String {
  @afs.mkdir("_build") catch {
    _ => ()
  }
  @afs.mkdir("_build/docx_sdk_validity") catch {
    _ => ()
  }
  let stamp = @env.now()
    .to_string()
    .replace(old=":", new="_")
    .replace(old=" ", new="_")
  for attempt in 0..<100 {
    let candidate = "_build/docx_sdk_validity/\{stamp}_\{attempt}"
    let created = try {
      @afs.mkdir(candidate)
      true
    } catch {
      _ => false
    }
    if created {
      return candidate
    }
  }
  fail("could not create a fresh scratch directory")
}

///|
/// Schema-validates representative docx bytes through the real Microsoft
/// OpenXML SDK — the authoritative complement to the portable structural
/// tier behind `docx validate`. Covers the committed reader fixtures and
/// the repo's one write path (`embed_style_map`), so any packaging
/// regression in the re-zip surfaces here.
async test "docx fixtures and embed_style_map output are Microsoft OpenXML schema-valid" {
  let dir = fresh_scratch_dir()
  let single_paragraph = @afs.read_file(
    "tests/cram/fixtures/single-paragraph.docx",
  ).binary()
  let tiny_picture = @afs.read_file("tests/cram/fixtures/tiny-picture.docx").binary()
  let header_footer = @afs.read_file("tests/cram/fixtures/header-footer.docx").binary()
  validate_docx_via_sdk(dir, "single_paragraph", single_paragraph)
  validate_docx_via_sdk(dir, "tiny_picture", tiny_picture)
  validate_docx_via_sdk(dir, "header_footer", header_footer)
  validate_docx_via_sdk(dir, "blank_document", @docx2html.new_blank_docx())
  let written = @docx2html.write_docx([
    @docx2html.paragraph(
      [@docx2html.run([@docx2html.text("Written heading")])],
      properties=@docx2html.paragraph_properties(style_id=Some("Heading2")),
    ),
    @docx2html.paragraph([
      @docx2html.run(
        [@docx2html.text("Body "), @docx2html.text("text")],
        properties=@docx2html.run_properties(is_bold=true, font_size=Some(12)),
      ),
    ]),
  ])
  validate_docx_via_sdk(dir, "written_paragraphs", written)
  // Every rPr property at once + heading + alignment: CT_RPr is an enforced
  // child sequence, and this all-flags body is what exposes ordering
  // regressions the structural tier cannot see (review finding on F1).
  let all_flags = @docx2html.write_docx([
    @docx2html.paragraph(
      [
        @docx2html.run(
          [@docx2html.text("Every flag at once")],
          properties=@docx2html.run_properties(
            is_bold=true,
            is_italic=true,
            is_underline=true,
            is_strikethrough=true,
            is_all_caps=true,
            is_small_caps=true,
            vertical_alignment=Superscript,
            font=Some("Arial"),
            font_size=Some(11),
            highlight=Some("yellow"),
          ),
        ),
      ],
      properties=@docx2html.paragraph_properties(
        style_id=Some("Heading1"),
        alignment=Some("center"),
      ),
    ),
    @docx2html.paragraph(
      [
        @docx2html.run(
          [@docx2html.text("italic with font and size")],
          properties=@docx2html.run_properties(
            is_italic=true,
            font=Some("Arial"),
            font_size=Some(14),
          ),
        ),
      ],
      properties=@docx2html.paragraph_properties(alignment=Some("distribute")),
    ),
  ])
  validate_docx_via_sdk(dir, "written_all_flags", all_flags)
  // F2: a span-heavy table (header row, gridSpan, vMerge restart +
  // synthesized continuations) through the real schema validator — CT_Tbl,
  // CT_TrPr, and CT_TcPr are enforced sequences like CT_RPr was.
  let table = @docx2html.write_docx([
    @docx2html.table([
      @docx2html.table_row(
        [
          @docx2html.table_cell([
            @docx2html.paragraph([@docx2html.run([@docx2html.text("H1")])]),
          ]),
          @docx2html.table_cell([
            @docx2html.paragraph([@docx2html.run([@docx2html.text("H2")])]),
          ]),
        ],
        is_header=true,
      ),
      @docx2html.table_row([
        @docx2html.table_cell(
          [@docx2html.paragraph([@docx2html.run([@docx2html.text("tall")])])],
          row_span=2,
        ),
        @docx2html.table_cell([
          @docx2html.paragraph([@docx2html.run([@docx2html.text("r1")])]),
        ]),
      ]),
      @docx2html.table_row([
        @docx2html.table_cell([
          @docx2html.paragraph([@docx2html.run([@docx2html.text("r2")])]),
        ]),
      ]),
      @docx2html.table_row([
        @docx2html.table_cell(
          [@docx2html.paragraph([@docx2html.run([@docx2html.text("wide")])])],
          col_span=2,
        ),
      ]),
    ]),
  ])
  validate_docx_via_sdk(dir, "written_table", table)
  // F3: ordered + unordered lists at several levels — CT_Numbering/CT_Lvl
  // are enforced sequences like CT_RPr was.
  let lists = @docx2html.write_docx([
    @docx2html.paragraph(
      [@docx2html.run([@docx2html.text("one")])],
      properties=@docx2html.paragraph_properties(
        numbering=Some(@docx2html.numbering(true, 1)),
      ),
    ),
    @docx2html.paragraph(
      [@docx2html.run([@docx2html.text("bullet")])],
      properties=@docx2html.paragraph_properties(
        numbering=Some(@docx2html.numbering(false, 3)),
      ),
    ),
    @docx2html.paragraph(
      [@docx2html.run([@docx2html.text("deep")])],
      properties=@docx2html.paragraph_properties(
        numbering=Some(@docx2html.numbering(true, 9)),
      ),
    ),
  ])
  validate_docx_via_sdk(dir, "written_lists", lists)
  // F4: hyperlinks (external rel + anchor) and an inline DrawingML picture
  // — wp:inline/pic:pic are enforced sequences and the media part, its
  // content-type default, and the r:embed relationship must all line up.
  let tiny_png = @afs.read_file("tests/cram/fixtures/tiny-picture.docx").binary()
  let png = @docx2html.read_docx_package(tiny_png)
  let mut image_bytes : Bytes = b""
  fn find_image(element : @docx2html.DocumentElement) -> Unit {
    match element {
      Image(image) => image_bytes = image.data
      Document(children~, ..) | Paragraph(children~, ..) | Run(children~, ..) =>
        for child in children {
          find_image(child)
        }
      _ => ()
    }
  }
  find_image(png.document)
  let media = @docx2html.write_docx([
    @docx2html.paragraph([
      @docx2html.hyperlink(
        [@docx2html.run([@docx2html.text("site")])],
        href=Some("https://example.com/x?y=1&z=2"),
      ),
      @docx2html.hyperlink(
        [@docx2html.run([@docx2html.text("go")])],
        anchor=Some("top"),
      ),
    ]),
    @docx2html.paragraph([
      @docx2html.run([
        @docx2html.image("image/png", image_bytes, alt_text=Some("dot")),
      ]),
    ]),
  ])
  validate_docx_via_sdk(dir, "written_media", media)
  let restyled = @docx2html.embed_style_map(single_paragraph, "p => h1:fresh")
  validate_docx_via_sdk(dir, "embedded_style_map", restyled)
}

///|
/// End-to-end gate for the `docx batch` surface: a script exercising every
/// batch op and run spec (styles, flags, link, list levels, spanned table,
/// inline image) must build a package the Microsoft SDK accepts. The batch
/// package's own tests pin parsing; this pins that the surface COMPOSES
/// into schema-valid OOXML (enforced-sequence regressions surface here).
async test "a full-surface docx.batch/1 script is Microsoft OpenXML schema-valid" {
  let dir = fresh_scratch_dir()
  let tiny_png = @afs.read_file("tests/cram/fixtures/tiny-picture.docx").binary()
  let png = @docx2html.read_docx_package(tiny_png)
  let mut image_bytes : Bytes = b""
  fn find_image(element : @docx2html.DocumentElement) -> Unit {
    match element {
      Image(image) => image_bytes = image.data
      Document(children~, ..) | Paragraph(children~, ..) | Run(children~, ..) =>
        for child in children {
          find_image(child)
        }
      _ => ()
    }
  }
  find_image(png.document)
  let script = @batch.parse_batch(
    @json.parse(
      (
        #|{
        #|  "schema": "docx.batch/1",
        #|  "ops": [
        #|    {"op": "paragraph", "params": {"text": "Title", "style": "Heading1"}},
        #|    {"op": "paragraph", "params": {"align": "center", "runs": [
        #|      {"text": "flags", "bold": true, "italic": true, "underline": true,
        #|       "strike": true, "all_caps": true, "font": "Arial", "size": 14,
        #|       "highlight": "yellow"},
        #|      {"text": "small", "small_caps": true},
        #|      {"text": "sup", "vertical": "superscript"},
        #|      {"text": "sub", "vertical": "subscript"},
        #|      {"link": {"href": "https://example.com/a?b=1&c=2", "text": "site"}},
        #|      {"link": {"anchor": "top", "target_frame": "_blank", "runs": [{"text": "up", "bold": true}]}},
        #|      {"image": {"path": "dot.png", "content_type": "image/png", "alt": "a dot"}}
        #|    ]}},
        #|    {"op": "paragraph", "params": {"text": "one", "list": {"ordered": true}}},
        #|    {"op": "paragraph", "params": {"text": "deep", "list": {"ordered": false, "level": 9}}},
        #|    {"op": "table", "params": {"header_rows": 1, "rows": [
        #|      [{"text": "H1"}, {"text": "H2"}],
        #|      [{"text": "wide", "col_span": 2}],
        #|      [{"text": "tall", "row_span": 2}, {"paragraphs": [{"text": "a"}, {"text": "b"}]}],
        #|      [{"text": "x"}]
        #|    ]}}
        #|  ]
        #|}
      ),
    ),
  )
  let body = script.build_body({ "dot.png": image_bytes })
  validate_docx_via_sdk(dir, "batch_full_surface", @docx2html.write_docx(body))
}

///|
/// Phase-2 J1: the annotated-comments CONFORMANCE fixture must be
/// Microsoft-schema-valid AND the annotation index must read it back with
/// the plan's semantics. (The tolerant-reader NEGATIVE fixtures live in
/// docx/annotation_index_wbtest.mbt and are deliberately not SDK-green.)
async test "a commented document is schema-valid and the annotation index reads it back" {
  let dir = fresh_scratch_dir()
  let document =
    #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:body>
    #|<w:p><w:r><w:t>plain</w:t></w:r></w:p>
    #|<w:p><w:commentRangeStart w:id="0"/><w:r><w:t>first half</w:t></w:r></w:p>
    #|<w:p><w:r><w:t>second half</w:t></w:r><w:commentRangeEnd w:id="0"/><w:r><w:rPr><w:rStyle w:val="CommentReference"/></w:rPr><w:commentReference w:id="0"/></w:r></w:p>
    #|<w:p><w:r><w:commentReference w:id="1"/></w:r><w:r><w:footnoteReference w:id="2"/></w:r></w:p>
    #|<w:tbl><w:tblPr><w:tblW w:w="0" w:type="auto"/></w:tblPr><w:tblGrid><w:gridCol/></w:tblGrid><w:tr><w:tc><w:tcPr><w:tcW w:w="0" w:type="auto"/></w:tcPr><w:p><w:commentRangeStart w:id="5"/><w:r><w:t>cell</w:t></w:r><w:commentRangeEnd w:id="5"/><w:r><w:commentReference w:id="5"/></w:r></w:p></w:tc></w:tr></w:tbl>
    #|<w:sectPr><w:pgSz w:w="12240" w:h="15840"/></w:sectPr>
    #|</w:body>
    #|</w:document>
  let styles =
    #|<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:style w:type="paragraph" w:styleId="Normal" w:default="1"><w:name w:val="Normal"/></w:style>
    #|<w:style w:type="character" w:styleId="CommentReference"><w:name w:val="annotation reference"/></w:style>
    #|</w:styles>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="w14">
    #|<w:comment w:id="0" w:author="Ada" w:initials="A" w:date="2026-07-11T01:00:00Z"><w:p w14:paraId="1AAA0001"><w:r><w:t>range note</w:t></w:r></w:p><w:p w14:paraId="1AAA0002"><w:r><w:t>more</w:t></w:r></w:p></w:comment>
    #|<w:comment w:id="1" w:author="Bob"><w:p w14:paraId="1BBB0001"><w:r><w:t>point note</w:t></w:r></w:p></w:comment>
    #|<w:comment w:id="3" w:author="Cid"><w:p w14:paraId="1CCC0001"><w:r><w:t>reply</w:t></w:r></w:p></w:comment>
    #|<w:comment w:id="5" w:author="Dee"><w:p><w:r><w:t>about the cell</w:t></w:r></w:p></w:comment>
    #|</w:comments>
  let extended =
    #|<w15:commentsEx xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="w15">
    #|<w15:commentEx w15:paraId="1AAA0002" w15:done="0"/>
    #|<w15:commentEx w15:paraId="1CCC0001" w15:paraIdParent="1AAA0002" w15:done="1"/>
    #|</w15:commentsEx>
  let footnotes =
    #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:footnote w:type="separator" w:id="-1"><w:p><w:r><w:separator/></w:r></w:p></w:footnote>
    #|<w:footnote w:type="continuationSeparator" w:id="0"><w:p><w:r><w:continuationSeparator/></w:r></w:p></w:footnote>
    #|<w:footnote w:id="2"><w:p><w:r><w:t>the footnote</w:t></w:r></w:p></w:footnote>
    #|</w:footnotes>
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_override(
    "/word/styles.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml",
  )
  builder.add_override(
    "/word/comments.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml",
  )
  builder.add_override(
    "/word/commentsExtended.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.commentsExtended+xml",
  )
  builder.add_override(
    "/word/footnotes.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml",
  )
  builder.add_relationship(
    "rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/document.xml",
  )
  builder.add_relationship(
    "rId1",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
    "styles.xml",
    source="word/document.xml",
  )
  builder.add_relationship(
    "rId2",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
    "comments.xml",
    source="word/document.xml",
  )
  builder.add_relationship(
    "rId3",
    "http://schemas.microsoft.com/office/2011/relationships/commentsExtended",
    "commentsExtended.xml",
    source="word/document.xml",
  )
  builder.add_relationship(
    "rId4",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
    "footnotes.xml",
    source="word/document.xml",
  )
  builder.add_part("word/document.xml", @utf8.encode(document))
  builder.add_part("word/styles.xml", @utf8.encode(styles))
  builder.add_part("word/comments.xml", @utf8.encode(comments))
  builder.add_part("word/commentsExtended.xml", @utf8.encode(extended))
  builder.add_part("word/footnotes.xml", @utf8.encode(footnotes))
  let bytes = builder.build()
  validate_docx_via_sdk(dir, "commented_conformance", bytes)
  let annotated = @docx2html.read_docx_annotated(bytes[:])
  let index = annotated.annotations()
  debug_inspect(index.warnings(), content="[]")
  debug_inspect(index.comments().length(), content="4")
  let first = index.comments()[0]
  debug_inspect(
    first.id(),
    content=(
      #|"0"
    ),
  )
  debug_inspect(first.anchors().length(), content="1")
  debug_inspect(
    first.anchors()[0].start(),
    content=(
      #|Some("/body/p[2]")
    ),
  )
  debug_inspect(
    first.anchors()[0].references(),
    content=(
      #|["/body/p[3]/r[2]"]
    ),
  )
  // Comment 1 is a TRUE point (reference only) covering its paragraph;
  // comment 3 ranges a TABLE CELL paragraph.
  let point = index.comments()[1]
  debug_inspect(point.anchors().length(), content="1")
  debug_inspect(point.anchors()[0].start(), content="None")
  let cell_comment = index.comments()[3]
  debug_inspect(
    cell_comment.id(),
    content=(
      #|"5"
    ),
  )
  debug_inspect(
    index.covering_comment_ids("/body/tbl[1]/tr[1]/tc[1]/p[1]"),
    content=(
      #|["5"]
    ),
  )
  debug_inspect(index.footnotes().length(), content="1")
  debug_inspect(
    index.footnotes()[0].references(),
    content=(
      #|["/body/p[4]/r[2]"]
    ),
  )
  let reply = index.comments()[2]
  debug_inspect(
    reply.parent_id(),
    content=(
      #|Some("0")
    ),
  )
  debug_inspect(reply.done(), content="Some(true)")
  debug_inspect(
    index.covering_comment_ids("/body/p[2]"),
    content=(
      #|["0"]
    ),
  )
}

///|
/// Phase-2 J2: the committed cram fixture for the annotation read
/// surface. This test IS the fixture's generator: it rebuilds the bytes
/// from the reviewed XML and byte-compares against the committed file
/// (bootstrap-writing it only when absent), so the fixture can never
/// drift from what the SDK gate validated.
async test "the committed commented.docx cram fixture matches its generator" {
  let document =
    #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    #|<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:body>
    #|<w:p><w:r><w:t>plain first paragraph</w:t></w:r></w:p>
    #|<w:p><w:commentRangeStart w:id="0"/><w:r><w:t>the annotated sentence</w:t></w:r><w:commentRangeEnd w:id="0"/><w:r><w:rPr><w:rStyle w:val="CommentReference"/></w:rPr><w:commentReference w:id="0"/></w:r></w:p>
    #|<w:p><w:r><w:t>closing paragraph</w:t></w:r><w:r><w:footnoteReference w:id="2"/></w:r></w:p>
    #|<w:sectPr><w:pgSz w:w="12240" w:h="15840"/></w:sectPr>
    #|</w:body>
    #|</w:document>
  let styles =
    #|<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:style w:type="paragraph" w:styleId="Normal" w:default="1"><w:name w:val="Normal"/></w:style>
    #|<w:style w:type="character" w:styleId="CommentReference"><w:name w:val="annotation reference"/></w:style>
    #|</w:styles>
  let comments =
    #|<w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w14="http://schemas.microsoft.com/office/word/2010/wordml" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="w14">
    #|<w:comment w:id="0" w:author="Ada Lovelace" w:initials="AL" w:date="2026-07-11T09:00:00Z"><w:p w14:paraId="3AAA0001"><w:r><w:t>Please cite a source here.</w:t></w:r></w:p></w:comment>
    #|<w:comment w:id="1" w:author="Grace Hopper"><w:p w14:paraId="3BBB0001"><w:r><w:t>Agreed, fixed in the next draft.</w:t></w:r></w:p></w:comment>
    #|</w:comments>
  let extended =
    #|<w15:commentsEx xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="w15">
    #|<w15:commentEx w15:paraId="3AAA0001" w15:done="0"/>
    #|<w15:commentEx w15:paraId="3BBB0001" w15:paraIdParent="3AAA0001" w15:done="1"/>
    #|</w15:commentsEx>
  let footnotes =
    #|<w:footnotes xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
    #|<w:footnote w:type="separator" w:id="-1"><w:p><w:r><w:separator/></w:r></w:p></w:footnote>
    #|<w:footnote w:type="continuationSeparator" w:id="0"><w:p><w:r><w:continuationSeparator/></w:r></w:p></w:footnote>
    #|<w:footnote w:id="2"><w:p><w:r><w:t>See the appendix for details.</w:t></w:r></w:p></w:footnote>
    #|</w:footnotes>
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_override(
    "/word/styles.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml",
  )
  builder.add_override(
    "/word/comments.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml",
  )
  builder.add_override(
    "/word/commentsExtended.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.commentsExtended+xml",
  )
  builder.add_override(
    "/word/footnotes.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.footnotes+xml",
  )
  builder.add_relationship(
    "rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/document.xml",
  )
  builder.add_relationship(
    "rId1",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
    "styles.xml",
    source="word/document.xml",
  )
  builder.add_relationship(
    "rId2",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
    "comments.xml",
    source="word/document.xml",
  )
  builder.add_relationship(
    "rId3",
    "http://schemas.microsoft.com/office/2011/relationships/commentsExtended",
    "commentsExtended.xml",
    source="word/document.xml",
  )
  builder.add_relationship(
    "rId4",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/footnotes",
    "footnotes.xml",
    source="word/document.xml",
  )
  builder.add_part("word/document.xml", @utf8.encode(document))
  builder.add_part("word/styles.xml", @utf8.encode(styles))
  builder.add_part("word/comments.xml", @utf8.encode(comments))
  builder.add_part("word/commentsExtended.xml", @utf8.encode(extended))
  builder.add_part("word/footnotes.xml", @utf8.encode(footnotes))
  let bytes = builder.build()
  let dir = fresh_scratch_dir()
  validate_docx_via_sdk(dir, "commented_cram_fixture", bytes)
  let fixture_path = "tests/cram/fixtures/commented.docx"
  if @afs.exists(fixture_path) {
    let committed = @afs.read_file(fixture_path).binary()
    debug_inspect(committed == bytes, content="true")
  } else if @env.get_env_var("REGENERATE_FIXTURES") is Some(_) {
    // Explicit regeneration only (REGENERATE_FIXTURES=1 moon test ...).
    @afs.write_file(fixture_path, bytes, create_mode=CreateNew)
    println("regenerated \{fixture_path}; commit it")
  } else {
    // A missing committed fixture is a FAILURE, never a silent
    // bootstrap: CI runs this test before cram, and quietly recreating
    // the file would mask its deletion (J2 review round 1).
    fail(
      "tests/cram/fixtures/commented.docx is missing; regenerate with REGENERATE_FIXTURES=1 and commit",
    )
  }
}

///|
/// Phase-2 K1: a full-surface docx.batch/2 script — a point comment on a
/// styled paragraph plus a range comment passing OVER a table, with
/// styled/formatted/listed body paragraphs — must be Microsoft-schema-
/// valid, and the annotation index must read back exactly what the
/// writer anchored (the author->read loop closed by our own reader).
async test "a docx.batch/2 script with comments is schema-valid and round-trips" {
  let dir = fresh_scratch_dir()
  let script = @batch.parse_batch(
    @json.parse(
      (
        #|{
        #|  "schema": "docx.batch/2",
        #|  "ops": [
        #|    {"op": "paragraph", "params": {"text": "Title", "style": "Heading1"}},
        #|    {"op": "comment", "params": {"on": 0, "author": "Reviewer", "initials": "R",
        #|     "date": "2026-07-11T09:30:00Z", "text": "Point note on the title"}},
        #|    {"op": "paragraph", "params": {"text": "Body paragraph"}},
        #|    {"op": "table", "params": {"rows": [[{"text": "cell"}]]}},
        #|    {"op": "paragraph", "params": {"text": "After the table"}},
        #|    {"op": "comment", "params": {"on": {"from": 2, "to": 4}, "author": "Second",
        #|     "paragraphs": [
        #|       {"text": "Range over the table", "style": "Heading2"},
        #|       {"runs": [{"text": "formatted", "bold": true, "highlight": "yellow"},
        #|                 {"text": " tail", "italic": true}]},
        #|       {"text": "a listed point", "list": {"ordered": true}}
        #|     ]}}
        #|  ]
        #|}
      ),
    ),
  )
  let body = script.build_body(Map([]))
  let comments = []
  for comment in script.build_comments() {
    guard (comment.from_block(), comment.to_block()) is (Some(from), Some(to))
    comments.push(
      @docx2html.comment_spec(
        author=comment.author(),
        initials?=comment.initials(),
        date?=comment.date(),
        from~,
        to~,
        comment.body(),
      ),
    )
  }
  let bytes = @docx2html.write_docx_with_comments(body, comments)
  validate_docx_via_sdk(dir, "batch2_commented", bytes)
  let annotated = @docx2html.read_docx_annotated(bytes[:])
  let index = annotated.annotations()
  debug_inspect(index.warnings(), content="[]")
  debug_inspect(index.comments().length(), content="2")
  let point = index.comments()[0]
  debug_inspect(
    point.id(),
    content=(
      #|"0"
    ),
  )
  debug_inspect(
    point.author(),
    content=(
      #|Some("Reviewer")
    ),
  )
  debug_inspect(
    point.date(),
    content=(
      #|Some("2026-07-11T09:30:00Z")
    ),
  )
  debug_inspect(point.anchors().length(), content="1")
  debug_inspect(
    point.anchors()[0].start(),
    content=(
      #|Some("/body/p[1]")
    ),
  )
  debug_inspect(
    point.anchors()[0].end(),
    content=(
      #|Some("/body/p[1]")
    ),
  )
  // Blocks: op0 -> p[1], op2 -> p[2], op3 -> tbl[1], op4 -> p[3]. The
  // range comment anchors p[2]..p[3], passing over the table, and its
  // reference run lands at the end of the closing paragraph.
  let range = index.comments()[1]
  debug_inspect(
    range.anchors()[0].start(),
    content=(
      #|Some("/body/p[2]")
    ),
  )
  debug_inspect(
    range.anchors()[0].end(),
    content=(
      #|Some("/body/p[3]")
    ),
  )
  debug_inspect(
    range.anchors()[0].references(),
    content=(
      #|["/body/p[3]/r[2]"]
    ),
  )
  debug_inspect(range.body_paragraphs(), content="3")
  // The table BETWEEN the endpoints is covered by the range.
  debug_inspect(
    index.covering_comment_ids("/body/tbl[1]/tr[1]/tc[1]/p[1]"),
    content=(
      #|["1"]
    ),
  )
  debug_inspect(
    index.covering_comment_ids("/body/p[1]"),
    content=(
      #|["0"]
    ),
  )
}

///|
/// Phase-2 K2: a WRITER-authored thread — multi-paragraph parent, a
/// resolved reply, a chained reply — must be Microsoft-schema-valid
/// (comments + commentsExtended parts, w14/w15 + mc:Ignorable) and the
/// index must read the thread back: parent_id chain, done flags, and
/// the reply's anchorlessness.
async test "a written comment thread is schema-valid and reads back threaded" {
  let dir = fresh_scratch_dir()
  let body = [
    @docx2html.paragraph([@docx2html.run([@docx2html.text("Claim")])]),
  ]
  let bytes = @docx2html.write_docx_with_comments(body, [
    @docx2html.comment_spec(
      author="Ada",
      initials="A",
      date="2026-07-11T16:00:00Z",
      from=0,
      to=0,
      [
        @docx2html.paragraph([@docx2html.run([@docx2html.text("First,")])]),
        @docx2html.paragraph([@docx2html.run([@docx2html.text("second.")])]),
      ],
    ),
    @docx2html.comment_reply(author="Bob", reply_to=0, done=true, [
      @docx2html.paragraph([@docx2html.run([@docx2html.text("Resolved.")])]),
    ]),
    @docx2html.comment_reply(author="Cid", reply_to=1, [
      @docx2html.paragraph([@docx2html.run([@docx2html.text("Agreed.")])]),
    ]),
  ])
  validate_docx_via_sdk(dir, "k2_thread", bytes)
  let annotated = @docx2html.read_docx_annotated(bytes[:])
  let index = annotated.annotations()
  debug_inspect(index.warnings(), content="[]")
  debug_inspect(index.comments().length(), content="3")
  let parent = index.comments()[0]
  debug_inspect(parent.done(), content="Some(false)")
  debug_inspect(parent.parent_id(), content="None")
  debug_inspect(parent.body_paragraphs(), content="2")
  let reply = index.comments()[1]
  debug_inspect(
    reply.parent_id(),
    content=(
      #|Some("0")
    ),
  )
  debug_inspect(reply.done(), content="Some(true)")
  debug_inspect(reply.anchors().length(), content="0")
  let chained = index.comments()[2]
  debug_inspect(
    chained.parent_id(),
    content=(
      #|Some("1")
    ),
  )
  debug_inspect(chained.done(), content="Some(false)")
}

///|
/// Phase-2 K3: writer-authored footnotes and endnotes — plumbing notes,
/// in-note mark runs, positive id allocation — must be Microsoft-schema-
/// valid and read back through the index with per-run reference paths.
async test "written footnotes and endnotes are schema-valid and read back" {
  let dir = fresh_scratch_dir()
  let bytes = @docx2html.write_docx_with_annotations(
    [
      @docx2html.paragraph([
        @docx2html.run([
          @docx2html.text("Cited"),
          @docx2html.note_reference("footnote", "0"),
        ]),
        @docx2html.run([
          @docx2html.text(" twice"),
          @docx2html.note_reference("footnote", "1"),
        ]),
      ]),
      @docx2html.paragraph([
        @docx2html.run([
          @docx2html.text("Closing"),
          @docx2html.note_reference("endnote", "0"),
        ]),
      ]),
    ],
    footnotes=[
      @docx2html.note_spec([
        @docx2html.paragraph([@docx2html.run([@docx2html.text("Source A.")])]),
      ]),
      @docx2html.note_spec([
        @docx2html.paragraph([@docx2html.run([@docx2html.text("Source B,")])]),
        @docx2html.paragraph([@docx2html.run([@docx2html.text("continued.")])]),
      ]),
    ],
    endnotes=[
      @docx2html.note_spec([
        @docx2html.paragraph([@docx2html.run([@docx2html.text("An endnote.")])]),
      ]),
    ],
  )
  validate_docx_via_sdk(dir, "k3_notes", bytes)
  let annotated = @docx2html.read_docx_annotated(bytes[:])
  let index = annotated.annotations()
  debug_inspect(index.warnings(), content="[]")
  debug_inspect(index.footnotes().length(), content="2")
  debug_inspect(index.endnotes().length(), content="1")
  debug_inspect(
    index.footnotes()[1].references(),
    content=(
      #|["/body/p[1]/r[2]"]
    ),
  )
  debug_inspect(
    index.endnotes()[0].references(),
    content=(
      #|["/body/p[2]/r[1]"]
    ),
  )
}

///|
/// Phase-2 L0 — THE SPIKE PROOF: add a comment to an EXISTING document
/// by byte-span surgery alone (no reserialization), then hold it to
/// every gate at once: Microsoft schema validity, annotation-index
/// read-back, and the fidelity oracle — mutated parts byte-identical
/// outside the declared spans, untouched parts payload-identical, and
/// nothing mutated beyond the operation's row in the roadmap's
/// mutated-part matrix (document.xml, its .rels, [Content_Types].xml,
/// the new comments.xml — and NOTHING else).
async test "L0 spike: a comment splices into an existing document byte-preservingly" {
  let dir = fresh_scratch_dir()
  // The "existing" document: written normally, treated as opaque bytes
  // from here on. A styled paragraph guarantees a pPr to insert AFTER.
  let original = @docx2html.write_docx([
    @docx2html.paragraph(
      [@docx2html.run([@docx2html.text("Heading text")])],
      properties=@docx2html.paragraph_properties(style_id=Some("Heading1")),
    ),
    @docx2html.paragraph([
      @docx2html.run([@docx2html.text("The sentence under review.")]),
    ]),
  ])
  let annotated = @docx2html.read_docx_annotated(original)
  let main_part = annotated.main_story_part()
  inspect(main_part, content="word/document.xml")
  guard annotated.body_paragraph_span("p[2]") is Some(span)
  guard span.content_start() is Some(content_start)
  guard span.close_tag_start() is Some(close_start)
  // Fragments are namespace-SELF-CONTAINED: every spliced element
  // declares the WML binding for its own prefix, so correctness does
  // not depend on what the surrounding document happened to bind (the
  // namespace-correctness criterion; the hostile-binding test below
  // proves the independence).
  let wml = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  let start_fragment = "<w:commentRangeStart xmlns:w=\"\{wml}\" w:id=\"0\"/>"
  let end_fragment = "<w:commentRangeEnd xmlns:w=\"\{wml}\" w:id=\"0\"/>" +
    "<w:r xmlns:w=\"\{wml}\"><w:commentReference w:id=\"0\"/></w:r>"
  let plan = @splice.SplicePlan::new()
  plan.edit_part(
    main_part,
    @splice.span_edit(
      start=content_start,
      end=content_start,
      @utf8.encode(start_fragment),
    ),
  )
  plan.edit_part(
    main_part,
    @splice.span_edit(
      start=close_start,
      end=close_start,
      @utf8.encode(end_fragment),
    ),
  )
  plan.add_part(
    "word/comments.xml",
    @utf8.encode(
      (
        #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="0" w:author="Surgeon" w:date="2026-07-11T18:00:00Z"><w:p><w:r><w:t>Spliced in, not rewritten.</w:t></w:r></w:p></w:comment></w:comments>
      ),
    ),
  )
  // Wire the new part: a relationship in the main part's .rels and an
  // Override in [Content_Types].xml — themselves span edits.
  let archive = @mbtzip.read(original)
  guard archive.get("word/_rels/document.xml.rels") is Some(rels_bytes)
  let rels_text = @utf8.decode(rels_bytes, ignore_bom=true)
  guard rels_text.find("</Relationships>") is Some(rels_at)
  plan.edit_part(
    "word/_rels/document.xml.rels",
    @splice.span_edit(
      start=rels_at,
      end=rels_at,
      @utf8.encode(
        "<Relationship Id=\"rIdSplice1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"comments.xml\"/>",
      ),
    ),
  )
  guard archive.get("[Content_Types].xml") is Some(types_bytes)
  let types_text = @utf8.decode(types_bytes, ignore_bom=true)
  guard types_text.find("</Types>") is Some(types_at)
  plan.edit_part(
    "[Content_Types].xml",
    @splice.span_edit(
      start=types_at,
      end=types_at,
      @utf8.encode(
        "<Override PartName=\"/word/comments.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml\"/>",
      ),
    ),
  )
  let spliced = @splice.splice_docx(original, plan)
  // Gate 1: Microsoft schema validity of the SURGICAL result.
  validate_docx_via_sdk(dir, "l0_spliced_comment", spliced)
  // Gate 2: the annotation surface reads the spliced comment back.
  let after = @docx2html.read_docx_annotated(spliced[:])
  let index = after.annotations()
  debug_inspect(index.warnings(), content="[]")
  debug_inspect(index.comments().length(), content="1")
  let comment = index.comments()[0]
  debug_inspect(
    comment.author(),
    content=(
      #|Some("Surgeon")
    ),
  )
  debug_inspect(
    comment.anchors()[0].start(),
    content=(
      #|Some("/body/p[2]")
    ),
  )
  debug_inspect(
    comment.anchors()[0].references(),
    content=(
      #|["/body/p[2]/r[2]"]
    ),
  )
  // Gate 3: the fidelity oracle. The mutated main part must be the
  // MANUAL splice of the original bytes — byte-identical outside the
  // two declared spans.
  let out = @mbtzip.read(spliced)
  guard archive.get(main_part) is Some(original_doc)
  guard out.get(main_part) is Some(spliced_doc)
  let expected = Buffer()
  expected.write_bytesview(original_doc[0:content_start])
  expected.write_bytes(@utf8.encode(start_fragment))
  expected.write_bytesview(original_doc[content_start:close_start])
  expected.write_bytes(@utf8.encode(end_fragment))
  expected.write_bytesview(original_doc[close_start:])
  inspect(spliced_doc == expected.contents(), content="true")
  // ...and BOTH other edited parts reconstruct the same way — a
  // regression that canonicalizes unrelated bytes inside an allowed
  // part would otherwise hide inside the matrix.
  guard out.get("word/_rels/document.xml.rels") is Some(spliced_rels)
  let expected_rels = Buffer()
  expected_rels.write_bytesview(rels_bytes[0:rels_at])
  expected_rels.write_bytes(
    @utf8.encode(
      "<Relationship Id=\"rIdSplice1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"comments.xml\"/>",
    ),
  )
  expected_rels.write_bytesview(rels_bytes[rels_at:])
  inspect(spliced_rels == expected_rels.contents(), content="true")
  guard out.get("[Content_Types].xml") is Some(spliced_types)
  let expected_types = Buffer()
  expected_types.write_bytesview(types_bytes[0:types_at])
  expected_types.write_bytes(
    @utf8.encode(
      "<Override PartName=\"/word/comments.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml\"/>",
    ),
  )
  expected_types.write_bytesview(types_bytes[types_at:])
  inspect(spliced_types == expected_types.contents(), content="true")
  // The mutated-part matrix: ONLY the operation's row may differ.
  let changed : Array[String] = []
  for entry in archive.entries() {
    guard out.get(entry.name()) is Some(new_bytes)
    if new_bytes != entry.data() {
      changed.push(entry.name())
    }
  }
  // (Entry order — the walk follows the archive's original order.)
  debug_inspect(
    changed,
    content=(
      #|[
      #|  "[Content_Types].xml",
      #|  "word/_rels/document.xml.rels",
      #|  "word/document.xml",
      #|]
    ),
  )
  inspect(out.get("word/comments.xml") is Some(_), content="true")
  // The output's entry set is EXACTLY the original's plus the one new
  // part — nothing dropped, nothing else invented.
  let original_names : Array[String] = []
  for entry in archive.entries() {
    original_names.push(entry.name())
  }
  let output_names : Array[String] = []
  for entry in out.entries() {
    output_names.push(entry.name())
  }
  original_names.push("word/comments.xml")
  assert_eq(output_names, original_names)
}

///|
/// L0 review round 1 (High): fragment namespace correctness must not
/// depend on the document's own bindings. This document binds the WML
/// namespace to `x:` and deliberately binds `w:` to a FOREIGN URI —
/// context-relying fragments would silently attach to the wrong
/// namespace. Self-contained fragments (each element declaring its own
/// xmlns:w, which locally SHADOWS the hostile binding) splice
/// correctly: the SDK validates the result and the index anchors it.
async test "L0: self-contained fragments survive hostile prefix bindings" {
  let dir = fresh_scratch_dir()
  let document =
    #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?><x:document xmlns:x="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:w="urn:not-wml"><x:body><x:p><x:r><x:t>hostile ground</x:t></x:r></x:p><x:sectPr><x:pgSz x:w="12240" x:h="15840"/></x:sectPr></x:body></x:document>
  let styles =
    #|<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:style w:type="paragraph" w:styleId="Normal" w:default="1"><w:name w:val="Normal"/></w:style></w:styles>
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_override(
    "/word/styles.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml",
  )
  builder.add_override(
    "/word/comments.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml",
  )
  builder.add_relationship(
    "rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/document.xml",
  )
  builder.add_relationship(
    "rId1",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
    "styles.xml",
    source="word/document.xml",
  )
  builder.add_relationship(
    "rId2",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments",
    "comments.xml",
    source="word/document.xml",
  )
  builder.add_part("word/document.xml", @utf8.encode(document))
  builder.add_part("word/styles.xml", @utf8.encode(styles))
  builder.add_part(
    "word/comments.xml",
    @utf8.encode(
      (
        #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="0" w:author="Hostile"><w:p><w:r><w:t>note</w:t></w:r></w:p></w:comment></w:comments>
      ),
    ),
  )
  let original = builder.build()
  let annotated = @docx2html.read_docx_annotated(original)
  guard annotated.body_paragraph_span("p[1]") is Some(span)
  guard span.content_start() is Some(content_start)
  guard span.close_tag_start() is Some(close_start)
  let wml = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  let plan = @splice.SplicePlan::new()
  plan.edit_part(
    "word/document.xml",
    @splice.span_edit(
      start=content_start,
      end=content_start,
      @utf8.encode("<w:commentRangeStart xmlns:w=\"\{wml}\" w:id=\"0\"/>"),
    ),
  )
  plan.edit_part(
    "word/document.xml",
    @splice.span_edit(
      start=close_start,
      end=close_start,
      @utf8.encode(
        "<w:commentRangeEnd xmlns:w=\"\{wml}\" w:id=\"0\"/><w:r xmlns:w=\"\{wml}\"><w:commentReference w:id=\"0\"/></w:r>",
      ),
    ),
  )
  let spliced = @splice.splice_docx(original, plan)
  validate_docx_via_sdk(dir, "l0_hostile_prefix", spliced)
  let after = @docx2html.read_docx_annotated(spliced[:])
  let index = after.annotations()
  debug_inspect(index.warnings(), content="[]")
  debug_inspect(index.comments().length(), content="1")
  debug_inspect(
    index.comments()[0].anchors()[0].start(),
    content=(
      #|Some("/body/p[1]")
    ),
  )
}

///|
/// L0 review round 1 (Medium): two insertions at the SAME offset (an
/// EMPTY open paragraph: content_start == close_tag_start) must splice
/// in plan order — start marker first — under the deterministic
/// (start, consuming, ordinal) key.
async test "L0: equal-offset insertions splice in plan order" {
  let dir = fresh_scratch_dir()
  // An EMPTY OPEN paragraph (<w:p></w:p>) — our writer never emits one
  // (empty elements serialize self-closing), so build the package by
  // hand; content_start == close_tag_start is exactly the tie the
  // deterministic sort key must break in plan order.
  let document =
    #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:body><w:p></w:p><w:p><w:r><w:t>anchor next</w:t></w:r></w:p><w:sectPr><w:pgSz w:w="12240" w:h="15840"/></w:sectPr></w:body></w:document>
  let styles =
    #|<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:style w:type="paragraph" w:styleId="Normal" w:default="1"><w:name w:val="Normal"/></w:style></w:styles>
  let builder = @opc.PackageBuilder::new()
  builder.add_default(
    "rels", "application/vnd.openxmlformats-package.relationships+xml",
  )
  builder.add_default("xml", "application/xml")
  builder.add_override(
    "/word/document.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml",
  )
  builder.add_override(
    "/word/styles.xml", "application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml",
  )
  builder.add_relationship(
    "rId1", "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
    "word/document.xml",
  )
  builder.add_relationship(
    "rId1",
    "http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles",
    "styles.xml",
    source="word/document.xml",
  )
  builder.add_part("word/document.xml", @utf8.encode(document))
  builder.add_part("word/styles.xml", @utf8.encode(styles))
  let original = builder.build()
  let annotated = @docx2html.read_docx_annotated(original)
  guard annotated.body_paragraph_span("p[1]") is Some(span)
  guard span.content_start() is Some(content_start)
  guard span.close_tag_start() is Some(close_start)
  inspect(content_start == close_start, content="true")
  let wml = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
  let plan = @splice.SplicePlan::new()
  plan.edit_part(
    "word/document.xml",
    @splice.span_edit(
      start=content_start,
      end=content_start,
      @utf8.encode("<w:commentRangeStart xmlns:w=\"\{wml}\" w:id=\"0\"/>"),
    ),
  )
  plan.edit_part(
    "word/document.xml",
    @splice.span_edit(
      start=close_start,
      end=close_start,
      @utf8.encode(
        "<w:commentRangeEnd xmlns:w=\"\{wml}\" w:id=\"0\"/><w:r xmlns:w=\"\{wml}\"><w:commentReference w:id=\"0\"/></w:r>",
      ),
    ),
  )
  plan.add_part(
    "word/comments.xml",
    @utf8.encode(
      (
        #|<?xml version="1.0" encoding="UTF-8" standalone="yes"?><w:comments xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"><w:comment w:id="0" w:author="Orderly"><w:p><w:r><w:t>on empty</w:t></w:r></w:p></w:comment></w:comments>
      ),
    ),
  )
  let archive = @mbtzip.read(original)
  guard archive.get("word/_rels/document.xml.rels") is Some(rels_bytes)
  guard @utf8.decode(rels_bytes, ignore_bom=true).find("</Relationships>")
    is Some(rels_at)
  plan.edit_part(
    "word/_rels/document.xml.rels",
    @splice.span_edit(
      start=rels_at,
      end=rels_at,
      @utf8.encode(
        "<Relationship Id=\"rIdSplice1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/comments\" Target=\"comments.xml\"/>",
      ),
    ),
  )
  guard archive.get("[Content_Types].xml") is Some(types_bytes)
  guard @utf8.decode(types_bytes, ignore_bom=true).find("</Types>")
    is Some(types_at)
  plan.edit_part(
    "[Content_Types].xml",
    @splice.span_edit(
      start=types_at,
      end=types_at,
      @utf8.encode(
        "<Override PartName=\"/word/comments.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.comments+xml\"/>",
      ),
    ),
  )
  let spliced = @splice.splice_docx(original, plan)
  validate_docx_via_sdk(dir, "l0_equal_offset", spliced)
  // Order proof at the byte level: start marker precedes the end marker.
  let out = @mbtzip.read(spliced)
  guard out.get("word/document.xml") is Some(doc)
  let text = @utf8.decode(doc, ignore_bom=true)
  guard text.find("commentRangeStart") is Some(start_at)
  guard text.find("commentRangeEnd") is Some(end_at)
  inspect(start_at < end_at, content="true")
  let after = @docx2html.read_docx_annotated(spliced[:])
  debug_inspect(after.annotations().warnings(), content="[]")
  debug_inspect(after.annotations().comments().length(), content="1")
}
