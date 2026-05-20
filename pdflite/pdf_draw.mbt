///|
/// Colour specification used by cpdf draw operations.
///
/// The `CYMK` spelling follows the OCaml source variant name in `cpdfdraw.ml`.
pub(all) enum PdfDrawColour {
  PdfDrawNoCol
  PdfDrawRGB(Double, Double, Double)
  PdfDrawGrey(Double)
  PdfDrawCYMK(Double, Double, Double, Double)
} derive(Debug, Eq, ToJson)

///|
/// Paragraph justification used by cpdf draw operations.
pub(all) enum PdfDrawJustification {
  PdfDrawLeft
  PdfDrawRight
  PdfDrawCentre
} derive(Debug, Eq, ToJson)

///|
/// Source-level cpdf draw operation.
///
/// This mirrors the operation shape from `cpdfdraw.ml`. The first rendering
/// slice converts path, graphics-state, colour, matrix, and paint operations to
/// `PdfContentOp`; text, image, form, and structure operations are represented
/// here and will be rendered by later cpdfdraw slices.
pub(all) enum PdfDrawOp {
  PdfDrawRect(Double, Double, Double, Double)
  PdfDrawBezier(Double, Double, Double, Double, Double, Double)
  PdfDrawBezier23(Double, Double, Double, Double)
  PdfDrawBezier13(Double, Double, Double, Double)
  PdfDrawTo(Double, Double)
  PdfDrawLine(Double, Double)
  PdfDrawClosePath
  PdfDrawSetFill(PdfDrawColour)
  PdfDrawSetStroke(PdfDrawColour)
  PdfDrawSetLineThickness(Double)
  PdfDrawSetLineCap(Int)
  PdfDrawSetLineJoin(Int)
  PdfDrawSetMiterLimit(Double)
  PdfDrawSetDashPattern(Array[Double], Double)
  PdfDrawMatrix(TransformMatrix)
  PdfDrawQq(Array[PdfDrawOp])
  PdfDrawFill
  PdfDrawFillEvenOdd
  PdfDrawStroke
  PdfDrawFillStroke
  PdfDrawFillStrokeEvenOdd
  PdfDrawClip
  PdfDrawClipEvenOdd
  PdfDrawFormXObject(Double, Double, Double, Double, String, Array[PdfDrawOp])
  PdfDrawUse(String)
  PdfDrawImageXObject(String, PdfObject)
  PdfDrawImage(String)
  PdfDrawNewPage
  PdfDrawOpacity(Double)
  PdfDrawSOpacity(Double)
  PdfDrawFontPack(String, PdfFontPack, Array[Int])
  PdfDrawFont(String, Double)
  PdfDrawTextSection(Array[PdfDrawOp])
  PdfDrawText(String)
  PdfDrawSpecialText(String)
  PdfDrawPara(Double?, PdfDrawJustification, Double, Array[String])
  PdfDrawNewline
  PdfDrawLeading(Double)
  PdfDrawCharSpace(Double)
  PdfDrawWordSpace(Double)
  PdfDrawTextScale(Double)
  PdfDrawRenderMode(Int)
  PdfDrawRise(Double)
  PdfDrawTag(String)
  PdfDrawEndTag
  PdfDrawSTag(String)
  PdfDrawEndSTag
  PdfDrawBeginArtifact
  PdfDrawEndArtifact
  PdfDrawNamespace(String)
  PdfDrawEltInfo(String, PdfObject)
  PdfDrawEndEltInfo(String)
  PdfDrawAutoTag(Bool)
} derive(Debug, Eq, ToJson)

///|
fn pdf_draw_colour_fill_ops(colour : PdfDrawColour) -> Array[PdfContentOp] {
  match colour {
    PdfDrawNoCol => []
    PdfDrawRGB(r, g, b) => [Op_rg(r, g, b)]
    PdfDrawGrey(g) => [Op_g(g)]
    PdfDrawCYMK(c, m, y, k) => [Op_k(c, m, y, k)]
  }
}

///|
fn pdf_draw_colour_stroke_ops(colour : PdfDrawColour) -> Array[PdfContentOp] {
  match colour {
    PdfDrawNoCol => []
    PdfDrawRGB(r, g, b) => [Op_RG(r, g, b)]
    PdfDrawGrey(g) => [Op_G(g)]
    PdfDrawCYMK(c, m, y, k) => [Op_K(c, m, y, k)]
  }
}

