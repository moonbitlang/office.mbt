///|
/// End-to-end nets for DOCX bounded row repetition (#207 R3): the happy
/// invoice table, strip behavior, scalar/region ownership, the refusal
/// matrix, and record-ordinal missing accounting.

///|
async fn with_docx_region_dir(run : async (String) -> Unit) -> Unit {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-docx-regions-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    run(directory)
  }
}

///|
/// A title paragraph (scalar placeholder), one table with a static
/// header row and a template row, and a footer paragraph.
fn docx_region_fixture() -> Bytes raise {
  @word_fixture.write_docx([
    @word_fixture.paragraph([
      @word_fixture.run([@word_fixture.text("Invoice {{company}}")]),
    ]),
    @word_fixture.table([
      @word_fixture.table_row([
        @word_fixture.table_cell([
          @word_fixture.paragraph([
            @word_fixture.run([@word_fixture.text("Item")]),
          ]),
        ]),
        @word_fixture.table_cell([
          @word_fixture.paragraph([
            @word_fixture.run([@word_fixture.text("Qty")]),
          ]),
        ]),
      ]),
      @word_fixture.table_row([
        @word_fixture.table_cell([
          @word_fixture.paragraph([
            @word_fixture.run([@word_fixture.text("{{item}}")]),
          ]),
        ]),
        @word_fixture.table_cell([
          @word_fixture.paragraph([
            @word_fixture.run([@word_fixture.text("{{qty}} pcs")]),
          ]),
        ]),
      ]),
    ]),
    @word_fixture.paragraph([@word_fixture.run([@word_fixture.text("footer")])]),
  ])
}

///|
fn docx_region_data(records : String) -> @template.TemplateData raise {
  @template.parse_template_document(
    "{\"schema\": \"office.template.data/1\", " +
    "\"values\": {\"company\": \"ACME\"}, " +
    "\"regions\": {\"items\": {\"path\": \"/docx/body/tbl[1]/tr[2]\", \"records\": [" +
    records +
    "]}}}",
  )
}

///|
async fn published_document_xml(path : String) -> String {
  let bytes = @afs.read_file(path).binary()
  let archive = @zip.read(bytes[:])
  guard archive.get("word/document.xml") is Some(part) else {
    fail("published document.xml missing")
  }
  @utf8.decode(part)
}

///|
/// Rebuilds the fixture with one text replacement inside
/// word/document.xml, preserving entry order (a read+replace round trip
/// breaks bounded package identification).
fn docx_region_fixture_with(
  old_text : String,
  new_text : String,
) -> Bytes raise {
  let base = docx_region_fixture()
  let archive = @zip.read(base[:])
  let rebuilt = @zip.Archive::new()
  let mut replaced = false
  for entry in archive.entries() {
    let name = entry.name()
    guard archive.get(name) is Some(payload) else { continue }
    if name == "word/document.xml" {
      let text = @utf8.decode(payload)
      let injected = text.replace(old=old_text, new=new_text)
      if injected == text {
        fail("fixture shape changed; the injection found no anchor")
      }
      replaced = true
      rebuilt.add(name, @utf8.encode(injected))
    } else {
      rebuilt.add(name, payload.to_bytes())
    }
  }
  if !replaced {
    fail("fixture lacks word/document.xml")
  }
  @zip.write(rebuilt)
}

