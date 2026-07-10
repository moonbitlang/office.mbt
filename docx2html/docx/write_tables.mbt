// F2 of the content writers: tables. Serializes `Table`/`TableRow`/
// `TableCell` — including column spans (`w:gridSpan`) and row spans
// (`w:vMerge`, with the continuation cells the reader strips synthesized
// back into the following rows) — into schema-valid `w:tbl` markup. Same
// contract as F1: fail closed on anything unsupported.

///|
/// Grid width (in columns) of one row: the sum of its cells' column spans.
fn row_grid_width(cells : Array[DocumentElement]) -> Int {
  let mut width = 0
  for cell in cells {
    match cell {
      TableCell(col_span~, ..) => width += col_span
      _ => width += 1
    }
  }
  width
}

///|
/// A pending vertical merge: `remaining` continuation rows still to emit
/// for the merge that started at this grid column, spanning `col_span`
/// grid columns.
priv struct PendingMerge {
  mut remaining : Int
  col_span : Int
}

///|
fn write_table(
  children : Array[DocumentElement],
  properties : TableProperties,
  ctx : WriteContext,
) -> XmlElement raise DocxError {
  if properties.style_id is Some(_) || properties.style_name is Some(_) {
    raise Unsupported(
      message="the table writer cannot serialize table styles yet",
    )
  }
  let rows : Array[(Array[DocumentElement], Bool)] = []
  for child in children {
    match child {
      TableRow(children~, is_header~) => rows.push((children, is_header))
      other =>
        raise Unsupported(
          message="a table can only contain rows; cannot serialize: \{block_kind_name(other)}",
        )
    }
  }
  if rows.length() == 0 {
    raise Unsupported(
      message="the table writer cannot serialize an empty table",
    )
  }
  // The grid width is fixed by the widest row; narrower rows are rejected
  // rather than padded (silent padding would invent cells).
  let mut grid_width = 0
  for row in rows {
    let (cells, _) = row
    let width = row_grid_width(cells)
    if width > grid_width {
      grid_width = width
    }
  }
  if grid_width == 0 {
    raise Unsupported(
      message="the table writer cannot serialize a table with no cells",
    )
  }
  // Active vertical merges by starting grid column.
  let pending : Map[Int, PendingMerge] = Map([])
  let row_nodes : Array[XmlNode] = []
  for row_index, row in rows {
    let (cells, is_header) = row
    let cell_nodes : Array[XmlNode] = []
    let mut grid_column = 0
    let mut cell_cursor = 0
    while grid_column < grid_width {
      match pending.get(grid_column) {
        Some(merge) if merge.remaining > 0 => {
          // Synthesize the continuation cell the reader strips.
          merge.remaining -= 1
          cell_nodes.push(XmlElement(vmerge_continuation_cell(merge.col_span)))
          grid_column += merge.col_span
          if merge.remaining == 0 {
            pending.remove(grid_column - merge.col_span)
          }
          continue
        }
        _ => ()
      }
      if cell_cursor >= cells.length() {
        break
      }
      let cell = cells[cell_cursor]
      cell_cursor += 1
      guard cell is TableCell(children~, col_span~, row_span~) else {
        raise Unsupported(
          message="a table row can only contain cells; cannot serialize: \{block_kind_name(cell)}",
        )
      }
      if col_span < 1 || row_span < 1 {
        raise Unsupported(
          message="table cell spans must be at least 1 (got col_span=\{col_span}, row_span=\{row_span})",
        )
      }
      // A cell's span must not stride over ANY pending-merge column — the
      // placement loop only meets merges at their start column, so an
      // unchecked interior collision would silently push the vMerge
      // continuation into a later row (schema-valid, reader-masked, wrong
      // in Word — review finding on F2).
      for offset in 1..<col_span {
        if pending.get(grid_column + offset) is Some(interior) &&
          interior.remaining > 0 {
          raise Unsupported(
            message="row \{row_index + 1}: a cell spanning columns \{grid_column + 1}..\{grid_column + col_span} collides with a vertical merge at column \{grid_column + offset + 1}",
          )
        }
      }
      if row_span > 1 {
        if row_index + row_span > rows.length() {
          raise Unsupported(
            message="a row span of \{row_span} starting at row \{row_index + 1} exceeds the table's \{rows.length()} row(s)",
          )
        }
        pending[grid_column] = { remaining: row_span - 1, col_span }
      }
      cell_nodes.push(
        XmlElement(write_table_cell(children, col_span, row_span > 1, ctx)),
      )
      grid_column += col_span
    }
    if cell_cursor < cells.length() {
      raise Unsupported(
        message="row \{row_index + 1} is wider than the table grid (\{grid_width} column(s)) once vertical merges are placed",
      )
    }
    if grid_column != grid_width {
      raise Unsupported(
        message="row \{row_index + 1} covers \{grid_column} of \{grid_width} grid column(s); ragged tables are not serializable",
      )
    }
    let row_children : Array[XmlNode] = []
    if is_header {
      row_children.push(
        XmlElement(
          @xml.xml_element("w:trPr", children=[
            XmlElement(@xml.xml_element("w:tblHeader")),
          ]),
        ),
      )
    }
    row_children.append(cell_nodes)
    row_nodes.push(XmlElement(@xml.xml_element("w:tr", children=row_children)))
  }
  // Verify no merge outlived the table (guarded above, but keep the
  // invariant explicit).
  for _, merge in pending {
    if merge.remaining > 0 {
      raise Unsupported(
        message="a vertical merge extends past the last table row",
      )
    }
  }
  let grid_columns : Array[XmlNode] = []
  for _ in 0..<grid_width {
    grid_columns.push(XmlElement(@xml.xml_element("w:gridCol")))
  }
  @xml.xml_element(
    "w:tbl",
    children=[
      XmlElement(
        @xml.xml_element("w:tblPr", children=[
          XmlElement(
            @xml.xml_element("w:tblW", attributes={
              "w:w": "0",
              "w:type": "auto",
            }),
          ),
        ]),
      ),
      XmlElement(@xml.xml_element("w:tblGrid", children=grid_columns)),
      ..row_nodes,
    ],
  )
}

