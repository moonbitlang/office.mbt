///|
/// Accepting a deletion or move, or rejecting an insertion, can remove
/// a boundary that appears to close before the target in the XML.
test "revision-dependent boundaries cannot close regions before deletion" {
  for revision in ["ins", "del", "moveFrom", "moveTo"] {
    for
      (start, end) in [
        (
          "<w:r><w:fldChar w:fldCharType=\"begin\"/></w:r>", "<w:r><w:fldChar w:fldCharType=\"end\"/></w:r>",
        ),
        (
          "<w:bookmarkStart w:id=\"4\" w:name=\"Chapter\"/>", "<w:bookmarkEnd w:id=\"4\"/>",
        ),
      ] {
      let annotated = delete_fixture(
        "<w:p>" +
        start +
        "<w:\{revision} w:id=\"1\" w:author=\"a\">" +
        end +
        "</w:\{revision}></w:p>" +
        "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
        "<w:p>" +
        end +
        "<w:r><w:t>keeper</w:t></w:r></w:p>",
      )
      let error = @test.expect_error(() => {
        @docx.plan_docx_paragraph_deletion(annotated, at="p[2]")
      })
      assert_true(error is Unsupported(_))
    }
  }
}

///|
test "foreign revision names do not make field boundaries conditional" {
  let annotated = delete_fixture(
    "<w:p><w:r><w:fldChar w:fldCharType=\"begin\"/></w:r>" +
    "<x:moveFrom xmlns:x=\"urn:example\"><w:r><w:fldChar w:fldCharType=\"end\"/></w:r></x:moveFrom></w:p>" +
    "<w:p><w:r><w:t>target</w:t></w:r></w:p>" +
    "<w:p><w:r><w:t>keeper</w:t></w:r></w:p>",
  )
  let (_, receipt) = @docx.plan_docx_paragraph_deletion(annotated, at="p[2]")
  @test.assert_eq(receipt.text(), "target")
}