///|
async test "docx region merge clones the row and keeps everything else" {
  with_docx_region_dir() <| directory => {
    let input = directory + "/tpl.docx"
    @afs.write_file(
      input,
      docx_region_fixture(),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/filled.docx"
    let result = @docx.transact_docx_template_document(
      @transaction.transaction_options(input, output_path=output),
      docx_region_data(
        "{\"item\": \"Widget\", \"qty\": 2}, " +
        "{\"item\": \"Gadget\", \"qty\": 3}, " +
        "{\"item\": \"Gizmo\", \"qty\": 5}",
      ),
      allow_missing=false,
    )
    assert_eq(result.regions.length(), 1)
    assert_eq(result.regions[0].records, 3)
    // two placeholders per record row
    assert_eq(result.regions[0].replaced, 6)
    // the scalar pass handled the title and skipped the claimed row's
    // two cell paragraphs
    assert_eq(result.report.replaced, 7)
    assert_eq(result.scalar_paragraphs_skipped, 2)
    assert_true(result.report.changed)
    let document = published_document_xml(output)
    assert_true(document.contains("Invoice ACME"))
    assert_true(document.contains("Widget"))
    assert_true(document.contains("Gadget"))
    assert_true(document.contains("Gizmo"))
    assert_true(document.contains("2 pcs"))
    assert_true(document.contains("3 pcs"))
    assert_true(document.contains("5 pcs"))
    assert_true(document.contains("footer"))
    // the static header row survives exactly once; the table now holds
    // four rows
    let mut rows = 0
    let mut search = 0
    while search < document.length() {
      match document.substring(start=search).find("<w:tr") {
        Some(offset) => {
          rows += 1
          search = search + offset + 1
        }
        None => break
      }
    }
    assert_eq(rows, 4)
    // ordering: Widget before Gadget before Gizmo
    guard (
        document.find("Widget"),
        document.find("Gadget"),
        document.find("Gizmo"),
      )
      is (Some(first), Some(second), Some(third)) else {
      fail("clone texts missing")
    }
    assert_true(first < second && second < third)
  }
}

///|
async test "docx region strips paraId from every clone" {
  with_docx_region_dir() <| directory => {
    // inject paraId/textId into the template row's paragraph via rezip
    let tampered = docx_region_fixture_with(
      "<w:p><w:r><w:t>{{item}}</w:t></w:r></w:p>", "<w:p xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\" w14:paraId=\"11111111\" w14:textId=\"22222222\"><w:r><w:t>{{item}}</w:t></w:r></w:p>",
    )
    let input = directory + "/para.docx"
    @afs.write_file(input, tampered, create_mode=CreateNew, permission=0o600)
    let output = directory + "/para-out.docx"
    let result = @docx.transact_docx_template_document(
      @transaction.transaction_options(input, output_path=output),
      docx_region_data(
        "{\"item\": \"A\", \"qty\": 1}, {\"item\": \"B\", \"qty\": 2}",
      ),
      allow_missing=false,
    )
    assert_true(result.report.changed)
    let document = published_document_xml(output)
    // both clones carry the substituted text and neither carries the ids
    assert_true(document.contains(">A<"))
    assert_true(document.contains(">B<"))
    assert_false(document.contains("paraId"))
    assert_false(document.contains("textId"))
  }
}

///|
async test "docx region refusal matrix" {
  with_docx_region_dir() <| directory => {
    // a bookmark inside the row refuses via the gate
    let tampered = docx_region_fixture_with(
      "<w:p><w:r><w:t>{{item}}</w:t></w:r></w:p>", "<w:p><w:bookmarkStart w:id=\"0\" w:name=\"a\"/><w:bookmarkEnd w:id=\"0\"/><w:r><w:t>{{item}}</w:t></w:r></w:p>",
    )
    let bookmark_input = directory + "/bookmark.docx"
    @afs.write_file(
      bookmark_input,
      tampered,
      create_mode=CreateNew,
      permission=0o600,
    )
    let bookmark_output = directory + "/bookmark-out.docx"
    try
      @docx.transact_docx_template_document(
        @transaction.transaction_options(
          bookmark_input,
          output_path=bookmark_output,
        ),
        docx_region_data("{\"item\": \"A\", \"qty\": 1}"),
        allow_missing=false,
      )
      |> ignore
    catch {
      @docx.DocxTemplateRefused(report) => {
        assert_true(report.unsupported_total > 0)
        let mut seen = false
        for finding in report.unsupported {
          if finding.detail.contains("bookmarkStart") {
            seen = true
          }
        }
        assert_true(seen)
      }
      error => fail("expected DocxTemplateRefused, got \{error}")
    } noraise {
      _ => fail("expected the bookmark row to refuse")
    }
    assert_false(@afs.exists(bookmark_output))
    // header/footer paths and absent rows refuse as unsupported
    let mut refusal_case = 0
    for
      case in [
        ("/docx/header[1]/tbl[1]/tr[1]", "header and footer table rows"),
        ("/docx/body/tbl[1]/tr[9]", "no table row at"),
        ("/docx/body/tbl[1]/tr[1]", "carries no placeholder"),
      ] {
      let (path, fragment) = case
      refusal_case += 1
      let input = directory + "/refuse-\{refusal_case}.docx"
      @afs.write_file(
        input,
        docx_region_fixture(),
        create_mode=CreateNew,
        permission=0o600,
      )
      let output = input + ".out"
      let data = @template.parse_template_document(
        "{\"schema\": \"office.template.data/1\", \"values\": {}, " +
        "\"regions\": {\"items\": {\"path\": \"" +
        path +
        "\", \"records\": [{\"item\": \"x\"}]}}}",
      )
      try
        @docx.transact_docx_template_document(
          @transaction.transaction_options(input, output_path=output),
          data,
          allow_missing=false,
        )
        |> ignore
      catch {
        @docx.DocxTemplateRefused(report) => {
          let mut seen = false
          for finding in report.unsupported {
            if finding.detail.contains(fragment) {
              seen = true
            }
          }
          assert_true(seen)
        }
        error => fail("expected DocxTemplateRefused, got \{error}")
      } noraise {
        _ => fail("expected refusal: " + fragment)
      }
      assert_false(@afs.exists(output))
    }
  }
}

///|
async test "docx region missing keys carry record ordinals" {
  with_docx_region_dir() <| directory => {
    let input = directory + "/missing.docx"
    @afs.write_file(
      input,
      docx_region_fixture(),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/missing-out.docx"
    let data = docx_region_data(
      "{\"item\": \"A\", \"qty\": 1}, {\"item\": \"B\"}",
    )
    try
      @docx.transact_docx_template_document(
        @transaction.transaction_options(input, output_path=output),
        data,
        allow_missing=false,
      )
      |> ignore
    catch {
      @docx.DocxTemplateRefused(report) => {
        assert_eq(report.missing_total, 1)
        let mut seen = false
        for finding in report.missing {
          if finding.detail == "record 1: qty" {
            seen = true
          }
        }
        assert_true(seen)
      }
      error => fail("expected DocxTemplateRefused, got \{error}")
    } noraise {
      _ => fail("expected the missing record key to refuse")
    }
    assert_false(@afs.exists(output))
    // allow-missing publishes with the literal in that clone only
    let relaxed = @docx.transact_docx_template_document(
      @transaction.transaction_options(input, output_path=output),
      data,
      allow_missing=true,
    )
    assert_eq(relaxed.report.missing_total, 1)
    let document = published_document_xml(output)
    assert_true(document.contains("1 pcs"))
    assert_true(document.contains("{{qty}} pcs"))
  }
}

///|
async test "docx scalar-only documents match transact_docx_template" {
  with_docx_region_dir() <| directory => {
    let input = directory + "/scalar.docx"
    @afs.write_file(
      input,
      docx_region_fixture(),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/scalar-out.docx"
    let data = @template.parse_template_document(
      "{\"schema\": \"office.template.data/1\", \"values\": {\"company\": \"ACME\", \"item\": \"X\", \"qty\": 9}}",
    )
    let result = @docx.transact_docx_template_document(
      @transaction.transaction_options(input, output_path=output),
      data,
      allow_missing=false,
    )
    assert_eq(result.regions.length(), 0)
    assert_eq(result.scalar_paragraphs_skipped, 0)
    // the scalar pass substitutes INSIDE the table too when no region
    // claims it
    assert_eq(result.report.replaced, 3)
    let document = published_document_xml(output)
    assert_true(document.contains("Invoice ACME"))
    assert_true(document.contains(">X<"))
    assert_true(document.contains("9 pcs"))
  }
}

///|
async test "docx region unused keys attribute per region, not globally" {
  with_docx_region_dir() <| directory => {
    // "shared" is unused in region A (tr[2], which uses only item/qty)
    // but consumed in region B (tr[3]); region A record 0 must report it
    let two_row = {
      let archive = @zip.read(docx_region_fixture()[:])
      let rebuilt = @zip.Archive::new()
      for entry in archive.entries() {
        let name = entry.name()
        guard archive.get(name) is Some(payload) else { continue }
        if name == "word/document.xml" {
          let text = @utf8.decode(payload)
          let anchor = "<w:tr><w:tc><w:p><w:r><w:t>{{item}}</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>{{qty}} pcs</w:t></w:r></w:p></w:tc></w:tr>"
          let clone_row = "<w:tr><w:tc><w:p><w:r><w:t>{{code}}</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>{{shared}}</w:t></w:r></w:p></w:tc></w:tr>"
          let injected = text.replace(old=anchor, new=anchor + clone_row)
          if injected == text {
            fail("two-row injection found no anchor")
          }
          rebuilt.add(name, @utf8.encode(injected))
        } else {
          rebuilt.add(name, payload.to_bytes())
        }
      }
      @zip.write(rebuilt)
    }
    let input = directory + "/two-region.docx"
    @afs.write_file(input, two_row, create_mode=CreateNew, permission=0o600)
    let output = directory + "/two-region-out.docx"
    // region A (tr[2]) provides shared as an UNUSED record key; region B
    // (tr[3]) consumes it
    let data = @template.parse_template_document(
      "{\"schema\": \"office.template.data/1\", \"values\": {\"company\": \"C\"}, \"regions\": {" +
      "\"a\": {\"path\": \"/docx/body/tbl[1]/tr[2]\", \"records\": [{\"item\": \"i\", \"qty\": 1, \"shared\": \"x\"}]}, " +
      "\"b\": {\"path\": \"/docx/body/tbl[1]/tr[3]\", \"records\": [{\"code\": \"c\", \"shared\": \"y\"}]}}}",
    )
    let result = @docx.transact_docx_template_document(
      @transaction.transaction_options(input, output_path=output),
      data,
      allow_missing=false,
    )
    // region A's record 0 carries shared but its row never uses it
    let mut seen = false
    for key in result.report.unused {
      if key == "region a record 0: shared" {
        seen = true
      }
    }
    assert_true(seen)
  }
}

///|
async test "docx region clone bytes are bounded before allocation" {
  with_docx_region_dir() <| directory => {
    let input = directory + "/huge.docx"
    @afs.write_file(
      input,
      docx_region_fixture(),
      create_mode=CreateNew,
      permission=0o600,
    )
    let output = directory + "/huge-out.docx"
    // 4096 records each carrying a 65536-unit value: the pre-allocation
    // bound must refuse before materializing
    let big = String::make(65536, 'x')
    let records = StringBuilder::new()
    for index in 0..<4096 {
      if index > 0 {
        records.write_string(", ")
      }
      records.write_string("{\"item\": \"" + big + "\", \"qty\": 1}")
    }
    let data = @template.parse_template_document(
      "{\"schema\": \"office.template.data/1\", \"values\": {\"company\": \"C\"}, " +
      "\"regions\": {\"items\": {\"path\": \"/docx/body/tbl[1]/tr[2]\", \"records\": [" +
      records.to_string() +
      "]}}}",
    )
    try
      @docx.transact_docx_template_document(
        @transaction.transaction_options(input, output_path=output),
        data,
        allow_missing=false,
      )
      |> ignore
    catch {
      @docx.DocxTemplateRefused(report) => {
        let mut seen = false
        for finding in report.unsupported {
          if finding.detail.contains("materialize more than") {
            seen = true
          }
        }
        assert_true(seen)
      }
      error => fail("expected a bounded refusal, got \{error}")
    } noraise {
      _ => fail("expected the oversized merge to refuse")
    }
    assert_false(@afs.exists(output))
  }
}
