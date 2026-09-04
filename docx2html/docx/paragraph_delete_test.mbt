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
    ).contains("a bookmark range"),
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
  // A SPLIT field boundary refuses — its partner lies outside…
  assert_true(
    delete_refusal(
      "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r></w:p>" + keeper,
      "p[1]",
    ).contains("split field boundary"),
  )
  // …while a COMPLETE field leaves with its paragraph and dangles
  // nothing. Page numbers, DATE, REF and every TOC entry are this
  // shape, so refusing it made a large share of real Word paragraphs
  // undeletable.
  let complete_field = delete_fixture(
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r><w:r><w:instrText>PAGE</w:instrText></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"separate\"/></w:r><w:r><w:t>1</w:t></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>" +
    keeper,
  )
  assert_eq(delete_refusal_of(complete_field, "p[1]"), "<planned>")
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
  // "At least one paragraph remains" is STRUCTURAL, so it counts DIRECT
  // body paragraphs: a paragraph inside a content control may render
  // for nobody, and a body with none is the state this refuses.
  let wrapped_only = delete_fixture(
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:sdt><w:sdtContent><w:p><w:r><w:t>next</w:t></w:r></w:p></w:sdtContent></w:sdt>",
  )
  assert_true(
    delete_refusal_of(wrapped_only, "p[1]").contains(
      "final direct body paragraph",
    ),
  )
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
  // Tracked block moves and deletions wrap flow content without
  // contributing layout of their own — a table inside one is still the
  // table that would merge.
  for wrapper in ["del", "moveFrom", "moveTo", "ins"] {
    let wrapped = delete_fixture(
      table +
      "<w:p/><w:\{wrapper} w:id=\"1\" w:author=\"a\">" +
      table +
      "</w:\{wrapper}>" +
      keeper,
    )
    assert_true(
      delete_refusal_of(wrapped, "p[1]").contains("separates two tables"),
      msg="a table inside w:" + wrapper + " is still a table",
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
  // Asserted POSITIVELY: `!contains(...)` passes on any other outcome,
  // including the family collapse this case exists to catch.
  assert_eq(delete_refusal_of(mismatched, "p[1]"), "<planned>")
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
  // Word's caret anchors nothing, and a multi-paragraph edit leaves one
  // SPANNING paragraphs — so the exemption follows it outside the
  // target, not only inside.
  let caret = delete_fixture(
    "<w:bookmarkStart w:id=\"1\" w:name=\"_GoBack\"/><w:p><w:r><w:t>target</w:t></w:r></w:p><w:bookmarkEnd w:id=\"1\"/>" +
    keeper,
  )
  assert_eq(delete_refusal_of(caret, "p[1]"), "<planned>")
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
    delete_refusal_of(orphan_end, "p[1]").contains(
      "sits inside a bookmark range",
    ),
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
  // An unclosed start elsewhere in the story strands nothing when a
  // paragraph it does not cover is deleted: intervals judge each id on
  // its own, so the paragraphs outside every range plan…
  for path in ["p[1]", "p[2]"] {
    assert_eq(delete_refusal_of(orphan_start, path), "<planned>")
  }
  // …and only the one a real range covers refuses.
  assert_true(
    delete_refusal_of(orphan_start, "p[3]").contains(
      "sits inside a bookmark range",
    ),
  )
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
    delete_refusal_of(inverted, "p[1]").contains("sits inside a bookmark range"),
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
    delete_refusal_of(nested_inversion, "p[1]").contains(
      "sits inside a bookmark range",
    ),
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
  assert_true(delete_refusal_of(annotated, "p[2]").contains("cannot be read"))
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
  // An orphan `begin` with no later end that closes it opens no region
  // this deletion can truncate: Word tolerates the stray boundary, and
  // refusing every paragraph after it would name a field that does not
  // exist.
  assert_eq(delete_refusal_of(orphaned, "p[2]"), "<planned>")
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
/// The constructs the registry lists but no test reached — each now
/// exercised where it is dispatched, so the ledger's citation is true.
test "the remaining hazard vocabulary is exercised" {
  let keeper = "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>"
  // A data-bound content control anchors a customXml island.
  let bound = delete_fixture(
    "<w:p><w:sdt><w:sdtPr><w:dataBinding w:xpath=\"/root/customer\" w:storeItemID=\"{X}\"/></w:sdtPr>" +
    "<w:sdtContent><w:r><w:t>Acme</w:t></w:r></w:sdtContent></w:sdt></w:p>" +
    keeper,
  )
  assert_true(
    delete_refusal_of(bound, "p[1]").contains("content-control data binding"),
  )
  // `separate` divides instruction from result INSIDE a region and
  // changes no depth — the commonest fldChar spelling in real output,
  // and the arm whose misclassification would refuse or permit every
  // field in the document.
  let separated = delete_fixture(
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r><w:r><w:instrText>PAGE</w:instrText></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"separate\"/></w:r><w:r><w:t>1</w:t></w:r>" +
    "<w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>after</w:t></w:r></w:p>" +
    keeper,
  )
  // The paragraph AFTER a closed field is deletable: `separate` did not
  // leave the region open.
  assert_eq(delete_refusal_of(separated, "p[2]"), "<planned>")
  // Two spellings of one attribute in ONE namespace are a duplicate
  // attribute, which the strict XML gate refuses before this planner
  // ever sees the document. Across two WML DIALECTS they are different
  // names, no duplicate check fires anywhere, and the gates that care
  // read through `unique_attribute_value` — which is why a bookmark
  // whose name is spelled twice reads as unknown and refuses.
  let dialects = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:s=\"http://purl.oclc.org/ooxml/wordprocessingml/main\"><w:body>" +
    "<w:p><w:bookmarkStart w:id=\"1\" w:name=\"_GoBack\" s:name=\"Chapter\"/><w:bookmarkEnd w:id=\"1\"/><w:r><w:t>x</w:t></w:r></w:p>" +
    keeper +
    "<w:sectPr/></w:body></w:document>"
  let annotated = @docx.read_docx_annotated(fixture_docx(dialects))
  assert_true(
    delete_refusal_of(annotated, "p[1]").contains("could not be read"),
  )
}

///|
/// The arms of `open_range_across` that no fixture reached: SPLIT (a
/// range with markers on both sides of the target) and UNPLACEABLE (a
/// marker whose id cannot be read). Both are fail-open if deleted, and
/// both were previously invisible because every fixture resolved
/// through the spanning arm.
test "every range-hazard arm is reachable" {
  let keeper = "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>"
  // SPLIT is DEFENSIVE, not reachable: every id-bearing family placed
  // inside the target is refused earlier by the subtree walk — a named
  // bookmark as a blocked construct, comment and permission markers by
  // name, move and customXml ranges as revision content — and the one
  // exemption (`_GoBack`) is caught by the multiset when its partner
  // lies outside. The shape below therefore refuses for the EARLIER
  // reason, which this pins so a change in that order surfaces here
  // rather than silently making the arm load-bearing and untested.
  let split_shape = delete_fixture(
    "<w:p><w:bookmarkStart w:id=\"5\" w:name=\"Chapter\"/><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>mid</w:t></w:r></w:p><w:bookmarkEnd w:id=\"5\"/>" +
    keeper,
  )
  assert_true(
    delete_refusal_of(split_shape, "p[1]").contains("a named bookmark"),
  )
  let goback_split = delete_fixture(
    "<w:p><w:bookmarkStart w:id=\"6\" w:name=\"_GoBack\"/><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>mid</w:t></w:r></w:p><w:bookmarkEnd w:id=\"6\"/>" +
    keeper,
  )
  assert_true(
    delete_refusal_of(goback_split, "p[1]").contains("do not pair inside it"),
  )
  // UNPLACEABLE is judged TARGET-RELATIVE: markers this reader cannot
  // place matter only when an unplaceable pair could straddle the
  // target. One before it strands nothing…
  let one_sided = delete_fixture(
    "<w:commentRangeStart/><w:p><w:r><w:t>target</w:t></w:r></w:p>" + keeper,
  )
  assert_eq(delete_refusal_of(one_sided, "p[1]"), "<planned>")
  // …while one on each side could cover it, and cannot be judged.
  let straddling = delete_fixture(
    "<w:commentRangeStart/><w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:commentRangeEnd/>" +
    keeper,
  )
  assert_true(delete_refusal_of(straddling, "p[1]").contains("cannot be read"))
  // Two DISJOINT ranges that reuse one id are two intervals, not one
  // long one: nothing covers the paragraph between them.
  let reused_id = delete_fixture(
    "<w:bookmarkStart w:id=\"1\" w:name=\"A\"/><w:p><w:r><w:t>one</w:t></w:r></w:p><w:bookmarkEnd w:id=\"1\"/>" +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:bookmarkStart w:id=\"1\" w:name=\"B\"/><w:p><w:r><w:t>three</w:t></w:r></w:p><w:bookmarkEnd w:id=\"1\"/>" +
    keeper,
  )
  assert_eq(delete_refusal_of(reused_id, "p[2]"), "<planned>")
  // A `separate` BEFORE the target, with the region still open across
  // it: classified as anything but NotABoundary, this shape either
  // refuses every field or permits splicing out of a field's result.
  let separated_open = delete_fixture(
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r><w:r><w:fldChar w:fldCharType=\"separate\"/></w:r></w:p>" +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:p><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>" +
    keeper,
  )
  assert_true(
    delete_refusal_of(separated_open, "p[2]").contains(
      "sits inside a field region",
    ),
  )
  // Permission ids are ST_String, so `1` and `01` are DIFFERENT
  // permissions and neither covers the paragraph between them.
  let permissions = delete_fixture(
    "<w:p><w:permStart w:id=\"1\" w:edGrp=\"everyone\"/><w:r><w:t>a</w:t></w:r><w:permEnd w:id=\"1\"/></w:p>" +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:p><w:permStart w:id=\"01\" w:edGrp=\"everyone\"/><w:r><w:t>c</w:t></w:r><w:permEnd w:id=\"01\"/></w:p>" +
    keeper,
  )
  assert_eq(delete_refusal_of(permissions, "p[2]"), "<planned>")
}

///|
/// The three bypasses round 10 confirmed end to end, each pinned by the
/// shape that produced it.
test "the structural gates are not bypassable by wrapping or overlap" {
  let table = "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>cell</w:t></w:r></w:p></w:tc></w:tr></w:tbl>"
  let keeper = "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>"
  // A body whose ONLY direct paragraph is the target, followed by a
  // table: deleting it leaves a body with no paragraph at all.
  let no_paragraph_left = delete_fixture(
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" + table,
  )
  assert_true(
    delete_refusal_of(no_paragraph_left, "p[1]").contains(
      "final direct body paragraph",
    ),
  )
  // The two BRANCHES of one AlternateContent are alternatives, not
  // neighbours: a consumer showing the Fallback sees the tables meet.
  let alternate = delete_fixture(
    table +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"><mc:Choice Requires=\"wps\"><w:p><w:r><w:t>alt</w:t></w:r></w:p></mc:Choice><mc:Fallback>" +
    table +
    "</mc:Fallback></mc:AlternateContent>" +
    keeper,
  )
  assert_true(
    delete_refusal_of(alternate, "p[1]").contains("separates two tables"),
  )
  // Overlapping bookmarks are what Word EMITS around cross-referenced
  // headings; they must not make the verb unusable.
  let overlapping = delete_fixture(
    "<w:p><w:bookmarkStart w:id=\"1\" w:name=\"_Toc1\"/><w:bookmarkStart w:id=\"2\" w:name=\"_Ref1\"/>" +
    "<w:r><w:t>heading</w:t></w:r><w:bookmarkEnd w:id=\"1\"/><w:bookmarkEnd w:id=\"2\"/></w:p>" +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    keeper,
  )
  assert_eq(delete_refusal_of(overlapping, "p[2]"), "<planned>")
  // A field boundary with no type at all is one this reader cannot
  // place — schema-required, so its absence is not a shrug.
  let typeless = delete_fixture(
    "<w:p><w:r><w:fldChar/></w:r></w:p>" +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:p><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></w:p>" +
    keeper,
  )
  assert_true(delete_refusal_of(typeless, "p[2]").contains("cannot be read"))
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
      (keeper + keeper, "p[0]", "target_grammar"),
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
