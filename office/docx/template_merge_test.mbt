///|
/// End-to-end DOCX template merge over a real fixture with headers: the
/// body and the header story both substitute, the escape survives, and
/// the preservation manifest names exactly the parts the merge touched.
async test "docx template substitutes body and header stories" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-template-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    // build the fixture: header-footer.docx with placeholders spliced
    // into the body's first paragraph and the default header
    let source_bytes = @afs.read_file(
      "../docx2html/tests/cram/fixtures/header-footer.docx",
    ).binary()
    let archive = @zip.read(source_bytes[:])
    let rebuilt = @zip.Archive::new()
    for entry in archive.entries() {
      let name = entry.name()
      guard archive.get(name) is Some(payload) else { continue }
      let replaced = if name == "word/header1.xml" {
        let text = @utf8.decode(payload)
        @utf8.encode(
          text.replace(old="Default header text", new="Header for {{customer}}"),
        )
      } else if name == "word/document.xml" {
        let text = @utf8.decode(payload)
        @utf8.encode(
          text.replace(
            old="Body first paragraph",
            new="Dear {{customer}}, \\{{kept}} balance {{total}}",
          ),
        )
      } else {
        payload.to_bytes()
      }
      rebuilt.add(name, replaced)
    }
    let input = directory + "/tpl.docx"
    @afs.write_file(
      input,
      @zip.write(rebuilt),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/filled.docx"
    let values : Map[String, @template.TemplateValue] = {
      "customer": TextValue("Ada Lovelace"),
      "total": NumberValue(1234.5),
    }
    let result = @docx.transact_docx_template(
      @transaction.transaction_options(input, output_path=output),
      values,
      allow_missing=false,
    )
    assert_eq(result.report.replaced, 3)
    assert_eq(result.report.escapes_applied, 1)
    assert_eq(result.report.missing_total, 0)
    assert_true(result.report.stories_scanned.contains("/header[1]"))
    // only the touched parts changed
    let changed = result.transaction.preservation.changed
    assert_true(changed.contains("word/document.xml"))
    assert_true(changed.contains("word/header1.xml"))
    assert_false(changed.contains("word/header2.xml"))
    assert_false(changed.contains("word/footer1.xml"))
    // the published document carries the substitutions
    let published = @afs.read_file(output).binary()
    let out_archive = @zip.read(published[:])
    guard out_archive.get("word/document.xml") is Some(document) else {
      fail("missing document part")
    }
    let document_text = @utf8.decode(document)
    assert_true(
      document_text.contains("Dear Ada Lovelace, {{kept}} balance 1234.5"),
    )
    guard out_archive.get("word/header1.xml") is Some(header) else {
      fail("missing header part")
    }
    let header_text = @utf8.decode(header)
    assert_true(header_text.contains("Header for Ada Lovelace"))
  }
}

///|
/// Strict refusal: a missing key publishes nothing and reports the
/// canonical paragraph location.
async test "docx template refuses missing keys without publishing" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-template-miss-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let source_bytes = @afs.read_file(
      "../docx2html/tests/cram/fixtures/single-paragraph.docx",
    ).binary()
    let archive = @zip.read(source_bytes[:])
    let rebuilt = @zip.Archive::new()
    for entry in archive.entries() {
      let name = entry.name()
      guard archive.get(name) is Some(payload) else { continue }
      let replaced = if name == "word/document.xml" {
        let text = @utf8.decode(payload)
        @utf8.encode(
          text.replace(old="Walking on imported air", new="Hi {{missing}}"),
        )
      } else {
        payload.to_bytes()
      }
      rebuilt.add(name, replaced)
    }
    let input = directory + "/tpl.docx"
    @afs.write_file(
      input,
      @zip.write(rebuilt),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/never.docx"
    let values : Map[String, @template.TemplateValue] = {}
    match
      (try? @docx.transact_docx_template(
        @transaction.transaction_options(input, output_path=output),
        values,
        allow_missing=false,
      )) {
      Err(@docx.DocxTemplateRefused(report)) => {
        assert_eq(report.missing_total, 1)
        assert_eq(report.missing[0].location, "/docx/body/p[1]")
        assert_eq(report.missing[0].detail, "missing")
      }
      Err(_) => fail("expected the typed refusal")
      Ok(_) => fail("a missing key must refuse")
    }
    if @afs.exists(output) {
      fail("refusal must not publish")
    }
  }
}

///|
/// Codex #208 round-4 bytes-level nets: shapes the parsed model cannot
/// represent — only the byte-fidelity gate can see them.
async fn docx_template_bytes_case(
  directory : String,
  replacement : String,
  values : Map[String, @template.TemplateValue],
  allow_missing : Bool,
) -> @docx.DocxTemplateReport {
  let source_bytes = @afs.read_file(
    "../docx2html/tests/cram/fixtures/single-paragraph.docx",
  ).binary()
  let archive = @zip.read(source_bytes[:])
  let rebuilt = @zip.Archive::new()
  for entry in archive.entries() {
    let name = entry.name()
    guard archive.get(name) is Some(payload) else { continue }
    let replaced = if name == "word/document.xml" {
      let text = @utf8.decode(payload)
      @utf8.encode(
        text.replace(
          old="<w:r><w:t>Walking on imported air</w:t></w:r>",
          new=replacement,
        ),
      )
    } else {
      payload.to_bytes()
    }
    rebuilt.add(name, replaced)
  }
  let input = directory + "/bytes-tpl.docx"
  @afs.write_file(
    input,
    @zip.write(rebuilt),
    create_mode=CreateNew,
    permission=0o600,
  )
  let output = directory + "/bytes-out.docx"
  match
    (try? @docx.transact_docx_template(
      @transaction.transaction_options(input, output_path=output),
      values,
      allow_missing~,
    )) {
    Err(@docx.DocxTemplateRefused(report)) => {
      if @afs.exists(output) {
        fail("refusal must not publish")
      }
      report
    }
    Err(error) => raise error
    Ok(_) => fail("expected the typed refusal")
  }
}

///|
async test "a dropped in-run picture cannot be crossed by a placeholder" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-template-pict-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    // the reader drops w:pict, leaving Run([]) — indistinguishable from
    // an empty run in the model; the fidelity gate on interior runs
    // must refuse the span
    let report = docx_template_bytes_case(
      directory,
      "<w:r><w:t>{</w:t></w:r><w:r><w:pict></w:pict></w:r><w:r><w:t>{k}}</w:t></w:r>",
      { "k": @template.TextValue("VALUE") },
      false,
    )
    assert_true(report.unsupported_total >= 1)
    // the refused report still describes the would-have merge; nothing
    // was published (asserted in the case helper)
    assert_false(report.changed)
  }
}

///|
async test "unfaithful bytes under a missing-key match refuse even with allow-missing" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-template-sym-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    // the run's model text is pure (the hyphen element maps to a text
    // character) but its bytes cannot round-trip; unsupported must
    // outrank missing, even under allow-missing
    let report = docx_template_bytes_case(
      directory,
      "<w:r><w:t>{{missing}}</w:t><w:noBreakHyphen/></w:r>",
      {},
      true,
    )
    assert_true(report.unsupported_total >= 1)
  }
}