///|
/// A `vMerge` continuation cell: empty paragraph body (required by the
/// schema), continuing the merge started above.
fn vmerge_continuation_cell(col_span : Int) -> XmlElement {
  let tc_pr : Array[XmlNode] = []
  if col_span > 1 {
    tc_pr.push(
      XmlElement(
        @xml.xml_element("w:gridSpan", attributes={
          "w:val": col_span.to_string(),
        }),
      ),
    )
  }
  tc_pr.push(XmlElement(@xml.xml_element("w:vMerge")))
  @xml.xml_element("w:tc", children=[
    XmlElement(@xml.xml_element("w:tcPr", children=tc_pr)),
    XmlElement(@xml.xml_element("w:p")),
  ])
}

///|
fn write_table_cell(
  children : Array[DocumentElement],
  col_span : Int,
  starts_merge : Bool,
  ctx : WriteContext,
) -> XmlElement raise DocxError {
  let nodes : Array[XmlNode] = []
  // CT_TcPr sequence: gridSpan before vMerge.
  let tc_pr : Array[XmlNode] = []
  if col_span > 1 {
    tc_pr.push(
      XmlElement(
        @xml.xml_element("w:gridSpan", attributes={
          "w:val": col_span.to_string(),
        }),
      ),
    )
  }
  if starts_merge {
    tc_pr.push(
      XmlElement(
        @xml.xml_element("w:vMerge", attributes={ "w:val": "restart" }),
      ),
    )
  }
  if tc_pr.length() > 0 {
    nodes.push(XmlElement(@xml.xml_element("w:tcPr", children=tc_pr)))
  }
  // A cell must end with a block; the schema requires at least one
  // paragraph.
  if children.length() == 0 {
    nodes.push(XmlElement(@xml.xml_element("w:p")))
  } else {
    for child in children {
      nodes.push(XmlElement(write_block(child, ctx)))
    }
  }
  @xml.xml_element("w:tc", children=nodes)
}
