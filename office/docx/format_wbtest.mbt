///|
/// A one-paragraph DOCX whose body run markup is exactly `runs`.
async fn format_readback_fixture(
  directory : String,
  name : String,
  runs : String,
) -> String {
  let source_bytes = @afs.read_file(
    "../docx2html/tests/cram/fixtures/single-paragraph.docx",
  ).binary()
  let archive = @zip.read(source_bytes)
  let rebuilt = @zip.Archive::new()
  for entry in archive.entries() {
    let entry_name = entry.name()
    guard archive.get(entry_name) is Some(payload) else { continue }
    let replaced = if entry_name == "word/document.xml" {
      let text = @utf8.decode(payload)
      @utf8.encode(
        text.replace(
          old="<w:r><w:t>Walking on imported air</w:t></w:r>",
          new=runs,
        ),
      )
    } else {
      payload.to_owned()
    }
    rebuilt.add(entry_name, replaced)
  }
  let path = directory + "/" + name
  @afs.write_file(
    path,
    @zip.write(rebuilt),
    create_mode=CreateNew,
    permission=0o600,
  )
  path
}

///|
async fn with_format_readback_dir(run : async (String) -> Unit) -> Unit {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-readback-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    run(directory)
  }
}

///|
/// The candidate archive with `word/document.xml` doctored by one
/// substitution, so each sabotage differs from the honest candidate in
/// exactly one respect.
fn doctored_candidate(
  candidate : @zip.Archive,
  old : String,
  new : String,
) -> @zip.Archive raise {
  let rebuilt = @zip.Archive::new()
  for entry in candidate.entries() {
    let name = entry.name()
    guard candidate.get(name) is Some(payload) else { continue }
    if name == "word/document.xml" {
      let text = @utf8.decode(payload)
      guard text.contains(old) else {
        fail("the candidate does not contain \{old}")
      }
      rebuilt.add(name, @utf8.encode(text.replace(old~, new~)))
    } else {
      rebuilt.add(name, payload.to_owned())
    }
  }
  rebuilt
}

///|
fn finding_codes(findings : Array[@transaction.ValidationFinding]) -> String {
  findings.map(finding => finding.code).join(",")
}

