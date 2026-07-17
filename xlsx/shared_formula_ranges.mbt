///|
priv struct SharedFormulaRangeEvent {
  row : Int
  column_lo : Int
  column_hi : Int
  delta : Int
}

///|
fn shared_formula_range_tree_push(
  maximums : Array[Int],
  pending_additions : Array[Int],
  node : Int,
) -> Unit {
  let pending = pending_additions[node]
  if pending == 0 {
    return
  }
  let left = node * 2
  let right = left + 1
  maximums[left] += pending
  maximums[right] += pending
  pending_additions[left] += pending
  pending_additions[right] += pending
  pending_additions[node] = 0
}

///|
fn shared_formula_range_tree_add(
  maximums : Array[Int],
  pending_additions : Array[Int],
  node : Int,
  lo : Int,
  hi : Int,
  query_lo : Int,
  query_hi : Int,
  delta : Int,
) -> Unit {
  if query_lo <= lo && hi <= query_hi {
    maximums[node] += delta
    pending_additions[node] += delta
    return
  }
  shared_formula_range_tree_push(maximums, pending_additions, node)
  let middle = lo + (hi - lo) / 2
  if query_lo <= middle {
    shared_formula_range_tree_add(
      maximums,
      pending_additions,
      node * 2,
      lo,
      middle,
      query_lo,
      query_hi,
      delta,
    )
  }
  if query_hi > middle {
    shared_formula_range_tree_add(
      maximums,
      pending_additions,
      node * 2 + 1,
      middle + 1,
      hi,
      query_lo,
      query_hi,
      delta,
    )
  }
  let left_maximum = maximums[node * 2]
  let right_maximum = maximums[node * 2 + 1]
  maximums[node] = if left_maximum > right_maximum {
    left_maximum
  } else {
    right_maximum
  }
}

///|
fn shared_formula_range_tree_maximum(
  maximums : Array[Int],
  pending_additions : Array[Int],
  node : Int,
  lo : Int,
  hi : Int,
  query_lo : Int,
  query_hi : Int,
) -> Int {
  if query_lo <= lo && hi <= query_hi {
    return maximums[node]
  }
  shared_formula_range_tree_push(maximums, pending_additions, node)
  let middle = lo + (hi - lo) / 2
  let mut result = 0
  if query_lo <= middle {
    result = shared_formula_range_tree_maximum(
      maximums,
      pending_additions,
      node * 2,
      lo,
      middle,
      query_lo,
      query_hi,
    )
  }
  if query_hi > middle {
    let right = shared_formula_range_tree_maximum(
      maximums,
      pending_additions,
      node * 2 + 1,
      middle + 1,
      hi,
      query_lo,
      query_hi,
    )
    if right > result {
      result = right
    }
  }
  result
}

///|
/// Validates two-dimensional master rectangles in O(m log columns) time. End
/// events sort before starts on the following row, so touching but disjoint
/// ranges remain valid. The column tree has a fixed 16,384-column footprint.
fn validate_shared_formula_master_ranges(
  masters : Map[UInt, SharedFormulaMaster],
) -> Unit raise XlsxError {
  if masters.length() < 2 {
    return
  }
  let events : Array[SharedFormulaRangeEvent] = []
  for _, master in masters {
    events.push({
      row: master.row_lo,
      column_lo: master.column_lo,
      column_hi: master.column_hi,
      delta: 1,
    })
    events.push({
      row: master.row_hi + 1,
      column_lo: master.column_lo,
      column_hi: master.column_hi,
      delta: -1,
    })
  }
  events.sort_by((left, right) => {
    if left.row != right.row {
      left.row.compare(right.row)
    } else if left.delta != right.delta {
      // Remove rectangles that ended on the preceding row before inserting
      // rectangles that begin on this row.
      left.delta.compare(right.delta)
    } else if left.column_lo != right.column_lo {
      left.column_lo.compare(right.column_lo)
    } else {
      left.column_hi.compare(right.column_hi)
    }
  })
  let tree_size = cell_ref_max_cols * 4 + 8
  let maximums = Array::make(tree_size, 0)
  let pending_additions = Array::make(tree_size, 0)
  for event in events {
    if event.delta > 0 &&
      shared_formula_range_tree_maximum(
        maximums,
        pending_additions,
        1,
        1,
        cell_ref_max_cols,
        event.column_lo,
        event.column_hi,
      ) >
      0 {
      raise InvalidXml(msg="shared formula master ranges overlap")
    }
    shared_formula_range_tree_add(
      maximums,
      pending_additions,
      1,
      1,
      cell_ref_max_cols,
      event.column_lo,
      event.column_hi,
      event.delta,
    )
  }
}