///|
/// Convert a cpdf content colour into the draw colour variant.
pub fn PdfContentColour::to_draw_colour(
  self : PdfContentColour,
) -> PdfDrawColour {
  match self {
    PdfContentGrey(grey) => PdfDrawGrey(grey)
    PdfContentRGB(red, green, blue) => PdfDrawRGB(red, green, blue)
    PdfContentCMYK(cyan, magenta, yellow, black) =>
      PdfDrawCYMK(cyan, magenta, yellow, black)
  }
}

///|
/// Parse a cpdf draw-control colour argument.
///
/// This ports `cpdfdrawcontrol.ml`'s `parse_colour`/`col_of_string` path while
/// preserving the draw-layer `NoCol` sentinel separately from content colours.
pub fn pdf_parse_draw_colour(text : String) -> PdfDrawColour raise PdfError {
  pdf_parse_content_colour(text).to_draw_colour()
}

///|
/// Parse a cpdf draw colour, returning `PdfDrawNoCol` on malformed input.
pub fn pdf_draw_colour_of_string(text : String) -> PdfDrawColour {
  pdf_parse_draw_colour(text) catch {
    _ => PdfDrawNoCol
  }
}

///|
fn pdf_draw_content_unsupported(
  op : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  raise SoftError("Cpdfdraw: unsupported draw operation " + op.debug_name())
}

///|
/// Return the cpdf diagnostic spelling for one draw operation.
pub fn PdfDrawOp::debug_name(self : PdfDrawOp) -> String {
  match self {
    PdfDrawQq(ops) => "Qq (" + pdf_string_of_drawops(ops) + ")"
    PdfDrawFormXObject(_, _, _, _, _, ops) =>
      "FormXObject (" + pdf_string_of_drawops(ops) + ")"
    PdfDrawTextSection(ops) =>
      "TextSection (" + pdf_string_of_drawops(ops) + ")"
    PdfDrawRect(_, _, _, _) => "Rect"
    PdfDrawBezier(_, _, _, _, _, _) => "Bezier"
    PdfDrawBezier23(_, _, _, _) => "Bezier23"
    PdfDrawBezier13(_, _, _, _) => "Bezier13"
    PdfDrawTo(_, _) => "To"
    PdfDrawLine(_, _) => "Line"
    PdfDrawClosePath => "ClosePath"
    PdfDrawSetFill(_) => "SetFill"
    PdfDrawSetStroke(_) => "SetStroke"
    PdfDrawSetLineThickness(_) => "SetLineThickness"
    PdfDrawSetLineCap(_) => "SetLineCap"
    PdfDrawSetLineJoin(_) => "SetLineJoin"
    PdfDrawSetMiterLimit(_) => "SetMiterLimit"
    PdfDrawSetDashPattern(_, _) => "SetDashPattern"
    PdfDrawMatrix(_) => "SetMatrix"
    PdfDrawFill => "Fill"
    PdfDrawFillEvenOdd => "FillEvenOdd"
    PdfDrawStroke => "Stroke"
    PdfDrawFillStroke => "FillStroke"
    PdfDrawFillStrokeEvenOdd => "FillStrokeEvenOdd"
    PdfDrawClip => "Clip"
    PdfDrawClipEvenOdd => "ClipEvenOdd"
    PdfDrawUse(_) => "Use"
    PdfDrawImageXObject(_, _) => "ImageXObject"
    PdfDrawImage(_) => "Image"
    PdfDrawNewPage => "NewPage"
    PdfDrawOpacity(_) => "Opacity"
    PdfDrawSOpacity(_) => "SOpacity"
    PdfDrawFontPack(name, _, _) => "FontPack " + name + " "
    PdfDrawFont(font, _) => "Font " + font + " "
    PdfDrawText(_) => "Text"
    PdfDrawSpecialText(_) => "SpecialText"
    PdfDrawPara(_, _, _, _) => "Para"
    PdfDrawNewline => "Newline"
    PdfDrawLeading(_) => "Leading"
    PdfDrawCharSpace(_) => "CharSpace"
    PdfDrawWordSpace(_) => "WordSpace"
    PdfDrawTextScale(_) => "TextScale"
    PdfDrawRenderMode(_) => "RenderMode"
    PdfDrawRise(_) => "Rise"
    PdfDrawEndTag => "EndTag"
    PdfDrawTag(name) => "Tag " + name
    PdfDrawEndSTag => "EndSTag"
    PdfDrawSTag(name) => "Tag " + name
    PdfDrawBeginArtifact => "BeginArtifact"
    PdfDrawEndArtifact => "EndArtifact"
    PdfDrawNamespace(name) => "Namespace " + name
    PdfDrawEltInfo(_, _) => "EltInfo"
    PdfDrawEndEltInfo(_) => "EndEltInfo"
    PdfDrawAutoTag(_) => "AutoTag"
  }
}