///|
/// The readback is the last thing standing between a wrong candidate and
/// a published file, so each of its three checks gets a NEGATIVE witness:
/// a candidate doctored to break exactly that check, which the honest
/// candidate does not break. Delete any one check and one of these
/// stops failing.
async test "the format readback refuses candidates that its three checks catch" {
  with_format_readback_dir(directory => {
    let source = format_readback_fixture(
      directory, "source.docx", "<w:r><w:t>Hello world</w:t></w:r>",
    )
    let format = @word.docx_direct_format(bold=true)
    transact_docx_format(
      @transaction.transaction_options(
        source,
        output_path=directory + "/out.docx",
      ),
      format~,
      text="world",
    )
    |> ignore
    let candidate = @zip.read(@afs.read_file(directory + "/out.docx").binary())
    // The snapshot the transaction would have captured: the same plan,
    // against the same source.
    let before_archive = @zip.read(@afs.read_file(source).binary())
    let before = @word.read_docx_annotated_archive_limited(
      before_archive,
      candidate_xml_budget(),
    )
    let (_, receipt) = @word.plan_docx_format(
      before,
      before.main_story_source(),
      format~,
      text="world",
    )
    let snapshot : Ref[FormatReadbackSnapshot?] = Ref(
      Some({ before, affected: receipt.affected(), spans: receipt.spans(), }),
    )
    // The honest candidate passes: every failure below is caused by the
    // doctoring alone.
    assert_eq(
      finding_codes(format_readback_findings(snapshot, format, Docx, candidate)),
      "",
    )
    // (1) The paragraph no longer projects what it did.
    assert_eq(
      finding_codes(
        format_readback_findings(
          snapshot,
          format,
          Docx,
          doctored_candidate(candidate, "<w:t>world</w:t>", "<w:t>worlds</w:t>"),
        ),
      ),
      // Changed text also moves the run's place in the paragraph, so
      // the preservation check speaks up alongside the projection one.
      "docx.format.readback_mismatch,docx.format.readback_collateral",
    )
    // (2) The selected span does not carry the request.
    assert_eq(
      finding_codes(
        format_readback_findings(
          snapshot,
          format,
          Docx,
          doctored_candidate(candidate, "<w:rPr><w:b/><w:bCs/></w:rPr>", ""),
        ),
      ),
      "docx.format.readback_unformatted",
    )
    // (3) Formatting nobody asked for appeared on an UNTOUCHED run.
    assert_eq(
      finding_codes(
        format_readback_findings(
          snapshot,
          format,
          Docx,
          doctored_candidate(
            candidate, "<w:r><w:t xml:space=\"preserve\">Hello </w:t></w:r>", "<w:r><w:rPr><w:i/></w:rPr><w:t xml:space=\"preserve\">Hello </w:t></w:r>",
          ),
        ),
      ),
      "docx.format.readback_collateral",
    )
    // A paragraph that vanished is missing, not merely different.
    assert_eq(
      finding_codes(
        format_readback_findings(
          snapshot,
          format,
          Docx,
          doctored_candidate(
            candidate, "<w:p w:rsidR=\"003872F6\" w:rsidRDefault=\"00BF0D64\"><w:r><w:t xml:space=\"preserve\">Hello </w:t></w:r><w:r><w:rPr><w:b/><w:bCs/></w:rPr><w:t>world</w:t></w:r><w:bookmarkStart w:id=\"0\" w:name=\"_GoBack\"/><w:bookmarkEnd w:id=\"0\"/></w:p>",
            "",
          ),
        ),
      ),
      // All three checks notice a paragraph that is simply gone.
      "docx.format.readback_missing,docx.format.readback_unformatted,docx.format.readback_collateral",
    )
    // A validator with nothing captured must not pass by vacuity.
    assert_eq(
      finding_codes(
        format_readback_findings(Ref(None), format, Docx, candidate),
      ),
      "docx.format.readback_uncaptured",
    )
    // Spans and affected paragraphs must agree: a span whose paragraph
    // is unaffected would go unchecked by the projection pass, and an
    // affected paragraph with no span would go unchecked by the
    // direct-format pass.
    let spanless : Ref[FormatReadbackSnapshot?] = Ref(
      Some({ before, affected: receipt.affected(), spans: [], }),
    )
    assert_eq(
      finding_codes(format_readback_findings(spanless, format, Docx, candidate)),
      "docx.format.readback_inconsistent",
    )
    let unaffected : Ref[FormatReadbackSnapshot?] = Ref(
      Some({ before, affected: [], spans: receipt.spans(), }),
    )
    assert_eq(
      finding_codes(
        format_readback_findings(unaffected, format, Docx, candidate),
      ),
      "docx.format.readback_inconsistent",
    )
    // And a candidate of the wrong format is judged before anything is
    // read out of it.
    assert_eq(
      finding_codes(format_readback_findings(snapshot, format, Xlsx, candidate)),
      "docx.format.wrong_format",
    )
  })
}

///|
/// A document with many formatted paragraphs, end to end.
///
/// Every question the readback asks about a story is asked in one
/// batch, because resolving a paragraph path costs a pass over the
/// story: asking per paragraph made a document like this one cost the
/// whole document once per formatted paragraph per check. Measured on
/// this fixture, the per-paragraph form spent about three times the CPU
/// of the batched one, and the gap grows with the document.
async test "one request formats hundreds of paragraphs" {
  with_format_readback_dir(directory => {
    let builder = StringBuilder()
    let paragraphs = 300
    for index in 0..<paragraphs {
      if index > 0 {
        builder.write_string("</w:p><w:p>")
      }
      for run in 0..<8 {
        builder.write_string(
          "<w:r><w:t xml:space=\"preserve\">filler \{run} </w:t></w:r>",
        )
      }
      builder.write_string("<w:r><w:t>hello world</w:t></w:r>")
    }
    let source = format_readback_fixture(
      directory,
      "many.docx",
      builder.to_string(),
    )
    let output = directory + "/many-out.docx"
    let result = transact_docx_format(
      @transaction.transaction_options(source, output_path=output),
      format=@word.docx_direct_format(bold=true),
      text="world",
    )
    assert_eq(result.report().spans().length(), paragraphs)
    assert_eq(result.report().affected().length(), paragraphs)
    let published = @zip.read(@afs.read_file(output).binary())
    guard published.get("word/document.xml") is Some(payload) else {
      fail("no document part")
    }
    let document = @utf8.decode(payload)
    // One bold per selected span, and the filler runs are untouched.
    assert_eq(document.split("<w:b/>").collect().length() - 1, paragraphs)
    assert_eq(document.split("filler 0 ").collect().length() - 1, paragraphs)
  })
}
