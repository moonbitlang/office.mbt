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
  delete_refusal_of(delete_fixture(body), at)
}

///|
fn delete_refusal_of(
  annotated : @docx.DocxAnnotatedResult,
  at : String,
) -> String raise {
  try {
    ignore(@docx.plan_docx_paragraph_deletion(annotated, at~))
    "<planned>"
  } catch {
    Unsupported(message~) => message
    other => raise other
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
  assert_eq(receipt.successor_text(), Some("third"))
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
  // Both identity legs of the readback go quiet in this regime — most
  // producers other than Word emit no paraIds at all — so the receipt
  // still carries the successor's TEXT, which is what the readback
  // has left to verify with.
  assert_eq(receipt.successor_para_id(), None)
  assert_eq(receipt.successor_text(), Some("keeper"))
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
    ).contains("a section break"),
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
    ).contains("a named bookmark"),
  )
  assert_true(
    delete_refusal(
      "<w:p><w:bookmarkStart w:id=\"0\" w:name=\"_GoBack\"/><w:r><w:t>x</w:t></w:r></w:p>" +
      "<w:p><w:bookmarkEnd w:id=\"0\"/><w:r><w:t>keeper</w:t></w:r></w:p>",
      "p[1]",
    ).contains("do not pair inside it"),
  )
  assert_true(
    delete_refusal(
      "<w:p><w:bookmarkStart w:id=\"0\" w:name=\"_GoBack\"/><w:r><w:t>x</w:t></w:r></w:p>" +
      "<w:p><w:bookmarkEnd w:id=\"0\"/><w:r><w:t>keeper</w:t></w:r></w:p>",
      "p[2]",
    ).contains("do not pair inside it"),
  )
  // id-less and id-colliding bookmark markers cannot be pair-judged
  assert_true(
    delete_refusal(
      "<w:p><w:bookmarkStart w:name=\"_GoBack\"/><w:bookmarkEnd w:id=\"0\"/><w:r><w:t>x</w:t></w:r></w:p>" +
      keeper,
      "p[1]",
    ).contains("without a usable id"),
  )
  // Pairing is judged as a MULTISET, so an extra end inside refuses
  // even though set membership would have called it paired…
  assert_true(
    delete_refusal(
      "<w:p><w:bookmarkStart w:id=\"0\" w:name=\"_GoBack\"/><w:bookmarkEnd w:id=\"0\"/><w:bookmarkEnd w:id=\"0\"/><w:r><w:t>x</w:t></w:r></w:p>" +
      keeper,
      "p[1]",
    ).contains("do not pair inside it"),
  )
  // …and an END inside the target, while a range of that family is
  // open across it, refuses: whatever the ids say, a consumer could
  // pair that boundary with the outside start, and taking it strands
  // the start.
  assert_true(
    delete_refusal(
      "<w:p><w:bookmarkStart w:id=\"7\" w:name=\"Chapter1\"/><w:r><w:t>outside</w:t></w:r></w:p>" +
      "<w:p><w:bookmarkStart w:id=\"7\" w:name=\"_GoBack\"/><w:bookmarkEnd w:id=\"7\"/><w:r><w:t>x</w:t></w:r></w:p>" +
      keeper +
      "<w:bookmarkEnd w:id=\"7\"/>",
      "p[2]",
    ).contains("carries the end of a bookmark range opened before it"),
  )
  // range permissions pair across paragraphs
  for construct in ["permStart", "permEnd"] {
    assert_true(
      delete_refusal(
        "<w:p><w:\{construct} w:id=\"1\"/><w:r><w:t>x</w:t></w:r></w:p>" +
        keeper,
        "p[1]",
      ).contains("range-permission boundary"),
      msg="expected the permission refusal for \{construct}",
    )
  }
  // the customXml revision range markers come from the reader's own
  // vocabulary, not a hand copy
  for
    construct in [
      "customXmlInsRangeStart", "customXmlInsRangeEnd", "customXmlDelRangeStart",
      "customXmlDelRangeEnd", "customXmlMoveFromRangeStart", "customXmlMoveFromRangeEnd",
      "customXmlMoveToRangeStart", "customXmlMoveToRangeEnd", "cellMerge", "tblGridChange",
      "tblPrExChange",
    ] {
    assert_true(
      delete_refusal(
        "<w:p><w:r><w:t>x</w:t></w:r><w:\{construct}/></w:p>" + keeper,
        "p[1]",
      ).contains("tracked-revision content"),
      msg="expected the revision refusal for \{construct}",
    )
  }
  // block-level content the reader tolerated inside the paragraph: the
  // physical span holds more than the receipt could name, and a table
  // that left with it is invisible to every readback leg
  assert_true(
    delete_refusal(
      "<w:p><w:r><w:t>pre</w:t></w:r><w:tbl><w:tr><w:tc><w:tcPr/></w:tc></w:tr></w:tbl></w:p>" +
      keeper,
      "p[1]",
    ).contains("a nested table"),
  )
  // a nested paragraph the reader tolerated: the physical span holds
  // more logical paragraphs than the receipt could name
  assert_true(
    delete_refusal(
      "<w:p><w:r><w:t>pre</w:t></w:r><w:p><w:r><w:t>inner</w:t></w:r></w:p></w:p>" +
      keeper,
      "p[1]",
    ).contains("a nested paragraph"),
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
    ).contains("a field boundary"),
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
        "an embedded object",
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
  assert_true(
    delete_refusal_of(annotated, "p[1]").contains("DIRECT child of the body"),
  )
}

