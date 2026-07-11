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
    #|<w:p><w:commentRangeStart w:id="1"/><w:r><w:t>point-ish</w:t></w:r><w:commentRangeEnd w:id="1"/><w:r><w:commentReference w:id="1"/></w:r></w:p>
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
    #|</w:comments>
  let extended =
    #|<w15:commentsEx xmlns:w15="http://schemas.microsoft.com/office/word/2012/wordml" xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006" mc:Ignorable="w15">
    #|<w15:commentEx w15:paraId="1AAA0002" w15:done="0"/>
    #|<w15:commentEx w15:paraId="1CCC0001" w15:paraIdParent="1AAA0002" w15:done="1"/>
    #|</w15:commentsEx>
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
  builder.add_part("word/document.xml", @utf8.encode(document))
  builder.add_part("word/styles.xml", @utf8.encode(styles))
  builder.add_part("word/comments.xml", @utf8.encode(comments))
  builder.add_part("word/commentsExtended.xml", @utf8.encode(extended))
  let bytes = builder.build()
  validate_docx_via_sdk(dir, "commented_conformance", bytes)
  let annotated = @docx2html.read_docx_annotated(bytes[:])
  let index = annotated.annotations()
  debug_inspect(index.warnings(), content="[]")
  debug_inspect(index.comments().length(), content="3")
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
