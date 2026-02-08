///|
test "merge cell wb: get_end_axis falls back to start when no colon is present" {
  let merge = MergeCell::new("A1", "")
  inspect(merge.get_end_axis(), content="A1")
}

///|
test "merge cell wb: rect_union covers min/max branch matrix" {
  inspect(rect_union((5, 5, 10, 10), (3, 4, 8, 9)), content="(3, 4, 10, 10)")
}

///|
test "merge cell wb: merge_overlap_ranges handles used-j continue path" {
  let merged = merge_overlap_ranges(["A1:B2", "D1:E2", "B2:C3"]) catch {
    err => fail("merge_overlap_ranges failed: \{err}")
  }
  inspect(merged.length(), content="2")
  inspect(merged.contains("A1:C3"), content="true")
  inspect(merged.contains("D1:E2"), content="true")
}
