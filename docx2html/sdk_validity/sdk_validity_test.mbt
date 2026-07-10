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
  let restyled = @docx2html.embed_style_map(single_paragraph, "p => h1:fresh")
  validate_docx_via_sdk(dir, "embedded_style_map", restyled)
}
