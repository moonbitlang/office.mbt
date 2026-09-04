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
  // …and an id another marker OUTSIDE the target also uses refuses,
  // because this deletion would take that marker's partner.
  assert_true(
    delete_refusal(
      "<w:p><w:bookmarkStart w:id=\"7\" w:name=\"Chapter1\"/><w:r><w:t>outside</w:t></w:r></w:p>" +
      "<w:p><w:bookmarkStart w:id=\"7\" w:name=\"_GoBack\"/><w:bookmarkEnd w:id=\"7\"/><w:r><w:t>x</w:t></w:r></w:p>" +
      keeper,
      "p[2]",
    ).contains("another marker outside it also uses"),
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
  assert_true(delete_refusal_of(commented, "p[1]").contains("a comment range"))
  let permitted = delete_fixture(
    "<w:permStart w:id=\"1\" w:edGrp=\"everyone\"/><w:p><w:r><w:t>target</w:t></w:r></w:p><w:permEnd w:id=\"1\"/>" +
    "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  assert_true(
    delete_refusal_of(permitted, "p[1]").contains("a range permission"),
  )
  // A range that CLOSES before the target does not bracket it.
  let closed = delete_fixture(
    "<w:commentRangeStart w:id=\"1\"/><w:p><w:r><w:t>other</w:t></w:r></w:p><w:commentRangeEnd w:id=\"1\"/>" +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p><w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  assert_eq(delete_refusal_of(closed, "p[2]"), "<planned>")
}

///|
/// The successor is judged on the SAME flattened surface the receipt
/// reports and the readback re-reads, so a wrapped following paragraph
/// is a successor — not a reason to call the target document-final.
test "a wrapped successor is still a successor" {
  let annotated = delete_fixture(
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:sdt><w:sdtContent><w:p><w:r><w:t>next</w:t></w:r></w:p></w:sdtContent></w:sdt>",
  )
  let (_, receipt) = @docx.plan_docx_paragraph_deletion(annotated, at="p[1]")
  assert_eq(receipt.text(), "target")
  assert_eq(receipt.successor_text(), Some("next"))
}

///|
/// Co-authoring conflict revisions live in the w14 namespace, which the
/// WML revision vocabulary does not reach — they are revision history
/// all the same.
test "deletion refuses w14 conflict revisions" {
  let keeper = "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>"
  for construct in ["conflictIns", "conflictDel"] {
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
