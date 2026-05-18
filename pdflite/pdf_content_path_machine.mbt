///|
pub(all) enum PdfContentPartialPath {
  PdfContentNoPartialPath
  PdfContentPartialPath(PdfContentPartialPathState)
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfContentPartialPathState {
  start_point : Point2
  current_point : Point2
  segments : Array[PdfPathSegment]
  subpaths : Array[PdfPathSubpath]
} derive(Debug, Eq, ToJson)

///|
pub(all) struct PdfContentPathOpResult {
  partial_path : PdfContentPartialPath
  drawn_path : PdfDrawnPath?
} derive(Debug, Eq, ToJson)

///|
pub fn pdf_content_no_partial_path() -> PdfContentPartialPath {
  PdfContentNoPartialPath
}

///|
fn pdf_content_path_empty_result(
  partial_path : PdfContentPartialPath,
) -> PdfContentPathOpResult {
  { partial_path, drawn_path: None }
}

///|
fn pdf_content_path_copy_segments(
  segments : ArrayView[PdfPathSegment],
) -> Array[PdfPathSegment] {
  [
    for segment in segments => segment
  ]
}

///|
fn pdf_content_path_append_segment(
  segments : ArrayView[PdfPathSegment],
  segment : PdfPathSegment,
) -> Array[PdfPathSegment] {
  let output = pdf_content_path_copy_segments(segments)
  output.push(segment)
  output
}

///|
fn pdf_content_path_copy_subpaths(
  subpaths : ArrayView[PdfPathSubpath],
) -> Array[PdfPathSubpath] {
  [
    for subpath in subpaths => subpath
  ]
}

///|
fn pdf_content_path_append_subpath(
  subpaths : ArrayView[PdfPathSubpath],
  subpath : PdfPathSubpath,
) -> Array[PdfPathSubpath] {
  let output = pdf_content_path_copy_subpaths(subpaths)
  output.push(subpath)
  output
}

///|
fn pdf_content_path_subpath(
  closure : PdfPathClosure,
  segments : ArrayView[PdfPathSegment],
) -> PdfPathSubpath {
  {
    hole: PdfPathNotHole,
    closure,
    segments: pdf_content_path_copy_segments(segments),
  }
}

///|
fn pdf_content_partial_path_clear(
  state : PdfContentPartialPathState,
) -> PdfContentPartialPath {
  PdfContentPartialPath({ ..state, segments: [], subpaths: [] })
}

///|
fn PdfContentPartialPath::content_move_to(
  self : PdfContentPartialPath,
  point : Point2,
) -> PdfContentPartialPath {
  match self {
    PdfContentPartialPath(state) if state.segments.length() == 0 =>
      PdfContentPartialPath({
        start_point: point,
        current_point: point,
        segments: [],
        subpaths: state.subpaths,
      })
    PdfContentPartialPath(state) =>
      PdfContentPartialPath({
        start_point: point,
        current_point: point,
        segments: [],
        subpaths: pdf_content_path_append_subpath(
          state.subpaths,
          pdf_content_path_subpath(PdfPathOpen, state.segments),
        ),
      })
    PdfContentNoPartialPath =>
      PdfContentPartialPath({
        start_point: point,
        current_point: point,
        segments: [],
        subpaths: [],
      })
  }
}

///|
fn PdfContentPartialPath::content_line_to(
  self : PdfContentPartialPath,
  point : Point2,
) -> PdfContentPartialPath {
  match self {
    PdfContentPartialPath(state) =>
      PdfContentPartialPath({
        ..state,
        current_point: point,
        segments: pdf_content_path_append_segment(
          state.segments,
          PdfPathStraight(state.current_point, point),
        ),
      })
    PdfContentNoPartialPath => self
  }
}

///|
fn PdfContentPartialPath::content_curve_to(
  self : PdfContentPartialPath,
  control1 : Point2,
  control2 : Point2,
  finish : Point2,
) -> PdfContentPartialPath {
  match self {
    PdfContentPartialPath(state) =>
      PdfContentPartialPath({
        ..state,
        current_point: finish,
        segments: pdf_content_path_append_segment(
          state.segments,
          PdfPathBezier(state.current_point, control1, control2, finish),
        ),
      })
    PdfContentNoPartialPath => self
  }
}

///|
fn PdfContentPartialPath::content_close_path(
  self : PdfContentPartialPath,
) -> PdfContentPartialPath {
  match self {
    PdfContentPartialPath(state) =>
      PdfContentPartialPath({
        ..state,
        segments: [],
        subpaths: pdf_content_path_append_subpath(
          state.subpaths,
          pdf_content_path_subpath(PdfPathClosed, state.segments),
        ),
      })
    PdfContentNoPartialPath => self
  }
}

///|
fn PdfContentPartialPath::content_rectangle(
  self : PdfContentPartialPath,
  x : Double,
  y : Double,
  width : Double,
  height : Double,
) -> PdfContentPartialPath {
  self
  .content_move_to(point2(x, y))
  .content_line_to(point2(x + width, y))
  .content_line_to(point2(x + width, y + height))
  .content_line_to(point2(x, y + height))
  .content_close_path()
}

///|
fn pdf_content_path_finish_subpaths(
  state : PdfContentPartialPathState,
  close_current : Bool,
) -> Array[PdfPathSubpath] {
  if state.segments.length() == 0 {
    pdf_content_path_copy_subpaths(state.subpaths)
  } else {
    pdf_content_path_append_subpath(
      state.subpaths,
      pdf_content_path_subpath(
        if close_current {
          PdfPathClosed
        } else {
          PdfPathOpen
        },
        state.segments,
      ),
    )
  }
}

///|
fn PdfContentPartialPath::content_paint(
  self : PdfContentPartialPath,
  winding_rule : PdfPathWindingRule,
  filled : Bool,
  stroked : Bool,
  close_current : Bool,
) -> PdfContentPathOpResult {
  match self {
    PdfContentPartialPath(state) => {
      let subpaths = pdf_content_path_finish_subpaths(state, close_current)
      {
        partial_path: pdf_content_partial_path_clear(state),
        drawn_path: Some({ stroked, filled, path: { winding_rule, subpaths } }),
      }
    }
    PdfContentNoPartialPath => pdf_content_path_empty_result(self)
  }
}

///|
/// Apply cpdfcontent path-construction and path-painting operator semantics.
///
/// Non-path operators are ignored. Painting operators return the drawn path and
/// clear the accumulated subpaths the same way `process_op` resets
/// `partial_path` after emitting a path.
pub fn PdfContentPartialPath::content_apply_path_op(
  self : PdfContentPartialPath,
  op : PdfContentOp,
) -> PdfContentPathOpResult {
  match op {
    Op_m(x, y) =>
      pdf_content_path_empty_result(self.content_move_to(point2(x, y)))
    Op_l(x, y) =>
      pdf_content_path_empty_result(self.content_line_to(point2(x, y)))
    Op_c(a, b, c, d, e, f) =>
      pdf_content_path_empty_result(
        self.content_curve_to(point2(a, b), point2(c, d), point2(e, f)),
      )
    Op_v(a, b, c, d) => {
      let next = match self {
        PdfContentPartialPath(state) =>
          self.content_curve_to(state.current_point, point2(a, b), point2(c, d))
        PdfContentNoPartialPath => self
      }
      pdf_content_path_empty_result(next)
    }
    Op_y(a, b, c, d) => {
      let finish = point2(c, d)
      let next = self.content_curve_to(point2(a, b), finish, finish)
      pdf_content_path_empty_result(next)
    }
    Op_h => pdf_content_path_empty_result(self.content_close_path())
    Op_re(x, y, width, height) =>
      pdf_content_path_empty_result(self.content_rectangle(x, y, width, height))
    Op_s =>
      self.content_apply_path_op(Op_h).partial_path.content_paint(
        PdfPathEvenOdd,
        false,
        true,
        false,
      )
    Op_b =>
      self.content_apply_path_op(Op_h).partial_path.content_paint(
        PdfPathNonZero,
        true,
        true,
        false,
      )
    Op_bstar =>
      self.content_apply_path_op(Op_h).partial_path.content_apply_path_op(
        Op_Bstar,
      )
    Op_f | Op_F =>
      self.content_apply_path_op(Op_h).partial_path.content_paint(
        PdfPathNonZero,
        true,
        false,
        false,
      )
    Op_S => self.content_paint(PdfPathEvenOdd, false, true, false)
    Op_B => self.content_paint(PdfPathNonZero, true, true, false)
    Op_Bstar =>
      self.content_apply_path_op(Op_h).partial_path.content_paint(
        PdfPathEvenOdd,
        true,
        true,
        false,
      )
    Op_fstar => self.content_paint(PdfPathEvenOdd, true, false, false)
    Op_n => { partial_path: PdfContentNoPartialPath, drawn_path: None }
    _ => pdf_content_path_empty_result(self)
  }
}

///|
/// Compatibility wrapper for `PdfContentPartialPath::content_apply_path_op`.
pub fn pdf_content_apply_path_op(
  partial_path : PdfContentPartialPath,
  op : PdfContentOp,
) -> PdfContentPathOpResult {
  partial_path.content_apply_path_op(op)
}
