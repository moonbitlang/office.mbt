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
  let restyled = @docx2html.embed_style_map(single_paragraph, "p => h1:fresh")
  validate_docx_via_sdk(dir, "embedded_style_map", restyled)
}
