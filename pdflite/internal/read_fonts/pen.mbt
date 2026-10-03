// Port of read-fonts 0.39.2 `src/model/pen.rs` (subset).

///|
/// Interface for accepting a sequence of path commands.
pub(open) trait OutlinePen {
  /// Emit a command to begin a new subpath at (x, y).
  fn move_to(Self, Float, Float) -> Unit
  /// Emit a line segment from the current point to (x, y).
  fn line_to(Self, Float, Float) -> Unit
  /// Emit a quadratic bezier segment from the current point with a control
  /// point at (cx0, cy0) and ending at (x, y).
  fn quad_to(Self, Float, Float, Float, Float) -> Unit
  /// Emit a cubic bezier segment from the current point with control
  /// points at (cx0, cy0) and (cx1, cy1) and ending at (x, y).
  fn curve_to(Self, Float, Float, Float, Float, Float, Float) -> Unit
  /// Emit a command to close the current subpath.
  fn close(Self) -> Unit
}

///|
/// Single element of a path.
pub(all) enum PathElement {
  MoveTo(x~ : Float, y~ : Float)
  LineTo(x~ : Float, y~ : Float)
  QuadTo(cx0~ : Float, cy0~ : Float, x~ : Float, y~ : Float)
  CurveTo(
    cx0~ : Float,
    cy0~ : Float,
    cx1~ : Float,
    cy1~ : Float,
    x~ : Float,
    y~ : Float
  )
  Close
} derive(Eq, Debug)

///|
/// Pen that records all path elements.
pub(all) struct RecordingPen {
  elements : Array[PathElement]
}

///|
pub fn RecordingPen::new() -> RecordingPen {
  { elements: [], }
}

///|
pub impl OutlinePen for RecordingPen with fn move_to(self, x, y) {
  self.elements.push(MoveTo(x~, y~))
}

///|
pub impl OutlinePen for RecordingPen with fn line_to(self, x, y) {
  self.elements.push(LineTo(x~, y~))
}

///|
pub impl OutlinePen for RecordingPen with fn quad_to(self, cx0, cy0, x, y) {
  self.elements.push(QuadTo(cx0~, cy0~, x~, y~))
}

///|
pub impl OutlinePen for RecordingPen with fn curve_to(
  self,
  cx0,
  cy0,
  cx1,
  cy1,
  x,
  y,
) {
  self.elements.push(CurveTo(cx0~, cy0~, cx1~, cy1~, x~, y~))
}

///|
pub impl OutlinePen for RecordingPen with fn close(self) {
  self.elements.push(Close)
}

///|
/// Pen that drops all drawing output into the ether.
pub(all) struct NullPen {}

///|
pub impl OutlinePen for NullPen with fn move_to(_self, _x, _y) {
  ()
}

///|
pub impl OutlinePen for NullPen with fn line_to(_self, _x, _y) {
  ()
}

///|
pub impl OutlinePen for NullPen with fn quad_to(_self, _cx0, _cy0, _x, _y) {
  ()
}

///|
pub impl OutlinePen for NullPen with fn curve_to(
  _self,
  _cx0,
  _cy0,
  _cx1,
  _cy1,
  _x,
  _y,
) {
  ()
}

///|
pub impl OutlinePen for NullPen with fn close(_self) {
  ()
}
