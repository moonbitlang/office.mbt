// Blackbox witnesses for the N3b deletion planner: the splice removes
// exactly the addressed paragraph, the receipt names what leaves and
// who answers at the path afterwards, and every v1 refusal is typed.

///|
fn delete_fixture(body : String) -> @docx.DocxAnnotatedResult raise {
  let document = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:body>\{body}<w:sectPr/></w:body></w:document>"
  @docx.read_docx_annotated(fixture_docx(document))
}

///|
fn delete_refusal(body : String, at : String) -> String raise {
  let annotated = delete_fixture(body)
  try {
    ignore(@docx.plan_docx_paragraph_deletion(annotated, at~))
    "<planned>"
  } catch {
    error =>
      match error {
        @core.DocxError::Unsupported(message~) => message
        other => raise other
      }
  }
}

///|
/// The full round trip: plan a deletion, splice, re-read — the
/// paragraph is gone, the successor answers at the deleted path with
/// its own identity, and the receipt said all of it in advance.
test "deletion plans splice and read back without the deleted identity" {
  let body = "<w:p w14:paraId=\"00000001\"><w:r><w:t>first</w:t></w:r></w:p><w:p w14:paraId=\"00000002\"><w:r><w:t>second</w:t></w:r></w:p><w:p w14:paraId=\"00000003\"><w:r><w:t>third</w:t></w:r></w:p>"
  let annotated = delete_fixture(body)
  let (plan, receipt) = @docx.plan_docx_paragraph_deletion(annotated, at="p[2]")
  assert_eq(receipt.path(), "p[2]")
  assert_eq(receipt.para_id(), Some("00000002"))
  assert_eq(receipt.anchor_status(), "unique")
  assert_eq(receipt.text(), "second")
  assert_eq(receipt.successor_para_id(), Some("00000003"))
  let source = fixture_docx(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:body>\{body}<w:sectPr/></w:body></w:document>",
  )
  let spliced = @splice.splice_docx(source, plan)
  let reread = @docx.read_docx_annotated(spliced)
  let text = reread.result().document.to_raw_text()
  assert_true(!text.contains("second"))
  assert_true(text.contains("first"))
  assert_true(text.contains("third"))
  let index = @docx.docx_paragraph_anchor_index(
    reread,
    reread.main_story_source(),
  )
  // The successor answers at the deleted path; the deleted identity is
  // nowhere.
  match index.anchor_at("p[2]") {
    Some(anchor) => {
      assert_eq(anchor.para_id(), Some("00000003"))
      assert_eq(anchor.status(), "unique")
    }
    None => fail("the successor does not answer at the deleted path")
  }
  assert_eq(index.paragraphs_with_para_id("00000002"), [])
  assert_true(index.anchor_at("p[3]") is None)
}

