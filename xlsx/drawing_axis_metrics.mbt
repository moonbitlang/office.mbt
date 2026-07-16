///|
priv struct DrawingAxisMetrics {
  axis : String
  limit : Int
  default_px : Int
  override_indices : Array[Int]
  prefix_deltas : Array[Int64]
}

///|
priv struct DrawingMetrics {
  cols : DrawingAxisMetrics
  rows : DrawingAxisMetrics
}

///|
fn drawing_axis_metrics_for_sheet(
  sheet : Worksheet,
  axis : StringView,
) -> DrawingAxisMetrics raise XlsxError {
  let (limit, default_px) = if axis == "col" {
    (cell_ref_max_cols, sheet.default_col_width_pixels())
  } else if axis == "row" {
    (cell_ref_max_rows, sheet.default_row_height_pixels())
  } else {
    raise InvalidXml(msg="drawing axis invalid")
  }
  if default_px < 0 {
    raise InvalidXml(msg="drawing cell dimension invalid")
  }
  let overrides : Array[(Int, Int)] = []
  if axis == "col" {
    for idx1, _ in sheet.col_dimensions {
      if idx1 <= 0 || idx1 > limit {
        raise InvalidXml(msg="drawing cell dimension invalid")
      }
      let actual_px = sheet.col_width_pixels(idx1)
      if actual_px < 0 {
        raise InvalidXml(msg="drawing cell dimension invalid")
      }
      overrides.push((idx1 - 1, actual_px - default_px))
    }
  } else {
    for idx1, _ in sheet.row_dimensions {
      if idx1 <= 0 || idx1 > limit {
        raise InvalidXml(msg="drawing cell dimension invalid")
      }
      let actual_px = sheet.row_height_pixels(idx1)
      if actual_px < 0 {
        raise InvalidXml(msg="drawing cell dimension invalid")
      }
      overrides.push((idx1 - 1, actual_px - default_px))
    }
  }
  overrides.sort_by((left, right) => {
    let (left_index, _) = left
    let (right_index, _) = right
    if left_index < right_index {
      -1
    } else if left_index > right_index {
      1
    } else {
      0
    }
  })
  let override_indices : Array[Int] = []
  let prefix_deltas : Array[Int64] = [0L]
  let mut delta_sum = 0L
  for entry in overrides {
    let (index, delta) = entry
    override_indices.push(index)
    delta_sum = delta_sum + Int64::from_int(delta)
    prefix_deltas.push(delta_sum)
  }
  { axis: axis.to_owned(), limit, default_px, override_indices, prefix_deltas }
}

///|
fn drawing_metrics_for_sheet(
  sheet : Worksheet,
) -> DrawingMetrics raise XlsxError {
  {
    cols: drawing_axis_metrics_for_sheet(sheet, "col"),
    rows: drawing_axis_metrics_for_sheet(sheet, "row"),
  }
}

///|
fn DrawingAxisMetrics::delta_before(
  self : DrawingAxisMetrics,
  idx0 : Int,
) -> Int64 {
  let mut low = 0
  let mut high = self.override_indices.length()
  while low < high {
    let mid = low + (high - low) / 2
    if self.override_indices[mid] < idx0 {
      low = mid + 1
    } else {
      high = mid
    }
  }
  self.prefix_deltas[low]
}

///|
fn DrawingAxisMetrics::pixel_span(
  self : DrawingAxisMetrics,
  start_idx0 : Int,
  end_idx0 : Int,
) -> Int64 raise XlsxError {
  if start_idx0 < 0 || end_idx0 < start_idx0 || end_idx0 > self.limit {
    raise InvalidXml(msg="drawing " + self.axis + " invalid")
  }
  let count = end_idx0 - start_idx0
  let base = Int64::from_int(self.default_px) * Int64::from_int(count)
  let delta = self.delta_before(end_idx0) - self.delta_before(start_idx0)
  let total = base + delta
  if total < 0L {
    raise InvalidXml(msg="drawing span invalid")
  }
  total
}

///|
test "drawing metrics wb: sparse overrides use logarithmic range sums" {
  let sheet = Worksheet::new("Sheet1")
  sheet.set_col_width(501, 10.0)
  let metrics = drawing_metrics_for_sheet(sheet)
  inspect(metrics.cols.pixel_span(0, 1000), content="64016")
  inspect(metrics.cols.pixel_span(500, 501), content="80")
}
