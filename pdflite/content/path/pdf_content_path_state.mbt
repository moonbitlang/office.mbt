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
fn pdf_content_path_reverse_subpaths(
  subpaths : ArrayView[PdfPathSubpath],
) -> Array[PdfPathSubpath] {
  pdf_content_path_copy_subpaths(subpaths).rev()
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
fn pdf_content_path_copy_paths(paths : ArrayView[PdfPath]) -> Array[PdfPath] {
  [
    for path in paths => path
  ]
}

///|
fn pdf_content_path_prepend_path(
  paths : ArrayView[PdfPath],
  path : PdfPath,
) -> Array[PdfPath] {
  let output = [path]
  for existing in paths {
    output.push(existing)
  }
  output
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
  .content_move_to(@geometry.point2(x, y))
  .content_line_to(@geometry.point2(x + width, y))
  .content_line_to(@geometry.point2(x + width, y + height))
  .content_line_to(@geometry.point2(x, y + height))
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
fn PdfContentPartialPath::content_clipping_path(
  self : PdfContentPartialPath,
  winding_rule : PdfPathWindingRule,
) -> PdfPath? {
  match self {
    PdfContentPartialPath(state) =>
      if state.segments.length() == 0 && state.subpaths.length() == 0 {
        None
      } else {
        let subpaths = if state.segments.length() == 0 {
          pdf_content_path_reverse_subpaths(state.subpaths)
        } else {
          let output = [pdf_content_path_subpath(PdfPathClosed, state.segments)]
          for subpath in pdf_content_path_reverse_subpaths(state.subpaths) {
            output.push(subpath)
          }
          output
        }
        Some({ winding_rule, subpaths })
      }
    PdfContentNoPartialPath => None
  }
}

///|
fn PdfContentPartialPath::content_clip(
  self : PdfContentPartialPath,
  clipping_path : ArrayView[PdfPath],
  winding_rule : PdfPathWindingRule,
) -> PdfContentClippingOpResult {
  match self.content_clipping_path(winding_rule) {
    Some(path) =>
      {
        partial_path: self,
        clipping_path: pdf_content_path_prepend_path(clipping_path, path),
      }
    None =>
      {
        partial_path: self,
        clipping_path: pdf_content_path_copy_paths(clipping_path),
      }
  }
}
