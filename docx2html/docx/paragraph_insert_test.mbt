// Blackbox witnesses for the N3a insertion planner: minting is valid
// and fresh, fragments are namespace-self-contained and land where
// addressed, and every v1 refusal is typed.

///|
test "mint_para_id is valid, fresh, and case-insensitively conservative" {
  // R3's rule: assert VALIDITY and FRESHNESS, never the allocator's
  // sequence.
  let minted = @docx.mint_para_id([])
  assert_eq(@docx.validated_para_id(minted), Some(minted))
  let occupied = ["00000001", "0000000a", "junk"]
  let next = @docx.mint_para_id(occupied)
  assert_eq(@docx.validated_para_id(next), Some(next))
  // Fresh against every occupant, case-insensitively (the lowercase
  // occupant blocks its canonical form too).
  for value in occupied {
    assert_true(next != value)
    match @docx.validated_para_id(value) {
      Some(canonical) => assert_true(next != canonical)
      None => ()
    }
  }
}

///|
/// The full round trip at the engine level: plan an insertion after a
/// stamped paragraph, splice, re-read — the new paragraph carries the
/// minted id with a UNIQUE anchor, sits at the planned path, and the
/// neighbours are untouched.
test "insertion plans splice and read back with the minted identity" {
  let annotated = identity_fixture(
    "<w:p w14:paraId=\"00000001\"><w:r><w:t>first</w:t></w:r></w:p><w:p w14:paraId=\"00000002\"><w:r><w:t>second</w:t></w:r></w:p>",
  )
  let (plan, receipt) = @docx.plan_docx_paragraph_insertion(
    annotated,
    at="p[1]",
    before=false,
    content={
      style: None,
      runs: [{ text: "inserted", bold: true, italic: false, underline: false, }],
    },
    used_para_ids=["00000001", "00000002"],
  )
  // Validity and freshness, never the allocator sequence.
  assert_eq(@docx.validated_para_id(receipt.para_id()), Some(receipt.para_id()))
  assert_true(
    receipt.para_id() != "00000001" && receipt.para_id() != "00000002",
  )
  assert_eq(receipt.planned_path(), "p[2]")
  let source = fixture_docx(
    "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\" xmlns:w14=\"http://schemas.microsoft.com/office/word/2010/wordml\"><w:body><w:p w14:paraId=\"00000001\"><w:r><w:t>first</w:t></w:r></w:p><w:p w14:paraId=\"00000002\"><w:r><w:t>second</w:t></w:r></w:p><w:sectPr/></w:body></w:document>",
  )
  let spliced = @splice.splice_docx(source, plan)
  let reread = @docx.read_docx_annotated(spliced)
  let text = reread.result().document.to_raw_text()
  assert_true(text.contains("inserted"))
  let index = @docx.docx_paragraph_anchor_index(
    reread,
    reread.main_story_source(),
  )
  guard index.anchor_at("p[2]") is Some(anchor) else {
    fail("expected the inserted paragraph's anchor")
  }
  assert_eq(anchor.status(), "unique")
  assert_eq(anchor.para_id(), Some(receipt.para_id()))
  // Neighbours keep their identities and order.
  guard index.anchor_at("p[1]") is Some(first) else { fail("p[1]") }
  assert_eq(first.para_id(), Some("00000001"))
  guard index.anchor_at("p[3]") is Some(third) else { fail("p[3]") }
  assert_eq(third.para_id(), Some("00000002"))
}

///|
/// Every v1 refusal is typed: nested anchors, empty payloads, control
/// characters, and undefined style references.
test "insertion refuses the v1 boundaries" {
  let annotated = identity_fixture(
    "<w:p w14:paraId=\"00000001\"><w:r><w:t>only</w:t></w:r></w:p>",
  )
  fn refuse(at : String, content : @docx.DocxInsertContent) -> String raise {
    let mut message = ""
    try
      ignore(
        @docx.plan_docx_paragraph_insertion(
          annotated,
          at~,
          before=true,
          content~,
          used_para_ids=[],
        ),
      )
    catch {
      error => message = repr(error)
    } noraise {
      _ => fail("expected a refusal")
    }
    message
  }
  let plain = @docx.DocxInsertContent::{
    style: None,
    runs: [{ text: "x", bold: false, italic: false, underline: false, }],
  }
  assert_true(refuse("tbl[1]/tr[1]/tc[1]/p[1]", plain).contains("direct body"))
  assert_true(refuse("p[9]", plain).contains("does not resolve"))
  assert_true(
    refuse("p[1]", { style: None, runs: [], }).contains("at least one run"),
  )
  assert_true(
    refuse("p[1]", {
      style: None,
      runs: [{ text: "a\tb", bold: false, italic: false, underline: false, }],
    }).contains("control characters"),
  )
  assert_true(
    refuse("p[1]", {
      style: Some("NoSuchStyle"),
      runs: [{ text: "x", bold: false, italic: false, underline: false, }],
    }).contains("styles part does not define"),
  )
}

///|
/// Round 1's High, pinned: the flattened path grammar lets a paragraph
/// INSIDE a block content control answer to "p[1]" — but it is not a
/// physical child of w:body, and an insertion beside it would land
/// inside the wrapper. The anchor proof is on the element tree.
test "insertion refuses an anchor wrapped by a content control" {
  let annotated = identity_fixture(
    "<w:sdt><w:sdtContent><w:p w14:paraId=\"00000001\"><w:r><w:t>wrapped</w:t></w:r></w:p></w:sdtContent></w:sdt>",
  )
  let mut message = ""
  try
    ignore(
      @docx.plan_docx_paragraph_insertion(
        annotated,
        at="p[1]",
        before=false,
        content={
          style: None,
          runs: [{ text: "x", bold: false, italic: false, underline: false, }],
        },
        used_para_ids=[],
      ),
    )
  catch {
    error => message = repr(error)
  } noraise {
    _ => fail("expected the wrapped-anchor refusal")
  }
  assert_true(
    message.contains("not a DIRECT child"),
    msg="got '" + message + "'",
  )
}
