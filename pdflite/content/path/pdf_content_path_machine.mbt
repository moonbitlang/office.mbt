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
      pdf_content_path_empty_result(
        self.content_move_to(@geometry.point2(x, y)),
      )
    Op_l(x, y) =>
      pdf_content_path_empty_result(
        self.content_line_to(@geometry.point2(x, y)),
      )
    Op_c(a, b, c, d, e, f) =>
      pdf_content_path_empty_result(
        self.content_curve_to(
          @geometry.point2(a, b),
          @geometry.point2(c, d),
          @geometry.point2(e, f),
        ),
      )
    Op_v(a, b, c, d) => {
      let next = match self {
        PdfContentPartialPath(state) =>
          self.content_curve_to(
            state.current_point,
            @geometry.point2(a, b),
            @geometry.point2(c, d),
          )
        PdfContentNoPartialPath => self
      }
      pdf_content_path_empty_result(next)
    }
    Op_y(a, b, c, d) => {
      let finish = @geometry.point2(c, d)
      let next = self.content_curve_to(@geometry.point2(a, b), finish, finish)
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

///|
/// Apply cpdfcontent clipping operator semantics for `W` and `W*`.
///
/// The partial path is intentionally preserved. In PDF content streams, `n`
/// commonly follows a clipping operator and clears the current path separately.
pub fn PdfContentPartialPath::content_apply_clipping_op(
  self : PdfContentPartialPath,
  clipping_path : ArrayView[PdfPath],
  op : PdfContentOp,
) -> PdfContentClippingOpResult {
  match op {
    Op_W => self.content_clip(clipping_path, PdfPathNonZero)
    Op_Wstar => self.content_clip(clipping_path, PdfPathEvenOdd)
    _ =>
      {
        partial_path: self,
        clipping_path: pdf_content_path_copy_paths(clipping_path),
      }
  }
}

///|
/// Compatibility wrapper for `PdfContentPartialPath::content_apply_clipping_op`.
pub fn pdf_content_apply_clipping_op(
  partial_path : PdfContentPartialPath,
  clipping_path : ArrayView[PdfPath],
  op : PdfContentOp,
) -> PdfContentClippingOpResult {
  partial_path.content_apply_clipping_op(clipping_path, op)
}
