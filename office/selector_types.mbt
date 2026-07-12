///|
/// Whether an address survives ordinary positional edits.
pub enum SelectorStability {
  Stable
  SnapshotRelative
}

///|
/// The optional selector attached to a named path segment.
pub enum SegmentSelection {
  Position(Int)
  Key(String, String)
}

///|
/// One named segment in a canonical Office selector. Construction stays
/// package-private so parsed selector invariants cannot be bypassed.
pub struct SelectorSegment {
  name : String
  selection : SegmentSelection?
}

///|
/// One validated XLSX A1 cell coordinate. Columns and rows are 1-based;
/// construction stays package-private so invalid coordinates cannot render.
pub struct CellAddress {
  column : Int
  row : Int
}

///|
/// The XLSX-only coordinate leaf of an Office selector.
pub enum SelectorCoordinate {
  Cell(CellAddress)
  Range(CellAddress, CellAddress)
}

///|
/// A parsed, format-explicit `office.selector/1` address. Instances originate
/// from the parser or syntax adapters so their canonical-form invariants hold.
pub struct OfficeSelector {
  format : DocumentFormat
  segments : ReadOnlyArray[SelectorSegment]
  coordinate : SelectorCoordinate?
  stability : SelectorStability
}

///|
/// A bounded, structured selector parse or validation failure. `offset` is a
/// zero-based Unicode-scalar position in the original input; `input` is a
/// bounded echo suitable for diagnostics.
pub(all) suberror SelectorError {
  SelectorError(
    code~ : String,
    offset~ : Int,
    input~ : String,
    message~ : String
  )
}

///|
pub impl Show for SelectorError with fn output(self, logger) {
  match self {
    SelectorError(code~, offset~, input~, message~) =>
      logger.write_string(
        "selector error \{code} at offset \{offset} in '\{input}': \{message}",
      )
  }
}

///|
/// Returns a positional selection when this segment uses one.
pub fn SelectorSegment::position(self : SelectorSegment) -> Int? {
  match self.selection {
    Some(Position(index)) => Some(index)
    _ => None
  }
}

///|
/// Returns a named selector value when this segment uses `key`.
pub fn SelectorSegment::key_value(
  self : SelectorSegment,
  key : StringView,
) -> String? {
  match self.selection {
    Some(Key(actual, value)) if actual == key.to_owned() => Some(value)
    _ => None
  }
}

///|
fn selector_column_name(column : Int) -> String {
  let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ".to_array()
  let reversed : Array[Char] = []
  let mut value = column
  while value > 0 {
    let offset = (value - 1) % 26
    reversed.push(alphabet[offset])
    value = (value - 1) / 26
  }
  let output = StringBuilder::new()
  let mut index = reversed.length()
  while index > 0 {
    index = index - 1
    output.write_char(reversed[index]) |> ignore
  }
  output.to_string()
}

///|
/// Renders this coordinate in canonical uppercase A1 form.
pub fn CellAddress::render(self : CellAddress) -> String {
  selector_column_name(self.column) + self.row.to_string()
}

///|
fn render_segment_selection(selection : SegmentSelection) -> String {
  match selection {
    Position(index) => "[\{index}]"
    Key(key, value) => "[\{key}=\{Json::string(value).stringify()}]"
  }
}

///|
/// Renders this selector in its unique canonical form.
pub fn OfficeSelector::render(self : OfficeSelector) -> String {
  let output = StringBuilder::new()
  output.write_string("/") |> ignore
  output.write_string(self.format.name()) |> ignore
  for segment in self.segments {
    output.write_string("/") |> ignore
    output.write_string(segment.name) |> ignore
    match segment.selection {
      Some(selection) =>
        output.write_string(render_segment_selection(selection)) |> ignore
      None => ()
    }
  }
  match self.coordinate {
    Some(Cell(address)) => {
      output.write_string("/cell[") |> ignore
      output.write_string(address.render()) |> ignore
      output.write_string("]") |> ignore
    }
    Some(Range(start, finish)) => {
      output.write_string("/range[") |> ignore
      output.write_string(start.render()) |> ignore
      output.write_string(":") |> ignore
      output.write_string(finish.render()) |> ignore
      output.write_string("]") |> ignore
    }
    None => ()
  }
  output.to_string()
}
