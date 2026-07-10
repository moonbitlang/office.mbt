///|
/// Writes `bytes` to a temp file and validates it with the Microsoft
/// DocumentFormat.OpenXml SDK (via scripts/validate_docx.sh in the
/// workspace root — docx2html tests run with the member directory as cwd),
/// failing with the validator output when the package is not schema-valid.
#cfg(target="native")
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
/// Schema-validates representative docx bytes through the real Microsoft
/// OpenXML SDK — the authoritative complement to the portable structural
/// tier behind `docx validate`. Covers the committed reader fixtures and
/// the repo's one write path (`embed_style_map`), so any packaging
/// regression in the re-zip surfaces here.
#cfg(target="native")
async test "docx fixtures and embed_style_map output are Microsoft OpenXML schema-valid" {
  let stamp = @env.now()
    .to_string()
    .replace(old=":", new="_")
    .replace(old=" ", new="_")
  let dir = "_build/docx_sdk_validity/\{stamp}"
  // Two non-recursive EEXIST-tolerant steps: async tests share _build and a
  // recursive mkdir can abort on the already-existing ancestor.
  @afs.mkdir("_build") catch {
    _ => ()
  }
  @afs.mkdir("_build/docx_sdk_validity") catch {
    _ => ()
  }
  @afs.mkdir(dir) catch {
    err => fail("mkdir failed: \{err}")
  }
  validate_docx_via_sdk(dir, "single_paragraph", single_paragraph_docx())
  validate_docx_via_sdk(dir, "tables", tables_docx())
  let restyled = @docx2html.embed_style_map(
    single_paragraph_docx(),
    "p => h1:fresh",
  )
  validate_docx_via_sdk(dir, "embedded_style_map", restyled)
}