///|
/// Return cpdf's space-prefixed diagnostic string for a list of draw ops.
pub fn pdf_string_of_drawops(ops : ArrayView[PdfDrawOp]) -> String {
  let mut output = ""
  for op in ops {
    output = output + " " + op.debug_name()
  }
  output
}

///|
/// Compatibility wrapper for `PdfDrawOp::debug_name`.
pub fn pdf_string_of_drawop(op : PdfDrawOp) -> String {
  op.debug_name()
}

///|
/// Convert one cpdf draw operation to flat PDF content operators.
///
/// The currently ported rendering subset covers the direct operator mappings in
/// the front of `cpdfdraw.ml`'s `ops_of_drawop`: graphics state, matrix, path,
/// colour, paint, clip, and `q`/`Q` grouping. Later slices will fill in forms,
/// images, text, and tagged-content rendering.
pub fn PdfDrawOp::to_content_ops(
  self : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  match self {
    PdfDrawQq(ops) => {
      let output : Array[PdfContentOp] = [Op_q]
      for op in ops {
        for content_op in op.to_content_ops() {
          output.push(content_op)
        }
      }
      output.push(Op_Q)
      output
    }
    PdfDrawSetFill(colour) => pdf_draw_colour_fill_ops(colour)
    PdfDrawSetStroke(colour) => pdf_draw_colour_stroke_ops(colour)
    PdfDrawSetLineThickness(width) => [Op_w(width)]
    PdfDrawSetLineCap(cap) => [Op_J(cap)]
    PdfDrawSetLineJoin(join) => [Op_j(join)]
    PdfDrawSetMiterLimit(limit) => [Op_M(limit)]
    PdfDrawSetDashPattern(dashes, phase) => [Op_d(dashes, phase)]
    PdfDrawMatrix(matrix) => [Op_cm(matrix)]
    PdfDrawRect(x, y, w, h) => [Op_re(x, y, w, h)]
    PdfDrawBezier(x1, y1, x2, y2, x3, y3) => [Op_c(x1, y1, x2, y2, x3, y3)]
    PdfDrawBezier23(x2, y2, x3, y3) => [Op_v(x2, y2, x3, y3)]
    PdfDrawBezier13(x1, y1, x3, y3) => [Op_y(x1, y1, x3, y3)]
    PdfDrawTo(x, y) => [Op_m(x, y)]
    PdfDrawLine(x, y) => [Op_l(x, y)]
    PdfDrawClosePath => [Op_h]
    PdfDrawFill => [Op_f]
    PdfDrawFillEvenOdd => [Op_fstar]
    PdfDrawStroke => [Op_S]
    PdfDrawFillStroke => [Op_B]
    PdfDrawFillStrokeEvenOdd => [Op_Bstar]
    PdfDrawClip => [Op_W, Op_n]
    PdfDrawClipEvenOdd => [Op_Wstar, Op_n]
    _ => pdf_draw_content_unsupported(self)
  }
}

///|
/// Convert a sequence of cpdf draw operations to flat PDF content operators.
pub fn pdf_drawops_to_content_ops(
  ops : ArrayView[PdfDrawOp],
) -> Array[PdfContentOp] raise PdfError {
  let output : Array[PdfContentOp] = []
  for op in ops {
    for content_op in op.to_content_ops() {
      output.push(content_op)
    }
  }
  output
}

///|
/// Compatibility wrapper for `PdfDrawOp::to_content_ops`.
pub fn pdf_drawop_to_content_ops(
  op : PdfDrawOp,
) -> Array[PdfContentOp] raise PdfError {
  op.to_content_ops()
}
