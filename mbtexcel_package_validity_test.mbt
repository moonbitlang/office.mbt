///|
/// Runs every complex demo workbook through the in-MoonBit OOXML package
/// validator (content-type coverage, relationship-target integrity,
/// required parts, no duplicate/malformed part names). These demos
/// exercise charts, pivot tables, slicers, sparklines, form controls,
/// hyperlinks, images, and streaming, so a single structural regression
/// in any of those surfaces here.
test "demo workbooks are structurally valid OOXML packages" {
  let cases : Array[(String, Bytes)] = [
    ("dashboard", @demos.demo_dashboard_bytes()),
    ("invoice", @demos.demo_invoice_bytes()),
    ("pivot_slicer", @demos.demo_pivot_slicer_bytes()),
    ("sparklines", @demos.demo_sparklines_bytes()),
    ("tracker_heatmap", @demos.demo_tracker_heatmap_bytes()),
    ("interactive_controls", @demos.demo_interactive_controls_bytes()),
    ("combo_chart", @demos.demo_combo_chart_bytes()),
    ("ooxml_showcase", @demos.demo_ooxml_showcase_bytes()),
    ("stream_big", @demos.demo_stream_big_bytes(rows=200)),
  ]
  for entry in cases {
    let (name, bytes) = entry
    let problems = @xlsx.validate_ooxml_package(bytes)
    if problems.length() != 0 {
      fail("demo \{name} is not a valid package: \{repr(problems)}")
    }
  }
}

///|
/// A password-encrypted workbook is an OLE compound file, not a plain
/// OOXML zip, so the plain validator should report it as unreadable
/// rather than silently passing.
test "encrypted demo is not a plain OOXML zip" {
  let bytes = @demos.demo_secure_bytes(password="p@ss")
  let problems = @xlsx.validate_ooxml_package(bytes)
  guard problems.length() > 0 else {
    fail("expected encrypted package to be flagged as non-zip")
  }
}