///|
/// A paragraph without a paraId deletes fine — identity is optional,
/// the receipt just carries None.
test "deletion of an id-less paragraph reports no identity" {
  let annotated = delete_fixture(
    "<w:p><w:r><w:t>plain</w:t></w:r></w:p><w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  let (_, receipt) = @docx.plan_docx_paragraph_deletion(annotated, at="p[1]")
  assert_eq(receipt.para_id(), None)
  assert_eq(receipt.text(), "plain")
}

///|
/// Every v1 refusal class, each with its typed voice. `fldSimple` is
/// self-contained and permitted; `fldChar` pairs are global and refuse.
test "deletion refusals are typed per construct" {
  let keeper = "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>"
  // sectPr carrier
  assert_true(
    delete_refusal(
      "<w:p><w:pPr><w:sectPr/></w:pPr><w:r><w:t>x</w:t></w:r></w:p>" + keeper,
      "p[1]",
    ).contains("section break"),
  )
  // final direct body paragraph
  assert_true(
    delete_refusal("<w:p><w:r><w:t>only</w:t></w:r></w:p>", "p[1]").contains(
      "final direct body paragraph",
    ),
  )
  // note references
  assert_true(
    delete_refusal(
      "<w:p><w:r><w:footnoteReference w:id=\"1\"/></w:r></w:p>" + keeper,
      "p[1]",
    ).contains("footnote reference"),
  )
  assert_true(
    delete_refusal(
      "<w:p><w:r><w:endnoteReference w:id=\"1\"/></w:r></w:p>" + keeper,
      "p[1]",
    ).contains("endnote reference"),
  )
  // comment machinery
  assert_true(
    delete_refusal(
      "<w:p><w:commentRangeStart w:id=\"0\"/><w:r><w:t>x</w:t></w:r></w:p>" +
      keeper,
      "p[1]",
    ).contains("comment machinery"),
  )
  // bookmark markers: a named bookmark refuses; a crossing _GoBack
  // refuses; a wholly-internal _GoBack pair is Word's cursor artifact
  // and plans.
  assert_true(
    delete_refusal(
      "<w:p><w:bookmarkStart w:id=\"0\" w:name=\"b\"/><w:bookmarkEnd w:id=\"0\"/><w:r><w:t>x</w:t></w:r></w:p>" +
      keeper,
      "p[1]",
    ).contains("the bookmark 'b'"),
  )
  assert_true(
    delete_refusal(
      "<w:p><w:bookmarkStart w:id=\"0\" w:name=\"_GoBack\"/><w:r><w:t>x</w:t></w:r></w:p>" +
      "<w:p><w:bookmarkEnd w:id=\"0\"/><w:r><w:t>keeper</w:t></w:r></w:p>",
      "p[1]",
    ).contains("end lies outside"),
  )
  assert_true(
    delete_refusal(
      "<w:p><w:bookmarkStart w:id=\"0\" w:name=\"_GoBack\"/><w:r><w:t>x</w:t></w:r></w:p>" +
      "<w:p><w:bookmarkEnd w:id=\"0\"/><w:r><w:t>keeper</w:t></w:r></w:p>",
      "p[2]",
    ).contains("start lies outside"),
  )
  let goback = delete_fixture(
    "<w:p><w:bookmarkStart w:id=\"0\" w:name=\"_GoBack\"/><w:bookmarkEnd w:id=\"0\"/><w:r><w:t>cursor</w:t></w:r></w:p>" +
    keeper,
  )
  ignore(@docx.plan_docx_paragraph_deletion(goback, at="p[1]"))
  // split field boundary refuses; a self-contained simple field plans
  assert_true(
    delete_refusal(
      "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r></w:p>" + keeper,
      "p[1]",
    ).contains("split field boundary"),
  )
  let simple = delete_fixture(
    "<w:p><w:fldSimple w:instr=\" PAGE \"><w:r><w:t>1</w:t></w:r></w:fldSimple></w:p>" +
    keeper,
  )
  ignore(@docx.plan_docx_paragraph_deletion(simple, at="p[1]"))
  // revision content — the whole family, each by name
  for
    construct in [
      "ins", "del", "moveFrom", "moveTo", "moveFromRangeStart", "moveFromRangeEnd",
      "moveToRangeStart", "moveToRangeEnd", "rPrChange", "pPrChange", "sectPrChange",
      "tblPrChange", "trPrChange", "tcPrChange", "numberingChange", "cellIns", "cellDel",
    ] {
    assert_true(
      delete_refusal(
        "<w:p><w:r><w:t>x</w:t></w:r><w:\{construct}/></w:p>" + keeper,
        "p[1]",
      ).contains("tracked-revision content"),
      msg="expected the revision refusal for \{construct}",
    )
  }
  // drawings and embedded objects
  for construct in ["drawing", "object", "pict"] {
    assert_true(
      delete_refusal("<w:p><w:r><w:\{construct}/></w:r></w:p>" + keeper, "p[1]").contains(
        "drawing or embedded object",
      ),
      msg="expected the object refusal for \{construct}",
    )
  }
  // the remaining comment machinery names
  for construct in ["commentReference", "commentRangeEnd"] {
    assert_true(
      delete_refusal(
        "<w:p><w:r><w:t>x</w:t></w:r><w:\{construct} w:id=\"0\"/></w:p>" +
        keeper,
        "p[1]",
      ).contains("comment machinery"),
      msg="expected the comment refusal for \{construct}",
    )
  }
  // the anchor grammar and resolution refusals
  assert_true(
    delete_refusal(keeper + keeper, "p[0]").contains(
      "direct body paragraph (p[N])",
    ),
  )
  assert_true(
    delete_refusal(keeper + keeper, "p[9]").contains("does not resolve"),
  )
}

///|
/// The path grammar flattens wrappers, so "p[1]" can name a paragraph
/// INSIDE one — a deletion there must refuse on the element tree, not
/// trust the path.
test "deletion refuses a wrapped paragraph the path grammar flattens" {
  let annotated = delete_fixture(
    "<w:sdt><w:sdtContent><w:p><w:r><w:t>wrapped</w:t></w:r></w:p></w:sdtContent></w:sdt><w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  try {
    ignore(@docx.plan_docx_paragraph_deletion(annotated, at="p[1]"))
    fail("expected the direct-child refusal")
  } catch {
    error =>
      match error {
        @core.DocxError::Unsupported(message~) =>
          assert_true(message.contains("DIRECT child of the body"))
        other => raise other
      }
  }
}

///|
/// A hyperlink inside the paragraph deletes with it: the relationship
/// it leaves behind is an OPC-legal orphan, not dangling state.
test "deletion permits a hyperlink-bearing paragraph" {
  let annotated = delete_fixture(
    "<w:p><w:hyperlink><w:r><w:t>link</w:t></w:r></w:hyperlink></w:p><w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  let (_, receipt) = @docx.plan_docx_paragraph_deletion(annotated, at="p[1]")
  assert_eq(receipt.text(), "link")
}
