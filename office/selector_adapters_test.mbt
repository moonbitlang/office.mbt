///|
test "all emitted DOCX projection path shapes adapt to canonical selectors" {
  let cases = [
    ("/body", "/docx/body"),
    ("/body/p[1]/r[2]", "/docx/body/p[1]/r[2]"),
    (
      "/body/tbl[1]/tr[2]/tc[1]/p[1]/image[1]", "/docx/body/tbl[1]/tr[2]/tc[1]/p[1]/image[1]",
    ),
    ("/header[1]/p[1]", "/docx/header[1]/p[1]"),
    ("/footer[2]/p[1]/r[1]", "/docx/footer[2]/p[1]/r[1]"),
    ("/footnotes/note[@id=2]/p[2]", "/docx/footnotes/note[id=\"2\"]/p[2]"),
    ("/endnotes/note[@id=end-7]/p[1]", "/docx/endnotes/note[id=\"end-7\"]/p[1]"),
    ("/comments/comment[@id=0]/p[1]", "/docx/comments/comment[id=\"0\"]/p[1]"),
    ("/body/p[2]/hyperlink[1]/r[1]", "/docx/body/p[2]/hyperlink[1]/r[1]"),
  ]
  for case in cases {
    let (legacy, expected) = case
    let selector = @office.selector_from_docx_projection_path(legacy)
    assert_eq(selector.render(), expected)
  }
}

///|
test "DOCX projection adapter preserves stability semantics" {
  let positional = @office.selector_from_docx_projection_path("/body/p[1]")
  assert_true(positional.stability is SnapshotRelative)
  let annotation = @office.selector_from_docx_projection_path(
    "/comments/comment[@id=7]",
  )
  assert_true(annotation.stability is Stable)
}

///|
test "DOCX projection adapter bounds legacy diagnostics" {
  try @office.selector_from_docx_projection_path("/body/unknown[1]") catch {
    SelectorError(code~, offset~, input~, message~) => {
      assert_eq(code, "office.selector.legacy_docx")
      assert_eq(offset, 0)
      assert_eq(input, "/body/unknown[1]")
      assert_true(message.contains("unknown kind"))
    }
  } noraise {
    _ => fail("expected invalid legacy path")
  }
  let oversized = "/body/" + "p".repeat(@office.SELECTOR_MAX_LENGTH)
  try @office.selector_from_docx_projection_path(oversized) catch {
    SelectorError(code~, input~, message~, ..) => {
      assert_eq(code, "office.selector.too_long")
      assert_true(input.to_array().length() <= 161)
      assert_true(message.to_array().length() <= 320)
    }
  } noraise {
    _ => fail("expected oversized legacy path")
  }
}

///|
test "XLSX adapters quote sheet names and normalize coordinates" {
  let cell = @office.selector_for_xlsx_cell("财务 / \"Q1\"", "xfd1048576")
  assert_eq(
    cell.render(),
    "/xlsx/sheet[name=\"财务 / \\\"Q1\\\"\"]/cell[XFD1048576]",
  )
  let range = @office.selector_for_xlsx_range("O'Brien", "C12:A1")
  assert_eq(range.render(), "/xlsx/sheet[name=\"O'Brien\"]/range[A1:C12]")
}

///|
test "XLSX adapters reject oversized raw arguments before rendering" {
  let oversized_name = "x".repeat(@office.SELECTOR_MAX_VALUE_LENGTH + 1)
  let oversized_reference = "A".repeat(22)
  for
    run in [
      () => @office.selector_for_xlsx_cell(oversized_name, "A1"),
      () => @office.selector_for_xlsx_range("Data", oversized_reference),
    ] {
    try run() catch {
      SelectorError(code~, offset~, input~, message~) => {
        assert_eq(code, "office.selector.adapter_input_too_long")
        assert_true(offset <= @office.SELECTOR_MAX_VALUE_LENGTH)
        assert_true(input.to_array().length() <= 161)
        assert_true(message.to_array().length() < 80)
      }
    } noraise {
      _ => fail("expected oversized XLSX adapter input")
    }
  }
}
