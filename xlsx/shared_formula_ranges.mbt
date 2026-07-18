///|
priv struct SharedFormulaRangeEvent {
  row : Int
  column_lo : Int
  column_hi : Int
  delta : Int
}

///|
fn shared_formula_range_checkpoint(
  budget : ReadBudget?,
  cancelled : () -> Bool,
) -> Unit raise XlsxError {
  match budget {
    Some(value) => value.checkpoint()
    None => if cancelled() { raise ReadCancelled }
  }
}

///|
fn compare_shared_formula_range_events(
  left : SharedFormulaRangeEvent,
  right : SharedFormulaRangeEvent,
) -> Int {
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
}

///|
/// Bottom-up merge sort used instead of `Array::sort_by` so hostile workloads
/// cannot hide an uninterruptible O(m log m) comparison pass inside the
/// runtime. Each pass is charged before it runs and polls at 4 Ki-event
/// boundaries while merging and copying back.
fn sort_shared_formula_range_events(
  events : Array[SharedFormulaRangeEvent],
  budget? : ReadBudget,
  cancelled? : () -> Bool = () => false,
) -> Unit raise XlsxError {
  if events.length() < 2 {
    return
  }
  shared_formula_range_checkpoint(budget, cancelled)
  match budget {
    Some(value) =>
      // Account before allocating/copying the O(events) merge scratch buffer.
      value.charge_work(events.length())
    None => ()
  }
  let scratch = events.copy()
  let mut width = 1
  while width < events.length() {
    shared_formula_range_checkpoint(budget, cancelled)
    match budget {
      Some(value) => value.charge_work(events.length())
      None => ()
    }
    let mut run = 0
    let mut output = 0
    while run < events.length() {
      let middle = if run > events.length() - width {
        events.length()
      } else {
        run + width
      }
      let end = if middle > events.length() - width {
        events.length()
      } else {
        middle + width
      }
      let mut left = run
      let mut right = middle
      while left < middle || right < end {
        if (output & 4095) == 0 {
          shared_formula_range_checkpoint(budget, cancelled)
        }
        if right >= end ||
          (
            left < middle &&
            compare_shared_formula_range_events(events[left], events[right]) <=
            0
          ) {
          scratch[output] = events[left]
          left += 1
        } else {
          scratch[output] = events[right]
          right += 1
        }
        output += 1
      }
      run = end
    }
    shared_formula_range_checkpoint(budget, cancelled)
    match budget {
      Some(value) => value.charge_work(events.length())
      None => ()
    }
    for index in 0..<events.length() {
      if (index & 4095) == 0 {
        shared_formula_range_checkpoint(budget, cancelled)
      }
      events[index] = scratch[index]
    }
    width = if width > events.length() / 2 {
      events.length()
    } else {
      width * 2
    }
  }
  shared_formula_range_checkpoint(budget, cancelled)
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
  budget? : ReadBudget,
  cancelled? : () -> Bool = () => false,
) -> Unit raise XlsxError {
  if masters.length() < 2 {
    shared_formula_range_checkpoint(budget, cancelled)
    return
  }
  let events : Array[SharedFormulaRangeEvent] = []
  shared_formula_range_checkpoint(budget, cancelled)
  match budget {
    Some(value) => {
      value.charge_work(masters.length())
      value.charge_work(masters.length())
    }
    None => ()
  }
  let mut master_index = 0
  for _, master in masters {
    if (master_index & 4095) == 0 {
      shared_formula_range_checkpoint(budget, cancelled)
    }
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
    master_index += 1
  }
  sort_shared_formula_range_events(events, budget?, cancelled~)
  let tree_size = cell_ref_max_cols * 4 + 8
  let maximums = Array::make(tree_size, 0)
  let pending_additions = Array::make(tree_size, 0)
  match budget {
    Some(value) =>
      // Each event performs at most one range maximum and one range update on
      // a fixed-depth 16,384-column tree. Charging 32 event-width passes is a
      // conservative bound for both traversals without risking multiplication
      // overflow in attacker-controlled accounting.
      for _ in 0..<32 {
        value.charge_work(events.length())
      }
    None => ()
  }
  let mut event_index = 0
  for event in events {
    if (event_index & 4095) == 0 {
      shared_formula_range_checkpoint(budget, cancelled)
    }
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
    event_index += 1
  }
  shared_formula_range_checkpoint(budget, cancelled)
}

///|
test "shared formula event sorting polls cancellation inside long passes" {
  let events : Array[SharedFormulaRangeEvent] = []
  for index in 0..<(16 * 1024) {
    events.push({ row: 16 * 1024 - index, column_lo: 1, column_hi: 1, delta: 1 })
  }
  let checks = [0]
  let budget = ReadBudget::new(ReadLimits::new(), cancelled=() => {
    checks[0] += 1
    checks[0] >= 4
  })
  let result : Result[Unit, Error] = Ok(
    sort_shared_formula_range_events(events, budget~),
  ) catch {
    error => Err(error)
  }
  assert_eq(checks[0], 4)
  assert_true(result is Err(ReadCancelled))
}

///|
test "shared formula sorting checks cancellation before scratch allocation" {
  let events : Array[SharedFormulaRangeEvent] = []
  for index in 0..<(16 * 1024) {
    events.push({ row: index, column_lo: 1, column_hi: 1, delta: 1 })
  }
  let checks = [0]
  let budget = ReadBudget::new(ReadLimits::new(), cancelled=() => {
    checks[0] += 1
    true
  })
  try sort_shared_formula_range_events(events, budget~) catch {
    ReadCancelled => assert_eq(checks[0], 1)
    _ => fail("expected cancellation before shared-formula scratch allocation")
  } noraise {
    _ => fail("expected shared-formula sort cancellation")
  }
}
