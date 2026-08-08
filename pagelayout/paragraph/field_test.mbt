///|
test "field instructions are classified by their keyword" {
  debug_inspect(@paragraph.field_kind(" PAGE "), content="PageNumber")
  debug_inspect(@paragraph.field_kind(" NUMPAGES "), content="PageCount")
  // switches after the keyword are formatting directives, not the field
  debug_inspect(
    @paragraph.field_kind(" PAGE \\* MERGEFORMAT "),
    content="PageNumber",
  )
  debug_inspect(@paragraph.field_kind("page"), content="PageNumber")
  // fields this engine cannot compute keep their cached result
  debug_inspect(@paragraph.field_kind(" REF _Ref12345 "), content="NotAField")
  debug_inspect(@paragraph.field_kind(" TOC \\o "), content="NotAField")
  debug_inspect(@paragraph.field_kind(""), content="NotAField")
}

///|
test "evaluating substitutes the real page number" {
  let style = @paragraph.RunStyle::{
    family: "Calibri",
    size_pt: 12,
    bold: false,
    italic: false,
    color: @pagelayout.black,
  }
  // "37" is the value Word cached when the document was last saved
  let page = @paragraph.RunInput::{ text: "37", style, field: PageNumber }
  let count = @paragraph.RunInput::{ text: "37", style, field: PageCount }
  let plain = @paragraph.RunInput::{ text: "37", style, field: NotAField }
  inspect(page.evaluate(5, 56).text, content="5")
  inspect(count.evaluate(5, 56).text, content="56")
  // ordinary text that happens to look like a number is untouched
  inspect(plain.evaluate(5, 56).text, content="37")
}

///|
test "a paragraph reports whether it holds fields" {
  let style = @paragraph.RunStyle::{
    family: "Calibri",
    size_pt: 12,
    bold: false,
    italic: false,
    color: @pagelayout.black,
  }
  let plain = @paragraph.ParagraphInput::{
    runs: [{ text: "x", style, field: NotAField }],
    style: @paragraph.ParagraphStyle::default(),
  }
  let with_field = @paragraph.ParagraphInput::{
    runs: [
      { text: "Page ", style, field: NotAField },
      { text: "1", style, field: PageNumber },
    ],
    style: @paragraph.ParagraphStyle::default(),
  }
  assert_false(plain.has_fields())
  assert_true(with_field.has_fields())
}
