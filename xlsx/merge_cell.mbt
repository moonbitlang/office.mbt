///|
pub struct MergeCell {
  range_ref : String
  value : String
} derive(Debug)

///|
fn MergeCell::new(range_ref : String, value : String) -> MergeCell {
  { range_ref, value }
}

///|
pub fn MergeCell::get_cell_value(self : MergeCell) -> String {
  self.value
}

///|
pub fn MergeCell::get_start_axis(self : MergeCell) -> String {
  match self.range_ref.split_once(":") {
    Some((start, _)) => start.to_owned()
    None => self.range_ref
  }
}

///|
pub fn MergeCell::get_end_axis(self : MergeCell) -> String {
  match self.range_ref.split_once(":") {
    Some((_, end)) => end.to_owned()
    None => self.range_ref
  }
}

///|
fn rects_overlap(a : (Int, Int, Int, Int), b : (Int, Int, Int, Int)) -> Bool {
  let (a_min_row, a_min_col, a_max_row, a_max_col) = a
  let (b_min_row, b_min_col, b_max_row, b_max_col) = b
  !(a_max_row < b_min_row ||
  a_min_row > b_max_row ||
  a_max_col < b_min_col ||
  a_min_col > b_max_col)
}

///|
fn rect_union(
  a : (Int, Int, Int, Int),
  b : (Int, Int, Int, Int),
) -> (Int, Int, Int, Int) {
  let (a_min_row, a_min_col, a_max_row, a_max_col) = a
  let (b_min_row, b_min_col, b_max_row, b_max_col) = b
  (
    if a_min_row < b_min_row {
      a_min_row
    } else {
      b_min_row
    },
    if a_min_col < b_min_col {
      a_min_col
    } else {
      b_min_col
    },
    if a_max_row > b_max_row {
      a_max_row
    } else {
      b_max_row
    },
    if a_max_col > b_max_col {
      a_max_col
    } else {
      b_max_col
    },
  )
}

///|
fn rect_to_range(rect : (Int, Int, Int, Int)) -> String raise XlsxError {
  let (min_row, min_col, max_row, max_col) = rect
  let start_ref = cell_ref_from(min_row, min_col)
  let end_ref = cell_ref_from(max_row, max_col)
  "\{start_ref}:\{end_ref}"
}

///|
fn merge_overlap_ranges(
  ranges : ArrayView[String],
) -> Array[String] raise XlsxError {
  let rects : Array[(Int, Int, Int, Int)] = []
  for range_ref in ranges {
    rects.push(parse_range_ref(range_ref))
  }
  let mut rect_list = rects
  let mut merged = true
  while merged {
    merged = false
    let used : Array[Bool] = Array::make(rect_list.length(), false)
    let merged_rects : Array[(Int, Int, Int, Int)] = []
    for i in 0..<rect_list.length() {
      if used[i] {
        continue
      }
      let mut current = rect_list[i]
      for j in (i + 1)..<rect_list.length() {
        if used[j] {
          continue
        }
        let candidate = rect_list[j]
        if rects_overlap(current, candidate) {
          current = rect_union(current, candidate)
          used[j] = true
          merged = true
        }
      }
      merged_rects.push(current)
    }
    rect_list = merged_rects
  }
  let merged_ranges : Array[String] = []
  for rect in rect_list {
    merged_ranges.push(rect_to_range(rect))
  }
  merged_ranges
}

///|
test "merge cell wb: get_end_axis falls back to start when no colon is present" {
  let merge = MergeCell::new("A1", "")
  inspect(merge.get_end_axis(), content="A1")
}

///|
test "merge cell wb: rect_union covers min/max branch matrix" {
  debug_inspect(
    rect_union((5, 5, 10, 10), (3, 4, 8, 9)),
    content="(3, 4, 10, 10)",
  )
}

///|
test "merge cell wb: merge_overlap_ranges handles used-j continue path" {
  let merged = merge_overlap_ranges(["A1:B2", "D1:E2", "B2:C3"]) catch {
    err => fail("merge_overlap_ranges failed: \{repr(err)}")
  }
  inspect(merged.length(), content="2")
  inspect(merged.contains("A1:C3"), content="true")
  inspect(merged.contains("D1:E2"), content="true")
}
