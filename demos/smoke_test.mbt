///|
test "demos: build demo bytes (smoke)" {
  inspect(demo_dashboard_bytes().length() > 0, content="true")
  inspect(demo_invoice_bytes().length() > 0, content="true")
  inspect(demo_pivot_slicer_bytes().length() > 0, content="true")
  inspect(demo_sparklines_bytes().length() > 0, content="true")
  inspect(demo_tracker_heatmap_bytes().length() > 0, content="true")
  inspect(demo_interactive_controls_bytes().length() > 0, content="true")
  inspect(demo_combo_chart_bytes().length() > 0, content="true")
  inspect(demo_ooxml_showcase_bytes().length() > 0, content="true")
  // keep this small for tests; stream demo is meant for large sheets at runtime
  inspect(demo_stream_big_bytes(rows=100).length() > 0, content="true")
  inspect(demo_secure_bytes().length() > 0, content="true")
}