///|
/// The relationship-reference class is judged by resolved attribute
/// URI, mechanically: any element carrying an `r:`-namespace attribute
/// refuses — `w:contentPart`, or anything future — while a hyperlink
/// (the one designed exemption) deletes with its OPC-legal orphan rel,
/// and an `r`-PREFIXED attribute bound to some other namespace does
/// not trigger the class.
test "deletion judges relationship references by URI" {
  let refusal = delete_refusal(
    "<w:p xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><w:r><w:contentPart r:id=\"rId9\"/></w:r></w:p><w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
    "p[1]",
  )
  assert_true(refusal.contains("references a package relationship"))
  let hyperlinked = delete_fixture(
    "<w:p xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><w:hyperlink r:id=\"rId5\"><w:r><w:t>link</w:t></w:r></w:hyperlink></w:p><w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  let (_, receipt) = @docx.plan_docx_paragraph_deletion(hyperlinked, at="p[1]")
  assert_eq(receipt.text(), "link")
  // The class judges the resolved URI in BOTH dialects: a Strict
  // package binds r: to the purl spelling, and the refusal must not
  // be inert there.
  let strict = delete_refusal(
    "<w:p xmlns:r=\"http://purl.oclc.org/ooxml/officeDocument/relationships\"><w:r><w:contentPart r:id=\"rId9\"/></w:r></w:p><w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
    "p[1]",
  )
  assert_true(strict.contains("references a package relationship"))
  let masquerade = delete_fixture(
    "<w:p xmlns:r=\"urn:example:not-relationships\"><w:r r:id=\"x\"><w:t>plain</w:t></w:r></w:p><w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  let (_, receipt2) = @docx.plan_docx_paragraph_deletion(masquerade, at="p[1]")
  assert_eq(receipt2.text(), "plain")
}

///|
/// A paragraph between two tables is the separator that keeps them
/// apart: to a consumer, two adjacent `w:tbl` elements are ONE table,
/// so deleting it merges them — structural corruption no readback of
/// paragraph identity could notice. Neighbours decide this, not the
/// target's own subtree, and the target is EMPTY in the witness so no
/// other class could be doing the work.
test "deletion refuses the separator between two tables" {
  let table = "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  let annotated = delete_fixture(
    "<w:p><w:r><w:t>lead</w:t></w:r></w:p>" +
    table +
    "<w:p/>" +
    table +
    "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  assert_true(
    delete_refusal_of(annotated, "p[2]").contains("separates two tables"),
  )
  // A paragraph between a table and a PARAGRAPH is ordinary content.
  let ordinary = delete_fixture(
    table +
    "<w:p><w:r><w:t>between</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  assert_eq(delete_refusal_of(ordinary, "p[1]"), "<planned>")
}

///|
/// Neighbours are judged as FLOW, the way the projection reads the
/// story: a zero-width marker between the paragraph and a table does
/// not separate them, and a table inside a transparent wrapper is
/// still the adjacent table. Both shapes are what Word emits.
test "the table-separator refusal reads neighbours as flow" {
  let table = "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  let keeper = "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>"
  // A body-level bookmarkEnd between the table and the separator.
  let marked = delete_fixture(
    table + "<w:bookmarkEnd w:id=\"0\"/><w:p/>" + table + keeper,
  )
  assert_true(
    delete_refusal_of(marked, "p[1]").contains("separates two tables"),
  )
  // The following table wrapped in a content control — the projection
  // already calls it the adjacent table.
  let wrapped = delete_fixture(
    table +
    "<w:p/><w:sdt><w:sdtContent>" +
    table +
    "</w:sdtContent></w:sdt>" +
    keeper,
  )
  assert_true(
    delete_refusal_of(wrapped, "p[1]").contains("separates two tables"),
  )
}

///|
/// A comment or permission range anchored by the target's own SIBLINGS
/// brackets it: the markers are not inside the span, so the subtree
/// scan cannot see them, and deleting the paragraph leaves the range
/// anchoring nothing.
test "deletion refuses a paragraph a sibling range brackets" {
  let commented = delete_fixture(
    "<w:commentRangeStart w:id=\"1\"/><w:p><w:r><w:t>target</w:t></w:r></w:p><w:commentRangeEnd w:id=\"1\"/>" +
    "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  assert_true(
    delete_refusal_of(commented, "p[1]").contains("sits inside a comment range"),
  )
  let permitted = delete_fixture(
    "<w:permStart w:id=\"1\" w:edGrp=\"everyone\"/><w:p><w:r><w:t>target</w:t></w:r></w:p><w:permEnd w:id=\"1\"/>" +
    "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  assert_true(
    delete_refusal_of(permitted, "p[1]").contains(
      "sits inside a range permission",
    ),
  )
  // A range that CLOSES before the target does not bracket it.
  let closed = delete_fixture(
    "<w:commentRangeStart w:id=\"1\"/><w:p><w:r><w:t>other</w:t></w:r></w:p><w:commentRangeEnd w:id=\"1\"/>" +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p><w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  assert_eq(delete_refusal_of(closed, "p[2]"), "<planned>")
}

///|
/// Two questions, two surfaces, and the difference matters both ways.
///
/// "Will the body still have a direct paragraph?" is STRUCTURAL: a
/// paragraph nested in a content control does not keep the body's last
/// direct one company, so deleting the only direct paragraph refuses
/// even though the flattened path space still shows a successor.
///
/// "Who answers at the deleted path?" is FLATTENED: that IS the wrapped
/// paragraph, and the receipt reports its text, because that is what an
/// agent must re-anchor on.
test "the final-paragraph guard is structural, the successor is flattened" {
  // The rule is what the comment says: the body must still END with a
  // paragraph. A wrapped paragraph IS the body's last flow child, so
  // this deletion is fine…
  let wrapped_only = delete_fixture(
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:sdt><w:sdtContent><w:p><w:r><w:t>next</w:t></w:r></w:p></w:sdtContent></w:sdt>",
  )
  assert_eq(delete_refusal_of(wrapped_only, "p[1]"), "<planned>")
  // …and deleting the last of two ordinary paragraphs, the commonest
  // deletion there is, leaves a body ending in a paragraph too.
  let pair = delete_fixture(
    "<w:p><w:r><w:t>one</w:t></w:r></w:p><w:p><w:r><w:t>two</w:t></w:r></w:p>",
  )
  assert_eq(delete_refusal_of(pair, "p[2]"), "<planned>")
  // What the rule DOES stop: a deletion that MAKES the body end with a
  // table — the target is the last flow child and a table precedes it.
  let table_last = delete_fixture(
    "<w:p><w:r><w:t>one</w:t></w:r></w:p>" +
    "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl>" +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>",
  )
  assert_true(
    delete_refusal_of(table_last, "p[2]").contains(
      "final direct body paragraph",
    ),
  )
  // And what it does NOT stop: a middle deletion in a body that already
  // ends with a table. That ending is not this deletion's doing.
  let already_table_last = delete_fixture(
    "<w:p><w:r><w:t>one</w:t></w:r></w:p><w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl>",
  )
  assert_eq(delete_refusal_of(already_table_last, "p[2]"), "<planned>")
  // With a direct paragraph further on, the deletion proceeds — and the
  // receipt names the WRAPPED paragraph as the successor, because that
  // is the one that answers at the deleted path afterwards.
  let both = delete_fixture(
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:sdt><w:sdtContent><w:p><w:r><w:t>wrapped</w:t></w:r></w:p></w:sdtContent></w:sdt>" +
    "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  let (_, receipt) = @docx.plan_docx_paragraph_deletion(both, at="p[1]")
  assert_eq(receipt.text(), "target")
  assert_eq(receipt.successor_text(), Some("wrapped"))
}

///|
/// Flow is an ALLOW-LIST, so the shapes Word actually emits cannot slip
/// between a paragraph and its neighbouring table: a content control
/// carries `w:sdtPr` before its content, and none of that is flow.
test "flow sees past the markup Word puts between blocks" {
  let table = "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  let keeper = "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>"
  let shapes = [
    // a real content control, properties and all
    "<w:sdt><w:sdtPr><w:id w:val=\"1\"/></w:sdtPr><w:sdtContent>" +
    table +
    "</w:sdtContent></w:sdt>",
    // a customXml wrapper
    "<w:customXml w:element=\"x\">" + table + "</w:customXml>",
    // compatibility alternatives
    "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"><mc:Fallback>" +
    table +
    "</mc:Fallback></mc:AlternateContent>",
  ]
  for shape in shapes {
    let annotated = delete_fixture(table + "<w:p/>" + shape + keeper)
    assert_true(
      delete_refusal_of(annotated, "p[1]").contains("separates two tables"),
      msg="a table behind " + shape[0:12].to_owned() + " is still a table",
    )
  }
  // And a marker between blocks is not flow either.
  let marked = delete_fixture(
    table +
    "<w:customXmlMoveFromRangeStart w:id=\"3\" w:name=\"x\"/><w:p/>" +
    table +
    keeper,
  )
  assert_true(
    delete_refusal_of(marked, "p[1]").contains("separates two tables"),
  )
}

///|
/// Range families have INDEPENDENT id spaces: a permission numbered 1
/// must neither close a comment range numbered 1 nor fabricate one.
test "bracketing ranges do not cross families" {
  let keeper = "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>"
  // A permission pair sharing id 1 must not clear the open comment
  // range that actually brackets the target.
  let crossed = delete_fixture(
    "<w:commentRangeStart w:id=\"1\"/><w:permStart w:id=\"1\" w:edGrp=\"everyone\"/><w:permEnd w:id=\"1\"/>" +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p><w:commentRangeEnd w:id=\"1\"/>" +
    keeper,
  )
  assert_true(
    delete_refusal_of(crossed, "p[1]").contains("sits inside a comment range"),
  )
  // A cross-family pair is not a range at all.
  let mismatched = delete_fixture(
    "<w:permStart w:id=\"1\" w:edGrp=\"everyone\"/><w:p><w:r><w:t>target</w:t></w:r></w:p><w:commentRangeEnd w:id=\"1\"/>" +
    keeper,
  )
  let mismatched_refusal = delete_refusal_of(mismatched, "p[1]")
  assert_true(!mismatched_refusal.contains("sits inside a comment range"))
  // Every paired family is judged, not just comments and permissions.
  for
    pair in [
      ("moveFromRangeStart", "moveFromRangeEnd"),
      ("moveToRangeStart", "moveToRangeEnd"),
      ("customXmlInsRangeStart", "customXmlInsRangeEnd"),
    ] {
    let (open_name, close_name) = pair
    let annotated = delete_fixture(
      "<w:\{open_name} w:id=\"1\" w:name=\"m\"/><w:p><w:r><w:t>target</w:t></w:r></w:p><w:\{close_name} w:id=\"1\"/>" +
      keeper,
    )
    assert_true(
      delete_refusal_of(annotated, "p[1]").contains("sits inside"),
      msg="expected an open-range refusal for \{open_name}",
    )
  }
  // A named bookmark bracketing the target refuses; Word's _GoBack
  // caret does not.
  let bookmarked = delete_fixture(
    "<w:bookmarkStart w:id=\"1\" w:name=\"Chapter\"/><w:p><w:r><w:t>target</w:t></w:r></w:p><w:bookmarkEnd w:id=\"1\"/>" +
    keeper,
  )
  assert_true(
    delete_refusal_of(bookmarked, "p[1]").contains(
      "sits inside a bookmark range",
    ),
  )
  // A caret that BRACKETS a whole paragraph refuses too. Word collapses
  // `_GoBack` at the cursor, so a bracketing one is not a shape it
  // emits, and buying its exemption back would mean reading ids and
  // names again — the model whose every corner this collapse removed.
  // Over-refusal in the safe direction, stated plainly.
  let caret = delete_fixture(
    "<w:bookmarkStart w:id=\"1\" w:name=\"_GoBack\"/><w:p><w:r><w:t>target</w:t></w:r></w:p><w:bookmarkEnd w:id=\"1\"/>" +
    keeper,
  )
  assert_true(
    delete_refusal_of(caret, "p[1]").contains("sits inside a bookmark range"),
  )
  // The caret INSIDE a paragraph — the shape Word actually emits — is
  // still deletable with it.
  let collapsed = delete_fixture(
    "<w:p><w:bookmarkStart w:id=\"1\" w:name=\"_GoBack\"/><w:bookmarkEnd w:id=\"1\"/><w:r><w:t>target</w:t></w:r></w:p>" +
    keeper,
  )
  assert_eq(delete_refusal_of(collapsed, "p[1]"), "<planned>")
}

///|
/// The two ways a naive range counter goes wrong, both reproduced by
/// review before they were fixed.
test "range counting refuses what it cannot pair and nothing else" {
  let keeper = "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>"
  // An ORPHAN END before the target must not cancel a range that is
  // genuinely open across it. Counting alone cannot tell which range an
  // end closes, so an unbalanced story is one this verb declines to
  // judge at all.
  let orphan_end = delete_fixture(
    "<w:bookmarkStart w:id=\"1\" w:name=\"Chapter\"/><w:bookmarkEnd w:id=\"7\"/>" +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p><w:bookmarkEnd w:id=\"1\"/>" +
    keeper,
  )
  assert_true(
    delete_refusal_of(orphan_end, "p[1]").contains("not properly nested"),
  )
  // An ORPHAN START before the target must not make a LATER, unrelated
  // range's end refuse every paragraph in between. Only a range whose
  // depth falls below its entry level after the target spans it.
  let orphan_start = delete_fixture(
    "<w:bookmarkStart w:id=\"1\" w:name=\"Orphan\"/>" +
    "<w:p><w:r><w:t>one</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>two</w:t></w:r></w:p>" +
    "<w:bookmarkStart w:id=\"2\" w:name=\"Real\"/><w:p><w:r><w:t>bracketed</w:t></w:r></w:p><w:bookmarkEnd w:id=\"2\"/>" +
    keeper,
  )
  // An unbalanced story is one this verb declines to judge AT ALL,
  // uniformly and with a message that says so — rather than refusing
  // some paragraphs while naming a range that does not cover them.
  for path in ["p[1]", "p[2]", "p[3]"] {
    assert_true(
      delete_refusal_of(orphan_start, path).contains("not properly nested"),
      msg="expected the well-formedness refusal at " + path,
    )
  }
  // A story whose markers DO balance judges each paragraph on its own:
  // only the one the range covers refuses.
  let balanced = delete_fixture(
    "<w:p><w:r><w:t>one</w:t></w:r></w:p>" +
    "<w:bookmarkStart w:id=\"2\" w:name=\"Real\"/><w:p><w:r><w:t>covered</w:t></w:r></w:p><w:bookmarkEnd w:id=\"2\"/>" +
    keeper,
  )
  assert_eq(delete_refusal_of(balanced, "p[1]"), "<planned>")
  assert_true(
    delete_refusal_of(balanced, "p[2]").contains("sits inside a bookmark range"),
  )
}

///|
/// An INVERTED pair — an end before its start — nets to zero across
/// the story, so a total cannot see it. A running prefix minimum can,
/// and must, because such a story leaves a real range unpairable.
test "an inverted range pair is not balanced" {
  let keeper = "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>"
  let inverted = delete_fixture(
    "<w:bookmarkEnd w:id=\"1\"/><w:bookmarkStart w:id=\"2\" w:name=\"Real\"/>" +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:bookmarkEnd w:id=\"2\"/><w:bookmarkStart w:id=\"1\" w:name=\"Late\"/>" +
    keeper,
  )
  assert_true(
    delete_refusal_of(inverted, "p[1]").contains("not properly nested"),
  )
  // The shape a running minimum alone cannot see: an inversion NESTED
  // inside another open range of the same family, whose prefix sums
  // never dip below zero. Well-formedness catches it because the
  // nesting is still wrong.
  let nested_inversion = delete_fixture(
    "<w:bookmarkStart w:id=\"7\" w:name=\"Wide\"/><w:bookmarkEnd w:id=\"9\"/>" +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:bookmarkStart w:id=\"9\" w:name=\"Late\"/><w:bookmarkEnd w:id=\"7\"/>" +
    keeper,
  )
  assert_true(
    delete_refusal_of(nested_inversion, "p[1]").contains("not properly nested"),
  )
}

///|
/// A stray marker that cannot reach the target does not take the whole
/// document out: the balance refusal applies to families whose markers
/// STRADDLE the target, not to every family in the story.
test "an unbalanced family away from the target still permits deletion" {
  let annotated = delete_fixture(
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>" +
    "<w:bookmarkStart w:id=\"9\" w:name=\"Orphan\"/>",
  )
  assert_eq(delete_refusal_of(annotated, "p[1]"), "<planned>")
}

///|
/// `w:id` normalizes as a NUMBER only when it is one: `0abc` is not
/// zero followed by letters, and collapsing it onto `abc` would pair
/// two ids a consumer keeps apart.
test "only decimal ids normalize as decimals" {
  let keeper = "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>"
  // `01` and `1` ARE the same id, so this pairs and plans.
  let numeric = delete_fixture(
    "<w:p><w:bookmarkStart w:id=\"01\" w:name=\"_GoBack\"/><w:bookmarkEnd w:id=\"1\"/><w:r><w:t>x</w:t></w:r></w:p>" +
    keeper,
  )
  assert_eq(delete_refusal_of(numeric, "p[1]"), "<planned>")
  // `0abc` and `abc` are NOT, so this cannot pair and refuses.
  let textual = delete_fixture(
    "<w:p><w:bookmarkStart w:id=\"0abc\" w:name=\"_GoBack\"/><w:bookmarkEnd w:id=\"abc\"/><w:r><w:t>x</w:t></w:r></w:p>" +
    keeper,
  )
  assert_true(
    delete_refusal_of(textual, "p[1]").contains("do not pair inside it"),
  )
}

///|
/// A field boundary whose type has two WML-resolved spellings is one
/// this reader cannot judge — and a field whose depth cannot be judged
/// is one this verb will not edit around. (The reader's own projection
/// keeps its last-wins precedence; only the GATE is stricter.)
test "an ambiguous field boundary refuses" {
  let document = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:s=\"http://purl.oclc.org/ooxml/wordprocessingml/main\"><w:body>" +
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\" s:fldCharType=\"end\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>keeper</w:t></w:r></w:p><w:sectPr/></w:body></w:document>"
  let annotated = @docx.read_docx_annotated(fixture_docx(document))
  assert_true(
    delete_refusal_of(annotated, "p[2]").contains(
      "cannot be read unambiguously",
    ),
  )
}

///|
/// Fields are judged by the SAME well-formedness rule as ranges, and
/// the message says which: a story carrying an orphan `begin` is one
/// whose field extents cannot be judged, so a paragraph between that
/// orphan and a later field refuses — accurately, rather than naming a
/// region that does not exist. A story whose fields ARE well formed is
/// judged position by position.
test "field extents are judged only on a well-formed story" {
  let orphaned = delete_fixture(
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>plain</w:t></w:r></w:p>" +
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r><w:r><w:instrText>PAGE</w:instrText></w:r><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  assert_true(
    delete_refusal_of(orphaned, "p[2]").contains("not properly nested"),
  )
  // Well formed: the paragraph beside a self-contained field is
  // deletable, the one inside a field is not.
  let sound = delete_fixture(
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>inside</w:t></w:r></w:p>" +
    "<w:p><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>outside</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  assert_true(
    delete_refusal_of(sound, "p[2]").contains("sits inside a field region"),
  )
  assert_eq(delete_refusal_of(sound, "p[4]"), "<planned>")
}

///|
/// A field boundary inside track-DELETED content STILL COUNTS. The
/// splice is physical and the boundary is physically there: a consumer
/// that rejects the tracked deletion gets its field back, and it would
/// then span a hole where this paragraph used to be. Reading the
/// projection here would be the more elegant answer to the wrong
/// question.
test "a suppressed field boundary still opens a region" {
  let annotated = delete_fixture(
    "<w:p><w:del w:id=\"1\" w:author=\"a\"><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r></w:del></w:p>" +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:p><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  assert_true(
    delete_refusal_of(annotated, "p[2]").contains("inside a field region"),
  )
}

///|
/// The relationship class judges the target's OWN attributes too, not
/// only its descendants'.
test "the target's own relationship attribute is judged" {
  let annotated = delete_fixture(
    "<w:p xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\" r:id=\"rId9\"><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  assert_true(
    delete_refusal_of(annotated, "p[1]").contains(
      "references a package relationship",
    ),
  )
}

///|
/// Co-authoring conflict revisions live in the w14 namespace, which the
/// WML revision vocabulary does not reach — they are revision history
/// all the same.
test "deletion refuses w14 conflict revisions" {
  let keeper = "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>"
  for
    construct in [
      "conflictIns", "conflictDel", "conflictInsDel", "conflictMoveFrom", "conflictMoveTo",
    ] {
    let annotated = delete_fixture(
      "<w:p xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w14:\{construct}><w:r><w:t>x</w:t></w:r></w14:\{construct}></w:p>" +
      keeper,
    )
    assert_true(
      delete_refusal_of(annotated, "p[1]").contains("tracked-revision content"),
      msg="expected the conflict refusal for \{construct}",
    )
  }
}

///|
/// A paragraph strictly INSIDE a field region carries part of a field
/// whose boundaries live in other paragraphs — the instruction or the
/// result would be truncated with it. The target here carries no
/// `fldChar` of its own, so only the region judgment can refuse it.
test "deletion refuses a paragraph inside a field region" {
  let annotated = delete_fixture(
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r></w:p>" +
    "<w:p><w:r><w:instrText> HYPERLINK \\l \"_Toc12\" </w:instrText></w:r></w:p>" +
    "<w:p><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  assert_true(
    delete_refusal_of(annotated, "p[2]").contains("inside a field region"),
  )
  // After the region closes, ordinary paragraphs delete normally.
  let after = delete_fixture(
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r></w:p>" +
    "<w:p><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>free</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  let (_, receipt) = @docx.plan_docx_paragraph_deletion(after, at="p[3]")
  assert_eq(receipt.text(), "free")
}

///|
/// A deleted paragraph MARK joins two physical paragraphs into one
/// logical paragraph. Neither half is a deletable target: the tail's
/// path is claimed by nobody (tombstoned to None) and the head is
/// `multi_physical`. Both refuse, and the physical count still sees
/// all three — the readback compares physical counts on both sides,
/// so a tombstoned story cannot truncate the walk and falsely refuse
/// a sound deletion elsewhere.
test "deletion refuses either half of a revision-joined paragraph" {
  let joined = delete_fixture(
    "<w:p><w:pPr><w:rPr><w:del w:id=\"1\" w:author=\"a\"/></w:rPr></w:pPr><w:r><w:t>head</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>tail</w:t></w:r></w:p><w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  let index = @docx.docx_paragraph_anchor_index(
    joined,
    joined.main_story_source(),
  )
  // The shape the refusals stand on, pinned so a reader change that
  // removes the join surfaces here rather than silently weakening the
  // tests below.
  assert_true(index.anchor_at("p[2]") is None)
  guard index.anchor_at("p[1]") is Some(head) else {
    fail("expected the joined head to anchor")
  }
  assert_eq(head.status(), "multi_physical")
  assert_true(
    delete_refusal_of(joined, "p[2]").contains(
      "does not address exactly one whole paragraph",
    ),
  )
  // The head refuses on its own terms even though its subtree also
  // carries the revision markup that caused the join.
  assert_true(
    delete_refusal_of(joined, "p[1]").contains("tracked-revision content"),
  )
  // The physical count is blind to tombstones, which is what the
  // readback needs.
  assert_eq(@docx.docx_direct_body_paragraph_count(joined), 3)
  // The `multi_physical` guard in the planner is a STANDING guarantee,
  // not a reachable path: every join today is made by a deleted
  // paragraph mark whose `w:del` sits in the head's own subtree, so the
  // revision class always speaks first. This test deliberately does not
  // claim to exercise it — asserting "some refusal happened" here would
  // pass on the revision refusal and read as coverage it is not.
}

///|
/// The refusal SLUG is the wire contract an agent branches on, so the
/// planner's own suite pins it — asserting prose alone would let a
/// rename move a hazard's code with every test still green.
test "planner refusals carry their slugs" {
  let keeper = "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>"
  let table = "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  for
    probe in [
      ("<w:p><w:r><w:t>only</w:t></w:r></w:p>", "p[1]", "final_paragraph"),
      (keeper + keeper, "p[9]", "target_not_found"),
      (keeper + keeper, "p[0]", "target_not_direct"),
      (
        "<w:p><w:r><w:footnoteReference w:id=\"1\"/></w:r></w:p>" + keeper,
        "p[1]",
        "blocked_construct",
      ),
      (table + "<w:p/>" + table + keeper, "p[1]", "table_separator"),
      (
        "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r></w:p>" +
        "<w:p><w:r><w:t>x</w:t></w:r></w:p>" +
        "<w:p><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>" +
        keeper,
        "p[2]",
        "field_region",
      ),
      (
        "<w:bookmarkStart w:id=\"3\" w:name=\"R\"/><w:p><w:r><w:t>x</w:t></w:r></w:p><w:bookmarkEnd w:id=\"3\"/>" +
        keeper,
        "p[1]",
        "open_range",
      ),
      (
        "<w:p><w:bookmarkStart w:id=\"4\" w:name=\"_GoBack\"/><w:r><w:t>x</w:t></w:r></w:p>" +
        keeper,
        "p[1]",
        "bookmark_unpairable",
      ),
      (
        "<w:p xmlns:r=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships\"><w:r><w:contentPart r:id=\"rId9\"/></w:r></w:p>" +
        keeper,
        "p[1]",
        "relationship_reference",
      ),
    ] {
    let (body, at, slug) = probe
    let annotated = delete_fixture(body)
    let message = delete_refusal_of(annotated, at)
    assert_eq(
      @docx.docx_delete_refusal_slug(message),
      Some(slug),
      msg="'\{at}' -> " + message,
    )
    // The prose half is what a person reads, and it never carries the
    // machine prefix.
    assert_true(!@docx.docx_delete_refusal_prose(message).has_prefix("delete/"))
  }
}
