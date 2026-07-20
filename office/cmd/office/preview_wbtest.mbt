///|
/// A valid 1x1 PNG so the DOCX writer can read real image dimensions.
let preview_probe_png : Bytes = [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48,
  0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00,
  0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78,
  0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]

///|
test "preview generated help exposes publication flags" {
  let help = preview_command().render_help()
  assert_true(help.contains("<file>"))
  assert_true(help.contains("--output"))
  assert_true(help.contains("--overwrite"))
  assert_true(help.contains("--json"))
  assert_true(help.contains("--jsonl"))
}

///|
test "occurrence counting is non-overlapping and complete" {
  assert_eq(office_preview_count_occurrences("aaaa", "aa"), 2)
  assert_eq(office_preview_count_occurrences("abcabcab", "abc"), 2)
  assert_eq(office_preview_count_occurrences("abc", ""), 0)
  assert_eq(office_preview_count_occurrences("", "a"), 0)
}

///|
async test "xlsx preview renders charts inline and reports truthful stats" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-preview-xlsx-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let workbook = @xlsx.Workbook::new()
    ignore(workbook.add_sheet("Data"))
    workbook.set_cell("Data", "A1", "Region")
    workbook.set_cell("Data", "B1", "Sales")
    workbook.set_cell("Data", "A2", "East")
    workbook.set_cell_int("Data", "B2", 30)
    workbook.set_cell("Data", "A3", "West")
    workbook.set_cell_int("Data", "B3", 70)
    let chart = @xlsx.ChartOptions::new(Col)
    chart.series.push(
      @xlsx.ChartSeries::new(
        "Data!$A$2:$A$3",
        "Data!$B$2:$B$3",
        name="Data!$B$1",
      ),
    )
    workbook.add_chart_with_options("Data", "D2", chart)
    let path = write_probe_package(
      directory,
      "charted.xlsx",
      @xlsx.write(workbook),
    )
    let source = read_office_package(path)
    let (html, stats) = office_preview_render_xlsx(source)
    assert_true(html.contains("<figure class=\"chart\""))
    assert_true(html.contains("<title>barChart</title>"))
    assert_true(html.contains(">Sales</text>"))
    assert_eq(stats.charts_rendered, 1)
    assert_eq(stats.charts_placeholder, 0)
    assert_true(stats.truncated_sheets is [])
    let report = office_preview_report(source, "out.html", html.length(), stats)
    let rendered = report.stringify()
    assert_true(rendered.contains("\"schema\":\"office.preview/1\""))
    assert_true(rendered.contains("\"charts_rendered\":1"))
    assert_true(rendered.contains("\"truncated_sheets\":[]"))
    assert_false(rendered.contains("\"warnings\""))
  }
}

///|
async test "xlsx preview names sheets exceeding the render window as truncated" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-preview-trunc-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let workbook = @xlsx.Workbook::new()
    ignore(workbook.add_sheet("Wide"))
    ignore(workbook.add_sheet("Small"))
    workbook.set_cell("Wide", "A1500", "far")
    workbook.set_cell("Small", "A1", "near")
    let path = write_probe_package(
      directory,
      "trunc.xlsx",
      @xlsx.write(workbook),
    )
    let source = read_office_package(path)
    let (html, stats) = office_preview_render_xlsx(source)
    assert_true(html.contains("showing 1000 of 1500 rows"))
    assert_true(stats.truncated_sheets is ["Wide"])
  }
}

///|
/// A merge extending past the last stored cell widens the rendered sheet;
/// the report's truncation verdict must follow the page, not just the
/// stored-cell bounds.
async test "merge-extended sheets count as truncated like the page says" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-preview-merge-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let workbook = @xlsx.Workbook::new()
    ignore(workbook.add_sheet("Merged"))
    workbook.set_cell("Merged", "A1", "anchor")
    workbook.merge_cells("Merged", "A1:A1500")
    let path = write_probe_package(
      directory,
      "merged.xlsx",
      @xlsx.write(workbook),
    )
    let source = read_office_package(path)
    let (html, stats) = office_preview_render_xlsx(source)
    assert_true(html.contains("showing 1000 of 1500 rows"))
    assert_true(stats.truncated_sheets is ["Merged"])
  }
}

///|
async test "docx preview embeds bounded images and escapes hostile text" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-preview-docx-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    let bytes = @word.write_docx([
      @word.paragraph([@word.run([@word.text("<script>alert(1)</script>")])]),
      @word.paragraph([
        @word.run([
          @word.image("image/png", preview_probe_png, alt_text=Some("dot")),
        ]),
      ]),
    ])
    let path = write_probe_package(directory, "note.docx", bytes)
    let source = read_office_package(path)
    let (html, stats) = office_preview_render_docx(source)
    assert_true(html.contains("<!DOCTYPE html>"))
    assert_true(html.contains("<title>" + path + "</title>"))
    assert_true(html.contains("data:image/png;base64,"))
    assert_true(html.contains("alt=\"dot\""))
    assert_false(html.contains("<script>"))
    assert_true(html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
    assert_eq(stats.images_embedded, 1)
    assert_eq(stats.images_omitted, 0)
    assert_true(stats.warnings is [])
  }
}

///|
async test "docx preview omits images beyond the per-image allowance" {
  @async.with_task_group() <| group => {
    let directory = @afs.tmpdir(prefix="office-preview-big-")
    group.add_defer() <| () => {
      @async.protect_from_cancel(() => @afs.rmdir(directory, recursive=true))
    }
    // a real PNG header followed by padding: dimensions parse, but the
    // payload exceeds the per-image preview allowance
    let padded : Array[Byte] = []
    for byte in preview_probe_png {
      padded.push(byte)
    }
    for _ in 0..<office_preview_max_image_bytes {
      padded.push(0)
    }
    let bytes = @word.write_docx([
      @word.paragraph([
        @word.run([@word.image("image/png", Bytes::from_array(padded))]),
      ]),
    ])
    let path = write_probe_package(directory, "big.docx", bytes)
    let source = read_office_package(path)
    let (html, stats) = office_preview_render_docx(source)
    assert_false(html.contains("data:image/png"))
    assert_eq(stats.images_embedded, 0)
    assert_eq(stats.images_omitted, 1)
    assert_true(
      stats.warnings
      .iter()
      .any(warning => {
        warning.contains("preview image omitted by the bounded asset allowance")
      }),
    )
    let report = office_preview_report(source, "out.html", html.length(), stats)
    assert_true(report.stringify().contains("\"images_omitted\":1"))
  }
}
